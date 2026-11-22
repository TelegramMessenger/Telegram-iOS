#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class RichTextEditorViewTests: XCTestCase {
    /// Runs the main runloop until all currently-queued `DispatchQueue.main.async` blocks have executed.
    /// The coalesced selection-driven `onChange` is dispatched async, so this lets it fire deterministically
    /// (FIFO: our drain block is enqueued after it).
    private func drainMainQueue() {
        let exp = expectation(description: "drain main queue")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
    }

    // The façade surfaces first-responder transitions so a host can react (show/hide a panel). Each
    // callback fires ONCE on the genuine transition — gaining focus, then losing it — and NOT on a
    // redundant becomeFirstResponder() while already focused (the canvas calls that on every tap).
    func test_firstResponderCallbacks_fireOnceOnTransition_notWhenAlreadyFocused() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let editor = RichTextEditorView(frame: window.bounds)
        window.addSubview(editor)
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        editor.layoutIfNeeded()

        var becameCount = 0, resignedCount = 0
        editor.onBecameFirstResponder = { becameCount += 1 }
        editor.onResignedFirstResponder = { resignedCount += 1 }

        XCTAssertTrue(editor.becomeFirstResponder())
        XCTAssertEqual(becameCount, 1, "fires when the editor gains focus")
        XCTAssertEqual(resignedCount, 0)

        _ = editor.becomeFirstResponder()                       // already focused → no real transition
        XCTAssertEqual(becameCount, 1, "does not re-fire while already first responder")

        XCTAssertTrue(editor.canvas.resignFirstResponder())
        XCTAssertEqual(resignedCount, 1, "fires when the editor loses focus")
        XCTAssertEqual(becameCount, 1, "losing focus does not fire the became callback")
    }

    func test_pasteMediaHooks_forwardToCanvas() {
        let editor = RichTextEditorView()
        editor.onPasteMedia = { true }
        editor.canPasteMedia = { true }
        XCTAssertTrue(editor.canvas.onPasteMedia?() ?? false)    // forwarded to the canvas
        XCTAssertTrue(editor.canvas.canPasteMedia?() ?? false)
    }

    // A content-height change after an edit re-flows the host layout (canvas frame), not only on the
    // next external layout pass (e.g. a rotation). Pre-fix the edit never marked the host dirty, so a
    // normal layout pass left the canvas at its old height. (The canvas also fills at least the viewport
    // for hit-testing, so this uses a minimal-height editor — there the canvas tracks the content height.)
    func test_editGrowingContent_reflowsCanvasHeight() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()
        let before = editor.canvas.frame.height
        // Simulate the host: re-run layout via update() whenever the editor reports a change. The editor no
        // longer self-schedules layout — it notifies (onChange) and the host (parent) drives layout.
        editor.onChange = { [weak editor] in guard let editor else { return }; _ = editor.update(size: editor.bounds.size, insets: .zero) }
        // Add a paragraph at the end (Enter) → taller content; the edit's onChange drives the host re-layout.
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(editor.canvas.documentSizeValue),
                                                            DocumentTextPosition(editor.canvas.documentSizeValue))
        editor.canvas.insertText("\n")
        XCTAssertGreaterThan(editor.canvas.frame.height, before,
                             "host re-sizes the canvas when content height grows after an edit")
    }

    func test_tapsInEmptyAreaBelowContent_landOnTheCanvas() {
        // The tap/long-press/loupe recognizers live on the canvas, so the canvas must cover the whole
        // viewport — otherwise a tap in the empty area below a short document reaches the inert scroll view
        // and nothing happens (no caret, no loupe). Regression: the canvas used to hug the content height,
        // so only taps ON the text (the short content rect) registered.
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        editor.layoutIfNeeded()
        XCTAssertLessThan(editor.canvas.intrinsicContentSize.height, 200,
                          "precondition: the content is much shorter than the 400pt editor")
        // The canvas (which owns the gesture recognizers) fills at least the viewport.
        XCTAssertGreaterThanOrEqual(editor.canvas.frame.height, editor.bounds.height,
                                    "canvas fills the viewport so taps below the content still reach its recognizers")
        // A point in the empty area far below the text hit-tests into the canvas, not the inert scroll view.
        let emptyPoint = CGPoint(x: 20, y: 360)
        let hit = editor.hitTest(emptyPoint, with: nil)
        XCTAssertTrue(hit === editor.canvas || (hit?.isDescendant(of: editor.canvas) ?? false),
                      "a tap far below the text lands on the canvas (the gesture target), not the scroll view")
    }

    func test_shortContent_scrollContentFillsVisibleArea_notFullFrame_underInsets() {
        // With a short document the canvas fills the viewport (for hit-testing), but it must fill the
        // VISIBLE area (frame − top − bottom inset), not the full frame — otherwise the scroll content is
        // top+bottom too tall and the view scrolls/bounces over empty space. It must also track inset changes.
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        let insets = UIEdgeInsets(top: 40, left: 0, bottom: 100, right: 0)
        _ = editor.update(size: CGSize(width: 320, height: 480), insets: insets)
        XCTAssertEqual(editor.scrollContentHeightForTesting, 480 - 40 - 100, accuracy: 0.5,
                       "scroll content fills the visible area (frame − insets), so a short doc doesn't over-scroll")
        XCTAssertEqual(editor.canvas.frame.height, 480 - 40 - 100, accuracy: 0.5)
        // Updating the insets re-flows the content size (the reported 'doesn't update on inset change').
        _ = editor.update(size: CGSize(width: 320, height: 480), insets: .zero)
        XCTAssertEqual(editor.scrollContentHeightForTesting, 480, accuracy: 0.5,
                       "with no insets the visible area is the full frame")
    }

    func test_update_returnsMeasuredContentHeight() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        // No layoutIfNeeded needed: update(size:insets:) drives its own layout pass via performLayout.
        let oneLine = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        XCTAssertGreaterThan(oneLine, 0, "update returns the measured content height")
        // Growing the content increases the returned height.
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(editor.canvas.documentSizeValue),
                                                            DocumentTextPosition(editor.canvas.documentSizeValue))
        editor.canvas.insertText("\nA second line")
        let twoLines = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        XCTAssertGreaterThan(twoLines, oneLine, "more content → taller measured height")
    }

    // A document TALLER than the viewport must open resting BELOW the top inset (offset == −insets.top),
    // not scrolled under it. UIScrollView only CLAMPS the offset when an inset changes: a short document's
    // only valid offset IS −top so it snaps there, but for a tall document offset 0 stays in range — so the
    // first screenful sat under the navigation bar (the reported article-editor bug).
    func test_update_tallDocument_restsBelowTheTopInset() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: (0..<40).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        })
        _ = editor.update(size: CGSize(width: 320, height: 400),
                          insets: UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0))
        XCTAssertGreaterThan(editor.scrollContentHeightForTesting, 400,
                             "precondition: the content is taller than the viewport")
        XCTAssertEqual(editor.contentOffsetForTesting.y, -100, accuracy: 0.5,
                       "a tall document opens at the top of its content, below the top inset")
    }

    // The rest-at-top adjustment must not yank a user who has scrolled away — it only applies when the
    // scroll view is resting at the top AND the top inset actually changes (initial application, rotation,
    // a navigation-height change). A bottom-inset-only update (keyboard) leaves the offset alone.
    func test_update_doesNotResetAScrolledOffset() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: (0..<40).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        })
        let insets = UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0)
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: insets)
        editor.contentOffsetForTesting = CGPoint(x: 0, y: 200)
        _ = editor.update(size: CGSize(width: 320, height: 400),
                          insets: UIEdgeInsets(top: 100, left: 0, bottom: 260, right: 0))
        XCTAssertEqual(editor.contentOffsetForTesting.y, 200, accuracy: 0.5,
                       "a scrolled editor keeps its offset across an update")
    }

    // The scroll content must cover every laid-out block. Under the V2 rhythm a gap next to a block that
    // cannot own it (a button row / table / media at a sequence edge, or two such neighbours) is laid down
    // by `BlockStack.layout` as BARE space belonging to no box frame — so a content height summed from box
    // heights alone under-reports the laid-out extent and the trailing block falls below the scrollable
    // range (unreachable, overlapping the bottom inset band).
    func test_documentEndingInAButtonRow_scrollContentCoversEveryBlock() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        var blocks: [Block] = (0..<30).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        }
        blocks.append(.buttonRow(ButtonRowBlock(id: BlockID("row"), buttons: [
            ButtonRef(label: [TextRun(text: "Open")], action: .url("https://telegram.org"))
        ])))
        editor.document = Document(blocks: blocks)
        let margins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        _ = editor.update(size: CGSize(width: 320, height: 400),
                          insets: UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0),
                          contentMargins: margins)
        assertScrollContentCoversLayout(editor, margins: margins)
    }

    // Same invariant from the other edge: a document STARTING with a non-paragraph block gets a bare
    // leading gap, which likewise belongs to no box frame.
    func test_documentStartingWithAButtonRow_scrollContentCoversEveryBlock() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        var blocks: [Block] = [.buttonRow(ButtonRowBlock(id: BlockID("row"), buttons: [
            ButtonRef(label: [TextRun(text: "Open")], action: .url("https://telegram.org"))
        ]))]
        blocks += (0..<30).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        }
        editor.document = Document(blocks: blocks)
        let margins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        _ = editor.update(size: CGSize(width: 320, height: 400),
                          insets: UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0),
                          contentMargins: margins)
        assertScrollContentCoversLayout(editor, margins: margins)
    }

    // The accumulating case, and the one the report described: several non-paragraph blocks, each
    // contributing its own bare gap. One 4pt shortfall is subtle; five is a visibly clipped document.
    func test_documentWithSeveralNonTextBlocks_scrollContentCoversEveryBlock() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        func row(_ id: String) -> Block {
            .buttonRow(ButtonRowBlock(id: BlockID(id), buttons: [
                ButtonRef(label: [TextRun(text: "Open")], action: .url("https://telegram.org"))
            ]))
        }
        var blocks: [Block] = (0..<30).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        }
        blocks += [row("b1"), .paragraph(ParagraphBlock(id: BlockID("mid"), runs: [TextRun(text: "Middle")])),
                   row("b2"), .code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x = 1")])), row("b3")]
        editor.document = Document(blocks: blocks)
        let margins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        _ = editor.update(size: CGSize(width: 320, height: 400),
                          insets: UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0),
                          contentMargins: margins)
        assertScrollContentCoversLayout(editor, margins: margins)
    }

    /// The scroll content must equal the LAID-OUT extent (`root.contentHeight` + the content margins) and
    /// reach past the last block — the bare gaps the V2 rhythm lays between blocks that cannot own them
    /// belong to no box frame, so a height summed from box heights alone silently under-reports.
    private func assertScrollContentCoversLayout(_ editor: RichTextEditorView, margins: UIEdgeInsets,
                                                 file: StaticString = #filePath, line: UInt = #line) {
        let laidOut = editor.canvas.root.contentHeight + margins.top + margins.bottom
        XCTAssertEqual(editor.scrollContentHeightForTesting, laidOut, accuracy: 0.5,
                       "the scroll content must equal the laid-out extent", file: file, line: line)
        let lastBlockBottom = editor.canvas.boxes.last?.frame.maxY ?? 0
        XCTAssertGreaterThanOrEqual(editor.scrollContentHeightForTesting, lastBlockBottom + margins.bottom,
                                    "the scroll content must reach past the last block plus the bottom margin",
                                    file: file, line: line)
    }

    func test_update_appliesBottomInset() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        _ = editor.update(size: CGSize(width: 320, height: 400),
                          insets: UIEdgeInsets(top: 0, left: 0, bottom: 250, right: 0))
        XCTAssertEqual(editor.bottomContentInsetForTesting, 250, "update applies insets.bottom to the scroll view")
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        XCTAssertEqual(editor.bottomContentInsetForTesting, 0, "zero insets clear the bottom inset")
    }

    // The host (the chat composer) sets the scroll indicator insets to a constant input-field inset,
    // independent of the content insets (which carry the keyboard/panel overlap). The optional
    // `scrollIndicatorInsets` parameter overrides the indicator; omitting it (nil) tracks the content
    // insets, exactly the prior behavior. Because the value is passed every update, a later update with
    // no override returns the indicator to the content insets — no stale state (the clobber the old
    // one-shot setter suffered).
    func test_update_scrollIndicatorInsets_overrideFallbackAndNoStale() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        let content = UIEdgeInsets(top: 0, left: 0, bottom: 250, right: 0)

        // No override → the indicator tracks the content insets.
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: content)
        XCTAssertEqual(editor.verticalScrollIndicatorInsetsForTesting, content,
                       "with no override the indicator tracks the content insets")

        // Override → applied to the indicator, content inset unchanged (decoupled).
        let indicator = UIEdgeInsets(top: 9, left: 0, bottom: 9, right: -13)
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: content,
                          scrollIndicatorInsets: indicator)
        XCTAssertEqual(editor.verticalScrollIndicatorInsetsForTesting, indicator,
                       "an explicit override is applied to the indicator")
        XCTAssertEqual(editor.bottomContentInsetForTesting, 250,
                       "the override does not change the content inset")

        // Drop the override → back to the content insets, no stale value.
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: content)
        XCTAssertEqual(editor.verticalScrollIndicatorInsetsForTesting, content,
                       "dropping the override returns the indicator to the content insets")
    }

    func test_onChange_firesOnEdit() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        editor.layoutIfNeeded()
        let end = DocumentTextPosition(editor.canvas.documentSizeValue)
        editor.canvas.selectedTextRange = DocumentTextRange(end, end)
        var fired = false
        editor.onChange = { fired = true }
        editor.canvas.insertText("X")
        XCTAssertTrue(fired, "a content edit fires onChange")
    }

    // A pure selection/caret move notifies the host via the COALESCED path (see
    // scheduleSelectionDrivenOnChange): the notification is deferred to a single trailing async call so a
    // transient OS delete-range is never observed synchronously. `scrollCaretIntoView` still runs synchronously.
    func test_onChange_firesOnSelectionMove_coalescedAsync() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()
        drainMainQueue()   // drain any coalesced notification scheduled during setup
        var fired = false
        editor.onChange = { fired = true }
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(1), DocumentTextPosition(1))
        XCTAssertFalse(fired, "a pure selection move does NOT notify the host synchronously (coalesced)")
        drainMainQueue()
        XCTAssertTrue(fired, "the coalesced selection notification fires on the next runloop turn")
    }

    // Backspace "selection flare" guard: the OS drives a backspace as a NON-COLLAPSED `selectedTextRange`
    // set (the range to delete) immediately followed — same runloop turn — by the delete that collapses it.
    // Because the selection-driven host notification is coalesced, the host never SYNCHRONOUSLY observes the
    // transient non-empty selection, and the two synchronous selection changes collapse to ONE trailing call
    // that reads the settled (collapsed) state. (Without this, a selection-gated toolbar flares into its
    // "has selection" state and back out on every backspace.)
    func test_selectionOnChange_isCoalesced_soATransientSelectionIsNotObservedSynchronously() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()
        let start = editor.canvas.boxes[0].textStart
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(start + 3), DocumentTextPosition(start + 3))
        drainMainQueue()   // drain the coalesced notification from the caret placement above

        var onChangeCount = 0
        var observedSelectionDuringBurst = false
        editor.onChange = {
            onChangeCount += 1
            if editor.currentState().hasSelection { observedSelectionDuringBurst = true }
        }
        // Simulate the OS backspace burst SYNCHRONOUSLY: set the non-empty delete-range, then collapse it.
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(start + 2), DocumentTextPosition(start + 3))   // transient
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(start + 2), DocumentTextPosition(start + 2))   // collapsed
        XCTAssertEqual(onChangeCount, 0, "the transient non-empty selection is not surfaced synchronously")

        drainMainQueue()
        XCTAssertEqual(onChangeCount, 1, "the two synchronous selection changes coalesce to exactly one host notification")
        XCTAssertFalse(observedSelectionDuringBurst, "the host never observes hasSelection == true from the transient range")
        XCTAssertFalse(editor.currentState().hasSelection, "the settled state is a collapsed caret")
    }

    func test_onChange_firesOnFormattingToggle() {
        // Render-only formatting changes neither text length nor selection, but routes through editing { },
        // which calls notifyContentSizeChanged() unconditionally → the SYNCHRONOUS content-size onChange relay.
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(0),
                                                            DocumentTextPosition(editor.canvas.documentSizeValue))
        var fired = false
        editor.onChange = { fired = true }
        editor.toggleBold()
        XCTAssertTrue(fired, "a formatting toggle fires onChange")
    }

    // Loop-termination invariant: update(size:insets:) must NOT synchronously fire onChange. A host calls
    // update() from its onChange handler; if update re-fired onChange synchronously it would recurse.
    func test_update_doesNotSynchronouslyFireOnChange() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()   // settle layout so update() is a no-op resize, not a first layout
        var fired = false
        editor.onChange = { fired = true }
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        XCTAssertFalse(fired, "update(size:insets:) must not synchronously fire onChange (else the host recurses)")
    }

    // Inset-ownership invariant: a plain layoutSubviews pass preserves the parent-applied inset (performLayout
    // sizes only; only update(size:insets:) writes insets).
    func test_layoutSubviews_preservesParentInset() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        _ = editor.update(size: CGSize(width: 320, height: 400),
                          insets: UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0))
        XCTAssertEqual(editor.bottomContentInsetForTesting, 120)
        editor.setNeedsLayout(); editor.layoutIfNeeded()   // a system layout pass must not reset the inset
        XCTAssertEqual(editor.bottomContentInsetForTesting, 120, "layoutSubviews must preserve the parent inset")
    }

    // The canvas notifies its host whenever it invalidates its intrinsic content size.
    func test_canvas_notifiesHostOnContentSizeChange() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200); v.layoutIfNeeded()
        var fired = false
        v.onContentSizeChange = { fired = true }
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.documentSizeValue),
                                                DocumentTextPosition(v.documentSizeValue))
        v.insertText("\n")
        XCTAssertTrue(fired, "a height-changing edit notifies the host to re-layout")
    }
}

extension RichTextEditorViewTests {
    private func editorWithTable() -> RichTextEditorView {
        let e = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        e.document = Document(blocks: [
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), isHeader: true,
                           cells: [Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "Name")]))]),
                                   Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "Role")]))])]),
                       Row(id: BlockID("r1"),
                           cells: [Cell(id: BlockID("c"), blocks: [.paragraph(ParagraphBlock(id: BlockID("cp"), runs: [TextRun(text: "Ada")]))]),
                                   Cell(id: BlockID("d"), blocks: [.paragraph(ParagraphBlock(id: BlockID("dp"), runs: [TextRun(text: "Eng")]))])])])),
        ])
        e.layoutIfNeeded()
        return e
    }

    func test_facadeInsertTableRow_delegatesToCanvas() {
        let e = editorWithTable()
        let t = e.canvas.boxes.first as! TableBlockBox
        let pos = t.cellTextStart(row: 1, column: 0)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
        e.insertTableRowBelow()
        e.layoutIfNeeded()
        XCTAssertEqual((e.canvas.boxes.first as! TableBlockBox).rowCount, 3)
    }

    func test_facadeSetSelectionAlignment_delegatesToCanvas() {
        let e = editorWithTable()
        let t = e.canvas.boxes.first as! TableBlockBox
        let pos = t.cellTextStart(row: 1, column: 1)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
        e.setSelectionHorizontalAlignment(.right)
        e.layoutIfNeeded()
        guard case .table(let out) = e.document.blocks.first(where: { if case .table = $0 { return true } else { return false } }) else { return XCTFail() }
        // No structural selection → falls back to the caret's single cell (1,1); other cells untouched.
        XCTAssertEqual(out.rows[1].cells[1].horizontalAlignment, .right)
        XCTAssertEqual(out.rows[1].cells[0].horizontalAlignment, .center, "other column unchanged")
        XCTAssertEqual(out.rows[0].cells[1].horizontalAlignment, .center, "other row unchanged")
    }

    func test_facadeDeleteTable_onlyBlock_leavesEmptyParagraph() {
        let e = editorWithTable()   // sole block is a table
        let t = e.canvas.boxes.first as! TableBlockBox
        let pos = t.cellTextStart(row: 1, column: 0)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
        e.deleteTable()
        e.layoutIfNeeded()
        XCTAssertFalse(e.canvas.boxes.contains { $0 is TableBlockBox }, "the table is removed")
        XCTAssertEqual(e.canvas.boxes.count, 1, "a single (empty paragraph) block remains")
        XCTAssertFalse(e.currentState().isInTable, "caret is no longer in a table")
    }

    func test_facadeDeleteTable_surroundedByParagraphs_removesOnlyTheTable() {
        let e = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        e.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Before")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), isHeader: true,
                           cells: [Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "A")]))]),
                                   Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "B")]))])])])),
            .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [TextRun(text: "After")])),
        ])
        e.layoutIfNeeded()
        let t = e.canvas.boxes[1] as! TableBlockBox
        let pos = t.cellTextStart(row: 0, column: 0)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
        e.deleteTable()
        e.layoutIfNeeded()
        XCTAssertFalse(e.canvas.boxes.contains { $0 is TableBlockBox }, "the table is removed")
        XCTAssertEqual(e.canvas.boxes.count, 2, "the two surrounding paragraphs remain")
        XCTAssertFalse(e.currentState().isInTable, "caret moved out of the (deleted) table")
    }

    func test_facadeDeleteTable_noTableAtCaret_isNoOp() {
        let e = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        e.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        e.layoutIfNeeded()
        let before = e.canvas.boxes.count
        e.deleteTable()
        XCTAssertEqual(e.canvas.boxes.count, before, "no-op when the caret isn't in a table")
    }

    // height(forWidth:) equals what update(...) returns for the same width — measure == commit.
    func test_heightForWidth_matchesUpdate() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"),
            runs: [TextRun(text: "A long enough paragraph to wrap differently at 300 versus 140 points wide.")]))])
        let committed = editor.update(size: CGSize(width: 300, height: 200), insets: .zero)
        XCTAssertEqual(editor.height(forWidth: 300), committed, accuracy: 0.5)

        let other = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 140, height: 200))
        other.document = editor.document
        let committed140 = other.update(size: CGSize(width: 140, height: 200), insets: .zero)
        XCTAssertEqual(editor.height(forWidth: 140), committed140, accuracy: 0.5)
    }

    // The headline guarantee: measuring at another width changes nothing observable.
    func test_heightForWidth_doesNotMutateLiveLayout() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"),
            runs: [TextRun(text: "A long enough paragraph to wrap differently at narrow widths and grow taller.")]))])
        _ = editor.update(size: CGSize(width: 300, height: 200), insets: .zero)
        let canvasFrame = editor.canvas.frame
        let scrollContent = editor.scrollContentHeightForTesting
        var changes = 0
        editor.onChange = { changes += 1 }
        _ = editor.height(forWidth: 120)
        XCTAssertEqual(editor.canvas.frame, canvasFrame, "measure must not move the canvas")
        XCTAssertEqual(editor.scrollContentHeightForTesting, scrollContent, accuracy: 0.001)
        XCTAssertEqual(changes, 0, "measure must not fire onChange")
    }
}
#endif

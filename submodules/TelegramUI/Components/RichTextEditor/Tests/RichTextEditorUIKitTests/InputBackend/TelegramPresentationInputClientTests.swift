#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
@MainActor
final class TelegramPresentationInputClientTests: XCTestCase {
    // MARK: Fixtures

    /// A bare, non-first-responder canvas + client (no window, no facade) — for members that don't
    /// depend on first-responder-gated visuals (`interactionContainerView`, `visibleBounds`, `invalidate`,
    /// `dismissEditMenu`, and the never-writes-selection sweep).
    private func makeClient(_ texts: [String] = ["Alpha", "Beta"], width: CGFloat = 300)
        -> (DocumentCanvasView, TelegramPresentationInputClient) {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 400); v.layoutIfNeeded()
        return (v, TelegramPresentationInputClient(canvas: v, facade: nil))
    }

    /// A windowed, FOCUSED canvas + client (no facade) — for caret/handle/floating-cursor members that
    /// gate on `isFirstResponder`. Mirrors `SelectionHighlightTests.test_selectionHandles_shownForRange_…`
    /// and `ScrollCaretOnEditTests`' window fixtures. The window is returned so callers can keep it alive
    /// for the test's duration (a deallocated window can resign first-responder).
    private func makeFocusedClient(_ text: String = "hello world", width: CGFloat = 320)
        -> (UIWindow, DocumentCanvasView, TelegramPresentationInputClient) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 400))
        let v = DocumentCanvasView()
        v.frame = window.bounds
        window.addSubview(v)
        window.makeKeyAndVisible()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: text)]))], width: width)
        v.layoutIfNeeded()
        precondition(v.becomeFirstResponder(), "fixture precondition: the canvas must become first responder")
        return (window, v, TelegramPresentationInputClient(canvas: v, facade: nil))
    }

    /// `apply`'s `snapshot` argument is UNUSED (deviation D26 — see the client's header comment): the
    /// legacy `refreshSelectionUI()` it delegates to re-derives everything from the canvas's own live
    /// state. So every `apply` test can pass the SAME placeholder value regardless of the canvas's actual
    /// selection/revision — a real backend would of course keep this synchronized, but nothing here reads it.
    private func dummySnapshot(revision: UInt64 = 0) -> RichTextInputPresentationSnapshot {
        RichTextInputPresentationSnapshot(
            state: RichTextInputStateSnapshot(
                documentRevision: revision,
                selection: .caret(at: .downstream(0)),
                markedRange: nil,
                isComposing: false
            ),
            caret: nil,
            visibleSelectionSegments: [],
            visibleBounds: .zero,
            isFirstResponder: false,
            selectionDisplayVisible: false,
            interaction: .inactive
        )
    }

    // MARK: interactionContainerView

    func test_interactionContainerViewIdentityIsStableAcrossFiftyApplies() {
        let (v, c) = makeClient()
        let first = ObjectIdentifier(c.interactionContainerView)
        for _ in 0..<50 {
            c.apply(dummySnapshot(revision: v.documentRevision))
        }
        XCTAssertEqual(ObjectIdentifier(c.interactionContainerView), first,
                       "the container's identity must be stable for the whole backend lifetime")
    }

    func test_interactionContainerViewIsASubviewOfTheCanvasAndNonInteractive() {
        let (v, c) = makeClient()
        XCTAssertTrue(c.interactionContainerView.superview === v,
                     "the container is supplied by Telegram (the canvas), not created standalone")
        XCTAssertFalse(c.interactionContainerView.isUserInteractionEnabled,
                       "the container is a drawing plane only — it must not intercept touches")
    }

    // MARK: visibleBounds

    /// Embeds the canvas in a real `UIScrollView` host with a non-zero content offset so `viewportRect()`'s
    /// scroll-host branch and its no-host `bounds` fallback would disagree — a naive `canvas.bounds`
    /// implementation would pass a test that never diverges the two.
    func test_visibleBoundsMatchesTheCanvasViewportRect() {
        let (v, c) = makeClient()
        let scrollHost = UIScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 150))
        scrollHost.contentSize = CGSize(width: 600, height: 600)
        scrollHost.addSubview(v)
        scrollHost.contentOffset = CGPoint(x: 15, y: 30)
        XCTAssertEqual(c.visibleBounds, v.viewportRect())
        XCTAssertEqual(c.visibleBounds, CGRect(x: 15, y: 30, width: 200, height: 150),
                       "must reflect the scroll host's viewport, not the canvas's own (unrelated) bounds")
    }

    // MARK: apply

    func test_applyPositionsTheCaretForACollapsedSelection() {
        let (window, v, c) = makeFocusedClient()
        withExtendedLifetime(window) {
            let before = v.caretView.frame
            let pos = v.boxes[0].textStart + 3
            v.setSelectionForTesting(anchor: pos, head: pos)   // the raw test seam alone does not move the view
            XCTAssertEqual(v.caretView.frame, before,
                           "precondition: setSelectionForTesting alone must not reposition the caret view")

            c.apply(dummySnapshot(revision: v.documentRevision))

            let expected = v.caretHostPlacement(forGlobal: pos)!.frame
            XCTAssertEqual(v.caretView.frame, expected, "apply must position the caret at the new collapsed selection")
            XCTAssertNotEqual(v.caretView.frame, before, "sanity: the position must have actually changed")
            XCTAssertFalse(v.caretView.isHidden)
        }
    }

    func test_applyShowsTwoHandlesForARangedSelection() {
        let (window, v, c) = makeFocusedClient()
        withExtendedLifetime(window) {
            XCTAssertTrue(v.startHandleView.isHidden, "precondition: a collapsed selection shows no handles")
            XCTAssertTrue(v.endHandleView.isHidden)

            let s = v.boxes[0].textStart, e = s + 5
            v.setSelectionForTesting(anchor: s, head: e)
            c.apply(dummySnapshot(revision: v.documentRevision))

            XCTAssertFalse(v.startHandleView.isHidden, "apply must show the start handle for a ranged selection")
            XCTAssertFalse(v.endHandleView.isHidden, "apply must show the end handle for a ranged selection")
        }
    }

    /// The idempotence the spec requires. `blinkResetCount` (`CaretView`) is the stateful signal a
    /// no-op re-apply must NOT disturb — it is explicitly "exposed for unit tests to assert the
    /// idempotency of `DocumentCanvasView.updateCaretView`" (see that property's doc comment). Container
    /// and frame identity are also asserted, matching the brief's literal ask.
    func test_equalSnapshotsAppliedTwiceDoNotRestartCaretBlinking() {
        let (window, v, c) = makeFocusedClient()
        withExtendedLifetime(window) {
            let pos = v.boxes[0].textStart + 3
            v.setSelectionForTesting(anchor: pos, head: pos)

            c.apply(dummySnapshot(revision: v.documentRevision))
            let resetCountAfterFirst = v.caretView.blinkResetCount
            let containerAfterFirst = v.caretView.superview
            let frameAfterFirst = v.caretView.frame
            XCTAssertGreaterThan(resetCountAfterFirst, 0,
                                 "precondition: the first apply must have moved the caret, or the no-restart assertion below is vacuous")

            c.apply(dummySnapshot(revision: v.documentRevision))   // second, EQUAL apply — same live selection

            XCTAssertEqual(v.caretView.blinkResetCount, resetCountAfterFirst,
                           "a second apply of an unchanged selection must not restart the blink")
            XCTAssertTrue(v.caretView.superview === containerAfterFirst, "container identity must stay stable")
            XCTAssertEqual(v.caretView.frame, frameAfterFirst, "frame must stay stable")
        }
    }

    // MARK: invalidate

    /// Fix-round-1 item 2: ONE table-driven test pinning ALL EIGHT `RichTextInputPresentationInvalidation`
    /// bits — not just the two (`.caret`/`.spelling`) the original brief named by test name. Four bits
    /// (`.caret`/`.selection`/`.spelling`/`.annotations`) share the same `selectionHighlight` dirty-flag
    /// signal (the one overlay both `setNeedsDisplay()` and `setNeedsSpellUnderlineDisplay()` reach), via
    /// the local `assertMovesSelectionHighlight` helper; the other four each need a bespoke signal because
    /// each moves something `selectionHighlight` doesn't observe. Every case states, in its assertion
    /// message, what moving means for that bit — i.e. what would make it red.
    func test_invalidateEachBitMovesItsOwnObservableSignal() {
        func assertMovesSelectionHighlight(_ bit: RichTextInputPresentationInvalidation) {
            let (v, c) = makeClient()
            v.selectionHighlight.layer.displayIfNeeded()
            XCTAssertFalse(v.selectionHighlight.layer.needsDisplay(),
                          "setup must leave no pending redraw, or the assertion below is vacuous")
            c.invalidate(bit)
            XCTAssertTrue(v.selectionHighlight.layer.needsDisplay(),
                         "invalidate(\(bit)) must mark the selection/underline overlay dirty")
        }
        assertMovesSelectionHighlight(.caret)
        assertMovesSelectionHighlight(.selection)
        assertMovesSelectionHighlight(.spelling)
        // `.annotations` reaches the SAME overlay as `.spelling` in this legacy path (D29: the annotation
        // client's own rendering-attribute writes bypass this presentation client entirely, so there is no
        // OTHER reachable signal for `.annotations` to move here — an honest statement, not a weaker one).
        assertMovesSelectionHighlight(.annotations)

        // `.handles` — fix-round-1 item 1. Its own signal: the two handle-lollipop views' dirty flags,
        // distinct from `selectionHighlight` (positioning is `updateSelectionHandleViews()`'s job via
        // `apply`, not `invalidate`). Red if `invalidate(.handles)` stopped calling
        // `canvas.setNeedsHandleDisplay()` (or that method stopped touching both handle views).
        do {
            let (v, c) = makeClient()
            v.startHandleView.layer.displayIfNeeded()
            v.endHandleView.layer.displayIfNeeded()
            XCTAssertFalse(v.startHandleView.layer.needsDisplay(), "setup must leave no pending redraw")
            XCTAssertFalse(v.endHandleView.layer.needsDisplay(), "setup must leave no pending redraw")

            c.invalidate(.handles)

            XCTAssertTrue(v.startHandleView.layer.needsDisplay(), "invalidate(.handles) must mark the start handle dirty")
            XCTAssertTrue(v.endHandleView.layer.needsDisplay(), "invalidate(.handles) must mark the end handle dirty")
        }

        // `.markedText` — fix-round-1 item 3's empirical finding: the ghost-prediction foreground is a
        // TextKit rendering attribute on the owning paragraph's OWN `BlockLayoutEngine`
        // (`setGhostForeground`), which does NOT self-trigger that block's `BlockBackingView.setNeedsDisplay()`
        // (probed directly — see the fix-round-1 report section), and `canvas.setNeedsDisplay()`'s cascade
        // doesn't reach a plain paragraph view either. The real, verified signal is the block view's own
        // repaint counter, moved by `syncBlockViews()`'s render-signature reconciliation. Red if
        // `invalidate(.markedText)` stopped calling `canvas.syncBlockViews()`.
        do {
            let (v, c) = makeClient()
            guard let view = v.blockViewForTesting(BlockID("p0")) as? BlockBackingView else {
                return XCTFail("the paragraph's block view must be realized, or the signal below is vacuous")
            }
            let region = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("p0")) }!
            // A REAL reason to repaint (bumps `layout.renderVersion`, which feeds `BlockBox.renderSignature`).
            region.layout.setGhostForeground(.red, start: 0, end: 3)
            let before = view.setNeedsDisplayCountForTesting

            c.invalidate(.markedText)

            XCTAssertGreaterThan(view.setNeedsDisplayCountForTesting, before,
                                 "invalidate(.markedText) must repaint the ghost-styled block's own view")
        }

        // `.layout` — the ONE observable effect of `notifyContentSizeChanged()`: firing the host's
        // content-size hook. Red if `invalidate(.layout)` stopped calling `canvas.notifyContentSizeChanged()`.
        do {
            let (v, c) = makeClient()
            var calls = 0
            v.onContentSizeChange = { calls += 1 }

            c.invalidate(.layout)

            XCTAssertEqual(calls, 1, "invalidate(.layout) must fire onContentSizeChange exactly once")
        }

        // `.editMenu` — the existing dismiss counter (mirrors `test_dismissEditMenuIncrementsTheExistingCounter`,
        // reached here via `invalidate` rather than `dismissEditMenu(reason:)` directly). Red if
        // `invalidate(.editMenu)` stopped calling `canvas.dismissEditMenuForSelectionOrTextChange()`.
        do {
            let (v, c) = makeClient()
            let before = v.dismissEditMenuCountForTesting

            c.invalidate(.editMenu)

            XCTAssertEqual(v.dismissEditMenuCountForTesting, before + 1,
                           "invalidate(.editMenu) must dismiss the edit menu")
        }
    }

    // MARK: requestReveal

    /// Builds a facade whose document is a TALL run of paragraphs (needs the facade's OUTER vertical
    /// reveal) followed by a WIDE table (needs the canvas's own table-cell HORIZONTAL reveal) — the same
    /// wide-table shape `TableScrollGeometryCharacterizationTests` uses (four 160pt columns against a
    /// 320pt canvas). Both existing reveal authorities therefore have real, independently observable work
    /// to do, so this proves BOTH ran rather than merely that neither crashed.
    func test_requestRevealCaretCallsBothRevealAuthorities() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))   // short viewport
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let editor = RichTextEditorView(frame: window.bounds)
        window.addSubview(editor)

        func cell(_ id: String, _ text: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
        }
        var blocks: [Block] = (0..<10).map {
            Block.paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        }
        blocks.append(.table(TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 160), ColumnSpec(width: 160), ColumnSpec(width: 160), ColumnSpec(width: 160)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta"), cell("c", "Gamma"), cell("d", "Delta")])])))
        editor.document = Document(blocks: blocks)
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.becomeFirstResponder())

        let canvas = editor.canvasForTesting
        let inCellD = canvas.allLeafRegions().first { $0.ref == .paragraph(BlockID("dp")) }!.globalStart + 1
        canvas.setSelectionForTesting(anchor: inCellD, head: inCellD)
        editor.layoutIfNeeded()

        guard let tableView = canvas.blockViewForTesting(BlockID("t")) as? TableBackingView else {
            return XCTFail("the table must be realized for this test")
        }
        XCTAssertGreaterThan(tableView.scroll.contentSize.width, tableView.scroll.bounds.width,
                             "precondition: the table must actually be horizontally scrollable, or the canvas-side reveal assertion below is vacuous")
        XCTAssertEqual(tableView.scroll.contentOffset.x, 0, "precondition: cell D not yet scrolled into view")

        // Scroll the OUTER document to the top so the table (near document end) sits off-screen.
        editor.contentOffsetForTesting = .zero
        editor.layoutIfNeeded()
        let outerBefore = editor.contentOffsetForTesting.y

        let client = TelegramPresentationInputClient(canvas: canvas, facade: editor)
        client.requestReveal(.caret(.downstream(inCellD)), animated: false)

        XCTAssertGreaterThan(tableView.scroll.contentOffset.x, 0,
                             "the canvas's table-cell horizontal reveal authority must have run")
        XCTAssertGreaterThan(editor.contentOffsetForTesting.y, outerBefore,
                             "the facade's outer vertical reveal authority must also have run")
    }

    // MARK: dismissEditMenu

    func test_dismissEditMenuIncrementsTheExistingCounter() {
        let (v, c) = makeClient()
        let before = v.dismissEditMenuCountForTesting
        c.dismissEditMenu(reason: .selectionChanged)
        XCTAssertEqual(v.dismissEditMenuCountForTesting, before + 1)
        c.dismissEditMenu(reason: .contentChanged)   // `reason` is unused — any value increments the same counter
        XCTAssertEqual(v.dismissEditMenuCountForTesting, before + 2)
    }

    // MARK: tearDownPresentation

    func test_tearDownPresentationHidesCaretAndHandlesWithoutChangingTheSelection() {
        let (window, v, c) = makeFocusedClient()
        withExtendedLifetime(window) {
            // Establish a visible CARET first (presence), or hiding it below proves nothing.
            let pos = v.boxes[0].textStart + 3
            v.setSelectionForTesting(anchor: pos, head: pos)
            v.refreshSelectionUI()
            XCTAssertFalse(v.caretView.isHidden, "precondition: the caret must be visible before teardown")

            c.tearDownPresentation()

            XCTAssertTrue(v.caretView.isHidden, "tearDownPresentation must hide the caret")
            XCTAssertEqual(v.anchor, pos, "teardown must not change the selection")
            XCTAssertEqual(v.head, pos, "teardown must not change the selection")

            // Establish visible HANDLES next (presence), or hiding them below proves nothing.
            let s = v.boxes[0].textStart, e = s + 5
            v.setSelectionForTesting(anchor: s, head: e)
            v.refreshSelectionUI()
            XCTAssertFalse(v.startHandleView.isHidden, "precondition: the handles must be visible before teardown")
            XCTAssertFalse(v.endHandleView.isHidden)

            c.tearDownPresentation()

            XCTAssertTrue(v.startHandleView.isHidden, "tearDownPresentation must hide the start handle")
            XCTAssertTrue(v.endHandleView.isHidden, "tearDownPresentation must hide the end handle")
            XCTAssertEqual(v.anchor, s, "teardown must not change the selection")
            XCTAssertEqual(v.head, e, "teardown must not change the selection")
        }
    }

    func test_tearDownPresentationCancelsAnActiveFloatingCursor() {
        let (window, v, c) = makeFocusedClient()
        withExtendedLifetime(window) {
            let pos = v.boxes[0].textStart + 2
            v.setSelectionForTesting(anchor: pos, head: pos)
            v.refreshSelectionUI()
            v.beginFloatingCursor(at: v.caretRect(for: DocumentTextPosition(pos)).origin)
            XCTAssertTrue(v.floatingCursorActive,
                         "precondition: the floating-cursor gesture must actually be active, or canceling it below proves nothing")

            c.tearDownPresentation()

            XCTAssertFalse(v.floatingCursorActive, "tearDownPresentation must cancel an active floating-cursor gesture")
        }
    }

    // MARK: never writes the selection

    /// Snapshots `(anchor, head)` across every member — none of the eight may move it.
    func test_presentationClientNeverWritesTheSelection() {
        let (v, c) = makeClient()
        let anchorPos = v.boxes[0].textStart + 1, headPos = v.boxes[0].textStart + 4
        v.setSelectionForTesting(anchor: anchorPos, head: headPos)
        let anchorBefore = v.anchor, headBefore = v.head

        _ = c.interactionContainerView
        _ = c.visibleBounds
        c.apply(dummySnapshot(revision: v.documentRevision))
        c.invalidate(.all)
        c.requestReveal(.caret(.downstream(v.head)), animated: false)
        c.dismissEditMenu(reason: .selectionChanged)
        c.tearDownPresentation()

        XCTAssertEqual(v.anchor, anchorBefore, "no presentation-client member may write the selection")
        XCTAssertEqual(v.head, headBefore, "no presentation-client member may write the selection")
    }
}
#endif

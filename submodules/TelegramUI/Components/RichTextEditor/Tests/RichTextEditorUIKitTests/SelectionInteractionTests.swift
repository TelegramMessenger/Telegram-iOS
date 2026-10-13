#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SelectionInteractionTests: XCTestCase {
    /// Keeps the test window alive for the duration of a test (a view only becomes first responder once it's
    /// in a window). Recreated per test via `setUp`.
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
    }
    override func tearDown() {
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    /// Adds `v` to the key window (so `becomeFirstResponder` can succeed) and lays it out.
    private func hostInWindow(_ v: DocumentCanvasView) {
        window.addSubview(v)
        v.layoutIfNeeded()
    }

    private func canvasWithInteraction() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello world")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        v.installSelectionInteractions()
        hostInWindow(v)
        return v
    }

    /// A canvas with a leading paragraph + a wide (horizontally-scrollable) table, sized so the table
    /// overflows the canvas width (7 columns × 100pt grid columns in a 390pt-wide canvas → scrolls).
    private func canvasWithWideTable() -> (canvas: DocumentCanvasView, table: TableBlockBox) {
        func cell(_ id: String, _ text: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID("\(id)p"), runs: [TextRun(text: text)]))])
        }
        let cols = (0..<7).map { _ in ColumnSpec(width: 100) }
        let header = Row(id: BlockID("hr"), isHeader: true, cells: (0..<7).map { cell("h\($0)", "H\($0)") })
        let body = Row(id: BlockID("br"), cells: (0..<7).map { cell("b\($0)", "B\($0)") })
        let table = TableBlock(id: BlockID("wt"), columns: cols, rows: [header, body])
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Lead paragraph")])),
            .table(table),
        ], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        v.installSelectionInteractions()
        hostInWindow(v)
        let box = v.boxes.compactMap { $0 as? TableBlockBox }.first { $0.id == BlockID("wt") }!
        return (v, box)
    }

    /// Two stacked body paragraphs, so the END handle's knob (drawn BELOW paragraph 1's line) sits over
    /// paragraph 2's territory — the geometry that exposes the line-centering drag bug.
    private func canvasWithTwoParagraphs() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "First line")])),
            .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [TextRun(text: "Second line")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        v.installSelectionInteractions()
        hostInWindow(v)
        return v
    }

    // MARK: - Handle drag preserves the initial touch→knob offset (iOS-style, not line-centered)

    func test_selectionHandleDrag_preservesGrabOffset_doesNotSnapToAdjacentLine() {
        // Grabbing a selection knob should keep the endpoint at its starting offset from the touch — the knob
        // is drawn OFFSET from the text line, so mapping the raw finger point snaps the endpoint to whatever
        // line is under the finger (here: paragraph 2). The drag must instead track the grabbed endpoint.
        let v = canvasWithTwoParagraphs()
        _ = v.becomeFirstResponder()
        let head = v.boxes[0].textStart + 5            // select "First" in paragraph 1
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.head)
        v.setSelectionHead(global: head)

        let r = SelectionHandleView.knobRadius
        let caret = v.caretRect(for: DocumentTextPosition(head))
        let endKnob = CGPoint(x: caret.midX, y: caret.maxY + r)   // END knob, drawn BELOW paragraph 1's line

        // Precondition: a RAW knob touch projects onto the adjacent line (the bug we're fixing).
        XCTAssertNotEqual(v.closestGlobalPosition(to: endKnob), head,
                          "precondition: a raw knob touch lands on the adjacent line, not the grabbed endpoint")

        // Begin the drag at the knob (captures the touch→endpoint offset), then map at the SAME touch point.
        v.captureSelectionDragOffset(endpoint: .head, touch: endKnob)
        XCTAssertEqual(v.selectionDragPosition(forTouch: endKnob), head,
                       "the drag preserves the grab offset — maps to the grabbed endpoint, not the finger's line")
    }

    func test_selectionDragPosition_tracksTheCaretAnchoredPoint_whenTouchMoves() {
        // After a grab, moving the touch by Δ must map as if the finger were Δ from the captured anchor
        // (touch + storedOffset), i.e. the offset is preserved across the whole drag — not re-derived per move.
        let v = canvasWithTwoParagraphs()
        _ = v.becomeFirstResponder()
        let head = v.boxes[0].textStart + 5
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.head)
        v.setSelectionHead(global: head)

        let r = SelectionHandleView.knobRadius
        let caret = v.caretRect(for: DocumentTextPosition(head))
        let endKnob = CGPoint(x: caret.midX, y: caret.maxY + r)
        v.captureSelectionDragOffset(endpoint: .head, touch: endKnob)

        let delta = CGPoint(x: 40, y: 0)
        let moved = CGPoint(x: endKnob.x + delta.x, y: endKnob.y + delta.y)
        // storedOffset == caretCenter − endKnob, so selectionDragPosition(moved) == closest(caretCenter + delta).
        let expected = v.closestGlobalPosition(to: CGPoint(x: caret.midX + delta.x, y: caret.midY + delta.y))
        XCTAssertEqual(v.selectionDragPosition(forTouch: moved), expected,
                       "drag maps touch+storedOffset, preserving the initial grab offset as the touch moves")
    }

    // MARK: - Handle views are host-configurable (carry Display dismiss-gesture flags)

    func test_selectionHandleViews_areInteractive_soTheyCanCarryHostFlags() {
        // The handle views must be hit-testable for a knob touch to resolve to THEM (not the whole editor),
        // so a host-set `disablesInteractiveModalDismiss`/`…Keyboard…` flag is scoped to knob interaction.
        let v = canvasWithInteraction()
        XCTAssertTrue(v.startHandleView.isUserInteractionEnabled)
        XCTAssertTrue(v.endHandleView.isUserInteractionEnabled)
    }

    func test_configureSelectionHandleView_isAppliedToBothHandles() {
        let v = canvasWithInteraction()
        var configuredIsStart: [Bool] = []
        v.configureSelectionHandleView = { handle in
            if let h = handle as? SelectionHandleView { configuredIsStart.append(h.isStart) }
        }
        XCTAssertEqual(Set(configuredIsStart), Set([true, false]),
                       "the host hook is applied to both the start and end handle views")
    }

    func test_selectionHandleView_hitArea_matchesTheDragTolerance_aroundTheCaret() {
        // The interactive hit area must match the canvas drag gate (±dragHitTolerance around the endpoint
        // caret) so the dismiss-gesture flag covers exactly where a handle drag can start.
        let handle = SelectionHandleView(isStart: false)
        let caret = CGRect(x: 50, y: 100, width: 2, height: 20)
        handle.frame = handle.boundingFrame(forCaret: caret)
        handle.setCaretLocalRect(handle.caretLocalRect(forCaret: caret))
        let tol = SelectionHandleView.dragHitTolerance
        let local = handle.caretLocalRect(forCaret: caret)
        XCTAssertTrue(handle.point(inside: CGPoint(x: local.midX, y: local.midY), with: nil), "on the caret")
        XCTAssertTrue(handle.point(inside: CGPoint(x: local.midX, y: local.maxY + tol - 1), with: nil), "within tolerance below")
        XCTAssertFalse(handle.point(inside: CGPoint(x: local.midX, y: local.maxY + tol + 5), with: nil), "beyond tolerance")
    }

    // MARK: - The move-cursor long-press yields to an active selection handle

    func test_cursorLongPress_isBlocked_onAnActiveSelectionHandle_soTheHandleCanBeGrabbed() {
        // With a ranged selection the two handle lollipops show. Pressing one to drag it must NOT let the
        // loupe / move-cursor long-press begin — otherwise it fires on the stationary hold (before the handle
        // pan can move), collapses the selection via setCaret, and the handles vanish before they can be
        // grabbed. So the long-press gate fails on a touch that lands on a handle (an "active item").
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.head)
        v.setSelectionHead(global: v.boxes[0].textStart + 5)

        let startCaret = v.caretRect(for: DocumentTextPosition(v.selFrom))
        let endCaret = v.caretRect(for: DocumentTextPosition(v.selTo))
        XCTAssertFalse(v.shouldBeginCursorLongPress(at: CGPoint(x: startCaret.midX, y: startCaret.midY)),
                       "the long-press must not begin on the START handle — the handle pan owns that touch")
        XCTAssertFalse(v.shouldBeginCursorLongPress(at: CGPoint(x: endCaret.midX, y: endCaret.midY)),
                       "the long-press must not begin on the END handle")
    }

    func test_cursorLongPress_stillBegins_awayFromTheHandles_whileASelectionIsActive() {
        // Only a touch ON a handle blocks the long-press; a long-press elsewhere in the document still moves
        // the cursor (standard iOS: it collapses the selection at the pressed point).
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.head)
        v.setSelectionHead(global: v.boxes[0].textStart + 5)

        let endCaret = v.caretRect(for: DocumentTextPosition(v.selTo))
        let farPoint = CGPoint(x: 300, y: endCaret.midY)   // far to the right of both endpoints
        XCTAssertTrue(v.shouldBeginCursorLongPress(at: farPoint),
                      "away from both handles the move-cursor long-press proceeds normally")
    }

    func test_cursorLongPress_alwaysBegins_whenSelectionIsCollapsed() {
        // No ranged selection ⇒ no handles ⇒ nothing to protect; grabbing the caret with a long-press must
        // still work even directly on the caret.
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        v.setCaret(global: v.boxes[0].textStart + 2)
        let caret = v.caretRect(for: DocumentTextPosition(v.head))
        XCTAssertTrue(v.shouldBeginCursorLongPress(at: CGPoint(x: caret.midX, y: caret.midY)),
                      "with a collapsed selection the long-press begins even on the caret (grab-the-cursor)")
    }

    // MARK: - Loupe end does not re-present (flicker) an already-open menu on a stationary press

    func test_loupeEnd_suppressesRepresent_forAStationaryPressOnAnAlreadyOpenMenu() {
        // A quick tap near the caret is caught as a loupe (0.05s near-cursor delay). If the menu is already open,
        // the loupe dismisses it on .began; re-presenting on .ended is the disappear-then-reappear flicker. A
        // stationary press (caret didn't move) on an open menu is a tap-like toggle-off → do NOT re-present.
        let v = canvasWithInteraction()
        XCTAssertFalse(v.loupeShouldPresentMenuOnEnd(menuWasVisibleAtBegan: true, caretMoved: false),
                       "stationary press on an already-open menu → toggle off, no re-present (no flicker)")
        // A press that began with no menu is a normal long-press → present the menu on release.
        XCTAssertTrue(v.loupeShouldPresentMenuOnEnd(menuWasVisibleAtBegan: false, caretMoved: false),
                      "long-press with no menu open → present on release")
        // A real cursor DRAG presents at the new caret even if the menu was open (native behavior).
        XCTAssertTrue(v.loupeShouldPresentMenuOnEnd(menuWasVisibleAtBegan: true, caretMoved: true),
                      "a drag re-presents at the new caret position")
        XCTAssertTrue(v.loupeShouldPresentMenuOnEnd(menuWasVisibleAtBegan: false, caretMoved: true),
                      "a drag from no menu presents on release")
    }

    // MARK: - The loupe gray "shadow" caret shows only once the accent glider diverges from it

    func test_loupeShadowShouldShow_onlyBeyondMinSeparation() {
        // During a loupe drag the gray "shadow" (the snapped real caret) is hidden while the accent glider (at
        // the finger) sits on top of it, and appears only once they diverge by >= loupeShadowMinSeparation.
        let v = canvasWithInteraction()
        let sep = DocumentCanvasView.loupeShadowMinSeparation
        XCTAssertFalse(v.loupeShadowShouldShow(accentX: 100, snappedX: 100), "coincident → shadow hidden")
        XCTAssertFalse(v.loupeShadowShouldShow(accentX: 100 + sep - 0.5, snappedX: 100), "just within the threshold → hidden")
        XCTAssertTrue(v.loupeShadowShouldShow(accentX: 100 + sep, snappedX: 100), "at the threshold → shown")
        XCTAssertTrue(v.loupeShadowShouldShow(accentX: 100 - sep - 5, snappedX: 100), "diverged to the left → shown (symmetric)")
    }

    // MARK: - Long-press loupe drag reports the selection ONCE (at the final position), not per frame

    func test_setCaret_withReportSuppressed_defersHostReport_untilTheDragEnds() {
        // A long-press loupe cursor drag moves the caret every frame, but the host must be told the selection
        // ONCE at the final position (the spacebar-trackpad model) — NOT continuously. Mid-drag the caret is
        // set with `reportSelectionChange: false`, which still moves the caret + brackets the input delegate
        // (the OS stays in sync) but suppresses `onSelectionChange` (the host report). The terminal setter
        // reports exactly once.
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        var reportCount = 0
        v.onSelectionChange = { reportCount += 1 }

        // Per-frame drag moves: caret advances, host is NOT told.
        v.setCaret(global: v.boxes[0].textStart + 1, reportSelectionChange: false)
        v.setCaret(global: v.boxes[0].textStart + 2, reportSelectionChange: false)
        v.setCaret(global: v.boxes[0].textStart + 3, reportSelectionChange: false)
        XCTAssertEqual(reportCount, 0, "a mid-drag caret move does not report the selection to the host")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 3, "the caret still moves each frame (just silently)")

        // The drag's terminal setter (default: reports) fires exactly one host report at the final position.
        v.setCaret(global: v.boxes[0].textStart + 3)
        XCTAssertEqual(reportCount, 1, "the final caret position is reported to the host exactly once")
    }

    func test_loupeDrag_coalescesInputDelegate_soKeyboardSuggestionsDoNotChurn() {
        // The keyboard recomputes its autocorrect/candidate bar on every `selectionDidChange` — so a per-frame
        // input-delegate bracket during the cursor drag makes the suggestions visibly JUMP. The drag coalesces
        // those brackets (`beginCoalescedSelectionDrag` + `setCaret(reportSelectionChange:false)` skipping the
        // bracket while coalescing) and fires exactly ONE at the end (`endCoalescedSelectionDrag`).
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        let spy = SelectionDelegateSpy()
        v.inputDelegate = spy

        v.beginCoalescedSelectionDrag()
        v.setCaret(global: v.boxes[0].textStart + 1, reportSelectionChange: false)
        v.setCaret(global: v.boxes[0].textStart + 2, reportSelectionChange: false)
        v.setCaret(global: v.boxes[0].textStart + 3, reportSelectionChange: false)
        XCTAssertEqual(spy.didChangeCount, 0,
                       "no per-frame selectionDidChange during the drag → the keyboard suggestion bar doesn't churn")

        v.endCoalescedSelectionDrag()
        XCTAssertEqual(spy.didChangeCount, 1, "the keyboard is told the final selection exactly once, at the end")
    }

    // MARK: - A gesture selection fires ONE input-delegate bracket (no autocorrect jiggle)

    func test_applySelection_firesASingleSelectionBracket_noAutocorrectJiggle() {
        // A deliberate word/paragraph/Select-All selection brackets the OS input delegate exactly ONCE. It must
        // NOT do the old autocorrect-dismiss "jiggle" (a fake→real selection round-trip = two EXTRA brackets):
        // each `selectionDidChange` drives the keyboard's synchronous `updateForChangedSelection` (~25ms on
        // device), so the jiggle tripled the double-tap selection latency for a non-standard nicety. Dropped —
        // a pending correction now just commits on selection-move like a stock UITextView.
        let v = canvasWithInteraction()   // "Hello world"
        _ = v.becomeFirstResponder()
        v.setCaret(global: v.boxes[0].textStart + 2)
        let spy = SelectionDelegateSpy()
        v.inputDelegate = spy
        spy.reset()

        v.selectWord(at: v.boxes[0].textStart + 2)
        XCTAssertEqual(spy.didChangeCount, 1, "a word selection fires exactly one selectionDidChange (no jiggle)")
        XCTAssertNotEqual(v.selFrom, v.selTo, "the word is selected")

        spy.reset()
        v.selectAllText()
        XCTAssertEqual(spy.didChangeCount, 1, "Select-All also fires exactly one selectionDidChange (no jiggle)")
    }

    // MARK: - Outer scroll yields to a selection-handle grip

    func test_gripYieldingScrollView_yieldsOnlyNearASelectionGrip() {
        // The outer document scroll (and the inner table scroll) must yield their pan to the canvas's
        // handle-drag when the touch is on a selection grip — otherwise a vertical knob drag races the scroll.
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        let scroll = GripYieldingScrollView()
        scroll.canvas = v

        // No ranged selection → there is no grip, so the scroll never yields.
        XCTAssertFalse(scroll.yieldsToGrip(at: CGPoint(x: 20, y: 20)), "no selection ⇒ no grip ⇒ scroll, don't yield")

        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.head)
        v.setSelectionHead(global: v.boxes[0].textStart + 5)
        let caret = v.caretRect(for: DocumentTextPosition(v.selFrom))
        XCTAssertTrue(scroll.yieldsToGrip(at: CGPoint(x: caret.midX, y: caret.midY)),
                      "yields on a selection grip so the canvas handle-drag wins")
        XCTAssertFalse(scroll.yieldsToGrip(at: CGPoint(x: caret.midX, y: caret.midY + 200)),
                       "does not yield far from any grip — normal scrolling")
    }

    // MARK: - No OS selection-display interaction (app draws everything itself)

    func test_noSelectionDisplayInteraction_isInstalled() {
        // The canvas owns every selection visual (caret/wash/handles), so it must NOT attach a
        // `UITextSelectionDisplayInteraction`. On iOS 18+ that interaction installs its own default selection
        // chrome (`_UITextSelectionLollipopView`/highlight/cursor) that custom no-draw replacement views no
        // longer suppress — the default lollipops leak at the container origin (handle knobs at ~CGPoint.zero).
        let v = canvasWithInteraction()
        if #available(iOS 17.0, *) {   // the type itself is iOS 17+ (it's what we assert we DON'T install)
            XCTAssertFalse(v.interactions.contains { $0 is UITextSelectionDisplayInteraction },
                           "no UITextSelectionDisplayInteraction (its default handle chrome would leak at the origin)")
        }
    }

    func test_appDrawsItsOwnHandles_forARangedSelection() {
        // The app draws handles itself so they ride a table's horizontal scroll/overscroll. With no OS
        // interaction, these own-drawn `SelectionHandleView`s are the ONLY handles.
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.head); v.setSelectionHead(global: v.boxes[0].textStart + 5)
        XCTAssertFalse(v.startHandleView.isHidden, "the app's own start handle shows for a range")
        XCTAssertFalse(v.endHandleView.isHidden, "the app's own end handle shows for a range")
    }

    // MARK: - Own-drawn caret

    func test_appDrawsItsOwnCaret_forACollapsedSelection() {
        // We draw the caret ourselves (a `CaretView`) so it rides a table's horizontal scroll/overscroll;
        // there is no OS cursor view to compete with it.
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        v.setCaret(global: v.boxes[0].textStart + 2)
        XCTAssertFalse(v.caretView.isHidden, "the app's own caret shows for a collapsed selection")
        XCTAssertTrue(v.caretView.superview === v, "a paragraph caret is hosted on the canvas")
    }

    func test_caretInWideTableCell_isHostedInsideTheTableContentView_andBlinks() {
        let (v, table) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        let target = table.cellTextStart(row: 1, column: 0)!
        v.setCaret(global: target)

        // The caret view rides the scroll: it lives inside the table's scrolling content view.
        XCTAssertTrue(v.caretView.superview is TableContentView,
                      "a caret inside a table cell is hosted in the table's scrolling content view")

        // Its frame ≈ the cell caret in content-local coords (unscrolled canvas − table.frame.origin).
        let (region, local) = v.leafRegion(containingGlobal: target)!
        let expected = region.layout.caretRect(atOffset: local)
            .offsetBy(dx: region.canvasOrigin.x - table.frame.minX,
                      dy: region.canvasOrigin.y - table.frame.minY)
        XCTAssertEqual(v.caretView.frame.minX, expected.minX, accuracy: 0.5)
        XCTAssertEqual(v.caretView.frame.minY, expected.minY, accuracy: 0.5)
        XCTAssertEqual(v.caretView.frame.height, expected.height, accuracy: 0.5)

        // A blink animation is running.
        XCTAssertFalse(v.caretView.layer.animationKeys()?.isEmpty ?? true,
                       "the caret view blinks (has a running opacity animation)")
    }

    func test_caretInParagraph_isHostedOnTheCanvas() {
        let (v, _) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        v.setCaret(global: v.boxes[0].textStart + 2)   // inside the lead paragraph

        XCTAssertTrue(v.caretView.superview === v, "a paragraph caret is hosted directly on the canvas")
        let (region, local) = v.leafRegion(containingGlobal: v.head)!
        let expected = region.layout.caretRect(atOffset: local)
            .offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y)
        XCTAssertEqual(v.caretView.frame.minX, expected.minX, accuracy: 0.5)
        XCTAssertEqual(v.caretView.frame.minY, expected.minY, accuracy: 0.5)
    }

    func test_caretHidden_whenRangedSelection() {
        let (v, _) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.head)
        v.setSelectionHead(global: v.boxes[0].textStart + 4)   // a ranged (non-collapsed) selection
        XCTAssertTrue(v.caretView.isHidden || v.caretView.superview == nil,
                      "no blinking caret while a range is selected")
    }

    func test_caretHidden_whenStructuralTableSelection() {
        let (v, _) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        v.selectTableColumns(0...0)   // structural row/column selection → outline is the indicator, no caret
        XCTAssertTrue(v.caretView.isHidden || v.caretView.superview == nil,
                      "no blinking caret while a table row/column is structurally selected")
    }

    func test_updateCaretView_isIdempotent_doesNotRestartBlinkOnNoOp() {
        // Re-running updateCaretView with the SAME caret (e.g. on a scroll tick) must NOT restart the
        // blink — otherwise the caret would never finish a blink cycle while the table scrolls.
        let (v, table) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        v.setCaret(global: table.cellTextStart(row: 1, column: 0)!)
        let resetsAfterFirst = v.caretView.blinkResetCount
        v.updateCaretView()
        v.updateCaretView()
        XCTAssertEqual(v.caretView.blinkResetCount, resetsAfterFirst,
                       "a no-op updateCaretView (same container + frame) does not restart the blink")
    }

    // MARK: - Selection-handle drag auto-scrolls the document vertically near the viewport edge

    /// Tall content inside a short scroll view so a selection-handle drag has vertical room to scroll.
    private func tallCanvasInScroll() -> (canvas: DocumentCanvasView, scroll: UIScrollView) {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let v = DocumentCanvasView()
        v.setBlocks((0..<40).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 1600)
        scroll.addSubview(v); scroll.contentSize = v.frame.size; v.layoutIfNeeded()
        return (v, scroll)
    }

    func test_dragAutoScroll_scrollsDocumentDown_whenHandleNearsBottomEdge() {
        let (v, scroll) = tallCanvasInScroll()
        // A non-collapsed selection whose HEAD we drag toward the bottom edge (no table involved).
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[1].textStart)
        let beforeY = scroll.contentOffset.y
        let beforeHead = v.head

        // A drag point in the viewport's bottom band (band = 60 of the 200pt viewport), in canvas coords.
        let bottomBand = CGPoint(x: 40, y: scroll.contentOffset.y + 190)
        v.updateDragAutoScroll(point: bottomBand, headInTable: false)
        for _ in 0..<5 { v.dragAutoScrollTick() }

        XCTAssertGreaterThan(scroll.contentOffset.y, beforeY,
                             "dragging a selection handle near the bottom edge scrolls the document down")
        XCTAssertNotEqual(v.head, beforeHead,
                          "the selection head re-extends to the content under the finger as it scrolls")
        v.stopDragAutoScroll()
        let maxY = scroll.contentSize.height - scroll.bounds.height
        XCTAssertLessThanOrEqual(scroll.contentOffset.y, maxY + 0.5, "clamped to the max content offset")
    }

    func test_dragAutoScroll_scrollsDocumentUp_whenHandleNearsTopEdge() {
        let (v, scroll) = tallCanvasInScroll()
        scroll.contentOffset.y = 800   // scrolled into the middle so there is room to scroll UP
        v.setSelectionForTesting(anchor: v.boxes[20].textStart, head: v.boxes[20].textStart + 1)
        let beforeY = scroll.contentOffset.y

        // A drag point in the viewport's top band, in canvas coords.
        let topBand = CGPoint(x: 40, y: scroll.contentOffset.y + 10)
        v.updateDragAutoScroll(point: topBand, headInTable: false)
        for _ in 0..<5 { v.dragAutoScrollTick() }

        XCTAssertLessThan(scroll.contentOffset.y, beforeY,
                          "dragging a selection handle near the top edge scrolls the document up")
        v.stopDragAutoScroll()
        XCTAssertGreaterThanOrEqual(scroll.contentOffset.y, -0.5, "clamped to zero")
    }

    func test_dragAutoScroll_reextendsTheDraggedAnchor_notTheHead() {
        let (v, scroll) = tallCanvasInScroll()
        // A range selection, then grab the ANCHOR (start) handle and drag it toward the bottom edge. The
        // auto-scroller must re-extend the endpoint being dragged (the anchor), leaving the head put.
        v.setSelectionForTesting(anchor: v.boxes[2].textStart, head: v.boxes[1].textStart)
        v.draggingEndpoint = .anchor
        let headBefore = v.head
        let anchorBefore = v.anchor

        let bottomBand = CGPoint(x: 40, y: scroll.contentOffset.y + 190)
        v.updateDragAutoScroll(point: bottomBand, headInTable: false)
        for _ in 0..<5 { v.dragAutoScrollTick() }

        XCTAssertGreaterThan(scroll.contentOffset.y, 0, "the document scrolls while dragging the anchor near the edge")
        XCTAssertNotEqual(v.anchor, anchorBefore, "the dragged ANCHOR re-extends as the document scrolls")
        XCTAssertEqual(v.head, headBefore, "the head (the endpoint NOT being dragged) stays put")
        v.stopDragAutoScroll()
        v.draggingEndpoint = nil
    }

    func test_dragAutoScroll_doesNotScroll_whenHandleInViewportMiddle() {
        let (v, scroll) = tallCanvasInScroll()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[1].textStart)
        let beforeY = scroll.contentOffset.y

        // A point in the middle of the viewport must not start the auto-scroller.
        v.updateDragAutoScroll(point: CGPoint(x: 40, y: scroll.contentOffset.y + 100), headInTable: false)
        XCTAssertNil(v.dragAutoScrollLink, "no auto-scroll link starts for a mid-viewport handle")
        for _ in 0..<5 { v.dragAutoScrollTick() }
        XCTAssertEqual(scroll.contentOffset.y, beforeY, accuracy: 0.5, "no scroll when the handle is mid-viewport")
        v.stopDragAutoScroll()
    }
}

/// Records `selectionDidChange` calls so a test can assert (a) the input-delegate bracket is coalesced during a
/// caret drag (fired once at the end, not per frame) and (b) the autocorrect-dismiss "jiggle" notifies the
/// keyboard of an intermediate selection before restoring the real one. `headSequence` captures the canvas's
/// `head` at each callback. The iOS-18.4 `conversationContext(_:didChange:)` requirement is stubbed under
/// `@available` so the class conforms on the current SDK.
private final class SelectionDelegateSpy: NSObject, UITextInputDelegate {
    var didChangeCount = 0
    var headSequence: [Int] = []
    func selectionWillChange(_ textInput: (any UITextInput)?) {}
    func selectionDidChange(_ textInput: (any UITextInput)?) {
        didChangeCount += 1
        if let canvas = textInput as? DocumentCanvasView { headSequence.append(canvas.head) }
    }
    func textWillChange(_ textInput: (any UITextInput)?) {}
    func textDidChange(_ textInput: (any UITextInput)?) {}
    @available(iOS 18.4, *)
    func conversationContext(_ context: UIConversationContext?, didChange textInput: (any UITextInput)?) {}
    func reset() { didChangeCount = 0; headSequence = [] }
}
#endif

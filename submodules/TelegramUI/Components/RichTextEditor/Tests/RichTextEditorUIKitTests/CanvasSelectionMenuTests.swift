#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasSelectionMenuTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    /// [ paragraph "Hello world", table( "Alpha" | "Beta" ) ]
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello world")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    func region(_ v: DocumentCanvasView, _ id: String) -> LeafTextRegion {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
    }

    func test_tapOutcome_onCaret_togglesMenu() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 3, head: r.globalStart + 3)
        XCTAssertEqual(v.tapOutcome(forResolvedPosition: r.globalStart + 3, point: .zero), .toggleMenu)
    }
    func test_tapOutcome_elsewhere_movesCaret() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 3, head: r.globalStart + 3)
        XCTAssertEqual(v.tapOutcome(forResolvedPosition: r.globalStart + 6, point: .zero), .setCaret(r.globalStart + 6))
    }
    func test_tapOutcome_insideSelection_togglesMenu() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // "Hello" selected
        let rects = v.selectionRects(globalFrom: v.selFrom, globalTo: v.selTo)
        let onSelection = CGPoint(x: rects[0].midX, y: rects[0].midY)   // a tap ON the rendered selection
        // A tap on the selection toggles the menu and KEEPS the selection (does not collapse).
        XCTAssertEqual(v.tapOutcome(forResolvedPosition: r.globalStart + 2, point: onSelection), .toggleMenu)
    }
    func test_tapOutcome_outsideSelection_setsCaret() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 3)   // "Hel" selected
        let caret = v.caretRect(for: DocumentTextPosition(r.globalStart + 6))           // past "Hel", off the selection
        // A tap OUTSIDE the selection collapses to a caret there.
        XCTAssertEqual(v.tapOutcome(forResolvedPosition: r.globalStart + 6, point: CGPoint(x: caret.midX, y: caret.midY)),
                       .setCaret(r.globalStart + 6))
    }
    /// The reported bug: a tap in the EMPTY AREA adjacent to the selection (so `closestGlobalPosition` resolves
    /// to a boundary offset INSIDE [selFrom, selTo]) but whose POINT is not on the rendered selection must
    /// collapse the selection + move the caret — NOT toggle/keep the menu. The composer's compact layout makes
    /// this the common "tap to deselect" gesture; the old offset-only check treated it as "inside".
    func test_tapOutcome_emptyAreaResolvingInsideRange_setsCaret() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + r.length)   // whole line selected
        let farOutside = CGPoint(x: 10_000, y: -10_000)   // nowhere near any selection rect
        XCTAssertEqual(v.tapOutcome(forResolvedPosition: r.globalStart + r.length, point: farOutside),
                       .setCaret(r.globalStart + r.length), "an empty-area tap must collapse the selection, not keep it")
    }
    /// Repro for the reported bug: tapping the MIDPOINT of the selection's highlight must NOT collapse it.
    /// Exercises the full single-tap handler (closestGlobalPosition → tapOutcome → toggle/setCaret), not
    /// just the pure tapOutcome. If this passes but the live app still collapses, the cause is the
    /// framework calling our selectedTextRange setter (not our handler).
    func test_performSingleTap_insideSelection_keepsSelection() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // "Hello" selected
        let rects = v.selectionRects(globalFrom: v.selFrom, globalTo: v.selTo)
        XCTAssertFalse(rects.isEmpty, "selection should have a highlight rect")
        let mid = CGPoint(x: rects[0].midX, y: rects[0].midY)
        v.performSingleTap(at: mid)
        XCTAssertEqual(v.selFrom, r.globalStart, "tap inside the selection must keep it (not collapse)")
        XCTAssertEqual(v.selTo, r.globalStart + 5)
    }
    /// Tapping OUTSIDE an active selection must collapse it to a caret at the tapped position (not keep the
    /// selection, not jump the caret elsewhere). Ground-truth for the reported "tap outside doesn't deselect".
    func test_performSingleTap_outsideSelection_clearsAndMovesCaret() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // "Hello" selected
        let caret = v.caretRect(for: DocumentTextPosition(r.globalStart + 8))           // inside "world", outside the selection
        v.performSingleTap(at: CGPoint(x: caret.midX, y: caret.midY))
        XCTAssertEqual(v.selFrom, v.selTo, "tap outside the selection must collapse it")
        XCTAssertEqual(v.head, r.globalStart + 8, "the caret moves to the tapped position")
    }
    /// Flicker fix: a toggle-tap presents only when the menu is neither showing nor just-dismissed. The
    /// system auto-dismisses the menu on the tap (willDismiss → justDismissed) before our delayed handler
    /// runs, so `(menuVisible:false, justDismissed:true)` MUST dismiss (not re-present = the flicker).
    func test_menuToggleAction_suppressesRepresentRightAfterDismiss() {
        let v = canvas()
        XCTAssertEqual(v.menuToggleAction(menuVisible: false, justDismissed: false, wasFirstResponder: true), .present)  // caret, no menu → show
        XCTAssertEqual(v.menuToggleAction(menuVisible: true,  justDismissed: false, wasFirstResponder: true), .dismiss)  // menu up → hide
        XCTAssertEqual(v.menuToggleAction(menuVisible: false, justDismissed: true,  wasFirstResponder: true), .dismiss)  // this tap closed it → don't reopen
        XCTAssertEqual(v.menuToggleAction(menuVisible: true,  justDismissed: true,  wasFirstResponder: true), .dismiss)
    }
    /// Focus-tap fix: a tap that BRINGS the field into first-responder (`wasFirstResponder == false`) must only
    /// place the caret — never open the menu — even when it lands on the (default) caret with no menu showing.
    /// This is the empty-field bug: `head` defaults to 0, a focusing tap resolves to 0, `tapOutcome` → `.toggleMenu`,
    /// and the menu was presented on the very first tap. A second tap on the caret (now first responder) still shows it.
    func test_menuToggleAction_focusingTap_neverPresents() {
        let v = canvas()
        XCTAssertEqual(v.menuToggleAction(menuVisible: false, justDismissed: false, wasFirstResponder: false), .dismiss,
                       "a tap that focuses the field must not open the menu")
        XCTAssertEqual(v.menuToggleAction(menuVisible: false, justDismissed: false, wasFirstResponder: true), .present,
                       "tapping the caret in an already-focused field still toggles the menu open")
    }
    func test_selectWord_atCaret_selectsWord() {
        let v = canvas()
        let r = region(v, "h"); v.selectWord(at: r.globalStart + 2)   // inside "Hello"
        XCTAssertEqual(v.selFrom, r.globalStart + 0)
        XCTAssertEqual(v.selTo, r.globalStart + 5)
    }
    func test_selectWord_insideCell() {
        let v = canvas()
        let a = region(v, "ap")
        v.selectWord(at: a.globalStart + 1)   // inside "Alpha"
        XCTAssertEqual(v.selFrom, a.globalStart)
        XCTAssertEqual(v.selTo, a.globalStart + 5)
    }
    func test_selectParagraph_selectsWholeRegion() {
        let v = canvas()
        let r = region(v, "h"); v.selectParagraph(at: r.globalStart + 4)
        XCTAssertEqual(v.selFrom, r.globalStart)
        XCTAssertEqual(v.selTo, r.globalStart + r.length)   // "Hello world"
    }

    // MARK: A gesture-driven RANGE selection must notify the host (the double-tap "flash then deselect" bug).
    // `selectWord`/`selectParagraph`/`selectAllText` go through `applySelection`, which (unlike `setCaret`) did
    // not fire `onSelectionChange`. The chat composer tracks the editor selection through that hook; without it
    // a word selection never reaches the panel's interface state, and the next state re-apply (`setInputContent`)
    // collapses the visible selection back to the stale caret. (No-op in the article editor — no such round-trip.)
    func test_selectWord_firesOnSelectionChange() {
        let v = canvas()
        let r = region(v, "h")
        var fired = false
        v.onSelectionChange = { fired = true }
        v.selectWord(at: r.globalStart + 2)   // double-tap inside "Hello"
        XCTAssertTrue(fired, "a gesture word-selection must notify the host so the composer tracks the range")
    }
    func test_selectParagraph_firesOnSelectionChange() {
        let v = canvas()
        let r = region(v, "h")
        var fired = false
        v.onSelectionChange = { fired = true }
        v.selectParagraph(at: r.globalStart + 4)   // triple-tap
        XCTAssertTrue(fired, "a gesture paragraph-selection must notify the host")
    }
    func test_selectAllText_firesOnSelectionChange() {
        let v = canvas()
        var fired = false
        v.onSelectionChange = { fired = true }
        v.selectAllText()   // Select All menu / Cmd+A
        XCTAssertTrue(fired, "Select All must notify the host")
    }

    // MARK: Tap latency fix — manual multi-tap escalation (no `require(toFail:)` gate → instant caret).
    // handleTap counts taps itself with an injected timestamp, so caret/word/paragraph is deterministic.
    private func tapPoint(_ v: DocumentCanvasView, _ r: LeafTextRegion, offset: Int) -> CGPoint {
        let caret = v.caretRect(for: DocumentTextPosition(r.globalStart + offset))
        return CGPoint(x: caret.midX, y: caret.midY)
    }
    func test_handleTap_singleTap_placesCollapsedCaret() {
        let v = canvas()
        let r = region(v, "h")
        v.handleTap(at: tapPoint(v, r, offset: 2), time: 100)
        XCTAssertEqual(v.selFrom, v.selTo, "a single tap is a collapsed caret")
        XCTAssertGreaterThanOrEqual(v.selFrom, r.globalStart)
        XCTAssertLessThanOrEqual(v.selFrom, r.globalStart + r.length)
    }
    func test_handleTap_quickSecondTap_selectsWord() {
        let v = canvas()
        let r = region(v, "h")
        let p = tapPoint(v, r, offset: 2)
        v.handleTap(at: p, time: 100)
        v.handleTap(at: p, time: 100.1)   // within multiTapWindow, same point → escalate to word
        XCTAssertEqual(v.selFrom, r.globalStart, "the quick second tap selects the word 'Hello'")
        XCTAssertEqual(v.selTo, r.globalStart + 5)
    }
    func test_handleTap_slowSecondTap_isFreshCaretNotWord() {
        let v = canvas()
        let r = region(v, "h")
        let p = tapPoint(v, r, offset: 2)
        v.handleTap(at: p, time: 100)
        v.handleTap(at: p, time: 100 + DocumentCanvasView.multiTapWindow + 0.5)   // past the window
        XCTAssertEqual(v.selFrom, v.selTo, "a tap past the multi-tap window is a fresh caret, not a word")
    }
    func test_handleTap_tripleTap_selectsParagraph() {
        let v = canvas()
        let r = region(v, "h")
        let p = tapPoint(v, r, offset: 4)
        v.handleTap(at: p, time: 100)
        v.handleTap(at: p, time: 100.1)
        v.handleTap(at: p, time: 100.2)   // third quick tap → whole paragraph
        XCTAssertEqual(v.selFrom, r.globalStart)
        XCTAssertEqual(v.selTo, r.globalStart + r.length)
    }
    // MARK: Double-tap still selects a word even when the follow-up tap fires the near-cursor loupe.
    // The proximity-adaptive loupe delay is tiny (loupeDelayNearCursor) right on the just-placed caret, so the
    // 2nd tap of a double-tap fires the long-press instead of completing as a tap. `handleLoupeBegan` detects
    // the rapid repeat and escalates to a word/paragraph selection + menu (returning true so the caller
    // suppresses the loupe cursor-drag), reusing the same window/slop/tapCount state as `handleTap`.
    func test_loupeBegan_asDoubleTap_selectsWord_andReportsConsumed() {
        let v = canvas()
        _ = v.becomeFirstResponder()
        let r = region(v, "h")
        let p = tapPoint(v, r, offset: 2)                       // inside "Hello"
        v.handleTap(at: p, time: 100)                           // 1st tap → caret (stamps multi-tap state)
        let consumed = v.handleLoupeBegan(at: p, time: 100.1)   // 2nd "tap" arrives as a loupe .began
        XCTAssertTrue(consumed, "the repeat tap is consumed as a multi-tap so the loupe cursor-drag is suppressed")
        XCTAssertEqual(v.selFrom, r.globalStart, "double-tap selects the word 'Hello'")
        XCTAssertEqual(v.selTo, r.globalStart + 5)
    }
    func test_loupeBegan_thirdRepeat_selectsParagraph() {
        let v = canvas()
        _ = v.becomeFirstResponder()
        let r = region(v, "h")
        let p = tapPoint(v, r, offset: 4)
        v.handleTap(at: p, time: 100)                           // caret
        XCTAssertTrue(v.handleLoupeBegan(at: p, time: 100.1))   // → word
        XCTAssertTrue(v.handleLoupeBegan(at: p, time: 100.2))   // → whole paragraph
        XCTAssertEqual(v.selFrom, r.globalStart)
        XCTAssertEqual(v.selTo, r.globalStart + r.length)
    }
    func test_loupeBegan_lonePress_isNotConsumed() {
        // No recent tap ⇒ a genuine long-press ⇒ NOT a multi-tap ⇒ run the normal loupe (returns false).
        let v = canvas()
        _ = v.becomeFirstResponder()
        let r = region(v, "h")
        v.setCaret(global: r.globalStart)                       // caret far from the press point
        let consumed = v.handleLoupeBegan(at: tapPoint(v, r, offset: 9), time: 500)
        XCTAssertFalse(consumed, "a lone long-press is a normal loupe, not a double-tap")
    }
    func test_loupeBegan_slowSecondPress_isNotConsumed() {
        let v = canvas()
        _ = v.becomeFirstResponder()
        let r = region(v, "h")
        let p = tapPoint(v, r, offset: 2)
        v.handleTap(at: p, time: 100)
        let consumed = v.handleLoupeBegan(at: p, time: 100 + DocumentCanvasView.multiTapWindow + 0.5)
        XCTAssertFalse(consumed, "past the multi-tap window a press is a normal loupe, not a double-tap")
    }

    func test_selectAllText_selectsRenderableBounds() {
        let v = canvas()
        v.selectAllText()
        XCTAssertEqual(v.selFrom, (v.beginningOfDocument as! DocumentTextPosition).offset)
        XCTAssertEqual(v.selTo, (v.endOfDocument as! DocumentTextPosition).offset)
        XCTAssertLessThan(v.selFrom, v.selTo)
    }
    func test_selectWordParagraph_atImageGap_isNoOp() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 40, height: 40))),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let gap = v.boxes.first { $0 is MediaBlockBox }!.nodeStart
        v.setSelectionForTesting(anchor: gap, head: gap)
        v.selectWord(at: gap)
        XCTAssertEqual(v.selFrom, gap); XCTAssertEqual(v.selTo, gap)   // no word at a structural gap → unchanged
        v.selectParagraph(at: gap)
        XCTAssertEqual(v.selFrom, gap); XCTAssertEqual(v.selTo, gap)
    }

    func test_canPerformAction_select_onlyWhenCollapsedWithText() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 2, head: r.globalStart + 2)   // collapsed
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.select(_:)), withSender: nil))
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // selection
        XCTAssertFalse(v.canPerformAction(#selector(UIResponderStandardEditActions.select(_:)), withSender: nil))
    }
    func test_canPerformAction_select_disabledOnImageGap() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 40, height: 40))),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let gap = v.boxes.first { $0 is MediaBlockBox }!.nodeStart
        v.setSelectionForTesting(anchor: gap, head: gap)
        XCTAssertFalse(v.canPerformAction(#selector(UIResponderStandardEditActions.select(_:)), withSender: nil),
                       "Select is meaningless at an image gap (no word)")
    }
    func test_canPerformAction_selectAll_whenNotAllSelected() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 2)
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.selectAll(_:)), withSender: nil))
        v.selectAllText()
        XCTAssertFalse(v.canPerformAction(#selector(UIResponderStandardEditActions.selectAll(_:)), withSender: nil))
    }
    func test_selectAction_selectsWordAtCaret() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 8, head: r.globalStart + 8)   // inside "world"
        v.select(nil)
        XCTAssertEqual(v.selFrom, r.globalStart + 6)   // "world" starts after "Hello "
        XCTAssertEqual(v.selTo, r.globalStart + 11)
    }
    func test_selectAllText_emptyDocument_doesNotCrashAndCollapses() {
        let v = DocumentCanvasView()
        v.setBlocks([], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.selectAllText()
        XCTAssertEqual(v.selFrom, v.selTo)   // nothing renderable to select
    }

    func test_nearerSelectionEndpoint_picksByDistance() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 2, head: r.globalStart + 8)
        XCTAssertEqual(v.nearerSelectionEndpoint(toGlobal: r.globalStart + 7), .head)
        XCTAssertEqual(v.nearerSelectionEndpoint(toGlobal: r.globalStart + 3), .anchor)
    }
    func test_nearerSelectionEndpoint_nilWhenCollapsed() {
        let v = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 4, head: r.globalStart + 4)
        XCTAssertNil(v.nearerSelectionEndpoint(toGlobal: r.globalStart + 4))
    }
}
#endif

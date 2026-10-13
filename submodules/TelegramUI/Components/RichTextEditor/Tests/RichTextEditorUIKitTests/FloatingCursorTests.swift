#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class FloatingCursorTests: XCTestCase {
    /// Two short body paragraphs, laid out at 300×400, hosted inside a scroll view (so `viewportRect()`
    /// reads a real `UIScrollView`).
    func makeCanvas(_ texts: [String] = ["Alpha", "Bravo"]) -> (DocumentCanvasView, UIScrollView) {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        let v = DocumentCanvasView()
        v.setBlocks(texts.map { .paragraph(ParagraphBlock(id: BlockID($0), runs: [TextRun(text: $0)])) },
                    width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 800)
        scroll.addSubview(v)
        scroll.contentSize = v.frame.size
        v.layoutIfNeeded()
        return (v, scroll)
    }

    func test_caretHostPlacement_paragraph_isCanvasAndMatchesCaretFrame() {
        let (v, _) = makeCanvas()
        let mid = v.boxes[0].textStart + 2
        guard let placement = v.caretHostPlacement(forGlobal: mid) else {
            return XCTFail("a mid-paragraph position must be renderable")
        }
        XCTAssertTrue(placement.container === v, "a paragraph caret hosts on the canvas")
        XCTAssertEqual(placement.frame.width, 2, accuracy: 0.001, "caret bar is 2pt wide")
        XCTAssertGreaterThan(placement.frame.height, 0)
    }

    func test_caretHostPlacement_structuralSlot_isNil() {
        let (v, _) = makeCanvas()
        // Global 0 is the document's structural open-token slot (not a renderable caret slot).
        XCTAssertNil(v.caretHostPlacement(forGlobal: 0),
                     "a non-renderable structural slot has no caret placement")
    }

    func test_transientCaret_isSubviewOfCanvas_andThemed() {
        let (v, _) = makeCanvas()
        XCTAssertTrue(v.transientCaretView.superview === v, "transient caret is a canvas subview at rest")
        XCTAssertTrue(v.transientCaretView.isHidden, "transient caret is hidden at rest")
        v.applyTheme(.default)
        XCTAssertEqual(v.transientCaretView.accentColor, v.caretView.accentColor,
                       "transient caret shares the steady caret's themed accent")
    }

    func test_begin_collapsesRangedSelection() {
        let (v, _) = makeCanvas()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 1, head: v.boxes[0].textStart + 4)   // ranged
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(v.anchor, v.head, "begin collapses a ranged selection")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 4, "collapses to the old head")
        v.endFloatingCursor()
    }

    func test_update_pointBelow_movesToLowerParagraph() {
        // The point is an ABSOLUTE canvas coordinate (not a relative delta): a point below the upper
        // paragraph lands the caret in the lower one.
        let (v, _) = makeCanvas(["Alpha", "Bravo"])
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.beginFloatingCursor(at: CGPoint(x: 40, y: 20))
        v.updateFloatingCursor(at: CGPoint(x: 40, y: 140))
        XCTAssertGreaterThanOrEqual(v.head, v.boxes[1].textStart,
            "an absolute point below the upper paragraph lands the caret in the lower one")
        v.endFloatingCursor()
    }

    func test_update_pointAbove_movesToUpperParagraph() {
        let (v, _) = makeCanvas(["Alpha", "Bravo"])
        v.setCaret(global: v.boxes[1].textStart + 1)
        v.beginFloatingCursor(at: CGPoint(x: 40, y: 140))
        v.updateFloatingCursor(at: CGPoint(x: 40, y: 20))
        XCTAssertLessThanOrEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength,
            "an absolute point in the upper paragraph lands the caret there")
        v.endFloatingCursor()
    }

    func test_update_landsOnGraphemeBoundary_neverMidCluster() {
        // "👨‍👩‍👧‍👦" is a multi-UTF-16 ZWJ cluster; the caret must never land inside it.
        let (v, _) = makeCanvas(["👨‍👩‍👧‍👦X"])
        let p = v.boxes[0]
        v.setCaret(global: p.textStart)
        v.beginFloatingCursor(at: CGPoint(x: 0, y: 20))
        v.updateFloatingCursor(at: CGPoint(x: 6, y: 20))   // a few points right — inside the cluster glyph
        XCTAssertTrue(v.isRenderablePosition(v.head), "head is a renderable slot")
        XCTAssertTrue(v.head == p.textStart || v.head >= p.textStart + ("👨‍👩‍👧‍👦" as NSString).length,
            "head snaps to a grapheme boundary, never inside the emoji cluster")
        v.endFloatingCursor()
    }

    func test_update_bracketsInputDelegate() {
        let (v, _) = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart)
        let spy = InputDelegateSpy(); v.inputDelegate = spy
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 20))
        let beforeWill = spy.selectionWillChangeCount
        let beforeDid = spy.selectionDidChangeCount
        v.updateFloatingCursor(at: CGPoint(x: 60, y: 20))
        XCTAssertGreaterThan(spy.selectionWillChangeCount, beforeWill,
            "each update brackets the input delegate (selectionWillChange)")
        XCTAssertGreaterThan(spy.selectionDidChangeCount, beforeDid,
            "each update brackets the input delegate (selectionDidChange)")
        v.endFloatingCursor()
    }

    func test_perUpdate_doesNotFireOnSelectionChange_endFiresOnce() {
        let (v, _) = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart)
        var fired = 0
        v.onSelectionChange = { fired += 1 }
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 20))
        v.updateFloatingCursor(at: CGPoint(x: 30, y: 20))
        v.updateFloatingCursor(at: CGPoint(x: 50, y: 20))
        XCTAssertEqual(fired, 0, "begin/update suppress the host scroll-follow hook")
        v.endFloatingCursor()
        XCTAssertEqual(fired, 1, "end fires onSelectionChange exactly once")
    }

    func test_end_leavesCaretAtLandingPosition() {
        let (v, _) = makeCanvas(["Alpha", "Bravo"])
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.beginFloatingCursor(at: CGPoint(x: 40, y: 20))
        v.updateFloatingCursor(at: CGPoint(x: 40, y: 140))
        let landed = v.head
        v.endFloatingCursor()
        XCTAssertFalse(v.floatingCursorActive)
        let range = v.selectedTextRange as? DocumentTextRange
        XCTAssertEqual(range?.from.offset, landed)
        XCTAssertEqual(range?.to.offset, landed)
    }

    func test_autoScrollStep_zeroInMiddle_signedNearEdges() {
        let (v, _) = makeCanvas()
        let h: CGFloat = 400, band: CGFloat = 60
        XCTAssertEqual(v.floatingAutoScrollStep(forViewportY: 200, viewportHeight: h, band: band), 0,
                       accuracy: 0.001, "no scroll in the middle")
        XCTAssertLessThan(v.floatingAutoScrollStep(forViewportY: 10, viewportHeight: h, band: band), 0,
                          "near the top scrolls up (negative)")
        XCTAssertGreaterThan(v.floatingAutoScrollStep(forViewportY: 390, viewportHeight: h, band: band), 0,
                             "near the bottom scrolls down (positive)")
        // Magnitude grows toward the very edge.
        XCTAssertGreaterThan(abs(v.floatingAutoScrollStep(forViewportY: 1, viewportHeight: h, band: band)),
                             abs(v.floatingAutoScrollStep(forViewportY: 50, viewportHeight: h, band: band)))
    }

    /// `@MainActor` (and only this case in the suite) because it SEEDS backend-owned state through the
    /// `RichTextInputBackend` contract, which is `@MainActor`-isolated; the two properties it used to
    /// write directly were plain canvas fields until Task 42.
    @MainActor
    func test_autoScrollTick_advancesOffsetAndResnaps() {
        // Tall content so there is room to scroll; caret pinned near the bottom edge.
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let v = DocumentCanvasView()
        v.setBlocks((0..<40).map { .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")])) },
                    width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 1600)
        scroll.addSubview(v); scroll.contentSize = v.frame.size; v.layoutIfNeeded()
        v.setCaret(global: v.boxes[0].textStart)
        v.beginFloatingCursor(at: CGPoint(x: 40, y: 20))
        // TASK 42 — the two properties moved to the backend and the canvas keeps read-only projections,
        // so a test that SEEDS them writes through the same doors the canvas bodies use.
        v.inputBackend.setFloatingCursorPoint(CGPoint(x: 40, y: 190))   // in the bottom band
        v.inputBackend.setFloatingScrollVelocity(12)
        let beforeY = scroll.contentOffset.y
        let beforeHead = v.head
        v.floatingAutoScrollTick()
        XCTAssertGreaterThan(scroll.contentOffset.y, beforeY, "tick advances the document scroll")
        XCTAssertNotEqual(v.head, beforeHead, "tick re-snaps the caret against the new offset")
        v.endFloatingCursor()
    }

    func test_resignFirstResponder_cancelsFloatingCursor() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let scroll = UIScrollView(frame: window.bounds)
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Alpha")]))], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        scroll.addSubview(v); scroll.contentSize = v.frame.size
        window.addSubview(scroll); window.makeKeyAndVisible()
        v.layoutIfNeeded()
        guard v.becomeFirstResponder() else { return XCTFail("canvas must become first responder") }
        v.beginFloatingCursor(at: CGPoint(x: 40, y: 20))
        XCTAssertTrue(v.floatingCursorActive)
        _ = v.resignFirstResponder()
        XCTAssertFalse(v.floatingCursorActive, "resigning first responder must cancel an in-flight floating cursor")
        XCTAssertTrue(v.transientCaretView.isHidden, "transient caret hidden after cancel")
    }

    func test_selectedTextRange_ignoredDuringFloatingCursor() {
        // iOS drives the gesture by pushing selection RANGES through the selectedTextRange setter; applying
        // them would turn the cursor MOVE into a text SELECTION. They must be ignored while the gesture owns
        // the caret (the runtime selection bug).
        let (v, _) = makeCanvas(["Hello world"])
        v.setCaret(global: v.boxes[0].textStart + 2)
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        let head0 = v.head
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart),
                                                DocumentTextPosition(v.boxes[0].textStart + 4))   // a RANGE
        XCTAssertEqual(v.anchor, v.head, "selection stays collapsed during the gesture (the range write is ignored)")
        XCTAssertEqual(v.head, head0, "the OS range write does not move the caret")
        v.endFloatingCursor()
        // After the gesture the setter works normally again.
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart),
                                                DocumentTextPosition(v.boxes[0].textStart + 3))
        XCTAssertEqual(v.selFrom, v.boxes[0].textStart)
        XCTAssertEqual(v.selTo, v.boxes[0].textStart + 3, "the setter applies ranges again once the gesture ends")
    }

    func test_update_shadowGlidesToContinuousX_notSnapped() {
        let (v, _) = makeCanvas(["Hello world"])
        v.setCaret(global: v.boxes[0].textStart)
        v.beginFloatingCursor(at: CGPoint(x: 0, y: 12))
        let fingerX: CGFloat = 33.3   // a non-character-boundary x
        v.updateFloatingCursor(at: CGPoint(x: fingerX, y: 12))
        XCTAssertEqual(v.transientCaretView.frame.minX, fingerX, accuracy: 0.5,
            "the shadow glides to the continuous finger x, not a snapped caret rect")
        v.endFloatingCursor()
    }

    func test_update_reachesDocumentStart_noViewportClamp() {
        // An overshooting-left point must reach the document start (the old viewport clamp froze it mid-text).
        let (v, _) = makeCanvas(["Hello world"])
        v.setCaret(global: v.boxes[0].textStart + 5)
        v.beginFloatingCursor(at: CGPoint(x: 60, y: 12))
        v.updateFloatingCursor(at: CGPoint(x: -50, y: 12))
        XCTAssertEqual(v.head, v.boxes[0].textStart, "an overshooting-left point reaches the document start")
        v.endFloatingCursor()
    }

    func test_steadyCaret_isDimmedLandingDuringGesture() {
        // The steady caret stays visible (dimmed) at the SNAPPED position as the landing indicator; the
        // bright shadow glides separately. caretView visibility requires first responder.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let scroll = UIScrollView(frame: window.bounds)
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello world")]))], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        scroll.addSubview(v); scroll.contentSize = v.frame.size
        window.addSubview(scroll); window.makeKeyAndVisible()
        v.layoutIfNeeded()
        guard v.becomeFirstResponder() else { return XCTFail("canvas must become first responder") }
        v.setCaret(global: v.boxes[0].textStart + 2)
        v.beginFloatingCursor(at: CGPoint(x: 20, y: 12))
        v.updateFloatingCursor(at: CGPoint(x: 50, y: 12))
        XCTAssertFalse(v.caretView.isHidden, "steady caret stays visible as the landing indicator")
        XCTAssertEqual(v.caretView.alpha, 0.4, accuracy: 0.001, "landing caret is dimmed during the gesture")
        v.endFloatingCursor()
        XCTAssertEqual(v.caretView.alpha, 1, accuracy: 0.001, "steady caret restored to full opacity after the gesture")
    }
}
#endif

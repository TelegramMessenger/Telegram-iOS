#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// willMove(toWindow: nil) (DCV:1163-1169) is the ONLY teardown for the two CADisplayLinks. It had
/// no test at all before this suite; a routing refactor can reintroduce a display-link retain cycle
/// with an otherwise fully green suite.
@available(iOS 16.0, *)
final class WindowDetachCharacterizationTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    private func hostedCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        window.addSubview(v); v.layoutIfNeeded()
        return v
    }

    /// Tall content inside a short scroll view (mirrors `SelectionInteractionTests.tallCanvasInScroll`) so a
    /// drag point in the viewport's bottom band genuinely starts `dragAutoScrollLink` — the vertical branch of
    /// `updateDragAutoScroll` only fires when `superview is UIScrollView`.
    private func hostedCanvasInScroll() -> (canvas: DocumentCanvasView, scroll: UIScrollView) {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        // Real production code sets this (`RichTextEditorView` — see the package's own CLAUDE.md), and it
        // matters here too: a scroll view added to a REAL, key window otherwise auto-adjusts its resting
        // `contentOffset` to the negative safe-area inset, which silently throws off every hardcoded
        // viewport-band coordinate below (discovered the hard way — see the floating-cursor test).
        scroll.contentInsetAdjustmentBehavior = .never
        let v = DocumentCanvasView()
        v.setBlocks((0..<40).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 1600)
        scroll.addSubview(v); scroll.contentSize = v.frame.size
        window.addSubview(scroll)
        v.layoutIfNeeded()
        return (v, scroll)
    }

    func test_removalFromWindow_cancelsAnActiveFloatingCursor() {
        let v = hostedCanvas()
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        XCTAssertTrue(v.floatingCursorActive)
        v.removeFromSuperview()
        XCTAssertFalse(v.floatingCursorActive)
    }

    /// `beginFloatingCursor` alone never touches `floatingScrollLink` — it is created only inside
    /// `updateFloatingAutoScroll`, reached from `updateFloatingCursor(at:)` when the point falls in the 60pt
    /// edge band. `hostedCanvas()`'s plain `window.addSubview(v)` host has no scroll-view superview, so
    /// `viewportRect()` falls back to `bounds` (300×300) — `y: 5` is well inside the top band.
    func test_removalFromWindow_tearsDownTheFloatingScrollLink() {
        let v = hostedCanvas()
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        v.updateFloatingCursor(at: CGPoint(x: 150, y: 5))   // inside the top auto-scroll band -> starts the link
        XCTAssertNotNil(v.floatingScrollLink, "precondition: the floating auto-scroll link actually started")
        v.removeFromSuperview()
        // `willMove(toWindow: nil)` calls `cancelFloatingCursor()` directly, which calls
        // `stopFloatingAutoScroll()` UNCONDITIONALLY (before the `floatingCursorActive` guard) — so, unlike
        // `resignFirstResponder` (which leaves other things alive per D18), window removal DOES tear this down.
        XCTAssertNil(v.floatingScrollLink, "willMove(toWindow: nil) invalidates this link via cancelFloatingCursor()")
    }

    /// `updateDragAutoScroll(point:headInTable:)` is internal, so the vertical auto-scroll link can be started
    /// directly under `@testable import` without a real drag gesture.
    func test_removalFromWindow_tearsDownDragAutoScroll() {
        let (v, scroll) = hostedCanvasInScroll()
        let bottomBand = CGPoint(x: 40, y: scroll.contentOffset.y + 190)   // viewport bottom band (band = 60 of 200pt)
        v.updateDragAutoScroll(point: bottomBand, headInTable: false)
        XCTAssertNotNil(v.dragAutoScrollLink, "precondition: the drag auto-scroll link actually started")
        v.removeFromSuperview()
        // `willMove(toWindow: nil)` calls `stopDragAutoScroll()` directly — so, unlike `resignFirstResponder`
        // (which D18 lists as leaving this link alive), window removal DOES tear it down.
        XCTAssertNil(v.dragAutoScrollLink, "willMove(toWindow: nil) invalidates this link via stopDragAutoScroll()")
    }

    func test_canvasIsDeallocatedAfterWindowRemoval() {
        weak var probe: DocumentCanvasView?
        autoreleasepool {
            let (v, scroll) = hostedCanvasInScroll()
            probe = v
            // Start BOTH display links before dropping the strong reference, so this actually exercises the
            // retain-cycle path the comment above describes (a stubbed-out link would keep `v` alive forever).
            v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
            v.updateFloatingCursor(at: CGPoint(x: 150, y: 5))
            v.updateDragAutoScroll(point: CGPoint(x: 40, y: scroll.contentOffset.y + 190), headInTable: false)
            XCTAssertNotNil(v.floatingScrollLink, "precondition: floating auto-scroll link")
            XCTAssertNotNil(v.dragAutoScrollLink, "precondition: drag auto-scroll link")
            v.removeFromSuperview()
        }
        XCTAssertNil(probe, "a retained display link or interaction would keep the canvas alive")
    }

    func test_removalFromWindow_doesNotChangeTheSelection() {
        let v = hostedCanvas()
        v.setCaret(global: v.boxes[0].textStart + 3)
        let (a, h) = (v.anchor, v.head)
        v.removeFromSuperview()
        XCTAssertEqual(v.anchor, a); XCTAssertEqual(v.head, h)
    }
}
#endif

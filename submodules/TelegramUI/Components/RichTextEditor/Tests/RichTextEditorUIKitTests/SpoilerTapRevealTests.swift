#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SpoilerTapRevealTests: XCTestCase {
    private func canvasWithSpoiler() -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "open secret end")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        c.simulateParentLayout()
        let start = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: start + 5, head: start + 11)
        c.toggleSpoiler()
        c.setSelectionForTesting(anchor: start, head: start)
        c.layoutIfNeeded()
        return c
    }

    func test_tapOnHiddenSpoiler_revealsAndPlacesCaretInside_andSetsHint() {
        let c = canvasWithSpoiler()
        let run = c.spoilerRunsForTesting[0]
        // Hold a strong reference to the dust view before the tap: the reconcile calls `dissolve(explodingAt:)`
        // and removes it from the superview. `wasExploded` (set synchronously in `dissolve` when the point is
        // non-nil) is the observable side-effect of the tap-to-reveal branch setting `spoilerRevealHint`.
        // The normal tap path passes nil → no explosion → `wasExploded` stays false.
        let dustView = c.firstSpoilerDustForTesting as? SpoilerDustView
        let p = run.canvasLineRects[0].center   // a point over the dust
        c.handleTap(at: p, time: 1000)
        XCTAssertTrue(c.head >= run.globalRange.lowerBound && c.head <= run.globalRange.upperBound,
                      "caret landed inside the spoiler")
        // The interception branch sets `spoilerRevealHint` before calling `setCaret`; the hint is consumed
        // inside `syncSpoilers` which calls `dissolve(explodingAt: viewLocalPoint)` → `wasExploded = true`.
        // Without the branch the hint is nil → `dissolve(explodingAt: nil)` → `wasExploded` stays false.
        XCTAssertEqual(dustView?.wasExploded, true, "tap-to-reveal branch must trigger the explosion dissolve (non-nil point)")
        c.layoutIfNeeded()
        XCTAssertFalse(c.spoilerRunsForTesting[0].hidden, "the tapped spoiler is now revealed")
    }

    func test_tapOnRevealedSpoiler_isNotIntercepted() {
        let c = canvasWithSpoiler()
        let start = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: start + 7, head: start + 7)   // reveal it first
        c.refreshSelectionUI()
        XCTAssertNil(c.hiddenSpoilerRun(at: c.spoilerRunsForTesting[0].canvasLineRects[0].center),
                     "a revealed spoiler is not a hidden hit-test target")
    }
}

private extension CGRect { var center: CGPoint { CGPoint(x: midX, y: midY) } }
#endif

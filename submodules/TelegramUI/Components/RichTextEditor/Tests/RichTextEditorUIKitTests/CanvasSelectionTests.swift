#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasSelectionTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
            ParagraphBlock(id: BlockID("c"), runs: [TextRun(text: "Gamma")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 240); v.layoutIfNeeded()
        return v
    }

    func test_crossBlockSelection_producesRectsFromEachCoveredBlock() {
        let v = canvas()
        // From inside Alpha to inside Gamma → rects in all three boxes.
        let rects = v.selectionRects(globalFrom: v.boxes[0].textStart + 2,
                                     globalTo: v.boxes[2].textStart + 2)
        func count(in box: CanvasBlock) -> Int { rects.filter { box.frame.intersects($0) }.count }
        XCTAssertGreaterThan(count(in: v.boxes[0]), 0)
        XCTAssertGreaterThan(count(in: v.boxes[1]), 0)   // fully-covered middle block
        XCTAssertGreaterThan(count(in: v.boxes[2]), 0)
    }

    func test_closestGlobalPosition_landsInVerticallyHitBlock() {
        let v = canvas()
        let pInB = v.closestGlobalPosition(to: CGPoint(x: 5, y: v.boxes[1].frame.midY))
        let (box, _) = v.box(containingGlobal: pInB)!
        XCTAssertEqual(box.id, BlockID("b"))
    }
}
#endif

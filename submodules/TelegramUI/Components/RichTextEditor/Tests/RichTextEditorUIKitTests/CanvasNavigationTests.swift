#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasNavigationTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200); v.layoutIfNeeded()
        return v
    }

    func test_rightAtBlockEnd_jumpsToNextBlockStart() {
        let v = canvas()
        let endOfA = v.boxes[0].textStart + v.boxes[0].textLength
        let next = (v.position(from: DocumentTextPosition(endOfA), in: .right, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(next, v.boxes[1].textStart)
    }

    func test_leftAtBlockStart_jumpsToPrevBlockEnd() {
        let v = canvas()
        let prev = (v.position(from: DocumentTextPosition(v.boxes[1].textStart), in: .left, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(prev, v.boxes[0].textStart + v.boxes[0].textLength)
    }

    func test_downFromFirstBlock_landsInSecondBlock() {
        let v = canvas()
        let down = (v.position(from: DocumentTextPosition(v.boxes[0].textStart + 1), in: .down, offset: 1) as! DocumentTextPosition).offset
        XCTAssertNotNil(v.box(containingGlobal: down))
        XCTAssertEqual(v.box(containingGlobal: down)!.box.id, BlockID("b"))
    }

    func test_toggleBold_overSelectionInABlock() {
        let v = canvas()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 5)
        v.toggleBold()
        XCTAssertTrue((v.boxes[0] as! BlockBox).currentParagraph().runs.allSatisfy { $0.attributes.bold })
    }
}
#endif

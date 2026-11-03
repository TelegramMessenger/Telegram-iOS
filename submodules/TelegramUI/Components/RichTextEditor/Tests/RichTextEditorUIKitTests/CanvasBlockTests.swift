#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasBlockTests: XCTestCase {
    func test_blockBox_conformsToCanvasBlock_withParagraphTokenMath() {
        let p = ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")])
        let box: CanvasBlock = BlockBox(paragraph: p, mapper: AttributedStringMapper(), width: 300)
        box.nodeStart = 1
        XCTAssertEqual(box.textLength, 5)
        XCTAssertEqual(box.nodeSize, 7)          // textLength + 2
        XCTAssertEqual(box.textStart, 1)         // == nodeStart for a paragraph
        XCTAssertEqual(box.textRef, .paragraph(BlockID("p")))
        guard case .paragraph(let out) = box.currentBlock() else { return XCTFail("expected paragraph") }
        XCTAssertEqual(out.runs.map(\.text).joined(), "Hello")
    }
}
#endif

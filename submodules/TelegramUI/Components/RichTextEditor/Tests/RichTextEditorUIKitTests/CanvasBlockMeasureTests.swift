#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class CanvasBlockMeasureTests: XCTestCase {
    private let mapper = AttributedStringMapper()
    private let longText = "A reasonably long paragraph that wraps onto several lines at narrow widths so its height changes."

    // measuredHeight at a box's CURRENT width equals its live height; at another width it equals a
    // box freshly laid out there. Insets are structural (width-independent), so reading them is correct.
    func test_blockBox_measuredHeight_parity() {
        let p = ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: longText)])
        let a = BlockBox(paragraph: p, mapper: mapper, width: 300)
        let b = BlockBox(paragraph: p, mapper: mapper, width: 140)
        BlockStack(boxes: [a]).layout(origin: .zero, width: 300)
        BlockStack(boxes: [b]).layout(origin: .zero, width: 140)
        XCTAssertEqual(a.measuredHeight(forWidth: 300), a.height, accuracy: 0.5)
        XCTAssertEqual(a.measuredHeight(forWidth: 140), b.height, accuracy: 0.5)
    }

    func test_blockBox_measuredHeight_doesNotMutate() {
        let a = BlockBox(paragraph: ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: longText)]), mapper: mapper, width: 300)
        BlockStack(boxes: [a]).layout(origin: .zero, width: 300)
        let before = a.height
        _ = a.measuredHeight(forWidth: 90)
        XCTAssertEqual(a.height, before, accuracy: 0.001)
        XCTAssertEqual(a.frame.width, 300, accuracy: 0.001)
    }

    func test_codeBlock_measuredHeight_parity() {
        let c = CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x = compute(a, b, c, d, e, f, g, h, i, j, k, l, m)")])
        let a = CodeBlockBox(code: c, mapper: mapper, width: 300)
        let b = CodeBlockBox(code: c, mapper: mapper, width: 140)
        BlockStack(boxes: [a]).layout(origin: .zero, width: 300)
        BlockStack(boxes: [b]).layout(origin: .zero, width: 140)
        XCTAssertEqual(a.measuredHeight(forWidth: 300), a.height, accuracy: 0.5)
        XCTAssertEqual(a.measuredHeight(forWidth: 140), b.height, accuracy: 0.5)
    }

    func test_mediaBlock_measuredHeight_parity() {
        let m = MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 400, height: 300))
        let a = MediaBlockBox(media: m, mapper: mapper, width: 300)
        let b = MediaBlockBox(media: m, mapper: mapper, width: 140)
        BlockStack(boxes: [a]).layout(origin: .zero, width: 300)
        BlockStack(boxes: [b]).layout(origin: .zero, width: 140)
        XCTAssertEqual(a.measuredHeight(forWidth: 300), a.height, accuracy: 0.5)
        XCTAssertEqual(a.measuredHeight(forWidth: 140), b.height, accuracy: 0.5)
    }

    func test_stack_measuredHeight_sumsBoxes() {
        let boxes: [CanvasBlock] = [
            BlockBox(paragraph: ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: longText)]), mapper: mapper, width: 300),
            BlockBox(paragraph: ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Short")]), mapper: mapper, width: 300),
        ]
        let stack = BlockStack(boxes: boxes)
        stack.layout(origin: .zero, width: 300)
        XCTAssertEqual(stack.measuredHeight(forWidth: 300), boxes.reduce(0) { $0 + $1.height }, accuracy: 0.5)
    }
}
#endif

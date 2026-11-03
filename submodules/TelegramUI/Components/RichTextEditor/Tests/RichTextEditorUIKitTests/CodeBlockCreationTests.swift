#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

@available(iOS 13.0, *)
final class CodeBlockCreationTests: XCTestCase {
    func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView(); c.setBlocks(blocks, width: 320); return c
    }

    func test_makeCodeBlock_convertsSelectedParagraphsToOneCodeBlock() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "line1")])),
            .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [TextRun(text: "line2")])),
        ])
        canvas.setSelectionAnchor(global: 0)
        canvas.setSelectionHead(global: canvas.documentSize)   // both paragraphs
        canvas.makeCodeBlock()
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "line1\nline2")
    }

    func test_makeCodeBlock_togglesOffBackToParagraphs() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "a\nb")]))])
        canvas.setSelectionAnchor(global: 0)
        canvas.setSelectionHead(global: canvas.documentSize)
        canvas.makeCodeBlock()                               // toggle off → body paragraphs
        XCTAssertEqual(canvas.boxes.count, 2)
        XCTAssertTrue(canvas.boxes.allSatisfy {
            if case .paragraph = $0.currentBlock() { return true }; return false
        })
    }

    func test_makeCodeBlock_mergingParagraphAndCodePreservesCodeText() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "a")])),
            .code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "b\nc")])),
        ])
        canvas.setSelectionAnchor(global: 0)
        canvas.setSelectionHead(global: canvas.documentSize)
        canvas.makeCodeBlock()
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "a\nb\nc")    // the existing code text is preserved, not dropped
    }
}
#endif

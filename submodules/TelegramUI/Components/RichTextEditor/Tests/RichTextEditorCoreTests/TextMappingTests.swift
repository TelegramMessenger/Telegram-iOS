import XCTest
@testable import RichTextEditorCore

final class TextMappingTests: XCTestCase {
    private func tree() -> DocNode {
        DocumentTree.build(from: Document(
            blocks: [
                .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "One")])),
                .media(MediaBlock(id: BlockID("i1"), mediaID: "a",
                                  naturalSize: Size2D(width: 1, height: 1),
                                  caption: [TextRun(text: "Hi")])),
            ]))
    }

    func test_textPosition_insideParagraph() {
        let t = PositionResolver.textPosition(at: 3, in: tree())   // after 'n' in "One"
        XCTAssertEqual(t?.ref, .paragraph(BlockID("p1")))
        XCTAssertEqual(t?.offset, 2)
    }

    func test_textPosition_insideCaption() {
        let t = PositionResolver.textPosition(at: 8, in: tree())   // before 'H' in caption "Hi"
        XCTAssertEqual(t?.ref, .caption(BlockID("i1")))
        XCTAssertEqual(t?.offset, 0)
    }

    func test_textPosition_atTopLevelBoundary_isNil() {
        XCTAssertNil(PositionResolver.textPosition(at: 5, in: tree()))  // between blocks
    }

    func test_globalPosition_isInverseOfTextPosition() {
        let tree = tree()
        for pos in [1, 2, 3, 4, 9, 10, 11] {   // positions inside text nodes
            if let t = PositionResolver.textPosition(at: pos, in: tree) {
                XCTAssertEqual(PositionResolver.globalPosition(of: t.ref, offset: t.offset, in: tree), pos)
            }
        }
    }
}

import XCTest
import RichTextEditorCore   // NOT @testable — verifies the public surface

final class PublicAPISmokeTests: XCTestCase {
    func test_buildSerializeResolveSelect_endToEnd() throws {
        let doc = Document(
            blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Hello")]))])

        let data = try DocumentCodec.encode(doc)
        XCTAssertEqual(try DocumentCodec.decode(data), doc)

        let tree = DocumentTree.build(from: doc)
        XCTAssertEqual(tree.nodeSize, 7)   // "Hello"(5) + 2
        let r = PositionResolver.resolve(3, in: tree)
        XCTAssertEqual(r.depth, 1)

        let sel = RTSelection.range(anchor: 1, head: 6)
        XCTAssertEqual(sel.from, 1); XCTAssertEqual(sel.to, 6)
    }
}

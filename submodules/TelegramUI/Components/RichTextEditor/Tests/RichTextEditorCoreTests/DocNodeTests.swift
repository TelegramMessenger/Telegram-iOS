import XCTest
@testable import RichTextEditorCore

final class DocNodeTests: XCTestCase {
    func test_textNode_sizeIsTextLength() {
        XCTAssertEqual(DocNode.text(length: 4, ref: .paragraph(BlockID("p"))).nodeSize, 4)
    }

    func test_paragraphNode_sizeIsTextPlusTwo() {
        let p = DocumentTree.build(from: Document(
            blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Hi!")]))]))
        // doc content = one paragraph of "Hi!" (3) → paragraph size 5, doc size 5
        XCTAssertEqual(p.nodeSize, 5)               // doc content size (no +2 on doc)
        XCTAssertEqual(p.children.count, 1)
        XCTAssertEqual(p.children[0].nodeSize, 5)   // the paragraph node
    }

    func test_mediaBlock_sizeIsAtomPlusCaptionParagraphPlusTwo() {
        // media atom (1) + caption paragraph("ab" → 2 → +2 = 4) = content 5 → mediaBlock 7
        let doc = Document(
            blocks: [.media(MediaBlock(id: BlockID("i1"), mediaID: "a",
                                       naturalSize: Size2D(width: 1, height: 1),
                                       caption: [TextRun(text: "ab")]))])
        let root = DocumentTree.build(from: doc)
        XCTAssertEqual(root.nodeSize, 7)            // doc content
        XCTAssertEqual(root.children[0].nodeSize, 7)
    }

    func test_table_walksRowMajor_andSizesNest() {
        // 1x2 table; each cell has an empty paragraph (size 2).
        // cell = content(2) + 2 = 4; row = (4+4) + 2 = 10; table = 10 + 2 = 12
        let cell = { (id: String) in
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p")))]) }
        let doc = Document(
            blocks: [.table(TableBlock(id: BlockID("t1"),
                columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
                rows: [Row(id: BlockID("r1"), cells: [cell("c1"), cell("c2")])]))])
        let root = DocumentTree.build(from: doc)
        XCTAssertEqual(root.children[0].nodeSize, 12)
    }

    func test_detailsNode_recursesLikeContainer() {
        // A .details node with two children paragraphs "ab"(2→4) + "c"(1→3): container = 4+3+2 = 9
        let n = DocNode.details(id: BlockID("d"), children: [
            .paragraph(id: BlockID("t"), children: [.text(length: 2, ref: .detailsTitle(BlockID("d")))]),
            .paragraph(id: BlockID("b"), children: [.text(length: 1, ref: .paragraph(BlockID("b")))]),
        ])
        XCTAssertEqual(n.nodeSize, 9)
        XCTAssertEqual(n.children.count, 2)
    }
}

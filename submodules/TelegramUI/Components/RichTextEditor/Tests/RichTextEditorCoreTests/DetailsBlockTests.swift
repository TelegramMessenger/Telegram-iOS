import XCTest
@testable import RichTextEditorCore

final class DetailsBlockTests: XCTestCase {
    func test_details_recursiveCodableRoundTrip() throws {
        let inner = DetailsBlock(id: BlockID("inner"),
                                 title: [TextRun(text: "Inner")],
                                 children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")]))],
                                 expanded: false)
        let outer = Block.details(DetailsBlock(id: BlockID("outer"),
                                               title: [TextRun(text: "Outer")],
                                               children: [.details(inner)],
                                               expanded: true))
        let data = try JSONEncoder().encode(outer)
        XCTAssertEqual(try JSONDecoder().decode(Block.self, from: data), outer)   // nesting + title + expanded survive
    }

    func test_details_titleDefaultsEmpty_andCounts() {
        XCTAssertEqual(DetailsBlock(id: BlockID("d")).title, [])
        XCTAssertEqual(DetailsBlock(id: BlockID("d")).children, [])
        XCTAssertTrue(DetailsBlock(id: BlockID("d")).expanded)   // defaults expanded
        XCTAssertEqual(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "ab")]).titleUTF16Count, 2)
    }

    func test_details_blockIdArm() {
        XCTAssertEqual(Block.details(DetailsBlock(id: BlockID("d"))).id, BlockID("d"))
    }

    func test_documentTree_detailsNodeSize_expandedVsFolded() {
        // title "T"(1)→ titlePara 3; body paragraph "ab"(2)→ 4; container +2
        let body = Block.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "ab")]))
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: [body], expanded: true)
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.details(d)])), 9)   // 3 + 4 + 2
        var folded = d; folded.expanded = false
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.details(folded)])), 5)   // 3 + 2 (body off-axis)
    }

    func test_documentTree_details_titleAlwaysPresent_evenEmpty() {
        // empty title (0)→ titlePara 2; empty body paragraph (0)→ 2; container +2 = 6
        let emptyBody = Block.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: []))
        let d = DetailsBlock(id: BlockID("d"), title: [], children: [emptyBody], expanded: true)
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.details(d)])), 6)
    }

    func test_details_regeneratesIdsRecursively_andPlainText() {
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "Sum")],
                             children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))],
                             expanded: true)
        XCTAssertEqual(blockPlainText(.details(d)), "Sum\nhi")   // title then body
        let regen = Document(blocks: [.details(d)]).regeneratingTopLevelIDs()
        guard case .details(let r) = regen.blocks[0] else { return XCTFail() }
        XCTAssertNotEqual(r.id, d.id)                            // top-level id regenerated
        guard case .paragraph(let rp) = r.children[0] else { return XCTFail() }
        XCTAssertNotEqual(rp.id, BlockID("p"))                   // child ids regenerated too
        XCTAssertEqual(r.title, d.title)                         // title preserved
    }
}

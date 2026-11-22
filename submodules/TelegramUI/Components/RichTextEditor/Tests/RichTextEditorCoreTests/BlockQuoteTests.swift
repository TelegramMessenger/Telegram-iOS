import XCTest
@testable import RichTextEditorCore
final class BlockQuoteTests: XCTestCase {
    func test_blockQuote_recursiveCodableRoundTrip() throws {
        let inner = BlockQuote(id: BlockID("inner"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")]))], collapsed: false)
        let outer = Block.blockQuote(BlockQuote(id: BlockID("outer"), children: [.blockQuote(inner)], collapsed: true))
        let data = try JSONEncoder().encode(outer)
        XCTAssertEqual(try JSONDecoder().decode(Block.self, from: data), outer)   // nesting + collapsed survive
    }

    func test_documentTree_blockQuoteNodeSize_expandedVsCollapsed() {
        // expanded quote holding one paragraph "ab" (utf16 2): text 2 + paragraph wrapper 2 = 4; + empty author
        // region (0 + 2 authorPara) = 2; quote wrapper +2 = 8 — the always-present empty author region adds +2
        // over the pre-author-region shape (was 6).
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))], collapsed: false)
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.blockQuote(bq)])), 8)
        var c = bq; c.collapsed = true
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.blockQuote(c)])), 3)   // folded → atom
    }

    func test_blockQuote_author_roundTripsAndDefaultsEmpty() throws {
        let bq = BlockQuote(id: BlockID("q"),
                            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))],
                            collapsed: false,
                            author: [TextRun(text: "Author")])
        let data = try JSONEncoder().encode(Block.blockQuote(bq))
        XCTAssertEqual(try JSONDecoder().decode(Block.self, from: data), .blockQuote(bq))
        XCTAssertEqual(BlockQuote(id: BlockID("q")).author, [])
    }

    func test_documentTree_blockQuoteNodeSize_withAuthorRegion() {
        // one paragraph "ab" (text 2 + para 2 = 4) + author "X" (1 + authorPara 2 = 3) + container 2 = 9
        let bq = BlockQuote(id: BlockID("q"),
                            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))],
                            collapsed: false,
                            author: [TextRun(text: "X")])
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.blockQuote(bq)])), 9)
        // Collapsed quote is unchanged (atom, nodeSize 3) — author held in model, off the position axis.
        var c = bq; c.collapsed = true
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.blockQuote(c)])), 3)
    }

    private func bqDoc(_ children: [Block], author: [TextRun] = []) -> Document {
        Document(blocks: [.blockQuote(BlockQuote(id: BlockID("q"), children: children, collapsed: false, author: author))])
    }

    func test_documentTree_blockQuote_authorConditional() {
        // Empty body (single empty paragraph) + empty author → NO author paragraph.
        // child emptyPara: text 0 + para 2 = 2; container +2 = 4.
        let emptyPara = Block.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: []))
        XCTAssertEqual(DocumentTree.documentSize(bqDoc([emptyPara])), 4)
        // Body has text → author paragraph reserved (empty author): child "ab"(2+2=4) + authorPara 2 + container 2 = 8.
        let textPara = Block.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))
        XCTAssertEqual(DocumentTree.documentSize(bqDoc([textPara])), 8)
        // Author text, empty body → author paragraph present: emptyPara(2) + authorPara "X"(1+2=3) + container 2 = 7.
        XCTAssertEqual(DocumentTree.documentSize(bqDoc([emptyPara], author: [TextRun(text: "X")])), 7)
        // Empty sub-quote child (a text-less structural block) → counts as content → author paragraph reserved.
        // inner empty quote: emptyPara(2) + container 2 = 4; outer: inner(4) + authorPara(2) + container 2 = 8.
        let emptySubQuote = Block.blockQuote(BlockQuote(id: BlockID("inner"),
            children: [.paragraph(ParagraphBlock(id: BlockID("ip"), style: .body, runs: []))], collapsed: false, author: []))
        XCTAssertEqual(DocumentTree.documentSize(bqDoc([emptySubQuote])), 8)
    }

    func test_fragment_blockQuote_notInlineMergeable_plainText_regenId() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        XCTAssertFalse(isInlineMergeable(.blockQuote(bq), intoHostStyle: .body))
        XCTAssertEqual(blockPlainText(.blockQuote(bq)), "hi")
        let regen = Document(blocks: [.blockQuote(bq)]).regeneratingTopLevelIDs()
        guard case .blockQuote(let r) = regen.blocks[0] else { return XCTFail() }
        XCTAssertNotEqual(r.id, bq.id)                                   // top-level id regenerated
        guard case .paragraph(let rp) = r.children[0] else { return XCTFail() }
        XCTAssertNotEqual(rp.id, BlockID("p"))                           // child ids regenerated too (no collisions on paste)
        XCTAssertEqual(rp.text, "hi")
    }
}

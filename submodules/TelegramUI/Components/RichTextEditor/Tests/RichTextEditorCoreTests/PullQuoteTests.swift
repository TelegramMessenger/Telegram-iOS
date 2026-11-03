import XCTest
@testable import RichTextEditorCore

final class PullQuoteTests: XCTestCase {
    func test_block_pullQuote_codableRoundTrip() throws {
        let pq = PullQuote(id: BlockID("pq1"), runs: [TextRun(text: "line1\nline2")])
        let block = Block.pullQuote(pq)
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(Block.self, from: data)
        XCTAssertEqual(decoded, block)
        XCTAssertEqual(decoded.id, pq.id)
    }

    func test_pullQuote_utf16Count() {
        let pq = PullQuote(id: BlockID("x"), runs: [TextRun(text: "ab"), TextRun(text: "c")])
        XCTAssertEqual(pq.utf16Count, 3)
        XCTAssertEqual(pq.text, "abc")
    }

    func test_documentTree_pullQuoteNodeSize() {
        // content(4) + 2 (pullPara) + 0 (empty author) + 2 (authorPara) + 2 (container) == 10 — the always-
        // present empty author region + container adds +4 over the pre-author-region shape (was 6).
        let doc = Document(blocks: [.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")]))])
        XCTAssertEqual(DocumentTree.documentSize(doc), 10)
    }

    func test_fragment_pullQuoteNotInlineMergeable() {
        XCTAssertFalse(isInlineMergeable(.pullQuote(PullQuote(id: BlockID("p"), runs: [])), intoHostStyle: .body))
    }

    func test_fragment_blockPlainText_pullQuote() {
        XCTAssertEqual(blockPlainText(.pullQuote(PullQuote(id: BlockID("p"), runs: [TextRun(text: "hi\nyo")]))), "hi\nyo")
    }

    func test_pullQuote_author_roundTripsAndEquatable() throws {
        let pq = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")], author: [TextRun(text: "Steve Jobs")])
        let data = try JSONEncoder().encode(pq)
        let decoded = try JSONDecoder().decode(PullQuote.self, from: data)
        XCTAssertEqual(decoded, pq)
        XCTAssertEqual(decoded.author.map(\.text).joined(), "Steve Jobs")
        XCTAssertNotEqual(pq, PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")], author: []))
    }

    func test_pullQuote_author_defaultsEmpty_andDecodesLegacyJSONWithoutAuthorKey() throws {
        XCTAssertEqual(PullQuote(id: BlockID("pq"), runs: []).author, [])
        // Legacy JSON produced before `author` existed: { "id": "pq", "runs": [] } with no "author" key.
        // (BlockID encodes as a bare string via a singleValueContainer — verified against BlockID.swift.)
        let legacy = "{\"id\":\"pq\",\"runs\":[]}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PullQuote.self, from: legacy)
        XCTAssertEqual(decoded.author, [])
    }

    func test_documentTree_pullQuoteNodeSize_withAuthorRegion() {
        // pull text "abcd" (4) + 2 (pullPara) + author "AB" (2) + 2 (authorPara) + 2 (container) = 12
        let pq = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")], author: [TextRun(text: "AB")])
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.pullQuote(pq)])), 12)
        // Empty author still reserves the region: 4 + 2 + 0 + 2 + 2 = 10.
        let pqEmpty = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")])
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.pullQuote(pqEmpty)])), 10)
    }

    func test_documentTree_pullQuote_authorHiddenWhenBothEmpty() {
        // Empty pull text + empty author → NO author paragraph: container(2) + pullPara(0+2) = 4.
        let empty = PullQuote(id: BlockID("pq"), runs: [], author: [])
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.pullQuote(empty)])), 4)
        // Body text present → author paragraph reserved (empty author): 4 + authorPara(0+2) = pullLen(4)+6.
        let withBody = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")], author: [])
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.pullQuote(withBody)])), 10)
        // Author text present, body empty → author paragraph present: pullLen(0) + authorLen(2) + 6 = 8.
        let withAuthor = PullQuote(id: BlockID("pq"), runs: [], author: [TextRun(text: "AB")])
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.pullQuote(withAuthor)])), 8)
        // Pull text stays at global 2 (container open 0, pullPara open 1, text 2) in BOTH states.
        // (documentSize checks above pin the shape; position stability is covered by the UIKit leafRegions test.)
    }

    func test_fragment_extractAndRegenerate_capturesPullQuote() {
        // A document with a single pull quote "abcd"; extract the whole block; assert a .pullQuote fragment
        // comes out with the covered runs, and regeneratingTopLevelIDs gives it a FRESH id.
        let pq = PullQuote(id: BlockID("orig"), runs: [TextRun(text: "abcd")])
        let doc = Document(blocks: [.pullQuote(pq)])
        // Pull text spans global [2, 6): the pull quote maps to a `.blockQuote` container [pullPara, authorPara],
        // so container open 0, pullPara open 1, text 2..6; extract [2, 6) covers all of it.
        let frag = doc.extractFragment(globalFrom: 2, globalTo: 6)
        guard case .pullQuote(let got)? = frag.blocks.first else { return XCTFail("no pull quote captured") }
        XCTAssertEqual(got.text, "abcd")
        let regen = frag.regeneratingTopLevelIDs()
        guard case .pullQuote(let r)? = regen.blocks.first else { return XCTFail() }
        XCTAssertNotEqual(r.id, got.id)      // fresh id
        XCTAssertEqual(r.text, "abcd")       // runs preserved
    }
}

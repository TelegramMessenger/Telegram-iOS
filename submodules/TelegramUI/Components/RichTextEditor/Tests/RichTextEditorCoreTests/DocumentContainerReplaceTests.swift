import XCTest
@testable import RichTextEditorCore

/// **A range inside one container's text is replaced inside that container.**
///
/// `replacingRange` computes a replacement as the complement of the range and joins back only a
/// top-level PARAGRAPH, so a caret inside a code block or a block quote split the container in two
/// and the fragment landed between the halves as top-level blocks (composer harness, 2026-09-23,
/// `HarnessFragmentPasteIntoContainerTests`: the editor's own copy of one word, pasted into a quote).
final class DocumentContainerReplaceTests: XCTestCase {
    private func para(_ text: String) -> Block {
        .paragraph(ParagraphBlock(id: .generate(), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func quote(_ children: Block...) -> Block {
        .blockQuote(BlockQuote(id: BlockID("q"), children: children))
    }
    private func childTexts(_ block: Block) -> [String]? {
        guard case let .blockQuote(q) = block else { return nil }
        return q.children.map(blockPlainText)
    }
    /// The global start of the quote child at `child` in a document `[p, quote]`.
    private func childTextStart(_ d: Document, child: Int) -> Int {
        guard case let .blockQuote(q) = d.blocks[1] else { return -1 }
        let quoteStart = DocumentTree.documentSize(Document(blocks: [d.blocks[0]]))
        return quoteStart + 1 + Document(blocks: q.children).globalTextStart(ofBlockAt: child)
    }

    func test_aWordPastedMidQuoteFoldsIntoTheChild() {
        let d = Document(blocks: [para("First paragraph."), quote(para("Second paragraph."))])
        let at = childTextStart(d, child: 0) + 7
        let (out, caret) = d.replacingRange(globalFrom: at, globalTo: at, with: Document(blocks: [para("First")]))
        XCTAssertEqual(out.blocks.count, 2)
        XCTAssertEqual(childTexts(out.blocks[1]), ["Second Firstparagraph."])
        XCTAssertEqual(caret, at + 5, "the caret follows the pasted word")
        guard case let .blockQuote(q) = out.blocks[1] else { return XCTFail() }
        XCTAssertEqual(q.id, BlockID("q"), "the quote keeps its identity")
    }

    func test_aWordPastedIntoAnEmptyQuoteChildStaysInTheQuote() {
        let d = Document(blocks: [para("First paragraph."), quote(para("Second paragraph."), para(""))])
        let at = childTextStart(d, child: 1)
        let (out, _) = d.replacingRange(globalFrom: at, globalTo: at, with: Document(blocks: [para("First")]))
        XCTAssertEqual(out.blocks.count, 2)
        XCTAssertEqual(childTexts(out.blocks[1]), ["Second paragraph.", "First"])
    }

    /// The choice for a multi-block fragment: it lands as blocks INSIDE the quote, splitting the
    /// child it was pasted into, exactly as it would split a top-level paragraph.
    func test_aMultiBlockFragmentLandsInsideTheQuote() {
        let d = Document(blocks: [para("intro"), quote(para("abcd"))])
        let at = childTextStart(d, child: 0) + 2
        let (out, caret) = d.replacingRange(globalFrom: at, globalTo: at,
                                            with: Document(blocks: [para("X"), para("Y")]))
        XCTAssertEqual(out.blocks.count, 2)
        XCTAssertEqual(childTexts(out.blocks[1]), ["abX", "Ycd"])
        XCTAssertEqual(caret, childTextStart(out, child: 1) + 1)
        XCTAssertNil(out.replacingRangeReportingInsertion(globalFrom: at, globalTo: at,
                                                          with: Document(blocks: [para("Z")])).lastInsertedBlockIndex)
    }

    func test_aSelectionInsideAQuoteIsReplacedInsideIt() {
        let d = Document(blocks: [para("intro"), quote(para("abcdef"))])
        let start = childTextStart(d, child: 0)
        let (out, _) = d.replacingRange(globalFrom: start + 1, globalTo: start + 4, with: Document(blocks: [para("Z")]))
        XCTAssertEqual(childTexts(out.blocks[1]), ["aZef"])
        let (deleted, _) = d.replacingRange(globalFrom: start + 1, globalTo: start + 4, with: Document(blocks: []))
        XCTAssertEqual(childTexts(deleted.blocks[1]), ["aef"], "a delete inside a quote keeps one quote")
    }

    func test_aFragmentPastedInACodeBlockIsSplicedAsText() {
        let code = CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x")])
        let d = Document(blocks: [para("intro"), .code(code)])
        let at = d.globalTextStart(ofBlockAt: 1) + 4
        let (out, caret) = d.replacingRange(globalFrom: at, globalTo: at,
                                            with: Document(blocks: [para("A"), para("B")]))
        XCTAssertEqual(out.blocks.count, 2)
        guard case let .code(result) = out.blocks[1] else { return XCTFail("the code block is gone") }
        XCTAssertEqual(result.text, "let A\nBx")
        XCTAssertEqual(result.language, "swift")
        XCTAssertEqual(caret, at + 3)
    }

    // MARK: - Pull quotes (a pull quote holds text, so the fragment is spliced into its runs)

    private func pullTextStart(_ d: Document) -> Int {
        DocumentTree.documentSize(Document(blocks: [d.blocks[0]])) + 2
    }

    func test_aWordPastedMidPullQuoteIsSplicedIntoItsText() {
        let pull = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Second paragraph.")],
                             author: [TextRun(text: "Me")])
        let d = Document(blocks: [para("First paragraph."), .pullQuote(pull)])
        let at = pullTextStart(d) + 7
        var bold = CharacterAttributes()
        bold.bold = true
        let fragment = Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "First", attributes: bold)]))])
        let (out, caret) = d.replacingRange(globalFrom: at, globalTo: at, with: fragment)
        XCTAssertEqual(out.blocks.count, 2, "the pull quote was split")
        guard case let .pullQuote(result) = out.blocks[1] else { return XCTFail("the pull quote is gone") }
        XCTAssertEqual(result.text, "Second Firstparagraph.")
        XCTAssertEqual(result.id, BlockID("pq"), "the pull quote keeps its identity")
        XCTAssertEqual(result.author.map(\.text).joined(), "Me", "the author survives")
        XCTAssertTrue(result.runs.contains { $0.text == "First" && $0.attributes.bold }, "the pasted formatting is kept")
        XCTAssertEqual(caret, at + 5, "the caret follows the pasted word")
    }

    func test_aMultiBlockFragmentInAPullQuoteLandsAsLines() {
        let pull = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")], author: [])
        let d = Document(blocks: [para("intro"), .pullQuote(pull)])
        let at = pullTextStart(d) + 2
        let (out, caret) = d.replacingRange(globalFrom: at, globalTo: at,
                                            with: Document(blocks: [para("X"), para("Y")]))
        XCTAssertEqual(out.blocks.count, 2)
        guard case let .pullQuote(result) = out.blocks[1] else { return XCTFail("the pull quote is gone") }
        XCTAssertEqual(result.text, "abX\nYcd")
        XCTAssertEqual(caret, at + 3)
    }

    func test_aSelectionInsideAPullQuoteIsReplacedInsideIt() {
        let pull = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcdef")], author: [])
        let d = Document(blocks: [para("intro"), .pullQuote(pull)])
        let start = pullTextStart(d)
        let (out, _) = d.replacingRange(globalFrom: start + 1, globalTo: start + 4, with: Document(blocks: [para("Z")]))
        guard case let .pullQuote(result) = out.blocks[1] else { return XCTFail("the pull quote is gone") }
        XCTAssertEqual(result.text, "aZef")
        XCTAssertEqual(out.blocks.count, 2)
    }
}

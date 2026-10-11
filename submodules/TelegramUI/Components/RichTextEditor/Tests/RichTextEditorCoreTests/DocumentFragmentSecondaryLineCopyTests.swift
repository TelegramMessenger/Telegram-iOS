import XCTest
@testable import RichTextEditorCore

/// **A copy carries the text of a second line it covers** (composer harness p19 fix wave,
/// `HarnessQuoteAuthorCutMoveTests`). A quote's author and a code block's language are on the editor's
/// axis, and a Cut or a move deletes what a range covers of them; a copy that carried nothing of them
/// lost that text for good.
final class DocumentFragmentSecondaryLineCopyTests: XCTestCase {
    private func position(_ document: Document, _ ref: TextNodeRef, _ offset: Int) -> Int {
        PositionResolver.globalPosition(of: ref, offset: offset, in: DocumentTree.build(from: document)) ?? -1
    }

    func test_aRangeFromAPullQuotesBodyIntoItsAuthorCarriesTheCoveredAuthor() {
        let document = Document(blocks: [.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "abc")],
                                                               author: [TextRun(text: "def")]))])
        let lo = position(document, .pullQuote(BlockID("q")), 1)
        let hi = position(document, .quoteAuthor(BlockID("q")), 2)
        let fragment = document.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: true)
        guard case .pullQuote(let quote)? = fragment.blocks.first else { return XCTFail("\(fragment)") }
        XCTAssertEqual(quote.runs.map(\.text).joined(), "bc")
        XCTAssertEqual(quote.author.map(\.text).joined(), "de")
    }

    func test_aRangeCoveringOnlyACodeLanguageCopiesItAsText() {
        let document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "top")])),
                                         .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let")]))])
        let lo = position(document, .paragraph(BlockID("p")), 1)
        let hi = position(document, .code(BlockID("c")), 0)
        let fragment = document.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: true)
        let texts = fragment.blocks.compactMap { block -> String? in
            if case .paragraph(let p) = block { return p.text }
            return nil
        }
        XCTAssertEqual(texts, ["op", "swift"])
    }

    /// Control: the whole pull text still carries the whole author.
    func test_controlTheWholePullTextCarriesTheWholeAuthor() {
        let document = Document(blocks: [.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "abc")],
                                                               author: [TextRun(text: "def")]))])
        let lo = position(document, .pullQuote(BlockID("q")), 0)
        let hi = position(document, .pullQuote(BlockID("q")), 3)
        let fragment = document.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: true)
        guard case .pullQuote(let quote)? = fragment.blocks.first else { return XCTFail("\(fragment)") }
        XCTAssertEqual(quote.author.map(\.text).joined(), "def")
    }
}

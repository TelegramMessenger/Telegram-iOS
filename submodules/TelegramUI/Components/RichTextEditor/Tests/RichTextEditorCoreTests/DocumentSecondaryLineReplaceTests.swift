import XCTest
@testable import RichTextEditorCore

/// **`replacingRange` must not keep, as body text, a container's second line that the replaced
/// range carries.** A code block's language and a pull quote's author are on the position axis, so
/// `extractFragment` copies a part of one that a range covers ALONE as a paragraph (composer harness
/// p19). But a range covering a code block's code text carries its language as METADATA, and a range
/// covering a pull quote's whole body carries its whole author: the replacement's complement
/// (`prefix = [0, lo)`, `suffix = [hi, size)`) kept that same line again as a paragraph, so the AI edit
/// handing back what it was given doubled it, and a delete turned it into a body line.
final class DocumentSecondaryLineReplaceTests: XCTestCase {
    private func para(_ text: String) -> Block {
        .paragraph(ParagraphBlock(id: .generate(), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func pullQuote(_ id: String, _ body: String, author: String) -> Block {
        .pullQuote(PullQuote(id: BlockID(id), runs: body.isEmpty ? [] : [TextRun(text: body)],
                             author: author.isEmpty ? [] : [TextRun(text: author)]))
    }
    private func code(_ id: String, language: String?, _ text: String) -> Block {
        .code(CodeBlock(id: BlockID(id), language: language, runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func position(_ document: Document, _ ref: TextNodeRef, _ offset: Int) -> Int {
        PositionResolver.globalPosition(of: ref, offset: offset, in: DocumentTree.build(from: document)) ?? -1
    }
    /// One line per block: `p "text"`, `code lang "text"`, `pull "body" by "author"`.
    private func describe(_ document: Document) -> [String] {
        document.blocks.map { block in
            switch block {
            case .paragraph(let p): return "p \"\(p.text)\""
            case .code(let c): return "code \(c.language ?? "-") \"\(c.text)\""
            case .pullQuote(let q): return "pull \"\(q.text)\" by \"\(q.author.map(\.text).joined())\""
            default: return "other"
            }
        }
    }
    /// Replaces `[lo, hi)` with its own copy — the article editor's AI edit answered unchanged.
    private func replacedWithItsOwnCopy(_ document: Document, _ lo: Int, _ hi: Int) -> Document {
        let copy = document.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: true)
        return document.replacingRange(globalFrom: lo, globalTo: hi, with: copy).document
    }

    // MARK: - A pull quote's author

    func test_aRangeThroughAPullQuotesWholeBody_replacedWithItsOwnCopy_changesNothing() {
        let document = Document(blocks: [para("intro"), pullQuote("q", "pulled", author: "Auth")])
        let lo = 1   // the start of "intro"
        // To the body's end, to the author's start, and into the author: each covers the whole body,
        // so its copy carries the whole author.
        for hi in [position(document, .pullQuote(BlockID("q")), 6),
                   position(document, .quoteAuthor(BlockID("q")), 0),
                   position(document, .quoteAuthor(BlockID("q")), 2)] {
            XCTAssertEqual(describe(replacedWithItsOwnCopy(document, lo, hi)),
                           ["p \"intro\"", "pull \"pulled\" by \"Auth\""], "1..<\(hi)")
        }
    }

    func test_deletingThroughAPullQuotesWholeBody_leavesNoAuthorParagraph() {
        let document = Document(blocks: [para("intro"), pullQuote("q", "pulled", author: "Auth"), para("after")])
        let hi = position(document, .pullQuote(BlockID("q")), 6)
        // From after "in" (text starts at 1).
        let deleted = document.replacingRange(globalFrom: 3, globalTo: hi, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["p \"in\"", "p \"after\""],
                       "the range covers the pull quote (its copy takes the author): nothing of it is left as body text")
    }

    func test_aRangeThroughAnEmptyPullQuoteIntoItsAuthor_replacedWithItsOwnCopy_changesNothing() {
        let document = Document(blocks: [para("intro"), pullQuote("q", "", author: "Auth"), para("after")])
        let hi = position(document, .quoteAuthor(BlockID("q")), 2)
        XCTAssertEqual(describe(replacedWithItsOwnCopy(document, 1, hi)),
                       ["p \"intro\"", "pull \"\" by \"Auth\"", "p \"after\""])
    }

    /// Control: a range entering a pull quote's body in PART leaves the author with the rest of it.
    func test_controlARangeEnteringAPullQuotesBodyKeepsTheAuthorWithTheRest() {
        let document = Document(blocks: [para("intro"), pullQuote("q", "pulled", author: "Auth")])
        let hi = position(document, .pullQuote(BlockID("q")), 3)
        let deleted = document.replacingRange(globalFrom: 1, globalTo: hi, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["pull \"led\" by \"Auth\""])
    }

    // MARK: - A code block's language

    func test_aRangeFromACodeBodyIntoTheNextParagraph_replacedWithItsOwnCopy_changesNothing() {
        let document = Document(blocks: [para("intro"), code("c", language: "swift", "abc"), para("next")])
        let lo = position(document, .code(BlockID("c")), 0)
        let hi = document.globalTextStart(ofBlockAt: 2) + 2
        XCTAssertEqual(describe(replacedWithItsOwnCopy(document, lo, hi)),
                       ["p \"intro\"", "code swift \"abc\"", "p \"next\""])
    }

    func test_deletingFromACodeBodyIntoTheNextParagraph_leavesNoLanguageParagraph() {
        let document = Document(blocks: [para("intro"), code("c", language: "swift", "abc"), para("next")])
        let lo = position(document, .code(BlockID("c")), 0)
        let hi = document.globalTextStart(ofBlockAt: 2) + 2
        let deleted = document.replacingRange(globalFrom: lo, globalTo: hi, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["p \"intro\"", "p \"xt\""],
                       "the range covers the code (its copy takes the language): nothing of it is left as body text")
    }

    func test_aRangeFromAnEmptyCodeBlockIntoTheNextParagraph_replacedWithItsOwnCopy_changesNothing() {
        let document = Document(blocks: [para("intro"), code("c", language: "swift", ""), para("next")])
        let lo = position(document, .code(BlockID("c")), 0)
        let hi = document.globalTextStart(ofBlockAt: 2) + 2
        XCTAssertEqual(describe(replacedWithItsOwnCopy(document, lo, hi)),
                       ["p \"intro\"", "code swift \"\"", "p \"next\""])
    }

    /// Control: a range covering the language line but none of the code text copies the language as
    /// text (`DocumentFragmentSecondaryLineCopyTests`), and a delete of it leaves the code block alone.
    func test_controlDeletingUpToACodeBodysStartKeepsTheCodeBlock() {
        let document = Document(blocks: [para("top"), code("c", language: "swift", "let")])
        let hi = position(document, .code(BlockID("c")), 0)
        let deleted = document.replacingRange(globalFrom: 2, globalTo: hi, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["p \"t\"", "code swift \"let\""])
    }
}

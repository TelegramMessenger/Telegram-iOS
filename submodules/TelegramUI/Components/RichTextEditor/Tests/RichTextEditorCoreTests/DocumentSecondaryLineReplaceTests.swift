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
            case .blockQuote(let q):
                return "quote \(q.children.map(blockPlainText)) by \"\(q.author.map(\.text).joined())\""
            default: return "other"
            }
        }
    }
    /// Replaces `[lo, hi)` with its own copy — the article editor's AI edit answered unchanged.
    private func replacedWithItsOwnCopy(_ document: Document, _ lo: Int, _ hi: Int) -> Document {
        let copy = document.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: true)
        return document.replacingRange(globalFrom: lo, globalTo: hi, with: copy).document
    }

    // MARK: - A block quote's author

    private func blockQuote(_ id: String, _ children: [String], author: String) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children.map { para($0) }, collapsed: false,
                               author: author.isEmpty ? [] : [TextRun(text: author)]))
    }

    /// A range covering ALL of a block quote's children takes its author, as a pull quote's whole body
    /// does — the engine's gate drops such a quote whole, author included, and its Copy is widened to
    /// match. Without that the copy left the author behind and the complement kept it as a body
    /// paragraph: `[quote … by ""] [p "Auth"]` after an AI edit answered unchanged (review of the fix
    /// wave, 2026-10-12).
    func test_aRangeThroughABlockQuotesWholeBody_replacedWithItsOwnCopy_changesNothing() {
        let document = Document(blocks: [para("intro"), blockQuote("q", ["body"], author: "Auth")])
        let lo = 3   // inside "intro"
        let quoteStart = document.globalTextStart(ofBlockAt: 1) - 1   // the quote's own open token
        let hi = quoteStart + 1 + DocumentTree.documentSize(Document(blocks: [para("body")])) - 1   // the end of "body"
        XCTAssertEqual(describe(replacedWithItsOwnCopy(document, lo, hi)),
                       ["p \"intro\"", "quote [\"body\"] by \"Auth\""], "\(lo)..<\(hi)")
    }

    func test_deletingThroughABlockQuotesWholeBody_leavesNoAuthorParagraph() {
        let document = Document(blocks: [para("intro"), blockQuote("q", ["one", "two"], author: "Auth"), para("after")])
        let hi = position(document, .paragraph(childID(document, quoteAt: 1, child: 1)), 3)   // the end of "two"
        let deleted = document.replacingRange(globalFrom: 3, globalTo: hi, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["p \"in\"", "p \"after\""],
                       "the range covers every child (its copy takes the author): nothing of the quote is left as body text")
    }

    /// Control: a range entering only PART of the children leaves the author with the rest of them.
    func test_controlARangeEnteringPartOfABlockQuoteKeepsTheAuthorWithTheRest() {
        let document = Document(blocks: [para("intro"), blockQuote("q", ["one", "two"], author: "Auth")])
        let hi = position(document, .paragraph(childID(document, quoteAt: 1, child: 0)), 2)   // inside "one"
        let deleted = document.replacingRange(globalFrom: 3, globalTo: hi, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["p \"in\"", "quote [\"e\", \"two\"] by \"Auth\""])
        let copy = document.extractFragment(globalFrom: 3, globalTo: hi, carryingNonTextBlocks: true)
        XCTAssertEqual(describe(copy), ["p \"tro\"", "quote [\"on\"] by \"\""], "a partial copy carries no uncovered author")
    }

    private func childID(_ document: Document, quoteAt index: Int, child: Int) -> BlockID {
        guard case .blockQuote(let q) = document.blocks[index], case .paragraph(let p) = q.children[child] else {
            preconditionFailure("not a quote of paragraphs")
        }
        return p.id
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

    // MARK: - A range INSIDE a second line edits that line

    func test_deletingInsideACodeLanguage_editsTheLanguage() {
        let document = Document(blocks: [para("intro"), code("c", language: "python", "x = 1")])
        let lo = position(document, .codeLanguage(BlockID("c")), 1)
        let deleted = document.replacingRange(globalFrom: lo, globalTo: lo + 2, with: Document(blocks: []))
        XCTAssertEqual(describe(deleted.document), ["p \"intro\"", "code phon \"x = 1\""])
        XCTAssertEqual(deleted.caret, lo)
        XCTAssertEqual(describe(replacedWithItsOwnCopy(document, lo, lo + 2)), describe(document))
        let replaced = document.replacingRange(globalFrom: lo, globalTo: lo + 2, with: Document(blocks: [para("YT")]))
        XCTAssertEqual(describe(replaced.document), ["p \"intro\"", "code pYThon \"x = 1\""])
        XCTAssertEqual(replaced.caret, lo + 2)
    }

    func test_deletingAWholeCodeLanguage_leavesNoLanguage() {
        let document = Document(blocks: [para("intro"), code("c", language: "swift", "let")])
        let lo = position(document, .codeLanguage(BlockID("c")), 0)
        let deleted = document.replacingRange(globalFrom: lo, globalTo: lo + 5, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["p \"intro\"", "code - \"let\""])
    }

    func test_deletingInsideAPullQuotesAuthor_editsTheAuthor() {
        let document = Document(blocks: [para("intro"), pullQuote("q", "body", author: "Author")])
        let lo = position(document, .quoteAuthor(BlockID("q")), 1)
        let deleted = document.replacingRange(globalFrom: lo, globalTo: lo + 2, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["p \"intro\"", "pull \"body\" by \"Ahor\""])
        XCTAssertEqual(describe(replacedWithItsOwnCopy(document, lo, lo + 2)), describe(document))
    }

    func test_deletingInsideABlockQuotesAuthor_editsTheAuthor() {
        let quote = Block.blockQuote(BlockQuote(id: BlockID("b"), children: [para("child")], collapsed: false,
                                                author: [TextRun(text: "Author")]))
        let document = Document(blocks: [para("intro"), quote])
        let lo = position(document, .quoteAuthor(BlockID("b")), 1)
        let deleted = document.replacingRange(globalFrom: lo, globalTo: lo + 2, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["p \"intro\"", "quote [\"child\"] by \"Ahor\""])
        XCTAssertEqual(describe(replacedWithItsOwnCopy(document, lo, lo + 2)), describe(document))
    }

    /// Control: a caret at the boundary after an empty, authorless pull quote (which has no author
    /// line on the axis) is not taken for a caret in its author.
    func test_controlACaretAfterAnEmptyPullQuoteIsNotInItsAuthor() {
        let document = Document(blocks: [pullQuote("q", "", author: ""), para("after")])
        let boundary = DocumentTree.documentSize(Document(blocks: [document.blocks[0]]))
        let pasted = document.replacingRange(globalFrom: boundary, globalTo: boundary,
                                             with: Document(blocks: [para("X")])).document
        XCTAssertFalse(describe(pasted).contains("pull \"\" by \"X\""), "\(describe(pasted))")
    }

    // MARK: - A pull quote's whole body is the pull quote

    /// A range covering exactly a pull quote's body copies the pull quote WITH its author, so a pull
    /// quote replacing that range replaces the author too — it is not spliced into the body as a line.
    func test_aPullQuotesWholeBody_replacedWithItsOwnCopy_changesNothing() {
        let document = Document(blocks: [para("intro"), pullQuote("q", "pulled", author: "Auth")])
        let lo = position(document, .pullQuote(BlockID("q")), 0)
        let result = replacedWithItsOwnCopy(document, lo, lo + 6)
        XCTAssertEqual(describe(result), ["p \"intro\"", "pull \"pulled\" by \"Auth\""])
        guard case .pullQuote(let quote) = result.blocks[1] else { return XCTFail() }
        XCTAssertEqual(quote.id, BlockID("q"), "the pull quote keeps its identity")
    }

    func test_aPullQuoteReplacingAWholeBody_takesItsAuthor_orKeepsTheOneThereWhenItHasNone() {
        let document = Document(blocks: [para("intro"), pullQuote("q", "pulled", author: "Auth")])
        let lo = position(document, .pullQuote(BlockID("q")), 0)
        let withAuthor = document.replacingRange(globalFrom: lo, globalTo: lo + 6,
                                                 with: Document(blocks: [pullQuote("n", "new", author: "Other")]))
        XCTAssertEqual(describe(withAuthor.document), ["p \"intro\"", "pull \"new\" by \"Other\""])
        XCTAssertEqual(withAuthor.caret, lo + 3)
        let withoutAuthor = document.replacingRange(globalFrom: lo, globalTo: lo + 6,
                                                    with: Document(blocks: [pullQuote("n", "new", author: "")]))
        XCTAssertEqual(describe(withoutAuthor.document), ["p \"intro\"", "pull \"new\" by \"Auth\""])
    }

    /// Control: a paragraph rewriting the whole body keeps the pull quote and its author.
    func test_controlAParagraphReplacingAWholePullQuoteBodyKeepsTheAuthor() {
        let document = Document(blocks: [para("intro"), pullQuote("q", "pulled", author: "Auth")])
        let lo = position(document, .pullQuote(BlockID("q")), 0)
        let result = document.replacingRange(globalFrom: lo, globalTo: lo + 6, with: Document(blocks: [para("new")]))
        XCTAssertEqual(describe(result.document), ["p \"intro\"", "pull \"new\" by \"Auth\""])
    }
}

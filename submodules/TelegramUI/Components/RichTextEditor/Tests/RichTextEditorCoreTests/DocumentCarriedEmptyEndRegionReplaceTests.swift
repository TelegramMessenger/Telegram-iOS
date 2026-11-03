import XCTest
@testable import RichTextEditorCore

/// **A range the copy covers is the range the paste replaces.**
///
/// `extractFragment` carries an EMPTY text region at the document's end when a range ends exactly at
/// it — an empty code block, an empty pull quote, the empty last line of an expanded details ending
/// the document — because that is where Select All ends (its end is the region's start). The
/// complement in `replacingRange` took the suffix from that same position, where the region was
/// covered again, so it appeared in both halves: Select All → Copy → Paste over `[p ""] [pull ""]`
/// gave `[p ""] [pull] [pull]` (composer harness p18, fuzz seed 6,
/// `HarnessEmptyPullQuoteAtEndPasteTests`).
///
/// Each case copies `[start, end-region)` and pastes it back over the same range; the result must
/// hold each block once. The controls are the regions the copy does NOT carry at that position: a
/// top-level trailing empty paragraph (the document's trailing line) and a block quote's empty child
/// (its author line follows, so its children never end the document).
final class DocumentCarriedEmptyEndRegionReplaceTests: XCTestCase {
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    private func kinds(_ blocks: [Block]) -> [String] {
        blocks.map { block in
            switch block {
            case .paragraph(let p): return "p(\(p.text))"
            case .code(let c): return "code(\(c.text))"
            case .pullQuote: return "pull"
            case .blockQuote(let q): return "quote[\(kinds(q.children).joined(separator: ", "))]"
            case .details(let d): return "details[\(kinds(d.children).joined(separator: ", "))]"
            case .table: return "table"
            case .media: return "media"
            case .buttonRow: return "buttonRow"
            }
        }
    }

    /// Copies `[first text position, region)` and pastes it back over that range.
    private func pasteBack(_ document: Document, endingAt ref: TextNodeRef) -> Document {
        let tree = DocumentTree.build(from: document)
        guard let lo = PositionResolver.globalPosition(of: .paragraph(BlockID("p0")), offset: 0, in: tree),
              let hi = PositionResolver.globalPosition(of: ref, offset: 0, in: tree) else {
            XCTFail("unresolvable range")
            return document
        }
        let fragment = document.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: true)
        return document.replacingRange(globalFrom: lo, globalTo: hi, with: fragment).document
    }

    /// Drops the one trailing empty body line a paste may add after a block the caret cannot stand in.
    private func withoutTrailingLine(_ blocks: [Block]) -> [String] {
        var result = kinds(blocks)
        if result.count > 1, result.last == "p()" { result.removeLast() }
        return result
    }

    func test_anEmptyPullQuoteEndingTheDocumentIsReplacedNotDuplicated() {
        let document = Document(blocks: [para("p0", ""), .pullQuote(PullQuote(id: BlockID("q")))])
        let out = pasteBack(document, endingAt: .pullQuote(BlockID("q")))
        XCTAssertEqual(withoutTrailingLine(out.blocks), ["p()", "pull"])
    }

    func test_anEmptyPullQuoteAfterTextIsReplacedNotDuplicated() {
        let document = Document(blocks: [para("p0", "a"), .pullQuote(PullQuote(id: BlockID("q")))])
        let out = pasteBack(document, endingAt: .pullQuote(BlockID("q")))
        XCTAssertEqual(withoutTrailingLine(out.blocks), ["p(a)", "pull"])
    }

    func test_anEmptyPullQuoteWithAnAuthorIsReplacedNotDuplicated() {
        let document = Document(blocks: [para("p0", ""),
                                         .pullQuote(PullQuote(id: BlockID("q"), author: [TextRun(text: "x")]))])
        let out = pasteBack(document, endingAt: .pullQuote(BlockID("q")))
        XCTAssertEqual(withoutTrailingLine(out.blocks), ["p()", "pull"])
    }

    func test_anEmptyCodeBlockEndingTheDocumentIsReplacedNotDuplicated() {
        let document = Document(blocks: [para("p0", ""), .code(CodeBlock(id: BlockID("c")))])
        let out = pasteBack(document, endingAt: .code(BlockID("c")))
        XCTAssertEqual(withoutTrailingLine(out.blocks), ["p()", "code()"])
    }

    func test_theEmptyLastLineOfADetailsEndingTheDocumentIsReplacedNotDuplicated() {
        let document = Document(blocks: [para("p0", "a"),
                                         .details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                                               children: [para("b", "body"), para("e", "")]))])
        let out = pasteBack(document, endingAt: .paragraph(BlockID("e")))
        XCTAssertEqual(withoutTrailingLine(out.blocks), ["p(a)", "details[p(body), p()]"])
    }

    // MARK: - Controls: regions the copy does not carry at that position

    func test_controlATrailingEmptyParagraphStaysTheDocumentsTrailingLine() {
        let document = Document(blocks: [para("p0", "a"), para("e", "")])
        let out = pasteBack(document, endingAt: .paragraph(BlockID("e")))
        XCTAssertEqual(kinds(out.blocks), ["p(a)", "p()"])
    }

    func test_controlABlockQuotesEmptyLastChildIsNotConsumed() {
        let document = Document(blocks: [para("p0", ""),
                                         .blockQuote(BlockQuote(id: BlockID("q"), children: [para("e", "")]))])
        let out = pasteBack(document, endingAt: .paragraph(BlockID("e")))
        XCTAssertEqual(withoutTrailingLine(out.blocks), ["p()", "quote[p()]"])
    }

    /// Control: a range ending INSIDE the empty region's own block is still decided inside it — the
    /// rule only widens a range that starts before the region.
    func test_controlAnEmptyRangeAtTheRegionChangesNothing() {
        let document = Document(blocks: [para("p0", "a"), .code(CodeBlock(id: BlockID("c")))])
        let tree = DocumentTree.build(from: document)
        let at = PositionResolver.globalPosition(of: .code(BlockID("c")), offset: 0, in: tree)!
        let out = document.replacingRange(globalFrom: at, globalTo: at,
                                          with: Document(blocks: [para("x", "x")])).document
        XCTAssertEqual(withoutTrailingLine(out.blocks), ["p(a)", "code(x)"])
    }
}

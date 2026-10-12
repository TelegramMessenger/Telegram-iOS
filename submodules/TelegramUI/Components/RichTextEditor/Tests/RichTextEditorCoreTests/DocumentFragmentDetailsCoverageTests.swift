import XCTest
@testable import RichTextEditorCore

/// **A range that covers none of a details block copies nothing of it.** `extractFragment` enters a
/// details like a block quote (composer harness, 2026-09-23), and emitted one whenever the range
/// started at or before its title — even when the range ENDED there and covered no title text and no
/// body: `[p "before"] [details "Title" …]`, copy from "fore" to the title's start, gave `[p "fore"]
/// [details "" [p ""]]`, which a paste-back or the AI edit's replacement then added to the document.
/// The empty body line it minted (the engine draws one for a childless expanded details) is only for a
/// details the copy really carries; minted for a range lying in the body, it was a stray top-level
/// paragraph.
final class DocumentFragmentDetailsCoverageTests: XCTestCase {
    private func para(_ text: String) -> Block {
        .paragraph(ParagraphBlock(id: .generate(), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func details(_ id: String, _ title: String, _ children: [Block], expanded: Bool = true) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: title.isEmpty ? [] : [TextRun(text: title)],
                              children: children, expanded: expanded))
    }
    private func position(_ document: Document, _ ref: TextNodeRef, _ offset: Int) -> Int {
        PositionResolver.globalPosition(of: ref, offset: offset, in: DocumentTree.build(from: document)) ?? -1
    }
    private func describe(_ blocks: [Block]) -> [String] {
        blocks.map { block in
            switch block {
            case .paragraph(let p): return "p \"\(p.text)\""
            case .details(let d):
                return "details \"\(d.title.map(\.text).joined())\"\(d.expanded ? "" : " folded") \(describe(d.children))"
            default: return "other"
            }
        }
    }
    private func describe(_ document: Document) -> [String] { describe(document.blocks) }

    // MARK: - Nothing covered, nothing copied

    func test_aRangeEndingAtADetailsTitle_copiesNothingOfTheDetails() {
        let document = Document(blocks: [para("before"), details("d", "Title", [para("body")]), para("after")])
        // The details' own start + 1 (what `globalTextStart` answers for it) and its title's text start.
        for end in [document.globalTextStart(ofBlockAt: 1), position(document, .detailsTitle(BlockID("d")), 0)] {
            XCTAssertEqual(describe(document.extractFragment(globalFrom: 3, globalTo: end)), ["p \"fore\""], "3..<\(end)")
        }
    }

    func test_aRangeEndingAtTheTitleOfADetailsStartingTheDocument_copiesNothing() {
        let document = Document(blocks: [details("d", "Title", [para("body")]), para("after")])
        let end = position(document, .detailsTitle(BlockID("d")), 0)
        XCTAssertEqual(describe(document.extractFragment(globalFrom: 0, globalTo: end)), [])
    }

    func test_aRangeEndingAtAnEmptyExpandedTitle_copiesNothingOfTheDetails() {
        let document = Document(blocks: [para("a"), details("d", "", [para("body")])])
        let end = position(document, .detailsTitle(BlockID("d")), 0)
        XCTAssertEqual(describe(document.extractFragment(globalFrom: 1, globalTo: end)), ["p \"a\""])
    }

    /// The mirror: the complement of a range ending at the end of a details' last body line kept an
    /// empty top-level paragraph minted from no text.
    func test_aRangeFromTheEndOfADetailsBody_copiesNothingOfTheDetails() {
        let document = Document(blocks: [para("before"), details("d", "Title", [para("body")]), para("after")])
        let bodyEnd = document.globalTextStart(ofBlockAt: 1) + 1 + 5 + 1 + 1 + 4
        XCTAssertEqual(describe(document.extractFragment(globalFrom: bodyEnd, globalTo: DocumentTree.documentSize(document))),
                       ["p \"after\""])
        let deleted = document.replacingRange(globalFrom: 2, globalTo: bodyEnd, with: Document(blocks: [])).document
        XCTAssertEqual(describe(deleted), ["p \"b\"", "p \"after\""])
        let copy = document.extractFragment(globalFrom: 2, globalTo: bodyEnd)
        XCTAssertEqual(describe(document.replacingRange(globalFrom: 2, globalTo: bodyEnd, with: copy).document),
                       describe(document), "replacing the range with its own copy changes nothing")
    }

    func test_aRangeEndingAtADetailsTitle_replacedWithItsOwnCopy_changesNothing() {
        let document = Document(blocks: [para("before"), details("d", "Title", [para("body")]), para("after")])
        let end = position(document, .detailsTitle(BlockID("d")), 0)
        let copy = document.extractFragment(globalFrom: 3, globalTo: end)
        XCTAssertEqual(describe(document.replacingRange(globalFrom: 3, globalTo: end, with: copy).document),
                       describe(document))
    }

    // MARK: - A part of the title copies no invented body line into the title

    func test_partOfADetailsTitle_replacedWithItsOwnCopy_changesNothing() {
        let document = Document(blocks: [details("d", "Tit", [para("body")])])
        let start = position(document, .detailsTitle(BlockID("d")), 0)
        let copy = document.extractFragment(globalFrom: start, globalTo: start + 1)
        XCTAssertEqual(describe(document.replacingRange(globalFrom: start, globalTo: start + 1, with: copy).document),
                       ["details \"Tit\" [\"p \\\"body\\\"\"]"])
    }

    /// The same for a body of SEVERAL empty lines: the check read the joined body, and the line breaks
    /// between the empty lines are text, so it pasted spaces into the title (review of the fix wave,
    /// 2026-10-12).
    func test_aDetailsWhoseBodyIsSeveralEmptyLines_pastedIntoATitle_addsNoSpaces() {
        let document = Document(blocks: [details("d", "Tit", [para("body")])])
        let start = position(document, .detailsTitle(BlockID("d")), 0)
        let fragment = Document(blocks: [details("f", "T", [para(""), para(""), para("")])])
        XCTAssertEqual(describe(document.replacingRange(globalFrom: start, globalTo: start + 1, with: fragment).document),
                       ["details \"Tit\" [\"p \\\"body\\\"\"]"])
    }

    /// One level down: a body line that is itself a container of empty lines (a quote of two empty
    /// paragraphs) is its own `"\n"`-joined line, which read as text and pasted a space.
    func test_aDetailsWhoseBodyIsAQuoteOfEmptyLines_pastedIntoATitle_addsNoSpaces() {
        let document = Document(blocks: [details("d", "Tit", [para("body")])])
        let start = position(document, .detailsTitle(BlockID("d")), 0)
        let quote = Block.blockQuote(BlockQuote(id: .generate(), children: [para(""), para("")], collapsed: false))
        let fragment = Document(blocks: [details("f", "T", [quote])])
        XCTAssertEqual(describe(document.replacingRange(globalFrom: start, globalTo: start + 1, with: fragment).document),
                       ["details \"Tit\" [\"p \\\"body\\\"\"]"])
    }

    // MARK: - Controls

    /// A range entering the title still copies a details, with the empty body line it needs to be
    /// drawn the way the model says (composer harness `HarnessDetailsCopyPasteTests`).
    func test_controlARangeEnteringTheTitleCopiesADetailsWithABodyLine() {
        let document = Document(blocks: [para("a"), details("d", "Title", [para("body")])])
        let end = position(document, .detailsTitle(BlockID("d")), 4)
        XCTAssertEqual(describe(document.extractFragment(globalFrom: 1, globalTo: end)),
                       ["p \"a\"", "details \"Titl\" [\"p \\\"\\\"\"]"])
    }

    /// Select All ends at a FOLDED details' empty title when it ends the document — the title is its
    /// only text position — and the copy keeps it, folded body included (unchanged). Replacing that
    /// range with its own copy changes nothing, and deleting it deletes what the copy took: the
    /// complement used to keep the details as well (`carriedEmptyEndRegionStart` had no mirror for it).
    func test_selectAllOverAFoldedEmptyTitledDetailsAtTheEnd_copiesIt_andTheReplacementAgrees() {
        let document = Document(blocks: [para("a"), details("d", "", [para("hidden")], expanded: false)])
        let end = position(document, .detailsTitle(BlockID("d")), 0)
        let copy = document.extractFragment(globalFrom: 1, globalTo: end)
        XCTAssertEqual(describe(copy), ["p \"a\"", "details \"\" folded [\"p \\\"hidden\\\"\"]"])
        XCTAssertEqual(describe(document.replacingRange(globalFrom: 1, globalTo: end, with: copy).document),
                       describe(document))
        XCTAssertEqual(describe(document.replacingRange(globalFrom: 1, globalTo: end, with: Document(blocks: [])).document),
                       ["p \"\""])
    }
}

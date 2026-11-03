import XCTest
@testable import RichTextEditorCore

/// **A table cell is a text region, for the copy and for the paste.**
///
/// A range inside a table used to snap to the WHOLE table (`expandingRangeOverNonTextBlocks`) and a
/// paste at a caret in a cell went to the complement model, whose halves both skip the table: copying
/// a word from a cell copied the table, and pasting the editor's own copy into a cell deleted the table
/// and put the pasted blocks in its place (composer harness p19,
/// `HarnessFragmentPasteIntoTableCellTests`). `tableCellFragment` answers a range inside one cell with
/// what it covers, and `replacingRange` splices a fragment into one cell as inline runs.
final class DocumentTableCellFragmentTests: XCTestCase {
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    private func table(_ id: String, _ cells: [String]) -> Block {
        .table(TableBlock(id: BlockID(id), columns: cells.map { _ in ColumnSpec(width: 0.0) },
                          rows: [Row(id: BlockID(id + "r"), cells: cells.map { text in
                              Cell(id: BlockID(id + text), blocks: [para(id + text + "p", text)])
                          })]))
    }

    private func position(_ document: Document, _ ref: TextNodeRef, _ offset: Int) -> Int {
        PositionResolver.globalPosition(of: ref, offset: offset, in: DocumentTree.build(from: document)) ?? -1
    }

    private func cellTexts(_ document: Document) -> [String] {
        document.blocks.compactMap { block -> String? in
            guard case .table(let table) = block else { return nil }
            return table.rows.flatMap(\.cells).map { cell in
                cell.blocks.map { block -> String in
                    if case .paragraph(let p) = block { return p.text }
                    return "?"
                }.joined(separator: "/")
            }.joined(separator: "|")
        }
    }

    func test_aFragmentPastedAtACaretInACellIsSplicedIntoTheCell() {
        let document = Document(blocks: [para("top", "Top"), table("t", ["a", "b"]), para("one", "one")])
        let caret = position(document, .paragraph(BlockID("tap")), 1)
        let fragment = Document(blocks: [para("x", "one")])
        let out = document.replacingRange(globalFrom: caret, globalTo: caret, with: fragment)
        XCTAssertEqual(cellTexts(out.document), ["aone|b"])
        XCTAssertEqual(out.document.blocks.count, 3)
        // After "aone": [p "Top"] is 5 tokens, then the table's, row's, cell's and paragraph's opens.
        XCTAssertEqual(out.caret, 5 + 4 + 4)
    }

    func test_aStructuredFragmentPastedIntoACellDegradesToOneCellOfText() {
        let document = Document(blocks: [table("t", ["a", "b"]), para("after", "after")])
        let caret = position(document, .paragraph(BlockID("tbp")), 1)
        let fragment = Document(blocks: [para("x", "one"), table("u", ["c", "d"]), para("y", "two")])
        let out = document.replacingRange(globalFrom: caret, globalTo: caret, with: fragment).document
        XCTAssertEqual(out.blocks.count, 2, "no block may leave the cell")
        XCTAssertEqual(cellTexts(out), ["a|bone\nc d\ntwo"])
    }

    func test_aReplacementInsideACellKeepsTheRestOfTheCell() {
        let document = Document(blocks: [table("t", ["abcd", "e"])])
        let lo = position(document, .paragraph(BlockID("tabcdp")), 1)
        let hi = position(document, .paragraph(BlockID("tabcdp")), 3)
        let out = document.replacingRange(globalFrom: lo, globalTo: hi, with: Document(blocks: [para("x", "Z")])).document
        XCTAssertEqual(cellTexts(out), ["aZd|e"])
    }

    func test_aRangeInsideOneCellCopiesWhatItCoversNotTheTable() {
        let document = Document(blocks: [table("t", ["word", "b"]), para("x", "x")])
        let lo = position(document, .paragraph(BlockID("twordp")), 1)
        let hi = position(document, .paragraph(BlockID("twordp")), 3)
        let fragment = document.tableCellFragment(globalFrom: lo, globalTo: hi)
        XCTAssertEqual(fragment?.blocks.count, 1)
        if case .paragraph(let p)? = fragment?.blocks.first {
            XCTAssertEqual(p.text, "or")
        } else {
            XCTFail("expected the covered text, got \(String(describing: fragment))")
        }
    }

    func test_aCellInsideAQuoteIsFoundToo() {
        let document = Document(blocks: [.blockQuote(BlockQuote(id: BlockID("q"), children: [table("t", ["word", "b"])]))])
        let lo = position(document, .paragraph(BlockID("twordp")), 0)
        let hi = position(document, .paragraph(BlockID("twordp")), 2)
        XCTAssertNotNil(document.tableCellFragment(globalFrom: lo, globalTo: hi))
    }

    /// A quote's author is text the fragment carries; degraded to runs it is a line of its own
    /// (p19 fix wave, `HarnessQuoteAuthorCutMoveTests`).
    func test_aPullQuoteFragmentsAuthorSurvivesBeingPastedAsRuns() {
        let document = Document(blocks: [table("t", ["a", "b"])])
        let caret = position(document, .paragraph(BlockID("tap")), 1)
        let fragment = Document(blocks: [.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "bc")],
                                                              author: [TextRun(text: "de")]))])
        let out = document.replacingRange(globalFrom: caret, globalTo: caret, with: fragment).document
        XCTAssertEqual(cellTexts(out), ["abc\nde|b"])
    }

    // Controls: a range reaching out of the cell keeps the whole-table rules.

    func test_controlARangeAcrossCellsIsNotOneCell() {
        let document = Document(blocks: [table("t", ["a", "b"])])
        let lo = position(document, .paragraph(BlockID("tap")), 0)
        let hi = position(document, .paragraph(BlockID("tbp")), 1)
        XCTAssertNil(document.tableCellFragment(globalFrom: lo, globalTo: hi))
    }

    func test_controlARangeFromAParagraphIntoACellIsNotOneCell() {
        let document = Document(blocks: [para("top", "Top"), table("t", ["a", "b"])])
        let lo = position(document, .paragraph(BlockID("top")), 1)
        let hi = position(document, .paragraph(BlockID("tap")), 1)
        XCTAssertNil(document.tableCellFragment(globalFrom: lo, globalTo: hi))
    }
}

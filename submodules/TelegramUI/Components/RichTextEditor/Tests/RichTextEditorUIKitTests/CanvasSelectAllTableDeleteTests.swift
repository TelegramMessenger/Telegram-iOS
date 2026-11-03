#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Select-All → Backspace over a document that contains a table (at ANY position) must reset to a SINGLE empty
/// body paragraph — dropping the table and every paragraph, exactly like the image cases in `CanvasImageEditTests`.
/// Regression: the whole-document reset in `applySelectionReplaceOutcome` was skipped whenever a Select-All endpoint
/// landed inside a table cell (table first/last/only block), so the delete fell through to the per-region clear,
/// which cleared each region's text but KEPT the block structure — the table and paragraphs stayed, empty.
final class CanvasSelectAllTableDeleteTests: XCTestCase {
    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    private func row(_ id: String, _ texts: [String]) -> Row {
        Row(id: BlockID(id), isHeader: false, cells: texts.enumerated().map { cell(id + "\($0.offset)", $0.element) })
    }
    private func table(_ id: String = "t") -> Block {
        .table(TableBlock(id: BlockID(id),
            columns: [ColumnSpec(width: 90), ColumnSpec(width: 90)],
            rows: [row(id + "r0", ["A", "B"]), row(id + "r1", ["c", "d"])]))
    }
    private func para(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: t)]))
    }
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        return v
    }
    private func assertSingleEmptyParagraph(_ v: DocumentCanvasView, _ message: String) {
        XCTAssertNil(v.boxes.first { $0 is TableBlockBox }, "\(message): the table is removed")
        XCTAssertEqual(v.boxes.count, 1, "\(message): collapses to exactly one block")
        XCTAssertTrue(v.boxes.first is BlockBox, "\(message): the surviving block is a paragraph")
        XCTAssertEqual(v.boxes.first?.textLength, 0, "\(message): the paragraph is empty")
    }

    func test_selectAll_backspace_tableFirst_resetsToEmptyParagraph() {
        let v = canvas([table(), para("bot", "Bot")])
        v.selectAllText()
        v.deleteBackward()
        v.layoutIfNeeded()
        assertSingleEmptyParagraph(v, "table first")
    }

    func test_selectAll_backspace_tableLast_resetsToEmptyParagraph() {
        let v = canvas([para("top", "Top"), table()])
        v.selectAllText()
        v.deleteBackward()
        v.layoutIfNeeded()
        assertSingleEmptyParagraph(v, "table last")
    }

    func test_selectAll_backspace_tableMiddle_resetsToEmptyParagraph() {
        let v = canvas([para("top", "Top"), table(), para("bot", "Bot")])
        v.selectAllText()
        v.deleteBackward()
        v.layoutIfNeeded()
        assertSingleEmptyParagraph(v, "table middle")
    }

    /// A lone (only-block) table: Select-All covers the table's ENTIRE content, so it resets to one empty
    /// paragraph too — not just cleared cells.
    func test_selectAll_backspace_loneTable_resetsToEmptyParagraph() {
        let v = canvas([table()])
        v.selectAllText()
        v.deleteBackward()
        v.layoutIfNeeded()
        assertSingleEmptyParagraph(v, "lone table")
    }

    /// A degenerate lone 1×1 EMPTY table: `selectAllText` would collapse to a caret (its single empty cell is the
    /// only renderable position), so Backspace would just do an in-cell delete and leave the table. selectAllText
    /// selects the structural range instead, so Backspace resets to an empty paragraph.
    func test_selectAll_backspace_lone1x1EmptyTable_resetsToEmptyParagraph() {
        let emptyCell = Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: []))])
        let v = canvas([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 90)],
            rows: [Row(id: BlockID("r0"), isHeader: false, cells: [emptyCell])]))])
        v.selectAllText()
        v.deleteBackward()
        v.layoutIfNeeded()
        assertSingleEmptyParagraph(v, "lone 1x1 empty table")
    }

    /// A PARTIAL cross-cell selection within a lone table must KEEP the table (clear the covered cells) — the
    /// per-cell delete behavior the whole-document reset must not steal.
    func test_partialSelect_inLoneTable_keepsTable() {
        let v = canvas([table()])
        let t = v.boxes.first { $0 is TableBlockBox } as! TableBlockBox
        // cell(0,0) → cell(1,0): covers some, not all, cells (never reaches the last cell).
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.deleteBackward()
        v.layoutIfNeeded()
        XCTAssertNotNil(v.boxes.first { $0 is TableBlockBox }, "a partial in-table selection keeps the table")
    }
}
#endif

#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Backspace with a table structural (row/column) selection deletes the selected rows / columns. Selecting
/// EVERY row or EVERY column (which would empty the table) instead removes the whole table block, replacing
/// it in place with an empty body paragraph (caret there).
final class CanvasTableBackspaceDeleteTests: XCTestCase {
    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    private func row(_ id: String, _ texts: [String], header: Bool = false) -> Row {
        Row(id: BlockID(id), isHeader: header, cells: texts.enumerated().map { cell(id + "\($0.offset)", $0.element) })
    }
    /// [ "Top", table(3 rows × 3 cols, r0 header), "Bot" ]
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"),
                columns: [ColumnSpec(width: 90), ColumnSpec(width: 90), ColumnSpec(width: 90)],
                rows: [row("r0", ["A", "B", "C"], header: true),
                       row("r1", ["d", "e", "f"]),
                       row("r2", ["g", "h", "i"])])),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        return v
    }
    private func tableBox(_ v: DocumentCanvasView) -> TableBlockBox? { v.boxes.first { $0 is TableBlockBox } as? TableBlockBox }
    private func putCaretInTable(_ v: DocumentCanvasView) {
        v.setSelectionForTesting(anchor: tableBox(v)!.cellTextStart(row: 1, column: 1)!, head: tableBox(v)!.cellTextStart(row: 1, column: 1)!)
    }
    private func paraTexts(_ v: DocumentCanvasView) -> [String] {
        v.currentBlocks().compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
    }

    func test_backspace_withPartialRowSelection_deletesSelectedRows() {
        let v = canvas()
        putCaretInTable(v)
        v.selectTableRows(1...1)                 // one body row, not all
        v.deleteBackward()
        v.layoutIfNeeded()
        XCTAssertNotNil(tableBox(v), "the table is kept")
        XCTAssertEqual(tableBox(v)!.rowCount, 2, "the selected body row is removed")
        XCTAssertEqual(paraTexts(v), ["Top", "Bot"], "surrounding paragraphs intact")
        XCTAssertNil(v.tableSelection, "the structural selection is cleared")
    }

    func test_backspace_withAllRowsSelected_replacesTableWithEmptyParagraph() {
        let v = canvas()
        putCaretInTable(v)
        v.selectTableRows(0...2)                 // every row (header + both body rows)
        v.deleteBackward()
        v.layoutIfNeeded()
        XCTAssertNil(tableBox(v), "the whole table is removed")
        XCTAssertEqual(v.boxes.count, 3, "Top | empty paragraph | Bot")
        XCTAssertTrue(v.boxes[1] is BlockBox)
        XCTAssertEqual((v.boxes[1] as! BlockBox).textLength, 0, "the table is replaced by an empty paragraph in place")
        XCTAssertEqual((v.boxes[1] as! BlockBox).style, .body)
        XCTAssertEqual(paraTexts(v), ["Top", "", "Bot"])
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands in the new empty paragraph")
        XCTAssertNil(v.tableSelection)
    }

    func test_backspace_withPartialColumnSelection_deletesSelectedColumns() {
        let v = canvas()
        putCaretInTable(v)
        v.selectTableColumns(1...1)
        v.deleteBackward()
        v.layoutIfNeeded()
        XCTAssertNotNil(tableBox(v))
        XCTAssertEqual(tableBox(v)!.columnCount, 2, "the selected column is removed from every row")
        XCTAssertNil(v.tableSelection)
    }

    func test_backspace_withAllColumnsSelected_replacesTableWithEmptyParagraph() {
        let v = canvas()
        putCaretInTable(v)
        v.selectTableColumns(0...2)
        v.deleteBackward()
        v.layoutIfNeeded()
        XCTAssertNil(tableBox(v), "the whole table is removed")
        XCTAssertEqual(v.boxes.count, 3, "Top | empty paragraph | Bot")
        XCTAssertEqual((v.boxes[1] as! BlockBox).textLength, 0)
        XCTAssertEqual(v.head, v.boxes[1].textStart)
    }

    func test_backspace_allRows_whenTableIsOnlyBlock_leavesSingleEmptyParagraph() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .table(TableBlock(id: BlockID("t"),
                columns: [ColumnSpec(width: 90), ColumnSpec(width: 90)],
                rows: [row("r0", ["A", "B"], header: true), row("r1", ["c", "d"])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        v.setSelectionForTesting(anchor: tableBox(v)!.cellTextStart(row: 0, column: 0)!, head: tableBox(v)!.cellTextStart(row: 0, column: 0)!)
        v.selectTableRows(0...1)
        v.deleteBackward()
        v.layoutIfNeeded()
        XCTAssertEqual(v.boxes.count, 1, "the document collapses to a single empty paragraph")
        XCTAssertTrue(v.boxes[0] is BlockBox)
        XCTAssertEqual((v.boxes[0] as! BlockBox).textLength, 0)
    }

    func test_backspace_structuralRowDelete_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        putCaretInTable(v)
        v.selectTableRows(1...1)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertEqual(tableBox(v)!.rowCount, 2)
        um.undo(); v.layoutIfNeeded()
        XCTAssertEqual(tableBox(v)!.rowCount, 3, "undo restores the deleted row")
    }

    func test_backspace_allRowsDelete_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        putCaretInTable(v)
        v.selectTableRows(0...2)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertNil(tableBox(v))
        um.undo(); v.layoutIfNeeded()
        XCTAssertNotNil(tableBox(v), "undo restores the whole table")
        XCTAssertEqual(tableBox(v)!.rowCount, 3)
    }
}
#endif

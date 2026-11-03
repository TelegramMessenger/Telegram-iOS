#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasTableCommandTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    /// A 2-col table: header row (r0) + one body row (r1), inside a doc with paragraphs around it.
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Name"), cell("b", "Role")]),
                       Row(id: BlockID("r1"), cells: [cell("c", "Ada"), cell("d", "Eng")])])),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 700); v.layoutIfNeeded()
        return v
    }
    func table(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes.first { $0 is TableBlockBox } as! TableBlockBox }
    /// Put the caret into cell (row,col).
    func caret(_ v: DocumentCanvasView, row: Int, col: Int) {
        let pos = table(v).cellTextStart(row: row, column: col)!
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }
    /// documentSize must equal the Core token count for the current content.
    func assertSpansMatchCore(_ v: DocumentCanvasView, _ msg: String = "") {
        let doc = Document(blocks: v.currentBlocks())
        XCTAssertEqual(v.documentSizeValue, DocumentTree.documentSize(doc), "span math \(msg)")
    }

    func test_insertRowBelow_addsBodyRow_caretInIt_spansMatch() {
        let v = canvas()
        caret(v, row: 1, col: 0)
        v.insertTableRowBelow()
        v.layoutIfNeeded()
        XCTAssertEqual(table(v).rowCount, 3)
        XCTAssertFalse(table(v).isHeaderRow(2))
        XCTAssertEqual(v.head, table(v).cellTextStart(row: 2, column: 0), "caret in the new row")
        assertSpansMatchCore(v, "after insertRowBelow")
    }

    func test_insertRowAbove_fromHeader_insertsBelowHeader() {
        let v = canvas()
        caret(v, row: 0, col: 0)               // in the header
        v.insertTableRowAbove()
        v.layoutIfNeeded()
        XCTAssertEqual(table(v).rowCount, 3)
        XCTAssertTrue(table(v).isHeaderRow(0), "row 0 stays the header")
        XCTAssertFalse(table(v).isHeaderRow(1), "the new row landed at index 1, a body row")
    }

    func test_deleteRow_removesBodyRow() {
        let v = canvas()
        caret(v, row: 1, col: 0)
        v.deleteTableRow()
        v.layoutIfNeeded()
        XCTAssertEqual(table(v).rowCount, 1, "only the header remains")
        XCTAssertTrue(table(v).isHeaderRow(0))
        assertSpansMatchCore(v, "after deleteRow")
    }

    func test_deleteRow_onHeader_isNoOp() {
        let v = canvas()
        caret(v, row: 0, col: 0)
        v.deleteTableRow()
        v.layoutIfNeeded()
        XCTAssertEqual(table(v).rowCount, 2, "header is undeletable")
    }

    func test_insertRow_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        caret(v, row: 1, col: 0)
        um.beginUndoGrouping(); v.insertTableRowBelow(); um.endUndoGrouping()
        XCTAssertEqual(table(v).rowCount, 3)
        um.undo(); v.layoutIfNeeded()
        XCTAssertEqual(table(v).rowCount, 2, "undo restores the table")
    }

    func test_rowCommands_noOpWhenCaretOutsideTable() {
        let v = canvas()
        let top = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("top")) }!
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(top.globalStart),
                                                DocumentTextPosition(top.globalStart))
        v.insertTableRowBelow(); v.deleteTableRow()
        XCTAssertEqual(table(v).rowCount, 2, "no change when caret isn't in a table")
    }
}

extension CanvasTableCommandTests {
    func test_insertColumnRight_addsColumnPerRow_caretInIt_spansMatch() {
        let v = canvas()
        caret(v, row: 1, col: 0)
        v.insertTableColumnRight()
        v.layoutIfNeeded()
        XCTAssertEqual(table(v).columnCount, 3)
        for r in 0..<table(v).rowCount { XCTAssertEqual(table(v).cells[r].count, 3) }
        XCTAssertEqual(v.head, table(v).cellTextStart(row: 1, column: 1), "caret in the new column")
        assertSpansMatchCore(v, "after insertColumnRight")
    }

    func test_insertColumnLeft_insertsBeforeCaretColumn() {
        let v = canvas()
        caret(v, row: 1, col: 1)
        v.insertTableColumnLeft()
        v.layoutIfNeeded()
        XCTAssertEqual(table(v).columnCount, 3)
        XCTAssertEqual(v.head, table(v).cellTextStart(row: 1, column: 1), "caret in the inserted column")
    }

    func test_deleteColumn_removesColumnPerRow() {
        let v = canvas()
        caret(v, row: 1, col: 0)
        v.deleteTableColumn()
        v.layoutIfNeeded()
        XCTAssertEqual(table(v).columnCount, 1)
        for r in 0..<table(v).rowCount { XCTAssertEqual(table(v).cells[r].count, 1) }
        assertSpansMatchCore(v, "after deleteColumn")
    }

    func test_deleteColumn_atOneColumn_isNoOp() {
        let v = canvas()
        caret(v, row: 1, col: 0); v.deleteTableColumn(); v.layoutIfNeeded()  // now 1 column
        XCTAssertEqual(table(v).columnCount, 1)
        caret(v, row: 1, col: 0); v.deleteTableColumn(); v.layoutIfNeeded()  // guard kicks in
        XCTAssertEqual(table(v).columnCount, 1, "never delete the last column")
    }
}

extension CanvasTableCommandTests {
    private func cellAlignment(_ v: DocumentCanvasView, row: Int, col: Int) -> TextAlignment? {
        guard case .table(let out) = v.currentBlocks().first(where: { if case .table = $0 { return true } else { return false } }) else { return nil }
        return out.rows[row].cells[col].horizontalAlignment
    }
    private func cellVerticalAlignment(_ v: DocumentCanvasView, row: Int, col: Int) -> VerticalAlignment? {
        guard case .table(let out) = v.currentBlocks().first(where: { if case .table = $0 { return true } else { return false } }) else { return nil }
        return out.rows[row].cells[col].verticalAlignment
    }

    /// Collapsed caret, no structural selection → the setter falls back to the caret's single cell (Task 4:
    /// `selectedCellCoords`'s `activeTable()` branch), NOT the whole column or row.
    func test_setSelectionHorizontalAlignment_collapsed_appliesToCaretCellOnly() {
        let v = canvas()
        caret(v, row: 1, col: 1)
        v.setSelectionHorizontalAlignment(.right)
        v.layoutIfNeeded()
        XCTAssertEqual(cellAlignment(v, row: 1, col: 1), .right)
        XCTAssertEqual(cellAlignment(v, row: 1, col: 0), .center, "other column unchanged")
        XCTAssertEqual(cellAlignment(v, row: 0, col: 1), .center, "other row (same column) unchanged")
    }

    /// A row structural selection applies vertical alignment to every cell in the range; an un-selected row
    /// is untouched.
    func test_setSelectionVerticalAlignment_spansSelectedRow() {
        let v = canvas()
        caret(v, row: 1, col: 0)
        v.selectTableRows(1...1)
        v.setSelectionVerticalAlignment(.bottom)
        v.layoutIfNeeded()
        XCTAssertEqual(cellVerticalAlignment(v, row: 1, col: 0), .bottom)
        XCTAssertEqual(cellVerticalAlignment(v, row: 1, col: 1), .bottom)
        XCTAssertEqual(cellVerticalAlignment(v, row: 0, col: 0), .top, "the un-selected row is untouched")
        XCTAssertEqual(cellVerticalAlignment(v, row: 0, col: 1), .top, "the un-selected row is untouched")
    }

    func test_setSelectionHorizontalAlignment_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        caret(v, row: 1, col: 1)
        um.beginUndoGrouping(); v.setSelectionHorizontalAlignment(.right); um.endUndoGrouping()
        XCTAssertEqual(cellAlignment(v, row: 1, col: 1), .right)
        um.undo(); v.layoutIfNeeded()
        XCTAssertEqual(cellAlignment(v, row: 1, col: 1), .center, "undo restores alignment")
    }
}
#endif

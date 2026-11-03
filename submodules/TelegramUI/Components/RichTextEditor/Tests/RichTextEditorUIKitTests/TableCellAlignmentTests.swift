#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

@available(iOS 13.0, *)
final class TableCellAlignmentTests: XCTestCase {
    private func cell(_ id: String, _ text: String, h: TextAlignment = .center, v: VerticalAlignment = .top) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), style: .body,
            runs: [TextRun(text: text)]))], horizontalAlignment: h, verticalAlignment: v)
    }

    func test_currentBlock_roundTripsPerCellAlignment() {
        let table = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","A", h: .left), cell("b","B", h: .right, v: .bottom)])])
        let box = TableBlockBox(table: table, mapper: AttributedStringMapper(), width: 390)
        box.frame = CGRect(x: 0, y: 0, width: 390, height: 200); box.recompute()
        guard case .table(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.rows[0].cells[0].horizontalAlignment, .left)
        XCTAssertEqual(out.rows[0].cells[1].horizontalAlignment, .right)
        XCTAssertEqual(out.rows[0].cells[1].verticalAlignment, .bottom)
    }

    func test_verticalAlignment_offsetsCellContentWithinTallRow() {
        // Column 0 is a single short line; column 1 is forced tall so the row has free vertical space.
        let tall = "L1\nL2\nL3\nL4"
        let table = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [
                cell("a", "short", v: .bottom),
                Cell(id: BlockID("b"), blocks: tall.split(separator: "\n").enumerated().map { i, s in
                    .paragraph(ParagraphBlock(id: BlockID("b\(i)"), style: .body, runs: [TextRun(text: String(s))])) })
            ])])
        let box = TableBlockBox(table: table, mapper: AttributedStringMapper(), width: 390)
        box.frame = CGRect(x: 0, y: 0, width: 390, height: 400); box.recompute()
        // `BlockStack` itself carries no `frame` — its child boxes do. The cell's stack holds one
        // paragraph `BlockBox`, whose `frame.minY` is the laid-out content origin (see `BlockStack.layout`:
        // the first box in a stack is placed at exactly `origin.y`, and with `verticalInsetBase == 0` for a
        // cell stack, its `topInset` is 0 too, so no additional offset hides inside the box itself).
        let shortStack = box.cells[0][0]
        let cellTopY = box.cellRect(row: 0, column: 0)!.minY
        let pad = TableBlockBox.cellVerticalPadding
        // Bottom-aligned short content sits well BELOW the top padding line (there is free space in the tall row).
        XCTAssertGreaterThan(shortStack.boxes[0].frame.minY, cellTopY + pad + 1.0)
    }

    func test_verticalAlignment_topIsUnchanged() {
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 200)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "x", v: .top)])])
        let box = TableBlockBox(table: table, mapper: AttributedStringMapper(), width: 390)
        box.frame = CGRect(x: 0, y: 0, width: 390, height: 200); box.recompute()
        let cellTopY = box.cellRect(row: 0, column: 0)!.minY
        XCTAssertEqual(box.cells[0][0].boxes[0].frame.minY, cellTopY + TableBlockBox.cellVerticalPadding, accuracy: 0.5)
    }

    func test_setSelectionHorizontalAlignment_setsSelectedColumnCells() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","A"), cell("b","B")]),
                   Row(id: BlockID("r1"), cells: [cell("c","C"), cell("d","D")])]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 400); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        v.selectTableColumn(1)
        v.setSelectionVerticalAlignment(.bottom)
        v.setSelectionHorizontalAlignment(.right)
        guard case .table(let out) = v.boxes[0].currentBlock() else { return XCTFail() }
        // Column 1 cells updated; column 0 untouched.
        XCTAssertEqual(out.rows[0].cells[1].horizontalAlignment, .right)
        XCTAssertEqual(out.rows[1].cells[1].verticalAlignment, .bottom)
        XCTAssertEqual(out.rows[0].cells[0].horizontalAlignment, .center, "column 0 untouched")
    }
}
#endif

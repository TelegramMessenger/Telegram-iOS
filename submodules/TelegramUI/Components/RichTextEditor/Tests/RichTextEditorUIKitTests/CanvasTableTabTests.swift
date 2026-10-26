#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasTableTabTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])]))], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 400); v.layoutIfNeeded()
        return v
    }

    func test_tabFromCellA_movesToCellB() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart + 1, head: cellA.globalStart + 1)
        v.moveToCell(forward: true)
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        XCTAssertEqual(v.head, cellB.globalStart)
    }

    func test_shiftTabFromCellB_movesToCellA() {
        let v = canvas()
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellB.globalStart + 1, head: cellB.globalStart + 1)
        v.moveToCell(forward: false)
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        XCTAssertEqual(v.head, cellA.globalStart)
    }

    /// A table followed by a paragraph "After".
    func canvasTableThenPara() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "After")])),
        ], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 400); v.layoutIfNeeded()
        return v
    }

    // Tab in the last cell exits to the START of the block after the table.
    func test_tabFromLastCell_exitsToBlockAfterTable() {
        let v = canvasTableThenPara()
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let after = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("after")) }!
        v.setSelectionForTesting(anchor: cellB.globalStart + 1, head: cellB.globalStart + 1)
        v.moveToCell(forward: true)
        XCTAssertEqual(v.head, after.globalStart, "Tab in the last cell moves to the start of the block after the table")
        XCTAssertEqual(v.anchor, v.head)
        guard case .table(let model) = (v.boxes.first as! TableBlockBox).currentBlock() else { return XCTFail() }
        XCTAssertEqual(model.rowCount, 1, "no row appended on exit")
    }

    // Tab in the last cell of a document-ending table is a no-op (no block after; no row appended).
    func test_tabFromLastCell_tableIsLastBlock_isNoOp() {
        let v = canvas()   // table is the only block
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellB.globalStart + 1, head: cellB.globalStart + 1)
        let before = v.head
        v.moveToCell(forward: true)
        XCTAssertEqual(v.head, before, "no block after the table → no-op")
        guard case .table(let model) = (v.boxes.first as! TableBlockBox).currentBlock() else { return XCTFail() }
        XCTAssertEqual(model.rowCount, 1, "Tab no longer appends a row")
    }

    // Tab exit when the block after the table is an IMAGE → the gap before the image.
    func test_tabFromLastCell_exitsToImageGap() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50))),
        ], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 500); v.layoutIfNeeded()
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let imageBox = v.boxes.first { $0 is MediaBlockBox }!
        v.setSelectionForTesting(anchor: cellB.globalStart + 1, head: cellB.globalStart + 1)
        v.moveToCell(forward: true)
        XCTAssertEqual(v.head, imageBox.nodeStart, "Tab exits to the gap before the image after the table")
    }

    // Tab exit when the block after the table is ANOTHER table → its first cell.
    func test_tabFromLastCell_exitsToNextTableFirstCell() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .table(TableBlock(id: BlockID("t1"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
            .table(TableBlock(id: BlockID("t2"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
                rows: [Row(id: BlockID("r1"), cells: [cell("c", "Gamma"), cell("d", "Delta")])])),
        ], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 600); v.layoutIfNeeded()
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let cellC = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("cp")) }!   // table 2's (0,0)
        v.setSelectionForTesting(anchor: cellB.globalStart + 1, head: cellB.globalStart + 1)
        v.moveToCell(forward: true)
        XCTAssertEqual(v.head, cellC.globalStart, "Tab exits to the first cell of the following table")
    }

    // `appendRow` (the model op behind the future Phase 3c insert-row command) still works directly.
    func test_appendRow_addsEmptyRowToModel() {
        let v = canvas()
        let table = v.boxes.first as! TableBlockBox
        table.appendRow()
        XCTAssertEqual(table.rowCount, 2)
        guard case .table(let model) = table.currentBlock() else { return XCTFail() }
        XCTAssertEqual(model.rows[1].cells.count, 2)
        if case .paragraph(let p) = model.rows[1].cells[0].blocks[0] { XCTAssertTrue(p.text.isEmpty) }
        else { XCTFail("new cell should hold an empty paragraph") }
    }
}
#endif

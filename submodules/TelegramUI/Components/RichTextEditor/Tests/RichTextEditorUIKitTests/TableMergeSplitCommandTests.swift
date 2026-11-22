#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Phase 2c-T2: `mergeSelectedCells()` / `splitSelectedCell()` commands and the Merge/Split entries in
/// the `.cells` structural menu.
final class TableMergeSplitCommandTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    /// A dense 3×3 table (no header) so a 2×2 merge in the top-left corner leaves the last row/column
    /// (P, Q, R, X, Y) intact and observable.
    ///   A B X
    ///   C D Y
    ///   P Q R
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .table(TableBlock(id: BlockID("t"),
                columns: [ColumnSpec(width: 120), ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B"), cell("x", "X")]),
                       Row(id: BlockID("r1"), cells: [cell("c", "C"), cell("d", "D"), cell("y", "Y")]),
                       Row(id: BlockID("r2"), cells: [cell("p", "P"), cell("q", "Q"), cell("r", "R")])])),
        ], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600); v.layoutIfNeeded()
        return v
    }
    func table(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes.first { $0 is TableBlockBox } as! TableBlockBox }
    func tableBlock(_ v: DocumentCanvasView) -> TableBlock {
        guard case .table(let t) = v.boxes.first { $0 is TableBlockBox }!.currentBlock() else { fatalError() }
        return t
    }
    func cellTexts(_ cell: Cell) -> [String] {
        cell.blocks.compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
    }
    func actionKinds(_ req: TableStructuralMenuRequest?) -> [TableStructuralMenuRequest.Kind] {
        req?.actions.map { $0.kind } ?? []
    }

    // MARK: - mergeSelectedCells

    func test_mergeSelectedCells_mergesRectAndConcatenatesContent() {
        let v = canvas(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))   // A, B, C, D
        v.mergeSelectedCells()
        v.layoutIfNeeded()

        let tb = tableBlock(v)
        let map = TableMap(tb)
        XCTAssertTrue(map.isWellFormed)

        guard let anchor = map.anchor(atRow: 0, column: 0) else { return XCTFail("no anchor at (0,0)") }
        XCTAssertEqual(anchor.colspan, 2)
        XCTAssertEqual(anchor.rowspan, 2)
        let anchorCell = tb.rows.flatMap { $0.cells }.first { $0.id == anchor.cellID }!
        XCTAssertEqual(cellTexts(anchorCell), ["A", "B", "C", "D"], "merged blocks concatenate row-major, anchor first")

        // Row 2 and the last column are untouched.
        XCTAssertEqual(cellTexts(tb.rows[0].cells.first { $0.id == BlockID("x") }!), ["X"])
        XCTAssertEqual(cellTexts(tb.rows[1].cells.first { $0.id == BlockID("y") }!), ["Y"])
        XCTAssertEqual(cellTexts(tb.rows[2].cells.first { $0.id == BlockID("p") }!), ["P"])
        XCTAssertEqual(cellTexts(tb.rows[2].cells.first { $0.id == BlockID("q") }!), ["Q"])
        XCTAssertEqual(cellTexts(tb.rows[2].cells.first { $0.id == BlockID("r") }!), ["R"])
    }

    func test_mergeSelectedCells_isUndoable_oneStep() {
        let v = canvas(); let t = table(v)
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))

        um.beginUndoGrouping(); v.mergeSelectedCells(); um.endUndoGrouping()
        v.layoutIfNeeded()
        XCTAssertEqual(TableMap(tableBlock(v)).anchor(atRow: 0, column: 0)?.colspan, 2, "merged")

        um.undo(); v.layoutIfNeeded()
        let restored = tableBlock(v)
        let restoredMap = TableMap(restored)
        XCTAssertEqual(restoredMap.anchor(atRow: 0, column: 0)?.colspan, 1, "undo restores the 4 separate cells")
        XCTAssertEqual(restoredMap.anchor(atRow: 0, column: 0)?.rowspan, 1)
        XCTAssertEqual(cellTexts(restored.rows[0].cells.first { $0.id == BlockID("a") }!), ["A"])
        XCTAssertEqual(cellTexts(restored.rows[0].cells.first { $0.id == BlockID("b") }!), ["B"])
        XCTAssertEqual(cellTexts(restored.rows[1].cells.first { $0.id == BlockID("c") }!), ["C"])
        XCTAssertEqual(cellTexts(restored.rows[1].cells.first { $0.id == BlockID("d") }!), ["D"])
    }

    func test_mergeSelectedCells_noopOnSingleCell() {
        let v = canvas(); let t = table(v)
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCell(row: 0, column: 0)   // a 1x1 rect

        v.mergeSelectedCells()
        v.layoutIfNeeded()

        XCTAssertFalse(um.canUndo, "a no-op merge must not register an undo entry")
        let tb = tableBlock(v)
        XCTAssertEqual(TableMap(tb).anchors.count, 9, "still 9 distinct cells, nothing merged")
    }

    // MARK: - splitSelectedCell

    func test_splitSelectedCell_restoresGrid() {
        let v = canvas(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        v.mergeSelectedCells()
        v.layoutIfNeeded()

        // Focus the merged cell: caret in it, no `.cells` selection.
        v.clearTableSelection()
        let t2 = table(v)
        v.setSelectionForTesting(anchor: t2.cellTextStart(row: 0, column: 0)!, head: t2.cellTextStart(row: 0, column: 0)!)
        XCTAssertNil(v.tableSelection)

        v.splitSelectedCell()
        v.layoutIfNeeded()

        let tb = tableBlock(v)
        let map = TableMap(tb)
        XCTAssertTrue(map.isWellFormed)
        XCTAssertEqual(map.anchors.count, 9, "back to 9 distinct single cells")
        let anchorAt00 = map.anchor(atRow: 0, column: 0)!
        XCTAssertEqual(anchorAt00.colspan, 1)
        XCTAssertEqual(anchorAt00.rowspan, 1)
        let anchorCell = tb.rows.flatMap { $0.cells }.first { $0.id == anchorAt00.cellID }!
        XCTAssertEqual(cellTexts(anchorCell), ["A", "B", "C", "D"], "the anchor keeps all the pooled content")
        // The other three re-materialized slots are fresh, empty cells.
        for (r, c) in [(0, 1), (1, 0), (1, 1)] {
            let a = map.anchor(atRow: r, column: c)!
            XCTAssertEqual(a.colspan, 1); XCTAssertEqual(a.rowspan, 1)
            let cellValue = tb.rows.flatMap { $0.cells }.first { $0.id == a.cellID }!
            XCTAssertEqual(cellTexts(cellValue), [""], "re-materialized cell is empty")
        }
    }

    func test_splitSelectedCell_noopWhenNotMerged() {
        let v = canvas(); let t = table(v)
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.splitSelectedCell()
        XCTAssertFalse(um.canUndo, "a no-op split must not register an undo entry")
        XCTAssertEqual(TableMap(tableBlock(v)).anchors.count, 9)
    }

    // MARK: - menu gating

    func test_menu_cellsSelection_offersMergeWhenMultiCell() {
        let v = canvas(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        let req = v.tableStructuralMenuRequest()
        let kinds = actionKinds(req)
        XCTAssertTrue(kinds.contains(.mergeCells))
        XCTAssertFalse(kinds.contains(.splitCell))
        XCTAssertNotNil(req?.alignment)
        XCTAssertNotNil(req?.header)
    }

    func test_menu_singleMergedCell_offersSplit() {
        let v = canvas(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        v.mergeSelectedCells()
        v.layoutIfNeeded()

        // Re-select the merged origin as a 1x1 `.cells` rect — `selectTableCells` expands it to the
        // merged footprint, so the map resolves to exactly ONE (already-merged) anchor.
        let t2 = table(v)
        v.setSelectionForTesting(anchor: t2.cellTextStart(row: 0, column: 0)!, head: t2.cellTextStart(row: 0, column: 0)!)
        v.selectTableCell(row: 0, column: 0)

        let kinds = actionKinds(v.tableStructuralMenuRequest())
        XCTAssertTrue(kinds.contains(.splitCell))
        XCTAssertFalse(kinds.contains(.mergeCells))
    }

    // MARK: - dense parity (rows/columns menu unchanged)

    func test_denseParity_columnMenuStillHasAddDeleteAlign_noMergeOrSplit() {
        let v = canvas(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(1)
        let kinds = actionKinds(v.tableStructuralMenuRequest())
        XCTAssertTrue(kinds.contains(.addColumnLeft))
        XCTAssertTrue(kinds.contains(.addColumnRight))
        XCTAssertTrue(kinds.contains(.deleteColumn))
        XCTAssertFalse(kinds.contains(.mergeCells))
        XCTAssertFalse(kinds.contains(.splitCell))
    }

    func test_denseParity_rowMenuStillHasAddDelete_noMergeOrSplit() {
        let v = canvas(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableRow(1)
        let kinds = actionKinds(v.tableStructuralMenuRequest())
        XCTAssertTrue(kinds.contains(.addRowAbove))
        XCTAssertTrue(kinds.contains(.addRowBelow))
        XCTAssertTrue(kinds.contains(.deleteRow))
        XCTAssertFalse(kinds.contains(.mergeCells))
        XCTAssertFalse(kinds.contains(.splitCell))
    }
}
#endif

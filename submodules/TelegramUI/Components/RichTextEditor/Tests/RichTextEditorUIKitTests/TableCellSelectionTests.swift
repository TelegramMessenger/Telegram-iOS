#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Phase 2c Task 1: `.cells(TableRect)` table-selection kind + its model plumbing. Model/plumbing only —
/// no drawing/gesture coverage here (that's T3/T4).
@available(iOS 13.0, *)
final class TableCellSelectionTests: XCTestCase {
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }

    /// A dense 3x3 table, ids "a".."i" row-major (row0: a,b,c; row1: d,e,f; row2: g,h,i).
    private func dense3x3() -> TableBlock {
        TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B"), cell("c", "C")]),
                Row(id: BlockID("r1"), cells: [cell("d", "D"), cell("e", "E"), cell("f", "F")]),
                Row(id: BlockID("r2"), cells: [cell("g", "G"), cell("h", "H"), cell("i", "I")]),
            ])
    }

    /// A 3x3 table with a colspan-2 cell merged at (0,0)-(0,1) (absorbing "b"'s content into "a"'s stack).
    private func mergedTopLeftColspan2() -> TableBlock {
        dense3x3().mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
    }

    private func canvas(_ table: TableBlock, width: CGFloat = 390) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table)], width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }

    private func table(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes[0] as! TableBlockBox }

    // MARK: - 1. selectedCellCoords dedupes and covers the rect

    func test_selectTableCells_selectedCellCoords_dedupesAndCoversRect() {
        let v = canvas(dense3x3())
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))

        let coords = v.selectedCellCoords(in: t)
        XCTAssertEqual(coords.count, 4, "no dupes — exactly the 4 cells in the 2x2 rect")
        let pairs = coords.map { [$0.row, $0.column] }
        XCTAssertEqual(pairs, [[0, 0], [0, 1], [1, 0], [1, 1]], "row-major order")
    }

    // MARK: - 2. Expands to whole merged cell

    func test_selectTableCells_expandsToWholeMergedCell() {
        let v = canvas(mergedTopLeftColspan2())
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        // Bisects the colspan-2 merged cell at (0,0)-(0,1): requesting only (0,0) must expand to include (0,1).
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))

        guard case .cells(let committed) = v.tableSelection?.kind else { return XCTFail("expected .cells") }
        XCTAssertEqual(committed, TableRect(top: 0, left: 0, bottom: 0, right: 1),
                       "committed rect is expanded to cover the whole merged cell")

        let coords = v.selectedCellCoords(in: t)
        XCTAssertEqual(coords.count, 1, "the merged cell is reported exactly ONCE, not once per covered slot")
        XCTAssertEqual(coords.first?.row, 0)
        XCTAssertEqual(coords.first?.column, 0)
    }

    // MARK: - 3. structuralCellRect + rowRange/columnRange nil for .cells

    func test_structuralCellRect_and_rangesNilForCells() {
        let v = canvas(dense3x3())
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))

        XCTAssertEqual(v.structuralCellRect(), TableRect(top: 0, left: 0, bottom: 1, right: 1))
        XCTAssertNil(v.structuralRowRange())
        XCTAssertNil(v.structuralColumnRange())
    }

    // MARK: - 4. tableStructuralSelectionRegions returns leaf regions of every covered cell

    func test_tableStructuralSelectionRegions_cells() {
        let v = canvas(dense3x3())
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))

        let regions = v.tableStructuralSelectionRegions()
        XCTAssertNotNil(regions)
        XCTAssertFalse(regions!.isEmpty)
        // Exactly the 4 covered cells' own leaf regions (one paragraph each, dense table).
        XCTAssertEqual(regions?.count, 4)
        let refs = regions!.map { $0.ref }
        for expected in [TextNodeRef.paragraph(BlockID("ap")), .paragraph(BlockID("bp")),
                         .paragraph(BlockID("dp")), .paragraph(BlockID("ep"))] {
            XCTAssertTrue(refs.contains(expected), "missing leaf region for \(expected)")
        }
    }

    // MARK: - 5. clearTableSelection clears .cells

    func test_clearTableSelection_clearsCells() {
        let v = canvas(dense3x3())
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        XCTAssertNotNil(v.tableSelection)
        v.clearTableSelection()
        XCTAssertNil(v.tableSelection)
    }

    // MARK: - 6. Dense parity: .rows/.columns behavior unchanged

    func test_denseParity_rowsAndColumnsSelectionUnchanged() {
        let v = canvas(dense3x3())
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableRow(1)
        XCTAssertEqual(v.tableSelection?.kind, .rows(1...1))
        XCTAssertEqual(v.head, t.cellTextStart(row: 1, column: 0))
        let rowCoords = v.selectedCellCoords(in: t)
        XCTAssertEqual(rowCoords.count, 3)

        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 2)!, head: t.cellTextStart(row: 0, column: 2)!)
        v.selectTableColumn(2)
        XCTAssertEqual(v.tableSelection?.kind, .columns(2...2))
        XCTAssertEqual(v.head, t.cellTextStart(row: 0, column: 2))
        let colCoords = v.selectedCellCoords(in: t)
        XCTAssertEqual(colCoords.count, 3)
    }

    // MARK: - Single-cell convenience

    func test_selectTableCell_singleCellConvenience() {
        let v = canvas(dense3x3())
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCell(row: 1, column: 1)
        XCTAssertEqual(v.tableSelection?.kind, .cells(TableRect(top: 1, left: 1, bottom: 1, right: 1)))
        XCTAssertEqual(v.head, t.cellTextStart(row: 1, column: 1))
    }
}
#endif

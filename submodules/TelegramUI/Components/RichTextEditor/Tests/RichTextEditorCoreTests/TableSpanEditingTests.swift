import XCTest
@testable import RichTextEditorCore

/// Covers the SPAN-AWARE `TableBlock.insertingColumn(at:width:)` / `removingColumn(at:)` /
/// `removingColumns(in:)` transforms — the Task 4 follow-up to the dense-grid-only originals in
/// `TableBlockEditingTests`. Every case asserts `TableMap(result).isWellFormed` (the covering-map
/// invariant these transforms must preserve).
final class TableSpanEditingTests: XCTestCase {

    // MARK: Fixtures (mirrors `TableMergeSplitTests`' pattern)

    /// A dense table built from a row-major grid of labels; each cell is a single labelled-text
    /// paragraph (label used as both the cell's `BlockID` and its plain text).
    private func denseTable(_ labels: [[String]], columnWidths: Double = 100) -> TableBlock {
        let columnCount = labels.first?.count ?? 0
        let columns = (0..<columnCount).map { _ in ColumnSpec(width: columnWidths) }
        let rows: [Row] = labels.enumerated().map { (r, rowLabels) in
            Row(id: BlockID("r\(r)"), cells: rowLabels.map { labelledCell($0) })
        }
        return TableBlock(id: BlockID("t"), columns: columns, rows: rows)
    }

    private func labelledCell(_ label: String, colspan: Int = 1, rowspan: Int = 1, isHeader: Bool = false) -> Cell {
        Cell(id: BlockID(label),
             blocks: [.paragraph(ParagraphBlock(id: BlockID(label + "_p"), runs: [TextRun(text: label)]))],
             isHeader: isHeader, colspan: colspan, rowspan: rowspan)
    }

    /// The plain texts of a cell's paragraph blocks, in declaration order.
    private func texts(of cell: Cell) -> [String] {
        cell.blocks.compactMap { block -> String? in
            guard case .paragraph(let p) = block else { return nil }
            return p.text
        }
    }

    private func cellByID(_ id: String, in table: TableBlock) -> Cell? {
        for row in table.rows {
            if let c = row.cells.first(where: { $0.id == BlockID(id) }) { return c }
        }
        return nil
    }

    // MARK: 1. Insert interior to a colspan-2 cell

    func test_insertingColumn_interiorToColspan2Cell_growsColspanNoNewCell() {
        // Row: M(colspan2) spans cols 0-1, N at col 2.
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [labelledCell("M", colspan: 2), labelledCell("N")])])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let inserted = table.insertingColumn(at: 1, width: 50)   // interior to M's span
        XCTAssertEqual(inserted.columnCount, 4)
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        XCTAssertEqual(inserted.rows[0].cells.count, 2, "no new cell declared — M grows instead")
        let m = cellByID("M", in: inserted)!
        XCTAssertEqual(m.colspan, 3, "M absorbs the interior column")
        XCTAssertEqual(m.rowspan, 1)
        XCTAssertEqual(texts(of: m), ["M"], "content preserved")

        let map = TableMap(inserted)
        XCTAssertEqual(map.anchor(atRow: 0, column: 0)?.cellID, BlockID("M"))
        XCTAssertEqual(map.anchor(atRow: 0, column: 2)?.cellID, BlockID("M"), "M now covers cols 0-2")
        XCTAssertEqual(map.anchor(atRow: 0, column: 3)?.cellID, BlockID("N"))
    }

    // MARK: 2. Insert at a clean boundary

    func test_insertingColumn_atCleanBoundary_addsFreshCellPerRow() {
        let table = denseTable([["A", "B"], ["C", "D"]])
        let inserted = table.insertingColumn(at: 1, width: 50)   // between col0 and col1
        XCTAssertEqual(inserted.columnCount, 3)
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        for row in inserted.rows {
            XCTAssertEqual(row.cells.count, 3, "every row gains a fresh cell, none mid-span here")
        }
        XCTAssertEqual(texts(of: inserted.rows[0].cells[0]), ["A"])
        XCTAssertEqual(texts(of: inserted.rows[0].cells[1]), [""], "fresh cell lands between A and B")
        XCTAssertEqual(texts(of: inserted.rows[0].cells[2]), ["B"])
        XCTAssertEqual(texts(of: inserted.rows[1].cells[1]), [""], "fresh cell lands between C and D too")
    }

    // MARK: 3. Insert at the right edge

    func test_insertingColumn_atRightEdge_appendsFreshTrailingCellPerRow() {
        let table = denseTable([["A", "B"], ["C", "D"]])
        let inserted = table.insertingColumn(at: 2, width: 50)   // ci == columns
        XCTAssertEqual(inserted.columnCount, 3)
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        for row in inserted.rows {
            XCTAssertEqual(row.cells.count, 3)
            XCTAssertEqual(texts(of: row.cells[2]), [""], "fresh trailing cell")
        }
    }

    // MARK: 4. Remove a column crossing a colspan-3 cell

    func test_removingColumn_crossingColspan3Cell_shrinksToColspan2() {
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [labelledCell("M", colspan: 3)])])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let removed = table.removingColumn(at: 1)   // interior column
        XCTAssertEqual(removed.columnCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)

        let m = cellByID("M", in: removed)!
        XCTAssertEqual(m.colspan, 2)
        XCTAssertEqual(texts(of: m), ["M"], "content preserved")
    }

    // MARK: 5. Remove the ORIGIN column of a colspan-2 cell (re-homing)

    func test_removingColumn_atOrigin_reHomesToNextColumn() {
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [labelledCell("A"), labelledCell("M", colspan: 2)])])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let removed = table.removingColumn(at: 1)   // M's origin column
        XCTAssertEqual(removed.columnCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)

        let m = cellByID("M", in: removed)!
        XCTAssertEqual(m.colspan, 1, "shrunk by one")
        XCTAssertEqual(texts(of: m), ["M"], "content preserved")

        let map = TableMap(removed)
        XCTAssertEqual(map.anchor(atRow: 0, column: 0)?.cellID, BlockID("A"))
        XCTAssertEqual(map.anchor(atRow: 0, column: 1)?.cellID, BlockID("M"), "M re-homed to the surviving column")
    }

    // MARK: 6. Remove a column of a colspan-1 cell

    func test_removingColumn_colspan1_removesCellEntirely() {
        let table = denseTable([["A", "B", "C"]])
        let removed = table.removingColumn(at: 1)
        XCTAssertEqual(removed.columnCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)
        XCTAssertNil(cellByID("B", in: removed), "B is gone entirely")
        XCTAssertEqual(removed.rows[0].cells.map(\.id), [BlockID("A"), BlockID("C")])
    }

    // MARK: 7. removingColumns over a range never empties the table

    func test_removingColumns_overSpannedTable_neverEmptiesAndStaysWellFormed() {
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [labelledCell("M", colspan: 3)])])
        let removed = table.removingColumns(in: 0...2)
        XCTAssertEqual(removed.columnCount, 1, "always leaves at least one column")
        XCTAssertTrue(TableMap(removed).isWellFormed)
    }

    func test_removingColumns_partialRangeOverSpannedTable_isWellFormed() {
        // M(colspan2) at cols 0-1, N at col 2, O at col 3.
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [labelledCell("M", colspan: 2), labelledCell("N"), labelledCell("O")])])
        let removed = table.removingColumns(in: 1...2)   // crosses M's right column + all of N
        XCTAssertEqual(removed.columnCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)
        let m = cellByID("M", in: removed)!
        XCTAssertEqual(m.colspan, 1, "M shrinks by the one column of its span that was removed")
        XCTAssertNil(cellByID("N", in: removed), "N (colspan1, fully in range) is gone")
        XCTAssertNotNil(cellByID("O", in: removed), "O survives outside the range")
    }

    // MARK: 8. Dense grid insert/remove matches the pre-span semantics

    func test_denseGrid_insertRemove_matchesPreSpanCellCounts() {
        let table = denseTable([["A", "B"], ["C", "D"]])

        let inserted = table.insertingColumn(at: 1, width: 90)
        XCTAssertEqual(inserted.columnCount, 3)
        for row in inserted.rows { XCTAssertEqual(row.cells.count, 3, "every row gains a cell") }
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        let removed = table.removingColumn(at: 0)
        XCTAssertEqual(removed.columnCount, 1)
        for row in removed.rows { XCTAssertEqual(row.cells.count, 1) }
        XCTAssertTrue(TableMap(removed).isWellFormed)
    }

    // MARK: 9. Rowspan regressions (grow-pass predicate + covered-not-declared classification)

    /// Insert at a rowspan cell's OWN origin column: the column is a clean boundary for every row the
    /// cell covers (its origin column), so a fresh cell is spliced into BOTH rows (including the row that
    /// only COVERS, never declares, the cell) and the rowspan cell re-homes one column right — its
    /// `colspan` must NOT grow.
    func test_insertingColumn_atRowspanCellOriginColumn_splicesFreshCellPerCoveredRowNoGrowth() {
        // 2x2: C(rowspan2) at col0 covering rows 0-1; A at (0,1); B at (1,1) (row 1 declares only B).
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [labelledCell("C", rowspan: 2), labelledCell("A")]),
                Row(id: BlockID("r1"), cells: [labelledCell("B")]),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let inserted = table.insertingColumn(at: 0, width: 50)   // C's own origin column
        XCTAssertEqual(inserted.columnCount, 3)
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        let c = cellByID("C", in: inserted)!
        XCTAssertEqual(c.colspan, 1, "C did NOT grow — the boundary is at its origin, not interior")
        XCTAssertEqual(c.rowspan, 2, "rowspan untouched")
        XCTAssertEqual(texts(of: c), ["C"], "content preserved")

        // Both covered rows gained a fresh cell at declaration index 0 (new column 0).
        XCTAssertEqual(inserted.rows[0].cells.count, 3, "row 0: fresh + C + A")
        XCTAssertEqual(inserted.rows[1].cells.count, 2, "row 1 (covered-not-declared at old col0): fresh + B")
        XCTAssertEqual(texts(of: inserted.rows[0].cells[0]), [""])
        XCTAssertEqual(texts(of: inserted.rows[1].cells[0]), [""])

        let map = TableMap(inserted)
        XCTAssertEqual(map.anchor(atRow: 0, column: 1)?.cellID, BlockID("C"), "C re-homed to column 1")
        XCTAssertEqual(map.anchor(atRow: 1, column: 1)?.cellID, BlockID("C"), "C still covers row 1 at column 1")
        XCTAssertEqual(map.anchor(atRow: 0, column: 2)?.cellID, BlockID("A"))
        XCTAssertEqual(map.anchor(atRow: 1, column: 2)?.cellID, BlockID("B"))
    }

    /// A colspan2/rowspan2 cell M straddling the new boundary grows its colspan EXACTLY ONCE (2→3), not
    /// once per covered row, and no fresh cell is spliced into any row it covers at that boundary.
    private func spannedTable_M2x2() -> TableBlock {
        // 2x3: M colspan2/rowspan2 at (0,0) covering cols 0-1 rows 0-1; N at (0,2); P at (1,2).
        TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [labelledCell("M", colspan: 2, rowspan: 2), labelledCell("N")]),
                Row(id: BlockID("r1"), cells: [labelledCell("P")]),
            ])
    }

    func test_insertingColumn_interiorToColspanRowspanCell_growsExactlyOnce() {
        let table = spannedTable_M2x2()
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let inserted = table.insertingColumn(at: 1, width: 50)   // strictly inside M's col span (0-1)
        XCTAssertEqual(inserted.columnCount, 4)
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        let m = cellByID("M", in: inserted)!
        XCTAssertEqual(m.colspan, 3, "grew once (2→3), NOT once per covered row")
        XCTAssertEqual(m.rowspan, 2)
        XCTAssertEqual(texts(of: m), ["M"], "content preserved")

        XCTAssertEqual(inserted.rows[0].cells.count, 2, "no fresh cell in M's rows: M + N")
        XCTAssertEqual(inserted.rows[1].cells.count, 1, "no fresh cell in M's rows: just P")

        let map = TableMap(inserted)
        XCTAssertEqual(map.anchor(atRow: 0, column: 2)?.cellID, BlockID("M"), "M now covers cols 0-2")
        XCTAssertEqual(map.anchor(atRow: 1, column: 2)?.cellID, BlockID("M"))
        XCTAssertEqual(map.anchor(atRow: 0, column: 3)?.cellID, BlockID("N"))
        XCTAssertEqual(map.anchor(atRow: 1, column: 3)?.cellID, BlockID("P"))
    }

    func test_removingColumn_crossingColspanRowspanCell_shrinksExactlyOnce() {
        let table = spannedTable_M2x2()
        let removed = table.removingColumn(at: 1)   // one of M's two spanned columns
        XCTAssertEqual(removed.columnCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)

        let m = cellByID("M", in: removed)!
        XCTAssertEqual(m.colspan, 1, "shrank once (2→1), NOT once per covered row")
        XCTAssertEqual(m.rowspan, 2, "rowspan untouched")
        XCTAssertEqual(texts(of: m), ["M"], "content preserved")

        let map = TableMap(removed)
        XCTAssertEqual(map.anchor(atRow: 0, column: 0)?.cellID, BlockID("M"))
        XCTAssertEqual(map.anchor(atRow: 1, column: 0)?.cellID, BlockID("M"), "M still spans both rows at col 0")
        XCTAssertEqual(map.anchor(atRow: 0, column: 1)?.cellID, BlockID("N"))
        XCTAssertEqual(map.anchor(atRow: 1, column: 1)?.cellID, BlockID("P"))
    }

    /// Removing the sole column of a colspan1/rowspan2 cell deletes the whole cell (declared once, in its
    /// origin row) — the covered-but-not-declared row must not double-remove or leave a dangling slot.
    func test_removingColumn_solingColumnOfColspan1Rowspan2Cell_removesWholeCell() {
        // 2x2: C(rowspan2) at col0 covering rows 0-1; A at (0,1); B at (1,1).
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [labelledCell("C", rowspan: 2), labelledCell("A")]),
                Row(id: BlockID("r1"), cells: [labelledCell("B")]),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let removed = table.removingColumn(at: 0)   // C's only column
        XCTAssertEqual(removed.columnCount, 1)
        XCTAssertTrue(TableMap(removed).isWellFormed)

        XCTAssertNil(cellByID("C", in: removed), "C removed entirely (from its single declaring row)")
        XCTAssertEqual(removed.rows[0].cells.map(\.id), [BlockID("A")])
        XCTAssertEqual(removed.rows[1].cells.map(\.id), [BlockID("B")])
    }

    func test_denseGrid_insertingColumn_preservesHeaderRow() {
        // Regression parity with `TableBlockEditingTests.test_insertingColumn_preservesHeaderRow`.
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("r0"), isHeader: true, cells: [Cell(id: BlockID("a")), Cell(id: BlockID("b"))]),
                Row(id: BlockID("r1"), cells: [Cell(id: BlockID("c")), Cell(id: BlockID("d"))]),
            ])
        let inserted = table.insertingColumn(at: 1, width: 90)
        XCTAssertTrue(inserted.rows[0].isHeader, "the header row stays a header row")
        XCTAssertFalse(inserted.rows[1].isHeader)
        XCTAssertTrue(TableMap(inserted).isWellFormed)
    }
}

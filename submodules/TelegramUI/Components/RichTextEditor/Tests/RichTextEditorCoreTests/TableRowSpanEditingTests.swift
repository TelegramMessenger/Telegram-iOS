import XCTest
@testable import RichTextEditorCore

/// Covers the SPAN-AWARE `TableBlock.insertingRow(at:)` / `removingRow(at:)` / `removingRows(in:)`
/// transforms — the Task 5 (row) transpose of Task 4's `TableSpanEditingTests` (column). Every case
/// asserts `TableMap(result).isWellFormed` (the covering-map invariant these transforms must preserve).
final class TableRowSpanEditingTests: XCTestCase {

    // MARK: Fixtures (mirrors `TableSpanEditingTests`' pattern)

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

    // MARK: 1. Insert interior to a rowspan-2 cell

    func test_insertingRow_interiorToRowspan2Cell_growsRowspanNoNewCellForThatColumn() {
        // Col0: C(rowspan2) spans rows 0-1. Col1: A at row0, B at row1.
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [labelledCell("C", rowspan: 2), labelledCell("A")]),
                Row(id: BlockID("r1"), cells: [labelledCell("B")]),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let inserted = table.insertingRow(at: 1)   // interior to C's span
        XCTAssertEqual(inserted.rowCount, 3)
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        let c = cellByID("C", in: inserted)!
        XCTAssertEqual(c.rowspan, 3, "C absorbs the interior row")
        XCTAssertEqual(c.colspan, 1)
        XCTAssertEqual(texts(of: c), ["C"], "content preserved")

        XCTAssertEqual(inserted.rows[1].cells.count, 1, "col0 skipped (C grows instead); only col1's fresh cell")
        XCTAssertEqual(texts(of: inserted.rows[1].cells[0]), [""], "the fresh cell lands at col1")

        let map = TableMap(inserted)
        XCTAssertEqual(map.anchor(atRow: 0, column: 0)?.cellID, BlockID("C"))
        XCTAssertEqual(map.anchor(atRow: 2, column: 0)?.cellID, BlockID("C"), "C now covers rows 0-2")
        XCTAssertEqual(map.anchor(atRow: 0, column: 1)?.cellID, BlockID("A"))
        XCTAssertEqual(map.anchor(atRow: 2, column: 1)?.cellID, BlockID("B"), "B shifted down to row 2")
    }

    // MARK: 2. Insert at a clean boundary

    func test_insertingRow_atCleanBoundary_addsFreshCellPerColumn() {
        let table = denseTable([["A", "B"], ["C", "D"]])
        let inserted = table.insertingRow(at: 1)   // between row0 and row1
        XCTAssertEqual(inserted.rowCount, 3)
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        XCTAssertEqual(inserted.rows[1].cells.count, 2, "every column gains a fresh cell, none mid-span here")
        XCTAssertEqual(texts(of: inserted.rows[1].cells[0]), [""])
        XCTAssertEqual(texts(of: inserted.rows[1].cells[1]), [""])

        XCTAssertEqual(texts(of: inserted.rows[0].cells[0]), ["A"], "row0 unaffected")
        XCTAssertEqual(texts(of: inserted.rows[2].cells[0]), ["C"], "old row1 shifted down to row2")
    }

    // MARK: 3. Insert at the bottom edge

    func test_insertingRow_atBottomEdge_appendsFreshTrailingRow() {
        let table = denseTable([["A", "B"], ["C", "D"]])
        let inserted = table.insertingRow(at: 2)   // ri == rows.count
        XCTAssertEqual(inserted.rowCount, 3)
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        XCTAssertEqual(inserted.rows[2].cells.count, 2)
        XCTAssertEqual(texts(of: inserted.rows[2].cells[0]), [""])
        XCTAssertEqual(texts(of: inserted.rows[2].cells[1]), [""])
    }

    // MARK: 4. Insert interior to a COLSPAN2+ROWSPAN2 cell

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

    func test_insertingRow_interiorToColspanRowspanCell_growsExactlyOnceSkipsBothColumns() {
        let table = spannedTable_M2x2()
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let inserted = table.insertingRow(at: 1)   // strictly inside M's row span (0-1)
        XCTAssertEqual(inserted.rowCount, 3)
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        let m = cellByID("M", in: inserted)!
        XCTAssertEqual(m.rowspan, 3, "grew once (2→3), NOT once per covered column")
        XCTAssertEqual(m.colspan, 2, "colspan untouched")
        XCTAssertEqual(texts(of: m), ["M"], "content preserved")

        XCTAssertEqual(inserted.rows[1].cells.count, 1, "both of M's columns skipped — only the fresh cell for col2")
        XCTAssertEqual(texts(of: inserted.rows[1].cells[0]), [""])

        let map = TableMap(inserted)
        XCTAssertEqual(map.anchor(atRow: 2, column: 0)?.cellID, BlockID("M"), "M now covers rows 0-2")
        XCTAssertEqual(map.anchor(atRow: 2, column: 1)?.cellID, BlockID("M"))
        XCTAssertEqual(map.anchor(atRow: 0, column: 2)?.cellID, BlockID("N"))
        XCTAssertEqual(map.anchor(atRow: 2, column: 2)?.cellID, BlockID("P"), "P shifted down to row 2")
    }

    // MARK: 5. Remove a row crossing a rowspan-3 cell (dedup across columns)

    func test_removingRow_crossingRowspan3Cell_shrinksToRowspan2Once() {
        // A single colspan2/rowspan3 cell filling the whole 2x3 grid.
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [labelledCell("M", colspan: 2, rowspan: 3)]),
                Row(id: BlockID("r1"), cells: []),
                Row(id: BlockID("r2"), cells: []),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let removed = table.removingRow(at: 1)   // interior row, crosses M at both columns
        XCTAssertEqual(removed.rowCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)

        let m = cellByID("M", in: removed)!
        XCTAssertEqual(m.rowspan, 2, "shrunk once (3→2), NOT once per covered column")
        XCTAssertEqual(m.colspan, 2, "colspan untouched")
        XCTAssertEqual(texts(of: m), ["M"], "content preserved")
    }

    // MARK: 6. Remove the ORIGIN row of a rowspan-2 cell (re-homing)

    func test_removingRow_atOrigin_reHomesToNextRow() {
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [labelledCell("A")]),
                Row(id: BlockID("r1"), cells: [labelledCell("M", rowspan: 2)]),
                Row(id: BlockID("r2"), cells: []),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let removed = table.removingRow(at: 1)   // M's origin row
        XCTAssertEqual(removed.rowCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)

        let m = cellByID("M", in: removed)!
        XCTAssertEqual(m.rowspan, 1, "shrunk by one")
        XCTAssertEqual(texts(of: m), ["M"], "content preserved")

        let map = TableMap(removed)
        XCTAssertEqual(map.anchor(atRow: 0, column: 0)?.cellID, BlockID("A"))
        XCTAssertEqual(map.anchor(atRow: 1, column: 0)?.cellID, BlockID("M"), "M re-homed to the surviving row")
    }

    // MARK: 7. Remove a row of a rowspan-1 cell

    func test_removingRow_rowspan1_removesCellEntirely() {
        let table = denseTable([["A", "B"], ["C", "D"], ["E", "F"]])
        let removed = table.removingRow(at: 1)
        XCTAssertEqual(removed.rowCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)
        XCTAssertNil(cellByID("C", in: removed), "C is gone entirely")
        XCTAssertNil(cellByID("D", in: removed), "D is gone entirely")
        XCTAssertEqual(removed.rows.map { $0.cells.map(\.id) }, [[BlockID("A"), BlockID("B")], [BlockID("E"), BlockID("F")]])
    }

    // MARK: 8. Remove crossing a colspan2+rowspan2 cell (shrink-in-place, non-origin row)

    func test_removingRow_crossingColspanRowspanCell_shrinksOnceColspanIntact() {
        let table = spannedTable_M2x2()
        let removed = table.removingRow(at: 1)   // M's non-origin (bottom) row
        XCTAssertEqual(removed.rowCount, 1)
        XCTAssertTrue(TableMap(removed).isWellFormed)

        let m = cellByID("M", in: removed)!
        XCTAssertEqual(m.rowspan, 1, "shrank once (2→1), NOT once per covered column")
        XCTAssertEqual(m.colspan, 2, "colspan untouched")
        XCTAssertEqual(texts(of: m), ["M"], "content preserved")
        XCTAssertNil(cellByID("P", in: removed), "P (rowspan1, wholly in the removed row) is gone")
        XCTAssertNotNil(cellByID("N", in: removed), "N survives (declared in the surviving row)")
    }

    // MARK: 9. removingRows never removes header rows, across spans, and stays well-formed

    func test_removingRows_neverRemovesHeaderRows_acrossSpans_staysWellFormed() {
        // Header row0 (H0,H1); body row1 = M(rowspan2)+A; body row2 = B (col0 covered by M); body row3 = C,D.
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), isHeader: true, cells: [labelledCell("H0", isHeader: true), labelledCell("H1", isHeader: true)]),
                Row(id: BlockID("r1"), cells: [labelledCell("M", rowspan: 2), labelledCell("A")]),
                Row(id: BlockID("r2"), cells: [labelledCell("B")]),
                Row(id: BlockID("r3"), cells: [labelledCell("C"), labelledCell("D")]),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let removed = table.removingRows(in: 0...3)   // range covers the header too
        XCTAssertEqual(removed.rowCount, 1, "only the header row survives")
        XCTAssertTrue(removed.rows[0].isHeader, "header row untouched")
        XCTAssertEqual(texts(of: removed.rows[0].cells[0]), ["H0"])
        XCTAssertEqual(texts(of: removed.rows[0].cells[1]), ["H1"])
        XCTAssertTrue(TableMap(removed).isWellFormed)
    }

    func test_removingRows_neverEmptiesToZeroRows() {
        // A range covering every row still leaves the header, matching the header-protection contract.
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), isHeader: true, cells: [labelledCell("H", isHeader: true)]),
                Row(id: BlockID("r1"), cells: [labelledCell("A")]),
            ])
        let removed = table.removingRows(in: 0...1)
        XCTAssertEqual(removed.rowCount, 1)
        XCTAssertTrue(removed.rows[0].isHeader)
        XCTAssertTrue(TableMap(removed).isWellFormed)
    }

    // MARK: 10. Dense grid insert/remove matches the pre-span semantics

    func test_denseGrid_insertRemove_matchesPreSpanRowCellCounts() {
        let table = denseTable([["A", "B"], ["C", "D"]])

        let inserted = table.insertingRow(at: 1)
        XCTAssertEqual(inserted.rowCount, 3)
        for row in inserted.rows { XCTAssertEqual(row.cells.count, 2, "every row has a cell per column") }
        XCTAssertTrue(TableMap(inserted).isWellFormed)

        let removed = table.removingRow(at: 0)
        XCTAssertEqual(removed.rowCount, 1)
        XCTAssertEqual(removed.rows[0].cells.count, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)
    }

    // MARK: 11. Multiple simultaneous transplants from one origin row (the running-counter path)

    /// Remove a row that is the ORIGIN of TWO rowspan>1 cells at once, with a pre-existing successor-row
    /// cell BETWEEN their columns. Both must transplant into the successor row at their correct covering
    /// columns, interleaved with the successor's own cells (so the successor ends up ordered by covering
    /// column). This is the highest-risk path — the `transplantedSoFar` running counter must keep the
    /// insertion indices correct as each transplant lands ahead of later ones.
    func test_removingRow_multipleTransplantsFromOneOriginRow_interleaveCorrectly() {
        // 5 cols. Row0 = header (all cells rowspan1). Row1 originates P(rowspan2)@col0 and Q(rowspan2)@col3,
        // with a plain cell R@col1..col2 area — actually: row1 declares P@0, R@1, S@2(? ) — keep it simple:
        // row1 = [P(rs2)@0, X@1, Y@2, Q(rs2)@3, Z@4]. Row2 declares its OWN cells only at cols 1,2,4
        // (cols 0 and 3 are covered by P and Q straddling down).
        let table = TableBlock(
            id: BlockID("t"),
            columns: (0..<5).map { _ in ColumnSpec(width: 100) },
            rows: [
                Row(id: BlockID("r0"), isHeader: true, cells: (0..<5).map { labelledCell("H\($0)", isHeader: true) }),
                Row(id: BlockID("r1"), cells: [
                    labelledCell("P", rowspan: 2), labelledCell("X"), labelledCell("Y"),
                    labelledCell("Q", rowspan: 2), labelledCell("Z"),
                ]),
                Row(id: BlockID("r2"), cells: [labelledCell("b1"), labelledCell("b2"), labelledCell("b4")]),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let removed = table.removingRow(at: 1)   // origin row of BOTH P and Q
        XCTAssertEqual(removed.rowCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)

        // P and Q survive, each rowspan decremented to 1, content preserved.
        let p = cellByID("P", in: removed)!
        let q = cellByID("Q", in: removed)!
        XCTAssertEqual(p.rowspan, 1)
        XCTAssertEqual(q.rowspan, 1)
        XCTAssertEqual(texts(of: p), ["P"])
        XCTAssertEqual(texts(of: q), ["Q"])

        // Row 1 (the former successor row, now at grid index 1) declares cells ordered by covering column:
        // P@0, b1@1, b2@2, Q@3, b4@4.
        let successor = removed.rows[1]
        XCTAssertEqual(successor.cells.map(\.id),
                       [BlockID("P"), BlockID("b1"), BlockID("b2"), BlockID("Q"), BlockID("b4")],
                       "both transplants interleave with the successor's own cells, ordered by covering column")

        let map = TableMap(removed)
        XCTAssertEqual(map.anchor(atRow: 1, column: 0)?.cellID, BlockID("P"))
        XCTAssertEqual(map.anchor(atRow: 1, column: 3)?.cellID, BlockID("Q"))
    }

    /// Two ADJACENT transplants (cols 0 and 1, no successor cell between them) stress the running counter's
    /// off-by-one: the second transplant must land at index 1, right after the first.
    func test_removingRow_adjacentTransplantsFromOneOriginRow_stayOrdered() {
        // 3 cols. Row0 header. Row1 = [P(rs2)@0, Q(rs2)@1, W@2]. Row2 declares only its own cell at col2.
        let table = TableBlock(
            id: BlockID("t"),
            columns: (0..<3).map { _ in ColumnSpec(width: 100) },
            rows: [
                Row(id: BlockID("r0"), isHeader: true, cells: (0..<3).map { labelledCell("H\($0)", isHeader: true) }),
                Row(id: BlockID("r1"), cells: [
                    labelledCell("P", rowspan: 2), labelledCell("Q", rowspan: 2), labelledCell("W"),
                ]),
                Row(id: BlockID("r2"), cells: [labelledCell("b2")]),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let removed = table.removingRow(at: 1)
        XCTAssertEqual(removed.rowCount, 2)
        XCTAssertTrue(TableMap(removed).isWellFormed)

        let successor = removed.rows[1]
        XCTAssertEqual(successor.cells.map(\.id), [BlockID("P"), BlockID("Q"), BlockID("b2")],
                       "adjacent transplants P,Q land at indices 0,1 ahead of the successor's own col-2 cell")
        XCTAssertEqual(cellByID("P", in: removed)!.rowspan, 1)
        XCTAssertEqual(cellByID("Q", in: removed)!.rowspan, 1)

        let map = TableMap(removed)
        XCTAssertEqual(map.anchor(atRow: 1, column: 0)?.cellID, BlockID("P"))
        XCTAssertEqual(map.anchor(atRow: 1, column: 1)?.cellID, BlockID("Q"))
        XCTAssertEqual(map.anchor(atRow: 1, column: 2)?.cellID, BlockID("b2"))
    }

    // MARK: 12. Transplanting a body cell INTO a header row (INTENTIONAL — pinned, not changed)

    /// A rowspan body cell straddling down into a header row, when its origin (body) row is removed,
    /// re-homes into the header row. The header row SURVIVES (header protection = not deleted, upheld),
    /// but its derived `isHeader` correctly flips to `false` because a body cell legitimately joined it.
    /// The transplanted cell KEEPS its own (body) `isHeader`; we do not stamp it to the row. This edge is
    /// only user-constructible once merge UI lands (Phase 2c) — re-confirm the product behavior then.
    func test_removingRow_transplantingBodyCellIntoHeaderRow_keepsCellSemantics_rowBecomesMixed() {
        // Row0 = body: M(rowspan2)@col0 (body) + A@col1 (body). Row1 = header: col0 covered by M straddling
        // down; H1(isHeader)@col1. (Row1 declares only H1; its col0 is M's footprint.)
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [labelledCell("M", rowspan: 2), labelledCell("A")]),
                Row(id: BlockID("r1"), cells: [labelledCell("H1", isHeader: true)]),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")
        XCTAssertFalse(table.rows[0].isHeader, "row0 is a body row")
        XCTAssertTrue(table.rows[1].isHeader, "row1 is a header row (its only declared cell is a header cell)")

        // removingRows over row 0 only: header row 1 is filtered out; the body origin row 0 is removed and
        // M transplants down into what was the header row.
        let removed = table.removingRows(in: 0...0)
        XCTAssertEqual(removed.rowCount, 1, "the header row survives — header protection holds (never deleted)")

        let survivor = removed.rows[0]
        XCTAssertEqual(survivor.cells.map(\.id), [BlockID("M"), BlockID("H1")],
                       "M re-homed into the surviving row at its covering column 0, before H1")
        let m = cellByID("M", in: removed)!
        XCTAssertEqual(m.rowspan, 1, "M shrank to rowspan 1")
        XCTAssertFalse(m.isHeader, "M keeps its own (body) header flag — not stamped to the destination row")
        XCTAssertTrue(cellByID("H1", in: removed)!.isHeader, "H1 keeps its header flag")
        XCTAssertFalse(survivor.isHeader, "the row is now MIXED — derived isHeader follows its actual cells (M is body)")
        XCTAssertTrue(TableMap(removed).isWellFormed)
    }
}

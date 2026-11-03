import XCTest
@testable import RichTextEditorCore

/// Covers the `TableMap` covering-map rebuild: slot→anchor resolution, rect dedupe, and rect expansion
/// over tables with merged (colspan/rowspan) cells. See TableMap.swift's Design doc for the API.
final class TableMapCoverageTests: XCTestCase {
    private func cell(_ s: String, colspan: Int = 1, rowspan: Int = 1) -> Cell {
        Cell(id: BlockID(s), colspan: colspan, rowspan: rowspan)
    }

    // MARK: 1. Dense grid (all spans 1)

    func test_denseGrid_allSpansOne() {
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a"), cell("b"), cell("c")]),
                Row(id: BlockID("r1"), cells: [cell("d"), cell("e"), cell("f")]),
            ])
        let m = TableMap(table)
        XCTAssertEqual(m.rows, 2)
        XCTAssertEqual(m.columns, 3)
        XCTAssertTrue(m.isWellFormed)

        let expected: [[String]] = [["a", "b", "c"], ["d", "e", "f"]]
        for r in 0..<2 {
            for c in 0..<3 {
                XCTAssertEqual(m.anchor(atRow: r, column: c)?.cellID, BlockID(expected[r][c]), "row \(r) col \(c)")
            }
        }
    }

    // MARK: 2. Colspan

    func test_colspan_singleRowTwoColumns() {
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", colspan: 2)]),
            ])
        let m = TableMap(table)
        XCTAssertTrue(m.isWellFormed)
        XCTAssertEqual(m.anchor(atRow: 0, column: 0)?.cellID, BlockID("a"))
        XCTAssertEqual(m.anchor(atRow: 0, column: 1)?.cellID, BlockID("a"))
        XCTAssertEqual(m.coveringRect(atRow: 0, column: 1), TableRect(top: 0, left: 0, bottom: 0, right: 1))
    }

    // MARK: 3. Rowspan

    func test_rowspan_twoRowsTwoColumns() {
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", rowspan: 2), cell("b")]),
                Row(id: BlockID("r1"), cells: [cell("c")]),
            ])
        let m = TableMap(table)
        XCTAssertTrue(m.isWellFormed)
        // The row-0/col-0 anchor covers slot (1, 0) too.
        XCTAssertEqual(m.anchor(atRow: 0, column: 0)?.cellID, BlockID("a"))
        XCTAssertEqual(m.anchor(atRow: 1, column: 0)?.cellID, BlockID("a"))
        // Row 1's lone cell lands at column 1 (column 0 is occupied by "a"'s rowspan).
        XCTAssertEqual(m.anchor(atRow: 1, column: 1)?.cellID, BlockID("c"))
        XCTAssertEqual(m.anchor(atRow: 0, column: 1)?.cellID, BlockID("b"))
    }

    // MARK: 4. 2x2 fully merged

    func test_fullyMergedTwoByTwo() {
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", colspan: 2, rowspan: 2)]),
                Row(id: BlockID("r1"), cells: []),
            ])
        let m = TableMap(table)
        XCTAssertTrue(m.isWellFormed)
        for r in 0..<2 {
            for c in 0..<2 {
                XCTAssertEqual(m.anchor(atRow: r, column: c)?.cellID, BlockID("a"), "row \(r) col \(c)")
            }
        }
        XCTAssertEqual(m.cellsInRect(TableRect(top: 0, left: 0, bottom: 1, right: 1)).count, 1)
    }

    // MARK: 5. cellsInRect dedupe

    func test_cellsInRect_dedupesOverlappingMergedCell() {
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", colspan: 2), cell("b")]),
                Row(id: BlockID("r1"), cells: [cell("c"), cell("d"), cell("e")]),
            ])
        let m = TableMap(table)
        XCTAssertTrue(m.isWellFormed)
        // Rect covers both slots of "a" plus "d" below column 1 — "a" should appear once.
        let rect = TableRect(top: 0, left: 0, bottom: 1, right: 1)
        let cells = m.cellsInRect(rect)
        let ids = cells.map { $0.cellID }
        XCTAssertEqual(ids, [BlockID("a"), BlockID("c"), BlockID("d")])
    }

    // MARK: 6. expanded

    func test_expanded_growsToWholeMergedCellOnEachEdge() {
        // Grid:
        // a a b
        // a a c
        // d e f
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", colspan: 2, rowspan: 2), cell("b")]),
                Row(id: BlockID("r1"), cells: [cell("c")]),
                Row(id: BlockID("r2"), cells: [cell("d"), cell("e"), cell("f")]),
            ])
        let m = TableMap(table)
        XCTAssertTrue(m.isWellFormed)

        // Rect covering only slot (0,0) touches "a" (which spans rows 0-1, cols 0-1) on both its right
        // and bottom edges, so it must grow on both axes to (0,0)-(1,1).
        let touchesOneCorner = TableRect(top: 0, left: 0, bottom: 0, right: 0)
        XCTAssertEqual(m.expanded(touchesOneCorner), TableRect(top: 0, left: 0, bottom: 1, right: 1))

        // Rect already spanning both of "a"'s columns but only its top row still straddles "a" on the
        // bottom edge and must grow to include row 1.
        let bisectBottom = TableRect(top: 0, left: 0, bottom: 0, right: 1)
        XCTAssertEqual(m.expanded(bisectBottom), TableRect(top: 0, left: 0, bottom: 1, right: 1))

        // A rect exactly matching "a"'s footprint should not grow further.
        let exact = TableRect(top: 0, left: 0, bottom: 1, right: 1)
        XCTAssertEqual(m.expanded(exact), exact)
    }

    func test_expanded_fixedPointCrossAxisGrowth() {
        // Grid:
        // a a b
        // c d d
        // Selecting only (0,0)-(0,1) [top row, "a"] plus (1,1) [part of "d"] straddles "d" which spans
        // columns 1-2 on row 1. Growing to include column 2 (to cover "d") then re-checks the row axis —
        // "a" only occupies row 0 so no further growth is needed there, but this exercises a rect that
        // needs re-checking on a second axis after the first grow.
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", colspan: 2), cell("b")]),
                Row(id: BlockID("r1"), cells: [cell("c"), cell("d", colspan: 2)]),
            ])
        let m = TableMap(table)
        XCTAssertTrue(m.isWellFormed)

        // Start with a rect covering only (0,0) and (1,1): straddles "a" (needs left..right = 0...1)
        // AND straddles "d" (needs left..right = 1...2). The union must grow to cover both fully.
        let start = TableRect(top: 0, left: 0, bottom: 1, right: 1)
        let result = m.expanded(start)
        XCTAssertEqual(result, TableRect(top: 0, left: 0, bottom: 1, right: 2))

        // Fixed point: expanding the result again changes nothing.
        XCTAssertEqual(m.expanded(result), result)
    }

    // MARK: 7. Malformed guard

    func test_malformed_overflowDoesNotCrash() {
        // True cell-vs-cell overlap is structurally impossible here (greedy skip-while-occupied placement),
        // so malformed input manifests as OVERFLOW: a cell's colspan/rowspan exceeds the remaining grid.
        // The builder must clamp defensively rather than crash, and report isWellFormed == false.
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                // "a" claims colspan 3 on a 2-column grid — overflows and must be clamped.
                Row(id: BlockID("r0"), cells: [cell("a", colspan: 3)]),
            ])
        let m = TableMap(table)
        XCTAssertFalse(m.isWellFormed)
        // Must not crash querying any in-bounds slot.
        XCTAssertNotNil(m.anchor(atRow: 0, column: 0))
        XCTAssertNotNil(m.anchor(atRow: 0, column: 1))
    }

    func test_malformed_gapDoesNotCrash() {
        // Row declares fewer cells than needed to fill the row given spans — leaves an uncovered gap.
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a")]),
            ])
        let m = TableMap(table)
        XCTAssertFalse(m.isWellFormed)
        XCTAssertNil(m.anchor(atRow: 0, column: 1))
        XCTAssertNil(m.anchor(atRow: 0, column: 2))
        // Still no crash.
        XCTAssertEqual(m.cellsInRect(TableRect(top: 0, left: 0, bottom: 0, right: 2)).count, 1)
    }
}

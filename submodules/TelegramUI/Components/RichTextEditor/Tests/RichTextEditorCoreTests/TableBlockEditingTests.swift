import XCTest
@testable import RichTextEditorCore

final class TableBlockEditingTests: XCTestCase {
    // MARK: ColumnSpec

    func test_columnSpec_roundTripsWidth() throws {
        let c = ColumnSpec(width: 80)
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(ColumnSpec.self, from: data)
        XCTAssertEqual(back, c)
    }

    func test_columnSpec_decodesLegacyJSONIgnoringAlignmentKey() throws {
        // A document written before `alignment` was retired (now per-cell) still loads; the
        // legacy key is simply ignored by the synthesized decode.
        let json = #"{"width":140,"alignment":"center"}"#.data(using: .utf8)!
        let c = try JSONDecoder().decode(ColumnSpec.self, from: json)
        XCTAssertEqual(c.width, 140)
    }
}

extension TableBlockEditingTests {
    private func table2x2() -> TableBlock {
        TableBlock(id: BlockID("t"),
                   columns: [ColumnSpec(width: 100), ColumnSpec(width: 120)],
                   rows: [
                       Row(id: BlockID("r0"), isHeader: true,
                           cells: [Cell(id: BlockID("a")), Cell(id: BlockID("b"))]),
                       Row(id: BlockID("r1"),
                           cells: [Cell(id: BlockID("c")), Cell(id: BlockID("d"))]),
                   ])
    }

    func test_insertingRow_addsBodyRowOfEmptyParagraphCells() {
        let t = table2x2().insertingRow(at: 1)
        XCTAssertEqual(t.rowCount, 3)
        XCTAssertFalse(t.rows[1].isHeader, "new rows are body rows")
        XCTAssertEqual(t.rows[1].cells.count, t.columnCount, "grid stays rectangular")
        // Each new cell has exactly one empty paragraph.
        for cell in t.rows[1].cells {
            XCTAssertEqual(cell.blocks.count, 1)
            guard case .paragraph(let p) = cell.blocks[0] else { return XCTFail("expected paragraph") }
            XCTAssertEqual(p.utf16Count, 0)
        }
    }

    func test_insertingRow_generatesFreshIDs() {
        let t = table2x2().insertingRow(at: 2)
        let ids = t.rows.map(\.id.rawValue)
        XCTAssertEqual(Set(ids).count, ids.count, "row ids unique")
        XCTAssertNotEqual(t.rows[2].id, t.rows[0].id)
    }

    func test_insertingRow_clampsOutOfRangeIndex() {
        XCTAssertEqual(table2x2().insertingRow(at: 99).rowCount, 3)
        XCTAssertEqual(table2x2().insertingRow(at: -5).rowCount, 3)
    }

    func test_removingRow_dropsThatRow() {
        let t = table2x2().removingRow(at: 1)
        XCTAssertEqual(t.rowCount, 1)
        XCTAssertTrue(t.rows[0].isHeader)
    }

    func test_removingRow_ignoresOutOfRange() {
        XCTAssertEqual(table2x2().removingRow(at: 9).rowCount, 2)
    }

    func test_insertingColumn_addsColumnAndACellPerRow() {
        let t = table2x2().insertingColumn(at: 1, width: 90)
        XCTAssertEqual(t.columnCount, 3)
        XCTAssertEqual(t.columns[1].width, 90)
        for row in t.rows {
            XCTAssertEqual(row.cells.count, 3, "every row gains a cell")
            guard case .paragraph(let p) = row.cells[1].blocks[0] else { return XCTFail("expected paragraph") }
            XCTAssertEqual(p.utf16Count, 0)
        }
    }

    func test_insertingColumn_preservesHeaderRow() {
        // Row 0 of table2x2() is a full header row. Inserting a column must keep it a header row —
        // the new cell inherits the row's header status (regression: a plain inserted cell flipped
        // the derived Row.isHeader to false and defeated removingRows' header protection).
        let t = table2x2().insertingColumn(at: 1, width: 90)
        XCTAssertTrue(t.rows[0].isHeader, "the header row stays a header row after a column insert")
        XCTAssertEqual(t.rows[0].cells.count, 3, "the header row gained the inserted cell")
        XCTAssertFalse(t.rows[1].isHeader, "the body row stays a body row")
        // The header protection still holds: a range over the (now un-flippable) header is a no-op.
        XCTAssertEqual(t.removingRows(in: 0...0).rowCount, 2, "header row remains delete-protected")
    }

    func test_removingColumn_dropsColumnAndACellPerRow() {
        let t = table2x2().removingColumn(at: 0)
        XCTAssertEqual(t.columnCount, 1)
        XCTAssertEqual(t.columns[0].width, 120, "the surviving column keeps its width")
        for row in t.rows { XCTAssertEqual(row.cells.count, 1) }
    }

    private func table4row() -> TableBlock {
        TableBlock(id: BlockID("t"),
                   columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                   rows: [
                       Row(id: BlockID("r0"), isHeader: true, cells: [Cell(id: BlockID("h0")), Cell(id: BlockID("h1"))]),
                       Row(id: BlockID("r1"), cells: [Cell(id: BlockID("a0")), Cell(id: BlockID("a1"))]),
                       Row(id: BlockID("r2"), cells: [Cell(id: BlockID("b0")), Cell(id: BlockID("b1"))]),
                       Row(id: BlockID("r3"), cells: [Cell(id: BlockID("c0")), Cell(id: BlockID("c1"))]),
                   ])
    }

    func test_removingRows_dropsTheBodyRangeHighToLow() {
        let t = table4row().removingRows(in: 1...2)   // remove body rows r1, r2
        XCTAssertEqual(t.rows.map(\.id.rawValue), ["r0", "r3"])
        XCTAssertEqual(t.columnCount, 2)
    }

    func test_removingRows_skipsHeaderInRange() {
        let t = table4row().removingRows(in: 0...2)   // range covers the header + r1 + r2
        XCTAssertEqual(t.rows.map(\.id.rawValue), ["r0", "r3"], "header survives; only body rows removed")
        XCTAssertTrue(t.rows[0].isHeader)
    }

    func test_removingRows_noOpWhenRangeIsHeaderOnly() {
        let t = table4row().removingRows(in: 0...0)
        XCTAssertEqual(t.rowCount, 4, "header-only range removes nothing")
    }

    func test_removingRows_ignoresOutOfRangeIndices() {
        let t = table4row().removingRows(in: 2...9)   // 3 is valid, 4..9 don't exist
        XCTAssertEqual(t.rows.map(\.id.rawValue), ["r0", "r1"], "removes r2 and r3, ignores phantom indices")
    }

    func test_removingColumns_dropsTheRangeAndACellPerRow() {
        let t3 = TableBlock(id: BlockID("t"),
                            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
                            rows: [Row(id: BlockID("r0"), isHeader: true,
                                       cells: [Cell(id: BlockID("a")), Cell(id: BlockID("b")), Cell(id: BlockID("c"))]),
                                   Row(id: BlockID("r1"),
                                       cells: [Cell(id: BlockID("d")), Cell(id: BlockID("e")), Cell(id: BlockID("f"))])])
        let t = t3.removingColumns(in: 0...1)
        XCTAssertEqual(t.columnCount, 1)
        for row in t.rows { XCTAssertEqual(row.cells.count, 1) }
        XCTAssertEqual(t.rows[0].cells[0].id, BlockID("c"), "the surviving column is the one not in the range")
    }

    func test_removingColumns_neverRemovesTheLastColumn() {
        let t = table2x2().removingColumns(in: 0...1)   // would empty the table
        XCTAssertEqual(t.columnCount, 1, "always leaves at least one column")
        for row in t.rows { XCTAssertEqual(row.cells.count, 1) }
    }

    func test_removingColumns_coveringAllColumns_keepsLowestIndexed() {
        let t3 = TableBlock(id: BlockID("t"),
                            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
                            rows: [Row(id: BlockID("r0"), isHeader: true,
                                       cells: [Cell(id: BlockID("a")), Cell(id: BlockID("b")), Cell(id: BlockID("c"))])])
        let t = t3.removingColumns(in: 0...2)   // would empty the table
        XCTAssertEqual(t.columnCount, 1)
        XCTAssertEqual(t.rows[0].cells[0].id, BlockID("a"), "the lowest-indexed covered column (col 0) is kept")
    }

    func test_removingRows_fullyOutOfBoundsRange_isNoOp() {
        let t = table4row().removingRows(in: 9...12)
        XCTAssertEqual(t.rowCount, 4)
        XCTAssertEqual(t.rows.map(\.id.rawValue), ["r0", "r1", "r2", "r3"])
    }
}

import XCTest
@testable import RichTextEditorCore

/// Basic (no-merge) coverage of the `TableMap` covering map. Merge/dedupe/expansion scenarios live in
/// `TableMapCoverageTests`.
final class TableMapTests: XCTestCase {
    private func table() -> TableBlock {
        func cell(_ s: String) -> Cell { Cell(id: BlockID(s)) }
        return TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a"), cell("b"), cell("c")]),
                Row(id: BlockID("r1"), cells: [cell("d"), cell("e"), cell("f")]),
            ])
    }

    func test_map_dimensions() {
        let m = TableMap(table())
        XCTAssertEqual(m.rows, 2)
        XCTAssertEqual(m.columns, 3)
        XCTAssertTrue(m.isWellFormed)
    }

    func test_coveringRect_forDenseGrid_isSingleSlot() {
        let m = TableMap(table())
        XCTAssertEqual(m.coveringRect(atRow: 1, column: 2), TableRect(top: 1, left: 2, bottom: 1, right: 2))
    }

    func test_cellsInRect_isRowMajor() {
        let m = TableMap(table())
        let cells = m.cellsInRect(TableRect(top: 0, left: 1, bottom: 1, right: 2))
        XCTAssertEqual(cells.map { $0.cellID }, [BlockID("b"), BlockID("c"), BlockID("e"), BlockID("f")])
        XCTAssertEqual(cells.map { [$0.row, $0.column] },
                       [[0, 1], [0, 2], [1, 1], [1, 2]])
    }
}

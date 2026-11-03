import XCTest
@testable import RichTextEditorCore

final class TableBlockTests: XCTestCase {
    func test_table_reportsRowAndColumnCounts() {
        let table = TableBlock(
            id: BlockID("t1"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("r1"), isHeader: true, cells: [
                    Cell(id: BlockID("c1")), Cell(id: BlockID("c2")),
                ]),
                Row(id: BlockID("r2"), cells: [
                    Cell(id: BlockID("c3")), Cell(id: BlockID("c4")),
                ]),
            ]
        )
        XCTAssertEqual(table.columnCount, 2)
        XCTAssertEqual(table.rowCount, 2)
        XCTAssertTrue(table.rows[0].isHeader)
        XCTAssertFalse(table.rows[1].isHeader)
    }
}

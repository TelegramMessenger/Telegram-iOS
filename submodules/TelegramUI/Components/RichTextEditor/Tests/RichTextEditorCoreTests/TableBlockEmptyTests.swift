import XCTest
@testable import RichTextEditorCore

final class TableBlockEmptyTests: XCTestCase {
    func test_empty_buildsHeaderAndBodyGrid() {
        let t = TableBlock.empty(rows: 2, columns: 2)
        XCTAssertEqual(t.columnCount, 2)
        XCTAssertEqual(t.rowCount, 2)
        XCTAssertTrue(t.rows[0].isHeader, "row 0 must be the header")
        XCTAssertFalse(t.rows[1].isHeader, "body rows are not headers")
        for row in t.rows {
            XCTAssertEqual(row.cells.count, 2, "grid invariant: every row has columnCount cells")
            for cell in row.cells {
                XCTAssertEqual(cell.blocks.count, 1)
                guard case .paragraph(let p) = cell.blocks[0] else { return XCTFail("cell block should be a paragraph") }
                XCTAssertTrue(p.runs.isEmpty, "fresh cell paragraph has no runs")
            }
        }
    }

    func test_empty_clampsToAtLeastOne() {
        let t = TableBlock.empty(rows: 0, columns: 0)
        XCTAssertEqual(t.rowCount, 1)
        XCTAssertEqual(t.columnCount, 1)
        XCTAssertTrue(t.rows[0].isHeader)
    }

    func test_empty_3x3HasOneHeaderTwoBody() {
        let t = TableBlock.empty(rows: 3, columns: 3)
        XCTAssertEqual(t.rows.filter { $0.isHeader }.count, 1)
        XCTAssertEqual(t.rows.filter { !$0.isHeader }.count, 2)
        XCTAssertEqual(t.columnCount, 3)
    }

    func test_empty_generatesFreshUniqueIDs() {
        let t = TableBlock.empty(rows: 3, columns: 3)
        var ids: [BlockID] = [t.id]
        for row in t.rows {
            ids.append(row.id)
            for cell in row.cells {
                ids.append(cell.id)
                if case .paragraph(let p) = cell.blocks[0] { ids.append(p.id) }
            }
        }
        XCTAssertEqual(Set(ids).count, ids.count, "all generated IDs must be unique")
    }
}

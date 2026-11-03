import XCTest
@testable import RichTextEditorCore

final class TableCellHeaderModelTests: XCTestCase {
    func test_cellHeaderDefaultsFalse() {
        XCTAssertFalse(Cell(id: BlockID("c")).isHeader)
    }

    func test_cellHeaderRoundTrips() throws {
        var cell = Cell(id: BlockID("c"))
        cell.isHeader = true
        let data = try JSONEncoder().encode(cell)
        XCTAssertTrue(try JSONDecoder().decode(Cell.self, from: data).isHeader)
    }

    func test_legacyCellWithoutHeader_decodesFalse() throws {
        let json = #"{"id":"c","blocks":[]}"#.data(using: .utf8)!
        XCTAssertFalse(try JSONDecoder().decode(Cell.self, from: json).isHeader)
    }

    func test_rowIsHeaderIsDerivedFromCells() {
        let hdr = { (id: String) -> Cell in var c = Cell(id: BlockID(id)); c.isHeader = true; return c }
        XCTAssertTrue(Row(id: BlockID("r"), cells: [hdr("a"), hdr("b")]).isHeader)
        XCTAssertFalse(Row(id: BlockID("r"), cells: [hdr("a"), Cell(id: BlockID("b"))]).isHeader)
        XCTAssertFalse(Row(id: BlockID("r"), cells: []).isHeader)
    }

    func test_initHeaderParamSeedsCells() {
        let row = Row(id: BlockID("r"), isHeader: true, cells: [Cell(id: BlockID("a")), Cell(id: BlockID("b"))])
        XCTAssertTrue(row.cells.allSatisfy { $0.isHeader })
        XCTAssertTrue(row.isHeader)
    }

    func test_mixedPerCellHeader_survivesRowRoundTrip() throws {
        // The core new capability: a non-uniform per-cell header pattern encodes and decodes intact
        // through the normal (non-legacy) path — cell 0 a header, cell 1 not.
        var hdr = Cell(id: BlockID("a")); hdr.isHeader = true
        let row = Row(id: BlockID("r"), cells: [hdr, Cell(id: BlockID("b"))])
        let data = try JSONEncoder().encode(row)
        let back = try JSONDecoder().decode(Row.self, from: data)
        XCTAssertTrue(back.cells[0].isHeader)
        XCTAssertFalse(back.cells[1].isHeader)
        XCTAssertFalse(back.isHeader, "a mixed row is not a whole-row header")
    }

    func test_legacyRowHeader_migratesIntoCells() throws {
        let json = #"{"id":"r","cells":[{"id":"a","blocks":[]},{"id":"b","blocks":[]}],"isHeader":true}"#.data(using: .utf8)!
        let row = try JSONDecoder().decode(Row.self, from: json)
        XCTAssertTrue(row.cells.allSatisfy { $0.isHeader }, "legacy row header folds into every cell")
        XCTAssertTrue(row.isHeader)
    }

    func test_rowDoesNotEncodeIsHeaderKey() throws {
        // NOTE: a naive whole-blob substring check for "isHeader" is unusable here — Cell legitimately
        // serializes its OWN "isHeader" key (Step 3), so the substring is always present once any cell
        // exists. Inspect the ROW's own top-level JSON keys instead, which is what the invariant actually means.
        let row = Row(id: BlockID("r"), isHeader: true, cells: [Cell(id: BlockID("a"))])
        let data = try JSONEncoder().encode(row)
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(obj["isHeader"], "row-level isHeader is not serialized (per-cell is the truth)")
    }
}

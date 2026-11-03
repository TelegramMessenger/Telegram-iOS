import XCTest
@testable import RichTextEditorCore

final class TableCellSpanModelTests: XCTestCase {
    func test_spanDefaultsToOne() {
        let c = Cell(id: BlockID("c"))
        XCTAssertEqual(c.colspan, 1); XCTAssertEqual(c.rowspan, 1)
    }
    func test_spanRoundTrips() throws {
        var c = Cell(id: BlockID("c")); c.colspan = 3; c.rowspan = 2
        let back = try JSONDecoder().decode(Cell.self, from: try JSONEncoder().encode(c))
        XCTAssertEqual(back.colspan, 3); XCTAssertEqual(back.rowspan, 2)
    }
    func test_legacyCellWithoutSpan_decodesToOne() throws {
        let json = #"{"id":"c","blocks":[]}"#.data(using: .utf8)!
        let c = try JSONDecoder().decode(Cell.self, from: json)
        XCTAssertEqual(c.colspan, 1); XCTAssertEqual(c.rowspan, 1)
    }
}

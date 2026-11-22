import XCTest
@testable import RichTextEditorCore

final class TableCellAlignmentModelTests: XCTestCase {
    func test_cellAlignmentDefaults() {
        let cell = Cell(id: BlockID("c"))
        XCTAssertEqual(cell.horizontalAlignment, .center)
        XCTAssertEqual(cell.verticalAlignment, .top)
    }

    func test_cellAlignmentRoundTrips() throws {
        var cell = Cell(id: BlockID("c"))
        cell.horizontalAlignment = .right
        cell.verticalAlignment = .bottom
        let data = try JSONEncoder().encode(cell)
        let back = try JSONDecoder().decode(Cell.self, from: data)
        XCTAssertEqual(back.horizontalAlignment, .right)
        XCTAssertEqual(back.verticalAlignment, .bottom)
    }

    func test_legacyCellWithoutAlignment_decodesToDefaults() throws {
        // A cell encoded before the fields existed: only id + blocks.
        let json = #"{"id":"c","blocks":[]}"#.data(using: .utf8)!
        let cell = try JSONDecoder().decode(Cell.self, from: json)
        XCTAssertEqual(cell.horizontalAlignment, .center)
        XCTAssertEqual(cell.verticalAlignment, .top)
    }

    func test_verticalAlignmentCodec() throws {
        for v in VerticalAlignment.allCases {
            let data = try JSONEncoder().encode(v)
            XCTAssertEqual(try JSONDecoder().decode(VerticalAlignment.self, from: data), v)
        }
    }
}

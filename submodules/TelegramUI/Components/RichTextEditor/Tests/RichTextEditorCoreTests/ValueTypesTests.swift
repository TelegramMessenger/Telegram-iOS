import XCTest
@testable import RichTextEditorCore

final class ValueTypesTests: XCTestCase {
    func test_rgbaColor_defaultsAlphaToOne_andRoundTrips() throws {
        let c = RGBAColor(red: 0.1, green: 0.2, blue: 0.3)
        XCTAssertEqual(c.alpha, 1.0)
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(RGBAColor.self, from: data), c)
    }

    func test_enums_haveStableRawValues() {
        XCTAssertEqual(TextAlignment.justified.rawValue, "justified")
        XCTAssertEqual(ParagraphStyleName.heading1.rawValue, "heading1")
        XCTAssertEqual(ListMarker.ordered.rawValue, "ordered")
        XCTAssertEqual(MediaAlignment.center.rawValue, "center")
    }
}

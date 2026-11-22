import XCTest
@testable import RichTextEditorCore

final class TextAlignmentTests: XCTestCase {
    func test_defaultParagraphAlignment_isNatural() {
        XCTAssertEqual(ParagraphAttributes.default.alignment, .natural)
        XCTAssertEqual(ParagraphAttributes().alignment, .natural)
    }

    func test_natural_isCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(TextAlignment.natural)
        XCTAssertEqual(try JSONDecoder().decode(TextAlignment.self, from: data), .natural)
    }

    func test_natural_isInAllCases() {
        XCTAssertTrue(TextAlignment.allCases.contains(.natural))
    }
}

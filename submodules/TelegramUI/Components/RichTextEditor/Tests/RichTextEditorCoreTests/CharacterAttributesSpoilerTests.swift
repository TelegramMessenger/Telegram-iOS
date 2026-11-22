import XCTest
@testable import RichTextEditorCore

final class CharacterAttributesSpoilerTests: XCTestCase {
    func test_spoiler_defaultsFalse() {
        XCTAssertFalse(CharacterAttributes().spoiler)
    }

    func test_spoiler_roundTripsThroughJSON() throws {
        let ca = CharacterAttributes(bold: true, spoiler: true)
        let data = try JSONEncoder().encode(ca)
        let back = try JSONDecoder().decode(CharacterAttributes.self, from: data)
        XCTAssertTrue(back.spoiler)
        XCTAssertTrue(back.bold)
        XCTAssertEqual(ca, back)
    }

    func test_spoiler_backwardCompatibleDecode_missingKeyIsFalse() throws {
        let json = #"{"bold":false,"italic":false,"underline":false,"strikethrough":false,"inlineCode":false}"#
        let ca = try JSONDecoder().decode(CharacterAttributes.self, from: Data(json.utf8))
        XCTAssertFalse(ca.spoiler)
    }

    func test_spoiler_participatesInEquatable() {
        XCTAssertNotEqual(CharacterAttributes(spoiler: true), CharacterAttributes(spoiler: false))
    }
}

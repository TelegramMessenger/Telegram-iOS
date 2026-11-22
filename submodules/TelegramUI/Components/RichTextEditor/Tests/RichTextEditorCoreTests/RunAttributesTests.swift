import XCTest
@testable import RichTextEditorCore

final class RunAttributesTests: XCTestCase {
    func test_characterAttributes_plainHasNoFormatting() {
        let a = CharacterAttributes.plain
        XCTAssertFalse(a.bold)
        XCTAssertNil(a.fontSize)
        XCTAssertNil(a.link)
    }

    func test_textRun_utf16CountCountsUTF16Units() {
        // "a😀" is 1 + 2 UTF-16 units = 3
        let run = TextRun(text: "a😀")
        XCTAssertEqual(run.utf16Count, 3)
    }

    func test_paragraphAttributes_defaultIsNaturalAligned() {
        XCTAssertEqual(ParagraphAttributes.default.alignment, .natural)
        XCTAssertEqual(ParagraphAttributes.default.lineHeightMultiple, 1)
    }

    func test_listMembership_roundTrips() throws {
        let m = ListMembership(marker: .ordered, level: 2)
        let data = try JSONEncoder().encode(m)
        XCTAssertEqual(try JSONDecoder().decode(ListMembership.self, from: data), m)
    }

    func test_characterAttributes_inlineCodeDefaultsFalse_andRoundTrips() throws {
        XCTAssertFalse(CharacterAttributes.plain.inlineCode)
        let a = CharacterAttributes(inlineCode: true)
        let data = try JSONEncoder().encode(a)
        let back = try JSONDecoder().decode(CharacterAttributes.self, from: data)
        XCTAssertTrue(back.inlineCode)
    }

    func test_characterAttributes_decodesLegacyJSONWithoutInlineCode() throws {
        // A payload written before `inlineCode` existed (key absent) must still decode.
        let json = #"{"bold":true,"italic":false,"underline":false,"strikethrough":false}"#
        let back = try JSONDecoder().decode(CharacterAttributes.self, from: Data(json.utf8))
        XCTAssertTrue(back.bold)
        XCTAssertFalse(back.inlineCode)
    }
}

import XCTest
@testable import RichTextEditorCore

final class EmojiRefTests: XCTestCase {
    func test_emojiRef_roundTripsThroughJSON() throws {
        let ref = EmojiRef(id: "partyparrot", instanceID: "inst-1", altText: ":partyparrot:")
        let data = try JSONEncoder().encode(ref)
        XCTAssertEqual(try JSONDecoder().decode(EmojiRef.self, from: data), ref)
    }

    func test_emojiRef_altTextIsOptional() throws {
        let ref = EmojiRef(id: "x", instanceID: "inst-2", altText: nil)
        let data = try JSONEncoder().encode(ref)
        XCTAssertNil(try JSONDecoder().decode(EmojiRef.self, from: data).altText)
    }

    func test_characterAttributes_emojiDefaultsNil_andRoundTrips() throws {
        XCTAssertNil(CharacterAttributes.plain.emoji)
        let ca = CharacterAttributes(emoji: EmojiRef(id: "star", instanceID: "i9", altText: nil))
        let data = try JSONEncoder().encode(ca)
        let back = try JSONDecoder().decode(CharacterAttributes.self, from: data)
        XCTAssertEqual(back.emoji?.id, "star")
        XCTAssertEqual(back.emoji?.instanceID, "i9")
    }

    func test_characterAttributes_decodesLegacyJSONWithoutEmoji() throws {
        let json = #"{"bold":true,"italic":false,"underline":false,"strikethrough":false}"#
        let back = try JSONDecoder().decode(CharacterAttributes.self, from: Data(json.utf8))
        XCTAssertTrue(back.bold)
        XCTAssertNil(back.emoji)
    }

    func test_paragraph_emojiRunCountsAsOneUTF16_andTreeSizeUnaffected() {
        let emojiRun = TextRun(text: "\u{FFFC}",
                               attributes: CharacterAttributes(emoji: EmojiRef(id: "x", instanceID: "i", altText: nil)))
        let p = ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Hi"), emojiRun, TextRun(text: "!")])
        XCTAssertEqual(p.text, "Hi\u{FFFC}!")
        XCTAssertEqual(p.utf16Count, 4)
        let root = DocumentTree.build(from: Document(
            blocks: [.paragraph(p)]))
        XCTAssertEqual(root.children[0].nodeSize, 6)   // text 4 + 2 (open/close); position model unchanged
    }
}

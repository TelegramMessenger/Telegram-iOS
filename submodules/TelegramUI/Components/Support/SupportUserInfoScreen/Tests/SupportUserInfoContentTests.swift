import Foundation
import XCTest
import TelegramCore
import TextFormat
@testable import SupportUserInfoScreen

final class SupportUserInfoContentTests: XCTestCase {
    private func roundTrip(_ text: String, _ entities: [MessageTextEntity]) -> SupportUserInfoContent {
        let info = SupportUserInfo(author: "agent", date: 1000, text: text, entities: entities)
        return supportUserInfoContent(fieldText: supportUserInfoEditorText(info), originalEntities: entities)
    }

    private func sorted(_ entities: [MessageTextEntity]) -> [MessageTextEntity] {
        return supportUserInfoContent(fieldText: chatInputStateStringWithAppliedEntities(String(repeating: "x", count: 64), entities: entities), originalEntities: entities).entities
    }

    func testEveryFormatSurvivesARoundTrip() {
        let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1001))
        let cases: [MessageTextEntityType] = [
            .Bold,
            .Italic,
            .Underline,
            .Strikethrough,
            .Spoiler,
            .Code,
            .Pre(language: "swift"),
            .Pre(language: nil),
            .BlockQuote(isCollapsed: false),
            .BlockQuote(isCollapsed: true),
            .TextUrl(url: "https://example.com/made-up"),
            .TextMention(peerId: peerId),
            .CustomEmoji(stickerPack: nil, fileId: 42),
            .FormattedDate(format: nil, date: 1000),
            .FormattedDate(format: .relative, date: 1000)
        ]
        for type in cases {
            let entity = MessageTextEntity(range: 2 ..< 6, type: type)
            let result = self.roundTrip("ab made-up", [entity])
            XCTAssertEqual(result.text, "ab made-up", "\(type)")
            XCTAssertEqual(result.entities, [entity], "\(type)")
        }
    }

    func testOverlappingFormatsKeepTheirCoverage() {
        let result = self.roundTrip("abcdef", [
            MessageTextEntity(range: 0 ..< 6, type: .Bold),
            MessageTextEntity(range: 3 ..< 6, type: .Italic)
        ])
        XCTAssertEqual(result.entities, [
            MessageTextEntity(range: 0 ..< 3, type: .Bold),
            MessageTextEntity(range: 3 ..< 6, type: .Bold),
            MessageTextEntity(range: 3 ..< 6, type: .Italic)
        ])
    }

    func testDetectedEntitiesAreNotSent() {
        let result = self.roundTrip("@name #tag example.com", [
            MessageTextEntity(range: 0 ..< 5, type: .Mention),
            MessageTextEntity(range: 6 ..< 10, type: .Hashtag),
            MessageTextEntity(range: 11 ..< 22, type: .Url)
        ])
        XCTAssertEqual(result.entities, [])
    }

    func testMarkdownIsConvertedAndEndsAreTrimmed() {
        let result = supportUserInfoContent(fieldText: NSAttributedString(string: "  **made**\n"), originalEntities: [])
        XCTAssertEqual(result.text, "made")
        XCTAssertEqual(result.entities, [MessageTextEntity(range: 0 ..< 4, type: .Bold)])
    }

    func testUnchangedTextCloses() {
        let original = self.roundTrip("made-up", [MessageTextEntity(range: 0 ..< 4, type: .Bold)])
        XCTAssertEqual(supportUserInfoSaveDecision(original: original, current: original), .close)
        let empty = SupportUserInfoContent(text: "", entities: [])
        XCTAssertEqual(supportUserInfoSaveDecision(original: empty, current: empty), .close)
    }

    func testChangedFormatSaves() {
        let original = SupportUserInfoContent(text: "made-up", entities: [])
        let current = SupportUserInfoContent(text: "made-up", entities: [MessageTextEntity(range: 0 ..< 4, type: .Bold)])
        XCTAssertEqual(supportUserInfoSaveDecision(original: original, current: current), .save)
    }

    func testEmptyingAsksFirst() {
        let original = SupportUserInfoContent(text: "made-up", entities: [])
        let current = SupportUserInfoContent(text: "", entities: [])
        XCTAssertEqual(supportUserInfoSaveDecision(original: original, current: current), .confirmDelete)
    }

    func testLimitCountsUtf16() {
        let original = SupportUserInfoContent(text: "", entities: [])
        let fits = SupportUserInfoContent(text: String(repeating: "a", count: supportUserInfoMaxLength), entities: [])
        XCTAssertEqual(supportUserInfoSaveDecision(original: original, current: fits), .save)
        let graphemes = String(repeating: "\u{1F600}", count: supportUserInfoMaxLength / 2 + 1)
        XCTAssertLessThan(graphemes.count, supportUserInfoMaxLength)
        XCTAssertEqual(supportUserInfoSaveDecision(original: original, current: SupportUserInfoContent(text: graphemes, entities: [])), .tooLong)
    }
}

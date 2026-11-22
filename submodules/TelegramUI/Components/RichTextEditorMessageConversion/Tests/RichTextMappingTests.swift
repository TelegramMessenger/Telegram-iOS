import XCTest
import TelegramCore
import TextFormat
import RichTextEditorCore
@testable import RichTextEditorMessageConversion

/// The editor keeps a mention and a date as `tg://` marker links (`MentionDateMarkers`). A rich message built from a
/// Document (the attachment screen's send path) sends them as a mention by name and a date, as the composer does,
/// never as links to the marker.
final class RichTextMappingTests: XCTestCase {
    private func run(_ text: String, link: String, bold: Bool = false) -> TextRun {
        var attributes = CharacterAttributes.plain
        attributes.link = link
        attributes.bold = bold
        return TextRun(text: text, attributes: attributes)
    }

    func testAMentionMarkerIsSentAsAMentionByTheRawUserId() throws {
        // Above 2^32, where a packed `PeerId` and the raw user id differ.
        let userId: Int64 = 5_000_000_000
        let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(userId))
        let link = try XCTUnwrap(mentionMarkdownURL(peerId: peerId))
        XCTAssertEqual(richText(from: run("Alice", link: link)), .textMentionName(text: .plain("Alice"), peerId: userId))
    }

    func testAMentionKeepsItsStylesInside() {
        XCTAssertEqual(richText(from: run("Alice", link: "tg://user?id=42", bold: true)), .textMentionName(text: .bold(.plain("Alice")), peerId: 42))
    }

    func testADateMarkerIsSentAsADate() {
        XCTAssertEqual(richText(from: run("tomorrow", link: dateMarkdownURL(timestamp: 1_800_000_000))), .textDate(text: .plain("tomorrow"), date: 1_800_000_000, format: nil))
    }

    func testAnOrdinaryLinkStaysALink() {
        XCTAssertEqual(richText(from: run("site", link: "https://telegram.org")), .url(text: .plain("site"), url: "https://telegram.org", webpageId: nil))
    }

    func testASpoilerIsSentHidden() {
        var attributes = CharacterAttributes.plain
        attributes.spoiler = true
        attributes.bold = true
        XCTAssertEqual(richText(from: TextRun(text: "secret", attributes: attributes)), .textSpoiler(text: .bold(.plain("secret"))))
    }

    func testALinkInsideASpoilerIsHiddenToo() {
        var attributes = CharacterAttributes.plain
        attributes.spoiler = true
        attributes.link = "https://telegram.org"
        XCTAssertEqual(richText(from: TextRun(text: "site", attributes: attributes)), .textSpoiler(text: .url(text: .plain("site"), url: "https://telegram.org", webpageId: nil)))
    }

    func testAMarkerOfAnImpossibleUserIdStaysALink() {
        XCTAssertEqual(richText(from: run("x", link: "tg://user?id=0")), .url(text: .plain("x"), url: "tg://user?id=0", webpageId: nil))
    }
}

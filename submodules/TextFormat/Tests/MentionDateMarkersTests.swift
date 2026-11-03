import XCTest
import TelegramCore
@testable import TextFormat

final class MentionDateMarkersTests: XCTestCase {
    func testMentionRoundTrip() {
        let peerId = EnginePeer.Id(12345)
        let url = mentionMarkdownURL(peerId: peerId)
        XCTAssertEqual(url, "tg://user?id=12345")
        XCTAssertEqual(parseMentionPeerId(fromURL: url), peerId)
    }

    func testMentionLargeChannelPeer() {
        // The internal PeerId.toInt64() packs namespace and id bits — for current Telegram peer
        // namespaces and realistic ID magnitudes the result is non-negative; the parser handles
        // signed values correctly regardless. Use a large valid channel peer id to exercise the
        // codec with multi-digit values. (The Telegram Bot API uses negative IDs for channels,
        // but that convention does not apply to the internal PeerId packed format used here.)
        let peerId = EnginePeer.Id(576460730828587007)
        let url = mentionMarkdownURL(peerId: peerId)
        XCTAssertEqual(parseMentionPeerId(fromURL: url), peerId)
    }

    func testMentionParseRejectsNonMatching() {
        XCTAssertNil(parseMentionPeerId(fromURL: "https://example.com"))
        XCTAssertNil(parseMentionPeerId(fromURL: "tg://username?id=1"))
        XCTAssertNil(parseMentionPeerId(fromURL: "tg://user?id=abc"))
        XCTAssertNil(parseMentionPeerId(fromURL: "tg://user?id="))
        // Swift's Int64 init tolerates a leading '+'; self-generated URLs never contain one, but lock the behavior.
        XCTAssertNotNil(parseMentionPeerId(fromURL: "tg://user?id=+1"))
    }

    func testDateRoundTrip() {
        XCTAssertEqual(dateMarkdownURL(timestamp: 1700000000), "tg://timestamp?t=1700000000")
        XCTAssertEqual(parseDate(fromURL: "tg://timestamp?t=1700000000"), 1700000000)
    }

    func testDateParseRejectsNonMatching() {
        XCTAssertNil(parseDate(fromURL: "tg://user?id=1"))
        XCTAssertNil(parseDate(fromURL: "tg://timestamp?t="))
        XCTAssertNil(parseDate(fromURL: "tg://timestamp?t=notanumber"))
    }

    func testClassifyPrecedence() {
        guard case let .mention(p) = classifyChatLink("tg://user?id=42") else { return XCTFail("expected mention") }
        XCTAssertEqual(p, EnginePeer.Id(42))
        guard case let .date(t) = classifyChatLink("tg://timestamp?t=99") else { return XCTFail("expected date") }
        XCTAssertEqual(t, 99)
        guard case let .url(u) = classifyChatLink("https://example.com") else { return XCTFail("expected url") }
        XCTAssertEqual(u, "https://example.com")
    }

    func testClassifyNearMissesFallToUrl() {
        guard case .url = classifyChatLink("tg://username?id=1") else { return XCTFail("tg://username must be url") }
        guard case .url = classifyChatLink("tg://user?id=abc") else { return XCTFail("non-numeric id must be url") }
        guard case .url = classifyChatLink("tg://timestamp?t=") else { return XCTFail("empty timestamp must be url") }
    }

    func testCodecBoundaryValues() {
        // Zero peer id and a negative timestamp both parse cleanly (no sign/zero special-casing).
        XCTAssertEqual(parseMentionPeerId(fromURL: "tg://user?id=0"), EnginePeer.Id(0))
        XCTAssertEqual(parseDate(fromURL: "tg://timestamp?t=-1"), -1)
    }
}

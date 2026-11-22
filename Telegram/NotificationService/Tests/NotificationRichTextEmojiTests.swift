import Foundation
import XCTest
@testable import NotificationServiceExtensionLib

/// A rich message carries its custom emoji inside the page, not as entities, and its push body is the server's plain
/// text with each emoji's alt text in its place. The emoji are found in that body only where no other occurrence of
/// the same alt text, in the page or in the body, can be the one in that place.
final class NotificationRichTextEmojiTests: XCTestCase {
    private typealias Run = (text: String, customEmojiFileId: Int64?)

    private func text(_ text: String) -> Run {
        return (text, nil)
    }

    private func emoji(_ fileId: Int64, _ alt: String) -> Run {
        return (alt, fileId)
    }

    private func ranges(_ body: String, from location: Int = 0, _ runs: [Run]) -> [String] {
        return notificationRichTextCustomEmoji(body: body, from: location, runs: runs).map { item in
            let range = NSRange(location: item.range.lowerBound, length: item.range.count)
            return "\(item.fileId):\((body as NSString).substring(with: range))@\(item.range.lowerBound)"
        }
    }

    func testMatchesEachEmojiInReadingOrder() {
        let runs = [text("Hi "), emoji(1, "🙂"), text(" and "), emoji(2, "🔥"), text(" then "), emoji(1, "🙂")]
        XCTAssertEqual(ranges("Hi 🙂 and 🔥 then 🙂", runs), ["1:🙂@3", "2:🔥@10", "1:🙂@18"])
    }

    func testRepeatedAltTextMapsToSuccessiveOccurrences() {
        XCTAssertEqual(ranges("🙂🙂", [emoji(1, "🙂"), emoji(2, "🙂")]), ["1:🙂@0", "2:🙂@2"])
    }

    func testMissingEmojiIsSkippedWithoutLosingTheRest() {
        XCTAssertEqual(ranges("a 🔥", [text("a "), emoji(1, "🙂"), emoji(2, "🔥")]), ["2:🔥@2"])
        XCTAssertEqual(ranges("a 🔥", [text("a "), emoji(1, ""), emoji(2, "🔥")]), ["2:🔥@2"])
    }

    func testDoesNotMatchInsideALargerEmoji() {
        // "❤" is the first scalar of "❤️" (with VS16) and of a ZWJ sequence; only a whole character matches.
        XCTAssertEqual(ranges("❤️ x ❤", [text("❤️ x "), emoji(1, "❤")]), ["1:❤@5"])
        XCTAssertEqual(ranges("👨‍👩‍👧", [emoji(1, "👨")]), [])
    }

    func testPlainAndCustomEmojiWithTheSameAltTextMapInOrder() {
        // "I ❤️ x [custom ❤️]": the page says which heart is custom, and the body has both.
        XCTAssertEqual(ranges("I ❤️ x ❤️", [text("I ❤️ x "), emoji(1, "❤️")]), ["1:❤️@7"])
    }

    func testPlainEmojiMatchesNothingWhenTheCustomOneIsLeftOutOfTheBody() {
        // "I ❤️ it" with a custom ❤️ in a table cell the body leaves out: the body's heart is the plain one.
        let runs = [text("I ❤️ it"), emoji(1, "❤️")]
        XCTAssertEqual(ranges("I ❤️ it", runs), [])
        XCTAssertEqual(ranges("I ❤️ it 🔥", runs + [emoji(2, "🔥")]), ["2:🔥@8"])
    }

    func testTruncatedBodyMapsAnEmojiThatHasNoPlainTwin() {
        XCTAssertEqual(ranges("a 🙂", [text("a "), emoji(1, "🙂"), text(" b "), emoji(1, "🙂")]), ["1:🙂@2"])
        // Two different emoji with one alt text: which one the truncated body kept is unknown.
        XCTAssertEqual(ranges("a 🙂", [text("a "), emoji(1, "🙂"), text(" b "), emoji(2, "🙂")]), [])
    }

    func testAnAltTextInsideAWordIsPlainText() {
        XCTAssertEqual(ranges("alternative alt", [text("alternative "), emoji(1, "alt")]), ["1:alt@12"])
        XCTAssertEqual(ranges("alternative", [text("alternative"), emoji(1, "alt")]), [])
    }

    func testAnAltTextContainingAnotherIsCountedAcrossRuns() {
        // A custom "😀" then a custom "😀😀": the longer alt text's first match in "😀😀😀" is not its own run, so
        // only the short one is certain; mapping both would overlap and cut a surrogate pair in half.
        XCTAssertEqual(ranges("😀😀😀", [emoji(2, "😀"), emoji(1, "😀😀")]), ["2:😀@0"])
    }

    func testAnAltTextStraddlingPlainTextIsNotMatched() {
        // "x😀" then a custom "😀😀": the body's first "😀😀" takes the plain 😀 and half of the emoji.
        XCTAssertEqual(ranges("x😀😀😀", [text("x😀"), emoji(1, "😀😀")]), [])
    }

    func testBlocksDoNotRunTogether() {
        // As the page walk emits them: a "\n" run before each block. "😀" | custom "😀", custom "😀😀", "😀": only the
        // first custom emoji's place is certain.
        XCTAssertEqual(ranges("😀\n😀😀😀😀", [text("\n"), text("😀"), text("\n"), emoji(2, "😀"), emoji(1, "😀😀"), text("😀")]), ["2:😀@3"])
        // A block starting with a combining mark must not hide the previous block's plain 👍 from the count.
        let runs = [text("\n"), text("x 👍"), text("\n"), text("\u{301}y "), emoji(1, "👍"), text("\n"), emoji(1, "👍")]
        XCTAssertEqual(ranges("x 👍\n\u{301}y 👍", runs), [])
    }

    func testSearchStartsAfterTheAuthorPrefix() {
        XCTAssertEqual(ranges("Ann 🙂: 🙂", from: 7, [emoji(1, "🙂")]), ["1:🙂@8"])
    }
}

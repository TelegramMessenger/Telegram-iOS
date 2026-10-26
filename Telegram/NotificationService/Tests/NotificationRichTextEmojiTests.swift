import Foundation
import XCTest
@testable import NotificationServiceExtensionLib

/// A rich message carries its custom emoji inside the page, not as entities, and its push body is the server's plain
/// text with each emoji's alt text in its place. The emoji are found in that body in reading order.
final class NotificationRichTextEmojiTests: XCTestCase {
    private func ranges(_ body: String, from location: Int = 0, _ emoji: [(fileId: Int64, alt: String)]) -> [String] {
        return notificationRichTextCustomEmoji(body: body, from: location, emoji: emoji).map { item in
            let range = NSRange(location: item.range.lowerBound, length: item.range.count)
            return "\(item.fileId):\((body as NSString).substring(with: range))@\(item.range.lowerBound)"
        }
    }

    func testMatchesEachEmojiInReadingOrder() {
        XCTAssertEqual(ranges("Hi 🙂 and 🔥 then 🙂", [(1, "🙂"), (2, "🔥"), (1, "🙂")]), ["1:🙂@3", "2:🔥@10", "1:🙂@18"])
    }

    func testRepeatedAltTextMapsToSuccessiveOccurrences() {
        XCTAssertEqual(ranges("🙂🙂", [(1, "🙂"), (2, "🙂")]), ["1:🙂@0", "2:🙂@2"])
    }

    func testMissingEmojiIsSkippedWithoutLosingTheRest() {
        XCTAssertEqual(ranges("a 🔥", [(1, "🙂"), (2, "🔥")]), ["2:🔥@2"])
        XCTAssertEqual(ranges("a 🔥", [(1, ""), (2, "🔥")]), ["2:🔥@2"])
    }

    func testDoesNotMatchInsideALargerEmoji() {
        // "❤" is the first scalar of "❤️" (with VS16) and of a ZWJ sequence; only a whole character matches.
        XCTAssertEqual(ranges("❤️ x ❤", [(1, "❤")]), ["1:❤@5"])
        XCTAssertEqual(ranges("👨‍👩‍👧", [(1, "👨")]), [])
    }

    func testSearchStartsAfterTheAuthorPrefix() {
        XCTAssertEqual(ranges("Ann 🙂: 🙂", from: 7, [(1, "🙂")]), ["1:🙂@8"])
    }
}

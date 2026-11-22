import XCTest
@testable import TextFormat

/// A reply quote stores the quoted text as the message has it, custom emoji included as their emoji characters. A text
/// node lays the text out with each custom emoji replaced by a one-character placeholder (`OriginalTextAttribute` keeps
/// what it stands for), so the quote has to be found in the original text and its range mapped onto the placeholders.
/// Searching the laid-out string directly misses any quote containing a custom emoji: tapping such a quote then
/// neither scrolled to it nor highlighted it.
final class QuoteTextRangeTests: XCTestCase {
    private static let placeholder = "&"

    /// `text` as `InteractiveTextNodeWithEntities` lays it out: every `customEmoji` occurrence replaced by a placeholder.
    private func layoutString(_ text: String, customEmoji: [String]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        var id = 0
        var searchLocation = 0
        while searchLocation < result.length {
            var nearest: (range: NSRange, emoji: String)?
            for emoji in customEmoji {
                let range = (result.string as NSString).range(of: emoji, range: NSRange(location: searchLocation, length: result.length - searchLocation))
                if range.location != NSNotFound, nearest == nil || range.location < nearest!.range.location {
                    nearest = (range, emoji)
                }
            }
            guard let nearest else {
                break
            }
            let replacement = NSAttributedString(string: QuoteTextRangeTests.placeholder, attributes: [originalTextAttributeKey: OriginalTextAttribute(id: id, string: nearest.emoji)])
            id += 1
            result.replaceCharacters(in: nearest.range, with: replacement)
            searchLocation = nearest.range.location + replacement.length
        }
        return result
    }

    func testQuoteContainingCustomEmojiIsFound() {
        let text = "Intro text. 💬Можно было бы подумать💬, — отметил."
        let layout = self.layoutString(text, customEmoji: ["💬"])
        let quote = "Можно было бы подумать💬, — отметил"
        let offset = (text as NSString).range(of: quote).location

        let range = findQuoteRange(layoutString: layout, quoteText: quote, offset: offset)

        XCTAssertEqual(range.map { (layout.string as NSString).substring(with: $0) }, "Можно было бы подумать&, — отметил")
    }

    func testOffsetInOriginalTextPicksNearestOccurrence() {
        // In the original text the offset is nearest to the first "ab"; read as a layout offset (each emoji there one
        // character, not two) it would be nearest to the second.
        let text = "💬💬💬💬ab 💬ab"
        let layout = self.layoutString(text, customEmoji: ["💬"])
        let offset = 10

        let range = findQuoteRange(layoutString: layout, quoteText: "ab", offset: offset)

        XCTAssertEqual(range, NSRange(location: 4, length: 2))
    }

    func testQuoteBoundaryInsideAnEmojiCoversItsPlaceholder() {
        // A custom emoji entity spanning two emoji: the quote ends after the first of them.
        let text = "a 👍👍 b"
        let layout = self.layoutString(text, customEmoji: ["👍👍"])

        let range = findQuoteRange(layoutString: layout, quoteText: "a 👍", offset: 0)

        XCTAssertEqual(range, NSRange(location: 0, length: 3))
    }

    func testQuoteStartInsideAnEmojiCoversItsPlaceholder() {
        let text = "a 👍👍 b"
        let layout = self.layoutString(text, customEmoji: ["👍👍"])

        let range = findQuoteRange(layoutString: layout, quoteText: "👍 b", offset: 4)

        XCTAssertEqual(range, NSRange(location: 2, length: 3))
    }

    func testQuoteEndingWithCustomEmojiAtTheEndOfTheText() {
        let text = "💬 one x 💬"
        let layout = self.layoutString(text, customEmoji: ["💬"])

        let range = findQuoteRange(layoutString: layout, quoteText: "x 💬", offset: nil)

        XCTAssertEqual(range, NSRange(location: 6, length: 3))
    }

    func testWithoutOffsetTheFirstOccurrenceIsFound() {
        let text = "💬 ab 💬 ab"
        let layout = self.layoutString(text, customEmoji: ["💬"])

        let range = findQuoteRange(layoutString: layout, quoteText: "ab", offset: nil)

        XCTAssertEqual(range, NSRange(location: 2, length: 2))
    }

    func testTextWithoutCustomEmojiIsSearchedAsIs() {
        let text = "one two one two"
        let layout = NSAttributedString(string: text)

        XCTAssertEqual(findQuoteRange(layoutString: layout, quoteText: "one", offset: 7), NSRange(location: 8, length: 3))
        XCTAssertEqual(findQuoteRange(layoutString: layout, quoteText: "one", offset: nil), NSRange(location: 0, length: 3))
    }

    func testQuoteNoLongerInTheTextIsNotFound() {
        let layout = self.layoutString("edited 💬 text", customEmoji: ["💬"])

        XCTAssertNil(findQuoteRange(layoutString: layout, quoteText: "original 💬 text", offset: 0))
    }
}

import XCTest
import TelegramCore
@testable import TextFormat

final class TrailingHashtagBlockTests: XCTestCase {
    private func hashtags(in text: String) -> [MessageTextEntity] {
        let string = text as NSString
        let regex = try! NSRegularExpression(pattern: "#\\w+")
        return regex.matches(in: text, range: NSRange(location: 0, length: string.length)).map { match in
            return MessageTextEntity(range: match.range.lowerBound ..< match.range.upperBound, type: .Hashtag)
        }
    }

    private func block(_ text: String) -> String? {
        guard let range = trailingHashtagBlockRange(text: text, entities: self.hashtags(in: text)) else {
            return nil
        }
        return (text as NSString).substring(with: NSRange(location: range.lowerBound, length: range.count))
    }

    func testFindsATrailingBlockAfterTheMessage() {
        XCTAssertEqual(self.block("Hello there\n\n#one | #two (#three)\n(word, #four #five) | #six"), "#one | #two (#three)\n(word, #four #five) | #six")
    }

    func testFindsASingleLineBlock() {
        XCTAssertEqual(self.block("Hello there\n#one | #two | #three"), "#one | #two | #three")
    }

    func testIgnoresTrailingBlankLines() {
        XCTAssertEqual(self.block("Hello\n#one #two #three\n\n"), "#one #two #three")
    }

    func testAFewHashtagsAreLeftAlone() {
        XCTAssertNil(self.block("Hello there\n#one #two"))
    }

    func testAWholeMessageOfHashtagsIsABlock() {
        XCTAssertEqual(self.block("#one #two #three"), "#one #two #three")
    }

    func testHashtagsInsideASentenceAreLeftAlone() {
        XCTAssertNil(self.block("I saw #one and #two and #three in a long sentence about something else"))
    }

    func testStopsAtTheFirstLineOfProse() {
        XCTAssertEqual(self.block("#a #b #c\nThis line is only ordinary words\n#one #two #three"), "#one #two #three")
    }

    func testABlankLineEndsTheBlock() {
        XCTAssertEqual(self.block("#a\n\n#one #two #three"), "#one #two #three")
    }

    func testNoHashtagsNoBlock() {
        XCTAssertNil(self.block("Hello there"))
        XCTAssertNil(self.block(""))
    }

    func testAQuoteOverTheBlockIsLeftAlone() {
        let text = "Hello\n#one #two #three"
        let entities = self.hashtags(in: text) + [MessageTextEntity(range: 6 ..< (text as NSString).length, type: .BlockQuote(isCollapsed: false))]
        XCTAssertNil(trailingHashtagBlockRange(text: text, entities: entities))
    }

    func testFooterListsItsTagsAndWhereTheTextEnds() {
        let text = "Hello there\n\n#one | #two (word, #three)"
        XCTAssertEqual(trailingHashtagFooter(text: text, entities: self.hashtags(in: text)), TrailingHashtagFooter(textEnd: 11, hashtags: ["#one", "#two", "#three"]))
    }

    func testFooterIgnoresTagsInTheText() {
        let text = "See #zero here please\n#one #two #three"
        XCTAssertEqual(trailingHashtagFooter(text: text, entities: self.hashtags(in: text))?.hashtags, ["#one", "#two", "#three"])
    }

    func testAMessageOfOnlyHashtagsHasNoFooter() {
        let text = "#one #two #three"
        XCTAssertNil(trailingHashtagFooter(text: text, entities: self.hashtags(in: text)))
    }

    func testACaptionOfOnlyHashtagsIsAllFooter() {
        let text = "#one #two #three"
        XCTAssertEqual(trailingHashtagFooter(text: text, entities: self.hashtags(in: text), isCaption: true), TrailingHashtagFooter(textEnd: 0, hashtags: ["#one", "#two", "#three"]))
    }

    func testACaptionWithTextKeepsItsTextEnd() {
        let text = "Hello there\n#one #two #three"
        XCTAssertEqual(trailingHashtagFooter(text: text, entities: self.hashtags(in: text), isCaption: true)?.textEnd, 11)
    }

    func testOffsetsCountEmojiAsUTF16() {
        let text = "\u{1F600}\u{1F600}\n#one #two #three"
        let range = trailingHashtagBlockRange(text: text, entities: self.hashtags(in: text))
        XCTAssertEqual(range, 5 ..< (text as NSString).length)
    }

    func testCollapsingExpandsTheFirstAndTheLastTaggedMessages() {
        XCTAssertEqual(trailingTagsExpandedPositions(taggedPositions: [2, 5, 7, 9], unreadDividerPosition: nil, collapsesMiddle: true, reachesStart: true, reachesEnd: true), [2, 9])
    }

    func testCollapsingExpandsTheFirstTaggedMessageAfterTheUnreadDivider() {
        XCTAssertEqual(trailingTagsExpandedPositions(taggedPositions: [2, 5, 7, 9], unreadDividerPosition: 6, collapsesMiddle: true, reachesStart: true, reachesEnd: true), [2, 7, 9])
    }

    func testAnUnreadDividerAfterEveryTaggedMessageExpandsNothingMore() {
        XCTAssertEqual(trailingTagsExpandedPositions(taggedPositions: [2, 5], unreadDividerPosition: 6, collapsesMiddle: true, reachesStart: true, reachesEnd: true), [2, 5])
    }

    func testALoadedWindowDoesNotPassItsEdgesOffAsTheFirstOrTheLastMessage() {
        XCTAssertEqual(trailingTagsExpandedPositions(taggedPositions: [2, 5, 9], unreadDividerPosition: nil, collapsesMiddle: true, reachesStart: false, reachesEnd: true), [9])
        XCTAssertEqual(trailingTagsExpandedPositions(taggedPositions: [2, 5, 9], unreadDividerPosition: nil, collapsesMiddle: true, reachesStart: true, reachesEnd: false), [2])
        XCTAssertEqual(trailingTagsExpandedPositions(taggedPositions: [2, 5, 9], unreadDividerPosition: nil, collapsesMiddle: true, reachesStart: false, reachesEnd: false), [])
    }

    func testWithoutCollapsingEveryTaggedMessageIsExpanded() {
        XCTAssertEqual(trailingTagsExpandedPositions(taggedPositions: [2, 5, 9], unreadDividerPosition: nil, collapsesMiddle: false, reachesStart: false, reachesEnd: false), [2, 5, 9])
    }
}

import XCTest
import TelegramCore
@testable import TextFormat

final class ChatListPreviewTextTests: XCTestCase {
    // The chat list's preview rule, shared with the News feed's rows.
    func testPreviewKeepsSpoilersCustomEmojiDatesAndInlineStyles() {
        let kept = [
            MessageTextEntity(range: 0 ..< 1, type: .Spoiler),
            MessageTextEntity(range: 1 ..< 2, type: .CustomEmoji(stickerPack: nil, fileId: 1)),
            MessageTextEntity(range: 2 ..< 3, type: .FormattedDate(format: nil, date: 0)),
            MessageTextEntity(range: 3 ..< 4, type: .Strikethrough),
            MessageTextEntity(range: 4 ..< 5, type: .Underline),
            MessageTextEntity(range: 5 ..< 6, type: .Italic),
            MessageTextEntity(range: 6 ..< 7, type: .Bold)
        ]
        XCTAssertEqual(chatListPreviewTextEntities(kept), kept)
    }

    // Links, mentions, code and quotes have no place in a preview; a quote or code block would also break the
    // line limit, since it lays the text out in blocks.
    func testPreviewDropsLinksMentionsCodeAndQuotes() {
        let dropped = [
            MessageTextEntity(range: 0 ..< 1, type: .Url),
            MessageTextEntity(range: 1 ..< 2, type: .TextUrl(url: "https://telegram.org")),
            MessageTextEntity(range: 2 ..< 3, type: .Mention),
            MessageTextEntity(range: 3 ..< 4, type: .Hashtag),
            MessageTextEntity(range: 4 ..< 5, type: .Code),
            MessageTextEntity(range: 5 ..< 6, type: .Pre(language: nil)),
            MessageTextEntity(range: 6 ..< 7, type: .BlockQuote(isCollapsed: false))
        ]
        XCTAssertEqual(chatListPreviewTextEntities(dropped), [])
    }
}

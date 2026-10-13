import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

final class FeedApiConversionTests: XCTestCase {
    private let channel = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(77))

    func testPositionRoundTripsThroughApi() {
        let position = EngineFeedPosition(date: 1_700_000_000, peerId: self.channel, id: 42)
        XCTAssertEqual(EngineFeedPosition(apiPosition: position.apiPosition), position)
    }

    func testFeedMessagesCarryTheirPositions() {
        let read = EngineFeedPosition(date: 10, peerId: self.channel, id: 1)
        let max = EngineFeedPosition(date: 20, peerId: self.channel, id: 2)
        let result = Api.feed.FeedMessages.feedMessages(.init(flags: (1 << 0) | (1 << 2), maxPosition: max.apiPosition, minPosition: nil, readMaxPosition: read.apiPosition, messages: [], chats: [], users: []))
        guard case let .page(page) = parseFeedMessages(result) else {
            XCTFail("expected a page")
            return
        }
        XCTAssertEqual(page.maxPosition, max)
        XCTAssertNil(page.minPosition)
        XCTAssertEqual(page.readMaxPosition, read)
    }

    func testFeedNotModified() {
        guard case .notModified = parseFeedMessages(.feedMessagesNotModified) else {
            XCTFail("expected notModified")
            return
        }
    }

    func testForYouKeepsItemOrder() {
        let message = Api.Message.messageEmpty(.init(flags: 1 << 0, id: 5, peerId: .peerChannel(.init(channelId: 77))))
        let result = Api.feed.ForYouFeed.forYouFeed(.init(flags: 0, items: [.feedItemInterestCategories, .feedItemMessage(.init(message: message))], chats: [], users: []))
        let parsed = parseForYouFeed(result)
        XCTAssertEqual(parsed.elements.count, 2)
        guard case .interests = parsed.elements[0], case .message = parsed.elements[1] else {
            XCTFail("wrong order")
            return
        }
    }

    func testInterestCategories() {
        let result = Api.feed.InterestCategories.interestCategories(.init(categories: [
            .interestCategory(.init(flags: 1 << 0, id: 3, title: "AI", emoji: "🤖", emojiDocumentId: nil)),
            .interestCategory(.init(flags: 1 << 1, id: 4, title: "Crypto", emoji: nil, emojiDocumentId: 99))
        ], selected: [4]))
        XCTAssertEqual(parseInterestCategories(result), EngineInterestCategories(categories: [
            EngineInterestCategory(id: 3, title: "AI", emoji: "🤖", emojiFileId: nil),
            EngineInterestCategory(id: 4, title: "Crypto", emoji: nil, emojiFileId: 99)
        ], selectedIds: [4]))
        XCTAssertNil(parseInterestCategories(.interestCategoriesNotModified))
    }
}

#if TELEGRAM_API_LAYER_233
import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

final class FeedApiConversionTests: XCTestCase {
    private let channel = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(77))

    // The feed API is parked (layer 232): conversions of removed types are tested only when it is compiled in.
#if TELEGRAM_NEWS_FEED_API
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

    func testForYouKeepsAMessageGroupAsOneElement() {
        let album = [5, 6].map { Api.Message.messageEmpty(.init(flags: 1 << 0, id: $0, peerId: .peerChannel(.init(channelId: 77)))) }
        let single = Api.Message.messageEmpty(.init(flags: 1 << 0, id: 7, peerId: .peerChannel(.init(channelId: 77))))
        let result = Api.feed.ForYouFeed.forYouFeed(.init(flags: 0, items: [.feedItemMessageGroup(.init(messages: album)), .feedItemMessage(.init(message: single))], chats: [], users: []))
        let parsed = parseForYouFeed(result)
        XCTAssertEqual(parsed.elements.count, 2)
        guard case let .messageGroup(messages) = parsed.elements[0], case .message = parsed.elements[1] else {
            XCTFail("expected a group, then a message")
            return
        }
        XCTAssertEqual(messages.compactMap { $0.id()?.id }, [5, 6])
    }
#endif

    func testForYouBatchTakesAGroupsStoredMessages() {
        let peer = Api.Peer.peerChannel(.init(channelId: 77))
        let elements: [ParsedForYouElement] = [
            .messageGroup([5, 6, 8].map { Api.Message.messageEmpty(.init(flags: 1 << 0, id: $0, peerId: peer)) }),
            .interests,
            .messageGroup([9].map { Api.Message.messageEmpty(.init(flags: 1 << 0, id: $0, peerId: peer)) }),
            .message(Api.Message.messageEmpty(.init(flags: 1 << 0, id: 7, peerId: peer)))
        ]
        var stored: [MessageId: FeedPageMessage] = [:]
        for id: Int32 in [5, 6, 7] {
            let messageId = MessageId(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: id)
            stored[messageId] = FeedPageMessage(id: messageId, timestamp: 100, groupingKey: 1)
        }
        // 8 and 9 were not stored: the first group keeps what was, the second has nothing left and is dropped.
        XCTAssertEqual(forYouBatchElements(elements, storedById: stored), [
            .group([5, 6].map { stored[MessageId(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: $0)]! }),
            .interests,
            .message(stored[MessageId(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: 7)]!)
        ])
    }

#if TELEGRAM_NEWS_FEED_API
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
#endif
}
#endif

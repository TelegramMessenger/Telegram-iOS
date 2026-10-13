import XCTest
import Postbox
@testable import TelegramCore

final class FeedReadStateTests: XCTestCase {
    private let channel = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(5))

    // The feed's caches share one TelegramCore collection, which must stay below the app-specific range
    // (applicationSpecificItemCacheCollectionId starts at 64).
    func testFeedCachesShareOneCollectionWithDistinctKeys() {
        let ids = [addedFeedCacheEntryId(filterId: 0), addedFeedCacheEntryId(filterId: 1), feedReadStateEntryId(filterId: 0), feedReadStateEntryId(filterId: 1), forYouFeedCacheEntryId(), feedInterestCategoriesEntryId()]
        XCTAssertEqual(Set(ids.map(\.collectionId)), [Namespaces.CachedItemCollection.feed])
        XCTAssertLessThan(Namespaces.CachedItemCollection.feed, 64)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testFirstReadMarkIsStored() {
        let position = EngineFeedPosition(date: 100, peerId: self.channel, id: 1)
        XCTAssertEqual(updatedFeedReadState(current: nil, maxPosition: position), FeedReadState(maxPosition: position))
    }

    func testOlderReadMarkFromAnotherSessionIsIgnored() {
        let newer = EngineFeedPosition(date: 200, peerId: self.channel, id: 2)
        let older = EngineFeedPosition(date: 100, peerId: self.channel, id: 1)
        XCTAssertNil(updatedFeedReadState(current: FeedReadState(maxPosition: newer), maxPosition: older))
    }

    func testCachedAddedFeedRoundTripsThroughCodableEntry() {
        let entry = EngineFeedEntry(position: EngineFeedPosition(date: 100, peerId: self.channel, id: 3), messageIds: [MessageId(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: 3)], groupingKey: nil)
        let cached = CachedAddedFeed(entries: [entry], readMaxPosition: entry.position)
        XCTAssertEqual(CodableEntry(cached)?.get(CachedAddedFeed.self), cached)
    }

    func testCachedForYouFeedRoundTripsThroughCodableEntry() {
        let entry = EngineFeedEntry(position: EngineFeedPosition(date: 100, peerId: self.channel, id: 3), messageIds: [MessageId(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: 3)], groupingKey: 9)
        let cached = CachedForYouFeed(items: [.interests, .post(entry)])
        XCTAssertEqual(CodableEntry(cached)?.get(CachedForYouFeed.self), cached)
    }
}

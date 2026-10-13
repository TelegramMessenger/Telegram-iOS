import XCTest
import Postbox
@testable import TelegramCore

final class FeedEntryGroupingTests: XCTestCase {
    private let channelA = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1))
    private let channelB = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(2))

    private func message(_ peerId: PeerId, _ id: Int32, date: Int32, group: Int64? = nil) -> FeedPageMessage {
        return FeedPageMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), timestamp: date, groupingKey: group)
    }

    func testPositionsOrderByDateThenPeerThenId() {
        let older = EngineFeedPosition(date: 100, peerId: self.channelB, id: 9)
        let sameSecondLowerPeer = EngineFeedPosition(date: 200, peerId: self.channelA, id: 50)
        let sameSecondHigherPeer = EngineFeedPosition(date: 200, peerId: self.channelB, id: 1)
        let sameSecondHigherId = EngineFeedPosition(date: 200, peerId: self.channelB, id: 2)
        XCTAssertEqual([sameSecondHigherId, older, sameSecondHigherPeer, sameSecondLowerPeer].sorted(), [older, sameSecondLowerPeer, sameSecondHigherPeer, sameSecondHigherId])
    }

    func testAlbumBecomesOneEntryAtItsNewestMessage() {
        let entries = groupFeedMessages([self.message(self.channelA, 10, date: 300, group: 7), self.message(self.channelA, 11, date: 301, group: 7), self.message(self.channelB, 5, date: 299)])
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].messageIds.map(\.id), [10, 11])
        XCTAssertEqual(entries[0].position, EngineFeedPosition(date: 301, peerId: self.channelA, id: 11))
        XCTAssertEqual(entries[1].messageIds.map(\.id), [5])
    }

    func testSameGroupingKeyInDifferentChannelsStaysSeparate() {
        let entries = groupFeedMessages([self.message(self.channelA, 10, date: 300, group: 7), self.message(self.channelB, 10, date: 300, group: 7)])
        XCTAssertEqual(entries.count, 2)
    }

    func testMergeDedupesAndSortsNewestFirst() {
        let existing = groupFeedMessages([self.message(self.channelA, 1, date: 100), self.message(self.channelA, 2, date: 200)])
        let page = groupFeedMessages([self.message(self.channelA, 2, date: 200), self.message(self.channelB, 3, date: 300)])
        let merged = mergeFeedEntries(existing, page)
        XCTAssertEqual(merged.map { $0.messageIds.map(\.id) }, [[3], [2], [1]])
    }

    func testMergeJoinsAnAlbumSplitAcrossPages() {
        let existing = groupFeedMessages([self.message(self.channelA, 10, date: 300, group: 7), self.message(self.channelA, 11, date: 300, group: 7)])
        let page = groupFeedMessages([self.message(self.channelA, 12, date: 300, group: 7), self.message(self.channelA, 9, date: 250)])
        let merged = mergeFeedEntries(existing, page)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].messageIds.map(\.id), [10, 11, 12])
        XCTAssertEqual(merged[0].position.id, 12)
    }

    func testReadMarkOnlyMovesForward() {
        let p100 = EngineFeedPosition(date: 100, peerId: self.channelA, id: 1)
        let p200 = EngineFeedPosition(date: 200, peerId: self.channelA, id: 2)
        XCTAssertEqual(advancedFeedReadPosition(current: nil, candidate: p100), p100)
        XCTAssertEqual(advancedFeedReadPosition(current: p100, candidate: p200), p200)
        XCTAssertNil(advancedFeedReadPosition(current: p200, candidate: p100))
        XCTAssertNil(advancedFeedReadPosition(current: p200, candidate: p200))
    }

    func testForYouBatchKeepsServerOrderAndJoinsAlbums() {
        let items = forYouItems(from: [.message(self.message(self.channelB, 5, date: 100)), .interests, .message(self.message(self.channelA, 10, date: 900, group: 3)), .message(self.message(self.channelA, 11, date: 900, group: 3))])
        XCTAssertEqual(items.map(forYouTestDescription), ["5", "interests", "10,11"])
    }

    func testAppendSkipsKnownPostsAndTheBatchBlockReplacesTheOldOne() {
        let list = forYouItems(from: [.message(self.message(self.channelA, 1, date: 1)), .interests, .message(self.message(self.channelA, 2, date: 2))])
        let batch = forYouItems(from: [.message(self.message(self.channelA, 2, date: 2)), .message(self.message(self.channelB, 3, date: 3)), .interests, .interests])
        XCTAssertEqual(appendingForYouBatch(list, batch).map(forYouTestDescription), ["1", "2", "3", "interests"])
    }

    func testAppendWithoutABlockKeepsTheOldOne() {
        let list = forYouItems(from: [.interests, .message(self.message(self.channelA, 1, date: 1))])
        let batch = forYouItems(from: [.message(self.message(self.channelB, 3, date: 3))])
        XCTAssertEqual(appendingForYouBatch(list, batch).map(forYouTestDescription), ["interests", "1", "3"])
    }

    // A For you batch counts items, not albums, so an album can straddle two batches. Two entries for one
    // album would share the row identity `album-<peer>-<groupingKey>`, which CoreList rejects with a
    // precondition failure, on every launch once persisted.
    func testAppendJoinsAnAlbumSplitAcrossBatches() {
        let list = forYouItems(from: [.message(self.message(self.channelA, 10, date: 300, group: 7)), .message(self.message(self.channelA, 11, date: 300, group: 7))])
        let batch = forYouItems(from: [.message(self.message(self.channelA, 12, date: 300, group: 7)), .message(self.message(self.channelB, 3, date: 3))])
        XCTAssertEqual(appendingForYouBatch(list, batch).map(forYouTestDescription), ["10,11,12", "3"])
    }

    func testPrependJoinsAnAlbumSplitAcrossBatches() {
        let list = forYouItems(from: [.message(self.message(self.channelA, 10, date: 300, group: 7))])
        let batch = forYouItems(from: [.message(self.message(self.channelB, 3, date: 3)), .message(self.message(self.channelA, 11, date: 300, group: 7))])
        XCTAssertEqual(prependingForYouBatch(list, batch).map(forYouTestDescription), ["3", "10,11"])
    }

    func testPrependPutsTheBatchOnTop() {
        let list = forYouItems(from: [.message(self.message(self.channelA, 1, date: 1))])
        let batch = forYouItems(from: [.message(self.message(self.channelB, 3, date: 3))])
        XCTAssertEqual(prependingForYouBatch(list, batch).map(forYouTestDescription), ["3", "1"])
    }

    func testPostCountIgnoresTheBlock() {
        XCTAssertEqual(forYouPostCount(forYouItems(from: [.interests, .message(self.message(self.channelA, 1, date: 1))])), 1)
    }

    // An Added feed that loaded empty used to stay empty: the newer probe needs a top entry to page from.
    func testRevalidatingAnEmptyAddedFeedReloadsIt() {
        XCTAssertEqual(addedFeedRevalidation(hasEntries: false, isLoadingInitial: false, hasNewer: false), .reloadInitial)
    }

    func testRevalidatingAnAddedFeedProbesForNewerPosts() {
        XCTAssertEqual(addedFeedRevalidation(hasEntries: true, isLoadingInitial: false, hasNewer: false), .loadNewer)
        // The pill already offers them.
        XCTAssertEqual(addedFeedRevalidation(hasEntries: true, isLoadingInitial: false, hasNewer: true), .none)
    }

    func testRevalidatingDuringTheFirstLoadDoesNothing() {
        XCTAssertEqual(addedFeedRevalidation(hasEntries: false, isLoadingInitial: true, hasNewer: false), .none)
        XCTAssertEqual(addedFeedRevalidation(hasEntries: true, isLoadingInitial: true, hasNewer: false), .none)
    }

    func testSnapshotKeepsTheTopItems() {
        let list = forYouItems(from: (1 ... 310).map { .message(self.message(self.channelA, Int32($0), date: Int32($0))) })
        let snapshot = forYouSnapshotItems(list, maxItems: 300)
        XCTAssertEqual(snapshot.count, 300)
        XCTAssertEqual(snapshot.first.map(forYouTestDescription), "1")
        XCTAssertEqual(snapshot.last.map(forYouTestDescription), "300")
    }
}

private func forYouTestDescription(_ item: EngineForYouItem) -> String {
    switch item {
    case .interests:
        return "interests"
    case let .post(entry):
        return entry.messageIds.map { "\($0.id)" }.joined(separator: ",")
    }
}

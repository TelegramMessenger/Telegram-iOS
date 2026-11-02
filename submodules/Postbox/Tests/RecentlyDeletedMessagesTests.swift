import Foundation
import XCTest
@testable import Postbox

/// The in-memory record of recently deleted messages (`RecentlyDeletedMessages`, read through
/// `Transaction.wasMessageDeletedRecently`). TelegramCore's history fills store no answer message on it: the
/// server's answer to a request that was in flight during a deletion can predate the deletion (owner decision
/// D2, 2026-10-15). The record holds what a deletion asked for, never-stored messages included, and expires
/// and drops entries but never widens them.
final class RecentlyDeletedMessagesTests: XCTestCase {
    /// A clock the test moves by hand.
    private final class TestClock {
        var time: Double = 1000.0
    }

    private let peer: Int64 = 900
    private var fixture: PostboxFixture?

    override func tearDown() {
        self.fixture?.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var peerId: PeerId {
        return MessageHistoryTableFixture.peerId(self.peer)
    }

    private func id(_ id: Int32, peer: Int64? = nil) -> MessageId {
        return MessageHistoryTableFixture.messageId(peer: peer ?? self.peer, id: id)
    }

    private func makeRecord(_ clock: TestClock, capacity: Int = 100, rangeCapacity: Int = 10) -> RecentlyDeletedMessages {
        return RecentlyDeletedMessages(lifetime: 300.0, capacity: capacity, rangeCapacity: rangeCapacity, now: {
            return clock.time
        })
    }

    private func makeFixture() -> PostboxFixture {
        let fixture = PostboxFixture(name: "RecentlyDeletedMessagesTests")
        self.fixture = fixture
        return fixture
    }

    /// Messages `ids` of the test chat, dated `1000 + id`, from `authorId`.
    private func store(_ fixture: PostboxFixture, _ ids: [Int32], authorId: PeerId? = nil) {
        let messages = ids.map { id -> StoreMessage in
            return StoreMessage(id: self.id(id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: 1000 + id, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "m\(id)", attributes: [], media: [])
        }
        fixture.transaction { transaction -> Void in
            let _ = transaction.addMessages(messages, location: .Random)
        }
    }

    /// Which of `ids` (of the test chat) `Transaction.wasMessageDeletedRecently` reports.
    private func deleted(_ fixture: PostboxFixture, _ ids: [Int32]) -> [Int32] {
        let messageIds = ids.map { self.id($0) }
        return fixture.transaction { transaction -> [Int32] in
            return messageIds.filter { transaction.wasMessageDeletedRecently($0) }.map { $0.id }
        } ?? []
    }

    // MARK: - The record

    /// An id is recorded for its own chat; a global id names the message in whichever chat holds it, but
    /// only where the namespaces have global ids; a range is per chat and namespace.
    func testRecordsIdsGlobalIdsAndRanges() {
        let record = self.makeRecord(TestClock())
        record.add(ids: [self.id(5)])
        record.add(globalIds: [7])
        record.add(peerId: self.peerId, namespace: PostboxFixture.messageNamespace, range: 20 ... 30)

        XCTAssertTrue(record.contains(self.id(5), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(6), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(5, peer: 901), matchesGlobalId: false), "an id is per chat")
        XCTAssertTrue(record.contains(self.id(7, peer: 901), matchesGlobalId: true), "a global id names the message in whichever chat holds it")
        XCTAssertFalse(record.contains(self.id(7), matchesGlobalId: false), "a global id counts only where the namespaces have global ids")
        XCTAssertTrue(record.contains(self.id(20), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(25), matchesGlobalId: false), "a range holds ids that were never stored")
        XCTAssertTrue(record.contains(self.id(30), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(19), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(31), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(25, peer: 901), matchesGlobalId: false), "a range is per chat")
        XCTAssertFalse(record.contains(MessageId(peerId: self.peerId, namespace: PostboxFixture.messageNamespace + 1, id: 25), matchesGlobalId: false), "a range is per namespace")
    }

    /// Every kind of entry lives `lifetime` seconds (300 here) from when it was recorded.
    func testEntriesExpireAfterTheLifetime() {
        let clock = TestClock()
        let record = self.makeRecord(clock)
        record.add(ids: [self.id(5)])
        record.add(globalIds: [7])
        record.add(peerId: self.peerId, namespace: PostboxFixture.messageNamespace, range: 20 ... 30)

        clock.time += 299.0
        XCTAssertTrue(record.contains(self.id(5), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(7), matchesGlobalId: true))
        XCTAssertTrue(record.contains(self.id(25), matchesGlobalId: false))

        clock.time += 1.0
        XCTAssertFalse(record.contains(self.id(5), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(7), matchesGlobalId: true))
        XCTAssertFalse(record.contains(self.id(25), matchesGlobalId: false))

        // A later recording prunes what expired and lives its own lifetime.
        record.add(ids: [self.id(6)])
        XCTAssertTrue(record.contains(self.id(6), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(5), matchesGlobalId: false))
    }

    /// Past the capacity (ids and global ids together) the oldest entries are dropped.
    func testOldestEntriesAreDroppedPastTheCapacity() {
        let record = self.makeRecord(TestClock(), capacity: 3)
        record.add(ids: [self.id(1), self.id(2), self.id(3)])
        record.add(ids: [self.id(4)])

        XCTAssertFalse(record.contains(self.id(1), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(2), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(4), matchesGlobalId: false))

        record.add(globalIds: [9])
        XCTAssertFalse(record.contains(self.id(2), matchesGlobalId: false), "global ids count toward the same capacity")
        XCTAssertTrue(record.contains(self.id(3), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(9), matchesGlobalId: true))
    }

    /// An id recorded again keeps its newer entry when its older one is dropped, by capacity or by age.
    func testRecordingAnIdAgainKeepsItRecorded() {
        let clock = TestClock()
        let record = self.makeRecord(clock, capacity: 2)
        record.add(ids: [self.id(1)])
        record.add(ids: [self.id(2)])
        record.add(ids: [self.id(1)])

        // Three entries for a capacity of two: the oldest, 1's first, is dropped.
        XCTAssertTrue(record.contains(self.id(1), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(2), matchesGlobalId: false))

        record.add(ids: [self.id(3)])
        XCTAssertFalse(record.contains(self.id(2), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(1), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(3), matchesGlobalId: false))

        // By age: recorded at 1000 and again at 1200, 1 is still recorded at 1301, after its first entry expired.
        let ageClock = TestClock()
        let aged = self.makeRecord(ageClock)
        aged.add(ids: [self.id(1)])
        ageClock.time = 1200.0
        aged.add(ids: [self.id(1)])
        ageClock.time = 1301.0
        aged.add(ids: [self.id(2)])
        XCTAssertTrue(aged.contains(self.id(1), matchesGlobalId: false))
        ageClock.time = 1500.0
        XCTAssertFalse(aged.contains(self.id(1), matchesGlobalId: false))
    }

    /// Past the range capacity the oldest range is dropped, never merged into a wider one.
    func testOldestRangesAreDroppedPastTheRangeCapacity() {
        let record = self.makeRecord(TestClock(), rangeCapacity: 2)
        record.add(peerId: self.peerId, namespace: PostboxFixture.messageNamespace, range: 1 ... 1)
        record.add(peerId: self.peerId, namespace: PostboxFixture.messageNamespace, range: 3 ... 3)
        record.add(peerId: self.peerId, namespace: PostboxFixture.messageNamespace, range: 5 ... 5)

        XCTAssertFalse(record.contains(self.id(1), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(2), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(3), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(4), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(5), matchesGlobalId: false))
    }

    // MARK: - Every deletion path records

    /// `deleteMessages` records every id it was asked to delete, a never-stored one (50) included.
    func testDeleteMessagesRecordsEveryRequestedId() {
        let fixture = self.makeFixture()
        self.store(fixture, [1, 2, 3])
        let requested = [self.id(2), self.id(50)]
        fixture.transaction { transaction -> Void in
            transaction.deleteMessages(requested, forEachMedia: nil)
        }

        XCTAssertEqual(self.deleted(fixture, [1, 2, 3, 50, 51]), [2, 50])
    }

    /// `deleteMessagesInRange` records its whole range, stored or not.
    func testDeleteMessagesInRangeRecordsTheWholeRange() {
        let fixture = self.makeFixture()
        self.store(fixture, [1, 5, 9])
        let peerId = self.peerId
        fixture.transaction { transaction -> Void in
            transaction.deleteMessagesInRange(peerId: peerId, namespace: PostboxFixture.messageNamespace, minId: 4, maxId: 8, forEachMedia: nil)
        }

        XCTAssertEqual(self.deleted(fixture, [1, 3, 4, 5, 6, 8, 9]), [4, 5, 6, 8])
    }

    /// `clearHistory` names no ids: it records the ones it removed.
    func testClearHistoryRecordsTheIdsItRemoved() {
        let fixture = self.makeFixture()
        self.store(fixture, [1, 2])
        let peerId = self.peerId
        fixture.transaction { transaction -> Void in
            transaction.clearHistory(peerId, threadId: nil, minTimestamp: nil, maxTimestamp: nil, namespaces: .all, forEachMedia: nil)
        }

        XCTAssertEqual(self.deleted(fixture, [1, 2, 3]), [1, 2])
    }

    /// Forgetting a chat drops its ids and ranges, as if they had expired, and nothing of another chat; global ids
    /// name no chat and stay. A deletion recorded afterwards is recorded as usual.
    func testForgettingAChatDropsItsIdsAndRangesOnly() {
        let record = self.makeRecord(TestClock())
        record.add(ids: [self.id(5), self.id(5, peer: 901)])
        record.add(globalIds: [7])
        record.add(peerId: self.peerId, namespace: PostboxFixture.messageNamespace, range: 20 ... 30)
        record.add(peerId: MessageHistoryTableFixture.peerId(901), namespace: PostboxFixture.messageNamespace, range: 20 ... 30)

        record.forget(peerId: self.peerId)

        XCTAssertFalse(record.contains(self.id(5), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(25), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(5, peer: 901), matchesGlobalId: false), "another chat's id stays")
        XCTAssertTrue(record.contains(self.id(25, peer: 901), matchesGlobalId: false), "another chat's range stays")
        XCTAssertTrue(record.contains(self.id(7), matchesGlobalId: true), "a global id names no chat and stays")

        record.add(ids: [self.id(5)])
        XCTAssertTrue(record.contains(self.id(5), matchesGlobalId: false))
    }

    /// A forgotten chat's ids no longer count toward the capacity. At capacity 3: 1 of the test chat, then 1 and 2
    /// of chat 901, which is forgotten, then 2 and 3 of the test chat. Three ids are recorded, so all three stay.
    /// Before the fix the forgotten ids still counted, and 1 was dropped as the oldest.
    func testForgottenIdsDoNotCountTowardTheCapacity() {
        let record = self.makeRecord(TestClock(), capacity: 3)
        record.add(ids: [self.id(1)])
        record.add(ids: [self.id(1, peer: 901), self.id(2, peer: 901)])
        record.forget(peerId: MessageHistoryTableFixture.peerId(901))
        record.add(ids: [self.id(2), self.id(3)])

        XCTAssertTrue(record.contains(self.id(1), matchesGlobalId: false), "a forgotten chat's ids pushed out a recorded one")
        XCTAssertTrue(record.contains(self.id(2), matchesGlobalId: false))
        XCTAssertTrue(record.contains(self.id(3), matchesGlobalId: false))
        XCTAssertFalse(record.contains(self.id(1, peer: 901), matchesGlobalId: false))
    }

    /// A removal that was local only (a debug reset clearing a chat's cached history) is forgotten through the
    /// transaction, so the next fetch of that chat stores its messages again.
    func testTransactionForgetsAChatsRecentDeletions() {
        let fixture = self.makeFixture()
        self.store(fixture, [1, 2])
        let peerId = self.peerId
        fixture.transaction { transaction -> Void in
            transaction.clearHistory(peerId, threadId: nil, minTimestamp: nil, maxTimestamp: nil, namespaces: .all, forEachMedia: nil)
            transaction.forgetRecentlyDeletedMessages(peerId: peerId)
        }

        XCTAssertEqual(self.deleted(fixture, [1, 2]), [])
    }

    /// `removeAllMessagesWithAuthor` records the ids it removed: the author's, not the others.
    func testRemoveAllMessagesWithAuthorRecordsTheIdsItRemoved() {
        let fixture = self.makeFixture()
        let authorId = MessageHistoryTableFixture.peerId(950)
        self.store(fixture, [1, 2], authorId: authorId)
        self.store(fixture, [3])
        let peerId = self.peerId
        fixture.transaction { transaction -> Void in
            transaction.removeAllMessagesWithAuthor(peerId, authorId: authorId, namespace: PostboxFixture.messageNamespace, forEachMedia: nil)
        }

        XCTAssertEqual(self.deleted(fixture, [1, 2, 3]), [1, 2])
        XCTAssertNotNil(fixture.transaction { transaction -> Message? in
            return transaction.getMessage(self.id(3))
        } ?? nil)
    }

    /// A message whose index moves (a new timestamp) and a message stored again are not deletions.
    func testMovingAMessageIsNotADeletion() {
        let fixture = self.makeFixture()
        self.store(fixture, [1, 2])
        let movedId = self.id(1)
        fixture.transaction { transaction -> Void in
            transaction.updateMessage(movedId, update: { message in
                return .update(StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: message.timestamp + 100, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: nil, authorId: nil, text: message.text, attributes: [], media: []))
            })
        }
        self.store(fixture, [2])

        XCTAssertEqual(self.deleted(fixture, [1, 2]), [])
    }

    /// The fixture's seed has no global-id namespaces, so a deleted global id matches none of its messages.
    /// TelegramCore's (private chats and basic groups, Cloud namespace) is exercised end to end by
    /// HistoryFillRecentDeletionTests.
    func testGlobalIdsCountOnlyWhereTheNamespacesHaveThem() {
        let fixture = self.makeFixture()
        fixture.transaction { transaction -> Void in
            transaction.deleteMessagesWithGlobalIds([7], forEachMedia: nil)
        }

        XCTAssertEqual(self.deleted(fixture, [7]), [])
    }
}

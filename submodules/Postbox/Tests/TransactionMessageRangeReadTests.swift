import Foundation
import XCTest
@testable import Postbox

/// The bounded reads a sync step uses to find the stored messages of one chat inside an id range:
/// `Transaction.messageIdsInRange` (the id index) and `Transaction.messageIndicesWithTag(…range:…)` (a tag's
/// index, which is ordered by date). TelegramCore confirms the stored messages a history fill or a chat-list
/// page leaves out with them.
final class TransactionMessageRangeReadTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let peer: Int64 = 900
    private let otherPeer: Int64 = 901
    private let tag = MessageTags(rawValue: 1 << 3)
    private let otherTag = MessageTags(rawValue: 1 << 4)

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "TransactionMessageRangeReadTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func peerId(_ peer: Int64) -> PeerId {
        return MessageHistoryTableFixture.peerId(peer)
    }

    private func store(peer: Int64? = nil, _ messages: [(id: Int32, timestamp: Int32, tags: MessageTags)]) {
        let peer = peer ?? self.peer
        let storeMessages = messages.map { message -> StoreMessage in
            return MessageHistoryTableFixture.storeMessage(id: MessageHistoryTableFixture.messageId(peer: peer, id: message.id), timestamp: message.timestamp, text: "m\(message.id)", tags: message.tags)
        }
        self.fixture.transaction { transaction -> Void in
            let _ = transaction.addMessages(storeMessages, location: .Random)
        }
    }

    private func ids(_ range: ClosedRange<Int32>, namespace: MessageId.Namespace = PostboxFixture.messageNamespace, limit: Int, fromUpperBound: Bool = false) -> [Int32] {
        let peerId = self.peerId(self.peer)
        return self.fixture.transaction { transaction -> [Int32] in
            return transaction.messageIdsInRange(peerId: peerId, namespace: namespace, range: range, limit: limit, fromUpperBound: fromUpperBound).map { $0.id }
        } ?? []
    }

    private func taggedIds(_ range: ClosedRange<Int32>, tag: MessageTags? = nil, limit: Int, fromUpperBound: Bool = false) -> [Int32] {
        let peerId = self.peerId(self.peer)
        let tag = tag ?? self.tag
        return self.fixture.transaction { transaction -> [Int32] in
            return transaction.messageIndicesWithTag(peerId: peerId, namespace: PostboxFixture.messageNamespace, tag: tag, range: range, limit: limit, fromUpperBound: fromUpperBound).map { $0.id.id }
        } ?? []
    }

    // MARK: - messageIdsInRange

    /// The stored ids of one chat inside an id range, in id order (not date order), from either end, with a
    /// limit. A limit above `Int32.max` asks for every id: `SqliteValueBox` binds the limit as `Int32`, and
    /// such a limit used to trap there.
    func testMessageIdsInRangeReadsTheIdIndex() {
        // Id 9 is the oldest message by date, as an imported one is.
        self.store([(9, 900, []), (3, 1000, []), (5, 1001, [])])
        self.store(peer: self.otherPeer, [(4, 1002, [])])

        XCTAssertEqual(self.ids(1 ... 100, limit: 0), [3, 5, 9])
        XCTAssertEqual(self.ids(5 ... 9, limit: 0), [5, 9])
        XCTAssertEqual(self.ids(1 ... 100, limit: 2), [3, 5])
        XCTAssertEqual(self.ids(1 ... 100, limit: 2, fromUpperBound: true), [9, 5])
        XCTAssertEqual(self.ids(6 ... 8, limit: 0), [])
        XCTAssertEqual(self.ids(1 ... 100, namespace: PostboxFixture.messageNamespace + 1, limit: 0), [])
        XCTAssertEqual(self.ids(1 ... 100, limit: Int.max), [3, 5, 9])
        XCTAssertEqual(self.ids(1 ... 100, limit: Int(Int32.max) + 1, fromUpperBound: true), [9, 5, 3])
    }

    // MARK: - messageIndicesWithTag(range:)

    /// Only the messages carrying the tag, of this chat, inside the range, in date order from either end,
    /// with a limit that counts what is returned.
    func testTaggedIndicesInRangeReadOnlyTheRange() {
        // Odd ids carry the tag; 21 carries another tag only.
        let messages = (Int32(1) ... Int32(20)).map { id -> (id: Int32, timestamp: Int32, tags: MessageTags) in
            return (id, 1000 + id, id % 2 == 1 ? self.tag : [])
        }
        self.store(messages + [(21, 1021, self.otherTag)])
        self.store(peer: self.otherPeer, [(7, 1007, self.tag)])

        XCTAssertEqual(self.taggedIds(5 ... 15, limit: 0), [5, 7, 9, 11, 13, 15])
        XCTAssertEqual(self.taggedIds(5 ... 15, limit: 2), [5, 7])
        XCTAssertEqual(self.taggedIds(5 ... 15, limit: 2, fromUpperBound: true), [15, 13])
        XCTAssertEqual(self.taggedIds(6 ... 6, limit: 0), [])
        // No stored message below 1 or above 21: the read runs to both ends of the chat's index.
        XCTAssertEqual(self.taggedIds(1 ... 100, limit: 0), [1, 3, 5, 7, 9, 11, 13, 15, 17, 19])
        XCTAssertEqual(self.taggedIds(1 ... 100, tag: self.otherTag, limit: 0), [21])
    }

    /// A range deep in a chat with more than 1000 tagged messages is read in full: the 1000 newest
    /// (`getMessageIndicesWithTag`) do not reach it.
    func testTaggedIndicesInRangeReachBelowTheThousandNewest() {
        self.store((Int32(1) ... Int32(1500)).map { id -> (id: Int32, timestamp: Int32, tags: MessageTags) in
            return (id, 1000 + id, self.tag)
        })

        XCTAssertEqual(self.taggedIds(100 ... 110, limit: 0), Array(Int32(100) ... Int32(110)))
        XCTAssertEqual(self.taggedIds(100 ... 110, limit: 3, fromUpperBound: true), [110, 109, 108])
        let peerId = self.peerId(self.peer)
        let newest = self.fixture.transaction { transaction -> [MessageIndex] in
            return transaction.getMessageIndicesWithTag(peerId: peerId, threadId: nil, namespace: PostboxFixture.messageNamespace, tag: self.tag)
        } ?? []
        XCTAssertFalse(newest.contains(where: { $0.id.id <= 110 }))
    }

    /// Messages sharing their neighbours' date are still inside the bounds (the index orders by date, then
    /// id).
    func testTaggedIndicesInRangeWithEqualDates() {
        self.store([(10, 1000, []), (11, 1000, self.tag), (12, 1000, self.tag), (13, 1000, [])])

        XCTAssertEqual(self.taggedIds(11 ... 12, limit: 0), [11, 12])
    }

    /// A neighbour whose date is out of order with its id (13, imported, is dated before 10) would make the
    /// bounds cross; the chat's whole index for the tag is read instead, so nothing in the range is missed.
    func testTaggedIndicesInRangeWithNeighboursOutOfOrder() {
        self.store([(10, 1010, []), (11, 1011, self.tag), (12, 1012, self.tag), (13, 500, [])])

        XCTAssertEqual(self.taggedIds(11 ... 12, limit: 0), [11, 12])
        XCTAssertEqual(self.taggedIds(11 ... 12, limit: 1, fromUpperBound: true), [12])
    }
}

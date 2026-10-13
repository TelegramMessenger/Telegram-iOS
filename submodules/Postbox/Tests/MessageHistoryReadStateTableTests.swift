import Foundation
import XCTest
@testable import Postbox

/// Deleting unread incoming messages subtracts them from the peer's unread count.
/// When more are deleted than the count knows about, the count is wrong and a
/// validation is scheduled; until it runs the stored count must be zero, not the
/// number of deleted messages.
final class MessageHistoryReadStateTableTests: XCTestCase {
    private var fixture: MessageHistoryTableFixture!

    private let peer = MessageHistoryTableFixture.peerId(200)
    private let namespace = MessageHistoryTableFixture.messageNamespace

    override func setUp() {
        super.setUp()
        self.fixture = MessageHistoryTableFixture(name: "MessageHistoryReadStateTableTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func index(_ id: Int32) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: self.peer, namespace: self.namespace, id: id), timestamp: 1000 + id)
    }

    /// Nothing read yet, `count` unread according to the server.
    private func setUnreadCount(_ count: Int32) {
        self.fixture.transaction { _, _ in
            let _ = self.fixture.readStateTable.resetStates(self.peer, namespaces: [self.namespace: .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 10, count: count, markedUnread: false)])
        }
    }

    /// The committed count, read after dropping the table's in-memory copy.
    private func storedUnreadCount() -> Int32? {
        var count: Int32?
        self.fixture.queue.sync {
            self.fixture.readStateTable.clearMemoryCache()
            count = self.fixture.readStateTable.getCombinedState(self.peer)?.states.first(where: { $0.0 == self.namespace })?.1.count
        }
        return count
    }

    // MARK: - Table

    func testDeletingMoreUnreadMessagesThanCountedStoresZeroAndInvalidates() {
        self.setUnreadCount(2)

        let (state, invalidate) = self.fixture.transaction { _, _ in
            self.fixture.readStateTable.deleteMessages(self.peer, indices: (1 ... 5).map(self.index), incomingStatsInIndices: { _, _, indices in (indices.count, false) })
        }

        XCTAssertTrue(invalidate)
        XCTAssertEqual(state?.states.first?.1.count, 0)
        XCTAssertEqual(self.storedUnreadCount(), 0)
    }

    func testDeletingFewerUnreadMessagesThanCountedSubtractsThem() {
        self.setUnreadCount(7)

        let (state, invalidate) = self.fixture.transaction { _, _ in
            self.fixture.readStateTable.deleteMessages(self.peer, indices: (1 ... 5).map(self.index), incomingStatsInIndices: { _, _, indices in (indices.count, false) })
        }

        XCTAssertFalse(invalidate)
        XCTAssertEqual(state?.states.first?.1.count, 2)
        XCTAssertEqual(self.storedUnreadCount(), 2)
    }

    func testAHoleAmongTheDeletedMessagesInvalidatesButStillSubtracts() {
        self.setUnreadCount(7)

        let (state, invalidate) = self.fixture.transaction { _, _ in
            self.fixture.readStateTable.deleteMessages(self.peer, indices: (1 ... 5).map(self.index), incomingStatsInIndices: { _, _, indices in (indices.count, true) })
        }

        XCTAssertTrue(invalidate)
        XCTAssertEqual(state?.states.first?.1.count, 2)
        XCTAssertEqual(self.storedUnreadCount(), 2)
    }

    // MARK: - Through the history table

    func testRemovingMoreUnreadMessagesThanCountedLeavesZeroAndSchedulesValidation() {
        let messages = (1 ... 5).map { id in
            MessageHistoryTableFixture.storeMessage(id: MessageId(peerId: self.peer, namespace: self.namespace, id: id), timestamp: 1000 + id, text: "m\(id)", flags: [.Incoming])
        }
        // A read state exists before the messages arrive, so adding them queues no
        // validation of its own and the one asserted below can only come from the removal.
        self.setUnreadCount(0)
        let addOperations = self.fixture.addMessages(messages)
        XCTAssertNil(addOperations.updatedPeerReadStateOperations[self.peer] ?? nil)
        // The server then reports fewer unread than are stored locally.
        self.setUnreadCount(2)

        let operations = self.fixture.removeMessages(messages.map { $0.index!.id })

        XCTAssertEqual(self.storedUnreadCount(), 0)
        XCTAssertEqual(operations.updatedPeerReadStateOperations[self.peer] ?? nil, .Validate)
    }
}

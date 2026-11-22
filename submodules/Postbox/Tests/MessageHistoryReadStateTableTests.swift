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

    // MARK: - Reading past the newest stored message

    /// The server counted `count` unread up to its newest message, 12; this device stored up to 11, with nothing in
    /// between read yet.
    private func setServerTopUnstored(count: Int32) {
        self.fixture.transaction { _, _ in
            let _ = self.fixture.readStateTable.resetStates(self.peer, namespaces: [self.namespace: .idBased(maxIncomingReadId: 10, maxOutgoingReadId: 0, maxKnownId: 12, count: count, markedUnread: false)])
        }
    }

    /// Marking the chat read from the chat list reads up to the server's newest message: every counted message is
    /// read, the stored one (11) and the one never stored here (12).
    func testAnInteractiveReadPastTheStoredTopAtTheServersTopReadsEverything() {
        self.setServerTopUnstored(count: 2)

        let (state, holes) = self.fixture.transaction { _, _ in
            self.fixture.readStateTable.applyIncomingMaxReadId(MessageId(peerId: self.peer, namespace: self.namespace, id: 12), incomingStatsInRange: { _, _, _ in (1, false) }, topMessageId: (11, false), interactive: true)
        }

        XCTAssertEqual(state?.states.first?.1.count, 0)
        XCTAssertEqual(state?.states.first?.1, .idBased(maxIncomingReadId: 12, maxOutgoingReadId: 0, maxKnownId: 12, count: 0, markedUnread: false))
        // The stored messages accounted for one of the two: the count disagreed with them, so it is validated.
        XCTAssertTrue(holes)
        XCTAssertEqual(self.storedUnreadCount(), 0)
    }

    /// Short of the server's newest message, an unstored message may still be unread: only what is stored is
    /// subtracted.
    func testAnInteractiveReadPastTheStoredTopShortOfTheServersTopSubtractsWhatIsStored() {
        self.setServerTopUnstored(count: 3)

        let (state, _) = self.fixture.transaction { _, _ in
            self.fixture.readStateTable.applyIncomingMaxReadId(MessageId(peerId: self.peer, namespace: self.namespace, id: 11), incomingStatsInRange: { _, _, _ in (1, false) }, topMessageId: (9, false), interactive: true)
        }

        XCTAssertEqual(state?.states.first?.1.count, 2)
    }

    /// An interactive read never moves the mark back, even past the stored top and the server's top.
    func testAnInteractiveReadBelowTheMarkLeavesItInPlace() {
        self.fixture.transaction { _, _ in
            let _ = self.fixture.readStateTable.resetStates(self.peer, namespaces: [self.namespace: .idBased(maxIncomingReadId: 14, maxOutgoingReadId: 0, maxKnownId: 12, count: 1, markedUnread: false)])
        }

        let (state, _) = self.fixture.transaction { _, _ in
            self.fixture.readStateTable.applyIncomingMaxReadId(MessageId(peerId: self.peer, namespace: self.namespace, id: 13), incomingStatsInRange: { _, _, _ in (0, false) }, topMessageId: (11, false), interactive: true)
        }

        XCTAssertNil(state)
        XCTAssertEqual(self.storedUnreadCount(), 1)
    }

    /// The server's own read past the stored top keeps subtracting what is stored, as before.
    func testAServerReadPastTheStoredTopSubtractsWhatIsStored() {
        self.setServerTopUnstored(count: 2)

        let (state, holes) = self.fixture.transaction { _, _ in
            self.fixture.readStateTable.applyIncomingMaxReadId(MessageId(peerId: self.peer, namespace: self.namespace, id: 12), incomingStatsInRange: { _, _, _ in (1, false) }, topMessageId: (11, false))
        }

        XCTAssertEqual(state?.states.first?.1.count, 1)
        XCTAssertFalse(holes)
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

import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A secret chat's read state is index-based, and the only thing the client can tell the
/// server about it is a date: the scheduled push goes out as
/// `messages.readEncryptedHistory(peer:max_date:)` carrying `maxIncomingReadIndex.timestamp`.
/// The server rejects `max_date = 0` with 400 MAX_DATE_INVALID.
///
/// Two guards in TelegramCore rest on that: `pushPeerReadState` skips the request when the
/// timestamp is zero, and `_internal_applyMaxReadMessageIdInteractively` never applies an
/// id-only read to a secret chat at all. These tests pin the premises both rest on - what
/// an index-based read state does with an invented index, and that a push can be scheduled
/// with a zero marker by a route no caller can fix. If one ever stops holding, the guard has
/// lost a reason to exist and should be revisited rather than deleted; the other premises,
/// and a read state reset to `MessageIndex.lowerBound`, remain.
///
/// Note these pin Postbox behaviour the guards depend on, not the guards themselves: both
/// live in TelegramCore, which has no test target.
final class SecretChatReadPushTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let peerId = MessageHistoryTableFixture.peerId(900)
    private let namespace = PostboxFixture.messageNamespace

    /// A real incoming message's date, well clear of zero.
    private let messageTimestamp: Int32 = 1_700_000_000

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "SecretChatReadPushTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func message(_ id: Int32) -> StoreMessage {
        return StoreMessage(id: MessageId(peerId: self.peerId, namespace: self.namespace, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: self.messageTimestamp + id, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "m\(id)", attributes: [], media: [])
    }

    /// The state a secret chat is created with: index-based, nothing read yet, so the read
    /// marker is `MessageIndex.lowerBound` and its timestamp is zero.
    private func seedNeverReadChat(unreadCount: Int32, messages: [StoreMessage]) {
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: self.peerId, title: "Secret")], update: { _, updated in updated })
            if !messages.isEmpty {
                let _ = transaction.addMessages(messages, location: .Random)
            }
            transaction.resetIncomingReadStates([self.peerId: [self.namespace: .indexBased(
                maxIncomingReadIndex: MessageIndex.lowerBound(peerId: self.peerId),
                maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: self.peerId),
                count: unreadCount,
                markedUnread: false
            )]])
        }
    }

    private func observeScheduledOperations() -> PostboxFixture.Recorder<[PeerId: PeerReadStateSynchronizationOperation]> {
        return self.fixture.observe(self.fixture.postbox.synchronizePeerReadStatesView() |> map { $0.operations })
    }

    /// The `max_date` a scheduled push would send for this peer.
    private func pushedMaxDate() -> Int32? {
        return self.fixture.transaction { transaction -> Int32? in
            guard let states = transaction.getPeerReadStates(self.peerId) else {
                return nil
            }
            for (stateNamespace, state) in states where stateNamespace == self.namespace {
                if case let .indexBased(maxIncomingReadIndex, _, _, _) = state {
                    return maxIncomingReadIndex.timestamp
                }
            }
            return nil
        } ?? nil
    }

    /// The peer's stored unread count.
    private func unreadCount() -> Int32? {
        return self.fixture.transaction { transaction -> Int32? in
            return transaction.getCombinedPeerReadState(self.peerId)?.count
        } ?? nil
    }

    private func assertPushScheduled(_ operations: [PeerId: PeerReadStateSynchronizationOperation], file: StaticString = #file, line: UInt = #line) {
        guard let operation = operations[self.peerId] else {
            XCTFail("no synchronization operation was scheduled", file: file, line: line)
            return
        }
        guard case .Push = operation else {
            XCTFail("expected a push, got \(operation)", file: file, line: line)
            return
        }
    }

    // MARK: - Tests

    /// An id-only caller has no date, so the index it invents is `timestamp: 0`. An id-based
    /// read state ignores that; an index-based one adopts it as its read marker, from where
    /// it is pushed as the `max_date` the server rejects. This is why the notification-reply
    /// and Siri paths no longer apply an id-only read to a secret chat.
    func testReadingByMessageIdAloneSchedulesAPushWithAZeroMaxDate() {
        self.seedNeverReadChat(unreadCount: 1, messages: [self.message(1)])
        let operations = self.observeScheduledOperations()
        XCTAssertNil(operations.waitForValues(count: 1).last?[self.peerId])

        self.fixture.transaction { transaction in
            let _ = transaction.applyInteractiveReadMaxIndex(MessageIndex(id: MessageId(peerId: self.peerId, namespace: self.namespace, id: 1), timestamp: 0))
        }

        self.assertPushScheduled(operations.waitForValues(count: 2).last ?? [:])
        XCTAssertEqual(self.pushedMaxDate(), 0)
    }

    /// Reading with a real index is the control - what opening the chat does: it stores that
    /// date, and a push carrying it is one the server accepts.
    func testReadingByFullIndexSchedulesAPushWithTheMessageDate() {
        self.seedNeverReadChat(unreadCount: 1, messages: [self.message(1)])
        let operations = self.observeScheduledOperations()
        XCTAssertNil(operations.waitForValues(count: 1).last?[self.peerId])

        self.fixture.transaction { transaction in
            let _ = transaction.applyInteractiveReadMaxIndex(MessageIndex(id: MessageId(peerId: self.peerId, namespace: self.namespace, id: 1), timestamp: self.messageTimestamp + 1))
        }

        self.assertPushScheduled(operations.waitForValues(count: 2).last ?? [:])
        XCTAssertEqual(self.pushedMaxDate(), self.messageTimestamp + 1)
    }

    /// A bare id in a namespace the peer has no read state for - a secret chat notification
    /// carries a `Cloud` id, while its read states are `SecretIncoming` and `Local` - changes
    /// no state at all and asks the server instead. That bare push is what looped, and is why
    /// the caller applies nothing rather than a zero index when it cannot resolve a real one.
    func testReadingByIdInAnUnknownNamespaceSchedulesABarePushAndChangesNothing() {
        self.seedNeverReadChat(unreadCount: 1, messages: [self.message(1)])
        let operations = self.observeScheduledOperations()
        XCTAssertNil(operations.waitForValues(count: 1).last?[self.peerId])

        let otherNamespace = self.namespace + 1
        self.fixture.transaction { transaction in
            let _ = transaction.applyInteractiveReadMaxIndex(MessageIndex(id: MessageId(peerId: self.peerId, namespace: otherNamespace, id: 1), timestamp: 0))
        }

        self.assertPushScheduled(operations.waitForValues(count: 2).last ?? [:])
        XCTAssertEqual(self.pushedMaxDate(), 0)
        XCTAssertEqual(self.unreadCount(), 1, "nothing was read, yet a push was scheduled")
    }

    /// Marking a chat unread never moves the read marker, so a chat that has never had a
    /// message read schedules a push whose marker is still the zero lower bound.
    func testMarkingANeverReadChatUnreadSchedulesAPushWithAZeroMaxDate() {
        self.seedNeverReadChat(unreadCount: 0, messages: [])
        let operations = self.observeScheduledOperations()
        XCTAssertNil(operations.waitForValues(count: 1).last?[self.peerId])

        self.fixture.transaction { transaction in
            transaction.applyMarkUnread(peerId: self.peerId, namespace: self.namespace, value: true, interactive: true)
        }

        self.assertPushScheduled(operations.waitForValues(count: 2).last ?? [:])
        XCTAssertEqual(self.pushedMaxDate(), 0)
    }
}

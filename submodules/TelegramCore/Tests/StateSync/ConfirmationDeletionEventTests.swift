import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Owner decision D1 (2026-10-15): a message that the account reset's ghost-tail rule or a history fill's
/// stored-message confirmation deletes fires the same app events as a received deletion. Its id reaches
/// `MessagesRemovedContext` (`synchronouslyIsMessageDeletedRemotely` and `…Interactively`) and
/// `AccountStateManager.deletedMessages` once, named as the replay names it: a private-chat or basic-group message by
/// its account-global id (`.global`), a channel message by its full id (`.messageId`); the pipe only once the deleting
/// transaction has committed. Until the fix only the storage changed. The history fill is driven directly, with a state
/// manager made for the account but not started: it hears about the deletions without running a poll.
final class ConfirmationDeletionEventTests: StateSyncTestCase {
    /// Records `deletedMessages` of the manager `makeStateManager` made, subscribed before anything is deleted:
    /// the subscription lands on the manager's queue (`runOn`), and the round trip waits for it.
    private func observeDeletedMessages() -> SignalRecorder<[DeletedMessageId]> {
        let deleted = self.fixture.observe(self.stateManager.deletedMessages)
        self.managerQueueRoundTrip()
        return deleted
    }

    /// Every delivery so far, read once the first has arrived and the manager's queue has run whatever was queued
    /// behind it, so a duplicate would be counted too.
    private func deliveries(_ deleted: SignalRecorder<[DeletedMessageId]>, file: StaticString = #filePath, line: UInt = #line) -> [[DeletedMessageId]] {
        deleted.wait(timeout: 5.0, file: file, line: line, until: { !$0.isEmpty })
        self.managerQueueRoundTrip(file: file, line: line)
        return deleted.values
    }

    /// The account reset deletes the stored private message above the dialog's top (11). Its deletion is delivered
    /// once as `.global(11)` and is known to `MessagesRemovedContext` both ways, as the replay's deletions are; the
    /// kept top message (10) is not.
    func testResetGhostTailDeletionFiresTheReceivedDeletionEventsOnce() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.fixture.storeMessage(peerId: user, id: 11, timestamp: self.baseDate + 11, authorId: user, text: "deleted during the gap")
        self.fixture.seedAccount(state: self.state(pts: 100))
        // `startAccountReset` makes the manager and starts it in one step; the observer must subscribe in between.
        self.makeStateManager()
        let deleted = self.observeDeletedMessages()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(200), topMessage: 10)],
            messages: [StateSyncApi.privateMessage(id: 10, peerUserId: 200, fromUserId: 200, date: self.baseDate + 10, text: "top")],
            users: [StateSyncApi.user(id: 200, firstName: "U200")]
        )))
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()

        // The barrier sits behind the running poll and completes once the follow-up ended the cycle.
        self.drainOperationQueue()

        let deletedId = self.messageId(user, 11)
        let keptId = self.messageId(user, 10)
        XCTAssertNil(self.fixture.message(deletedId), "precondition: the reset deleted 11")
        XCTAssertEqual(self.deliveries(deleted), [[.global(11)]])
        XCTAssertEqual(self.stateManager.synchronouslyIsMessageDeletedRemotely(ids: [deletedId, keptId]), [deletedId])
        XCTAssertEqual(self.stateManager.synchronouslyIsMessageDeletedInteractively(ids: [deletedId, keptId]), [deletedId])
    }

    /// The account reset deletes the stored channel post above the dialog's top (21). Its deletion is delivered once
    /// as `.messageId`, the way the replay names a channel deletion.
    func testResetChannelGhostTailDeletionFiresTheReceivedDeletionEventsOnce() {
        let channel = self.seedChannel(300, pts: 60, storedMessageId: 20)
        self.fixture.storeMessage(peerId: channel, id: 21, timestamp: self.baseDate + 1, authorId: nil, text: "deleted")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        let deleted = self.observeDeletedMessages()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(300), topMessage: 20, pts: 60)],
            messages: [StateSyncApi.channelPost(id: 20, channelId: 300, date: self.baseDate)],
            chats: [StateSyncApi.broadcastChannel(id: 300, title: "C300")]
        )))
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()

        self.drainOperationQueue()

        let deletedId = self.messageId(channel, 21)
        let keptId = self.messageId(channel, 20)
        XCTAssertNil(self.fixture.message(deletedId), "precondition: the reset deleted 21")
        XCTAssertEqual(self.deliveries(deleted), [[.messageId(deletedId)]])
        XCTAssertEqual(self.stateManager.synchronouslyIsMessageDeletedRemotely(ids: [deletedId, keptId]), [deletedId])
        XCTAssertEqual(self.stateManager.synchronouslyIsMessageDeletedInteractively(ids: [deletedId, keptId]), [deletedId])
    }

    /// A history fill confirms the two stored messages its answer left out: 13 is gone and deleted, 11 is still
    /// there and refreshed. Only 13 is delivered, once, as `.global(13)`.
    func testHistoryFillDeletionFiresTheReceivedDeletionEventsOnce() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11, 12, 13], text: "old")
        self.addHistoryFillHole(peerId)
        self.makeStateManager()
        let deleted = self.observeDeletedMessages()
        self.server.on("messages.getHistory", .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "new"),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "new")
        ])))
        self.server.on(Name.messagesGetMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 11, peerUserId: 500, fromUserId: 500, date: self.baseDate + 11, text: "edited")
        ])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        let deletedId = self.messageId(peerId, 13)
        let refreshedId = self.messageId(peerId, 11)
        XCTAssertNil(self.fixture.message(deletedId), "precondition: the fill deleted 13")
        XCTAssertEqual(self.fixture.message(refreshedId)?.text, "edited", "precondition: the fill refreshed 11")
        XCTAssertEqual(self.deliveries(deleted), [[.global(13)]], "only the deleted message, not the refreshed one")
        XCTAssertEqual(self.stateManager.synchronouslyIsMessageDeletedRemotely(ids: [deletedId, refreshedId]), [deletedId])
        XCTAssertEqual(self.stateManager.synchronouslyIsMessageDeletedInteractively(ids: [deletedId, refreshedId]), [deletedId])
    }

    /// `deletedMessages` hears of a confirmation deletion only once the deleting transaction has committed, so no
    /// receiver is told of a deletion it cannot read yet. The confirmation is applied here inside a transaction the
    /// test keeps open for 0.5 s: nothing is delivered while it is open, and the deletion exactly once after it
    /// committed. A report that hopped to the manager's queue straight from inside the transaction (this task's
    /// first draft) was delivered while the transaction was still open.
    func testConfirmationDeletionIsDeliveredOnlyOnceItsTransactionHasCommitted() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 11, timestamp: self.baseDate + 11, authorId: user, text: "deleted")
        self.makeStateManager()
        let deleted = self.observeDeletedMessages()
        let deletedId = self.messageId(user, 11)
        let versions = self.fixture.transaction { transaction -> [MessageId: UInt32] in
            var result: [MessageId: UInt32] = [:]
            if let message = transaction.getMessage(deletedId) {
                result[deletedId] = message.stableVersion
            }
            return result
        } ?? [:]
        let mediaBox = self.fixture.postbox.mediaBox
        let confirmation = StoredMessageConfirmation(existing: [], peers: AccumulatedPeers(), missing: Set([deletedId]))

        let deliveredWhileOpen = self.fixture.transaction { transaction -> Int in
            let _ = applyStoredMessageConfirmation(transaction: transaction, accountPeerId: StateSyncFixture.accountPeerId, mediaBox: mediaBox, confirmation: confirmation, versions: versions)
            // Still inside the deleting transaction: an event sent now has the time to reach the observer.
            let deadline = Date().addingTimeInterval(0.5)
            while deleted.values.isEmpty && Date() < deadline {
                usleep(10_000)
            }
            return deleted.values.count
        }

        XCTAssertEqual(deliveredWhileOpen, 0, "the deletion event was delivered before its transaction committed")
        XCTAssertNil(self.fixture.message(deletedId), "precondition: the confirmation deleted 11")
        XCTAssertEqual(self.deliveries(deleted), [[.global(11)]])
        XCTAssertEqual(self.stateManager.synchronouslyIsMessageDeletedRemotely(ids: [deletedId]), [deletedId])
    }

    /// Each account's manager registers under its own Postbox's media box, so a confirmation deletion reaches only the
    /// manager of the account that applied it (`StoredMessageConfirmationDeletionReporters`). Two accounts, each with
    /// its own Postbox, network and manager, store the same message id; a confirmation deletes it in the first. The
    /// first manager hears of it once; the second hears nothing, and its account keeps the message.
    func testConfirmationDeletionReachesOnlyTheManagerOfItsOwnAccount() throws {
        let otherFixture = try StateSyncFixture(name: "sync-other")
        self.addTeardownBlock {
            let _ = otherFixture.close()
        }
        let otherNetwork = Network.makeForTesting(engine: ScriptedServer(), basePath: otherFixture.basePath + "/network", encryptionProvider: UnusedEncryptionProvider())
        otherNetwork.shouldKeepConnection.set(.single(true))

        self.fixture.seedAccount(state: self.state(pts: 100))
        otherFixture.seedAccount(state: self.state(pts: 100))
        let user = self.seedUserChat(200)
        otherFixture.seedPeers([StateSyncFixture.makeUser(id: user, accessHash: 1, firstName: "U200")])
        otherFixture.seedChat(peerId: user)
        self.fixture.storeMessage(peerId: user, id: 11, timestamp: self.baseDate + 11, authorId: user, text: "deleted")
        otherFixture.storeMessage(peerId: user, id: 11, timestamp: self.baseDate + 11, authorId: user, text: "kept")

        self.makeStateManager()
        let otherManager = otherFixture.makeStateManager(network: otherNetwork)
        let deleted = self.observeDeletedMessages()
        let otherDeleted = otherFixture.observe(otherManager.deletedMessages)
        // The subscription lands on the other manager's queue; the round trip waits for it.
        let _ = otherFixture.wait(otherManager.isUpdating |> take(1))

        let deletedId = self.messageId(user, 11)
        let versions = self.fixture.transaction { transaction -> [MessageId: UInt32] in
            var result: [MessageId: UInt32] = [:]
            if let message = transaction.getMessage(deletedId) {
                result[deletedId] = message.stableVersion
            }
            return result
        } ?? [:]
        let mediaBox = self.fixture.postbox.mediaBox
        let confirmation = StoredMessageConfirmation(existing: [], peers: AccumulatedPeers(), missing: Set([deletedId]))
        self.fixture.transaction { transaction -> Void in
            let _ = applyStoredMessageConfirmation(transaction: transaction, accountPeerId: StateSyncFixture.accountPeerId, mediaBox: mediaBox, confirmation: confirmation, versions: versions)
        }

        XCTAssertNil(self.fixture.message(deletedId), "precondition: the confirmation deleted 11")
        XCTAssertEqual(self.deliveries(deleted), [[.global(11)]])
        XCTAssertEqual(self.stateManager.synchronouslyIsMessageDeletedRemotely(ids: [deletedId]), [deletedId])
        // Whatever the other manager was sent has reached it once its queue has run what was queued before this.
        let _ = otherFixture.wait(otherManager.isUpdating |> take(1))
        XCTAssertEqual(otherDeleted.values, [], "the other account's manager heard of a deletion in this account")
        XCTAssertEqual(otherManager.synchronouslyIsMessageDeletedRemotely(ids: [deletedId]), [])
        XCTAssertEqual(otherManager.synchronouslyIsMessageDeletedInteractively(ids: [deletedId]), [])
        XCTAssertEqual(otherFixture.message(deletedId)?.text, "kept")
    }
}

import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// The ghost tail of the account reset (spec section 3 point 3, as amended 2026-10-24): every stored Cloud message
/// above a fetched dialog's top message is deleted in the reset's transaction, without asking the server. The
/// server's `top_message` is the chat's newest message when the dialogs answer is built, so such a message was
/// deleted during the gap, or is newer than that answer. A newer one comes back: the reset moves pts to the one
/// differenceTooLong carried, which precedes the answer, so the follow-up getDifference delivers it again. Until the
/// fix such a message stayed outside every hole, visible at once and the chat-list preview.
final class ResetGhostTailTests: StateSyncTestCase {
    /// The reset's dialogs page: one chat with user `userId` whose top message is `topMessage`.
    private func userDialogs(_ userId: Int64, topMessage: Int32) -> Api.messages.Dialogs {
        return StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(userId), topMessage: topMessage)],
            messages: [StateSyncApi.privateMessage(id: topMessage, peerUserId: userId, fromUserId: userId, date: self.baseDate + topMessage, text: "top")],
            users: [StateSyncApi.user(id: userId, firstName: "U\(userId)")]
        )
    }

    /// The reset's dialogs page: broadcast channel `channelId` at `pts` whose top post is `topMessage`.
    private func channelDialogs(_ channelId: Int64, topMessage: Int32, pts: Int32) -> Api.messages.Dialogs {
        return StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(channelId), topMessage: topMessage, pts: pts)],
            messages: [StateSyncApi.channelPost(id: topMessage, channelId: channelId, date: self.baseDate + topMessage)],
            chats: [StateSyncApi.broadcastChannel(id: channelId, title: "C\(channelId)")]
        )
    }

    private func storedTopId(_ peerId: PeerId) -> MessageId? {
        return self.fixture.transaction { transaction -> MessageId? in
            return transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud)
        } ?? nil
    }

    /// The message id the chat's chat-list entry takes its index from, nil when the chat is not listed.
    private func chatListIndexMessageId(_ peerId: PeerId) -> MessageId? {
        return self.fixture.transaction { transaction -> MessageId? in
            return transaction.getPeerChatListIndex(peerId)?.1.messageIndex.id
        } ?? nil
    }

    /// A stored private message above the dialog's top is deleted in the reset's transaction, with no request of its
    /// own; the top message becomes the chat's newest again.
    func testResetDeletesAStoredMessageAboveTheTopWithoutAsking() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.fixture.storeMessage(peerId: user, id: 11, timestamp: self.baseDate + 11, authorId: user, text: "deleted during the gap")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.startAccountReset(dialogs: self.userDialogs(200, topMessage: 10))

        // The barrier sits behind the running poll and completes once the follow-up ended the cycle.
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 4, "log: \(names)")
        XCTAssertEqual(names.first, Name.getDifference)
        XCTAssertEqual(Set(names.dropFirst().prefix(2)), [Name.getDialogs, Name.getPinnedDialogs])
        XCTAssertEqual(names.last, Name.getDifference)
        XCTAssertNil(self.fixture.message(self.messageId(user, 11)))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 10)))
        XCTAssertEqual(self.storedTopId(user), self.messageId(user, 10))
        XCTAssertEqual(self.chatListIndexMessageId(user), self.messageId(user, 10))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 999)
    }

    /// A message above the top that is newer than the dialogs answer (here 12, the account's own reply, sent while the
    /// reset was in flight) is deleted too, and comes back with the follow-up getDifference: the reset moved pts to
    /// 999, which precedes the answer, so the difference from 999 carries the reply again and the replay stores it.
    func testResetDeletesAMessageNewerThanTheAnswerAndTheFollowUpDifferenceBringsItBack() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.fixture.storeMessage(peerId: user, id: 12, timestamp: self.baseDate + 12, authorId: StateSyncFixture.accountPeerId, text: "sent during the reset", incoming: false)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(self.userDialogs(200, topMessage: 10)))
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))))
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            newMessages: [StateSyncApi.privateMessage(id: 12, peerUserId: 200, fromUserId: 1000, date: self.baseDate + 12, text: "from the difference", outgoing: true)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            state: StateSyncApi.state(pts: 1000, qts: 5, date: self.baseDate + 120, seq: 10)
        )))
        self.fixture.resetStateManager()

        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertFalse(names.contains(Name.messagesGetMessages), "log: \(names)")
        XCTAssertEqual(names.filter { $0 == Name.getDifference }.count, 2, "log: \(names)")
        XCTAssertEqual(self.fixture.message(self.messageId(user, 12))?.text, "from the difference", "the follow-up difference did not bring the reply back")
        XCTAssertEqual(self.storedTopId(user), self.messageId(user, 12))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 1000)
    }

    /// A channel post above the top is deleted the same way, with no channels.getMessages.
    func testResetDeletesAChannelPostAboveTheTopWithoutAsking() {
        let channel = self.seedChannel(300, pts: 50, storedMessageId: 20)
        self.fixture.storeMessage(peerId: channel, id: 21, timestamp: self.baseDate + 21, authorId: nil, text: "deleted during the gap")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.startAccountReset(dialogs: self.channelDialogs(300, topMessage: 20, pts: 50))

        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 4, "log: \(names)")
        XCTAssertFalse(names.contains(Name.channelsGetMessages), "log: \(names)")
        XCTAssertNil(self.fixture.message(self.messageId(channel, 21)))
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 20)))
    }

    /// A dialog whose top_message is 0 (its history cleared on another device, the chat kept) has top 0: every
    /// stored Cloud message of the chat is above it and is deleted, and the chat-list entry no longer takes its index
    /// (the preview) from a cleared message. Until the fix such a dialog kept its whole stale history, its cleared
    /// last message as the preview.
    func testResetDeletesTheWholeStoredHistoryOfADialogWithoutATopMessage() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 5, timestamp: self.baseDate + 5, authorId: user, text: "cleared")
        self.fixture.storeMessage(peerId: user, id: 6, timestamp: self.baseDate + 6, authorId: user, text: "cleared")
        self.fixture.seedAccount(state: self.state(pts: 100))
        XCTAssertEqual(self.chatListIndexMessageId(user), self.messageId(user, 6), "precondition: the stored last message is the preview")
        self.startAccountReset(dialogs: StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(200), topMessage: 0)],
            messages: [],
            users: [StateSyncApi.user(id: 200, firstName: "U200")]
        ))

        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 4, "log: \(names)")
        XCTAssertFalse(names.contains(Name.messagesGetMessages), "log: \(names)")
        XCTAssertNil(self.fixture.message(self.messageId(user, 5)))
        XCTAssertNil(self.fixture.message(self.messageId(user, 6)))
        let indexId = self.chatListIndexMessageId(user)
        XCTAssertFalse(indexId == self.messageId(user, 5) || indexId == self.messageId(user, 6), "the chat-list entry takes its index from a cleared message: \(String(describing: indexId))")
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 999)
    }

    /// With nothing stored above any fetched top message, the normal case, the reset deletes nothing.
    func testResetWithNothingAboveTheTopDeletesNothing() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 9, timestamp: self.baseDate + 9, authorId: user, text: "older")
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.startAccountReset(dialogs: self.userDialogs(200, topMessage: 10))

        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 4, "log: \(names)")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 9)))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 10)))
    }

    /// The messages above the top are read from the id index a page at a time (`StoredMessageConfirmation.
    /// ghostTailPageLimit`, 1000 in the app) and a full page continues from its last id. With pages of 2, the five
    /// stored messages above the top take three pages, and all five are deleted.
    func testGhostTailReadContinuesPastAFullPage() {
        let originalPageLimit = StoredMessageConfirmation.ghostTailPageLimit
        self.addTeardownBlock {
            StoredMessageConfirmation.ghostTailPageLimit = originalPageLimit
        }
        StoredMessageConfirmation.ghostTailPageLimit = 2
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        for id in Int32(11) ... Int32(15) {
            self.fixture.storeMessage(peerId: user, id: id, timestamp: self.baseDate + id, authorId: user, text: "deleted")
        }
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.startAccountReset(dialogs: self.userDialogs(200, topMessage: 10))

        self.drainOperationQueue()

        for id in Int32(11) ... Int32(15) {
            XCTAssertNil(self.fixture.message(self.messageId(user, id)), "message \(id)")
        }
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 10)))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 999)
    }

    /// The Postbox read the ghost-tail search uses: the stored ids of one chat inside an id range, in id order
    /// (not timestamp order), from either end, with a limit.
    func testMessageIdsInRangeReadsTheIdIndex() {
        let user = self.seedUserChat(200)
        let other = self.seedUserChat(201)
        // Id 9 is the oldest message by date, as an imported one is.
        self.fixture.storeMessage(peerId: user, id: 9, timestamp: self.baseDate - 100, authorId: user, text: "imported")
        self.fixture.storeMessage(peerId: user, id: 3, timestamp: self.baseDate, authorId: user, text: "a")
        self.fixture.storeMessage(peerId: user, id: 5, timestamp: self.baseDate + 1, authorId: user, text: "b")
        self.fixture.storeMessage(peerId: other, id: 4, timestamp: self.baseDate + 2, authorId: other, text: "another chat")

        let read = self.fixture.transaction { transaction -> [[Int32]] in
            return [
                transaction.messageIdsInRange(peerId: user, namespace: Namespaces.Message.Cloud, range: 1 ... 100, limit: 0).map { $0.id },
                transaction.messageIdsInRange(peerId: user, namespace: Namespaces.Message.Cloud, range: 5 ... 9, limit: 0).map { $0.id },
                transaction.messageIdsInRange(peerId: user, namespace: Namespaces.Message.Cloud, range: 1 ... 100, limit: 2).map { $0.id },
                transaction.messageIdsInRange(peerId: user, namespace: Namespaces.Message.Cloud, range: 1 ... 100, limit: 2, fromUpperBound: true).map { $0.id },
                transaction.messageIdsInRange(peerId: user, namespace: Namespaces.Message.Cloud, range: 6 ... 8, limit: 0).map { $0.id },
                transaction.messageIdsInRange(peerId: user, namespace: Namespaces.Message.Local, range: 1 ... 100, limit: 0).map { $0.id }
            ]
        }
        XCTAssertEqual(read, [[3, 5, 9], [5, 9], [3, 5], [9, 5], [], []])
    }
}

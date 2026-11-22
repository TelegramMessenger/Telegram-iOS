import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Owner decision D2 for the account reset (`_internal_resetAccountState`, ResetState.swift) and the chat-list
/// hole fill (`fetchChatListHole`, Holes.swift): both store each dialog's top message (`.UpperHistoryBlock`) and
/// its reply targets after a network round trip, so a top message deleted while the page's requests were in flight
/// came back as the chat's preview. They now store no message on Postbox's record of recent deletions
/// (`Transaction.wasMessageDeletedRecently`), and answers that have grown older than that record keeps a deletion
/// (`FetchedAnswerAge`) write nothing and are fetched again, each restart in a row after a longer wait
/// (`FetchedAnswerAge.staleRestartDelay`).
final class ChatListRecentDeletionTests: StateSyncTestCase {
    /// The root list's first hole, at a `Namespaces.Peer.Empty` index, as the seed configuration and the reset add it.
    private let rootHole = ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1))

    /// A dialogs page: one chat with user `userId` whose top message is `topMessage`.
    private func userDialogs(_ userId: Int64, topMessage: Int32) -> Api.messages.Dialogs {
        return StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(userId), topMessage: topMessage)],
            messages: [StateSyncApi.privateMessage(id: topMessage, peerUserId: userId, fromUserId: userId, date: self.baseDate + topMessage, text: "top")],
            users: [StateSyncApi.user(id: userId, firstName: "U\(userId)")]
        )
    }

    private func pinnedDialogs(pts: Int32) -> Api.messages.PeerDialogs {
        return StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: pts, qts: 5, date: self.baseDate, seq: 10))
    }

    /// The message id the chat's chat-list entry takes its index from, nil when the chat is not listed.
    private func chatListIndexMessageId(_ peerId: PeerId) -> MessageId? {
        return self.fixture.transaction { transaction -> MessageId? in
            return transaction.getPeerChatListIndex(peerId)?.1.messageIndex.id
        } ?? nil
    }

    private func rootChatListHoles() -> [ChatListHole] {
        return self.fixture.transaction { transaction -> [ChatListHole] in
            return transaction.allChatListHoles(groupId: .root)
        } ?? []
    }

    /// Replaces `FetchedAnswerAge.staleRestartDelay` for this test: records each `n` it is asked for and answers
    /// `delay(n)`. Restored at teardown.
    private func recordStaleRestartDelays(_ delay: @escaping (Int) -> Double) -> Atomic<[Int]> {
        let calls = Atomic<[Int]>(value: [])
        let original = FetchedAnswerAge.staleRestartDelay
        self.addTeardownBlock {
            FetchedAnswerAge.staleRestartDelay = original
        }
        FetchedAnswerAge.staleRestartDelay = { n in
            let _ = calls.modify { $0 + [n] }
            return delay(n)
        }
        return calls
    }

    /// A fill of the root list's first hole; emits true once it completed.
    private func rootChatListHoleFill() -> Signal<Bool, NoError> {
        return fetchChatListHole(postbox: self.fixture.postbox, network: self.network, accountPeerId: StateSyncFixture.accountPeerId, groupId: .root, hole: self.rootHole)
        |> map { _ -> Bool in }
        |> then(Signal<Bool, NoError>.single(true))
    }

    /// The account reset. The chat's top message (10) is deleted while messages.getDialogs is held, and the page,
    /// produced before the deletion, still names it. The reset does not store it again: the chat keeps the hole
    /// the reset put over its whole history, and its chat-list entry takes its index from 9. The deletion is an
    /// interactive one (`deleteMessagesInteractively` deletes locally with `_internal_deleteMessages`, then
    /// queues the server's): a pushed update cannot land here, because it waits behind the poll cycle the reset
    /// runs in.
    func testResetDoesNotStoreATopMessageDeletedWhileTheDialogsWereInFlight() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 9, timestamp: self.baseDate + 9, authorId: user, text: "older")
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .result(self.pinnedDialogs(pts: 999)))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()

        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs), "the reset did not ask for the dialogs: \(self.server.requestNames)")
        let topId = self.messageId(user, 10)
        let mediaBox = self.fixture.postbox.mediaBox
        self.fixture.transaction { transaction -> Void in
            _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: [topId])
        }
        XCTAssertTrue(self.server.release(Name.getDialogs, with: .result(self.userDialogs(200, topMessage: 10))))
        // The barrier sits behind the running poll and completes once the follow-up ended the cycle.
        self.drainOperationQueue()

        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 999, "the reset did not complete")
        XCTAssertNil(self.fixture.message(topId), "the reset stored again a top message deleted while the dialogs were in flight")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 9)))
        XCTAssertTrue(self.fixture.holes(peerId: user).contains(10), "the chat's history lost its hole above the top message that was not stored")
        XCTAssertEqual(self.chatListIndexMessageId(user), self.messageId(user, 9))
    }

    /// The chat-list hole fill, which runs outside the poll cycle. A pushed `updateDeleteMessages` deletes the
    /// chat's top message (10) while messages.getDialogs is held; the page, produced before the deletion, still
    /// names it. The fill does not store it again, and the chat's chat-list entry takes its index from 9.
    func testChatListFillDoesNotStoreATopMessageAPushDeletedWhileThePageWasInFlight() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 9, timestamp: self.baseDate + 9, authorId: user, text: "older")
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.launchIdle()
        self.server.on(Name.getDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .result(self.pinnedDialogs(pts: 100)))

        let finished = self.fixture.observe(self.rootChatListHoleFill())

        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs), "the fill did not ask for the page: \(self.server.requestNames)")
        self.server.push(StateSyncApi.updates([
            .updateDeleteMessages(.init(messages: [10], pts: 101, ptsCount: 1))
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 101, "precondition: the push was applied")
        XCTAssertNil(self.fixture.message(self.messageId(user, 10)), "precondition: the push deleted 10")
        XCTAssertTrue(self.server.release(Name.getDialogs, with: .result(self.userDialogs(200, topMessage: 10))))
        finished.wait { $0.contains(true) }

        XCTAssertNil(self.fixture.message(self.messageId(user, 10)), "the chat-list fill stored again a top message a push deleted while the page was in flight")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 9)))
        XCTAssertEqual(self.chatListIndexMessageId(user), self.messageId(user, 9))
        XCTAssertFalse(self.rootChatListHoles().contains(self.rootHole), "the fill did not complete")
    }

    /// The reset's answers wait for messages.getPinnedDialogs, held past `FetchedAnswerAge.maximum` (0.2 s here), so
    /// they are older than the record of recent deletions keeps one: the reset writes nothing (pts stays, and 11,
    /// stored above the top message 10, is still there) and fetches the chat list again, after the first restart's
    /// delay. The second answers, young enough, are written: pts moves to 999 and 11 is deleted.
    func testResetWhoseAnswersOutlivedTheRecordFetchesTheChatListAgain() {
        let defaultMaximum = FetchedAnswerAge.maximum
        self.addTeardownBlock {
            FetchedAnswerAge.maximum = defaultMaximum
        }
        let askedDelays = self.recordStaleRestartDelays { _ in 0.0 }
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.fixture.storeMessage(peerId: user, id: 11, timestamp: self.baseDate + 11, authorId: user, text: "deleted during the gap")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(self.userDialogs(200, topMessage: 10)))
        self.server.on(Name.getDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .result(self.pinnedDialogs(pts: 999)))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        FetchedAnswerAge.maximum = 0.2
        self.fixture.resetStateManager()

        XCTAssertTrue(self.server.waitForRequest(Name.getPinnedDialogs), "the reset did not ask for the pinned chats: \(self.server.requestNames)")
        // The pinned chats outlast the (shortened) bound.
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(self.server.release(Name.getPinnedDialogs, with: .result(self.pinnedDialogs(pts: 999))))
        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs, count: 2), "the reset did not fetch the chat list again: \(self.server.requestNames)")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 11)), "the stale attempt deleted the ghost tail")
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 100, "the reset wrote answers older than the record of recent deletions")
        FetchedAnswerAge.maximum = defaultMaximum
        XCTAssertTrue(self.server.release(Name.getDialogs, with: .result(self.userDialogs(200, topMessage: 10))))
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.filter { $0 == Name.getDialogs }.count, 2, "log: \(names)")
        XCTAssertFalse(names.contains(Name.messagesGetMessages), "log: \(names)")
        XCTAssertNil(self.fixture.message(self.messageId(user, 11)))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 10)))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 999)
        XCTAssertEqual(askedDelays.with { $0 }, [1], "the restart did not wait the first restart's delay")
    }

    /// The chat-list fill's answers wait for messages.getPinnedDialogs, held past `FetchedAnswerAge.maximum` (0.2 s
    /// here): the fill writes nothing, its hole stays, and it fetches the page again after the first restart's delay;
    /// the second answers are written and close the hole.
    func testChatListFillWhoseAnswersOutlivedTheRecordFetchesThePageAgain() {
        let defaultMaximum = FetchedAnswerAge.maximum
        self.addTeardownBlock {
            FetchedAnswerAge.maximum = defaultMaximum
        }
        let askedDelays = self.recordStaleRestartDelays { _ in 0.0 }
        self.fixture.seedAccount(state: self.state(pts: 100))
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.server.on(Name.getDialogs, .result(self.userDialogs(200, topMessage: 10)))
        self.server.on(Name.getDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .result(self.pinnedDialogs(pts: 100)))
        FetchedAnswerAge.maximum = 0.2

        let finished = self.fixture.observe(self.rootChatListHoleFill())

        XCTAssertTrue(self.server.waitForRequest(Name.getPinnedDialogs), "the fill did not ask for the pinned chats: \(self.server.requestNames)")
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(self.server.release(Name.getPinnedDialogs, with: .result(self.pinnedDialogs(pts: 100))))
        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs, count: 2), "the fill did not fetch the page again: \(self.server.requestNames)")
        XCTAssertTrue(self.rootChatListHoles().contains(self.rootHole), "the fill closed its hole with answers older than the record of recent deletions")
        FetchedAnswerAge.maximum = defaultMaximum
        XCTAssertTrue(self.server.release(Name.getDialogs, with: .result(self.userDialogs(200, topMessage: 10))))
        finished.wait { $0.contains(true) }

        let names = self.server.requestNames
        XCTAssertEqual(names.filter { $0 == Name.getDialogs }.count, 2, "log: \(names)")
        XCTAssertFalse(names.contains(Name.messagesGetMessages), "log: \(names)")
        XCTAssertFalse(self.rootChatListHoles().contains(self.rootHole))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 10)))
        XCTAssertEqual(askedDelays.with { $0 }, [1], "the restart did not wait the first restart's delay")
    }

    /// A reset that stays slower than `FetchedAnswerAge.maximum` (0.2 s here): the first attempt's pinned chats and
    /// the second attempt's chat list are each held past it. Neither stale attempt writes anything (11, stored above
    /// the top message 10, stays until the third attempt deletes it); the third attempt writes. Each restart in a row
    /// waits its own delay first (`FetchedAnswerAge.staleRestartDelay`, 0.25 s times `n` here). Before, a stale
    /// attempt restarted at once, so a reset that stayed slower than the bound asked again back to back.
    func testResetThatStaysSlowerThanTheRecordBacksOffBeforeEachRestart() {
        let defaultMaximum = FetchedAnswerAge.maximum
        self.addTeardownBlock {
            FetchedAnswerAge.maximum = defaultMaximum
        }
        // The production curve: 1 s, doubling up to 60 s.
        XCTAssertEqual([1, 2, 3, 4, 5, 6, 7, 8, 1000].map(FetchedAnswerAge.staleRestartDelay), [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 60.0, 60.0, 60.0])
        let askedDelays = self.recordStaleRestartDelays { n in 0.25 * Double(n) }
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 10, authorId: user, text: "top")
        self.fixture.storeMessage(peerId: user, id: 11, timestamp: self.baseDate + 11, authorId: user, text: "deleted during the gap")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        let page = self.userDialogs(200, topMessage: 10)
        // When each messages.getDialogs arrived (`FetchedAnswerAge.now()`).
        let getDialogsTimes = Atomic<[Double]>(value: [])
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        // The first page is answered at once, the second is held past the bound, the third while the bound is restored.
        self.server.on(Name.getDialogs, { _ in
            let _ = getDialogsTimes.modify { $0 + [FetchedAnswerAge.now()] }
            return .result(page)
        })
        self.server.on(Name.getDialogs, { _ in
            let _ = getDialogsTimes.modify { $0 + [FetchedAnswerAge.now()] }
            return .hold
        })
        self.server.on(Name.getDialogs, { _ in
            let _ = getDialogsTimes.modify { $0 + [FetchedAnswerAge.now()] }
            return .hold
        })
        // The first attempt's pinned chats are held past the bound; the others are answered at once.
        self.server.on(Name.getPinnedDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .result(self.pinnedDialogs(pts: 999)))
        self.server.on(Name.getPinnedDialogs, .result(self.pinnedDialogs(pts: 999)))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        FetchedAnswerAge.maximum = 0.2
        self.fixture.resetStateManager()

        // The first attempt: its pinned chats outlast the bound.
        XCTAssertTrue(self.server.waitForRequest(Name.getPinnedDialogs), "the reset did not ask for the pinned chats: \(self.server.requestNames)")
        Thread.sleep(forTimeInterval: 0.4)
        let firstReleasedAt = FetchedAnswerAge.now()
        XCTAssertTrue(self.server.release(Name.getPinnedDialogs, with: .result(self.pinnedDialogs(pts: 999))))
        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs, count: 2), "the reset did not fetch the chat list again: \(self.server.requestNames)")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 11)), "the first attempt deleted the ghost tail")
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 100, "the first attempt wrote answers older than the record of recent deletions")

        // The second attempt: its chat list outlasts the bound.
        Thread.sleep(forTimeInterval: 0.4)
        let secondReleasedAt = FetchedAnswerAge.now()
        XCTAssertTrue(self.server.release(Name.getDialogs, with: .result(page)))
        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs, count: 3), "the reset did not fetch the chat list a third time: \(self.server.requestNames)")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 11)), "the second attempt deleted the ghost tail")
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 100, "the second attempt wrote answers older than the record of recent deletions")

        // The third attempt is written.
        FetchedAnswerAge.maximum = defaultMaximum
        XCTAssertTrue(self.server.release(Name.getDialogs, with: .result(page)))
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.filter { $0 == Name.getDialogs }.count, 3, "log: \(names)")
        XCTAssertFalse(names.contains(Name.messagesGetMessages), "log: \(names)")
        XCTAssertNil(self.fixture.message(self.messageId(user, 11)))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 10)))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 999, "the reset did not complete")
        XCTAssertEqual(askedDelays.with { $0 }, [1, 2], "each restart in a row asks for its own delay")
        let times = getDialogsTimes.with { $0 }
        XCTAssertEqual(times.count, 3)
        if times.count == 3 {
            XCTAssertGreaterThanOrEqual(times[1] - firstReleasedAt, 0.25, "the first restart did not wait its delay")
            XCTAssertGreaterThanOrEqual(times[2] - secondReleasedAt, 0.5, "the second restart did not wait its delay")
        }
    }
}

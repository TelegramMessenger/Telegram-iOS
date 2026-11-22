import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getMessages = "messages.getMessages"

/// The edit counterpart of owner decision D2 (HistoryFillRecentDeletionTests, ChatListRecentDeletionTests; owner
/// decision 2026-10-25), found by the truth server (seeds 887, 1285, 1443, 1540, 2178, 2819, 3160, 4875 and 4967 of
/// `TruthSessionTests.testRandomSessionsLong`; seven of them end the same way on master): a message is edited while a
/// fetch that brings it is in flight. The replay applies the edit to the stored message, or has none to apply it to,
/// and the answer, produced before the edit, holds the old content. Postbox records every edit the replay receives
/// (`Transaction.recordMessageEdit`), and a fetch whose request went out before it stores the edit in its answer's
/// place (`fetchedMessagesWithRecentEdits`). The edits are pushed and replayed by a running state manager,
/// except the reset's (its test says why). Helpers are in HistoryFillReconciliationTests.swift.
final class RecentEditTests: StateSyncTestCase {
    /// The root list's first hole, at a `Namespaces.Peer.Empty` index, as the seed configuration and the reset add it.
    private let rootHole = ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1))

    /// Pushes `updateEditMessage` for `message` (in the chat with `userId`) at `pts` and waits until it was replayed.
    private func pushEdit(_ message: Api.Message, userId: Int64 = 500, pts: Int32, file: StaticString = #filePath, line: UInt = #line) {
        self.server.push(StateSyncApi.updates([
            .updateEditMessage(.init(message: message, pts: pts, ptsCount: 1))
        ], users: [StateSyncApi.user(id: userId, firstName: "U\(userId)")], date: self.baseDate + 20, seq: 0))
        self.drainOperationQueue(file: file, line: line)
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, pts, "precondition: the edit was replayed", file: file, line: line)
    }

    // MARK: - History fills

    /// 12 was never stored here. `updateEditMessage` gives it new text while getHistory is in flight; the answer
    /// still holds the old text. The fill stores the edit, and the rest of its answer as before.
    func testAnswerMessageEditedWhileTheRequestWasInFlightKeepsTheEdit() {
        let peerId = self.seedUserChat(500)
        self.launchIdle()
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getHistory), "no fill was sent: \(self.server.requestNames)")
        self.pushEdit(StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "edited"), pts: 101)
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 12)), "precondition: the edit had no stored message to apply to")
        XCTAssertTrue(self.server.release(getHistory, with: .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "original"),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "original")
        ]))))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 12))?.text, "edited", "the fill's older answer undid an edit made while it was in flight")
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 10))?.text, "original")
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }

    /// A channel's fill too: post 12, never stored, is edited by `updateEditChannelMessage` while getHistory is in
    /// flight.
    func testChannelPostEditedWhileTheRequestWasInFlightKeepsTheEdit() {
        let channelId = self.seedChannel(310, pts: 20, storedMessageId: nil)
        self.launchIdle()
        self.addHistoryFillHole(channelId)
        self.server.on(getHistory, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: channelId, threadId: nil), direction: self.downwardFillDirection(channelId)))

        XCTAssertTrue(self.server.waitForRequest(getHistory), "no fill was sent: \(self.server.requestNames)")
        self.server.push(StateSyncApi.updates([
            .updateEditChannelMessage(.init(message: StateSyncApi.channelPost(id: 12, channelId: 310, date: self.baseDate + 12, text: "edited"), pts: 21, ptsCount: 1))
        ], chats: [StateSyncApi.broadcastChannel(id: 310)], date: self.baseDate + 20, seq: 0))
        self.drainOperationQueue()
        XCTAssertEqual(self.fixture.channelState(channelId)?.pts, 21, "precondition: the edit was replayed")
        XCTAssertTrue(self.server.release(getHistory, with: .result(StateSyncApi.channelMessages(pts: 20, [
            StateSyncApi.channelPost(id: 12, channelId: 310, date: self.baseDate + 12, text: "original"),
            StateSyncApi.channelPost(id: 10, channelId: 310, date: self.baseDate + 10, text: "original")
        ]))))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.fixture.message(self.messageId(channelId, 12))?.text, "edited", "the fill's older answer undid an edit made while it was in flight")
        XCTAssertEqual(self.fixture.message(self.messageId(channelId, 10))?.text, "original")
    }

    /// An edit replayed before the fill's request went out is in the answer, which can be newer still (a second edit
    /// whose update has not arrived yet): the fill stores its answer.
    func testAnEditReplayedBeforeTheRequestWentOutLeavesTheAnswer() {
        let peerId = self.seedUserChat(500)
        self.launchIdle()
        self.addHistoryFillHole(peerId)
        self.pushEdit(StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "edited"), pts: 101)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "edited twice"),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "original")
        ])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 12))?.text, "edited twice", "the fill replaced a newer answer with an edit it already had")
    }

    /// The fill is timed from the attempt that was answered: every retry of a transient error resets its `since`. 12 is
    /// edited while the first getHistory is out, and that attempt fails; the retry goes out after the edit, so its
    /// answer holds it, here with a second edit whose update has not arrived. The fill stores that answer. Timed from
    /// the first attempt, it would store the older edit over it.
    func testAnEditReplayedBeforeARetryWentOutLeavesTheRetrysAnswer() {
        let peerId = self.seedUserChat(500)
        self.launchIdle()
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .hold)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "edited twice"),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "original")
        ])))

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getHistory), "no fill was sent: \(self.server.requestNames)")
        self.pushEdit(StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "edited"), pts: 101)
        XCTAssertTrue(self.server.release(getHistory, with: .error(code: 500, text: "INTERNAL_SERVER_ERROR")))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.server.requestNames.filter { $0 == getHistory }.count, 2, "the fill did not retry: \(self.server.requestNames)")
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 12))?.text, "edited twice", "the retried fill replaced its answer with an edit made before the retry went out")
    }

    /// The fill's follow-up too: 10 replies to 5, which is not stored, so the follow-up asks for 5
    /// (messages.getMessages). 5 is edited while that request is in flight; its answer still holds the old text. The
    /// answer's user is written in the same transaction, so waiting for the user is waiting for the follow-up.
    func testReplyTargetEditedWhileTheFollowUpWasInFlightKeepsTheEdit() {
        let peerId = self.seedUserChat(500)
        self.launchIdle()
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, replyToMessageId: 5)
        ])))
        self.server.on(getMessages, .hold)

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertTrue(self.server.waitForRequest(getMessages), "the follow-up did not ask for the reply target: \(self.server.requestNames)")
        self.pushEdit(StateSyncApi.privateMessage(id: 5, peerUserId: 500, fromUserId: 500, date: self.baseDate + 5, text: "edited"), pts: 101)
        XCTAssertTrue(self.server.release(getMessages, with: .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 5, peerUserId: 500, fromUserId: 500, date: self.baseDate + 5, text: "original")
        ], users: [StateSyncApi.user(id: 500, firstName: "From the follow-up")]))))
        self.fixture.eventually {
            return (self.fixture.peer(peerId) as? TelegramUser)?.firstName == "From the follow-up"
        }

        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 5))?.text, "edited", "the follow-up's older answer undid an edit made while it was in flight")
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 10)))
    }

    /// A stored message too: 12 is stored (as a reset leaves a chat's stored messages under the hole it puts over the
    /// history; truth seed 4967). The replay edits it in place while getHistory is in flight, and the answer, produced
    /// before the edit, would write the old text over it: a fill that confirms nothing stores its whole answer, as
    /// master's does. The record holds this edit as well, and the fill stores it.
    func testStoredMessageEditedWhileTheRequestWasInFlightKeepsTheEdit() {
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [12])
        self.launchIdle()
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getHistory), "no fill was sent: \(self.server.requestNames)")
        self.pushEdit(StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "edited"), pts: 101)
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 12))?.text, "edited", "precondition: the replay edited the stored message")
        XCTAssertTrue(self.server.release(getHistory, with: .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "original"),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "original")
        ]))))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 12))?.text, "edited", "the fill's older answer undid an edit of a stored message made while it was in flight")
    }

    // MARK: - The chat-list hole fill

    /// It runs outside the poll cycle, so a push lands while its page is in flight: the chat's top message 10, never
    /// stored, is edited while messages.getDialogs is held, and the page, produced before the edit, names it with its
    /// old text. The fill stores the edit as the chat's top message.
    func testChatListFillStoresATopMessageEditedWhileThePageWasInFlight() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 9, timestamp: self.baseDate + 9, authorId: user, text: "older")
        self.launchIdle()
        self.server.on(Name.getDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate, seq: 10))))

        let finished = self.fixture.observe(fetchChatListHole(postbox: self.fixture.postbox, network: self.network, accountPeerId: StateSyncFixture.accountPeerId, groupId: .root, hole: self.rootHole)
        |> map { _ -> Bool in }
        |> then(Signal<Bool, NoError>.single(true)))

        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs), "the fill did not ask for the page: \(self.server.requestNames)")
        self.pushEdit(StateSyncApi.privateMessage(id: 10, peerUserId: 200, fromUserId: 200, date: self.baseDate + 10, text: "edited"), userId: 200, pts: 101)
        XCTAssertNil(self.fixture.message(self.messageId(user, 10)), "precondition: the edit had no stored message to apply to")
        XCTAssertTrue(self.server.release(Name.getDialogs, with: .result(StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(200), topMessage: 10)],
            messages: [StateSyncApi.privateMessage(id: 10, peerUserId: 200, fromUserId: 200, date: self.baseDate + 10, text: "original")],
            users: [StateSyncApi.user(id: 200, firstName: "U200")]
        ))))
        finished.wait { $0.contains(true) }

        XCTAssertEqual(self.fixture.message(self.messageId(user, 10))?.text, "edited", "the chat-list fill's older page undid an edit made while it was in flight")
    }

    // MARK: - The account reset

    /// The reset runs inside a poll cycle, so a pushed edit waits for it to end; an edit replayed beside the operation
    /// queue (a channel reset's) is recorded as the replay records every edit, here directly. The chat's top message 10, never stored, is edited while messages.getDialogs is held, and the page,
    /// produced before the edit, names it with its old text. The reset stores the edit as the chat's top message.
    func testResetStoresATopMessageEditedWhileTheDialogsWereInFlight() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 9, timestamp: self.baseDate + 9, authorId: user, text: "older")
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()

        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs), "the reset did not ask for the dialogs: \(self.server.requestNames)")
        guard let edit = StoreMessage(apiMessage: StateSyncApi.privateMessage(id: 10, peerUserId: 200, fromUserId: 200, date: self.baseDate + 10, text: "edited"), accountPeerId: StateSyncFixture.accountPeerId, peerIsForum: false) else {
            XCTFail("the edit did not parse")
            return
        }
        self.fixture.transaction { transaction -> Void in
            transaction.recordMessageEdit(edit)
        }
        XCTAssertTrue(self.server.release(Name.getDialogs, with: .result(StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(200), topMessage: 10)],
            messages: [StateSyncApi.privateMessage(id: 10, peerUserId: 200, fromUserId: 200, date: self.baseDate + 10, text: "original")],
            users: [StateSyncApi.user(id: 200, firstName: "U200")]
        ))))
        // The barrier sits behind the running poll and completes once the follow-up ended the cycle.
        self.drainOperationQueue()

        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 999, "the reset did not complete")
        XCTAssertEqual(self.fixture.message(self.messageId(user, 10))?.text, "edited", "the reset's older page undid an edit made while it was in flight")
    }
}

import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getMessages = "messages.getMessages"

/// No history fill stores a message deleted in the last few minutes (owner decision D2, 2026-10-15). A fill's
/// request, its confirmation and its follow-up are answered from server state that can predate a deletion
/// that lands while they are in flight. Postbox records what was deleted, messages it never stored included
/// (`Transaction.wasMessageDeletedRecently`), and the fill's store transaction skips the answer messages on
/// that record, with or without a confirmation. The deletions are made as the update replay makes them:
/// `deleteMessagesWithGlobalIds` for `updateDeleteMessages` (private chats and basic groups, by global id,
/// stored or not; StateReplay `.DeleteMessagesWithGlobalIds`), `_internal_deleteMessages` for
/// `updateDeleteChannelMessages`. The fills are driven directly, as ManagedMessageHistoryHoles starts them;
/// no state manager runs. The record keeps a deletion for 5 minutes, so an answer that has grown older than
/// that by the time it would be stored is not stored at all (`FetchedAnswerAge`).
final class HistoryFillRecentDeletionTests: StateSyncTestCase {
    /// As StateReplay applies `updateDeleteMessages` (`.DeleteMessagesWithGlobalIds`).
    private func deleteWithGlobalIds(_ ids: [Int32]) {
        self.fixture.transaction { transaction -> Void in
            transaction.deleteMessagesWithGlobalIds(ids, forEachMedia: nil)
        }
    }

    /// The race every fill had, without a confirmation: 12 was never stored here. An update deletes it while
    /// getHistory is in flight, and the answer, produced before the deletion, still holds it. The fill stores
    /// the rest of its answer and closes its hole as before; 12 stays deleted.
    func testAnswerMessageDeletedWhileTheRequestWasInFlightIsNotStored() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getHistory), "no fill was sent: \(self.server.requestNames)")
        self.deleteWithGlobalIds([12])
        XCTAssertTrue(self.server.release(getHistory, with: .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ]))))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.server.requestNames, [getHistory])
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 12)), "the fill's older answer brought back a message deleted while it was in flight")
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 10)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }

    /// The held-answer race of a fill with candidates, left open by the differenceTooLong work: 12, in the
    /// answer, was never stored here, so the versions read with the candidates cannot see it. An update
    /// deletes it while the confirmation of candidate 11 is in flight; when the confirmation answers, the fill
    /// stores its answer without 12. 11 is confirmed and deleted, 10 stored, and the hole closes as planned.
    func testNeverStoredAnswerMessageDeletedDuringTheConfirmationIsNotStored() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11])
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ])))
        self.server.on(getMessages, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getMessages), "no confirmation was sent: \(self.server.requestNames)")
        XCTAssertEqual(self.server.requests.last?.payload, HistoryFillApi.getMessagesPayload(ids: [11]))
        self.deleteWithGlobalIds([12])
        XCTAssertTrue(self.server.release(getMessages, with: .result(StateSyncApi.messages([]))))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 12)), "the fill stored a message of its answer that was deleted during the confirmation")
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 10)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 11)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }

    /// Every fill skips them, a channel's too: post 12, never stored, is deleted by id (as
    /// `updateDeleteChannelMessages` deletes it) while getHistory is in flight.
    func testChannelPostDeletedWhileTheRequestWasInFlightIsNotStored() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let channelId = self.seedChannel(310, pts: 20, storedMessageId: nil)
        self.addHistoryFillHole(channelId)
        self.server.on(getHistory, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: channelId, threadId: nil), direction: self.downwardFillDirection(channelId)))

        XCTAssertTrue(self.server.waitForRequest(getHistory), "no fill was sent: \(self.server.requestNames)")
        let deletedId = self.messageId(channelId, 12)
        let mediaBox = self.fixture.postbox.mediaBox
        self.fixture.transaction { transaction -> Void in
            _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: [deletedId])
        }
        XCTAssertTrue(self.server.release(getHistory, with: .result(StateSyncApi.channelMessages(pts: 20, [
            StateSyncApi.channelPost(id: 12, channelId: 310, date: self.baseDate + 12),
            StateSyncApi.channelPost(id: 10, channelId: 310, date: self.baseDate + 10)
        ]))))
        results.wait { !$0.isEmpty }

        XCTAssertNil(self.fixture.message(deletedId), "the fill's older answer brought back a post deleted while it was in flight")
        XCTAssertNotNil(self.fixture.message(self.messageId(channelId, 10)))
        XCTAssertEqual(self.fixture.holes(peerId: channelId), IndexSet(integersIn: 1 ... 9))
    }

    /// The fill's follow-up too: 10 replies to 5, which is not stored, so the follow-up asks for 5
    /// (messages.getMessages, `inputMessageReplyTo`). An update deletes 5 while that request is in flight; its
    /// answer still holds 5, which is not stored. The answer's user is written in the same transaction, so
    /// waiting for the user is waiting for the follow-up.
    func testReplyTargetDeletedWhileTheFollowUpWasInFlightIsNotStored() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, replyToMessageId: 5)
        ])))
        self.server.on(getMessages, .hold)

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertTrue(self.server.waitForRequest(getMessages), "the follow-up did not ask for the reply target: \(self.server.requestNames)")
        XCTAssertEqual(self.server.requests.last?.payload, Api.functions.messages.getMessages(id: [Api.InputMessage.inputMessageReplyTo(.init(id: 10))]).1.makeData())
        self.deleteWithGlobalIds([5])
        XCTAssertTrue(self.server.release(getMessages, with: .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 5, peerUserId: 500, fromUserId: 500, date: self.baseDate + 5)
        ], users: [StateSyncApi.user(id: 500, firstName: "From the follow-up")]))))
        self.fixture.eventually {
            return (self.fixture.peer(peerId) as? TelegramUser)?.firstName == "From the follow-up"
        }

        XCTAssertNil(self.fixture.message(self.messageId(peerId, 5)), "the follow-up stored a reply target deleted while it was fetched")
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 10)))
    }

    /// The plain path's follow-up times itself from its start: when its answers would be stored past
    /// `FetchedAnswerAge.maximum`, it stores none of them and starts again (`startReferencedDataFollowUp`). 10
    /// replies to 5, which is not stored, so the follow-up asks for 5; that request outlasts the bound, which is
    /// shortened to 0.2 s only once it is in flight (the fill's own store is not at stake). The stale answer is not
    /// stored, nor is its user, and the follow-up asks for 5 again; answered in time, 5 and its user are stored.
    func testFollowUpOlderThanTheRecordStoresNothingAndFetchesAgain() {
        let defaultMaximum = FetchedAnswerAge.maximum
        self.addTeardownBlock {
            FetchedAnswerAge.maximum = defaultMaximum
        }
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, replyToMessageId: 5)
        ])))
        self.server.on(getMessages, .hold)
        self.server.on(getMessages, .hold)

        XCTAssertNotNil(self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)), "precondition: the fill stored its answer")

        let replyTargetPayload = Api.functions.messages.getMessages(id: [Api.InputMessage.inputMessageReplyTo(.init(id: 10))]).1.makeData()
        XCTAssertTrue(self.server.waitForRequest(getMessages), "the follow-up did not ask for the reply target: \(self.server.requestNames)")
        XCTAssertEqual(self.server.requests.last?.payload, replyTargetPayload)
        FetchedAnswerAge.maximum = 0.2
        // The follow-up outlasts the (shortened) bound.
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(self.server.release(getMessages, with: .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 5, peerUserId: 500, fromUserId: 500, date: self.baseDate + 5, text: "stale")
        ], users: [StateSyncApi.user(id: 500, firstName: "From the stale follow-up")]))))

        // Sent after the stale answer's transaction stored nothing.
        XCTAssertTrue(self.server.waitForRequest(getMessages, count: 2), "the follow-up did not start again after a stale answer: \(self.server.requestNames)")
        XCTAssertEqual(self.server.requests.last?.payload, replyTargetPayload)
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 5)), "the follow-up stored an answer older than the record of recent deletions")
        XCTAssertEqual((self.fixture.peer(peerId) as? TelegramUser)?.firstName, "U500", "the follow-up stored a peer of an answer older than the record of recent deletions")

        FetchedAnswerAge.maximum = defaultMaximum
        XCTAssertTrue(self.server.release(getMessages, with: .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 5, peerUserId: 500, fromUserId: 500, date: self.baseDate + 5, text: "fresh")
        ], users: [StateSyncApi.user(id: 500, firstName: "From the fresh follow-up")]))))
        self.fixture.eventually {
            return (self.fixture.peer(peerId) as? TelegramUser)?.firstName == "From the fresh follow-up"
        }

        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 5))?.text, "fresh")
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 10)))
        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages, getMessages])
    }

    /// The record keeps a deletion for 5 minutes, and a fill's answer waits for its confirmation, which retries
    /// until it succeeds, for as long as that takes. An answer older than `FetchedAnswerAge.maximum` (the record's
    /// lifetime less a margin; 0.2 s here) when it would be stored may predate a deletion the record has already
    /// forgotten: the fill stores none of its answer, closes nothing and reports nothing. Its confirmation is applied
    /// all the same, as the account reset and the chat-list fill apply theirs on a stale attempt: it touches only
    /// messages still at the version they were read at, so it is safe at any age, and 11, which the server no
    /// longer has, is deleted. Its caller asks again (ManagedMessageHistoryHoles once its 20 s pause is over); asked
    /// again here, the fill has nothing left to confirm and stores its fresh answer.
    func testAnswerOlderThanTheRecordWhenStoredIsNotStoredAndTheFillIsAskedAgain() {
        let defaultMaximum = FetchedAnswerAge.maximum
        self.addTeardownBlock {
            FetchedAnswerAge.maximum = defaultMaximum
        }
        FetchedAnswerAge.maximum = 0.2
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11])
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "first answer"),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "first answer")
        ])))
        self.server.on(getMessages, .hold)

        let first = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getMessages), "no confirmation was sent: \(self.server.requestNames)")
        // The confirmation outlasts the (shortened) bound.
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(self.server.release(getMessages, with: .result(StateSyncApi.messages([]))))
        first.wait { !$0.isEmpty }

        XCTAssertEqual(first.values.count, 1)
        XCTAssertNil(first.values.first ?? nil, "the fill reported a result for an answer it must not store")
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 12)), "the fill stored an answer older than the record of recent deletions")
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 10))?.text, "stored", "the fill stored an answer older than the record of recent deletions")
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 11)), "the stale fill threw away its confirmation: 11, which the server no longer has, is still stored")
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... Int(Int32.max - 1)), "the fill closed its hole")

        // Asked again, as the hole manager asks: answers young enough to store. The stale attempt's confirmation
        // settled 11, so nothing is left to confirm.
        FetchedAnswerAge.maximum = defaultMaximum
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "second answer"),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "second answer")
        ])))
        let second = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertNotNil(second)
        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages, getHistory], "the fill asked again confirmed what the stale attempt's confirmation had settled")
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 12))?.text, "second answer")
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 10))?.text, "second answer")
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 11)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }
}

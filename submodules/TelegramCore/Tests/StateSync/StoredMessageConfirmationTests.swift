import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Api values only these tests need.
private enum ConfirmationApi {
    /// `messageEmpty#90a6ca84`: `peer_id` flags.0, set only when a peer is given.
    static func messageEmpty(id: Int32, peer: Api.Peer?) -> Api.Message {
        return .messageEmpty(.init(flags: peer != nil ? (1 << 0) : 0, id: id, peerId: peer))
    }

    /// The bytes of `messages.getMessages` for these ids, in this order.
    static func getMessagesPayload(_ ids: [Int32]) -> Data {
        return Api.functions.messages.getMessages(id: ids.map { Api.InputMessage.inputMessageID(.init(id: $0)) }).1.makeData()
    }
}

/// `confirmStoredMessages` and `applyStoredMessageConfirmation` (StoredMessageConfirmation.swift): how the
/// history fill of a private chat or basic group tells a stored message its answer left out that the server
/// deleted from one it still has. Driven directly: no state manager.
final class StoredMessageConfirmationTests: StateSyncTestCase {
    private func confirm(_ ids: [MessageId], knownPeers: AccumulatedPeers = AccumulatedPeers(), file: StaticString = #filePath, line: UInt = #line) -> StoredMessageConfirmation? {
        return self.fixture.wait(confirmStoredMessages(accountPeerId: StateSyncFixture.accountPeerId, postbox: self.fixture.postbox, source: .network(self.network), ids: ids, knownPeers: knownPeers), file: file, line: line)
    }

    /// The ids of `confirmation.existing`, ascending.
    private func existingIds(_ confirmation: StoredMessageConfirmation?) -> [MessageId] {
        return (confirmation?.existing ?? []).compactMap { message -> MessageId? in
            if case let .Id(id) = message.id {
                return id
            } else {
                return nil
            }
        }.sorted()
    }

    /// The payload of request `index`, or nil when there is no such request.
    private func payload(at index: Int) -> Data? {
        let requests = self.server.requests
        return index < requests.count ? requests[index].payload : nil
    }

    private func storedVersions(_ ids: [MessageId]) -> [MessageId: UInt32] {
        return self.fixture.transaction { transaction -> [MessageId: UInt32] in
            var result: [MessageId: UInt32] = [:]
            for id in ids {
                if let message = transaction.getMessage(id) {
                    result[id] = message.stableVersion
                }
            }
            return result
        } ?? [:]
    }

    private func apply(_ confirmation: StoredMessageConfirmation, versions: [MessageId: UInt32], file: StaticString = #filePath, line: UInt = #line) -> [MessageId]? {
        let mediaBox = self.fixture.postbox.mediaBox
        return self.fixture.transaction({ transaction -> [MessageId] in
            return applyStoredMessageConfirmation(transaction: transaction, accountPeerId: StateSyncFixture.accountPeerId, mediaBox: mediaBox, confirmation: confirmation, versions: versions)
        }, file: file, line: line)
    }

    /// A fresh copy of message `id` in the chat with user 200, as an answer carries it.
    private func freshPrivateMessage(_ id: Int32, text: String) -> StoreMessage? {
        return StoreMessage(apiMessage: StateSyncApi.privateMessage(id: id, peerUserId: 200, fromUserId: 200, date: self.baseDate, text: text), accountPeerId: StateSyncFixture.accountPeerId, peerIsForum: false)
    }

    // MARK: - Requests

    /// Private-chat ids go to messages.getMessages, ascending, at most 200 per request, and the second
    /// request is sent only after the first one answered.
    func testRegularIdsGoInBatchesOfTwoHundredOneAfterAnother() {
        let user = StateSyncFixture.userPeerId(200)
        let ids = (Int32(1) ... Int32(250)).map { self.messageId(user, $0) }
        self.server.on(Name.messagesGetMessages, .hold)
        self.server.on(Name.messagesGetMessages, .result(StateSyncApi.messages([self.incomingMessage(240, from: 200)], users: [StateSyncApi.user(id: 200, firstName: "U200")])))

        let recorder = self.fixture.observe(confirmStoredMessages(accountPeerId: StateSyncFixture.accountPeerId, postbox: self.fixture.postbox, source: .network(self.network), ids: Array(ids.reversed())))

        XCTAssertTrue(self.server.waitForRequest(Name.messagesGetMessages))
        // The block that sent the first request has finished: a parallel implementation would have sent the
        // second one by now.
        Postbox.sharedQueue.sync {}
        self.server.flush()
        XCTAssertEqual(self.server.requestNames, [Name.messagesGetMessages])
        XCTAssertTrue(self.server.release(Name.messagesGetMessages, with: .result(StateSyncApi.messages([self.incomingMessage(5, from: 200)], users: [StateSyncApi.user(id: 200, firstName: "U200")]))))

        let confirmation = recorder.wait(until: { !$0.isEmpty }).first
        XCTAssertEqual(self.server.requestNames, [Name.messagesGetMessages, Name.messagesGetMessages])
        XCTAssertEqual(self.payload(at: 0), ConfirmationApi.getMessagesPayload(Array(Int32(1) ... Int32(200))))
        XCTAssertEqual(self.payload(at: 1), ConfirmationApi.getMessagesPayload(Array(Int32(201) ... Int32(250))))
        XCTAssertEqual(self.existingIds(confirmation), [self.messageId(user, 5), self.messageId(user, 240)])
        XCTAssertEqual(confirmation?.missing.count, 248)
        XCTAssertEqual(confirmation?.missing.contains(self.messageId(user, 5)), false)
        XCTAssertEqual(confirmation?.missing.contains(self.messageId(user, 240)), false)
        XCTAssertEqual(confirmation?.peers.users.keys.sorted(), [user])
    }

    /// messageEmpty and an id the answer leaves out both count as missing: a left-out message is considered
    /// deleted (owner, 2026-10-25, keeping spec §4's "not returned: delete").
    func testMessageEmptyAndOmittedIdsAreMissing() {
        let user = StateSyncFixture.userPeerId(200)
        self.server.on(Name.messagesGetMessages, .result(StateSyncApi.messages([
            self.incomingMessage(10, from: 200),
            ConfirmationApi.messageEmpty(id: 11, peer: StateSyncApi.peerUser(200))
        ])))

        let confirmation = self.confirm([self.messageId(user, 10), self.messageId(user, 11), self.messageId(user, 12)])

        XCTAssertEqual(self.server.requestNames, [Name.messagesGetMessages])
        XCTAssertEqual(self.existingIds(confirmation), [self.messageId(user, 10)])
        XCTAssertEqual(confirmation?.missing, Set([self.messageId(user, 11), self.messageId(user, 12)]))
    }

    /// An id answered as a real message of another chat is neither existing nor missing.
    func testIdAnsweredUnderAnotherChatIsNeitherExistingNorMissing() {
        let user = StateSyncFixture.userPeerId(200)
        self.server.on(Name.messagesGetMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 15, peerUserId: 201, fromUserId: 201, date: self.baseDate)
        ])))

        let confirmation = self.confirm([self.messageId(user, 15), self.messageId(user, 16)])

        XCTAssertEqual(self.existingIds(confirmation), [])
        XCTAssertEqual(confirmation?.missing, Set([self.messageId(user, 16)]))
    }

    /// An error is retried with the same ids, and only the answer decides what is missing.
    func testAnErrorIsRetriedAndNothingIsLost() {
        let user = StateSyncFixture.userPeerId(200)
        self.server.on(Name.messagesGetMessages, .error(code: 500, text: "INTERNAL_SERVER_ERROR"))
        self.server.on(Name.messagesGetMessages, .result(StateSyncApi.messages([self.incomingMessage(20, from: 200)])))

        let confirmation = self.confirm([self.messageId(user, 20), self.messageId(user, 21)])

        XCTAssertEqual(self.server.requestNames, [Name.messagesGetMessages, Name.messagesGetMessages])
        XCTAssertEqual(self.payload(at: 0), ConfirmationApi.getMessagesPayload([20, 21]))
        XCTAssertEqual(self.payload(at: 1), ConfirmationApi.getMessagesPayload([20, 21]))
        XCTAssertEqual(self.existingIds(confirmation), [self.messageId(user, 20)])
        XCTAssertEqual(confirmation?.missing, Set([self.messageId(user, 21)]))
    }

    /// No ids, or only ids it does not confirm (a Local message), send nothing.
    func testNothingToConfirmSendsNothing() {
        let user = StateSyncFixture.userPeerId(200)

        let none = self.confirm([])
        let local = self.confirm([MessageId(peerId: user, namespace: Namespaces.Message.Local, id: 1)])

        XCTAssertEqual(self.server.requestNames, [])
        XCTAssertEqual(none?.missing, Set<MessageId>())
        XCTAssertEqual(self.existingIds(local), [])
        XCTAssertEqual(local?.missing, Set<MessageId>())
    }

    /// A channel id is skipped (logged) and nothing is asked about it, though the channel and its access hash are
    /// stored: a history fill reconciles only private chats and basic groups (`historyFillReconciles`), and the
    /// account reset deletes a channel's ghost tail without asking. The private-chat ids of the same call are
    /// confirmed as usual.
    func testAChannelIdIsSkippedAndNothingIsAskedAboutIt() {
        let user = StateSyncFixture.userPeerId(200)
        let channel = self.seedChannel(300, pts: nil, storedMessageId: nil)
        self.server.on(Name.messagesGetMessages, .result(StateSyncApi.messages([self.incomingMessage(9, from: 200)])))
        // Answered only so that a confirmation that still asks fails on its requests rather than by timing out.
        self.server.on(Name.channelsGetMessages, .result(StateSyncApi.channelMessages(pts: 40, [])))

        let confirmation = self.confirm([self.messageId(channel, 5), self.messageId(user, 9), self.messageId(user, 10)])

        XCTAssertEqual(self.server.requestNames, [Name.messagesGetMessages])
        XCTAssertEqual(self.payload(at: 0), ConfirmationApi.getMessagesPayload([9, 10]))
        XCTAssertEqual(self.existingIds(confirmation), [self.messageId(user, 9)])
        XCTAssertEqual(confirmation?.missing, Set([self.messageId(user, 10)]))
    }

    // MARK: - Applying

    /// A missing candidate is deleted; an existing one is stored again from its fresh copy, with the peers
    /// the answer carried.
    func testApplyDeletesMissingAndRestoresExisting() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 30, timestamp: self.baseDate, authorId: user, text: "stale")
        self.fixture.storeMessage(peerId: user, id: 31, timestamp: self.baseDate + 1, authorId: user, text: "deleted")
        let versions = self.storedVersions([self.messageId(user, 30), self.messageId(user, 31)])
        guard let fresh = self.freshPrivateMessage(30, text: "fresh") else {
            XCTFail("the message does not parse")
            return
        }
        let confirmation = StoredMessageConfirmation(existing: [fresh], peers: AccumulatedPeers(users: [StateSyncApi.user(id: 202, firstName: "Answer")]), missing: [self.messageId(user, 31)])

        let deleted = self.apply(confirmation, versions: versions)

        XCTAssertEqual(deleted, [self.messageId(user, 31)])
        XCTAssertNil(self.fixture.message(self.messageId(user, 31)))
        XCTAssertEqual(self.fixture.message(self.messageId(user, 30))?.text, "fresh")
        XCTAssertNotNil(self.fixture.peer(StateSyncFixture.userPeerId(202)))
    }

    /// A candidate written again after its version was read (an update while the confirmation was in
    /// flight) is left alone, whether the answer has it or not.
    func testApplyLeavesACandidateThatChangedSinceTheReadAlone() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 40, timestamp: self.baseDate, authorId: user, text: "stale")
        self.fixture.storeMessage(peerId: user, id: 41, timestamp: self.baseDate + 1, authorId: user, text: "stale")
        let versions = self.storedVersions([self.messageId(user, 40), self.messageId(user, 41)])
        self.fixture.storeMessage(peerId: user, id: 40, timestamp: self.baseDate, authorId: user, text: "edited", location: .Random)
        self.fixture.storeMessage(peerId: user, id: 41, timestamp: self.baseDate + 1, authorId: user, text: "edited", location: .Random)
        XCTAssertNotEqual(self.storedVersions([self.messageId(user, 40)])[self.messageId(user, 40)], versions[self.messageId(user, 40)])
        guard let fresh = self.freshPrivateMessage(40, text: "fresh") else {
            XCTFail("the message does not parse")
            return
        }
        let confirmation = StoredMessageConfirmation(existing: [fresh], peers: AccumulatedPeers(), missing: [self.messageId(user, 41)])

        let deleted = self.apply(confirmation, versions: versions)

        XCTAssertEqual(deleted, [])
        XCTAssertEqual(self.fixture.message(self.messageId(user, 40))?.text, "edited")
        XCTAssertEqual(self.fixture.message(self.messageId(user, 41))?.text, "edited")
    }

    /// A missing channel message is deleted too: the deletion is `deleteStoredMessagesAsReceivedDeletion`'s, with
    /// which the account reset deletes a channel's ghost tail (a history fill never confirms a channel).
    func testApplyDeletesAMissingChannelMessage() {
        let channel = self.seedChannel(300, pts: 10, storedMessageId: 50)
        let id = self.messageId(channel, 50)
        let versions = self.storedVersions([id])
        XCTAssertNotNil(versions[id])

        let deleted = self.apply(StoredMessageConfirmation(existing: [], peers: AccumulatedPeers(), missing: [id]), versions: versions)

        XCTAssertEqual(deleted, [id])
        XCTAssertNil(self.fixture.message(id))
    }
}

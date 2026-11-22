import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getSavedDialogsByID = "messages.getSavedDialogsByID"

/// Api values only these tests need.
private enum MonoforumFillApi {
    /// `message#7600b9d3` in channel `channelId` from user `fromUserId`, in the monoforum thread of user
    /// `savedPeerUserId`: `from_id` flags.8, `saved_peer_id` flags.28, `reply_to` flags.3. The saved peer is the
    /// thread: the message is stored with `threadId` = that user's peer id (StoreMessage_Telegram.swift).
    static func message(id: Int32, channelId: Int64, fromUserId: Int64, savedPeerUserId: Int64, date: Int32, replyToMessageId: Int32? = nil) -> Api.Message {
        var flags: Int32 = (1 << 8) | (1 << 28)
        if replyToMessageId != nil {
            flags |= 1 << 3
        }
        return .message(.init(flags: flags, flags2: 0, id: id, fromId: StateSyncApi.peerUser(fromUserId), fromBoostsApplied: nil, fromRank: nil, peerId: StateSyncApi.peerChannel(channelId), savedPeerId: StateSyncApi.peerUser(savedPeerUserId), fwdFrom: nil, viaBotId: nil, viaBusinessBotId: nil, guestchatViaFrom: nil, replyTo: replyToMessageId.flatMap { StateSyncApi.replyHeader(toMessageId: $0) }, date: date, message: "text", media: nil, replyMarkup: nil, entities: nil, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: nil, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil, richMessage: nil))
    }

    /// Answer to `messages.getSavedDialogsByID`: no dialogs.
    static func noSavedDialogs() -> Api.messages.SavedDialogs {
        return .savedDialogs(.init(dialogs: [], messages: [], chats: [], users: []))
    }
}

/// History fills of a monoforum (a channel's direct messages, `TelegramChannel` flag `.isMonoforum`). It shares
/// the forum's arm of `fetchMessageHistoryHole` (`isForumOrMonoForum`): while a fetched message's thread is
/// unknown, as in every test here, what the page references is resolved BEFORE the page is stored
/// (`withResolvedAssociatedMessages(resolveThreads: true)`, Holes.swift; `forumFillStoresFirst`), but its
/// threads are saved-peer dialogs, resolved with `messages.getSavedDialogsByID` instead of
/// `messages.getForumTopicsByID` (`resolveForumThreads`, Sync/SyncResolve.swift). ForumHistoryFillTests covers
/// the forum. No state manager is involved.
final class MonoforumHistoryFillTests: StateSyncTestCase {
    /// C3 for a monoforum. A page holding a reply to a message outside the page fetches the target
    /// (channels.getMessages), then the thread of both (messages.getSavedDialogsByID for the saved peer, user
    /// 400), and stores the target and the users that came with it in the transaction that stores the page. While
    /// the thread's dialog is in flight, neither the page nor the target is stored.
    func testMonoforumFillStoresFetchedReplyTargetAndResolvesItsThreadFirst() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let monoforumId = StateSyncFixture.channelPeerId(320)
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: monoforumId, accessHash: 1, title: "M320", isBroadcast: false).withUpdatedFlags([.isMonoforum]), state: nil)
        let threadUserId = StateSyncFixture.userPeerId(400)
        let targetAuthorId = StateSyncFixture.userPeerId(500)

        // `chats: []` in every answer: a chat there would be merged over the stored monoforum
        // (AccumulatedPeers(transaction:chats:users:)) and stored by the fill.
        self.server.on(getHistory, .result(StateSyncApi.channelMessages(pts: 20, [
            MonoforumFillApi.message(id: 11, channelId: 320, fromUserId: 400, savedPeerUserId: 400, date: self.baseDate, replyToMessageId: 6)
        ], users: [StateSyncApi.user(id: 400, firstName: "Sender")])))
        self.server.on(Name.channelsGetMessages, .result(StateSyncApi.channelMessages(pts: 20, [
            MonoforumFillApi.message(id: 6, channelId: 320, fromUserId: 500, savedPeerUserId: 400, date: self.baseDate - 100)
        ], users: [StateSyncApi.user(id: 500, firstName: "Author")])))
        self.server.on(getSavedDialogsByID, .hold)

        let results = self.fixture.observe(fetchMessageHistoryHole(
            accountPeerId: StateSyncFixture.accountPeerId,
            source: .network(self.network),
            postbox: self.fixture.postbox,
            peerInput: .direct(peerId: monoforumId, threadId: nil),
            namespace: Namespaces.Message.Cloud,
            direction: .range(start: self.messageId(monoforumId, Int32.max - 1), end: self.messageId(monoforumId, 1)),
            space: .everywhere,
            count: 100
        ))

        XCTAssertTrue(self.server.waitForRequest(getSavedDialogsByID), "the page's thread was not resolved: \(self.server.requestNames)")
        // Resolved before stored: while the thread's dialog is in flight, nothing of the page is stored.
        XCTAssertNil(self.fixture.message(self.messageId(monoforumId, 11)), "the page was stored before its thread was resolved")
        XCTAssertNil(self.fixture.message(self.messageId(monoforumId, 6)), "the reply target was stored before its thread was resolved")
        XCTAssertTrue(self.server.release(getSavedDialogsByID, with: .result(MonoforumFillApi.noSavedDialogs())))
        results.wait { !$0.isEmpty }
        let result = results.values.first ?? nil

        XCTAssertEqual(self.server.requestNames, [getHistory, Name.channelsGetMessages, getSavedDialogsByID])
        XCTAssertEqual(self.server.requests.dropFirst(1).first?.payload, Api.functions.channels.getMessages(channel: .inputChannel(.init(channelId: 320, accessHash: 1)), id: [.inputMessageReplyTo(.init(id: 11))]).1.makeData())
        // flags.1: `parent_peer` present.
        XCTAssertEqual(self.server.requests.dropFirst(2).first?.payload, Api.functions.messages.getSavedDialogsByID(flags: 1 << 1, parentPeer: .inputPeerChannel(.init(channelId: 320, accessHash: 1)), ids: [.inputPeerUser(.init(userId: 400, accessHash: 1))]).1.makeData(), "arguments: \(self.server.requests.dropFirst(2).first?.arguments ?? "none")")
        XCTAssertEqual(result?.ids, [self.messageId(monoforumId, 11)])
        XCTAssertEqual(self.fixture.message(self.messageId(monoforumId, 11))?.threadId, threadUserId.toInt64())
        XCTAssertNotNil(self.fixture.peer(threadUserId))
        // C3: the target and its author, fetched before the page was stored, are stored with it.
        XCTAssertNotNil(self.fixture.message(self.messageId(monoforumId, 6)))
        XCTAssertNotNil(self.fixture.peer(targetAuthorId))
    }
}

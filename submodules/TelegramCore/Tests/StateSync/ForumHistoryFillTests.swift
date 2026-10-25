import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getForumTopicsByID = "messages.getForumTopicsByID"

/// Api values only these tests need.
private enum ForumFillApi {
    /// `message#7600b9d3` in supergroup `channelId` from user `fromUserId`: `from_id` flags.8,
    /// `reply_to` flags.3. A reply header without `forum_topic` puts it in the forum's General topic,
    /// as a message with no reply does (`threadId = 1`, StoreMessage_Telegram.swift).
    static func groupMessage(id: Int32, channelId: Int64, fromUserId: Int64, date: Int32, replyToMessageId: Int32? = nil) -> Api.Message {
        var flags: Int32 = 1 << 8
        if replyToMessageId != nil {
            flags |= 1 << 3
        }
        return .message(.init(flags: flags, flags2: 0, id: id, fromId: StateSyncApi.peerUser(fromUserId), fromBoostsApplied: nil, fromRank: nil, peerId: StateSyncApi.peerChannel(channelId), savedPeerId: nil, fwdFrom: nil, viaBotId: nil, viaBusinessBotId: nil, guestchatViaFrom: nil, replyTo: replyToMessageId.flatMap { StateSyncApi.replyHeader(toMessageId: $0) }, date: date, message: "text", media: nil, replyMarkup: nil, entities: nil, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: nil, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil, richMessage: nil))
    }
}

/// History fills of a forum. `fetchMessageHistoryHole` for a peer whose `isForumOrMonoForum` is true resolves
/// what the page references (reply targets, topic infos) BEFORE it stores the page
/// (`withResolvedAssociatedMessages(resolveThreads: true)`, Holes.swift) while a fetched message's topic info is
/// neither stored nor in the answer, as in every test here (`forumFillStoresFirst`); otherwise, and for other
/// peers, it stores first.
/// No state manager is involved: the fill only needs an authorized account state and the network.
final class ForumHistoryFillTests: StateSyncTestCase {
    /// C3. A forum page holding a reply to a message outside the page fetches the target
    /// (channels.getMessages) and then the page's topic info (messages.getForumTopicsByID), and stores
    /// the target and the users that came with it in the transaction that stores the page.
    func testForumFillStoresFetchedReplyTargetAndItsPeers() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let forumId = StateSyncFixture.channelPeerId(310)
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: forumId, accessHash: 1, title: "F310", isBroadcast: false).withUpdatedFlags([.isForum]), state: nil)
        let replyAuthorId = StateSyncFixture.userPeerId(400)
        let targetAuthorId = StateSyncFixture.userPeerId(500)

        // `chats: []` in every answer: a chat there would be merged over the stored forum
        // (AccumulatedPeers(transaction:chats:users:)) and stored by the fill.
        self.server.on(getHistory, .result(StateSyncApi.channelMessages(pts: 20, [
            ForumFillApi.groupMessage(id: 11, channelId: 310, fromUserId: 400, date: self.baseDate, replyToMessageId: 6)
        ], users: [StateSyncApi.user(id: 400, firstName: "Replier")])))
        self.server.on(Name.channelsGetMessages, .result(StateSyncApi.channelMessages(pts: 20, [
            ForumFillApi.groupMessage(id: 6, channelId: 310, fromUserId: 500, date: self.baseDate - 100)
        ], users: [StateSyncApi.user(id: 500, firstName: "Author")])))
        self.server.on(getForumTopicsByID, .result(StateSyncApi.forumTopics(pts: 20)))

        let result = self.fixture.wait(fetchMessageHistoryHole(
            accountPeerId: StateSyncFixture.accountPeerId,
            source: .network(self.network),
            postbox: self.fixture.postbox,
            peerInput: .direct(peerId: forumId, threadId: nil),
            namespace: Namespaces.Message.Cloud,
            direction: .range(start: self.messageId(forumId, Int32.max - 1), end: self.messageId(forumId, 1)),
            space: .everywhere,
            count: 100
        )) ?? nil

        XCTAssertEqual(self.server.requestNames, [getHistory, Name.channelsGetMessages, getForumTopicsByID])
        XCTAssertEqual(self.server.requests.dropFirst(1).first?.payload, Api.functions.channels.getMessages(channel: .inputChannel(.init(channelId: 310, accessHash: 1)), id: [.inputMessageReplyTo(.init(id: 11))]).1.makeData())
        XCTAssertEqual(self.server.requests.dropFirst(2).first?.payload, Api.functions.messages.getForumTopicsByID(peer: .inputPeerChannel(.init(channelId: 310, accessHash: 1)), topics: [1]).1.makeData())
        XCTAssertEqual(result?.ids, [self.messageId(forumId, 11)])
        XCTAssertNotNil(self.fixture.message(self.messageId(forumId, 11)))
        XCTAssertNotNil(self.fixture.peer(replyAuthorId))
        // C3: the target and its author, fetched before the page was stored, are stored with it.
        XCTAssertNotNil(self.fixture.message(self.messageId(forumId, 6)))
        XCTAssertNotNil(self.fixture.peer(targetAuthorId))
    }

    /// A forum stores its page only after the resolution, and only while the answer is younger than
    /// `FetchedAnswerAge.maximum` (A2): the reply target's channels.getMessages outlasts the bound, which is
    /// shortened to 0.2 s once that request is in flight. The fill stores nothing (not the page, not the target,
    /// not their users), closes nothing and ends with nil, so its caller asks again.
    func testForumFillWhoseResolutionOutlastsTheRecordStoresNothing() {
        let defaultMaximum = FetchedAnswerAge.maximum
        self.addTeardownBlock {
            FetchedAnswerAge.maximum = defaultMaximum
        }
        self.fixture.seedAccount(state: self.state(pts: 100))
        let forumId = StateSyncFixture.channelPeerId(310)
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: forumId, accessHash: 1, title: "F310", isBroadcast: false).withUpdatedFlags([.isForum]), state: nil)
        self.addHistoryFillHole(forumId)
        let replyAuthorId = StateSyncFixture.userPeerId(400)
        let targetAuthorId = StateSyncFixture.userPeerId(500)

        // `chats: []` in every answer, as above.
        self.server.on(getHistory, .result(StateSyncApi.channelMessages(pts: 20, [
            ForumFillApi.groupMessage(id: 11, channelId: 310, fromUserId: 400, date: self.baseDate, replyToMessageId: 6)
        ], users: [StateSyncApi.user(id: 400, firstName: "Replier")])))
        self.server.on(Name.channelsGetMessages, .hold)
        self.server.on(getForumTopicsByID, .result(StateSyncApi.forumTopics(pts: 20)))

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: forumId, threadId: nil), direction: self.downwardFillDirection(forumId)))

        XCTAssertTrue(self.server.waitForRequest(Name.channelsGetMessages), "the forum fill did not ask for the reply target: \(self.server.requestNames)")
        FetchedAnswerAge.maximum = 0.2
        // The resolution outlasts the (shortened) bound.
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(self.server.release(Name.channelsGetMessages, with: .result(StateSyncApi.channelMessages(pts: 20, [
            ForumFillApi.groupMessage(id: 6, channelId: 310, fromUserId: 500, date: self.baseDate - 100)
        ], users: [StateSyncApi.user(id: 500, firstName: "Author")]))))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.server.requestNames, [getHistory, Name.channelsGetMessages, getForumTopicsByID])
        XCTAssertEqual(results.values.count, 1)
        XCTAssertNil(results.values.first ?? nil, "the fill reported a result for an answer it must not store")
        XCTAssertNil(self.fixture.message(self.messageId(forumId, 11)), "the fill stored a page older than the record of recent deletions")
        XCTAssertNil(self.fixture.message(self.messageId(forumId, 6)), "the fill stored a reply target older than the record of recent deletions")
        XCTAssertNil(self.fixture.peer(replyAuthorId), "the fill stored a peer of an answer older than the record of recent deletions")
        XCTAssertNil(self.fixture.peer(targetAuthorId), "the fill stored a peer of an answer older than the record of recent deletions")
        XCTAssertEqual(self.fixture.holes(peerId: forumId), IndexSet(integersIn: 1 ... Int(Int32.max - 1)), "the fill closed its hole")
    }
}

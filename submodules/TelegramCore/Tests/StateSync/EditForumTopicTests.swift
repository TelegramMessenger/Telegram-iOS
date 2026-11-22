import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// `updateEditForumTopic` (layer 233) edits a stored topic's info. A set flag means the field changed: flags.0 the
/// title, flags.1 the icon (0 removes it), flags.2 closed, flags.3 hidden. In a forum group the server still adds a
/// `messageActionTopicEdit` for a title, closed or hidden change, which edits the info the same way; an icon-only
/// change there, and every change in a bot's topics, comes only as this update. A topic with no stored message keeps
/// no info (`MessageThreadIndexTable.replay`), so there is nothing to edit: its next fetch carries the new state.
final class EditForumTopicTests: StateSyncTestCase {
    private let iconColor: Int32 = 0x6FB9F0

    /// `updateEditForumTopic#2366665c` with only the given fields' flags set.
    private func updateEditForumTopic(peer: Api.Peer, topicId: Int32, title: String? = nil, iconEmojiId: Int64? = nil, closed: Bool? = nil, hidden: Bool? = nil) -> Api.Update {
        var flags: Int32 = 0
        if title != nil {
            flags |= 1 << 0
        }
        if iconEmojiId != nil {
            flags |= 1 << 1
        }
        if closed != nil {
            flags |= 1 << 2
        }
        if hidden != nil {
            flags |= 1 << 3
        }
        return .updateEditForumTopic(.init(flags: flags, peer: peer, topicId: topicId, title: title, iconEmojiId: iconEmojiId, closed: closed.map { $0 ? .boolTrue : .boolFalse }, hidden: hidden.map { $0 ? .boolTrue : .boolFalse }))
    }

    /// Stores message `messageId` in topic `threadId` of `peerId` and the topic's info: "Old", icon 777, open, shown.
    private func seedTopic(peerId: PeerId, threadId: Int64, messageId: Int32) {
        let _ = self.fixture.transaction { transaction -> Void in
            let message = StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageId), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: self.baseDate, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "topic", attributes: [], media: [])
            let _ = transaction.addMessages([message], location: .UpperHistoryBlock)
            let data = MessageHistoryThreadData(creationDate: self.baseDate, isOwnedByMe: false, author: peerId, info: EngineMessageHistoryThread.Info(title: "Old", icon: 777, iconColor: self.iconColor), incomingUnreadCount: 0, isMarkedUnread: false, maxIncomingReadId: messageId, maxKnownMessageId: messageId, maxOutgoingReadId: 0, isClosed: false, isHidden: false, notificationSettings: TelegramPeerNotificationSettings.defaultSettings, isMessageFeeRemoved: false)
            transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: StoredMessageHistoryThreadInfo(data))
        }
    }

    private func topic(peerId: PeerId, threadId: Int64) -> MessageHistoryThreadData? {
        return self.fixture.transaction { transaction -> MessageHistoryThreadData? in
            return transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self)
        } ?? nil
    }

    private func seedForumGroup(_ id: Int64) -> PeerId {
        let peerId = StateSyncFixture.channelPeerId(id)
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: peerId, accessHash: 1, title: "F\(id)", isBroadcast: false).withUpdatedFlags([.isForum]), state: ChannelState(pts: 50, invalidatedPts: nil, synchronizedUntilMessageId: nil))
        self.fixture.seedChat(peerId: peerId)
        return peerId
    }

    /// `messageService#7a800e0a` in forum `channelId`, in topic `topicId` (`reply_to` flags.3 with `forum_topic`
    /// flags.3 and `reply_to_msg_id` flags.4: a topic edit's thread is its reply target, StoreMessage_Telegram.swift),
    /// with `messageActionTopicEdit#c0944820` carrying the given fields under the update's flags.
    private func topicEditServiceMessage(id: Int32, channelId: Int64, topicId: Int32, title: String? = nil, iconEmojiId: Int64? = nil, closed: Bool? = nil) -> Api.Message {
        var actionFlags: Int32 = 0
        if title != nil {
            actionFlags |= 1 << 0
        }
        if iconEmojiId != nil {
            actionFlags |= 1 << 1
        }
        if closed != nil {
            actionFlags |= 1 << 2
        }
        let replyHeader: Api.MessageReplyHeader = .messageReplyHeader(.init(flags: (1 << 3) | (1 << 4), replyToMsgId: topicId, replyToPeerId: nil, replyFrom: nil, replyMedia: nil, replyToTopId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, todoItemId: nil, pollOption: nil, quoteRich: nil))
        let action: Api.MessageAction = .messageActionTopicEdit(.init(flags: actionFlags, title: title, iconEmojiId: iconEmojiId, closed: closed.map { $0 ? .boolTrue : .boolFalse }, hidden: nil))
        return .messageService(.init(flags: 1 << 3, id: id, fromId: nil, peerId: StateSyncApi.peerChannel(channelId), savedPeerId: nil, replyTo: replyHeader, date: self.baseDate + 2, action: action, reactions: nil, ttlPeriod: nil))
    }

    /// A reply target the batch's resolution asks for (the topic's root, here) is answered empty.
    private func answerReplyTargetsEmpty() {
        self.server.always(Name.channelsGetMessages, { _ in .result(StateSyncApi.channelMessages(pts: 50, [])) })
    }

    private func push(_ update: Api.Update) {
        self.server.push(StateSyncApi.updates([update], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()
    }

    /// Every field flagged: the title, the icon removed (0), closed and hidden. The colour is not the update's and
    /// stays; nothing is asked.
    func testEditForumTopicAppliesEveryFlaggedField() {
        let forum = self.seedForumGroup(340)
        self.seedTopic(peerId: forum, threadId: 5, messageId: 20)
        self.launchIdle()

        self.push(self.updateEditForumTopic(peer: StateSyncApi.peerChannel(340), topicId: 5, title: "New", iconEmojiId: 0, closed: true, hidden: true))

        let data = self.topic(peerId: forum, threadId: 5)
        XCTAssertEqual(data?.info.title, "New")
        XCTAssertNil(data?.info.icon, "an icon id of 0 removes the icon")
        XCTAssertEqual(data?.info.iconColor, self.iconColor)
        XCTAssertEqual(data?.isClosed, true)
        XCTAssertEqual(data?.isHidden, true)
        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// Only the icon is flagged (a group's icon-only change, which has no service message): the title and flags
    /// keep their stored values; a later update reopens and shows the topic again.
    func testEditForumTopicLeavesTheFieldsItDoesNotFlag() {
        let forum = self.seedForumGroup(341)
        self.seedTopic(peerId: forum, threadId: 5, messageId: 20)
        self.launchIdle()

        self.push(self.updateEditForumTopic(peer: StateSyncApi.peerChannel(341), topicId: 5, iconEmojiId: 999))

        var data = self.topic(peerId: forum, threadId: 5)
        XCTAssertEqual(data?.info.title, "Old")
        XCTAssertEqual(data?.info.icon, 999)
        XCTAssertEqual(data?.isClosed, false)
        XCTAssertEqual(data?.isHidden, false)

        self.push(self.updateEditForumTopic(peer: StateSyncApi.peerChannel(341), topicId: 5, closed: true, hidden: true))
        data = self.topic(peerId: forum, threadId: 5)
        XCTAssertEqual(data?.isClosed, true)
        XCTAssertEqual(data?.isHidden, true)

        self.push(self.updateEditForumTopic(peer: StateSyncApi.peerChannel(341), topicId: 5, closed: false, hidden: false))

        data = self.topic(peerId: forum, threadId: 5)
        XCTAssertEqual(data?.info.title, "Old")
        XCTAssertEqual(data?.info.icon, 999)
        XCTAssertEqual(data?.isClosed, false, "boolFalse reopens the topic")
        XCTAssertEqual(data?.isHidden, false)
    }

    /// A bot's topics: `peer` is the bot, and the update is the only signal of the edit.
    func testEditForumTopicEditsABotsTopic() {
        let botId = StateSyncFixture.userPeerId(600)
        let bot = TelegramUser(
            id: botId, accessHash: .personal(1), firstName: "Bot", lastName: nil, username: nil, phone: nil, photo: [],
            botInfo: BotUserInfo(flags: [.hasForum], inlinePlaceholder: nil), restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [],
            storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil,
            profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil
        )
        self.fixture.seedPeers([bot])
        self.fixture.seedChat(peerId: botId)
        self.seedTopic(peerId: botId, threadId: 7, messageId: 30)
        self.launchIdle()

        self.push(self.updateEditForumTopic(peer: StateSyncApi.peerUser(600), topicId: 7, title: "Renamed by the bot"))

        let data = self.topic(peerId: botId, threadId: 7)
        XCTAssertEqual(data?.info.title, "Renamed by the bot")
        XCTAssertEqual(data?.info.icon, 777)
        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
    }

    /// A topic with no stored info: nothing is stored and nothing is asked, and the batch is replayed.
    func testEditForumTopicOfAnUnstoredTopicStoresNothing() {
        let forum = self.seedForumGroup(342)
        self.launchIdle()

        self.push(self.updateEditForumTopic(peer: StateSyncApi.peerChannel(342), topicId: 9, title: "New"))

        XCTAssertNil(self.topic(peerId: forum, threadId: 9))
        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// A group's title, closed or hidden edit also comes as a `messageActionTopicEdit` in the topic, which edits the
    /// stored info through the same replay as the update (`applyEditForumTopic`). The icon id 0 removes the icon there
    /// too.
    func testTopicEditServiceMessageEditsTheTopic() {
        let forum = self.seedForumGroup(344)
        self.seedTopic(peerId: forum, threadId: 5, messageId: 20)
        self.launchIdle()
        self.answerReplyTargetsEmpty()

        self.push(StateSyncApi.updateNewChannelMessage(self.topicEditServiceMessage(id: 21, channelId: 344, topicId: 5, title: "Renamed", iconEmojiId: 0), pts: 51))

        XCTAssertNotNil(self.fixture.message(self.messageId(forum, 21)), "the service message was not stored")
        let data = self.topic(peerId: forum, threadId: 5)
        XCTAssertEqual(data?.info.title, "Renamed")
        XCTAssertNil(data?.info.icon)
        XCTAssertEqual(data?.isClosed, false)
        XCTAssertEqual(self.fixture.channelState(forum)?.pts, 51)
    }

    /// The server sends both for a group's title or closed edit, possibly in one batch: the second application finds
    /// the info already edited and leaves it so.
    func testServiceMessageAndUpdateInOneBatchLeaveTheSameInfo() {
        let forum = self.seedForumGroup(345)
        self.seedTopic(peerId: forum, threadId: 5, messageId: 20)
        self.launchIdle()
        self.answerReplyTargetsEmpty()

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateNewChannelMessage(self.topicEditServiceMessage(id: 21, channelId: 345, topicId: 5, title: "Renamed", closed: true), pts: 51),
            self.updateEditForumTopic(peer: StateSyncApi.peerChannel(345), topicId: 5, title: "Renamed", closed: true)
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertNotNil(self.fixture.message(self.messageId(forum, 21)))
        let data = self.topic(peerId: forum, threadId: 5)
        XCTAssertEqual(data?.info.title, "Renamed")
        XCTAssertEqual(data?.info.icon, 777)
        XCTAssertEqual(data?.isClosed, true)
        XCTAssertEqual(data?.isHidden, false)
    }

    /// From a difference's `other_updates` as from a push.
    func testEditForumTopicInADifferenceIsApplied() {
        let forum = self.seedForumGroup(343)
        self.seedTopic(peerId: forum, threadId: 5, messageId: 20)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            otherUpdates: [self.updateEditForumTopic(peer: StateSyncApi.peerChannel(343), topicId: 5, title: "From the difference", hidden: true)],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        self.fixture.resetStateManager()
        self.isUpdating.wait { $0 == [true, false] }

        let data = self.topic(peerId: forum, threadId: 5)
        XCTAssertEqual(data?.info.title, "From the difference")
        XCTAssertEqual(data?.isHidden, true)
        XCTAssertEqual(data?.isClosed, false)
    }
}

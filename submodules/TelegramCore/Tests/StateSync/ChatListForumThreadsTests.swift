import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getForumTopicsByID = "messages.getForumTopicsByID"

/// Api values only these tests need.
private enum ChatListForumApi {
    /// `user#b1b8cc83` for a bot: `bot` flags.14 (which also carries `bot_info_version`, so that is set
    /// too), `access_hash` flags.0, `first_name` flags.1, and `bot_forum_view` flags2.16 when the bot's
    /// chat has topics (`BotUserInfoFlags.hasForum`).
    static func bot(id: Int64, hasForum: Bool) -> Api.User {
        let flags: Int32 = (1 << 0) | (1 << 1) | (1 << 14)
        let flags2: Int32 = hasForum ? (1 << 16) : 0
        return .user(.init(flags: flags, flags2: flags2, id: id, accessHash: 1, firstName: "Bot", lastName: nil, username: nil, phone: nil, photo: nil, status: nil, botInfoVersion: 1, restrictionReason: nil, botInlinePlaceholder: nil, langCode: nil, emojiStatus: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, botActiveUsers: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedCommunityId: nil))
    }

    /// `channel#d49f34c6` for a forum supergroup: `megagroup` flags.8, `access_hash` flags.13,
    /// `forum` flags.30.
    static func forumGroup(id: Int64) -> Api.Chat {
        let flags: Int32 = (1 << 8) | (1 << 13) | (1 << 30)
        return .channel(.init(flags: flags, flags2: 0, id: id, accessHash: 1, title: "Forum", username: nil, photo: .chatPhotoEmpty, date: 1, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: nil))
    }

    /// A message from bot `botId` in its chat, in topic `topicId`: `from_id` flags.8, `reply_to` flags.3
    /// with a header that has `forum_topic` flags.3 and `reply_to_msg_id` flags.4, which is how a bot
    /// forum's message gets its thread id (StoreMessage_Telegram.swift).
    static func botTopicMessage(id: Int32, botId: Int64, topicId: Int32, date: Int32) -> Api.Message {
        let replyHeader: Api.MessageReplyHeader = .messageReplyHeader(.init(flags: (1 << 3) | (1 << 4), replyToMsgId: topicId, replyToPeerId: nil, replyFrom: nil, replyMedia: nil, replyToTopId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, todoItemId: nil, pollOption: nil, quoteRich: nil))
        return .message(.init(flags: (1 << 3) | (1 << 8), flags2: 0, id: id, fromId: StateSyncApi.peerUser(botId), fromBoostsApplied: nil, fromRank: nil, peerId: StateSyncApi.peerUser(botId), savedPeerId: nil, fwdFrom: nil, viaBotId: nil, viaBusinessBotId: nil, guestchatViaFrom: nil, replyTo: replyHeader, date: date, message: "text", media: nil, replyMarkup: nil, entities: nil, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: nil, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil, richMessage: nil))
    }

    /// `forumTopic#fcdad815` with no optional field set (`icon_emoji_id` flags.0, `draft` flags.4 clear).
    static func forumTopic(id: Int32, peer: Api.Peer, title: String, topMessage: Int32) -> Api.ForumTopic {
        return .forumTopic(.init(flags: 0, id: id, date: 1, peer: peer, title: title, iconColor: 0, iconEmojiId: nil, topMessage: topMessage, readInboxMaxId: 0, readOutboxMaxId: 0, unreadCount: 0, unreadMentionsCount: 0, unreadReactionsCount: 0, unreadPollVotesCount: 0, fromId: peer, notifySettings: StateSyncApi.emptyNotifySettings(), draft: nil))
    }

    /// Answer to `messages.getForumTopicsByID`.
    static func forumTopics(_ topics: [Api.ForumTopic], pts: Int32) -> Api.messages.ForumTopics {
        return .forumTopics(.init(flags: 0, count: Int32(topics.count), topics: topics, messages: [], chats: [], users: [], pts: pts))
    }
}

/// `resolveForumThreads(fetchedChatList:)`, the last step of `fetchChatList` (login, chat-list holes,
/// account reset): the topic infos of the forum messages a chat-list page carries are requested and
/// returned in `threadInfos`. The page's peers are what `parseDialogs` builds,
/// `AccumulatedPeers(chats:users:)`: groups and channels in `peers`, users (bots too) in `users`.
final class ChatListForumThreadsTests: StateSyncTestCase {
    private func chatList(peers: AccumulatedPeers, messages: [StoreMessage]) -> FetchedChatList {
        return FetchedChatList(
            chatPeerIds: messages.compactMap { message -> PeerId? in
                if case let .Id(id) = message.id {
                    return id.peerId
                } else {
                    return nil
                }
            },
            peers: peers,
            notificationSettings: [:],
            ttlPeriods: [:],
            viewForumAsMessages: [:],
            readStates: [:],
            mentionTagSummaries: [:],
            reactionTagSummaries: [:],
            pollVoteTagSummaries: [:],
            channelStates: [:],
            storeMessages: messages,
            topMessageIds: [:],
            lowerNonPinnedIndex: nil,
            pinnedItemIds: nil,
            folderSummaries: [:],
            peerGroupIds: [:],
            threadInfos: [:],
            inputStates: []
        )
    }

    private func resolve(_ chatList: FetchedChatList, file: StaticString = #filePath, line: UInt = #line) -> FetchedChatList? {
        return self.fixture.wait(resolveForumThreads(accountPeerId: StateSyncFixture.accountPeerId, postbox: self.fixture.postbox, source: .network(self.network), fetchedChatList: chatList), file: file, line: line)
    }

    /// C11. A bot with topics: its chat's top message carries a thread id, and the bot is in the page's
    /// `users`. Its topic info is requested and returned.
    func testBotForumTopicIsResolved() {
        let botId = StateSyncFixture.userPeerId(600)
        let peers = AccumulatedPeers(chats: [], users: [ChatListForumApi.bot(id: 600, hasForum: true)])
        // The way parseDialogs builds the message: a forum peer's message gets its topic as thread id.
        guard let message = StoreMessage(apiMessage: ChatListForumApi.botTopicMessage(id: 20, botId: 600, topicId: 7, date: self.baseDate), accountPeerId: StateSyncFixture.accountPeerId, peerIsForum: peers.get(botId)?.isForumOrMonoForum ?? false) else {
            XCTFail("the message does not parse")
            return
        }
        XCTAssertEqual(message.threadId, 7)
        self.server.on(getForumTopicsByID, .result(ChatListForumApi.forumTopics([
            ChatListForumApi.forumTopic(id: 7, peer: StateSyncApi.peerUser(600), title: "Topic", topMessage: 20)
        ], pts: 1)))

        let resolved = self.resolve(self.chatList(peers: peers, messages: [message]))

        // C11: requested once, for the bot's topic.
        XCTAssertEqual(self.server.requestNames, [getForumTopicsByID])
        XCTAssertEqual(self.server.requests.first?.payload, Api.functions.messages.getForumTopicsByID(peer: .inputPeerUser(.init(userId: 600, accessHash: 1)), topics: [7]).1.makeData())
        XCTAssertEqual(resolved?.threadInfos[PeerAndBoundThreadId(peerId: botId, threadId: 7)]?.data.info.title, "Topic")
    }

    /// Control for C11: a forum supergroup is in the page's `peers`, and its topic was resolved before the
    /// fix as after it.
    func testForumGroupTopicIsResolved() {
        let forumId = StateSyncFixture.channelPeerId(700)
        let peers = AccumulatedPeers(chats: [ChatListForumApi.forumGroup(id: 700)], users: [])
        guard let message = StoreMessage(apiMessage: StateSyncApi.channelPost(id: 30, channelId: 700, date: self.baseDate), accountPeerId: StateSyncFixture.accountPeerId, peerIsForum: peers.get(forumId)?.isForumOrMonoForum ?? false) else {
            XCTFail("the message does not parse")
            return
        }
        XCTAssertEqual(message.threadId, 1)
        self.server.on(getForumTopicsByID, .result(ChatListForumApi.forumTopics([
            ChatListForumApi.forumTopic(id: 1, peer: StateSyncApi.peerChannel(700), title: "General", topMessage: 30)
        ], pts: 1)))

        let resolved = self.resolve(self.chatList(peers: peers, messages: [message]))

        XCTAssertEqual(self.server.requestNames, [getForumTopicsByID])
        XCTAssertEqual(self.server.requests.first?.payload, Api.functions.messages.getForumTopicsByID(peer: .inputPeerChannel(.init(channelId: 700, accessHash: 1)), topics: [1]).1.makeData())
        XCTAssertEqual(resolved?.threadInfos[PeerAndBoundThreadId(peerId: forumId, threadId: 1)]?.data.info.title, "General")
    }

    /// Control for C11: a bot without topics asks for nothing, even for a message that carries a thread
    /// id (built here as a forum peer's message would be; the bot's own flags say it has no topics).
    func testBotWithoutTopicsIsNotResolved() {
        let peers = AccumulatedPeers(chats: [], users: [ChatListForumApi.bot(id: 601, hasForum: false)])
        guard let message = StoreMessage(apiMessage: ChatListForumApi.botTopicMessage(id: 20, botId: 601, topicId: 7, date: self.baseDate), accountPeerId: StateSyncFixture.accountPeerId, peerIsForum: true) else {
            XCTFail("the message does not parse")
            return
        }
        XCTAssertEqual(message.threadId, 7)

        let resolved = self.resolve(self.chatList(peers: peers, messages: [message]))

        XCTAssertEqual(self.server.requestNames, [])
        XCTAssertEqual(resolved?.threadInfos.isEmpty, true)
    }
}

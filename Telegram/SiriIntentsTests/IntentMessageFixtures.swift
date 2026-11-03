import Foundation
import Postbox
import TelegramCore

/// Minimal peers and messages for the intents extension's message conversion. Only the
/// fields the conversion reads are meaningful; everything else is empty.
enum IntentMessageFixtures {
    static func user(_ id: Int64, firstName: String?, phone: String? = nil, flags: UserInfoFlags = []) -> TelegramUser {
        return TelegramUser(
            id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)),
            accessHash: nil,
            firstName: firstName,
            lastName: nil,
            username: nil,
            phone: phone,
            photo: [],
            botInfo: nil,
            restrictionInfo: nil,
            flags: flags,
            emojiStatus: nil,
            usernames: [],
            storiesHidden: nil,
            nameColor: nil,
            backgroundEmojiId: nil,
            profileColor: nil,
            profileBackgroundEmojiId: nil,
            subscriberCount: nil,
            verificationIconFileId: nil
        )
    }

    static func group(_ id: Int64, title: String, membership: TelegramGroupMembership = .Member, defaultBannedRights: TelegramChatBannedRights? = nil, flags: TelegramGroupFlags = [], migratedTo: PeerId? = nil) -> TelegramGroup {
        return TelegramGroup(
            id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id)),
            title: title,
            photo: [],
            participantCount: 3,
            role: .member,
            membership: membership,
            flags: flags,
            defaultBannedRights: defaultBannedRights,
            migrationReference: migratedTo.map { TelegramGroupToChannelMigrationReference(peerId: $0, accessHash: 0) },
            creationDate: 0,
            version: 0
        )
    }

    static func channel(_ id: Int64, title: String, info: TelegramChannelInfo, flags: TelegramChannelFlags = [], participationStatus: TelegramChannelParticipationStatus = .member, bannedRights: TelegramChatBannedRights? = nil, defaultBannedRights: TelegramChatBannedRights? = nil, sendPaidMessageStars: StarsAmount? = nil) -> TelegramChannel {
        return TelegramChannel(
            id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id)),
            accessHash: nil,
            title: title,
            username: nil,
            photo: [],
            creationDate: 0,
            version: 0,
            participationStatus: participationStatus,
            info: info,
            flags: flags,
            restrictionInfo: nil,
            adminRights: nil,
            bannedRights: bannedRights,
            defaultBannedRights: defaultBannedRights,
            usernames: [],
            storiesHidden: nil,
            nameColor: nil,
            backgroundEmojiId: nil,
            profileColor: nil,
            profileBackgroundEmojiId: nil,
            emojiStatus: nil,
            approximateBoostLevel: nil,
            subscriptionUntilDate: nil,
            verificationIconFileId: nil,
            sendPaidMessageStars: sendPaidMessageStars,
            linkedMonoforumId: nil
        )
    }

    static func broadcastChannel(_ id: Int64, title: String) -> TelegramChannel {
        return channel(id, title: title, info: .broadcast(TelegramChannelBroadcastInfo(flags: [])))
    }

    static func supergroup(_ id: Int64, title: String, flags: TelegramChannelFlags = [], participationStatus: TelegramChannelParticipationStatus = .member, bannedRights: TelegramChatBannedRights? = nil, defaultBannedRights: TelegramChatBannedRights? = nil, sendPaidMessageStars: StarsAmount? = nil) -> TelegramChannel {
        return channel(id, title: title, info: .group(TelegramChannelGroupInfo(flags: [])), flags: flags, participationStatus: participationStatus, bannedRights: bannedRights, defaultBannedRights: defaultBannedRights, sendPaidMessageStars: sendPaidMessageStars)
    }

    static let noTextAllowed = TelegramChatBannedRights(flags: [.banSendText], untilDate: Int32.max)

    /// An incoming text message in `chat`, written by `author`, rendered the way the postbox
    /// renders one: both the chat peer and the author are in `peers`.
    static func message(id: Int32 = 100, in chat: Peer, author: Peer, text: String = "hello") -> Message {
        var peers = SimpleDictionary<PeerId, Peer>()
        peers[chat.id] = chat
        peers[author.id] = author
        return Message(
            stableId: UInt32(id),
            stableVersion: 0,
            id: MessageId(peerId: chat.id, namespace: Namespaces.Message.Cloud, id: id),
            globallyUniqueId: nil,
            groupingKey: nil,
            groupInfo: nil,
            threadId: nil,
            timestamp: 1_700_000_000,
            flags: [.Incoming],
            tags: [],
            globalTags: [],
            localTags: [],
            customTags: [],
            forwardInfo: nil,
            author: author,
            text: text,
            attributes: [],
            media: [],
            peers: peers,
            associatedMessages: SimpleDictionary(),
            associatedMessageIds: [],
            associatedMedia: [:],
            associatedThreadInfo: nil,
            associatedStories: [:]
        )
    }
}

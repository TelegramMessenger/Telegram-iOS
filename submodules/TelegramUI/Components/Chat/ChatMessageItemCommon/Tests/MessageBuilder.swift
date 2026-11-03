import Foundation
import Postbox
import TelegramCore

let accountPeerIdForTests = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))

func makeUserPeerId(_ id: Int64) -> PeerId {
    return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
}

func makeUser(id: Int64) -> TelegramUser {
    return TelegramUser(
        id: makeUserPeerId(id),
        accessHash: nil,
        firstName: "U\(id)",
        lastName: nil,
        username: nil,
        phone: nil,
        photo: [],
        botInfo: nil,
        restrictionInfo: nil,
        flags: UserInfoFlags(),
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

func makeChannel(id: Int64, info: TelegramChannelInfo, flags: TelegramChannelFlags = TelegramChannelFlags(), adminRights: TelegramChatAdminRights? = nil, defaultBannedRights: TelegramChatBannedRights? = nil) -> TelegramChannel {
    return TelegramChannel(
        id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id)),
        accessHash: nil,
        title: "C\(id)",
        username: nil,
        photo: [],
        creationDate: 0,
        version: 0,
        participationStatus: .member,
        info: info,
        flags: flags,
        restrictionInfo: nil,
        adminRights: adminRights,
        bannedRights: nil,
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
        sendPaidMessageStars: nil,
        linkedMonoforumId: nil
    )
}

func makeGroupChannel(id: Int64, isMonoforum: Bool = false) -> TelegramChannel {
    var flags = TelegramChannelFlags()
    if isMonoforum {
        flags.insert(.isMonoforum)
    }
    return makeChannel(id: id, info: .group(TelegramChannelGroupInfo(flags: TelegramChannelGroupFlags())), flags: flags)
}

func makeBroadcastChannel(id: Int64, messagesShouldHaveProfiles: Bool) -> TelegramChannel {
    var broadcastFlags = TelegramChannelBroadcastFlags()
    if messagesShouldHaveProfiles {
        broadcastFlags.insert(.messagesShouldHaveProfiles)
    }
    return makeChannel(id: id, info: .broadcast(TelegramChannelBroadcastInfo(flags: broadcastFlags)))
}

func makeForwardInfo(author: Peer?, authorSignature: String?, date: Int32, isImported: Bool) -> MessageForwardInfo {
    var flags = MessageForwardInfo.Flags()
    if isImported {
        flags.insert(.isImported)
    }
    return MessageForwardInfo(
        author: author,
        source: nil,
        sourceMessageId: nil,
        date: date,
        authorSignature: authorSignature,
        psaType: nil,
        flags: flags
    )
}

/// Minimal message factory. Only the fields `referenceMessagesShouldBeMerged` reads are
/// parameterised; everything else is a fixed, inert default.
///
/// `Message.effectivelyIncoming(_:)` falls through to `flags.contains(.Incoming)` for any peer that
/// is not the account itself and any author that is not the account — which is every case this
/// builder produces, except that a broadcast channel forces `true` regardless. That is real
/// behavior, not a builder artifact.
func makeMessage(
    stableId: UInt32 = 1,
    peer: Peer,
    author: Peer?,
    timestamp: Int32 = 1000,
    isOutgoing: Bool = false,
    attributes: [MessageAttribute] = [],
    media: [Media] = [],
    forwardInfo: MessageForwardInfo? = nil,
    extraPeers: [Peer] = []
) -> Message {
    var flags = MessageFlags()
    if !isOutgoing {
        flags.insert(.Incoming)
    }

    var peers = SimpleDictionary<PeerId, Peer>()
    peers[peer.id] = peer
    if let author = author {
        peers[author.id] = author
    }
    for extra in extraPeers {
        peers[extra.id] = extra
    }

    return Message(
        stableId: stableId,
        stableVersion: 0,
        id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(stableId)),
        globallyUniqueId: nil,
        groupingKey: nil,
        groupInfo: nil,
        threadId: nil,
        timestamp: timestamp,
        flags: flags,
        tags: MessageTags(),
        globalTags: GlobalMessageTags(),
        localTags: LocalMessageTags(),
        customTags: [],
        forwardInfo: forwardInfo,
        author: author,
        text: "",
        attributes: attributes,
        media: media,
        peers: peers,
        associatedMessages: SimpleDictionary<MessageId, Message>(),
        associatedMessageIds: [],
        associatedMedia: [:],
        associatedThreadInfo: nil,
        associatedStories: [:]
    )
}

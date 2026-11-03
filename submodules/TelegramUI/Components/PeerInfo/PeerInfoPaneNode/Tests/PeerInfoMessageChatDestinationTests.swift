import XCTest
import Postbox
import TelegramCore
import PeerInfoPaneNode

/// "View in Chat" on a profile's shared media opens the chat the media tab lists, which is not
/// always the chat the message itself is stored in, nor the peer the profile describes.
final class PeerInfoMessageChatDestinationTests: XCTestCase {
    private let user = makeUser(id: 2)

    // bugs.telegram.org/c/26706: a secret chat's profile describes the user, but its media belongs
    // to the secret chat, which is what the profile's chat peer is.
    func testSecretChatProfileOpensTheSecretChat() {
        let secretChat = TelegramSecretChat(
            id: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(10)),
            creationDate: 0,
            regularPeerId: self.user.id,
            accessHash: 0,
            role: .creator,
            embeddedState: .active,
            messageAutoremoveTimeout: nil
        )
        let message = makeMessage(peer: secretChat, author: self.user)

        XCTAssertEqual(peerInfoMessageChatDestination(message: message, listedPeer: .secretChat(secretChat), listedThread: nil), .peer(.secretChat(secretChat)))
    }

    /// A supergroup's history view includes its pre-migration basic group as a tail, so the
    /// supergroup's media tab lists messages stored in the basic group. They open in the
    /// supergroup, which shows that history, not in the deactivated basic group.
    func testMessageFromPreMigrationGroupOpensTheSupergroup() {
        let supergroup = makeChannel(id: 50, flags: [])
        let basicGroup = TelegramGroup(
            id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(51)),
            title: "G",
            photo: [],
            participantCount: 2,
            role: .member,
            membership: .Member,
            flags: TelegramGroupFlags(),
            defaultBannedRights: nil,
            migrationReference: TelegramGroupToChannelMigrationReference(peerId: supergroup.id, accessHash: 0),
            creationDate: 0,
            version: 0
        )
        let message = makeMessage(peer: basicGroup, author: self.user)

        XCTAssertEqual(peerInfoMessageChatDestination(message: message, listedPeer: .channel(supergroup), listedThread: nil), .peer(.channel(supergroup)))
    }

    /// A user's profile opened from a channel's direct messages lists the monoforum thread with
    /// that user. The thread id is the user's peer id, which does not fit the Int32 message id
    /// that forum-topic resolution works with, so the listed thread is opened directly.
    func testDirectMessagesProfileOpensTheListedThread() {
        let largeUser = makeUser(id: Int64(Int32.max) + 1000)
        let monoforum = makeChannel(id: 20, flags: [.isMonoforum])
        let listedThread = makeThread(peerId: monoforum.id, threadId: largeUser.id.toInt64(), isMonoforumPost: true)
        let message = makeMessage(peer: monoforum, author: largeUser, threadId: largeUser.id.toInt64())

        XCTAssertEqual(peerInfoMessageChatDestination(message: message, listedPeer: .user(largeUser), listedThread: listedThread), .replyThread(listedThread))
    }

    /// No current entry point lists a monoforum as the profile's chat (a monoforum redirects its
    /// profile to the main channel), but if one does, its threads are keyed by user ids and must
    /// not go through forum-topic resolution either.
    func testMonoforumProfileOpensTheMessagesThread() {
        let largeUser = makeUser(id: Int64(Int32.max) + 1000)
        let monoforum = makeChannel(id: 20, flags: [.isMonoforum])
        let message = makeMessage(peer: monoforum, author: largeUser, threadId: largeUser.id.toInt64())

        XCTAssertEqual(peerInfoMessageChatDestination(message: message, listedPeer: .channel(monoforum), listedThread: nil), .replyThread(makeThread(peerId: monoforum.id, threadId: largeUser.id.toInt64(), isMonoforumPost: true)))
    }

    func testForumProfileOpensTheMessagesTopic() {
        let forum = makeChannel(id: 30, flags: [.isForum])
        let message = makeMessage(peer: forum, author: self.user, threadId: 7)

        XCTAssertEqual(peerInfoMessageChatDestination(message: message, listedPeer: .channel(forum), listedThread: nil), .forumTopic(peerId: forum.id, threadId: 7))
    }

    /// Unchanged from before: forum topics keep resolving through the topic, which refreshes the
    /// thread's state, rather than reusing the location the profile was opened with.
    func testForumTopicProfileOpensTheTopicThroughTopicResolution() {
        let forum = makeChannel(id: 30, flags: [.isForum])
        let listedThread = makeThread(peerId: forum.id, threadId: 7, isMonoforumPost: false)
        let message = makeMessage(peer: forum, author: self.user, threadId: 7)

        XCTAssertEqual(peerInfoMessageChatDestination(message: message, listedPeer: .channel(forum), listedThread: listedThread), .forumTopic(peerId: forum.id, threadId: 7))
    }

    /// Comments in a discussion group carry a thread id too, and have always opened the group.
    func testThreadedMessageInOrdinaryGroupOpensTheGroup() {
        let group = makeChannel(id: 40, flags: [])
        let message = makeMessage(peer: group, author: self.user, threadId: 7)

        XCTAssertEqual(peerInfoMessageChatDestination(message: message, listedPeer: .channel(group), listedThread: nil), .peer(.channel(group)))
    }

    func testPrivateChatProfileOpensThePrivateChat() {
        let message = makeMessage(peer: self.user, author: self.user)

        XCTAssertEqual(peerInfoMessageChatDestination(message: message, listedPeer: .user(self.user), listedThread: nil), .peer(.user(self.user)))
    }

    func testProfileWhoseChatIsNotLoadedHasNoDestination() {
        let message = makeMessage(peer: self.user, author: self.user)

        XCTAssertNil(peerInfoMessageChatDestination(message: message, listedPeer: nil, listedThread: nil))
    }
}

private func makeUser(id: Int64) -> TelegramUser {
    return TelegramUser(
        id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)),
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

private func makeChannel(id: Int64, flags: TelegramChannelFlags) -> TelegramChannel {
    return TelegramChannel(
        id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id)),
        accessHash: nil,
        title: "C\(id)",
        username: nil,
        photo: [],
        creationDate: 0,
        version: 0,
        participationStatus: .member,
        info: .group(TelegramChannelGroupInfo(flags: TelegramChannelGroupFlags())),
        flags: flags,
        restrictionInfo: nil,
        adminRights: nil,
        bannedRights: nil,
        defaultBannedRights: nil,
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

private func makeThread(peerId: PeerId, threadId: Int64, isMonoforumPost: Bool) -> ChatReplyThreadMessage {
    return ChatReplyThreadMessage(
        peerId: peerId,
        threadId: threadId,
        channelMessageId: nil,
        isChannelPost: false,
        isForumPost: true,
        isMonoforumPost: isMonoforumPost,
        maxMessage: nil,
        maxReadIncomingMessageId: nil,
        maxReadOutgoingMessageId: nil,
        unreadCount: 0,
        initialFilledHoles: IndexSet(),
        initialAnchor: .automatic,
        isNotAvailable: false
    )
}

private func makeMessage(peer: Peer, author: Peer, threadId: Int64? = nil) -> EngineMessage {
    var peers = SimpleDictionary<PeerId, Peer>()
    peers[peer.id] = peer
    peers[author.id] = author

    return EngineMessage(Message(
        stableId: 1,
        stableVersion: 0,
        id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 1),
        globallyUniqueId: nil,
        groupingKey: nil,
        groupInfo: nil,
        threadId: threadId,
        timestamp: 1000,
        flags: [.Incoming],
        tags: MessageTags(),
        globalTags: GlobalMessageTags(),
        localTags: LocalMessageTags(),
        customTags: [],
        forwardInfo: nil,
        author: author,
        text: "",
        attributes: [],
        media: [],
        peers: peers,
        associatedMessages: SimpleDictionary<MessageId, Message>(),
        associatedMessageIds: [],
        associatedMedia: [:],
        associatedThreadInfo: nil,
        associatedStories: [:]
    ))
}

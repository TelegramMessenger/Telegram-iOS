import Foundation
import TelegramCore

/// Where "View in Chat" opens a message listed in a profile's shared media: always within the chat
/// the media tab lists (see `peerInfoMessageChatDestination`).
public enum PeerInfoMessageChatDestination: Equatable {
    /// A topic of a forum channel, resolved through the topic so its state is fetched fresh.
    case forumTopic(peerId: EnginePeer.Id, threadId: Int64)
    /// A thread opened as is: the thread the tab lists, or a direct-messages thread.
    case replyThread(ChatReplyThreadMessage)
    /// The chat itself, for chats without threads.
    case peer(EnginePeer)
}

/// A channel's direct-messages thread with one user. Its thread id is the user's peer id.
public func peerInfoMonoforumThread(peerId: EnginePeer.Id, threadId: Int64) -> ChatReplyThreadMessage {
    return ChatReplyThreadMessage(
        peerId: peerId,
        threadId: threadId,
        channelMessageId: nil,
        isChannelPost: false,
        isForumPost: true,
        isMonoforumPost: true,
        maxMessage: nil,
        maxReadIncomingMessageId: nil,
        maxReadOutgoingMessageId: nil,
        unreadCount: 0,
        initialFilledHoles: IndexSet(),
        initialAnchor: .automatic,
        isNotAvailable: false
    )
}

/// The chat that "View in Chat" opens for a message listed in a profile's shared media.
///
/// It is the chat the media tab lists, not the chat the message is stored in: a supergroup's
/// history includes its pre-migration basic group, so its tab lists basic-group messages that
/// belong in the supergroup. Nor is it the peer the profile describes: a secret chat's profile
/// describes the user, so `listedPeer` must be the profile's chat peer (the secret chat).
///
/// `listedThread` is the thread the tab lists, if any. A user's profile opened from a channel's
/// direct messages lists that channel's thread with the user. Direct-messages threads are keyed by
/// user ids, which forum-topic resolution cannot take (it addresses a topic by an Int32 message
/// id), so they are always opened directly.
public func peerInfoMessageChatDestination(message: EngineMessage, listedPeer: EnginePeer?, listedThread: ChatReplyThreadMessage?) -> PeerInfoMessageChatDestination? {
    if case let .channel(channel) = listedPeer, channel.flags.contains(.isForum), let threadId = message.threadId {
        return .forumTopic(peerId: channel.id, threadId: threadId)
    }
    if let listedThread {
        return .replyThread(listedThread)
    }
    if case let .channel(channel) = listedPeer, channel.flags.contains(.isMonoforum), let threadId = message.threadId {
        return .replyThread(peerInfoMonoforumThread(peerId: channel.id, threadId: threadId))
    }
    return listedPeer.flatMap(PeerInfoMessageChatDestination.peer)
}

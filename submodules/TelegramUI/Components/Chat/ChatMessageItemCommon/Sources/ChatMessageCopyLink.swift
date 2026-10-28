import Foundation
import TelegramCore

/// Which link Copy Link in a message's context menu copies.
public enum ChatMessageCopyLinkKind: Equatable {
    /// A supergroup message or a channel post: the link the server exports for it.
    case channelMessage
    /// A message in a channel's direct messages. These are a separate channel (a monoforum) without a
    /// username, so the link is always a private `t.me/c/` one, which only those who see the conversation
    /// (the channel's admins and the user on the other side) can open.
    case directMessages
}

/// Whether a message's context menu offers Copy Link, and which link it copies. The menu also leaves it
/// out for a reply thread's head message and a migrated group's message, which depend on the chat it
/// is shown in rather than on the message.
public func chatMessageCopyLinkKind(message: EngineRawMessage) -> ChatMessageCopyLinkKind? {
    guard message.id.namespace == Namespaces.Message.Cloud, let channel = message.peers[message.id.peerId] as? TelegramChannel, !(message.media.first is TelegramMediaAction) else {
        return nil
    }
    if channel.isMonoForum {
        // The admin check every direct-messages surface uses: the main channel is the chat's associated
        // peer, so it is among the message's peers.
        guard let mainChannelId = channel.linkedMonoforumId, let mainChannel = message.peers[mainChannelId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) else {
            return nil
        }
        return .directMessages
    }
    return .channelMessage
}

/// The link Copy Link copies for a message in a channel's direct messages: the one
/// `channels.exportMessageLink` returns or, when the server returns none, the private link to the
/// message, which `t.me/c/` resolution opens in its conversation.
public func directMessagesMessageLink(exportedLink: String?, messageId: EngineMessage.Id) -> String {
    if let exportedLink {
        return exportedLink
    }
    return "https://t.me/c/\(messageId.peerId.id._internalGetInt64Value())/\(messageId.id)"
}

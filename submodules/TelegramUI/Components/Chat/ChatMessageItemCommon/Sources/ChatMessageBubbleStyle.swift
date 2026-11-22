import Foundation
import TelegramCore

/// What a message's media makes it, for the bubble-free mode: a service message (an action other than a call, or media
/// that expired), an outlined card (a poll, a checklist, a giveaway and its results, a call, a widget), or anything else.
public enum ChatMessageMediaKind: Equatable {
    case service
    case card
    case other
}

public func chatMessageMediaKind(_ message: EngineRawMessage) -> ChatMessageMediaKind {
    var kind: ChatMessageMediaKind = .other
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            switch action.action {
            case .phoneCall, .conferenceCall:
                kind = .card
            default:
                return .service
            }
        } else if media is TelegramMediaExpiredContent {
            return .service
        } else if media is TelegramMediaPoll || media is TelegramMediaTodo || media is TelegramMediaGiveaway || media is TelegramMediaGiveawayResults || media is TelegramMediaWidget {
            kind = .card
        }
    }
    return kind
}

/// How a message is drawn: in a bubble (always with bubble mode on, and for outgoing messages), flat on the page, as an
/// outlined card, or as a service message without a plate. The one decision every bubble-free layout reads (spec 6.4).
public enum ChatMessageBubbleStyle: Equatable {
    case bubble
    case bubbleless
    case bubblelessCard
    case bubblelessService
    
    /// An incoming message without a bubble: flat on the page or an outlined card.
    public var isBubbleless: Bool {
        switch self {
        case .bubbleless, .bubblelessCard:
            return true
        case .bubble, .bubblelessService:
            return false
        }
    }
}

public func chatMessageBubbleStyle(bubbleMode: Bool, isMessageOptions: Bool, incoming: Bool, message: EngineRawMessage) -> ChatMessageBubbleStyle {
    if bubbleMode {
        return .bubble
    }
    // The forward, reply and link option screens show messages as they are sent: in bubbles.
    if isMessageOptions {
        return .bubble
    }
    let kind = chatMessageMediaKind(message)
    if kind == .service {
        return .bubblelessService
    }
    if !incoming {
        return .bubble
    }
    return kind == .card ? .bubblelessCard : .bubbleless
}

/// Without bubbles, whether a message in a chat with a person carries their avatar, as in a group, so that their side
/// reads apart from yours: a message without a bubble (cards included, service messages not) in a cloud chat with a
/// user who is not a bot, outside previews (spec 3.2). The item's avatar header and every item node's avatar column read
/// this one answer.
public func chatMessageBubblelessPrivateChatHasAvatar(style: ChatMessageBubbleStyle, isPreview: Bool, chatPeer: EnginePeer?) -> Bool {
    guard style.isBubbleless, !isPreview, case let .user(user)? = chatPeer else {
        return false
    }
    return user.botInfo == nil
}

/// Without bubbles, whether incoming runs in a chat are headed by their author's name: in every chat but a secret one,
/// which gets neither a name nor an avatar (spec 3.2).
public func chatMessageBubblelessChatShowsAuthor(chatPeerId: EnginePeer.Id) -> Bool {
    return chatPeerId.namespace != Namespaces.Peer.SecretChat
}

/// Without bubbles, whether a chat is a channel whose posts carry no author profile: it has no avatar column to carry a
/// follow-up post's time, so every post is headed by its name, time and views.
public func chatMessageBubblelessIsChannelPostWithoutProfiles(chatPeer: EnginePeer?) -> Bool {
    if case let .channel(channel) = chatPeer, case let .broadcast(info) = channel.info, !info.flags.contains(.messagesShouldHaveProfiles) {
        return true
    }
    return false
}

/// Without bubbles, whether an incoming message heads its row with its author's name and time, for text and media and for
/// stickers and large emoji alike: the first of a run, and every post of a channel without profiles; never in a secret
/// chat (spec 3.2).
public func chatMessageBubblelessHeadsRow(isMergedWithPrevious: Bool, isChannelPostWithoutProfiles: Bool, chatPeerId: EnginePeer.Id) -> Bool {
    return (!isMergedWithPrevious || isChannelPostWithoutProfiles) && chatMessageBubblelessChatShowsAuthor(chatPeerId: chatPeerId)
}

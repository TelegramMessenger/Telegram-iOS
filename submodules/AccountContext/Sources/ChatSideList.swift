import Foundation
import TelegramCore
import TelegramUIPreferences

/// The chat side list: the parent chat list (Saved Messages sub-chats, a channel's direct messages, a bot's threads)
/// slid in over a chat from the sidebar button. With it off, those chats keep `ChatSideTopicsPanel`.
public let chatSideListKillswitchKey = "ios_killswitch_disable_chat_side_list"

public func chatSideListEnabled(legacyOverride: Bool, killswitchPresent: Bool) -> Bool {
    return !legacyOverride && !killswitchPresent
}

public extension AccountContext {
    var usesChatSideList: Bool {
        return chatSideListEnabled(
            legacyOverride: self.sharedContext.immediateExperimentalUISettings.chatSideListLegacy,
            killswitchPresent: self.getAppConfigValue(chatSideListKillswitchKey) != nil
        )
    }
}

public enum ChatSideListKind: Equatable {
    case savedMessages(peerId: EnginePeer.Id)
    case monoforum(peerId: EnginePeer.Id)
    case botThreads(peerId: EnginePeer.Id)

    /// The peer whose threads the list shows: the chat's own peer in every kind.
    public var parentPeerId: EnginePeer.Id {
        switch self {
        case let .savedMessages(peerId), let .monoforum(peerId), let .botThreads(peerId):
            return peerId
        }
    }

    public var listLocation: ChatListControllerLocation {
        switch self {
        case let .savedMessages(peerId), let .monoforum(peerId):
            return .savedMessagesChats(peerId: peerId)
        case let .botThreads(peerId):
            return .forum(peerId: peerId)
        }
    }

    public var showsNewTopicButton: Bool {
        if case .botThreads = self {
            return true
        } else {
            return false
        }
    }
}

/// Which side list a chat with `peerId` gets, or nil for none. Forums are left out on purpose: they keep their strip.
public func chatSideListKind(
    peerId: EnginePeer.Id,
    accountPeerId: EnginePeer.Id,
    isForum: Bool,
    isMonoforum: Bool,
    isAdminMonoforum: Bool,
    isBotWithThreads: Bool,
    isRegularWidth: Bool,
    enabled: Bool
) -> ChatSideListKind? {
    if !enabled || isRegularWidth || isForum {
        return nil
    }
    if peerId == accountPeerId {
        return .savedMessages(peerId: peerId)
    } else if isMonoforum {
        return isAdminMonoforum ? .monoforum(peerId: peerId) : nil
    } else if isBotWithThreads {
        return .botThreads(peerId: peerId)
    } else {
        return nil
    }
}

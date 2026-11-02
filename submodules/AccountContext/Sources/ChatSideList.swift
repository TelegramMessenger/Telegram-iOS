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
    /// A forum in the sidebar display mode (`forum_sidebar`).
    case forum(peerId: EnginePeer.Id)

    /// The peer whose threads the list shows: the chat's own peer in every kind.
    public var parentPeerId: EnginePeer.Id {
        switch self {
        case let .savedMessages(peerId), let .monoforum(peerId), let .botThreads(peerId), let .forum(peerId):
            return peerId
        }
    }

    public var listLocation: ChatListControllerLocation {
        switch self {
        case let .savedMessages(peerId), let .monoforum(peerId):
            return .savedMessagesChats(peerId: peerId)
        case let .botThreads(peerId), let .forum(peerId):
            return .forum(peerId: peerId)
        }
    }

    /// Bots' threads and forums: a New Topic button at the bottom of the list (a forum's only for who can create topics).
    public var showsNewTopicButton: Bool {
        switch self {
        case .botThreads, .forum:
            return true
        case .savedMessages, .monoforum:
            return false
        }
    }
}

/// Which side list a chat with `peerId` gets, or nil for none. A forum gets one only in the sidebar display mode
/// (`isSidebarForum`); one with tabs keeps its strip and one opened as its topic list keeps that screen.
public func chatSideListKind(
    peerId: EnginePeer.Id,
    accountPeerId: EnginePeer.Id,
    isForum: Bool,
    isSidebarForum: Bool,
    isMonoforum: Bool,
    isAdminMonoforum: Bool,
    isSidebarBot: Bool,
    enabled: Bool
) -> ChatSideListKind? {
    if !enabled {
        return nil
    }
    if isForum {
        return isSidebarForum ? .forum(peerId: peerId) : nil
    }
    if peerId == accountPeerId {
        return .savedMessages(peerId: peerId)
    } else if isMonoforum {
        return isAdminMonoforum ? .monoforum(peerId: peerId) : nil
    } else if isSidebarBot {
        return .botThreads(peerId: peerId)
    } else {
        return nil
    }
}

/// What tapping a row (or a search result) in the side list does.
public enum ChatSideListSelection: Equatable {
    /// Switch the open chat to `threadId` in place (nil: the parent's own chat), optionally at a message.
    case switchThread(Int64?, messageId: EngineMessage.Id?)
    /// The row of the chat already open: just close the list.
    case closeOnly
    /// Not one of the parent's threads (a search hit elsewhere): let the list open it as usual.
    case passThrough
}

public func chatSideListSelection(kind: ChatSideListKind, currentThreadId: Int64?, selectedPeerId: EnginePeer.Id, selectedThreadId: Int64?, messageId: EngineMessage.Id?) -> ChatSideListSelection {
    if selectedPeerId != kind.parentPeerId {
        return .passThrough
    }
    if selectedThreadId == currentThreadId && messageId == nil {
        return .closeOnly
    }
    return .switchThread(selectedThreadId, messageId: messageId)
}

/// The parent and thread a tap in a chat list resolves to. A Saved Messages or direct-messages list (and its search)
/// shows the parent's threads as peers, so a peer without a thread is the parent's thread with that peer's id; a row of
/// the parent itself is its own thread (Saved Messages' "My Notes"), a search hit for it is the parent's chat.
public func chatSideListResolvedSelection(location: ChatListControllerLocation, peerId: EnginePeer.Id, threadId: Int64?, isListRow: Bool) -> (peerId: EnginePeer.Id, threadId: Int64?) {
    if case let .savedMessagesChats(parentPeerId) = location, threadId == nil, isListRow || peerId != parentPeerId {
        return (parentPeerId, peerId.toInt64())
    }
    return (peerId, threadId)
}

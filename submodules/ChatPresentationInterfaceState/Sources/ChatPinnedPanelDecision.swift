import Foundation
import TelegramCore

/// Whether a chat's pinned list (the `.pinned` tag view) has answered: it has entries, or finished loading with none.
public enum ChatPinnedListResolution: Equatable {
    case unresolved
    case resolved(hasMessage: Bool)
}

/// What a channel's pinned panel shows.
public enum ChatPinnedPanelSource: Equatable {
    case none
    /// The pinned list's message.
    case list
    /// The message for the cached pinned id, stored locally, while the list is unresolved.
    case storedCachedMessage
    /// The cached pinned id's message is not stored: the panel is a skeleton until the list answers.
    case skeleton(EngineMessage.Id)
}

/// The cached pinned id (`CachedChannelData.pinnedMessageId`) is used only while the list has not answered.
public func chatPinnedPanelSource(list: ChatPinnedListResolution, cachedPinnedMessageId: EngineMessage.Id?, isCachedMessageStored: Bool) -> ChatPinnedPanelSource {
    switch list {
    case let .resolved(hasMessage):
        return hasMessage ? .list : .none
    case .unresolved:
        guard let cachedPinnedMessageId else {
            return .none
        }
        return isCachedMessageStored ? .storedCachedMessage : .skeleton(cachedPinnedMessageId)
    }
}

/// Whether the pinned title panel is shown: for a real message, or for a skeleton when there is none, unless the user
/// closed that pin or an unpin-all is pending.
public func chatPinnedPanelIsVisible(pinnedMessageTopId: EngineMessage.Id?, skeletonId: EngineMessage.Id?, closedPinnedMessageId: EngineMessage.Id?, pendingUnpinnedAllMessages: Bool) -> Bool {
    if pendingUnpinnedAllMessages {
        return false
    }
    if let pinnedMessageTopId {
        return pinnedMessageTopId != closedPinnedMessageId
    }
    if let skeletonId {
        return skeletonId != closedPinnedMessageId
    }
    return false
}

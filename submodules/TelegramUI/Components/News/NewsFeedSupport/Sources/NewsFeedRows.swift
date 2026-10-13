import Foundation
import TelegramCore

/// Drops entries whose messages no longer resolve (deleted after they were fetched); an album keeps only
/// the messages that still do.
public func newsResolvedEntries(_ entries: [EngineFeedEntry], availableMessageIds: Set<EngineMessage.Id>) -> [EngineFeedEntry] {
    return entries.compactMap { entry -> EngineFeedEntry? in
        let ids = entry.messageIds.filter { availableMessageIds.contains($0) }
        if ids.isEmpty {
            return nil
        }
        if ids.count == entry.messageIds.count {
            return entry
        }
        return EngineFeedEntry(position: entry.position, messageIds: ids, groupingKey: entry.groupingKey)
    }
}

/// The oldest unread post of the Added list (entries newest first): the last one newer than
/// `readMarkPosition`, the read mark captured when the window opened. The list opens with it just above
/// the bottom of the viewport. nil when nothing is unread.
public func newsAddedFirstUnreadIndex(entries: [EngineFeedEntry], readMarkPosition: EngineFeedPosition?) -> Int? {
    guard let readMarkPosition else {
        return nil
    }
    let unreadCount = entries.prefix(while: { $0.position > readMarkPosition }).count
    if unreadCount == 0 {
        return nil
    }
    return unreadCount - 1
}

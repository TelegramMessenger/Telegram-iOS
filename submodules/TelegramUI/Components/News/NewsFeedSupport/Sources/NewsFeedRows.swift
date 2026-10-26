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

/// Whether the loaded messages are this window's own. A messages signal keyed on the window's ids first answers
/// with the previous window's messages, and positioning a replaced window on that partial list would stick.
public func newsWindowIsResolved(entries: [EngineFeedEntry], loadedIds: [EngineMessage.Id]) -> Bool {
    return entries.flatMap(\.messageIds) == loadedIds
}

/// The messages For you's posts show, in list order: what the binding loads.
public func newsForYouMessageIds(_ items: [EngineForYouItem]) -> [EngineMessage.Id] {
    var ids: [EngineMessage.Id] = []
    for item in items {
        if case let .post(entry) = item {
            ids.append(contentsOf: entry.messageIds)
        }
    }
    return ids
}

/// `newsWindowIsResolved` for For you. A new batch first arrives with the previous items' messages, and rendering
/// that drops its posts but not its interests block, which then showed alone until the posts pushed it away.
public func newsForYouIsResolved(items: [EngineForYouItem], loadedIds: [EngineMessage.Id]) -> Bool {
    return newsForYouMessageIds(items) == loadedIds
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

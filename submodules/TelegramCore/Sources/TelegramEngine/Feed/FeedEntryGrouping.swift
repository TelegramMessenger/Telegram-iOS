import Foundation
import Postbox

/// A stored feed message, as the grouping helpers need it.
struct FeedPageMessage: Equatable {
    let id: MessageId
    let timestamp: Int32
    let groupingKey: Int64?
}

enum ForYouBatchElement: Equatable {
    case message(FeedPageMessage)
    /// One server item holding several messages (`feedItemMessageGroup`): one entry, whatever their grouping keys.
    case group([FeedPageMessage])
    case interests
}

private struct FeedAlbumKey: Hashable {
    let peerId: PeerId
    let groupingKey: Int64
}

private func makeFeedEntry(messages: [FeedPageMessage], groupingKey: Int64?) -> EngineFeedEntry {
    var newest = messages[0]
    for message in messages.dropFirst() {
        if message.timestamp > newest.timestamp || (message.timestamp == newest.timestamp && message.id.id > newest.id.id) {
            newest = message
        }
    }
    return EngineFeedEntry(
        position: EngineFeedPosition(date: newest.timestamp, peerId: newest.id.peerId, id: newest.id.id),
        messageIds: messages.map(\.id).sorted(),
        groupingKey: groupingKey
    )
}

/// Builds items from one batch in the order given: an album's messages (same peer and grouping key) join
/// the entry of its first message, a server group is one entry and joins the entry of any of its messages or
/// albums already placed; repeated message ids are skipped.
func forYouItems(from batch: [ForYouBatchElement]) -> [EngineForYouItem] {
    enum Slot {
        case interests
        case group(Int)
    }
    var slots: [Slot] = []
    var groups: [(groupingKey: Int64?, messages: [FeedPageMessage])] = []
    var albumIndex: [FeedAlbumKey: Int] = [:]
    var messageIndex: [MessageId: Int] = [:]
    func albumKey(_ message: FeedPageMessage) -> FeedAlbumKey? {
        return message.groupingKey.map { FeedAlbumKey(peerId: message.id.peerId, groupingKey: $0) }
    }
    for element in batch {
        let messages: [FeedPageMessage]
        switch element {
        case .interests:
            slots.append(.interests)
            continue
        case let .message(message):
            messages = [message]
        case let .group(groupMessages):
            messages = groupMessages
        }
        // The entry this element joins: the one holding one of its messages, else one of its albums.
        var index = messages.lazy.compactMap { messageIndex[$0.id] }.first
        if index == nil {
            index = messages.lazy.compactMap { albumKey($0).flatMap { albumIndex[$0] } }.first
        }
        let newMessages = messages.filter { messageIndex[$0.id] == nil }
        if newMessages.isEmpty {
            continue
        }
        let target: Int
        if let index {
            target = index
        } else {
            target = groups.count
            slots.append(.group(target))
            groups.append((messages.lazy.compactMap(\.groupingKey).first, []))
        }
        for message in newMessages {
            if messageIndex[message.id] == nil {
                messageIndex[message.id] = target
                groups[target].messages.append(message)
            }
            if let key = albumKey(message), albumIndex[key] == nil {
                albumIndex[key] = target
            }
        }
        if groups[target].groupingKey == nil {
            groups[target].groupingKey = newMessages.lazy.compactMap(\.groupingKey).first
        }
    }
    return slots.map { slot -> EngineForYouItem in
        switch slot {
        case .interests:
            return .interests
        case let .group(index):
            return .post(makeFeedEntry(messages: groups[index].messages, groupingKey: groups[index].groupingKey))
        }
    }
}

/// Groups one page of messages into entries, keeping the order of each entry's first message.
func groupFeedMessages(_ messages: [FeedPageMessage]) -> [EngineFeedEntry] {
    return forYouItems(from: messages.map(ForYouBatchElement.message)).compactMap { item -> EngineFeedEntry? in
        if case let .post(entry) = item {
            return entry
        } else {
            return nil
        }
    }
}

private func feedEntriesOverlap(_ lhs: EngineFeedEntry, _ rhs: EngineFeedEntry) -> Bool {
    if let groupingKey = lhs.groupingKey, groupingKey == rhs.groupingKey, lhs.peerId == rhs.peerId {
        return true
    }
    return !Set(lhs.messageIds).isDisjoint(with: rhs.messageIds)
}

private func unionFeedEntries(_ lhs: EngineFeedEntry, _ rhs: EngineFeedEntry) -> EngineFeedEntry {
    return EngineFeedEntry(
        position: max(lhs.position, rhs.position),
        messageIds: Array(Set(lhs.messageIds).union(rhs.messageIds)).sorted(),
        groupingKey: lhs.groupingKey ?? rhs.groupingKey
    )
}

/// Merges a fetched page into the window. Entries that share a message id, or belong to one album (an
/// album can straddle two pages), become one entry. The result is newest first.
func mergeFeedEntries(_ existing: [EngineFeedEntry], _ page: [EngineFeedEntry]) -> [EngineFeedEntry] {
    var result = existing
    for entry in page {
        if let index = result.firstIndex(where: { feedEntriesOverlap($0, entry) }) {
            result[index] = unionFeedEntries(result[index], entry)
        } else {
            result.append(entry)
        }
    }
    return result.sorted(by: { $0.position > $1.position })
}

/// The read mark only moves forward: `candidate` when it is newer than `current`, otherwise nil.
func advancedFeedReadPosition(current: EngineFeedPosition?, candidate: EngineFeedPosition) -> EngineFeedPosition? {
    if let current, candidate <= current {
        return nil
    }
    return candidate
}

enum AddedFeedRevalidation: Equatable {
    case none
    /// The window is empty, so there is no top entry to page newer from: load the first page again.
    case reloadInitial
    case loadNewer
}

/// What `AddedFeedContext.revalidate()` does (the screen appears, the app comes to the foreground). Nothing while
/// the first page is loading; when newer posts are already known the pill offers them.
func addedFeedRevalidation(hasEntries: Bool, isLoadingInitial: Bool, hasNewer: Bool) -> AddedFeedRevalidation {
    if isLoadingInitial {
        return .none
    }
    if !hasEntries {
        return .reloadInitial
    }
    return hasNewer ? .none : .loadNewer
}

private func mergingForYouBatch(into list: [EngineForYouItem], batch: [EngineForYouItem], atTop: Bool) -> [EngineForYouItem] {
    var kept = list
    var knownIds = Set<MessageId>()
    var albumIndex: [FeedAlbumKey: Int] = [:]
    for (index, item) in kept.enumerated() {
        if case let .post(entry) = item {
            knownIds.formUnion(entry.messageIds)
            if let groupingKey = entry.groupingKey {
                albumIndex[FeedAlbumKey(peerId: entry.peerId, groupingKey: groupingKey)] = index
            }
        }
    }
    var added: [EngineForYouItem] = []
    var batchHasInterests = false
    for item in batch {
        switch item {
        case .interests:
            if !batchHasInterests {
                batchHasInterests = true
                added.append(.interests)
            }
        case let .post(entry):
            // A batch counts items, not albums, so an album can straddle two batches: its messages join the
            // entry already in the list. Two entries for one album would share one row identity, which the
            // list rejects.
            if let groupingKey = entry.groupingKey, let index = albumIndex[FeedAlbumKey(peerId: entry.peerId, groupingKey: groupingKey)], case let .post(existing) = kept[index] {
                kept[index] = .post(unionFeedEntries(existing, entry))
                knownIds.formUnion(entry.messageIds)
                continue
            }
            if knownIds.isDisjoint(with: entry.messageIds) {
                knownIds.formUnion(entry.messageIds)
                added.append(item)
            }
        }
    }
    if atTop && kept.contains(.interests) {
        // A refresh never moves the interests block: it stays where it was, below the posts it sat among, and the
        // batch's marker is dropped.
        added.removeAll(where: { $0 == .interests })
    } else if batchHasInterests {
        // Only the newest interests block stays.
        kept.removeAll(where: { $0 == .interests })
    }
    // A feed without a block takes the refresh batch's, but never between the new posts (they show as one run): it
    // moves to just after them. One above them splits nothing and stays; a load-more keeps the server's placement.
    if atTop, let marker = added.firstIndex(of: .interests), let firstPost = added.firstIndex(where: { $0 != .interests }), let lastPost = added.lastIndex(where: { $0 != .interests }), marker > firstPost, marker < lastPost {
        added.remove(at: marker)
        added.insert(.interests, at: lastPost)
    }
    return atTop ? (added + kept) : (kept + added)
}

/// Appends a `loadMore()` batch: known posts are skipped, and a block in the batch replaces the old one.
func appendingForYouBatch(_ list: [EngineForYouItem], _ batch: [EngineForYouItem]) -> [EngineForYouItem] {
    return mergingForYouBatch(into: list, batch: batch, atTop: false)
}

/// Puts a `refresh()` batch on top, with the same rules as `appendingForYouBatch`.
func prependingForYouBatch(_ list: [EngineForYouItem], _ batch: [EngineForYouItem]) -> [EngineForYouItem] {
    return mergingForYouBatch(into: list, batch: batch, atTop: true)
}

func forYouPostCount(_ items: [EngineForYouItem]) -> Int {
    var count = 0
    for item in items {
        if case .post = item {
            count += 1
        }
    }
    return count
}

/// The `feed.getForYou` limit for the next batch: a feed without posts opens with a larger one.
func forYouBatchLimit(for items: [EngineForYouItem]) -> Int32 {
    return forYouPostCount(items) == 0 ? 100 : 40
}

/// What is persisted: the top `maxItems` items, so a relaunch shows the same posts.
func forYouSnapshotItems(_ list: [EngineForYouItem], maxItems: Int) -> [EngineForYouItem] {
    return Array(list.prefix(maxItems))
}

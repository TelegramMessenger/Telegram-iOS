import Foundation
import Postbox

/// The kinds of entry in the feed's one cache collection (`Namespaces.CachedItemCollection.feed`): the first
/// byte of every key.
private enum FeedCacheKind: UInt8 {
    case addedFeed = 0
    case forYouFeed = 1
    case interestCategories = 2
    case readState = 3
}

private func feedCacheEntryId(_ kind: FeedCacheKind, filterId: Int32? = nil) -> ItemCacheEntryId {
    let key = ValueBoxKey(length: filterId == nil ? 1 : 5)
    key.setUInt8(0, value: kind.rawValue)
    if let filterId {
        key.setInt32(1, value: filterId)
    }
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.feed, key: key)
}

func addedFeedCacheEntryId(filterId: Int32) -> ItemCacheEntryId {
    return feedCacheEntryId(.addedFeed, filterId: filterId)
}

func feedReadStateEntryId(filterId: Int32) -> ItemCacheEntryId {
    return feedCacheEntryId(.readState, filterId: filterId)
}

func forYouFeedCacheEntryId() -> ItemCacheEntryId {
    return feedCacheEntryId(.forYouFeed)
}

func feedInterestCategoriesEntryId() -> ItemCacheEntryId {
    return feedCacheEntryId(.interestCategories)
}

struct CachedAddedFeed: Codable, Equatable {
    var entries: [EngineFeedEntry]
    var readMaxPosition: EngineFeedPosition?
}

struct CachedForYouFeed: Codable, Equatable {
    var items: [EngineForYouItem]
}

/// The read mark of one feed, written by this session's reads and by `updateReadFeed` from other sessions.
struct FeedReadState: Codable, Equatable {
    var maxPosition: EngineFeedPosition
}

/// The state to store after a read mark arrives, or nil to keep the current one (it never moves back).
func updatedFeedReadState(current: FeedReadState?, maxPosition: EngineFeedPosition) -> FeedReadState? {
    guard let advanced = advancedFeedReadPosition(current: current?.maxPosition, candidate: maxPosition) else {
        return nil
    }
    return FeedReadState(maxPosition: advanced)
}

func applyFeedReadState(transaction: Transaction, filterId: Int32, maxPosition: EngineFeedPosition) {
    let entryId = feedReadStateEntryId(filterId: filterId)
    let current = transaction.retrieveItemCacheEntry(id: entryId)?.get(FeedReadState.self)
    if let updated = updatedFeedReadState(current: current, maxPosition: maxPosition), let entry = CodableEntry(updated) {
        transaction.putItemCacheEntry(id: entryId, entry: entry)
    }
}

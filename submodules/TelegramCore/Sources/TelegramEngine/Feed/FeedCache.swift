import Foundation
import Postbox

private func feedFilterCacheKey(filterId: Int32) -> ValueBoxKey {
    let key = ValueBoxKey(length: 4)
    key.setInt32(0, value: filterId)
    return key
}

func addedFeedCacheEntryId(filterId: Int32) -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedAddedFeed, key: feedFilterCacheKey(filterId: filterId))
}

func feedReadStateEntryId(filterId: Int32) -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.feedReadState, key: feedFilterCacheKey(filterId: filterId))
}

func forYouFeedCacheEntryId() -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedForYouFeed, key: ValueBoxKey(length: 0))
}

func feedInterestCategoriesEntryId() -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedFeedInterestCategories, key: ValueBoxKey(length: 0))
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

import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
internal import TelegramApi

func _internal_refreshFeedInterestCategories(account: Account) -> Signal<Never, NoError> {
#if TELEGRAM_NEWS_FEED_API
    return account.network.request(Api.functions.feed.getInterestCategories(hash: 0))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.feed.InterestCategories?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        guard let result, let categories = parseInterestCategories(result) else {
            Logger.shared.log("ForYouFeed", "getInterestCategories: \(result == nil ? "failed" : "not modified")")
            return .complete()
        }
        Logger.shared.log("ForYouFeed", "getInterestCategories: \(categories.categories.count) categories, selected \(categories.selectedIds)")
        return account.postbox.transaction { transaction -> Void in
            if let entry = CodableEntry(categories) {
                transaction.putItemCacheEntry(id: feedInterestCategoriesEntryId(), entry: entry)
            }
        }
        |> ignoreValues
    }
#else
    // The feed API is parked (layer 232): nothing to refresh.
    return .complete()
#endif
}

/// The cached categories (nil before the first fetch), refreshed from the server on subscription.
func _internal_feedInterestCategories(account: Account) -> Signal<EngineInterestCategories?, NoError> {
    let key = PostboxViewKey.cachedItem(feedInterestCategoriesEntryId())
    let cached = account.postbox.combinedView(keys: [key])
    |> map { views -> EngineInterestCategories? in
        return (views.views[key] as? CachedItemView)?.value?.get(EngineInterestCategories.self)
    }
    |> distinctUntilChanged
    let refresh = _internal_refreshFeedInterestCategories(account: account)
    return Signal { subscriber in
        let cachedDisposable = cached.start(next: { value in
            subscriber.putNext(value)
        })
        let refreshDisposable = refresh.start()
        return ActionDisposable {
            cachedDisposable.dispose()
            refreshDisposable.dispose()
        }
    }
}

/// Replaces the selection: optimistically in the cache, then on the server; reverts on failure.
func _internal_setFeedInterestCategories(account: Account, ids: [Int32]) -> Signal<Never, NoError> {
#if TELEGRAM_NEWS_FEED_API
    let entryId = feedInterestCategoriesEntryId()
    return account.postbox.transaction { transaction -> [Int32]? in
        guard var current = transaction.retrieveItemCacheEntry(id: entryId)?.get(EngineInterestCategories.self) else {
            return nil
        }
        let previous = current.selectedIds
        current.selectedIds = ids
        if let entry = CodableEntry(current) {
            transaction.putItemCacheEntry(id: entryId, entry: entry)
        }
        return previous
    }
    |> mapToSignal { previous -> Signal<Never, NoError> in
        return account.network.request(Api.functions.feed.setInterestCategories(categoryIds: ids))
        |> ignoreValues
        |> `catch` { error -> Signal<Never, NoError> in
            if error.errorDescription == "CATEGORY_ID_INVALID" {
                return _internal_refreshFeedInterestCategories(account: account)
            }
            guard let previous else {
                return .complete()
            }
            return account.postbox.transaction { transaction -> Void in
                guard var current = transaction.retrieveItemCacheEntry(id: entryId)?.get(EngineInterestCategories.self), current.selectedIds == ids else {
                    return
                }
                current.selectedIds = previous
                if let entry = CodableEntry(current) {
                    transaction.putItemCacheEntry(id: entryId, entry: entry)
                }
            }
            |> ignoreValues
        }
    }
#else
    // The feed API is parked (layer 232): the selection is not changed.
    return .complete()
#endif
}

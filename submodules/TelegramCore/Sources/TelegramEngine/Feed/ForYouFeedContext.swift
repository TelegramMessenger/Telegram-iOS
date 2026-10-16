import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

private let forYouSnapshotLimit = 300

/// One `feed.getForYou` batch, stored and turned into items in server order. nil on a network error.
private func fetchForYouBatch(account: Account, limit: Int32) -> Signal<[EngineForYouItem]?, NoError> {
#if TELEGRAM_NEWS_FEED_API
    return account.network.request(Api.functions.feed.getForYou(flags: 0, query: nil, limit: limit))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.feed.ForYouFeed?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<[EngineForYouItem]?, NoError> in
        guard let result else {
            return .single(nil)
        }
        let parsed = parseForYouFeed(result)
        return account.postbox.transaction { transaction -> [EngineForYouItem]? in
            let apiMessages = parsed.elements.flatMap { element -> [Api.Message] in
                switch element {
                case let .message(message):
                    return [message]
                case let .messageGroup(messages):
                    return messages
                case .interests:
                    return []
                }
            }
            let stored = storeFeedMessages(transaction: transaction, accountPeerId: account.peerId, messages: apiMessages, chats: parsed.chats, users: parsed.users)
            Logger.shared.log("ForYouFeed", "getForYou(limit: \(limit)): \(parsed.elements.count) items (\(apiMessages.count) messages), \(parsed.chats.count) chats, \(parsed.users.count) users; stored \(stored.count)")
            var storedById: [MessageId: FeedPageMessage] = [:]
            for message in stored {
                storedById[message.id] = message
            }
            return forYouItems(from: forYouBatchElements(parsed.elements, storedById: storedById))
        }
    }
#else
    // The feed API is parked (layer 232): an empty batch, nothing sent.
    return .single([])
#endif
}

private final class ForYouFeedContextImpl {
    private let queue: Queue
    private let account: Account

    private var state = ForYouFeedContext.State(items: [], isLoadingMore: false, isRefreshing: false, isExhausted: false, hasError: false, didLoadSnapshot: false)
    private let statePromise = Promise<ForYouFeedContext.State>()

    private let cacheDisposable = MetaDisposable()
    private let loadMoreDisposable = MetaDisposable()
    private let refreshDisposable = MetaDisposable()

    var stateSignal: Signal<ForYouFeedContext.State, NoError> {
        return self.statePromise.get()
    }

    init(queue: Queue, account: Account) {
        self.queue = queue
        self.account = account
        self.pushState()

        let entryId = forYouFeedCacheEntryId()
        self.cacheDisposable.set((account.postbox.transaction { transaction -> CachedForYouFeed? in
            return transaction.retrieveItemCacheEntry(id: entryId)?.get(CachedForYouFeed.self)
        }
        |> deliverOn(queue)).start(next: { [weak self] cached in
            guard let self else {
                return
            }
            self.state.items = cached?.items ?? []
            self.state.didLoadSnapshot = true
            self.pushState()
            if self.state.items.isEmpty {
                self.loadMore()
            }
        }))
    }

    deinit {
        self.cacheDisposable.dispose()
        self.loadMoreDisposable.dispose()
        self.refreshDisposable.dispose()
    }

    private func pushState() {
        self.statePromise.set(.single(self.state))
    }

    func loadMore() {
        guard self.state.didLoadSnapshot, !self.state.isLoadingMore, !self.state.isRefreshing, !self.state.isExhausted else {
            return
        }
        self.state.isLoadingMore = true
        self.state.hasError = false
        self.pushState()
        self.loadMoreDisposable.set((fetchForYouBatch(account: self.account, limit: forYouBatchLimit(for: self.state.items))
        |> deliverOn(self.queue)).start(next: { [weak self] batch in
            guard let self else {
                return
            }
            self.state.isLoadingMore = false
            guard let batch else {
                self.state.hasError = true
                self.pushState()
                return
            }
            let updated = appendingForYouBatch(self.state.items, batch)
            if forYouPostCount(updated) == forYouPostCount(self.state.items) {
                self.state.isExhausted = true
            }
            self.state.items = updated
            self.pushState()
            self.persist()
        }))
    }

    func refresh() {
        guard self.state.didLoadSnapshot, !self.state.isRefreshing else {
            return
        }
        // A load-more in flight is left to land and append: the server never returns a batch again, so
        // cancelling it would lose those posts. Only new load-mores wait for the refresh.
        self.state.isRefreshing = true
        self.state.hasError = false
        self.pushState()
        self.refreshDisposable.set((fetchForYouBatch(account: self.account, limit: forYouBatchLimit(for: self.state.items))
        |> deliverOn(self.queue)).start(next: { [weak self] batch in
            guard let self else {
                return
            }
            self.state.isRefreshing = false
            guard let batch else {
                self.pushState()
                return
            }
            self.state.items = prependingForYouBatch(self.state.items, batch)
            self.state.isExhausted = false
            self.pushState()
            self.persist()
        }))
    }

    private func persist() {
        let cached = CachedForYouFeed(items: forYouSnapshotItems(self.state.items, maxItems: forYouSnapshotLimit))
        let entryId = forYouFeedCacheEntryId()
        let _ = self.account.postbox.transaction({ transaction -> Void in
            if let entry = CodableEntry(cached) {
                transaction.putItemCacheEntry(id: entryId, entry: entry)
            }
        }).start()
    }
}

/// The For you feed (`feed.getForYou`). Every batch the server hands out is never returned again, so the
/// list is kept and persisted; new batches come only from `loadMore()` and `refresh()`.
public final class ForYouFeedContext {
    public struct State: Equatable {
        public var items: [EngineForYouItem]
        public var isLoadingMore: Bool
        public var isRefreshing: Bool
        /// The last batch added no posts; cleared by `refresh()`.
        public var isExhausted: Bool
        public var hasError: Bool
        public var didLoadSnapshot: Bool
    }

    private let queue: Queue = .mainQueue()
    private let impl: QueueLocalObject<ForYouFeedContextImpl>

    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.stateSignal.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }

    init(account: Account) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ForYouFeedContextImpl(queue: queue, account: account)
        })
    }

    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }

    public func refresh() {
        self.impl.with { impl in
            impl.refresh()
        }
    }
}

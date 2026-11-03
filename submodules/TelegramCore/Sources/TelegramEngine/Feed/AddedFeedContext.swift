import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
internal import TelegramApi

private let addedFeedPageLimit: Int32 = 40
/// The first page, around the read mark, is larger so the feed opens with plenty to scroll.
private let addedFeedInitialPageLimit: Int32 = 100
private let addedFeedSnapshotLimit = 200

private struct AddedFeedPage {
    let entries: [EngineFeedEntry]
    let readMaxPosition: EngineFeedPosition?
}

/// One `feed.getFeed` page, stored and grouped (newest first). nil on a network error.
private func fetchAddedFeedPage(account: Account, filterId: Int32, offsetToMaxRead: Bool, offsetPosition: EngineFeedPosition?, addOffset: Int32, limit: Int32) -> Signal<AddedFeedPage?, NoError> {
#if TELEGRAM_NEWS_FEED_API
    var flags: Int32 = 0
    if offsetPosition != nil {
        flags |= 1 << 0
    }
    if offsetToMaxRead {
        flags |= 1 << 3
    }
    return account.network.request(Api.functions.feed.getFeed(flags: flags, filterId: filterId, offsetPosition: offsetPosition?.apiPosition, addOffset: addOffset, limit: limit, maxPosition: nil, minPosition: nil, hash: 0))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.feed.FeedMessages?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<AddedFeedPage?, NoError> in
        guard let result else {
            return .single(nil)
        }
        switch parseFeedMessages(result) {
        case .notModified:
            return .single(AddedFeedPage(entries: [], readMaxPosition: nil))
        case let .page(page):
            return account.postbox.transaction { transaction -> AddedFeedPage? in
                let stored = storeFeedMessages(transaction: transaction, accountPeerId: account.peerId, messages: page.messages, chats: page.chats, users: page.users)
                let entries = groupFeedMessages(stored).sorted(by: { $0.position > $1.position })
                return AddedFeedPage(entries: entries, readMaxPosition: page.readMaxPosition)
            }
        }
    }
#else
    // The feed API is parked (layer 232): an empty page with no read mark, nothing sent.
    return .single(AddedFeedPage(entries: [], readMaxPosition: nil))
#endif
}

private final class AddedFeedContextImpl {
    private let queue: Queue
    private let account: Account
    private let filterId: Int32

    private var state: AddedFeedContext.State
    private let statePromise = Promise<AddedFeedContext.State>()

    private let cacheDisposable = MetaDisposable()
    private let initialDisposable = MetaDisposable()
    private let newestDisposable = MetaDisposable()
    private let newerDisposable = MetaDisposable()
    private let olderDisposable = MetaDisposable()
    private let readStateDisposable = MetaDisposable()
    // A set, not a MetaDisposable: a newer read must not cancel one in flight, or the per-channel read
    // updates that request's Updates carry are lost.
    private let readRequestDisposables = DisposableSet()
    private var readTimer: SwiftSignalKit.Timer?
    private var pendingReadPosition: EngineFeedPosition?

    var stateSignal: Signal<AddedFeedContext.State, NoError> {
        return self.statePromise.get()
    }

    init(queue: Queue, account: Account, filterId: Int32) {
        self.queue = queue
        self.account = account
        self.filterId = filterId
        self.state = AddedFeedContext.State(entries: [], hasNewer: false, hasOlder: true, readMaxPosition: nil, newestKnownPosition: nil, isLoadingInitial: true, isLoadingNewer: false, isLoadingOlder: false, hasError: false, windowGeneration: 0, windowAnchor: .readMark, windowReadMarkPosition: nil)
        self.pushState()

        let cacheEntryId = addedFeedCacheEntryId(filterId: filterId)
        self.cacheDisposable.set((account.postbox.transaction { transaction -> CachedAddedFeed? in
            return transaction.retrieveItemCacheEntry(id: cacheEntryId)?.get(CachedAddedFeed.self)
        }
        |> deliverOn(queue)).start(next: { [weak self] cached in
            guard let self else {
                return
            }
            if let cached, self.state.entries.isEmpty {
                self.state.entries = cached.entries
                self.state.readMaxPosition = cached.readMaxPosition
                self.state.windowGeneration += 1
                self.state.windowAnchor = .readMark
                self.state.windowReadMarkPosition = cached.readMaxPosition
                self.pushState()
            }
            self.loadInitial()
        }))

        let readStateKey = PostboxViewKey.cachedItem(feedReadStateEntryId(filterId: filterId))
        self.readStateDisposable.set((account.postbox.combinedView(keys: [readStateKey])
        |> deliverOn(queue)).start(next: { [weak self] views in
            guard let self, let readState = (views.views[readStateKey] as? CachedItemView)?.value?.get(FeedReadState.self) else {
                return
            }
            if let advanced = advancedFeedReadPosition(current: self.state.readMaxPosition, candidate: readState.maxPosition) {
                self.state.readMaxPosition = advanced
                self.pushState()
            }
        }))
    }

    deinit {
        self.cacheDisposable.dispose()
        self.initialDisposable.dispose()
        self.newestDisposable.dispose()
        self.newerDisposable.dispose()
        self.olderDisposable.dispose()
        self.readStateDisposable.dispose()
        self.readRequestDisposables.dispose()
        self.readTimer?.invalidate()
    }

    private func pushState() {
        self.statePromise.set(.single(self.state))
    }

    private func computeHasNewer() -> Bool {
        guard let top = self.state.entries.first?.position else {
            return false
        }
        // Unknown until the limit-1 probe returns; saying "newer" before then would flash the pill on
        // every open. The probe's completion re-evaluates this.
        guard let newest = self.state.newestKnownPosition else {
            return false
        }
        return top < newest
    }

    private func noteNewest(_ position: EngineFeedPosition?) {
        guard let position else {
            return
        }
        if let current = self.state.newestKnownPosition, position <= current {
            return
        }
        self.state.newestKnownPosition = position
    }

    func loadInitial() {
        self.state.isLoadingInitial = true
        self.state.hasError = false
        self.pushState()
        let limit = addedFeedInitialPageLimit
        self.initialDisposable.set((fetchAddedFeedPage(account: self.account, filterId: self.filterId, offsetToMaxRead: true, offsetPosition: nil, addOffset: -limit / 2, limit: limit)
        |> deliverOn(self.queue)).start(next: { [weak self] page in
            guard let self else {
                return
            }
            self.state.isLoadingInitial = false
            guard let page else {
                self.state.hasError = true
                self.pushState()
                return
            }
            self.newerDisposable.set(nil)
            self.olderDisposable.set(nil)
            self.state.isLoadingNewer = false
            self.state.isLoadingOlder = false
            self.state.entries = page.entries
            // The server's mark, not the local one: reading the snapshot may have advanced it already, and
            // the separator must not jump past the posts just read.
            self.state.windowReadMarkPosition = page.readMaxPosition ?? self.state.readMaxPosition
            if let readMaxPosition = page.readMaxPosition, let advanced = advancedFeedReadPosition(current: self.state.readMaxPosition, candidate: readMaxPosition) {
                self.state.readMaxPosition = advanced
            }
            self.state.hasOlder = !page.entries.isEmpty
            self.state.hasNewer = self.computeHasNewer()
            self.state.windowGeneration += 1
            self.state.windowAnchor = .readMark
            self.pushState()
            self.persist()
        }))
        self.refreshNewestKnown()
    }

    private func refreshNewestKnown() {
        self.newestDisposable.set((fetchAddedFeedPage(account: self.account, filterId: self.filterId, offsetToMaxRead: false, offsetPosition: nil, addOffset: 0, limit: 1)
        |> deliverOn(self.queue)).start(next: { [weak self] page in
            guard let self, let page else {
                return
            }
            self.noteNewest(page.entries.first?.position)
            self.state.hasNewer = self.computeHasNewer()
            self.pushState()
        }))
    }

    func loadNewer(force: Bool) {
        guard !self.state.isLoadingInitial, !self.state.isLoadingNewer, force || self.state.hasNewer, let top = self.state.entries.first?.position else {
            return
        }
        self.state.isLoadingNewer = true
        self.pushState()
        let limit = addedFeedPageLimit
        self.newerDisposable.set((fetchAddedFeedPage(account: self.account, filterId: self.filterId, offsetToMaxRead: false, offsetPosition: top, addOffset: -limit, limit: limit)
        |> deliverOn(self.queue)).start(next: { [weak self] page in
            guard let self else {
                return
            }
            self.state.isLoadingNewer = false
            guard let page else {
                self.pushState()
                return
            }
            let previousCount = self.state.entries.count
            self.state.entries = mergeFeedEntries(self.state.entries, page.entries)
            self.noteNewest(self.state.entries.first?.position)
            self.state.hasNewer = self.state.entries.count > previousCount && self.computeHasNewer()
            self.pushState()
            self.persist()
        }))
    }

    func loadOlder() {
        guard !self.state.isLoadingInitial, !self.state.isLoadingOlder, self.state.hasOlder, let bottom = self.state.entries.last?.position else {
            return
        }
        self.state.isLoadingOlder = true
        self.pushState()
        self.olderDisposable.set((fetchAddedFeedPage(account: self.account, filterId: self.filterId, offsetToMaxRead: false, offsetPosition: bottom, addOffset: 0, limit: addedFeedPageLimit)
        |> deliverOn(self.queue)).start(next: { [weak self] page in
            guard let self else {
                return
            }
            self.state.isLoadingOlder = false
            guard let page else {
                self.pushState()
                return
            }
            let previousCount = self.state.entries.count
            self.state.entries = mergeFeedEntries(self.state.entries, page.entries)
            self.state.hasOlder = self.state.entries.count > previousCount
            self.pushState()
            self.persist()
        }))
    }

    func jumpToNewest() {
        self.newerDisposable.set(nil)
        self.olderDisposable.set(nil)
        self.state.isLoadingOlder = false
        self.state.isLoadingNewer = true
        self.pushState()
        self.newerDisposable.set((fetchAddedFeedPage(account: self.account, filterId: self.filterId, offsetToMaxRead: false, offsetPosition: nil, addOffset: 0, limit: addedFeedPageLimit)
        |> deliverOn(self.queue)).start(next: { [weak self] page in
            guard let self else {
                return
            }
            self.state.isLoadingNewer = false
            guard let page else {
                self.pushState()
                return
            }
            self.state.entries = page.entries
            self.noteNewest(page.entries.first?.position)
            self.state.hasNewer = false
            self.state.hasOlder = !page.entries.isEmpty
            self.state.windowGeneration += 1
            self.state.windowAnchor = .top
            self.state.windowReadMarkPosition = nil
            self.pushState()
            self.persist()
        }))
    }

    func revalidate() {
        switch addedFeedRevalidation(hasEntries: !self.state.entries.isEmpty, isLoadingInitial: self.state.isLoadingInitial, hasNewer: self.state.hasNewer) {
        case .none:
            if !self.state.isLoadingInitial {
                self.refreshNewestKnown()
            }
        case .reloadInitial:
            // Probes for the newest itself.
            self.loadInitial()
        case .loadNewer:
            self.refreshNewestKnown()
            self.loadNewer(force: true)
        }
    }

    func markRead(upTo position: EngineFeedPosition) {
        guard let advanced = advancedFeedReadPosition(current: self.state.readMaxPosition, candidate: position) else {
            return
        }
        self.state.readMaxPosition = advanced
        self.pushState()
        self.pendingReadPosition = advanced
        if self.readTimer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: false, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.readTimer = nil
                self.commitRead()
            }, queue: self.queue)
            self.readTimer = timer
            timer.start()
        }
    }

    func markAllRead() {
        if let position = self.state.newestKnownPosition ?? self.state.entries.first?.position {
            self.markRead(upTo: position)
        }
    }

    private func commitRead() {
        guard let position = self.pendingReadPosition else {
            return
        }
        self.pendingReadPosition = nil
        let account = self.account
        let filterId = self.filterId
        let applyLocally = account.postbox.transaction { transaction -> Void in
            applyFeedReadState(transaction: transaction, filterId: filterId, maxPosition: position)
        }
#if TELEGRAM_NEWS_FEED_API
        self.readRequestDisposables.add((applyLocally
        |> mapToSignal { _ -> Signal<Api.Updates?, NoError> in
            return account.network.request(Api.functions.feed.readFeed(filterId: filterId, maxPosition: position.apiPosition))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
        }).start(next: { updates in
            if let updates {
                account.stateManager.addUpdates(updates)
            }
        }))
#else
        // The feed API is parked (layer 232): the read mark stays local.
        self.readRequestDisposables.add(applyLocally.start())
#endif
        self.persist()
    }

    private func persist() {
        let cached = CachedAddedFeed(entries: Array(self.state.entries.prefix(addedFeedSnapshotLimit)), readMaxPosition: self.state.readMaxPosition)
        let entryId = addedFeedCacheEntryId(filterId: self.filterId)
        let _ = self.account.postbox.transaction({ transaction -> Void in
            if let entry = CodableEntry(cached) {
                transaction.putItemCacheEntry(id: entryId, entry: entry)
            }
        }).start()
    }
}

/// The Added feed (`feed.getFeed`) for one filter: a window of entries around the read mark.
public final class AddedFeedContext {
    public enum WindowAnchor: Equatable {
        /// Position the list at the read mark.
        case readMark
        /// Position the list at the newest post.
        case top
    }

    public struct State: Equatable {
        /// Newest first.
        public var entries: [EngineFeedEntry]
        /// Newer posts exist above the window.
        public var hasNewer: Bool
        public var hasOlder: Bool
        public var readMaxPosition: EngineFeedPosition?
        public var newestKnownPosition: EngineFeedPosition?
        public var isLoadingInitial: Bool
        public var isLoadingNewer: Bool
        public var isLoadingOlder: Bool
        /// The first page failed; `reload()` retries.
        public var hasError: Bool
        /// Increments whenever the window is replaced wholesale (snapshot, first page, jump to newest).
        public var windowGeneration: Int
        public var windowAnchor: WindowAnchor
        /// The read mark the current window opened with (nil after a jump to the newest): the list opens
        /// there, and it stays put while reading.
        public var windowReadMarkPosition: EngineFeedPosition?
    }

    private let queue: Queue = .mainQueue()
    private let impl: QueueLocalObject<AddedFeedContextImpl>

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

    init(account: Account, filterId: Int32) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return AddedFeedContextImpl(queue: queue, account: account, filterId: filterId)
        })
    }

    /// `force`: load even when the window is believed to reach the newest post (a pull to refresh).
    public func loadNewer(force: Bool = false) {
        self.impl.with { impl in
            impl.loadNewer(force: force)
        }
    }

    public func loadOlder() {
        self.impl.with { impl in
            impl.loadOlder()
        }
    }

    public func jumpToNewest() {
        self.impl.with { impl in
            impl.jumpToNewest()
        }
    }

    /// On tab appear and app foreground: re-checks the newest post and loads newer posts when at the top.
    public func revalidate() {
        self.impl.with { impl in
            impl.revalidate()
        }
    }

    public func reload() {
        self.impl.with { impl in
            impl.loadInitial()
        }
    }

    public func markRead(upTo position: EngineFeedPosition) {
        self.impl.with { impl in
            impl.markRead(upTo: position)
        }
    }

    public func markAllRead() {
        self.impl.with { impl in
            impl.markAllRead()
        }
    }
}

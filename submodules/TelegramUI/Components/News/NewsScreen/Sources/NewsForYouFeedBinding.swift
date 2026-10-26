import Foundation
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import CoreListComponentHost
import NewsFeedSupport
import NewsFeedComponents

/// The For you feed's state, resolved messages and interest selection, and the rows they make.
final class NewsForYouFeedBinding {
    private let context: AccountContext
    let feed: ForYouFeedContext
    private(set) var state: ForYouFeedContext.State?
    private var messages: [EngineMessage.Id: EngineMessage] = [:]
    private var interests: EngineInterestCategories?
    /// The local selection while the 1 s autosave is pending or in flight.
    private var pendingSelection: [Int32]?
    private var saveTimer: SwiftSignalKit.Timer?
    private var stateDisposable: Disposable?
    private var interestsDisposable: Disposable?
    private let saveDisposable = MetaDisposable()
    private var reload = NewsReloadTracker()
    /// A pull to refresh in flight: the posts the feed held when it began, and whether its refresh was seen running.
    private var pullRefresh: (knownKeys: Set<AnyHashable>, sawRefreshing: Bool)?
    /// Posts a pull brought: marked fresh when the drop lands (spec §1.5).
    private var heldBack = Set<AnyHashable>()
    /// While a pull runs and until its result is shown: the feed as it was when the pull began. The rows show it, so
    /// nothing the refresh changes (its posts, or the interests marker the merge moves) shows early.
    private var holdingSnapshot: [EngineForYouItem]?
    /// The last reveal: its posts and time, until `NewsFreshBlock.lifetime` later.
    private var freshReveal: (keys: Set<AnyHashable>, time: Double)?
    var onPullRefreshEnded: ((NewsRefreshOutcome) -> Void)?

    var updated: (() -> Void)?

    init(context: AccountContext) {
        self.context = context
        self.feed = context.engine.feed.forYouFeedContext()
        let engine = context.engine
        let state = self.feed.state
        let ids = state
        |> map { state -> [EngineMessage.Id] in
            return newsForYouMessageIds(state.items)
        }
        self.stateDisposable = (combineLatest(state, newsFeedMessages(engine: engine, ids: ids))
        |> deliverOnMainQueue).start(next: { [weak self] state, loaded in
            guard let self else {
                return
            }
            // A new batch first arrives with the previous items' messages: wait for its own, so its posts and its
            // interests block appear together.
            guard newsForYouIsResolved(items: state.items, loadedIds: loaded.ids) else {
                return
            }
            let _ = self.reload.observe(isLoading: state.isRefreshing)
            self.state = state
            self.messages = loaded.messages
            if var pull = self.pullRefresh {
                if state.isRefreshing {
                    pull.sawRefreshing = true
                    self.pullRefresh = pull
                } else if pull.sawRefreshing {
                    // Past the resolve guard above: the new posts' messages are loaded, so they can be shown.
                    self.pullRefresh = nil
                    let fresh = newsForYouFreshPostKeys(knownKeys: pull.knownKeys, items: state.items)
                    self.heldBack = Set(fresh)
                    self.onPullRefreshEnded?(fresh.isEmpty ? .nothing : .posts(fresh.count))
                }
            }
            self.updated?()
        })
        self.interestsDisposable = (engine.feed.interestCategories()
        |> deliverOnMainQueue).start(next: { [weak self] interests in
            guard let self else {
                return
            }
            self.interests = interests
            self.updated?()
        })
    }

    deinit {
        self.stateDisposable?.dispose()
        self.interestsDisposable?.dispose()
        self.saveDisposable.dispose()
        self.saveTimer?.invalidate()
    }

    private var selectedInterestIds: Set<Int32> {
        return Set(self.pendingSelection ?? self.interests?.selectedIds ?? [])
    }

    func toggleInterest(_ id: Int32) {
        var selection = self.selectedInterestIds
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
        let ordered = (self.interests?.categories.map(\.id) ?? []).filter { selection.contains($0) }
        self.pendingSelection = ordered
        self.updated?()

        self.saveTimer?.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
            guard let self, let selection = self.pendingSelection else {
                return
            }
            self.saveTimer = nil
            self.saveDisposable.set((self.context.engine.feed.setInterestCategories(ids: selection)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                guard let self else {
                    return
                }
                if self.pendingSelection == selection {
                    self.pendingSelection = nil
                    self.updated?()
                    // The server now recommends by the new selection; an empty feed has nothing to lose.
                    if let state = self.state, !state.items.contains(where: { if case .post = $0 { return true } else { return false } }) {
                        self.feed.refresh()
                    }
                }
            }))
        }, queue: Queue.mainQueue())
        self.saveTimer = timer
        timer.start()
    }

    /// Reload Feed: the list gives way to the skeleton until a new batch lands (or the request fails). The server never
    /// returns a batch twice, so the list is kept and the batch prepended, as a pull does.
    func reloadFeed() {
        guard let state = self.state, state.didLoadSnapshot else {
            return
        }
        let token = self.reload.begin(isLoading: state.isRefreshing)
        self.feed.refresh()
        self.updated?()
        // Offline the request waits for the connection instead of failing: give the rows back meanwhile (a late
        // batch still lands on top).
        Queue.mainQueue().after(NewsReloadTracker.timeout, { [weak self] in
            guard let self, self.reload.expire(token: token) else {
                return
            }
            self.updated?()
        })
    }

    /// The posts the feed holds, for the search.
    var searchCorpus: NewsSearchCorpus {
        guard let state = self.state else {
            return NewsSearchCorpus()
        }
        var entries: [EngineFeedEntry] = []
        for item in state.items {
            if case let .post(entry) = item {
                entries.append(entry)
            }
        }
        return NewsSearchCorpus(entries: entries, messages: self.messages)
    }

    /// The feed's posts in order, with their channels, for the "Post hidden" flow.
    var feedbackPosts: [(post: AnyHashable, channel: EnginePeer.Id)] {
        guard let state = self.state else {
            return []
        }
        var result: [(post: AnyHashable, channel: EnginePeer.Id)] = []
        for item in state.items {
            if case let .post(entry) = item {
                result.append((newsPostIdentity(entry), entry.peerId))
            }
        }
        return result
    }

    /// The rows, or none while the first load is under way (`isLoading`): the list's skeleton stands in then.
    func beginPullRefresh() {
        guard let state = self.state else {
            self.onPullRefreshEnded?(.nothing)
            return
        }
        let knownKeys = newsForYouPostKeys(state.items)
        self.pullRefresh = (knownKeys, state.isRefreshing)
        self.holdingSnapshot = state.items
        self.feed.refresh()
    }

    /// The refresh's result may be shown: its posts become rows, marked fresh. A later reveal replaces these marks.
    func revealPullRefresh(now: Double) {
        self.holdingSnapshot = nil
        guard !self.heldBack.isEmpty else {
            return
        }
        self.freshReveal = (self.heldBack, now)
        self.heldBack = []
        Queue.mainQueue().after(NewsFreshBlock.lifetime, { [weak self] in
            guard let self, self.freshReveal?.time == now else {
                return
            }
            self.freshReveal = nil
            self.updated?()
        })
    }

    func items(environment: NewsFeedItemEnvironment) -> (items: [CoreListComponentItem], isLoading: Bool, hasPosts: Bool) {
        let presentationData = environment.presentationData
        let theme = presentationData.theme
        guard let state = self.state else {
            return ([], true, false)
        }
        if self.reload.isActive {
            return ([], true, false)
        }
        let available = Set(self.messages.keys)
        var result: [CoreListComponentItem] = []
        // CoreList rejects a repeated identity with a precondition failure; never hand it one.
        var usedIdentities = Set<AnyHashable>()
        var hasPosts = false
        enum Row {
            case post(EngineFeedEntry)
            case interests
        }
        var rows: [Row] = []
        for item in newsForYouItemsShowingInterests(self.holdingSnapshot.map { newsForYouHeldItems(snapshot: $0, current: state.items) } ?? state.items) {
            switch item {
            case let .post(entry):
                if let resolved = newsResolvedEntries([entry], availableMessageIds: available).first, environment.feedback?.isShown(resolved) ?? true {
                    rows.append(.post(resolved))
                }
            case .interests:
                rows.append(.interests)
            }
        }
        let freshKeys = self.freshReveal?.keys ?? []
        let segments = newsFreshSegments(isFresh: rows.map { row in
            if case let .post(entry) = row {
                return freshKeys.contains(newsPostIdentity(entry)) && !(environment.feedback?.hasPanel(entry) ?? false)
            }
            return false
        }, revealTime: self.freshReveal?.time ?? 0.0)
        for (index, row) in rows.enumerated() {
            switch row {
            case let .post(entry):
                if let postItem = newsPostItem(entry: entry, messages: self.messages, environment: environment, fresh: segments[index]), usedIdentities.insert(postItem.identity).inserted {
                    result.append(postItem)
                    hasPosts = true
                }
            case .interests:
                guard let interests = self.interests, !interests.categories.isEmpty, usedIdentities.insert(AnyHashable("interests")).inserted else {
                    continue
                }
                result.append(CoreListComponentItem(identity: AnyHashable("interests"), component: AnyComponent(NewsInterestsBlockComponent(
                    context: environment.context,
                    theme: theme,
                    icon: "📰",
                    title: presentationData.strings.News_Interests_Title,
                    categories: interests.categories,
                    selectedIds: self.selectedInterestIds,
                    toggle: { [weak self] id in
                        self?.toggleInterest(id)
                    }
                ))))
            }
        }
        // Without posts, `result` holds only the interests block, which stays above the status row.
        switch newsForYouListStatus(hasPosts: hasPosts, didLoadSnapshot: state.didLoadSnapshot, isLoadingMore: state.isLoadingMore, isExhausted: state.isExhausted, hasError: state.hasError) {
        case .placeholders:
            return ([], true, false)
        case .error:
            result.append(newsStatusItem(theme: theme, text: presentationData.strings.News_Error_Text, actionTitle: presentationData.strings.News_Error_Retry, action: { [weak self] in
                self?.feed.loadMore()
            }))
        case .empty:
            result.append(newsStatusItem(theme: theme, text: presentationData.strings.News_Empty_ForYou, actionTitle: presentationData.strings.News_Refresh, action: { [weak self] in
                self?.feed.refresh()
            }))
        case .loadingMore:
            result.append(contentsOf: newsPlaceholderItems(count: 1, theme: theme, rowLayout: environment.skeletonRowLayout, identityPrefix: "foryou-more"))
        case .loadMoreFailed:
            result.append(newsStatusItem(theme: theme, text: presentationData.strings.News_Error_Text, actionTitle: presentationData.strings.News_Error_Retry, action: { [weak self] in
                self?.feed.loadMore()
            }))
        case .none:
            break
        }
        return (result, false, hasPosts)
    }
}

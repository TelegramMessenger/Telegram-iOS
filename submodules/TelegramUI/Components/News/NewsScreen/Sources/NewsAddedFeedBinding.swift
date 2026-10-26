import Foundation
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import CoreListComponentHost
import NewsFeedSupport
import NewsFeedComponents

/// The Added feed's state and resolved messages, and the rows they make.
final class NewsAddedFeedBinding {
    struct Rows {
        var items: [CoreListComponentItem]
        /// Item index → the post's position, for read tracking and the pill.
        var positions: [Int: EngineFeedPosition]
        /// Item index of the oldest unread post.
        var firstUnreadItemIndex: Int?
        /// The first load is under way and there are no rows: the list's skeleton stands in.
        var isLoading: Bool = false
        /// A post or a "Post hidden" panel is among the rows (a panel has no read position).
        var hasPostRows: Bool = false
    }

    let feed: AddedFeedContext
    private(set) var state: AddedFeedContext.State?
    private var messages: [EngineMessage.Id: EngineMessage] = [:]
    /// The read mark when the current window opened: the list opens there, and it stays put while reading.
    private var readMarkPosition: EngineFeedPosition?
    private var appliedGeneration = -1
    private var isReloading = false
    private var reloadGeneration = 0
    private var stateDisposable: Disposable?
    /// A pull to refresh in flight: the window's top when it began, and its request.
    private var pullRefresh: (top: EngineFeedPosition, request: NewsAddedPullRequest)?
    /// Posts a pull brought, kept out of the rows until the drop lands (spec §1.5).
    private var heldBack = Set<AnyHashable>()
    /// The last reveal: its posts and time, until `NewsFreshBlock.lifetime` later.
    private var freshReveal: (keys: Set<AnyHashable>, time: Double)?
    var onPullRefreshEnded: ((NewsRefreshOutcome) -> Void)?

    /// `windowReplaced` is true when the window was replaced wholesale and the list must be repositioned.
    var updated: ((_ windowReplaced: Bool) -> Void)?

    init(context: AccountContext) {
        self.feed = context.engine.feed.addedFeedContext(filterId: 0)
        let engine = context.engine
        let state = self.feed.state
        let ids = state
        |> map { state -> [EngineMessage.Id] in
            return state.entries.flatMap(\.messageIds)
        }
        self.stateDisposable = (combineLatest(state, newsFeedMessages(engine: engine, ids: ids))
        |> deliverOnMainQueue).start(next: { [weak self] state, loaded in
            guard let self else {
                return
            }
            self.state = state
            self.messages = loaded.messages
            if var pull = self.pullRefresh {
                let ended = pull.request.observe(isLoadingNewer: state.isLoadingNewer, isLoadingInitial: state.isLoadingInitial)
                self.pullRefresh = pull
                if ended && newsWindowIsResolved(entries: state.entries, loadedIds: loaded.ids) {
                    self.pullRefresh = nil
                    let fresh = newsAddedFreshPostKeys(entries: state.entries, above: pull.top)
                    self.heldBack = Set(fresh)
                    self.onPullRefreshEnded?(fresh.isEmpty ? .nothing : .posts(fresh.count))
                }
            }
            // A replaced window is applied (and the list repositioned) once its own messages have loaded.
            let windowReplaced = state.windowGeneration != self.appliedGeneration && newsWindowIsResolved(entries: state.entries, loadedIds: loaded.ids)
            if windowReplaced {
                self.appliedGeneration = state.windowGeneration
                self.readMarkPosition = state.windowReadMarkPosition
            }
            // A reload ends once its page has replaced the window (with its own messages) or has failed.
            if self.isReloading && !state.isLoadingInitial && (windowReplaced || state.hasError) {
                self.isReloading = false
            }
            self.updated?(windowReplaced)
        })
    }

    deinit {
        self.stateDisposable?.dispose()
    }

    /// Reload Feed: the skeleton stands in until the first page replaces the window; the list then opens where Added
    /// always opens, at the read mark (spec §11.1).
    func reloadFeed() {
        guard self.state != nil else {
            return
        }
        self.isReloading = true
        self.reloadGeneration += 1
        let generation = self.reloadGeneration
        self.feed.reload()
        self.updated?(false)
        // Offline the request waits for the connection instead of failing: give the rows back meanwhile.
        Queue.mainQueue().after(NewsReloadTracker.timeout, { [weak self] in
            guard let self, self.isReloading, self.reloadGeneration == generation else {
                return
            }
            self.isReloading = false
            self.updated?(false)
        })
    }

    /// The posts the window holds, for the search.
    var searchCorpus: NewsSearchCorpus {
        guard let state = self.state else {
            return NewsSearchCorpus()
        }
        return NewsSearchCorpus(entries: state.entries, messages: self.messages)
    }

    func beginPullRefresh() {
        guard let state = self.state, let top = state.entries.first?.position else {
            self.onPullRefreshEnded?(.nothing)
            return
        }
        self.pullRefresh = (top, NewsAddedPullRequest(isLoadingNewer: state.isLoadingNewer, isLoadingInitial: state.isLoadingInitial))
        self.feed.loadNewer(force: true)
    }

    /// The refresh's result may be shown: the held-back posts become rows, marked fresh. A later reveal replaces these
    /// marks.
    func revealPullRefresh(now: Double) {
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
            self.updated?(false)
        })
    }

    /// The feed's posts in order, with their channels, for the "Post hidden" flow.
    var feedbackPosts: [(post: AnyHashable, channel: EnginePeer.Id)] {
        return (self.state?.entries ?? []).map { (newsPostIdentity($0), $0.peerId) }
    }

    func rows(environment: NewsFeedItemEnvironment) -> Rows {
        let presentationData = environment.presentationData
        let theme = presentationData.theme
        guard let state = self.state else {
            return Rows(items: [], positions: [:], firstUnreadItemIndex: nil, isLoading: true)
        }
        if self.isReloading {
            return Rows(items: [], positions: [:], firstUnreadItemIndex: nil, isLoading: true)
        }
        let entries = newsResolvedEntries(state.entries, availableMessageIds: Set(self.messages.keys)).filter { !self.heldBack.contains(newsPostIdentity($0)) && (environment.feedback?.isShown($0) ?? true) }
        if entries.isEmpty {
            if state.isLoadingInitial {
                return Rows(items: [], positions: [:], firstUnreadItemIndex: nil, isLoading: true)
            }
            if state.hasError {
                return Rows(items: [newsStatusItem(theme: theme, text: presentationData.strings.News_Error_Text, actionTitle: presentationData.strings.News_Error_Retry, action: { [weak self] in
                    self?.feed.reload()
                })], positions: [:], firstUnreadItemIndex: nil)
            }
            return Rows(items: [newsStatusItem(theme: theme, text: presentationData.strings.News_Empty_Added, actionTitle: nil, action: nil)], positions: [:], firstUnreadItemIndex: nil)
        }

        let firstUnreadEntryIndex = newsAddedFirstUnreadIndex(entries: entries, readMarkPosition: self.readMarkPosition)
        var items: [CoreListComponentItem] = []
        var positions: [Int: EngineFeedPosition] = [:]
        var firstUnreadItemIndex: Int?
        // CoreList rejects a repeated identity with a precondition failure; never hand it one.
        var usedIdentities = Set<AnyHashable>()
        let freshKeys = self.freshReveal?.keys ?? []
        let segments = newsFreshSegments(isFresh: entries.map { freshKeys.contains(newsPostIdentity($0)) && !(environment.feedback?.hasPanel($0) ?? false) }, revealTime: self.freshReveal?.time ?? 0.0)
        for (entryIndex, entry) in entries.enumerated() {
            if let item = newsPostItem(entry: entry, messages: self.messages, environment: environment, fresh: segments[entryIndex]), usedIdentities.insert(item.identity).inserted {
                if entryIndex == firstUnreadEntryIndex {
                    firstUnreadItemIndex = items.count
                }
                // A panel row is no post: it carries no read position.
                if environment.feedback?.state.hasPanel(newsPostIdentity(entry)) != true {
                    positions[items.count] = entry.position
                }
                items.append(item)
            }
        }
        return Rows(items: items, positions: positions, firstUnreadItemIndex: firstUnreadItemIndex, hasPostRows: !items.isEmpty)
    }
}

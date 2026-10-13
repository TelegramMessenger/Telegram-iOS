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

    var updated: (() -> Void)?

    init(context: AccountContext) {
        self.context = context
        self.feed = context.engine.feed.forYouFeedContext()
        let engine = context.engine
        let state = self.feed.state
        let ids = state
        |> map { state -> [EngineMessage.Id] in
            var ids: [EngineMessage.Id] = []
            for item in state.items {
                if case let .post(entry) = item {
                    ids.append(contentsOf: entry.messageIds)
                }
            }
            return ids
        }
        self.stateDisposable = (combineLatest(state, newsFeedMessages(engine: engine, ids: ids))
        |> deliverOnMainQueue).start(next: { [weak self] state, messages in
            guard let self else {
                return
            }
            self.state = state
            self.messages = messages
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

    func items(environment: NewsFeedItemEnvironment) -> [CoreListComponentItem] {
        let presentationData = environment.presentationData
        let theme = presentationData.theme
        guard let state = self.state else {
            return newsPlaceholderItems(count: 4, theme: theme, identityPrefix: "foryou")
        }
        let available = Set(self.messages.keys)
        var result: [CoreListComponentItem] = []
        // CoreList rejects a repeated identity with a precondition failure; never hand it one.
        var usedIdentities = Set<AnyHashable>()
        var hasPosts = false
        for item in newsForYouItemsShowingInterests(state.items) {
            switch item {
            case let .post(entry):
                if let resolved = newsResolvedEntries([entry], availableMessageIds: available).first, let postItem = newsPostItem(entry: resolved, messages: self.messages, environment: environment), usedIdentities.insert(postItem.identity).inserted {
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
                    title: "📰 " + presentationData.strings.News_Interests_Title,
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
            return newsPlaceholderItems(count: 4, theme: theme, identityPrefix: "foryou")
        case .error:
            result.append(newsStatusItem(theme: theme, text: presentationData.strings.News_Error_Text, actionTitle: presentationData.strings.News_Error_Retry, action: { [weak self] in
                self?.feed.loadMore()
            }))
        case .empty:
            result.append(newsStatusItem(theme: theme, text: presentationData.strings.News_Empty_ForYou, actionTitle: presentationData.strings.News_Refresh, action: { [weak self] in
                self?.feed.refresh()
            }))
        case .loadingMore:
            result.append(contentsOf: newsPlaceholderItems(count: 1, theme: theme, identityPrefix: "foryou-more"))
        case .loadMoreFailed:
            result.append(newsStatusItem(theme: theme, text: presentationData.strings.News_Error_Text, actionTitle: presentationData.strings.News_Error_Retry, action: { [weak self] in
                self?.feed.loadMore()
            }))
        case .none:
            break
        }
        return result
    }
}

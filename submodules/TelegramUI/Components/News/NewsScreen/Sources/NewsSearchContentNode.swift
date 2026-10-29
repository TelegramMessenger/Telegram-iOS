import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import SearchUI
import CoreList
import CoreListComponentHost
import NewsFeedSupport

/// How many posts one search asks for. `feed.getForYou` has no offset, so this is the whole result.
private let newsSearchLimit: Int32 = 50
/// Typing pauses this long before the query goes to the server.
private let newsSearchDelay: Double = 0.3

/// News search: the server's For you search (`feed.getForYou` with a query), one page per query, as feed rows.
final class NewsSearchContentNode: SearchDisplayControllerContentNode {
    private enum Results {
        case posts(entries: [EngineFeedEntry], messages: [EngineMessage.Id: EngineMessage])
        case failed
    }

    private let context: AccountContext
    private var presentationData: PresentationData
    private let itemEnvironment: (NewsFeedListView) -> NewsFeedItemEnvironment?
    private let listView = NewsFeedListView()

    private var query = ""
    /// The last answer, for the query it was for: shown until the next query's answer arrives.
    private var results: (query: String, results: Results)?
    private let searchDisposable = MetaDisposable()
    private let isSearchingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat)?

    override var isSearching: Signal<Bool, NoError> {
        return self.isSearchingPromise.get()
    }

    init(context: AccountContext, presentationData: PresentationData, itemEnvironment: @escaping (NewsFeedListView) -> NewsFeedItemEnvironment?) {
        self.context = context
        self.presentationData = presentationData
        self.itemEnvironment = itemEnvironment

        super.init()

        self.listView.reduceMotion = presentationData.reduceMotion
        self.view.addSubview(self.listView)
        self.listView.onWillBeginDragging = { [weak self] in
            self?.dismissInput?()
        }
    }

    deinit {
        self.searchDisposable.dispose()
    }

    override func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.listView.reduceMotion = presentationData.reduceMotion
        self.updateResults(scrollToTop: false)
    }

    override func searchTextUpdated(text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != self.query else {
            return
        }
        self.query = query
        self.search()
    }

    private func search() {
        let query = self.query
        if query.isEmpty {
            self.searchDisposable.set(nil)
            self.isSearchingPromise.set(false)
            self.results = nil
            self.updateResults(scrollToTop: false)
            return
        }
        self.isSearchingPromise.set(true)
        let engine = self.context.engine
        // The delay comes before the request, so a query replaced while typing is never sent.
        let signal: Signal<Results, NoError> = (Signal<[EngineFeedEntry]?, NoError>.complete()
        |> delay(newsSearchDelay, queue: .mainQueue())
        |> then(engine.feed.searchForYouPosts(query: query, limit: newsSearchLimit)))
        |> mapToSignal { entries -> Signal<Results, NoError> in
            guard let entries else {
                return .single(.failed)
            }
            if entries.isEmpty {
                return .single(.posts(entries: [], messages: [:]))
            }
            // Kept live, so a post edited or deleted meanwhile updates its row.
            return newsFeedMessages(engine: engine, ids: .single(entries.flatMap(\.messageIds)))
            |> map { loaded -> Results in
                return .posts(entries: entries, messages: loaded.messages)
            }
        }
        self.searchDisposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] results in
            guard let self, self.query == query else {
                return
            }
            let isNewQuery = self.results?.query != query
            self.results = (query, results)
            self.isSearchingPromise.set(false)
            self.updateResults(scrollToTop: isNewQuery)
        }))
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        self.validLayout = (layout, navigationBarHeight)
        transition.updateFrame(view: self.listView, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.updateResults(scrollToTop: false, transition: CoreListTransition(transition))
    }

    override func scrollToTop() {
        self.listView.scrollToTop()
    }

    /// Show more on one of the results: the rows are laid out again on `transition`, the window first widened by the
    /// post's growth so the rows under it slide down (`NewsFeedListView.prepareHeightChange`).
    func textExpansionChanged(identity: AnyHashable, expands: Bool, transition: CoreListTransition) {
        if expands, let growth = self.listView.postRow(identity: identity)?.textExpansionGrowth {
            self.listView.prepareHeightChange(travel: growth, preloadsRows: false, duration: transition.duration)
        }
        self.updateResults(scrollToTop: false, transition: transition)
    }

    private func updateResults(scrollToTop: Bool, transition: CoreListTransition = .immediate) {
        guard let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        let insets = UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right)
        let theme = self.presentationData.theme
        let strings = self.presentationData.strings

        var items: [CoreListComponentItem] = []
        if !self.query.isEmpty, let (_, results) = self.results {
            switch results {
            case let .posts(entries, messages):
                if let environment = self.itemEnvironment(self.listView) {
                    // CoreList rejects a repeated identity with a precondition failure; never hand it one.
                    var usedIdentities = Set<AnyHashable>()
                    for entry in newsResolvedEntries(entries, availableMessageIds: Set(messages.keys)) {
                        if let item = newsPostItem(entry: entry, messages: messages, environment: environment), usedIdentities.insert(item.identity).inserted {
                            items.append(item)
                        }
                    }
                }
                if items.isEmpty {
                    items.append(newsStatusItem(theme: theme, text: strings.ChatList_Search_NoResults, actionTitle: nil, action: nil))
                }
            case .failed:
                items.append(newsStatusItem(theme: theme, text: strings.News_Error_Text, actionTitle: strings.News_Error_Retry, action: { [weak self] in
                    self?.search()
                }))
            }
        }
        let scrollTo = scrollToTop && !items.isEmpty ? CoreListScrollTarget(index: 0, pointOffset: 0.0) : nil
        self.listView.update(size: layout.size, insets: insets, items: items, scrollTo: scrollTo, anchorMode: .automatic, transition: transition)
    }
}

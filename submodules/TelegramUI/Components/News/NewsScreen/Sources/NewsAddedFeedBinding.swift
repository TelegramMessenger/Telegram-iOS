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
    }

    let feed: AddedFeedContext
    private(set) var state: AddedFeedContext.State?
    private var messages: [EngineMessage.Id: EngineMessage] = [:]
    /// The read mark when the current window opened: the list opens there, and it stays put while reading.
    private var readMarkPosition: EngineFeedPosition?
    private var appliedGeneration = -1
    private var stateDisposable: Disposable?

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
        |> deliverOnMainQueue).start(next: { [weak self] state, messages in
            guard let self else {
                return
            }
            self.state = state
            self.messages = messages
            let windowReplaced = state.windowGeneration != self.appliedGeneration
            if windowReplaced {
                self.appliedGeneration = state.windowGeneration
                self.readMarkPosition = state.windowReadMarkPosition
            }
            self.updated?(windowReplaced)
        })
    }

    deinit {
        self.stateDisposable?.dispose()
    }

    func rows(environment: NewsFeedItemEnvironment) -> Rows {
        let presentationData = environment.presentationData
        let theme = presentationData.theme
        guard let state = self.state else {
            return Rows(items: newsPlaceholderItems(count: 4, theme: theme, identityPrefix: "added"), positions: [:], firstUnreadItemIndex: nil)
        }
        let entries = newsResolvedEntries(state.entries, availableMessageIds: Set(self.messages.keys))
        if entries.isEmpty {
            if state.isLoadingInitial {
                return Rows(items: newsPlaceholderItems(count: 4, theme: theme, identityPrefix: "added"), positions: [:], firstUnreadItemIndex: nil)
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
        for (entryIndex, entry) in entries.enumerated() {
            if let item = newsPostItem(entry: entry, messages: self.messages, environment: environment), usedIdentities.insert(item.identity).inserted {
                if entryIndex == firstUnreadEntryIndex {
                    firstUnreadItemIndex = items.count
                }
                positions[items.count] = entry.position
                items.append(item)
            }
        }
        return Rows(items: items, positions: positions, firstUnreadItemIndex: firstUnreadItemIndex)
    }
}

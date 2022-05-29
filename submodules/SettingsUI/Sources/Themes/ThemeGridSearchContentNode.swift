import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import WebSearchUI
import SearchBarNode

enum WallpaperSearchColor: CaseIterable {
    case blue
    case red
    case orange
    case yellow
    case green
    case teal
    case purple
    case pink
    case brown
    case black
    case gray
    case white
    
    var string: String {
        switch self {
            case .blue:
                return "Blue"
            case .red:
                return "Red"
            case .orange:
                return "Orange"
            case .yellow:
                return "Yellow"
            case .green:
                return "Green"
            case .teal:
                return "Teal"
            case .purple:
                return "Purple"
            case .pink:
                return "Pink"
            case .brown:
                return "Brown"
            case .black:
                return "Black"
            case .gray:
                return "Gray"
            case .white:
                return "White"
        }
    }
    
    var displayColor: UIColor {
        switch self {
            case .blue:
                return UIColor(rgb: 0x0076ff)
            case .red:
                return UIColor(rgb: 0xff0000)
            case .orange:
                return UIColor(rgb: 0xff8a00)
            case .yellow:
                return UIColor(rgb: 0xffca00)
            case .green:
                return UIColor(rgb: 0x00e432)
            case .teal:
                return UIColor(rgb: 0x1fa9ab)
            case .purple:
                return UIColor(rgb: 0x7300aa)
            case .pink:
                return UIColor(rgb: 0xf9bec5)
            case .brown:
                return UIColor(rgb: 0x734021)
            case .black:
                return UIColor(rgb: 0x000000)
            case .gray:
                return UIColor(rgb: 0x5c585f)
            case .white:
                return UIColor(rgb: 0xffffff)
        }
    }
    
    func localizedString(strings: PresentationStrings) -> String {
        switch self {
            case .blue:
                return strings.WallpaperSearch_ColorBlue
            case .red:
                return strings.WallpaperSearch_ColorRed
            case .orange:
                return strings.WallpaperSearch_ColorOrange
            case .yellow:
                return strings.WallpaperSearch_ColorYellow
            case .green:
                return strings.WallpaperSearch_ColorGreen
            case .teal:
                return strings.WallpaperSearch_ColorTeal
            case .purple:
                return strings.WallpaperSearch_ColorPurple
            case .pink:
                return strings.WallpaperSearch_ColorPink
            case .brown:
                return strings.WallpaperSearch_ColorBrown
            case .black:
                return strings.WallpaperSearch_ColorBlack
            case .gray:
                return strings.WallpaperSearch_ColorGray
            case .white:
                return strings.WallpaperSearch_ColorWhite
        }
    }
}

enum WallpaperSearchQuery: Equatable {
    case generic(String)
    case color(WallpaperSearchColor, String)
    
    var botQuery: String {
        switch self {
            case let .generic(query):
                return query
            case let .color(color, query):
                return "#color\(color.string) \(query)"
        }
    }
    
    var query: String {
        switch self {
            case let .generic(query), let .color(_, query):
                return query
        }
    }
    
    func updatedWithText(_ text: String) -> WallpaperSearchQuery {
        switch self {
            case .generic:
                return .generic(text)
            case let .color(color, _):
                return .color(color, text)
        }
    }
    
    func updatedWithColor(_ color: WallpaperSearchColor?) -> WallpaperSearchQuery {
        if let color = color {
            switch self {
                case let .generic(text):
                    return .color(color, text)
                case let .color(_, text):
                    return .color(color, text)
            }
        } else {
            switch self {
                case .generic:
                    return self
                case let .color(_, text):
                    return .generic(text)
            }
        }
    }
}

final class ThemeGridSearchInteraction {
    let openResult: (ChatContextResult) -> Void
    let selectColor: (WallpaperSearchColor) -> Void
    let setSearchQuery: (WallpaperSearchQuery) -> Void
    let deleteRecentQuery: (String) -> Void
    
    init(openResult: @escaping (ChatContextResult) -> Void, selectColor: @escaping (WallpaperSearchColor) -> Void, setSearchQuery: @escaping (WallpaperSearchQuery) -> Void, deleteRecentQuery: @escaping (String) -> Void) {
        self.openResult = openResult
        self.selectColor = selectColor
        self.setSearchQuery = setSearchQuery
        self.deleteRecentQuery = deleteRecentQuery
    }
}

private enum ThemeGridRecentEntryStableId: Hashable {
    case colors
    case query(String)
}

private enum ThemeGridRecentEntry: Comparable, Identifiable {
    case colors(PresentationTheme, PresentationStrings)
    case query(Int, String)
    
    var stableId: ThemeGridRecentEntryStableId {
        switch self {
            case .colors:
                return .colors
            case let .query(_, query):
                return .query(query)
        }
    }
    
    static func ==(lhs: ThemeGridRecentEntry, rhs: ThemeGridRecentEntry) -> Bool {
        switch lhs {
            case let .colors(lhsTheme, lhsStrings):
                if case let .colors(rhsTheme, rhsStrings) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .query(lhsIndex, lhsQuery):
                if case .query(lhsIndex, lhsQuery) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ThemeGridRecentEntry, rhs: ThemeGridRecentEntry) -> Bool {
        switch lhs {
            case .colors:
                return true
            case let .query(lhsIndex, _):
                switch rhs {
                    case .colors:
                        return false
                    case let .query(rhsIndex, _):
                        return lhsIndex <= rhsIndex
                }
        }
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: ThemeGridSearchInteraction, header: ListViewItemHeader) -> ListViewItem {
        switch self {
            case let .colors(theme, strings):
                return ThemeGridSearchColorsItem(account: account, theme: theme, strings: strings, colorSelected: { color in
                    interaction.selectColor(color)
                })
            case let .query(_, query):
                return WebSearchRecentQueryItem(account: account, theme: theme, strings: strings, query: query, tapped: { query in
                    interaction.setSearchQuery(.generic(query))
                }, deleted: { query in
                    interaction.deleteRecentQuery(query)
                }, header: header)
        }
    }
}

private struct ThemeGridSearchContainerRecentTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private struct ThemeGridSearchEntry: Comparable, Identifiable {
    let index: Int
    let result: ChatContextResult
    
    static func ==(lhs: ThemeGridSearchEntry, rhs: ThemeGridSearchEntry) -> Bool {
        return lhs.index == rhs.index && lhs.result == rhs.result
    }
    
    static func <(lhs: ThemeGridSearchEntry, rhs: ThemeGridSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: Int {
        return self.index
    }
    
    func item(account: Account, theme: PresentationTheme, interaction: ThemeGridSearchInteraction) -> ThemeGridSearchItem {
        return ThemeGridSearchItem(account: account, theme: theme, result: self.result, interaction: interaction)
    }
}

struct ThemeGridSearchContainerTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let displayingResults: Bool
    let isEmpty: Bool
    let query: String
}

private func themeGridSearchContainerPreparedRecentTransition(from fromEntries: [ThemeGridRecentEntry], to toEntries: [ThemeGridRecentEntry], account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: ThemeGridSearchInteraction, header: ListViewItemHeader) -> ThemeGridSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction, header: header), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction, header: header), directionHint: nil) }
    
    return ThemeGridSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates)
}

private func themeGridSearchContainerPreparedTransition(from fromEntries: [ThemeGridSearchEntry], to toEntries: [ThemeGridSearchEntry], displayingResults: Bool, account: Account, theme: PresentationTheme, isEmpty: Bool, query: String, interaction: ThemeGridSearchInteraction) -> ThemeGridSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)

    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, theme: theme, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, interaction: interaction)) }
    
    return ThemeGridSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults, isEmpty: isEmpty, query: query)
}

private struct ThemeGridSearchResult {
    let query: String
    let collection: ChatContextResultCollection
    let items: [ChatContextResult]
    let nextOffset: String?
}

private struct ThemeGridSearchContext {
    let result: ThemeGridSearchResult
    let loadMoreIndex: String?
}

final class ThemeGridSearchContentNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    
    private let recentListNode: ListView
    private let gridNode: GridNode
    private let dimNode: ASDisplayNode
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    
    private var enqueuedRecentTransitions: [(ThemeGridSearchContainerRecentTransition, Bool)] = []
    private var enqueuedTransitions: [(ThemeGridSearchContainerTransition, Bool)] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?

    private var queryValue: WallpaperSearchQuery = .generic("")
    private let queryPromise: Promise<WallpaperSearchQuery>
    private let searchDisposable = MetaDisposable()
    private var recentDisposable: Disposable?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let presentationDataPromise: Promise<PresentationData>
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    override var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
        
    init(context: AccountContext, openResult: @escaping (ChatContextResult) -> Void) {
        self.context = context
        self.queryPromise = Promise<WallpaperSearchQuery>(self.queryValue)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.dimNode = ASDisplayNode()
        self.recentListNode = ListView()
        self.recentListNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.recentListNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.gridNode = GridNode()
        
        self.emptyResultsTitleNode = ImmediateTextNode()
        self.emptyResultsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.SharedMedia_SearchNoResults, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
        self.emptyResultsTitleNode.textAlignment = .center
        self.emptyResultsTitleNode.isHidden = true
        
        self.emptyResultsTextNode = ImmediateTextNode()
        self.emptyResultsTextNode.maximumNumberOfLines = 0
        self.emptyResultsTextNode.textAlignment = .center
        self.emptyResultsTextNode.isHidden = true
        
        super.init()
        
        self.dimNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.recentListNode)
        self.addSubnode(self.gridNode)
        
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)
        
        let searchContext = Promise<ThemeGridSearchContext?>(nil)
        let searchContextValue = Atomic<ThemeGridSearchContext?>(value: nil)
        let updateSearchContext: ((ThemeGridSearchContext?) -> (ThemeGridSearchContext?, Bool)) -> Void = { f in
            var shouldUpdate = false
            let updated = searchContextValue.modify { current in
                let (u, s) = f(current)
                shouldUpdate = s
                if s {
                    return u
                } else {
                    return current
                }
            }
            if shouldUpdate {
                searchContext.set(.single(updated))
            }
        }
        
        self.gridNode.isHidden = true
        self.gridNode.visibleItemsUpdated = { visibleItems in
            if let bottom = visibleItems.bottom {
                if let context = searchContextValue.with({ $0 }), bottom.0 >= context.result.items.count - 8 {
                    updateSearchContext { previous in
                        guard let previous = previous else {
                            return (nil, false)
                        }
                        if previous.loadMoreIndex != nil {
                            return (previous, false)
                        }
                        guard let _ = previous.result.items.last else {
                            return (previous, false)
                        }
                        return (ThemeGridSearchContext(result: previous.result, loadMoreIndex: previous.result.nextOffset), true)
                    }
                }
            }
        }
        self.recentListNode.isHidden = false
        
        let previousSearchItems = Atomic<[ThemeGridSearchEntry]?>(value: nil)
        
        let interaction = ThemeGridSearchInteraction(openResult: { [weak self] result in
            openResult(result)
            if let strongSelf = self {
                strongSelf.dismissInput?()
                
                let query = strongSelf.queryValue.query
                if !query.isEmpty {
                    let _ = addRecentWallpaperSearchQuery(engine: strongSelf.context.engine, string: query).start()
                }
            }
        }, selectColor: { [weak self] color in
            self?.updateQuery({ $0.updatedWithColor(color) }, updateInterface: true)
        }, setSearchQuery: { [weak self] query in
            self?.dismissInput?()
            self?.updateQuery({ _ in
                return query
            }, updateInterface: true)
        }, deleteRecentQuery: { query in
            let _ = removeRecentWallpaperSearchQuery(engine: context.engine, string: query).start()
        })
        
        let configuration = self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
        
        let foundItems = self.queryPromise.get()
        |> mapToSignal { query -> Signal<([ThemeGridSearchEntry], Bool)?, NoError> in
            let query = query.botQuery
            guard !query.isEmpty else {
                return .single(nil)
            }
            
            let wallpaperQuery = "#wallpaper \(query)"
            updateSearchContext { _ in
                return (nil, true)
            }
            
            return .single(([], true))
            |> then(
                configuration
                |> mapToSignal { configuration -> Signal<Peer?, NoError> in
                    guard let name = configuration.imageBotUsername else {
                        return .single(nil)
                    }
                    return context.engine.peers.resolvePeerByName(name: name)
                    |> mapToSignal { peer -> Signal<Peer?, NoError> in
                        if let peer = peer {
                            return .single(peer._asPeer())
                        } else {
                            return .single(nil)
                        }
                    }
                }
                |> mapToSignal { peer -> Signal<([ThemeGridSearchEntry], Bool)?, NoError> in
                    if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                        let loadMore = searchContext.get()
                        |> mapToSignal { searchContext -> Signal<([ThemeGridSearchEntry], Bool)?, NoError> in
                            if let searchContext = searchContext {
                                if let _ = searchContext.loadMoreIndex, let nextOffset = searchContext.result.nextOffset {
                                    let collection = searchContext.result.collection
                                    let geoPoint = collection.geoPoint.flatMap { geoPoint -> (Double, Double) in
                                        return (geoPoint.latitude, geoPoint.longitude)
                                    }
                                    return self.context.engine.messages.requestChatContextResults(botId: collection.botId, peerId: collection.peerId, query: searchContext.result.query, location: .single(geoPoint), offset: nextOffset)
                                    |> map { results -> ChatContextResultCollection? in
                                        return results?.results
                                    }
                                    |> `catch` { error -> Signal<ChatContextResultCollection?, NoError> in
                                        return .single(nil)
                                    }
                                    |> map { nextResults -> (ChatContextResultCollection, String?) in
                                        var results: [ChatContextResult] = []
                                        var existingIds = Set<String>()
                                        for result in searchContext.result.items {
                                            results.append(result)
                                            existingIds.insert(result.id)
                                        }
                                        var nextOffset: String?
                                        if let nextResults = nextResults {
                                            for result in nextResults.results {
                                                if !existingIds.contains(result.id) {
                                                    results.append(result)
                                                    existingIds.insert(result.id)
                                                }
                                            }
                                            if let newNextOffset = nextResults.nextOffset, !newNextOffset.isEmpty {
                                                nextOffset = newNextOffset
                                            }
                                        }
                                        let merged = ChatContextResultCollection(botId: collection.botId, peerId: collection.peerId, query: collection.query, geoPoint: collection.geoPoint, queryId: nextResults?.queryId ?? collection.queryId, nextOffset: nextOffset ?? "", presentation: collection.presentation, switchPeer: collection.switchPeer, results: results, cacheTimeout: collection.cacheTimeout)
                                        return (merged, nextOffset)
                                    }
                                    |> mapToSignal { newCollection, nextOffset -> Signal<([ThemeGridSearchEntry], Bool)?, NoError> in
                                        updateSearchContext { previous in
                                            return (ThemeGridSearchContext(result: ThemeGridSearchResult(query: searchContext.result.query, collection: newCollection, items: newCollection.results, nextOffset: nextOffset), loadMoreIndex: nil), true)
                                        }
                                        return .complete()
                                    }
                                } else {
                                    var entries: [ThemeGridSearchEntry] = []
                                    var i = 0
                                    for result in searchContext.result.items {
                                        entries.append(ThemeGridSearchEntry(index: i, result: result))
                                        i += 1
                                    }
                                    return .single((entries, false))
                                }
                            } else {
                                return .complete()
                            }
                        }
                        
                        
                        return (.complete() |> delay(0.1, queue: Queue.concurrentDefaultQueue()))
                        |> then(
                            requestContextResults(context: context, botId: user.id, query: wallpaperQuery, peerId: context.account.peerId, limit: 16)
                            |> map { results -> ChatContextResultCollection? in
                                return results?.results
                            }
                            |> map { collection -> ([ThemeGridSearchEntry], Bool)? in
                                guard let collection = collection else {
                                    return nil
                                }
                                var entries: [ThemeGridSearchEntry] = []
                                var i = 0
                                for result in collection.results {
                                    entries.append(ThemeGridSearchEntry(index: i, result: result))
                                    i += 1
                                }
                                updateSearchContext { _ in
                                    return (ThemeGridSearchContext(result: ThemeGridSearchResult(query: wallpaperQuery, collection: collection, items: collection.results, nextOffset: collection.nextOffset), loadMoreIndex: nil), true)
                                }
                                return (entries, false)
                            }
                            |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                            |> then(loadMore)
                        )
                    } else {
                        return .single(nil)
                    }
                }
            )
        }
        
        let previousRecentItems = Atomic<[ThemeGridRecentEntry]?>(value: nil)
        self.recentDisposable = (combineLatest(wallpaperSearchRecentQueries(engine: self.context.engine), self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] queries, presentationData in
            if let strongSelf = self {
                var entries: [ThemeGridRecentEntry] = []
                
                entries.append(.colors(presentationData.theme, presentationData.strings))
                for i in 0 ..< queries.count {
                    entries.append(.query(i, queries[i]))
                }
                
                let header = ChatListSearchItemHeader(type: .recentPeers, theme: presentationData.theme, strings: presentationData.strings, actionTitle: presentationData.strings.WebSearch_RecentSectionClear, action: {
                    let _ = clearRecentWallpaperSearchQueries(engine: strongSelf.context.engine).start()
                })
                
                let previousEntries = previousRecentItems.swap(entries)
                let transition = themeGridSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries, account: context.account, theme: presentationData.theme, strings: presentationData.strings, interaction: interaction, header: header)
                strongSelf.enqueueRecentTransition(transition, firstTime: previousEntries == nil)
            }
        })
        
        self.searchDisposable.set((combineLatest(foundItems, self.presentationDataPromise.get(), self.queryPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] entriesAndFlags, presentationData, query in
            if let strongSelf = self {
                strongSelf._isSearching.set(entriesAndFlags?.1 ?? false)
                
                let previousEntries = previousSearchItems.swap(entriesAndFlags?.0)
                
                var isEmpty = false
                if let entriesAndFlags = entriesAndFlags {
                    isEmpty = entriesAndFlags.0.isEmpty && !entriesAndFlags.1
                }
                
                let firstTime = previousEntries == nil
                let transition = themeGridSearchContainerPreparedTransition(from: previousEntries ?? [], to: entriesAndFlags?.0 ?? [], displayingResults: entriesAndFlags?.0 != nil, account: context.account, theme: presentationData.theme, isEmpty: isEmpty, query: query.query, interaction: interaction)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
            
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(presentationData))
                
                if previousTheme !== presentationData.theme {
                    strongSelf.updateTheme(theme: presentationData.theme)
                }
            }
        })
        
        self.recentListNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
        
        self.gridNode.scrollingInitiated = { [weak self] in
            self?.dismissInput?()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.recentDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateTheme(theme: PresentationTheme) {
        self.backgroundColor = theme.chatList.backgroundColor
        self.dimNode.backgroundColor = theme.chatList.backgroundColor
        self.recentListNode.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
    }
    
    private func updateQuery(_ f: (WallpaperSearchQuery) -> (WallpaperSearchQuery), updateInterface: Bool = false) {
        let query = f(self.queryValue)
        if query != self.queryValue {
            self.queryValue = query
            self.queryPromise.set(.single(query))
            
            if updateInterface {
                let tokens: [SearchBarToken]
                let text: String
                let placeholder: String
                switch query {
                    case let .generic(query):
                        tokens = []
                        text = query
                        placeholder = self.presentationData.strings.Wallpaper_Search
                    case let .color(color, query):
                        let backgroundColor = color.displayColor
                        let foregroundColor: UIColor
                        let strokeColor: UIColor
                        if color == .white {
                            foregroundColor = .black
                            strokeColor = self.presentationData.theme.rootController.navigationSearchBar.inputClearButtonColor
                        } else {
                            foregroundColor = .white
                            strokeColor = color.displayColor
                        }
                        tokens = [SearchBarToken(id: 0, icon: UIImage(bundleImageName: "Settings/WallpaperSearchColorIcon"), title: color.localizedString(strings: self.presentationData.strings), style: SearchBarToken.Style(backgroundColor: backgroundColor, foregroundColor: foregroundColor, strokeColor: strokeColor), permanent: false)]
                        text = query
                        placeholder = self.presentationData.strings.Wallpaper_SearchShort
                }
                self.setQuery?(nil, tokens, text)
                self.setPlaceholder?(placeholder)
            }
        }
    }
    
    override func searchTextUpdated(text: String) {
        self.updateQuery({ $0.updatedWithText(text) })
    }
    
    override func searchTextClearPrefix() {
        self.updateQuery({ $0.updatedWithColor(nil) }, updateInterface: true)
    }
    
    override func searchTextClearTokens() {
        self.updateQuery({ $0.updatedWithColor(nil) }, updateInterface: true)
    }
    
    private func enqueueRecentTransition(_ transition: ThemeGridSearchContainerRecentTransition, firstTime: Bool) {
        self.enqueuedRecentTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func dequeueRecentTransition() {
        if let (transition, firstTime) = self.enqueuedRecentTransitions.first {
            self.enqueuedRecentTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
                options.insert(.PreferSynchronousDrawing)
            } else {
                options.insert(.AnimateInsertion)
            }
            
            self.recentListNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }
    
    private func enqueueTransition(_ transition: ThemeGridSearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let displayingResults = transition.displayingResults
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: nil, updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.gridNode.isHidden = !displayingResults
                    strongSelf.recentListNode.isHidden = displayingResults
                    strongSelf.dimNode.isHidden = displayingResults
                    strongSelf.backgroundColor = strongSelf.presentationData.theme.chatList.backgroundColor
                    
                    strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.WebSearch_SearchNoResultsDescription(transition.query).string, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                    
                    let emptyResults = displayingResults && transition.isEmpty
                    strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                    strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                    
                    if let (layout, navigationBarHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                    }
                }
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (layout, navigationBarHeight)
        
        let minSpacing: CGFloat = 8.0
        let referenceImageSize: CGSize
        let screenWidth = min(layout.size.width, layout.size.height)
        if screenWidth >= 390.0 {
            referenceImageSize = CGSize(width: 108.0, height: 230.0)
        } else {
            referenceImageSize = CGSize(width: 91.0, height: 161.0)
        }
        let imageCount = Int((layout.size.width - minSpacing * 2.0) / (referenceImageSize.width + minSpacing))
        let imageSize = referenceImageSize.aspectFilled(CGSize(width: floor((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - CGFloat(imageCount + 1) * minSpacing) / CGFloat(imageCount)), height: referenceImageSize.height))
        let spacing = floor((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount + 1))
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        self.recentListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.gridNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight + spacing, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), preloadSize: 300.0, type: .fixed(itemSize: imageSize, fillWidth: nil, lineSpacing: spacing, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        let padding: CGFloat = 16.0
        let emptyTitleSize = self.emptyResultsTitleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        let insets = layout.insets(options: [.input])
        let emptyTextSpacing: CGFloat = 8.0
        let emptyTotalHeight = emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
        let emptyTitleY = navigationBarHeight + floorToScreenPixels((layout.size.height - navigationBarHeight - max(insets.bottom, layout.intrinsicInsets.bottom) - emptyTotalHeight) / 2.0)
        
        transition.updateFrame(node: self.emptyResultsTitleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyTitleY), size: emptyTitleSize))
        transition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyTitleY + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
        
        if !hadValidLayout {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func clearRecentSearch() {
        let _ = (self.context.engine.peers.clearRecentlySearchedPeers() |> deliverOnMainQueue).start()
    }
    
    override func scrollToTop() {
        if !self.gridNode.isHidden {
            self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: GridNodeScrollToItem(index: 0, position: .top(0.0), transition: .animated(duration: 0.25, curve: .easeInOut), directionHint: .up, adjustForSection: true, adjustForTopInset: true), updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        } else {
            self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
}

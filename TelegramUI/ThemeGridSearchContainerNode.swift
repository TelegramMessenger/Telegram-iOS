import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

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
}

final class ThemeGridSearchInteraction {
    let openResult: (ChatContextResult) -> Void
    let selectColor: (WallpaperSearchColor) -> Void
    let setSearchQuery: (String) -> Void
    let deleteRecentQuery: (String) -> Void
    
    init(openResult: @escaping (ChatContextResult) -> Void, selectColor: @escaping (WallpaperSearchColor) -> Void, setSearchQuery: @escaping (String) -> Void, deleteRecentQuery: @escaping (String) -> Void) {
        self.openResult = openResult
        self.selectColor = selectColor
        self.setSearchQuery = setSearchQuery
        self.deleteRecentQuery = deleteRecentQuery
    }
}

private enum ThemeGridRecentEntryStableId: Hashable {
    case colors
    case query(String)
    
    static func ==(lhs: ThemeGridRecentEntryStableId, rhs: ThemeGridRecentEntryStableId) -> Bool {
        switch lhs {
            case .colors:
                if case .colors = rhs {
                    return true
                } else {
                    return false
                }
            case let .query(query):
                if case .query(query) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case .colors:
                return 0
            case let .query(query):
                return query.hashValue
        }
    }
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
                    interaction.setSearchQuery(query)
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
}

private func themeGridSearchContainerPreparedRecentTransition(from fromEntries: [ThemeGridRecentEntry], to toEntries: [ThemeGridRecentEntry], account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: ThemeGridSearchInteraction, header: ListViewItemHeader) -> ThemeGridSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction, header: header), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction, header: header), directionHint: nil) }
    
    return ThemeGridSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates)
}

private func themeGridSearchContainerPreparedTransition(from fromEntries: [ThemeGridSearchEntry], to toEntries: [ThemeGridSearchEntry], displayingResults: Bool, account: Account, theme: PresentationTheme, interaction: ThemeGridSearchInteraction) -> ThemeGridSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)

    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, theme: theme, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, interaction: interaction)) }
    
    return ThemeGridSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults)
}

private struct ThemeGridSearchContainerNodeState: Equatable {
    let peerIdWithRevealedOptions: PeerId?
    
    init(peerIdWithRevealedOptions: PeerId? = nil) {
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
    }
    
    static func ==(lhs: ThemeGridSearchContainerNodeState, rhs: ThemeGridSearchContainerNodeState) -> Bool {
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        return true
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ThemeGridSearchContainerNodeState {
        return ThemeGridSearchContainerNodeState(peerIdWithRevealedOptions: peerIdWithRevealedOptions)
    }
}

private struct ThemeGridSearchResult {
    let query: String
    let items: [ChatContextResult]
    let nextOffset: String?
}

private struct ThemeGridSearchContext {
    let result: ThemeGridSearchResult
    let loadMoreIndex: String?
}

final class ThemeGridSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    
    private let recentListNode: ListView
    private let gridNode: GridNode
    private let dimNode: ASDisplayNode
    private var enqueuedRecentTransitions: [(ThemeGridSearchContainerRecentTransition, Bool)] = []
    private var enqueuedTransitions: [(ThemeGridSearchContainerTransition, Bool)] = []
    private var validLayout: ContainerViewLayout?

    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    private var recentDisposable: Disposable?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let presentationDataPromise: Promise<PresentationData>
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    override var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    init(account: Account, openResult: @escaping (ChatContextResult) -> Void) {
        self.account = account
        self.dimNode = ASDisplayNode()
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.recentListNode = ListView()
        self.recentListNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.gridNode = GridNode()
        
        super.init()
        
        self.dimNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.recentListNode)
        self.addSubnode(self.gridNode)
        
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
//        self.listNode.visibleBottomContentOffsetChanged = { offset in
//            guard case let .known(value) = offset, value < 100.0 else {
//                return
//            }
//            updateSearchContext { previous in
//                guard let previous = previous else {
//                    return (nil, false)
//                }
//                if previous.loadMoreIndex != nil {
//                    return (previous, false)
//                }
//                guard let last = previous.result.messages.last else {
//                    return (previous, false)
//                }
//                return (ChatListSearchMessagesContext(result: previous.result, loadMoreIndex: MessageIndex(last)), true)
//            }
//        }
        self.recentListNode.isHidden = false
        
        let previousSearchItems = Atomic<[ThemeGridSearchEntry]?>(value: nil)
        
        let interaction = ThemeGridSearchInteraction(openResult: { [weak self] result in
            openResult(result)
            self?.dismissInput?()
        }, selectColor: { [weak self] color in
            self?.setQuery?("#color\(color.string) ")
        }, setSearchQuery: { [weak self] query in
            self?.setQuery?(query)
        }, deleteRecentQuery: { query in
            let _ = removeRecentWallpaperSearchQuery(postbox: account.postbox, string: query).start()
        })
        
        let configuration = self.account.postbox.transaction { transaction -> SearchBotsConfiguration in
            return currentSearchBotsConfiguration(transaction: transaction)
        }
        
        let foundItems = self.searchQuery.get()
        |> mapToSignal { query -> Signal<([ThemeGridSearchEntry], Bool)?, NoError> in
            guard let query = query, !query.isEmpty else {
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
                    return resolvePeerByName(account: account, name: name)
                    |> mapToSignal { peerId -> Signal<Peer?, NoError> in
                        if let peerId = peerId {
                            return account.postbox.loadedPeerWithId(peerId)
                            |> map { peer -> Peer? in
                                return peer
                            }
                            |> take(1)
                        } else {
                            return .single(nil)
                        }
                    }
                }
                |> mapToSignal { peer -> Signal<([ThemeGridSearchEntry], Bool)?, NoError> in
                    if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                        return (.complete() |> delay(0.1, queue: Queue.concurrentDefaultQueue()))
                        |> then(
                            requestContextResults(account: account, botId: user.id, query: wallpaperQuery, peerId: account.peerId, limit: 16)
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
                                    return (ThemeGridSearchContext(result: ThemeGridSearchResult(query: query, items: collection.results, nextOffset: collection.nextOffset), loadMoreIndex: nil), true)
                                }
                                return (entries, false)
                            }
                        )
                    } else {
                        return .single(nil)
                    }
                }
            )
        }
        
        let previousRecentItems = Atomic<[ThemeGridRecentEntry]?>(value: nil)
        self.recentDisposable = (combineLatest(wallpaperSearchRecentQueries(postbox: self.account.postbox), self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] queries, presentationData in
            if let strongSelf = self {
                var entries: [ThemeGridRecentEntry] = []
                
                entries.append(.colors(presentationData.theme, presentationData.strings))
                for i in 0 ..< queries.count {
                    entries.append(.query(i, queries[i]))
                }
                
                let header = ChatListSearchItemHeader(type: .recentPeers, theme: presentationData.theme, strings: presentationData.strings, actionTitle: presentationData.strings.WebSearch_RecentSectionClear.uppercased(), action: {
                    _ = clearRecentWallpaperSearchQueries(postbox: strongSelf.account.postbox).start()
                })
                
                let previousEntries = previousRecentItems.swap(entries)
                let transition = themeGridSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries, account: account, theme: presentationData.theme, strings: presentationData.strings, interaction: interaction, header: header)
                strongSelf.enqueueRecentTransition(transition, firstTime: previousEntries == nil)
            }
        })
        
        self.searchDisposable.set((combineLatest(foundItems, self.presentationDataPromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] entriesAndFlags, presentationData in
            if let strongSelf = self {
                strongSelf._isSearching.set(entriesAndFlags?.1 ?? false)
                
                let previousEntries = previousSearchItems.swap(entriesAndFlags?.0)
                
                let firstTime = previousEntries == nil
                let transition = themeGridSearchContainerPreparedTransition(from: previousEntries ?? [], to: entriesAndFlags?.0 ?? [], displayingResults: entriesAndFlags?.0 != nil, account: account, theme: presentationData.theme, interaction: interaction)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                //let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(presentationData))
                
                if previousTheme !== presentationData.theme {
                    strongSelf.updateTheme(theme: presentationData.theme)
                }
            }
        })
        
        self.recentListNode.beganInteractiveDragging = { [weak self] in
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
    
//    private func updateState(_ f: (ChatListSearchContainerNodeState) -> ChatListSearchContainerNodeState) {
//        let state = f(self.stateValue)
//        if state != self.stateValue {
//            self.stateValue = state
//            self.statePromise.set(state)
//        }
//    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
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
                }
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.validLayout != nil
        self.validLayout = layout
        
        let minSpacing: CGFloat = 8.0
        let referenceImageSize: CGSize
        let screenWidth = min(layout.size.width, layout.size.height)
        if screenWidth >= 375.0 {
            referenceImageSize = CGSize(width: 108.0, height: 230.0)
        } else {
            referenceImageSize = CGSize(width: 91.0, height: 161.0)
        }
        let imageCount = Int((layout.size.width - minSpacing * 2.0) / (referenceImageSize.width + minSpacing))
        let imageSize = referenceImageSize.aspectFilled(CGSize(width: floor((layout.size.width - CGFloat(imageCount + 1) * minSpacing) / CGFloat(imageCount)), height: referenceImageSize.height))
        let spacing = floor((layout.size.width - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount + 1))
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: duration)
        }
        
        self.recentListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.gridNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight + spacing, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), preloadSize: 300.0, type: .fixed(itemSize: imageSize, fillWidth: nil, lineSpacing: spacing, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
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
        let _ = (clearRecentlySearchedPeers(postbox: self.account.postbox) |> deliverOnMainQueue).start()
    }
    
    override func scrollToTop() {
        if !self.gridNode.isHidden {
            self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: GridNodeScrollToItem(index: 0, position: .top, transition: .animated(duration: 0.25, curve: .easeInOut), directionHint: .up, adjustForSection: true, adjustForTopInset: true), updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        } else {
            self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
}

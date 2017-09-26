import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

private struct ChatMediaInputPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private struct ChatMediaInputGridTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
    let animated: Bool
}

private func preparedChatMediaInputPanelEntryTransition(account: Account, from fromEntries: [ChatMediaInputPanelEntry], to toEntries: [ChatMediaInputPanelEntry], inputNodeInteraction: ChatMediaInputNodeInteraction) -> ChatMediaInputPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, inputNodeInteraction: inputNodeInteraction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, inputNodeInteraction: inputNodeInteraction), directionHint: nil) }
    
    return ChatMediaInputPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

private func preparedChatMediaInputGridEntryTransition(account: Account, from fromEntries: [ChatMediaInputGridEntry], to toEntries: [ChatMediaInputGridEntry], update: StickerPacksCollectionUpdate, interfaceInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction) -> ChatMediaInputGridTransition {
    var stationaryItems: GridNodeStationaryItems = .none
    var scrollToItem: GridNodeScrollToItem?
    var animated = false
    switch update {
        case .generic:
            animated = true
        case .scroll:
            var fromStableIds = Set<ChatMediaInputGridEntryStableId>()
            for entry in fromEntries {
                fromStableIds.insert(entry.stableId)
            }
            var index = 0
            var indices = Set<Int>()
            for entry in toEntries {
                if fromStableIds.contains(entry.stableId) {
                    indices.insert(index)
                }
                index += 1
            }
            stationaryItems = .indices(indices)
        case let .navigate(index, collectionId):
            if let index = index {
                for i in 0 ..< toEntries.count {
                    if toEntries[i].index >= index {
                        var directionHint: GridNodePreviousItemsTransitionDirectionHint = .up
                        if !fromEntries.isEmpty && fromEntries[0].index < toEntries[i].index {
                            directionHint = .down
                        }
                        scrollToItem = GridNodeScrollToItem(index: i, position: .top, transition: .animated(duration: 0.45, curve: .spring), directionHint: directionHint, adjustForSection: true)
                        break
                    }
                }
            } else if !toEntries.isEmpty {
                if let collectionId = collectionId {
                    for i in 0 ..< toEntries.count {
                        if toEntries[i].index.collectionId == collectionId {
                            var directionHint: GridNodePreviousItemsTransitionDirectionHint = .up
                            if !fromEntries.isEmpty && fromEntries[0].index < toEntries[i].index {
                                directionHint = .down
                            }
                            scrollToItem = GridNodeScrollToItem(index: i, position: .top, transition: .animated(duration: 0.45, curve: .spring), directionHint: directionHint, adjustForSection: true)
                            break
                        }
                    }
                }
                if scrollToItem == nil {
                    scrollToItem = GridNodeScrollToItem(index: 0, position: .top, transition: .animated(duration: 0.45, curve: .spring), directionHint: .up, adjustForSection: true)
                }
            }
    }
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interfaceInteraction: interfaceInteraction, inputNodeInteraction: inputNodeInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interfaceInteraction: interfaceInteraction, inputNodeInteraction: inputNodeInteraction)) }
    
    var firstIndexInSectionOffset = 0
    if !toEntries.isEmpty {
        firstIndexInSectionOffset = Int(toEntries[0].index.itemIndex.index)
    }
    
    return ChatMediaInputGridTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: firstIndexInSectionOffset, stationaryItems: stationaryItems, scrollToItem: scrollToItem, animated: animated)
}

private func chatMediaInputPanelEntries(view: ItemCollectionsView, savedStickers: OrderedItemListView?, recentStickers: OrderedItemListView?, theme: PresentationTheme) -> [ChatMediaInputPanelEntry] {
    var entries: [ChatMediaInputPanelEntry] = []
    entries.append(.recentGifs(theme))
    if let savedStickers = savedStickers, !savedStickers.items.isEmpty {
        entries.append(.savedStickers(theme))
    }
    if let recentStickers = recentStickers, !recentStickers.items.isEmpty {
        entries.append(.recentPacks(theme))
    }
    var index = 0
    for (_, info, item) in view.collectionInfos {
        if let info = info as? StickerPackCollectionInfo {
            entries.append(.stickerPack(index: index, info: info, topItem: item as? StickerPackItem, theme: theme))
            index += 1
        }
    }
    return entries
}

private func chatMediaInputGridEntries(view: ItemCollectionsView, savedStickers: OrderedItemListView?, recentStickers: OrderedItemListView?, strings: PresentationStrings, theme: PresentationTheme) -> [ChatMediaInputGridEntry] {
    var entries: [ChatMediaInputGridEntry] = []
    
    var stickerPackInfos: [ItemCollectionId: StickerPackCollectionInfo] = [:]
    for (id, info, _) in view.collectionInfos {
        if let info = info as? StickerPackCollectionInfo {
            stickerPackInfos[id] = info
        }
    }
    
    var savedStickerIds = Set<Int64>()
    if let savedStickers = savedStickers, !savedStickers.items.isEmpty {
        let packInfo = StickerPackCollectionInfo(id: ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue, id: 0), flags: [], accessHash: 0, title: strings.Stickers_Favorited.uppercased(), shortName: "", hash: 0, count: 0)
        for i in 0 ..< savedStickers.items.count {
            if let item = savedStickers.items[i].contents as? SavedStickerItem {
                savedStickerIds.insert(item.file.fileId.id)
                let index = ItemCollectionItemIndex(index: Int32(i), id: item.file.fileId.id)
                let stickerItem = StickerPackItem(index: index, file: item.file, indexKeys: [])
                entries.append(ChatMediaInputGridEntry(index: ItemCollectionViewEntryIndex(collectionIndex: -2, collectionId: packInfo.id, itemIndex: index), stickerItem: stickerItem, stickerPackInfo: packInfo, theme: theme))
            }
        }
    }
    
    if let recentStickers = recentStickers, !recentStickers.items.isEmpty {
        let packInfo = StickerPackCollectionInfo(id: ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue, id: 0), flags: [], accessHash: 0, title: strings.Stickers_FrequentlyUsed.uppercased(), shortName: "", hash: 0, count: 0)
        var addedCount = 0
        for i in 0 ..< recentStickers.items.count {
            if addedCount >= 20 {
                break
            }
            if let item = recentStickers.items[i].contents as? RecentMediaItem, let file = item.media as? TelegramMediaFile, let mediaId = item.media.id {
                if !savedStickerIds.contains(mediaId.id) {
                    let index = ItemCollectionItemIndex(index: Int32(i), id: mediaId.id)
                    let stickerItem = StickerPackItem(index: index, file: file, indexKeys: [])
                    entries.append(ChatMediaInputGridEntry(index: ItemCollectionViewEntryIndex(collectionIndex: -1, collectionId: packInfo.id, itemIndex: index), stickerItem: stickerItem, stickerPackInfo: packInfo, theme: theme))
                    addedCount += 1
                }
            }
        }
    }
    
    for entry in view.entries {
        if let item = entry.item as? StickerPackItem {
            entries.append(ChatMediaInputGridEntry(index: entry.index, stickerItem: item, stickerPackInfo: stickerPackInfos[entry.index.collectionId], theme: theme))
        }
    }
    return entries
}

private enum StickerPacksCollectionPosition: Equatable {
    case initial
    case scroll(aroundIndex: ItemCollectionViewEntryIndex?)
    case navigate(index: ItemCollectionViewEntryIndex?, collectionId: ItemCollectionId?)
    
    static func ==(lhs: StickerPacksCollectionPosition, rhs: StickerPacksCollectionPosition) -> Bool {
        switch lhs {
            case .initial:
                if case .initial = rhs {
                    return true
                } else {
                    return false
                }
            case let .scroll(lhsAroundIndex):
                if case let .scroll(rhsAroundIndex) = rhs, lhsAroundIndex == rhsAroundIndex {
                    return true
                } else {
                    return false
                }
            case .navigate:
                return false
        }
    }
}

private enum StickerPacksCollectionUpdate {
    case generic
    case scroll
    case navigate(ItemCollectionViewEntryIndex?, ItemCollectionId?)
}

final class ChatMediaInputNodeInteraction {
    let navigateToCollectionId: (ItemCollectionId) -> Void
    
    var highlightedStickerItemCollectionId: ItemCollectionId?
    var highlightedItemCollectionId: ItemCollectionId?
    var previewedStickerPackItem: StickerPackItem?
    
    init(navigateToCollectionId: @escaping (ItemCollectionId) -> Void) {
        self.navigateToCollectionId = navigateToCollectionId
    }
}

private func clipScrollPosition(_ position: StickerPacksCollectionPosition) -> StickerPacksCollectionPosition {
    switch position {
        case let .scroll(index):
            if let index = index, index.collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue || index.collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue {
                return .scroll(aroundIndex: nil)
            }
        default:
            break
    }
    return position
}

private let defaultPortraitPanelHeight: CGFloat = UIScreenScale.isEqual(to: 3.0) ? 271.0 : 258.0
private let defaultLandscapePanelHeight: CGFloat = UIScreenScale.isEqual(to: 3.0) ? 194.0 : 194.0

private enum ChatMediaInputPane {
    case gifs
    case stickers
}

private struct ChatMediaInputPaneArrangement {
    let panes: [ChatMediaInputPane]
    let currentIndex: Int
    let indexTransition: CGFloat
    
    func withIndexTransition(_ indexTransition: CGFloat) -> ChatMediaInputPaneArrangement {
        return ChatMediaInputPaneArrangement(panes: self.panes, currentIndex: currentIndex, indexTransition: indexTransition)
    }
    
    func withCurrentIndex(_ currentIndex: Int) -> ChatMediaInputPaneArrangement {
        return ChatMediaInputPaneArrangement(panes: self.panes, currentIndex: currentIndex, indexTransition: self.indexTransition)
    }
}

final class ChatMediaInputNode: ChatInputNode {
    private let account: Account
    private let controllerInteraction: ChatControllerInteraction
    
    private var inputNodeInteraction: ChatMediaInputNodeInteraction!
    
    private let collectionListPanel: ASDisplayNode
    private let collectionListSeparator: ASDisplayNode
    
    private let disposable = MetaDisposable()
    
    private let listView: ListView
    
    private let stickerPane: ChatMediaInputStickerPane
    private let gifPane: ChatMediaInputGifPane
    
    private let itemCollectionsViewPosition = Promise<StickerPacksCollectionPosition>()
    private var currentStickerPacksCollectionPosition: StickerPacksCollectionPosition?
    private var currentView: ItemCollectionsView?
    
    private var stickerPreviewController: StickerPreviewController?
    
    private var validLayout: (CGFloat, ChatPresentationInterfaceState)?
    private var paneArrangement: ChatMediaInputPaneArrangement
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    init(account: Account, controllerInteraction: ChatControllerInteraction, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        self.controllerInteraction = controllerInteraction
        self.theme = theme
        self.strings = strings
        
        self.themeAndStringsPromise = Promise((theme, strings))
        
        self.collectionListPanel = ASDisplayNode()
        self.collectionListPanel.backgroundColor = theme.chat.inputPanel.panelBackgroundColor
        
        self.collectionListSeparator = ASDisplayNode()
        self.collectionListSeparator.isLayerBacked = true
        self.collectionListSeparator.backgroundColor = theme.chat.inputMediaPanel.panelSerapatorColor
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(Double.pi / 2.0), 0.0, 0.0, 1.0)
        
        self.stickerPane = ChatMediaInputStickerPane()
        self.gifPane = ChatMediaInputGifPane(account: account, controllerInteraction: controllerInteraction)
        
        self.paneArrangement = ChatMediaInputPaneArrangement(panes: [.gifs, .stickers], currentIndex: 1, indexTransition: 0.0)
        
        super.init()
        
        self.inputNodeInteraction = ChatMediaInputNodeInteraction(navigateToCollectionId: { [weak self] collectionId in
            if let strongSelf = self, let currentView = strongSelf.currentView, (collectionId != strongSelf.inputNodeInteraction.highlightedItemCollectionId || true) {
                var index: Int32 = 0
                if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue {
                    strongSelf.setCurrentPane(.gifs, transition: .animated(duration: 0.25, curve: .spring))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
                    for (id, _, _) in currentView.collectionInfos {
                        if id.namespace == collectionId.namespace {
                            if id == collectionId {
                                let itemIndex = ItemCollectionViewEntryIndex.lowerBound(collectionIndex: index, collectionId: id)
                                strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: itemIndex, collectionId: nil)))
                                break
                            }
                            index += 1
                        }
                    }
                }
            }
        })
        
        self.clipsToBounds = true
        self.backgroundColor = theme.chat.inputMediaPanel.gifsBackgroundColor
        
        self.addSubnode(self.collectionListPanel)
        self.addSubnode(self.collectionListSeparator)
        self.addSubnode(self.listView)
        
        let itemCollectionsView = self.itemCollectionsViewPosition.get()
            |> distinctUntilChanged
            |> mapToSignal { position -> Signal<(ItemCollectionsView, StickerPacksCollectionUpdate), NoError> in
                switch position {
                    case .initial:
                        return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 50)
                            |> map { view -> (ItemCollectionsView, StickerPacksCollectionUpdate) in
                                return (view, .generic)
                            }
                    case let .scroll(aroundIndex):
                        var firstTime = true
                        return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: aroundIndex, count: 140)
                            |> map { view -> (ItemCollectionsView, StickerPacksCollectionUpdate) in
                                let update: StickerPacksCollectionUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .scroll
                                } else {
                                    update = .generic
                                }
                                return (view, update)
                            }
                    case let .navigate(index, collectionId):
                        var firstTime = true
                        return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: index, count: 140)
                            |> map { view -> (ItemCollectionsView, StickerPacksCollectionUpdate) in
                                let update: StickerPacksCollectionUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .navigate(index, collectionId)
                                } else {
                                    update = .generic
                                }
                                return (view, update)
                        }
                }
        }
        
        let previousEntries = Atomic<([ChatMediaInputPanelEntry], [ChatMediaInputGridEntry])>(value: ([], []))
        
        let inputNodeInteraction = self.inputNodeInteraction!
        
        let transitions = combineLatest(itemCollectionsView, self.themeAndStringsPromise.get())
            |> map { viewAndUpdate, themeAndStrings -> (ItemCollectionsView, ChatMediaInputPanelTransition, Bool, ChatMediaInputGridTransition, Bool) in
                let (view, update) = viewAndUpdate
                let (theme, strings) = themeAndStrings
                
                var savedStickers: OrderedItemListView?
                var recentStickers: OrderedItemListView?
                for orderedView in view.orderedItemListsViews {
                    if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentStickers {
                        recentStickers = orderedView
                    } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudSavedStickers {
                        savedStickers = orderedView
                    }
                }
                let panelEntries = chatMediaInputPanelEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, theme: theme)
                let gridEntries = chatMediaInputGridEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, strings: strings, theme: theme)
                let (previousPanelEntries, previousGridEntries) = previousEntries.swap((panelEntries, gridEntries))
                return (view, preparedChatMediaInputPanelEntryTransition(account: account, from: previousPanelEntries, to: panelEntries, inputNodeInteraction: inputNodeInteraction), previousPanelEntries.isEmpty, preparedChatMediaInputGridEntryTransition(account: account, from: previousGridEntries, to: gridEntries, update: update, interfaceInteraction: controllerInteraction, inputNodeInteraction: inputNodeInteraction), previousGridEntries.isEmpty)
            }
        
        self.disposable.set((transitions |> deliverOnMainQueue).start(next: { [weak self] (view, panelTransition, panelFirstTime, gridTransition, gridFirstTime) in
            if let strongSelf = self {
                strongSelf.currentView = view
                strongSelf.enqueuePanelTransition(panelTransition, firstTime: panelFirstTime, thenGridTransition: gridTransition, gridFirstTime: gridFirstTime)
            }
        }))
        
        self.stickerPane.gridNode.visibleItemsUpdated = { [weak self] visibleItems in
            if let strongSelf = self {
                var topVisibleCollectionId: ItemCollectionId?
                
                if let topVisibleSection = visibleItems.topSectionVisible as? ChatMediaInputStickerGridSection {
                    topVisibleCollectionId = topVisibleSection.collectionId
                } else if let topVisible = visibleItems.topVisible, let item = topVisible.1 as? ChatMediaInputStickerGridItem {
                    topVisibleCollectionId = item.index.collectionId
                }
                if let collectionId = topVisibleCollectionId {
                    if strongSelf.inputNodeInteraction.highlightedItemCollectionId != collectionId {
                        strongSelf.setHighlightedItemCollectionId(collectionId)
                    }
                }
                
                if let currentView = strongSelf.currentView, let (topIndex, topItem) = visibleItems.top, let (bottomIndex, bottomItem) = visibleItems.bottom {
                    if topIndex <= 10 && currentView.lower != nil {
                        let position: StickerPacksCollectionPosition = clipScrollPosition(.scroll(aroundIndex: (topItem as! ChatMediaInputStickerGridItem).index))
                        if strongSelf.currentStickerPacksCollectionPosition != position {
                            strongSelf.currentStickerPacksCollectionPosition = position
                            strongSelf.itemCollectionsViewPosition.set(.single(position))
                        }
                    } else if bottomIndex >= visibleItems.count - 10 && currentView.higher != nil {
                        let position: StickerPacksCollectionPosition = clipScrollPosition(.scroll(aroundIndex: (bottomItem as! ChatMediaInputStickerGridItem).index))
                        if strongSelf.currentStickerPacksCollectionPosition != position {
                            strongSelf.currentStickerPacksCollectionPosition = position
                            strongSelf.itemCollectionsViewPosition.set(.single(position))
                        }
                    }
                }
            }
        }
        
        let longTapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.previewGesture(_:)))
        longTapRecognizer.tapActionAtPoint = { [weak self] location in
            if let strongSelf = self, let _ = strongSelf.stickerPane.gridNode.itemNodeAtPoint(location) as? ChatMediaInputStickerGridItemNode {
                return .waitForHold(timeout: 0.2, acceptTap: false)
            }
            return .fail
        }
        self.stickerPane.gridNode.view.addGestureRecognizer(longTapRecognizer)
        
        self.currentStickerPacksCollectionPosition = .initial
        self.itemCollectionsViewPosition.set(.single(.initial))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            
            self.collectionListPanel.backgroundColor = theme.chat.inputPanel.panelBackgroundColor
            self.collectionListSeparator.backgroundColor = theme.chat.inputMediaPanel.panelSerapatorColor
            self.backgroundColor = theme.chat.inputMediaPanel.gifsBackgroundColor
            
            self.themeAndStringsPromise.set(.single((theme, strings)))
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    private func heightForWidth(width: CGFloat) -> CGFloat {
        return defaultPortraitPanelHeight
    }
    
    private func setCurrentPane(_ pane: ChatMediaInputPane, transition: ContainedViewLayoutTransition) {
        if let index = self.paneArrangement.panes.index(of: pane), index != self.paneArrangement.currentIndex {
            self.paneArrangement = self.paneArrangement.withIndexTransition(0.0).withCurrentIndex(index)
            if let (width, interfaceState) = self.validLayout {
                let _ = self.updateLayout(width: width, transition: .animated(duration: 0.25, curve: .spring), interfaceState: interfaceState)
            }
            switch pane {
                case .gifs:
                    self.setHighlightedItemCollectionId(ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue, id: 0))
                case .stickers:
                    if let highlightedStickerCollectionId = self.inputNodeInteraction.highlightedStickerItemCollectionId {
                        self.setHighlightedItemCollectionId(highlightedStickerCollectionId)
                    }
            }
        }
    }
    
    private func setHighlightedItemCollectionId(_ collectionId: ItemCollectionId) {
        if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue {
            if self.paneArrangement.panes[self.paneArrangement.currentIndex] == .gifs {
                self.inputNodeInteraction.highlightedItemCollectionId = collectionId
            }
        } else {
            self.inputNodeInteraction.highlightedStickerItemCollectionId = collectionId
            if self.paneArrangement.panes[self.paneArrangement.currentIndex] == .stickers {
                self.inputNodeInteraction.highlightedItemCollectionId = collectionId
            }
        }
        var ensuredNodeVisible = false
        var firstVisibleCollectionId: ItemCollectionId?
        self.listView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMediaInputStickerPackItemNode {
                if firstVisibleCollectionId == nil {
                    firstVisibleCollectionId = itemNode.currentCollectionId
                }
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputMetaSectionItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputRecentGifsItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            }
        }
        
        if let currentView = self.currentView, let firstVisibleCollectionId = firstVisibleCollectionId, !ensuredNodeVisible {
            let targetIndex = currentView.collectionInfos.index(where: { id, _, _ in return id == collectionId })
            let firstVisibleIndex = currentView.collectionInfos.index(where: { id, _, _ in return id == firstVisibleCollectionId })
            if let targetIndex = targetIndex, let firstVisibleIndex = firstVisibleIndex {
                let toRight = targetIndex > firstVisibleIndex
                self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [], scrollToItem: ListViewScrollToItem(index: targetIndex, position: toRight ? .bottom(0.0) : .top(0.0), animated: true, curve: .Default, directionHint: toRight ? .Down : .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil)
            }
        }
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        self.validLayout = (width, interfaceState)
        
        if self.theme !== interfaceState.theme || self.strings !== interfaceState.strings {
            self.updateThemeAndStrings(theme: interfaceState.theme, strings: interfaceState.strings)
        }
        
        let separatorHeight = UIScreenPixel
        let panelHeight = self.heightForWidth(width: width)
        
        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: 41.0)))
        transition.updateFrame(node: self.collectionListSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 41.0), size: CGSize(width: width, height: separatorHeight)))
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: 41.0, height: width)
        self.listView.position = CGPoint(x: width / 2.0, y: 41.0 / 2.0)
        
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
            listViewCurve = .Default
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: 41.0, height: width), insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), duration: duration, curve: listViewCurve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        var visiblePanes: [(ChatMediaInputPane, CGFloat)] = []
        
        var paneIndex = 0
        for pane in self.paneArrangement.panes {
            let paneOrigin = CGFloat(paneIndex - self.paneArrangement.currentIndex) * width - self.paneArrangement.indexTransition * width
            if paneOrigin.isLess(than: width) && CGFloat(0.0).isLess(than: (paneOrigin + width)) {
                visiblePanes.append((pane, paneOrigin))
            }
            paneIndex += 1
        }
        
        for (pane, paneOrigin) in visiblePanes {
            switch pane {
                case .gifs:
                    if self.gifPane.supernode == nil {
                        self.addSubnode(self.gifPane)
                        self.gifPane.frame = CGRect(origin: CGPoint(x: -width, y: 41.0), size: CGSize(width: width, height: panelHeight - 41.0))
                    }
                    self.gifPane.layer.removeAnimation(forKey: "position")
                    transition.updateFrame(node: self.gifPane, frame: CGRect(origin: CGPoint(x: paneOrigin, y: 41.0), size: CGSize(width: width, height: panelHeight - 41.0)))
                case .stickers:
                    if self.stickerPane.supernode == nil {
                        self.addSubnode(self.stickerPane)
                        self.stickerPane.frame = CGRect(origin: CGPoint(x: width, y: 41.0), size: CGSize(width: width, height: panelHeight - 41.0))
                    }
                    self.stickerPane.layer.removeAnimation(forKey: "position")
                    transition.updateFrame(node: self.stickerPane, frame: CGRect(origin: CGPoint(x: paneOrigin, y: 41.0), size: CGSize(width: width, height: panelHeight - 41.0)))
            }
        }
        
        self.gifPane.updateLayout(size: CGSize(width: width, height: panelHeight - 41.0), transition: transition)
        self.stickerPane.updateLayout(size: CGSize(width: width, height: panelHeight - 41.0), transition: transition)
        
        if self.gifPane.supernode != nil {
            if !visiblePanes.contains(where: { $0.0 == .gifs }) {
                if case .animated = transition {
                    var toLeft = false
                    if let index = self.paneArrangement.panes.index(of: .gifs), index < self.paneArrangement.currentIndex {
                        toLeft = true
                    }
                    transition.animatePosition(node: self.gifPane, to: CGPoint(x: (toLeft ? -width : width) + width / 2.0, y: self.gifPane.layer.position.y), removeOnCompletion: false, completion: { [weak self] value in
                        if let strongSelf = self, value {
                            strongSelf.gifPane.removeFromSupernode()
                        }
                    })
                } else {
                    self.gifPane.removeFromSupernode()
                }
            }
        }
        
        if self.stickerPane.supernode != nil {
            if !visiblePanes.contains(where: { $0.0 == .stickers }) {
                if case .animated = transition {
                    var toLeft = false
                    if let index = self.paneArrangement.panes.index(of: .stickers), index < self.paneArrangement.currentIndex {
                        toLeft = true
                    }
                    transition.animatePosition(node: self.stickerPane, to: CGPoint(x: (toLeft ? -width : width) + width / 2.0, y: self.stickerPane.layer.position.y), removeOnCompletion: false, completion: { [weak self] value in
                        if let strongSelf = self, value {
                            strongSelf.stickerPane.removeFromSupernode()
                        }
                    })
                } else {
                    self.stickerPane.removeFromSupernode()
                }
            }
        }
        
        return panelHeight
    }
    
    private func enqueuePanelTransition(_ transition: ChatMediaInputPanelTransition, firstTime: Bool, thenGridTransition gridTransition: ChatMediaInputGridTransition, gridFirstTime: Bool) {
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.Synchronous)
            options.insert(.LowLatency)
        } else {
            options.insert(.AnimateInsertion)
        }
        self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.enqueueGridTransition(gridTransition, firstTime: gridFirstTime)
            }
        })
    }
    
    private func enqueueGridTransition(_ transition: ChatMediaInputGridTransition, firstTime: Bool) {
        var itemTransition: ContainedViewLayoutTransition = .immediate
        if transition.animated {
            itemTransition = .animated(duration: 0.3, curve: .spring)
        }
        self.stickerPane.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: itemTransition, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { _ in })
    }
    
    @objc func previewGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .began:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation, case .hold = gesture {
                    if let itemNode = self.stickerPane.gridNode.itemNodeAtPoint(location) as? ChatMediaInputStickerGridItemNode {
                        self.updatePreviewingItem(item: itemNode.stickerPackItem, animated: true)
                    }
                }
            case .ended, .cancelled:
                self.updatePreviewingItem(item: nil, animated: true)
            case .changed:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation, case .hold = gesture, let itemNode = self.stickerPane.gridNode.itemNodeAtPoint(location) as? ChatMediaInputStickerGridItemNode {
                    self.updatePreviewingItem(item: itemNode.stickerPackItem, animated: true)
                }
            default:
                break
        }
    }
    
    private func updatePreviewingItem(item: StickerPackItem?, animated: Bool) {
        if self.inputNodeInteraction.previewedStickerPackItem != item {
            self.inputNodeInteraction.previewedStickerPackItem = item
            
            self.stickerPane.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMediaInputStickerGridItemNode {
                    itemNode.updatePreviewing(animated: animated)
                }
            }
            
            if let item = item {
                if let stickerPreviewController = self.stickerPreviewController {
                    stickerPreviewController.updateItem(item)
                } else {
                    let stickerPreviewController = StickerPreviewController(account: self.account, item: item)
                    self.stickerPreviewController = stickerPreviewController
                    self.controllerInteraction.presentController(stickerPreviewController, StickerPreviewControllerPresentationArguments(transitionNode: { [weak self] item in
                        if let strongSelf = self {
                            var result: ASDisplayNode?
                            strongSelf.stickerPane.gridNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ChatMediaInputStickerGridItemNode, itemNode.stickerPackItem == item {
                                    result = itemNode.transitionNode()
                                }
                            }
                            return result
                        }
                        return nil
                    }))
                }
            } else if let stickerPreviewController = self.stickerPreviewController {
                stickerPreviewController.dismiss()
                self.stickerPreviewController = nil
            }
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                break
            case .changed:
                if let (width, interfaceState) = self.validLayout {
                    let translationX = -recognizer.translation(in: self.view).x
                    var indexTransition = translationX / width
                    if self.paneArrangement.currentIndex == 0 {
                        indexTransition = max(0.0, indexTransition)
                    } else if self.paneArrangement.currentIndex == self.paneArrangement.panes.count - 1 {
                        indexTransition = min(0.0, indexTransition)
                    }
                    self.paneArrangement = self.paneArrangement.withIndexTransition(indexTransition)
                    let _ = self.updateLayout(width: width, transition: .immediate, interfaceState: interfaceState)
                }
            case .ended:
                if let (width, _) = self.validLayout {
                    var updatedIndex = self.paneArrangement.currentIndex
                    if abs(self.paneArrangement.indexTransition * width) > 30.0 {
                        if self.paneArrangement.indexTransition < 0.0 {
                            updatedIndex = max(0, self.paneArrangement.currentIndex - 1)
                        } else {
                            updatedIndex = min(self.paneArrangement.panes.count - 1, self.paneArrangement.currentIndex + 1)
                        }
                    }
                    self.setCurrentPane(self.paneArrangement.panes[updatedIndex], transition: .animated(duration: 0.25, curve: .spring))
                }
            case .cancelled:
                if let (width, interfaceState) = self.validLayout {
                    self.paneArrangement = self.paneArrangement.withIndexTransition(0.0)
                    let _ = self.updateLayout(width: width, transition: .animated(duration: 0.25, curve: .spring), interfaceState: interfaceState)
                }
            default:
                break
        }
    }
}

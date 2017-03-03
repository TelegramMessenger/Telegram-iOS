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
    switch update {
        case .generic:
            break
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
        case let .navigate(index):
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
                scrollToItem = GridNodeScrollToItem(index: 0, position: .top, transition: .animated(duration: 0.45, curve: .spring), directionHint: .up, adjustForSection: true)
            }
    }
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interfaceInteraction: interfaceInteraction, inputNodeInteraction: inputNodeInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, item: $0.1.item(account: account, interfaceInteraction: interfaceInteraction, inputNodeInteraction: inputNodeInteraction)) }
    
    var firstIndexInSectionOffset = 0
    if !toEntries.isEmpty {
        firstIndexInSectionOffset = Int(toEntries[0].index.itemIndex.index)
    }
    
    return ChatMediaInputGridTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: firstIndexInSectionOffset, stationaryItems: stationaryItems, scrollToItem: scrollToItem)
}

private func chatMediaInputPanelEntries(view: ItemCollectionsView, recentStickers: OrderedItemListView?) -> [ChatMediaInputPanelEntry] {
    var entries: [ChatMediaInputPanelEntry] = []
    if let recentStickers = recentStickers, !recentStickers.items.isEmpty {
        entries.append(.recentPacks)
    }
    var index = 0
    for (_, info, item) in view.collectionInfos {
        if let info = info as? StickerPackCollectionInfo {
            entries.append(.stickerPack(index: index, info: info, topItem: item as? StickerPackItem))
            index += 1
        }
    }
    return entries
}

private func chatMediaInputGridEntries(view: ItemCollectionsView, recentStickers: OrderedItemListView?) -> [ChatMediaInputGridEntry] {
    var entries: [ChatMediaInputGridEntry] = []
    
    var stickerPackInfos: [ItemCollectionId: StickerPackCollectionInfo] = [:]
    for (id, info, _) in view.collectionInfos {
        if let info = info as? StickerPackCollectionInfo {
            stickerPackInfos[id] = info
        }
    }
    
    if let recentStickers = recentStickers, !recentStickers.items.isEmpty {
        let packInfo = StickerPackCollectionInfo(id: ItemCollectionId(namespace: Namespaces.ItemCollection.CloudRecentStickers, id: 0), flags: [], accessHash: 0, title: "FREQUENTLY USED", shortName: "", hash: 0)
        for i in 0 ..< min(20, recentStickers.items.count) {
            if let item = recentStickers.items[i].contents as? RecentMediaItem, let file = item.media as? TelegramMediaFile, let mediaId = item.media.id {
                let index = ItemCollectionItemIndex(index: Int32(i), id: mediaId.id)
                let stickerItem = StickerPackItem(index: index, file: file, indexKeys: [])
                entries.append(ChatMediaInputGridEntry(index: ItemCollectionViewEntryIndex(collectionIndex: -1, collectionId: packInfo.id, itemIndex: index), stickerItem: stickerItem, stickerPackInfo: packInfo))
            }
        }
    }
    
    for entry in view.entries {
        if let item = entry.item as? StickerPackItem {
            entries.append(ChatMediaInputGridEntry(index: entry.index, stickerItem: item, stickerPackInfo: stickerPackInfos[entry.index.collectionId]))
        }
    }
    return entries
}

private enum StickerPacksCollectionPosition: Equatable {
    case initial
    case scroll(aroundIndex: ItemCollectionViewEntryIndex?)
    case navigate(index: ItemCollectionViewEntryIndex?)
    
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
    case navigate(ItemCollectionViewEntryIndex?)
}

final class ChatMediaInputNodeInteraction {
    let navigateToCollectionId: (ItemCollectionId) -> Void
    
    var highlightedItemCollectionId: ItemCollectionId?
    
    init(navigateToCollectionId: @escaping (ItemCollectionId) -> Void) {
        self.navigateToCollectionId = navigateToCollectionId
    }
}

private func clipScrollPosition(_ position: StickerPacksCollectionPosition) -> StickerPacksCollectionPosition {
    switch position {
        case let .scroll(index):
            if let index = index, index.collectionId.namespace == Namespaces.ItemCollection.CloudRecentStickers {
                return .scroll(aroundIndex: nil)
            }
        default:
            break
    }
    return position
}

private let defaultPortraitPanelHeight: CGFloat = UIScreenScale.isEqual(to: 3.0) ? 271.0 : 258.0
private let defaultLandscapePanelHeight: CGFloat = UIScreenScale.isEqual(to: 3.0) ? 194.0 : 194.0

final class ChatMediaInputNode: ChatInputNode {
    private let account: Account
    private let controllerInteraction: ChatControllerInteraction
    
    private var inputNodeInteraction: ChatMediaInputNodeInteraction!
    
    private let collectionListPanel: ASDisplayNode
    private let collectionListSeparator: ASDisplayNode
    
    private let disposable = MetaDisposable()
    
    private let listView: ListView
    private let gridNode: GridNode
    
    private let itemCollectionsViewPosition = Promise<StickerPacksCollectionPosition>()
    private var currentStickerPacksCollectionPosition: StickerPacksCollectionPosition?
    private var currentView: ItemCollectionsView?
    
    init(account: Account, controllerInteraction: ChatControllerInteraction) {
        self.account = account
        self.controllerInteraction = controllerInteraction
        
        self.collectionListPanel = ASDisplayNode()
        self.collectionListPanel.backgroundColor = UIColor(0xF5F6F8)
        
        self.collectionListSeparator = ASDisplayNode()
        self.collectionListSeparator.isLayerBacked = true
        self.collectionListSeparator.backgroundColor = UIColor(0xBEC2C6)
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(M_PI / 2.0), 0.0, 0.0, 1.0)
        
        self.gridNode = GridNode()
        
        super.init()
        
        self.inputNodeInteraction = ChatMediaInputNodeInteraction(navigateToCollectionId: { [weak self] collectionId in
            if let strongSelf = self, let currentView = strongSelf.currentView, (collectionId != strongSelf.inputNodeInteraction.highlightedItemCollectionId || true) {
                var index: Int32 = 0
                if collectionId.namespace == Namespaces.ItemCollection.CloudRecentStickers {
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: nil)))
                } else {
                    for (id, _, _) in currentView.collectionInfos {
                        if id.namespace == collectionId.namespace {
                            if id == collectionId {
                                let itemIndex = ItemCollectionViewEntryIndex.lowerBound(collectionIndex: index, collectionId: id)
                                strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: itemIndex)))
                                break
                            }
                            index += 1
                        }
                    }
                }
            }
        })
        
        self.clipsToBounds = true
        self.backgroundColor = UIColor(0xE8EBF0)
        
        self.addSubnode(self.collectionListPanel)
        self.addSubnode(self.collectionListSeparator)
        self.addSubnode(self.listView)
        self.addSubnode(self.gridNode)
        
        let itemCollectionsView = self.itemCollectionsViewPosition.get()
            |> distinctUntilChanged
            |> mapToSignal { position -> Signal<(ItemCollectionsView, StickerPacksCollectionUpdate), NoError> in
                switch position {
                    case .initial:
                        return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 50)
                            |> map { view -> (ItemCollectionsView, StickerPacksCollectionUpdate) in
                                return (view, .generic)
                            }
                    case let .scroll(aroundIndex):
                        var firstTime = true
                        return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: aroundIndex, count: 140)
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
                    case let .navigate(index):
                        var firstTime = true
                        return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: index, count: 140)
                            |> map { view -> (ItemCollectionsView, StickerPacksCollectionUpdate) in
                                let update: StickerPacksCollectionUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .navigate(index)
                                } else {
                                    update = .generic
                                }
                                return (view, update)
                        }
                }
        }
        
        let previousEntries = Atomic<([ChatMediaInputPanelEntry], [ChatMediaInputGridEntry])>(value: ([], []))
        
        let inputNodeInteraction = self.inputNodeInteraction!
        
        let transitions = itemCollectionsView
            |> map { (view, update) -> (ItemCollectionsView, ChatMediaInputPanelTransition, Bool, ChatMediaInputGridTransition, Bool) in
                var recentStickers: OrderedItemListView?
                for orderedView in view.orderedItemListsViews {
                    if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentStickers {
                        recentStickers = orderedView
                        break
                    }
                }
                let panelEntries = chatMediaInputPanelEntries(view: view, recentStickers: recentStickers)
                let gridEntries = chatMediaInputGridEntries(view: view, recentStickers: recentStickers)
                let (previousPanelEntries, previousGridEntries) = previousEntries.swap((panelEntries, gridEntries))
                return (view, preparedChatMediaInputPanelEntryTransition(account: account, from: previousPanelEntries, to: panelEntries, inputNodeInteraction: inputNodeInteraction), previousPanelEntries.isEmpty, preparedChatMediaInputGridEntryTransition(account: account, from: previousGridEntries, to: gridEntries, update: update, interfaceInteraction: controllerInteraction, inputNodeInteraction: inputNodeInteraction), previousGridEntries.isEmpty)
            }
        
        self.disposable.set((transitions |> deliverOnMainQueue).start(next: { [weak self] (view, panelTransition, panelFirstTime, gridTransition, gridFirstTime) in
            if let strongSelf = self {
                strongSelf.currentView = view
                strongSelf.enqueuePanelTransition(panelTransition, firstTime: panelFirstTime)
                strongSelf.enqueueGridTransition(gridTransition, firstTime: gridFirstTime)
            }
        }))
        
        self.gridNode.visibleItemsUpdated = { [weak self] visibleItems in
            if let strongSelf = self {
                var topVisibleCollectionId: ItemCollectionId?
                
                if let topVisibleSection = visibleItems.topSectionVisible as? ChatMediaInputStickerGridSection {
                    topVisibleCollectionId = topVisibleSection.collectionId
                } else if let topVisible = visibleItems.topVisible, let item = topVisible.1 as? ChatMediaInputStickerGridItem {
                    topVisibleCollectionId = item.index.collectionId
                }
                if let collectionId = topVisibleCollectionId {
                    if strongSelf.inputNodeInteraction.highlightedItemCollectionId != collectionId {
                        strongSelf.inputNodeInteraction.highlightedItemCollectionId = collectionId
                        var ensuredNodeVisible = false
                        var firstVisibleCollectionId: ItemCollectionId?
                        strongSelf.listView.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? ChatMediaInputStickerPackItemNode {
                                if firstVisibleCollectionId == nil {
                                    firstVisibleCollectionId = itemNode.currentCollectionId
                                }
                                itemNode.updateIsHighlighted()
                                if itemNode.currentCollectionId == collectionId {
                                    strongSelf.listView.ensureItemNodeVisible(itemNode)
                                    ensuredNodeVisible = true
                                }
                            } else if let itemNode = itemNode as? ChatMediaInputRecentStickerPacksItemNode {
                                itemNode.updateIsHighlighted()
                                if itemNode.currentCollectionId == collectionId {
                                    strongSelf.listView.ensureItemNodeVisible(itemNode)
                                    ensuredNodeVisible = true
                                }
                            }
                        }
                        if let currentView = strongSelf.currentView, let firstVisibleCollectionId = firstVisibleCollectionId, !ensuredNodeVisible {
                            let targetIndex = currentView.collectionInfos.index(where: { id, _, _ in return id == collectionId })
                            let firstVisibleIndex = currentView.collectionInfos.index(where: { id, _, _ in return id == firstVisibleCollectionId })
                            if let targetIndex = targetIndex, let firstVisibleIndex = firstVisibleIndex {
                                let toRight = targetIndex > firstVisibleIndex
                                strongSelf.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [], scrollToItem: ListViewScrollToItem(index: targetIndex, position: toRight ? .Bottom : .Top, animated: true, curve: .Default, directionHint: toRight ? .Down : .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil)
                            }
                        }
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
        
        self.currentStickerPacksCollectionPosition = .initial
        self.itemCollectionsViewPosition.set(.single(.initial))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private func heightForWidth(width: CGFloat) -> CGFloat {
        return defaultPortraitPanelHeight
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
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
        
        self.gridNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 41.0), size: CGSize(width: width, height: panelHeight - 41.0))
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: CGSize(width: width, height: panelHeight - 41.0), insets: UIEdgeInsets(), preloadSize: 300.0, itemSize: CGSize(width: 75.0, height: 75.0)), transition: .immediate), stationaryItems: .all, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        return panelHeight
    }
    
    private func enqueuePanelTransition(_ transition: ChatMediaInputPanelTransition, firstTime: Bool) {
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.Synchronous)
            options.insert(.LowLatency)
        } else {
            options.insert(.AnimateInsertion)
        }
        self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
        })
    }
    
    private func enqueueGridTransition(_ transition: ChatMediaInputGridTransition, firstTime: Bool) {
        self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { _ in })
    }
}

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import StickerPackPreviewUI
import PeerInfoUI
import SettingsUI
import ContextUI
import GalleryUI
import OverlayStatusController
import PresentationDataUtils

private struct PeerSpecificPackData {
    let peer: Peer
    let info: StickerPackCollectionInfo
    let items: [ItemCollectionItem]
}

private enum CanInstallPeerSpecificPack {
    case none
    case available(peer: Peer, dismissed: Bool)
}

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
    let updateOpaqueState: ChatMediaInputStickerPaneOpaqueState?
    let animated: Bool
}

private func preparedChatMediaInputPanelEntryTransition(context: AccountContext, from fromEntries: [ChatMediaInputPanelEntry], to toEntries: [ChatMediaInputPanelEntry], inputNodeInteraction: ChatMediaInputNodeInteraction) -> ChatMediaInputPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, inputNodeInteraction: inputNodeInteraction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, inputNodeInteraction: inputNodeInteraction), directionHint: nil) }
    
    return ChatMediaInputPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

private func preparedChatMediaInputGridEntryTransition(account: Account, view: ItemCollectionsView, from fromEntries: [ChatMediaInputGridEntry], to toEntries: [ChatMediaInputGridEntry], update: StickerPacksCollectionUpdate, interfaceInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction, trendingInteraction: TrendingPaneInteraction) -> ChatMediaInputGridTransition {
    var stationaryItems: GridNodeStationaryItems = .none
    var scrollToItem: GridNodeScrollToItem?
    var animated = false
    switch update {
        case .initial:
            for i in (0 ..< toEntries.count).reversed() {
                switch toEntries[i] {
                case .search, .peerSpecificSetup, .trending:
                    break
                case .sticker:
                    scrollToItem = GridNodeScrollToItem(index: i, position: .top(0.0), transition: .immediate, directionHint: .down, adjustForSection: true, adjustForTopInset: true)
                }
            }
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
            if let index = index.flatMap({ ChatMediaInputGridEntryIndex.collectionIndex($0) }) {
                for i in 0 ..< toEntries.count {
                    if toEntries[i].index >= index {
                        var directionHint: GridNodePreviousItemsTransitionDirectionHint = .up
                        if !fromEntries.isEmpty && fromEntries[0].index < toEntries[i].index {
                            directionHint = .down
                        }
                        scrollToItem = GridNodeScrollToItem(index: i, position: .top(0.0), transition: .animated(duration: 0.45, curve: .spring), directionHint: directionHint, adjustForSection: true, adjustForTopInset: true)
                        break
                    }
                }
            } else if !toEntries.isEmpty {
                if let collectionId = collectionId {
                    for i in 0 ..< toEntries.count {
                        var indexMatches = false
                        switch toEntries[i].index {
                            case let .collectionIndex(collectionIndex):
                                if collectionIndex.collectionId == collectionId {
                                    indexMatches = true
                                }
                            case .peerSpecificSetup:
                                if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue {
                                    indexMatches = true
                                }
                            default:
                                break
                        }
                        if indexMatches {
                            var directionHint: GridNodePreviousItemsTransitionDirectionHint = .up
                            if !fromEntries.isEmpty && fromEntries[0].index < toEntries[i].index {
                                directionHint = .down
                            }
                            scrollToItem = GridNodeScrollToItem(index: i, position: .top(0.0), transition: .animated(duration: 0.45, curve: .spring), directionHint: directionHint, adjustForSection: true, adjustForTopInset: true)
                            break
                        }
                    }
                }
                if scrollToItem == nil {
                    scrollToItem = GridNodeScrollToItem(index: 0, position: .top(0.0), transition: .animated(duration: 0.45, curve: .spring), directionHint: .up, adjustForSection: true, adjustForTopInset: true)
                }
            }
    }
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interfaceInteraction: interfaceInteraction, inputNodeInteraction: inputNodeInteraction, trendingInteraction: trendingInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interfaceInteraction: interfaceInteraction, inputNodeInteraction: inputNodeInteraction, trendingInteraction: trendingInteraction)) }
    
    var firstIndexInSectionOffset = 0
    if !toEntries.isEmpty {
        switch toEntries[0].index {
        case .search, .peerSpecificSetup, .trending:
            break
        case let .collectionIndex(index):
            firstIndexInSectionOffset = Int(index.itemIndex.index)
        }
    }
    
    if case .initial = update {
        switch toEntries[0].index {
            case .search:
                if toEntries.count > 1 {
                    //scrollToItem = GridNodeScrollToItem(index: 1, position: .top, transition: .immediate, directionHint: .up, adjustForSection: true)
                }
                break
            default:
                break
        }
    }
    
    let opaqueState = ChatMediaInputStickerPaneOpaqueState(hasLower: view.lower != nil)
    
    return ChatMediaInputGridTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: firstIndexInSectionOffset, stationaryItems: stationaryItems, scrollToItem: scrollToItem, updateOpaqueState: opaqueState, animated: animated)
}

private func chatMediaInputPanelEntries(view: ItemCollectionsView, savedStickers: OrderedItemListView?, recentStickers: OrderedItemListView?, peerSpecificPack: PeerSpecificPackData?, canInstallPeerSpecificPack: CanInstallPeerSpecificPack, hasUnreadTrending: Bool, theme: PresentationTheme) -> [ChatMediaInputPanelEntry] {
    var entries: [ChatMediaInputPanelEntry] = []
    entries.append(.recentGifs(theme))
    if hasUnreadTrending {
        entries.append(.trending(true, theme))
    }
    if let savedStickers = savedStickers, !savedStickers.items.isEmpty {
        entries.append(.savedStickers(theme))
    }
    var savedStickerIds = Set<Int64>()
    if let savedStickers = savedStickers, !savedStickers.items.isEmpty {
        for i in 0 ..< savedStickers.items.count {
            if let item = savedStickers.items[i].contents as? SavedStickerItem {
                savedStickerIds.insert(item.file.fileId.id)
            }
        }
    }
    if let recentStickers = recentStickers, !recentStickers.items.isEmpty {
        var found = false
        for item in recentStickers.items {
            if let item = item.contents as? RecentMediaItem, let _ = item.media as? TelegramMediaFile, let mediaId = item.media.id {
                if !savedStickerIds.contains(mediaId.id) {
                    found = true
                    break
                }
            }
        }
        if found {
            entries.append(.recentPacks(theme))
        }
    }
    if let peerSpecificPack = peerSpecificPack {
        entries.append(.peerSpecific(theme: theme, peer: peerSpecificPack.peer))
    } else if case let .available(peer, false) = canInstallPeerSpecificPack {
        entries.append(.peerSpecific(theme: theme, peer: peer))
    }
    var index = 0
    for (_, info, item) in view.collectionInfos {
        if let info = info as? StickerPackCollectionInfo {
            entries.append(.stickerPack(index: index, info: info, topItem: item as? StickerPackItem, theme: theme))
            index += 1
        }
    }
    
    if peerSpecificPack == nil, case let .available(peer, true) = canInstallPeerSpecificPack {
        entries.append(.peerSpecific(theme: theme, peer: peer))
    }
    
    if !hasUnreadTrending {
        entries.append(.trending(false, theme))
    }
    entries.append(.settings(theme))
    return entries
}

private func chatMediaInputGridEntries(view: ItemCollectionsView, savedStickers: OrderedItemListView?, recentStickers: OrderedItemListView?, peerSpecificPack: PeerSpecificPackData?, canInstallPeerSpecificPack: CanInstallPeerSpecificPack, strings: PresentationStrings, theme: PresentationTheme) -> [ChatMediaInputGridEntry] {
    var entries: [ChatMediaInputGridEntry] = []
    
    if view.lower == nil {
        entries.append(.search(theme: theme, strings: strings))
    }
    
    var stickerPackInfos: [ItemCollectionId: StickerPackCollectionInfo] = [:]
    for (id, info, _) in view.collectionInfos {
        if let info = info as? StickerPackCollectionInfo {
            stickerPackInfos[id] = info
        }
    }
    
    if view.lower == nil {
        var savedStickerIds = Set<Int64>()
        if let savedStickers = savedStickers, !savedStickers.items.isEmpty {
            let packInfo = StickerPackCollectionInfo(id: ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue, id: 0), flags: [], accessHash: 0, title: strings.Stickers_FavoriteStickers.uppercased(), shortName: "", thumbnail: nil, hash: 0, count: 0)
            for i in 0 ..< savedStickers.items.count {
                if let item = savedStickers.items[i].contents as? SavedStickerItem {
                    savedStickerIds.insert(item.file.fileId.id)
                    let index = ItemCollectionItemIndex(index: Int32(i), id: item.file.fileId.id)
                    let stickerItem = StickerPackItem(index: index, file: item.file, indexKeys: [])
                    entries.append(.sticker(index: ItemCollectionViewEntryIndex(collectionIndex: -3, collectionId: packInfo.id, itemIndex: index), stickerItem: stickerItem, stickerPackInfo: packInfo, canManagePeerSpecificPack: nil, theme: theme))
                }
            }
        }
        
        if let recentStickers = recentStickers, !recentStickers.items.isEmpty {
            let packInfo = StickerPackCollectionInfo(id: ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue, id: 0), flags: [], accessHash: 0, title: strings.Stickers_FrequentlyUsed.uppercased(), shortName: "", thumbnail: nil, hash: 0, count: 0)
            var addedCount = 0
            for i in 0 ..< recentStickers.items.count {
                if addedCount >= 20 {
                    break
                }
                if let item = recentStickers.items[i].contents as? RecentMediaItem, let file = item.media as? TelegramMediaFile, let mediaId = item.media.id {
                    if !savedStickerIds.contains(mediaId.id) {
                        let index = ItemCollectionItemIndex(index: Int32(i), id: mediaId.id)
                        let stickerItem = StickerPackItem(index: index, file: file, indexKeys: [])
                        entries.append(.sticker(index: ItemCollectionViewEntryIndex(collectionIndex: -2, collectionId: packInfo.id, itemIndex: index), stickerItem: stickerItem, stickerPackInfo: packInfo, canManagePeerSpecificPack: nil, theme: theme))
                        addedCount += 1
                    }
                }
            }
        }
        
        var canManagePeerSpecificPack = false
        if case .available(_, false) = canInstallPeerSpecificPack {
            canManagePeerSpecificPack = true
        }
        
        if peerSpecificPack == nil && canManagePeerSpecificPack {
            entries.append(.peerSpecificSetup(theme: theme, strings: strings, dismissed: false))
        }
        
        if let peerSpecificPack = peerSpecificPack {
            for i in 0 ..< peerSpecificPack.items.count {
                let packInfo = StickerPackCollectionInfo(id: ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue, id: 0), flags: [], accessHash: 0, title: strings.Stickers_GroupStickers, shortName: "", thumbnail: nil, hash: 0, count: 0)
                
                if let item = peerSpecificPack.items[i] as? StickerPackItem {
                    let index = ItemCollectionItemIndex(index: Int32(i), id: item.file.fileId.id)
                    let stickerItem = StickerPackItem(index: index, file: item.file, indexKeys: [])
                    entries.append(.sticker(index: ItemCollectionViewEntryIndex(collectionIndex: -1, collectionId: packInfo.id, itemIndex: index), stickerItem: stickerItem, stickerPackInfo: packInfo, canManagePeerSpecificPack: canManagePeerSpecificPack, theme: theme))
                }
            }
        }
    }
    
    for entry in view.entries {
        if let item = entry.item as? StickerPackItem {
            entries.append(.sticker(index: entry.index, stickerItem: item, stickerPackInfo: stickerPackInfos[entry.index.collectionId], canManagePeerSpecificPack: false, theme: theme))
        }
    }
    
    if view.higher == nil {
        if peerSpecificPack == nil, case .available(_, true) = canInstallPeerSpecificPack {
            entries.append(.peerSpecificSetup(theme: theme, strings: strings, dismissed: true))
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
    case initial
    case generic
    case scroll
    case navigate(ItemCollectionViewEntryIndex?, ItemCollectionId?)
}

final class ChatMediaInputNodeInteraction {
    let navigateToCollectionId: (ItemCollectionId) -> Void
    let openSettings: () -> Void
    let toggleSearch: (Bool, ChatMediaInputSearchMode?) -> Void
    let openPeerSpecificSettings: () -> Void
    let dismissPeerSpecificSettings: () -> Void
    let clearRecentlyUsedStickers: () -> Void
    
    var stickerSettings: ChatInterfaceStickerSettings?
    var highlightedStickerItemCollectionId: ItemCollectionId?
    var highlightedItemCollectionId: ItemCollectionId?
    var previewedStickerPackItem: StickerPreviewPeekItem?
    var appearanceTransition: CGFloat = 1.0
    
    init(navigateToCollectionId: @escaping (ItemCollectionId) -> Void, openSettings: @escaping () -> Void, toggleSearch: @escaping (Bool, ChatMediaInputSearchMode?) -> Void, openPeerSpecificSettings: @escaping () -> Void, dismissPeerSpecificSettings: @escaping () -> Void, clearRecentlyUsedStickers: @escaping () -> Void) {
        self.navigateToCollectionId = navigateToCollectionId
        self.openSettings = openSettings
        self.toggleSearch = toggleSearch
        self.openPeerSpecificSettings = openPeerSpecificSettings
        self.dismissPeerSpecificSettings = dismissPeerSpecificSettings
        self.clearRecentlyUsedStickers = clearRecentlyUsedStickers
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

private enum ChatMediaInputPaneType {
    case gifs
    case stickers
    case trending
}

private struct ChatMediaInputPaneArrangement {
    let panes: [ChatMediaInputPaneType]
    let currentIndex: Int
    let indexTransition: CGFloat
    
    func withIndexTransition(_ indexTransition: CGFloat) -> ChatMediaInputPaneArrangement {
        return ChatMediaInputPaneArrangement(panes: self.panes, currentIndex: currentIndex, indexTransition: indexTransition)
    }
    
    func withCurrentIndex(_ currentIndex: Int) -> ChatMediaInputPaneArrangement {
        return ChatMediaInputPaneArrangement(panes: self.panes, currentIndex: currentIndex, indexTransition: self.indexTransition)
    }
}

private final class CollectionListContainerNode: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in self.view.subviews {
            if let result = subview.hitTest(point.offsetBy(dx: -subview.frame.minX, dy: -subview.frame.minY), with: event) {
                return result
            }
        }
        return nil
    }
}

final class ChatMediaInputNode: ChatInputNode {
    private let context: AccountContext
    private let peerId: PeerId?
    private let controllerInteraction: ChatControllerInteraction
    private let gifPaneIsActiveUpdated: (Bool) -> Void
    
    private var inputNodeInteraction: ChatMediaInputNodeInteraction!
    
    private let collectionListPanel: ASDisplayNode
    private let collectionListSeparator: ASDisplayNode
    private let collectionListContainer: CollectionListContainerNode
    
    private let disposable = MetaDisposable()
    
    private let listView: ListView
    private var searchContainerNode: PaneSearchContainerNode?
    private let searchContainerNodeLoadedDisposable = MetaDisposable()
    
    private let stickerPane: ChatMediaInputStickerPane
    private var animatingStickerPaneOut = false
    private let gifPane: ChatMediaInputGifPane
    private var animatingGifPaneOut = false
    private let trendingPane: ChatMediaInputTrendingPane
    private var animatingTrendingPaneOut = false
    
    private var panRecognizer: UIPanGestureRecognizer?
    
    private let itemCollectionsViewPosition = Promise<StickerPacksCollectionPosition>()
    private var currentStickerPacksCollectionPosition: StickerPacksCollectionPosition?
    private var currentView: ItemCollectionsView?
    private let dismissedPeerSpecificStickerPack = Promise<Bool>()
    
    private var validLayout: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, ChatPresentationInterfaceState, DeviceMetrics, Bool)?
    private var paneArrangement: ChatMediaInputPaneArrangement
    private var initializedArrangement = false
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var fontSize: PresentationFontSize
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    private let _ready = Promise<Void>()
    private var didSetReady = false
    override var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    init(context: AccountContext, peerId: PeerId?, controllerInteraction: ChatControllerInteraction, chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, gifPaneIsActiveUpdated: @escaping (Bool) -> Void) {
        self.context = context
        self.peerId = peerId
        self.controllerInteraction = controllerInteraction
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        self.gifPaneIsActiveUpdated = gifPaneIsActiveUpdated
        
        self.themeAndStringsPromise = Promise((theme, strings))
        
        self.collectionListPanel = ASDisplayNode()
        self.collectionListPanel.clipsToBounds = true
        
        if case let .color(color) = chatWallpaper, UIColor(rgb: color).isEqual(theme.chat.inputPanel.panelBackgroundColorNoWallpaper) {
            self.collectionListPanel.backgroundColor = theme.chat.inputPanel.panelBackgroundColorNoWallpaper
        } else {
            self.collectionListPanel.backgroundColor = theme.chat.inputPanel.panelBackgroundColor
        }
        
        self.collectionListSeparator = ASDisplayNode()
        self.collectionListSeparator.isLayerBacked = true
        self.collectionListSeparator.backgroundColor = theme.chat.inputMediaPanel.panelSeparatorColor
        
        self.collectionListContainer = CollectionListContainerNode()
        self.collectionListContainer.clipsToBounds = true
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(Double.pi / 2.0), 0.0, 0.0, 1.0)
        
        var paneDidScrollImpl: ((ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void)?
        var fixPaneScrollImpl: ((ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void)?
        var openGifContextMenuImpl: ((FileMediaReference, ASDisplayNode, CGRect, ContextGesture) -> Void)?
        
        self.stickerPane = ChatMediaInputStickerPane(theme: theme, strings: strings, paneDidScroll: { pane, state, transition in
            paneDidScrollImpl?(pane, state, transition)
        }, fixPaneScroll: { pane, state in
            fixPaneScrollImpl?(pane, state)
        })
        self.gifPane = ChatMediaInputGifPane(account: context.account, theme: theme, strings: strings, controllerInteraction: controllerInteraction, paneDidScroll: { pane, state, transition in
            paneDidScrollImpl?(pane, state, transition)
        }, fixPaneScroll: { pane, state in
            fixPaneScrollImpl?(pane, state)
        }, openGifContextMenu: { fileReference, sourceNode, sourceRect, gesture in
            openGifContextMenuImpl?(fileReference, sourceNode, sourceRect, gesture)
        })
        
        var getItemIsPreviewedImpl: ((StickerPackItem) -> Bool)?
        self.trendingPane = ChatMediaInputTrendingPane(context: context, controllerInteraction: controllerInteraction, getItemIsPreviewed: { item in
            return getItemIsPreviewedImpl?(item) ?? false
        })
        
        self.paneArrangement = ChatMediaInputPaneArrangement(panes: [.gifs, .stickers, .trending], currentIndex: 1, indexTransition: 0.0)
        
        super.init()
        
        self.inputNodeInteraction = ChatMediaInputNodeInteraction(navigateToCollectionId: { [weak self] collectionId in
            if let strongSelf = self, let currentView = strongSelf.currentView, (collectionId != strongSelf.inputNodeInteraction.highlightedItemCollectionId || true) {
                var index: Int32 = 0
                if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue {
                    strongSelf.setCurrentPane(.gifs, transition: .animated(duration: 0.25, curve: .spring))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue {
                    strongSelf.setCurrentPane(.trending, transition: .animated(duration: 0.25, curve: .spring))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring), collectionIdHint: collectionId.namespace)
                    strongSelf.currentStickerPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring), collectionIdHint: collectionId.namespace)
                    strongSelf.currentStickerPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
                    strongSelf.currentStickerPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
                    for (id, _, _) in currentView.collectionInfos {
                        if id.namespace == collectionId.namespace {
                            if id == collectionId {
                                let itemIndex = ItemCollectionViewEntryIndex.lowerBound(collectionIndex: index, collectionId: id)
                                strongSelf.currentStickerPacksCollectionPosition = .navigate(index: itemIndex, collectionId: nil)
                                strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: itemIndex, collectionId: nil)))
                                break
                            }
                            index += 1
                        }
                    }
                }
            }
        }, openSettings: { [weak self] in
            if let strongSelf = self {
                let controller = installedStickerPacksController(context: context, mode: .modal)
                controller.navigationPresentation = .modal
                strongSelf.controllerInteraction.navigationController()?.pushViewController(controller)
            }
        }, toggleSearch: { [weak self] value, searchMode in
            if let strongSelf = self {
                if let searchMode = searchMode, value {
                    var searchContainerNode: PaneSearchContainerNode?
                    if let current = strongSelf.searchContainerNode {
                        searchContainerNode = current
                    } else {
                        searchContainerNode = PaneSearchContainerNode(context: strongSelf.context, theme: strongSelf.theme, strings: strongSelf.strings, controllerInteraction: strongSelf.controllerInteraction, inputNodeInteraction: strongSelf.inputNodeInteraction, mode: searchMode, trendingGifsPromise: strongSelf.gifPane.trendingPromise, cancel: {
                            self?.searchContainerNode?.deactivate()
                            self?.inputNodeInteraction.toggleSearch(false, nil)
                        })
                        strongSelf.searchContainerNode = searchContainerNode
                    }
                    if let searchContainerNode = searchContainerNode {
                        strongSelf.searchContainerNodeLoadedDisposable.set((searchContainerNode.ready
                        |> deliverOnMainQueue).start(next: {
                            if let strongSelf = self {
                                strongSelf.controllerInteraction.updateInputMode { current in
                                    switch current {
                                        case let .media(mode, _):
                                            return .media(mode: mode, expanded: .search(searchMode))
                                        default:
                                            return current
                                    }
                                }
                            }
                        }))
                    }
                } else {
                    strongSelf.controllerInteraction.updateInputMode { current in
                        switch current {
                            case let .media(mode, _):
                                return .media(mode: mode, expanded: nil)
                            default:
                                return current
                        }
                    }
                }
            }
        }, openPeerSpecificSettings: { [weak self] in
            guard let peerId = peerId, peerId.namespace == Namespaces.Peer.CloudChannel else {
                return
            }
            
            let _ = (context.account.postbox.transaction { transaction -> StickerPackCollectionInfo? in
                return (transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData)?.stickerPack
            }
            |> deliverOnMainQueue).start(next: { info in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controllerInteraction.presentController(groupStickerPackSetupController(context: context, peerId: peerId, currentPackInfo: info), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
        }, dismissPeerSpecificSettings: { [weak self] in
            self?.dismissPeerSpecificPackSetup()
        }, clearRecentlyUsedStickers: { [weak self] in
            if let strongSelf = self {
                let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: strongSelf.theme, fontSize: strongSelf.fontSize))
                var items: [ActionSheetItem] = []
                items.append(ActionSheetButtonItem(title: strongSelf.strings.Stickers_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    let _ = (context.account.postbox.transaction { transaction in
                        clearRecentlyUsedStickers(transaction: transaction)
                    }).start()
                }))
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                strongSelf.controllerInteraction.presentController(actionSheet, nil)
            }
        })
        
        getItemIsPreviewedImpl = { [weak self] item in
            if let strongSelf = self {
                return strongSelf.inputNodeInteraction.previewedStickerPackItem == .pack(item)
            }
            return false
        }
        
        self.backgroundColor = theme.chat.inputMediaPanel.stickersBackgroundColor
        
        self.collectionListPanel.addSubnode(self.listView)
        self.collectionListContainer.addSubnode(self.collectionListPanel)
        self.collectionListContainer.addSubnode(self.collectionListSeparator)
        self.addSubnode(self.collectionListContainer)
        
        let itemCollectionsView = self.itemCollectionsViewPosition.get()
        |> distinctUntilChanged
        |> mapToSignal { position -> Signal<(ItemCollectionsView, StickerPacksCollectionUpdate), NoError> in
            switch position {
                case .initial:
                    var firstTime = true
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 50)
                    |> map { view -> (ItemCollectionsView, StickerPacksCollectionUpdate) in
                        let update: StickerPacksCollectionUpdate
                        if firstTime {
                            firstTime = false
                            update = .initial
                        } else {
                            update = .generic
                        }
                        return (view, update)
                    }
                case let .scroll(aroundIndex):
                    var firstTime = true
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: aroundIndex, count: 300)
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
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: index, count: 300)
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
        self.inputNodeInteraction.stickerSettings = self.controllerInteraction.stickerSettings
        
        let previousEntries = Atomic<([ChatMediaInputPanelEntry], [ChatMediaInputGridEntry])>(value: ([], []))
        
        let inputNodeInteraction = self.inputNodeInteraction!
        let peerSpecificPack: Signal<(PeerSpecificPackData?, CanInstallPeerSpecificPack), NoError>
        if let peerId = peerId {
            self.dismissedPeerSpecificStickerPack.set(context.account.postbox.transaction { transaction -> Bool in
                guard let state = transaction.getPeerChatInterfaceState(peerId) as? ChatInterfaceState else {
                    return false
                }
                if state.messageActionsState.closedPeerSpecificPackSetup {
                    return true
                }
                
                return false
            })
            peerSpecificPack = combineLatest(peerSpecificStickerPack(postbox: context.account.postbox, network: context.account.network, peerId: peerId), context.account.postbox.multiplePeersView([peerId]), self.dismissedPeerSpecificStickerPack.get())
            |> map { packData, peersView, dismissedPeerSpecificPack -> (PeerSpecificPackData?, CanInstallPeerSpecificPack) in
                if let peer = peersView.peers[peerId] {
                    var canInstall: CanInstallPeerSpecificPack = .none
                    if packData.canSetup {
                        canInstall = .available(peer: peer, dismissed: dismissedPeerSpecificPack)
                    }
                    if let (info, items) = packData.packInfo {
                        return (PeerSpecificPackData(peer: peer, info: info, items: items), canInstall)
                    } else {
                        return (nil, canInstall)
                    }
                }
                return (nil, .none)
            }
        } else {
            peerSpecificPack = .single((nil, .none))
        }
        
        let trendingInteraction = TrendingPaneInteraction(installPack: { [weak self] info in
            guard let strongSelf = self, let info = info as? StickerPackCollectionInfo else {
                return
            }
            let _ = (loadedStickerPack(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, reference: .id(id: info.id.id, accessHash: info.accessHash), forceActualized: false)
            |> mapToSignal { result -> Signal<Void, NoError> in
                switch result {
                    case let .result(info, items, installed):
                        if installed {
                            return .complete()
                        } else {
                            return addStickerPackInteractively(postbox: strongSelf.context.account.postbox, info: info, items: items)
                        }
                    case .fetching:
                        break
                    case .none:
                        break
                }
                return .complete()
            }
            |> deliverOnMainQueue).start(completed: {
                guard let strongSelf = self else {
                    return
                }
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                strongSelf.controllerInteraction.presentController(OverlayStatusController(theme: presentationData.theme, type: .success), nil)
            })
        }, openPack: { [weak self] info in
            guard let strongSelf = self, let info = info as? StickerPackCollectionInfo else {
                return
            }
            strongSelf.view.window?.endEditing(true)
            let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
            let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controllerInteraction.navigationController(), sendSticker: { fileReference, sourceNode, sourceRect in
                if let strongSelf = self {
                    return strongSelf.controllerInteraction.sendSticker(fileReference, false, sourceNode, sourceRect)
                } else {
                    return false
                }
            })
            strongSelf.controllerInteraction.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }, getItemIsPreviewed: { item in
            return getItemIsPreviewedImpl?(item) ?? false
        })
        
        let previousView = Atomic<ItemCollectionsView?>(value: nil)
        let transitionQueue = Queue()
        let transitions = combineLatest(queue: transitionQueue, itemCollectionsView, peerSpecificPack, context.account.viewTracker.featuredStickerPacks(), self.themeAndStringsPromise.get())
        |> map { viewAndUpdate, peerSpecificPack, trendingPacks, themeAndStrings -> (ItemCollectionsView, ChatMediaInputPanelTransition, Bool, ChatMediaInputGridTransition, Bool) in
            let (view, viewUpdate) = viewAndUpdate
            let previous = previousView.swap(view)
            var update = viewUpdate
            if previous === view {
                update = .generic
            }
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
            
            var installedPacks = Set<ItemCollectionId>()
            for info in view.collectionInfos {
                installedPacks.insert(info.0)
            }
            
            var hasUnreadTrending = false
            for pack in trendingPacks {
                if pack.unread {
                    hasUnreadTrending = true
                    break
                }
            }
            
            let panelEntries = chatMediaInputPanelEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, peerSpecificPack: peerSpecificPack.0, canInstallPeerSpecificPack: peerSpecificPack.1, hasUnreadTrending: hasUnreadTrending, theme: theme)
            var gridEntries = chatMediaInputGridEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, peerSpecificPack: peerSpecificPack.0, canInstallPeerSpecificPack: peerSpecificPack.1, strings: strings, theme: theme)
            
            if view.higher == nil {
                var index = 0
                for item in trendingPacks {
                    if !installedPacks.contains(item.info.id) {
                        gridEntries.append(.trending(TrendingPaneEntry(index: index, info: item.info, theme: theme, strings: strings, topItems: item.topItems, installed: installedPacks.contains(item.info.id), unread: item.unread, topSeparator: true)))
                        index += 1
                    }
                }
            }
            
            let (previousPanelEntries, previousGridEntries) = previousEntries.swap((panelEntries, gridEntries))
            return (view, preparedChatMediaInputPanelEntryTransition(context: context, from: previousPanelEntries, to: panelEntries, inputNodeInteraction: inputNodeInteraction), previousPanelEntries.isEmpty, preparedChatMediaInputGridEntryTransition(account: context.account, view: view, from: previousGridEntries, to: gridEntries, update: update, interfaceInteraction: controllerInteraction, inputNodeInteraction: inputNodeInteraction, trendingInteraction: trendingInteraction), previousGridEntries.isEmpty)
        }
        
        self.disposable.set((transitions
        |> deliverOnMainQueue).start(next: { [weak self] (view, panelTransition, panelFirstTime, gridTransition, gridFirstTime) in
            if let strongSelf = self {
                strongSelf.currentView = view
                strongSelf.enqueuePanelTransition(panelTransition, firstTime: panelFirstTime, thenGridTransition: gridTransition, gridFirstTime: gridFirstTime)
                if !strongSelf.initializedArrangement {
                    strongSelf.initializedArrangement = true
                    var currentPane = strongSelf.paneArrangement.panes[strongSelf.paneArrangement.currentIndex]
                    if view.entries.isEmpty {
                        currentPane = .trending
                    }
                    if currentPane != strongSelf.paneArrangement.panes[strongSelf.paneArrangement.currentIndex] {
                        strongSelf.setCurrentPane(currentPane, transition: .immediate)
                    }
                }
            }
        }))
        
        self.stickerPane.gridNode.visibleItemsUpdated = { [weak self] visibleItems in
            if let strongSelf = self {
                var topVisibleCollectionId: ItemCollectionId?
                
                if let topVisibleSection = visibleItems.topSectionVisible as? ChatMediaInputStickerGridSection {
                    topVisibleCollectionId = topVisibleSection.collectionId
                } else if let topVisible = visibleItems.topVisible {
                    if let item = topVisible.1 as? ChatMediaInputStickerGridItem {
                        topVisibleCollectionId = item.index.collectionId
                    } else if let _ = topVisible.1 as? StickerPanePeerSpecificSetupGridItem {
                        topVisibleCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue, id: 0)
                    }
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
                        var position: StickerPacksCollectionPosition?
                        if let bottomItem = bottomItem as? ChatMediaInputStickerGridItem {
                            position = clipScrollPosition(.scroll(aroundIndex: bottomItem.index))
                        }
                        
                        if let position = position, strongSelf.currentStickerPacksCollectionPosition != position {
                            strongSelf.currentStickerPacksCollectionPosition = position
                            strongSelf.itemCollectionsViewPosition.set(.single(position))
                        }
                    }
                }
            }
        }
        
        self.currentStickerPacksCollectionPosition = .initial
        self.itemCollectionsViewPosition.set(.single(.initial))
        
        self.stickerPane.inputNodeInteraction = self.inputNodeInteraction
        self.gifPane.inputNodeInteraction = self.inputNodeInteraction
        
        paneDidScrollImpl = { [weak self] pane, state, transition in
            self?.updatePaneDidScroll(pane: pane, state: state, transition: transition)
        }
        
        fixPaneScrollImpl = { [weak self] pane, state in
            self?.fixPaneScroll(pane: pane, state: state)
        }
        
        openGifContextMenuImpl = { [weak self] fileReference, sourceNode, sourceRect, gesture in
            guard let strongSelf = self else {
                return
            }
            
            let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: PeerId(namespace: 0, id: 0), namespace: Namespaces.Message.Local, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [fileReference.media], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [])
            
            let gallery = GalleryController(context: strongSelf.context, source: .standaloneMessage(message), streamSingleVideo: true, replaceRootController: { _, _ in
            }, baseNavigationController: nil)
            gallery.setHintWillBePresentedInPreviewingContext(true)
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: strings.MediaPicker_Send, icon: { _ in nil }, action: { _, f in
                f(.default)
                self?.controllerInteraction.sendGif(fileReference, sourceNode, sourceRect)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { _ in nil }, action: { _, f in
                f(.dismissWithoutContent)
                
                guard let strongSelf = self else {
                    return
                }
                let _ = removeSavedGif(postbox: strongSelf.context.account.postbox, mediaId: fileReference.media.fileId).start()
            })))
            
            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            
            let contextController = ContextController(account: strongSelf.context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceNode: sourceNode, sourceRect: sourceRect)), items: .single(items), reactionItems: [], gesture: gesture)
            strongSelf.controllerInteraction.presentGlobalOverlayController(contextController, nil)
        }
    }
    
    deinit {
        self.disposable.dispose()
        self.searchContainerNodeLoadedDisposable.dispose()
    }
    
    private func updateThemeAndStrings(chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            
            if case let .color(color) = chatWallpaper, UIColor(rgb: color).isEqual(theme.chat.inputPanel.panelBackgroundColorNoWallpaper) {
                self.collectionListPanel.backgroundColor = theme.chat.inputPanel.panelBackgroundColorNoWallpaper
            } else {
                self.collectionListPanel.backgroundColor = theme.chat.inputPanel.panelBackgroundColor
            }
            
            self.collectionListSeparator.backgroundColor = theme.chat.inputMediaPanel.panelSeparatorColor
            self.backgroundColor = theme.chat.inputMediaPanel.stickersBackgroundColor
            
            self.searchContainerNode?.updateThemeAndStrings(theme: theme, strings: strings)
            
            self.stickerPane.updateThemeAndStrings(theme: theme, strings: strings)
            self.gifPane.updateThemeAndStrings(theme: theme, strings: strings)
            self.trendingPane.updateThemeAndStrings(theme: theme, strings: strings)
            
            self.themeAndStringsPromise.set(.single((theme, strings)))
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
            if let strongSelf = self {
                let panes: [ASDisplayNode]
                if let searchContainerNode = strongSelf.searchContainerNode {
                    panes = []
                    
                    if let (itemNode, item) = searchContainerNode.itemAt(point: point.offsetBy(dx: -searchContainerNode.frame.minX, dy: -searchContainerNode.frame.minY)) {
                        if let item = item as? StickerPreviewPeekItem {
                            return strongSelf.context.account.postbox.transaction { transaction -> Bool in
                                return getIsStickerSaved(transaction: transaction, fileId: item.file.fileId)
                                }
                            |> deliverOnMainQueue
                            |> map { isStarred -> (ASDisplayNode, PeekControllerContent)? in
                                if let strongSelf = self {
                                    var menuItems: [PeekControllerMenuItem] = []
                                    menuItems = [
                                        PeekControllerMenuItem(title: strongSelf.strings.StickerPack_Send, color: .accent, font: .bold, action: { node, rect in
                                            if let strongSelf = self {
                                                return strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), false, node, rect)
                                            } else {
                                                return false
                                            }
                                        }),
                                        PeekControllerMenuItem(title: isStarred ? strongSelf.strings.Stickers_RemoveFromFavorites : strongSelf.strings.Stickers_AddToFavorites, color: isStarred ? .destructive : .accent, action: { _, _ in
                                            if let strongSelf = self {
                                                if isStarred {
                                                    let _ = removeSavedSticker(postbox: strongSelf.context.account.postbox, mediaId: item.file.fileId).start()
                                                } else {
                                                    let _ = addSavedSticker(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, file: item.file).start()
                                                }
                                            }
                                            return true
                                        }),
                                        PeekControllerMenuItem(title: strongSelf.strings.StickerPack_ViewPack, color: .accent, action: { _, _ in
                                            if let strongSelf = self {
                                                loop: for attribute in item.file.attributes {
                                                    switch attribute {
                                                    case let .Sticker(_, packReference, _):
                                                        if let packReference = packReference {
                                                            let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controllerInteraction.navigationController(), sendSticker: { file, sourceNode, sourceRect in
                                                                if let strongSelf = self {
                                                                    return strongSelf.controllerInteraction.sendSticker(file, false, sourceNode, sourceRect)
                                                                } else {
                                                                    return false
                                                                }
                                                            })
                                                            
                                                            strongSelf.controllerInteraction.navigationController()?.view.window?.endEditing(true)
                                                            strongSelf.controllerInteraction.presentController(controller, nil)
                                                        }
                                                        break loop
                                                    default:
                                                        break
                                                    }
                                                }
                                            }
                                            return true
                                        }),
                                        PeekControllerMenuItem(title: strongSelf.strings.Common_Cancel, color: .accent, font: .bold, action: { _, _ in return true })
                                    ]
                                    return (itemNode, StickerPreviewPeekContent(account: strongSelf.context.account, item: item, menu: menuItems))
                                } else {
                                    return nil
                                }
                            }
                        } else if let file = item as? FileMediaReference {
                            return nil
                            /*return .single((strongSelf, ChatContextResultPeekContent(account: strongSelf.context.account, contextResult: .internalReference(queryId: 0, id: "", type: "gif", title: nil, description: nil, image: nil, file: file.media, message: .auto(caption: "", entities: nil, replyMarkup: nil)), menu: [
                                PeekControllerMenuItem(title: strongSelf.strings.ShareMenu_Send, color: .accent, font: .bold, action: { node, rect in
                                    if let strongSelf = self {
                                        return strongSelf.controllerInteraction.sendGif(file, node, rect)
                                    } else {
                                        return false
                                    }
                                }),
                                PeekControllerMenuItem(title: strongSelf.strings.Preview_SaveGif, color: .accent, action: { _, _ in
                                    if let strongSelf = self {
                                        let _ = addSavedGif(postbox: strongSelf.context.account.postbox, fileReference: file).start()
                                    }
                                    return true
                                })
                            ])))*/
                        }
                    }
                } else {
                    panes = [strongSelf.gifPane, strongSelf.stickerPane, strongSelf.trendingPane]
                }
                let panelPoint = strongSelf.view.convert(point, to: strongSelf.collectionListPanel.view)
                if panelPoint.y < strongSelf.collectionListPanel.frame.maxY {
                    return .single(nil)
                }
                
                for pane in panes {
                    if pane.supernode != nil, pane.frame.contains(point) {
                        if let pane = pane as? ChatMediaInputGifPane {
                            if let (file, _) = pane.fileAt(point: point.offsetBy(dx: -pane.frame.minX, dy: -pane.frame.minY)) {
                                return nil
                                /*return .single((strongSelf, ChatContextResultPeekContent(account: strongSelf.context.account, contextResult: .internalReference(queryId: 0, id: "", type: "gif", title: nil, description: nil, image: nil, file: file.media, message: .auto(caption: "", entities: nil, replyMarkup: nil)), menu: [
                                    PeekControllerMenuItem(title: strongSelf.strings.ShareMenu_Send, color: .accent, font: .bold, action: { node, rect in
                                        if let strongSelf = self {
                                            return strongSelf.controllerInteraction.sendGif(file, node, rect)
                                        } else {
                                            return false
                                        }
                                    }),
                                    PeekControllerMenuItem(title: strongSelf.strings.Common_Delete, color: .destructive, action: { _, _ in
                                        if let strongSelf = self {
                                            let _ = removeSavedGif(postbox: strongSelf.context.account.postbox, mediaId: file.media.fileId).start()
                                        }
                                        return true
                                    })
                                ])))*/
                            }
                        } else if pane is ChatMediaInputStickerPane || pane is ChatMediaInputTrendingPane {
                            var itemNodeAndItem: (ASDisplayNode, StickerPackItem)?
                            if let pane = pane as? ChatMediaInputStickerPane {
                                itemNodeAndItem = pane.itemAt(point: point.offsetBy(dx: -pane.frame.minX, dy: -pane.frame.minY))
                            } else if let pane = pane as? ChatMediaInputTrendingPane {
                                itemNodeAndItem = pane.itemAt(point: point.offsetBy(dx: -pane.frame.minX, dy: -pane.frame.minY))
                            }
                            
                            if let (itemNode, item) = itemNodeAndItem {
                                return strongSelf.context.account.postbox.transaction { transaction -> Bool in
                                    return getIsStickerSaved(transaction: transaction, fileId: item.file.fileId)
                                }
                                |> deliverOnMainQueue
                                |> map { isStarred -> (ASDisplayNode, PeekControllerContent)? in
                                    if let strongSelf = self {
                                        var menuItems: [PeekControllerMenuItem] = []
                                        menuItems = [
                                            PeekControllerMenuItem(title: strongSelf.strings.StickerPack_Send, color: .accent, font: .bold, action: { node, rect in
                                                if let strongSelf = self {
                                                    return strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), false, node, rect)
                                                } else {
                                                    return false
                                                }
                                            }),
                                            PeekControllerMenuItem(title: isStarred ? strongSelf.strings.Stickers_RemoveFromFavorites : strongSelf.strings.Stickers_AddToFavorites, color: isStarred ? .destructive : .accent, action: { _, _ in
                                                if let strongSelf = self {
                                                    if isStarred {
                                                        let _ = removeSavedSticker(postbox: strongSelf.context.account.postbox, mediaId: item.file.fileId).start()
                                                    } else {
                                                        let _ = addSavedSticker(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, file: item.file).start()
                                                    }
                                                }
                                                return true
                                            }),
                                            PeekControllerMenuItem(title: strongSelf.strings.StickerPack_ViewPack, color: .accent, action: { _, _ in
                                                if let strongSelf = self {
                                                    loop: for attribute in item.file.attributes {
                                                        switch attribute {
                                                            case let .Sticker(_, packReference, _):
                                                                if let packReference = packReference {
                                                                    let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controllerInteraction.navigationController(), sendSticker: { file, sourceNode, sourceRect in
                                                                                                                                               if let strongSelf = self {
                                                                                                                                                   return strongSelf.controllerInteraction.sendSticker(file, false, sourceNode, sourceRect)
                                                                                                                                               } else {
                                                                                                                                                   return false
                                                                                                                                               }
                                                                    })
                                                          
                                                                    strongSelf.controllerInteraction.navigationController()?.view.window?.endEditing(true)
                                                                    strongSelf.controllerInteraction.presentController(controller, nil)
                                                                }
                                                                break loop
                                                            default:
                                                                break
                                                        }
                                                    }
                                                }
                                                return true
                                            }),
                                            PeekControllerMenuItem(title: strongSelf.strings.Common_Cancel, color: .accent, font: .bold, action: { _, _ in return true })
                                        ]
                                        return (itemNode, StickerPreviewPeekContent(account: strongSelf.context.account, item: .pack(item), menu: menuItems))
                                    } else {
                                        return nil
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return nil
        }, present: { [weak self] content, sourceNode in
            if let strongSelf = self {
                let controller = PeekController(theme: PeekControllerTheme(presentationTheme: strongSelf.theme), content: content, sourceNode: {
                    return sourceNode
                })
                strongSelf.controllerInteraction.presentGlobalOverlayController(controller, nil)
                return controller
            }
            return nil
        }, updateContent: { [weak self] content in
            if let strongSelf = self {
                var item: StickerPreviewPeekItem?
                if let content = content as? StickerPreviewPeekContent {
                    item = content.item
                }
                strongSelf.updatePreviewingItem(item: item, animated: true)
            }
        }))
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.panRecognizer = panRecognizer
        self.view.addGestureRecognizer(panRecognizer)
    }
    
    private func setCurrentPane(_ pane: ChatMediaInputPaneType, transition: ContainedViewLayoutTransition, collectionIdHint: Int32? = nil) {
        var transition = transition
        
        if let index = self.paneArrangement.panes.firstIndex(of: pane), index != self.paneArrangement.currentIndex {
            let previousGifPanelWasActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .gifs
            //let previousTrendingPanelWasActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .trending
            self.paneArrangement = self.paneArrangement.withIndexTransition(0.0).withCurrentIndex(index)
            let updatedGifPanelWasActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .gifs
            //let updatedTrendingPanelIsActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .trending
            
            /*if updatedTrendingPanelIsActive != previousTrendingPanelWasActive {
                transition = .immediate
            }*/
            
            if let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible) = self.validLayout {
                let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: transition, interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible)
                self.updateAppearanceTransition(transition: transition)
            }
            if updatedGifPanelWasActive != previousGifPanelWasActive {
                self.gifPaneIsActiveUpdated(updatedGifPanelWasActive)
            }
            switch pane {
                case .gifs:
                    self.setHighlightedItemCollectionId(ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue, id: 0))
                case .stickers:
                    if let highlightedStickerCollectionId = self.inputNodeInteraction.highlightedStickerItemCollectionId {
                        self.setHighlightedItemCollectionId(highlightedStickerCollectionId)
                    } else if let collectionIdHint = collectionIdHint {
                        self.setHighlightedItemCollectionId(ItemCollectionId(namespace: collectionIdHint, id: 0))
                    }
                case .trending:
                    self.setHighlightedItemCollectionId(ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue, id: 0))
            }
            /*if updatedTrendingPanelIsActive != previousTrendingPanelWasActive {
                self.controllerInteraction.updateInputMode { current in
                    switch current {
                    case let .media(mode, _):
                        if updatedTrendingPanelIsActive {
                            return .media(mode: mode, expanded: .content)
                        } else {
                            return .media(mode: mode, expanded: nil)
                        }
                    default:
                        return current
                    }
                }
            }*/
        } else {
            if let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible) = self.validLayout {
                let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .animated(duration: 0.25, curve: .spring), interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible)
            }
        }
    }
    
    private func setHighlightedItemCollectionId(_ collectionId: ItemCollectionId) {
        if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue {
            if self.paneArrangement.panes[self.paneArrangement.currentIndex] == .gifs {
                self.inputNodeInteraction.highlightedItemCollectionId = collectionId
            }
        } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue {
            if self.paneArrangement.panes[self.paneArrangement.currentIndex] == .trending {
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
            } else if let itemNode = itemNode as? ChatMediaInputTrendingItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputPeerSpecificItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            }
        }
        
        if let currentView = self.currentView, let firstVisibleCollectionId = firstVisibleCollectionId, !ensuredNodeVisible {
            let targetIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == collectionId })
            let firstVisibleIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == firstVisibleCollectionId })
            if let targetIndex = targetIndex, let firstVisibleIndex = firstVisibleIndex {
                let toRight = targetIndex > firstVisibleIndex
                self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [], scrollToItem: ListViewScrollToItem(index: targetIndex, position: toRight ? .bottom(0.0) : .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: toRight ? .Down : .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil)
            }
        }
    }
    
    private func currentCollectionListPanelOffset() -> CGFloat {
        let paneOffsets = self.paneArrangement.panes.map { pane -> CGFloat in
            switch pane {
                case .stickers:
                    return self.stickerPane.collectionListPanelOffset
                case .gifs:
                    return self.gifPane.collectionListPanelOffset
                case .trending:
                    return self.trendingPane.collectionListPanelOffset
            }
        }
        
        let mainOffset = paneOffsets[self.paneArrangement.currentIndex]
        if self.paneArrangement.indexTransition.isZero {
            return mainOffset
        } else {
            var sideOffset: CGFloat?
            if self.paneArrangement.indexTransition < 0.0 {
                if self.paneArrangement.currentIndex != 0 {
                    sideOffset = paneOffsets[self.paneArrangement.currentIndex - 1]
                }
            } else {
                if self.paneArrangement.currentIndex != paneOffsets.count - 1 {
                    sideOffset = paneOffsets[self.paneArrangement.currentIndex + 1]
                }
            }
            if let sideOffset = sideOffset {
                let interpolator = CGFloat.interpolator()
                let value = interpolator(mainOffset, sideOffset, abs(self.paneArrangement.indexTransition)) as! CGFloat
                return value
            } else {
                return mainOffset
            }
        }
    }
    
    private func updateAppearanceTransition(transition: ContainedViewLayoutTransition) {
        var value: CGFloat = 1.0 - abs(self.currentCollectionListPanelOffset() / 41.0)
        value = min(1.0, max(0.0, value))
        
        self.inputNodeInteraction.appearanceTransition = max(0.1, value)
        transition.updateAlpha(node: self.listView, alpha: value)
        self.listView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMediaInputStickerPackItemNode {
                itemNode.updateAppearanceTransition(transition: transition)
            } else if let itemNode = itemNode as? ChatMediaInputMetaSectionItemNode {
                itemNode.updateAppearanceTransition(transition: transition)
            } else if let itemNode = itemNode as? ChatMediaInputRecentGifsItemNode {
                itemNode.updateAppearanceTransition(transition: transition)
            } else if let itemNode = itemNode as? ChatMediaInputTrendingItemNode {
                itemNode.updateAppearanceTransition(transition: transition)
            } else if let itemNode = itemNode as? ChatMediaInputPeerSpecificItemNode {
                itemNode.updateAppearanceTransition(transition: transition)
            } else if let itemNode = itemNode as? ChatMediaInputSettingsItemNode {
                itemNode.updateAppearanceTransition(transition: transition)
            }
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool) -> (CGFloat, CGFloat) {
        var searchMode: ChatMediaInputSearchMode?
        if let (_, _, _, _, _, _, _, _, interfaceState, _, _) = self.validLayout, case let .media(_, maybeExpanded) = interfaceState.inputMode, let expanded = maybeExpanded, case let .search(mode) = expanded {
            searchMode = mode
        }
        
        let wasVisible = self.validLayout?.10 ?? false
        
        self.validLayout = (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible)
        
        if self.theme !== interfaceState.theme || self.strings !== interfaceState.strings {
            self.updateThemeAndStrings(chatWallpaper: interfaceState.chatWallpaper, theme: interfaceState.theme, strings: interfaceState.strings)
        }
        
        var displaySearch = false
        let separatorHeight = UIScreenPixel
        let panelHeight: CGFloat
        
        var isExpanded: Bool = false
        if case let .media(_, maybeExpanded) = interfaceState.inputMode, let expanded = maybeExpanded {
            isExpanded = true
            switch expanded {
                case .content:
                    panelHeight = maximumHeight
                case let .search(mode):
                    panelHeight = maximumHeight
                    displaySearch = true
                    searchMode = mode
            }
            self.stickerPane.collectionListPanelOffset = 0.0
            self.gifPane.collectionListPanelOffset = 0.0
            self.trendingPane.collectionListPanelOffset = 0.0
            self.updateAppearanceTransition(transition: transition)
        } else {
            panelHeight = standardInputHeight
        }
        
        if displaySearch {
            if let searchContainerNode = self.searchContainerNode {
                let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: -inputPanelHeight), size: CGSize(width: width, height: panelHeight + inputPanelHeight))
                if searchContainerNode.supernode != nil {
                    transition.updateFrame(node: searchContainerNode, frame: containerFrame)
                    searchContainerNode.updateLayout(size: containerFrame.size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: transition)
                } else {
                    self.searchContainerNode = searchContainerNode
                    self.insertSubnode(searchContainerNode, belowSubnode: self.collectionListContainer)
                    searchContainerNode.frame = containerFrame
                    searchContainerNode.updateLayout(size: containerFrame.size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: .immediate)
                    var placeholderNode: PaneSearchBarPlaceholderNode?
                    if let searchMode = searchMode {
                        switch searchMode {
                            case .gif:
                                placeholderNode = self.gifPane.searchPlaceholderNode
                            case .sticker:
                                self.stickerPane.gridNode.forEachItemNode { itemNode in
                                    if let itemNode = itemNode as? PaneSearchBarPlaceholderNode {
                                        placeholderNode = itemNode
                                    }
                                }
                        }
                    }
                    
                    if let placeholderNode = placeholderNode {
                        searchContainerNode.animateIn(from: placeholderNode, transition: transition, completion: { [weak self] in
                            self?.gifPane.removeFromSupernode()
                        })
                    }
                }
            }
        }
        
        let contentVerticalOffset: CGFloat = displaySearch ? -(inputPanelHeight + 41.0) : 0.0
        
        let collectionListPanelOffset = self.currentCollectionListPanelOffset()
        
        transition.updateFrame(node: self.collectionListContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: contentVerticalOffset), size: CGSize(width: width, height: max(0.0, 41.0 + UIScreenPixel))))
        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: collectionListPanelOffset), size: CGSize(width: width, height: 41.0)))
        transition.updateFrame(node: self.collectionListSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 41.0 + collectionListPanelOffset), size: CGSize(width: width, height: separatorHeight)))
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: 41.0, height: width)
        transition.updatePosition(node: self.listView, position: CGPoint(x: width / 2.0, y: (41.0 - collectionListPanelOffset) / 2.0))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: 41.0, height: width), insets: UIEdgeInsets(top: 4.0 + leftInset, left: 0.0, bottom: 4.0 + rightInset, right: 0.0), duration: duration, curve: curve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        var visiblePanes: [(ChatMediaInputPaneType, CGFloat)] = []
        
        var paneIndex = 0
        for pane in self.paneArrangement.panes {
            let paneOrigin = CGFloat(paneIndex - self.paneArrangement.currentIndex) * width - self.paneArrangement.indexTransition * width
            if paneOrigin.isLess(than: width) && CGFloat(0.0).isLess(than: (paneOrigin + width)) {
                visiblePanes.append((pane, paneOrigin))
            }
            paneIndex += 1
        }
        
        for (pane, paneOrigin) in visiblePanes {
            let paneFrame = CGRect(origin: CGPoint(x: paneOrigin + leftInset, y: 0.0), size: CGSize(width: width - leftInset - rightInset, height: panelHeight))
            switch pane {
                case .gifs:
                    if self.gifPane.supernode == nil  {
                        if !displaySearch {
                            self.insertSubnode(self.gifPane, belowSubnode: self.collectionListContainer)
                            if self.searchContainerNode == nil {
                                self.gifPane.frame = CGRect(origin: CGPoint(x: -width, y: 0.0), size: CGSize(width: width, height: panelHeight))
                            }
                        }
                    }
                    if self.gifPane.frame != paneFrame {
                        self.gifPane.layer.removeAnimation(forKey: "position")
                        transition.updateFrame(node: self.gifPane, frame: paneFrame)
                    }
                case .stickers:
                    if self.stickerPane.supernode == nil {
                        self.insertSubnode(self.stickerPane, belowSubnode: self.collectionListContainer)
                        self.stickerPane.frame = CGRect(origin: CGPoint(x: width, y: 0.0), size: CGSize(width: width, height: panelHeight))
                    }
                    if self.stickerPane.frame != paneFrame {
                        self.stickerPane.layer.removeAnimation(forKey: "position")
                        transition.updateFrame(node: self.stickerPane, frame: paneFrame)
                    }
                case .trending:
                    if self.trendingPane.supernode == nil {
                        self.insertSubnode(self.trendingPane, belowSubnode: self.collectionListContainer)
                        self.trendingPane.frame = CGRect(origin: CGPoint(x: width, y: 0.0), size: CGSize(width: width, height: panelHeight))
                    }
                    if self.trendingPane.frame != paneFrame {
                        self.trendingPane.layer.removeAnimation(forKey: "position")
                        transition.updateFrame(node: self.trendingPane, frame: paneFrame)
                    }
            }
        }
        
        self.gifPane.updateLayout(size: CGSize(width: width - leftInset - rightInset, height: panelHeight), topInset: 41.0, bottomInset: bottomInset, isExpanded: isExpanded, isVisible: isVisible, deviceMetrics: deviceMetrics, transition: transition)
        self.stickerPane.updateLayout(size: CGSize(width: width - leftInset - rightInset, height: panelHeight), topInset: 41.0, bottomInset: bottomInset, isExpanded: isExpanded, isVisible: isVisible && visiblePanes.contains(where: { $0.0 == .stickers }), deviceMetrics: deviceMetrics, transition: transition)
        self.trendingPane.updateLayout(size: CGSize(width: width - leftInset - rightInset, height: panelHeight), topInset: 41.0, bottomInset: bottomInset, isExpanded: isExpanded, isVisible: isVisible, deviceMetrics: deviceMetrics, transition: transition)
        
        if self.gifPane.supernode != nil {
            if !visiblePanes.contains(where: { $0.0 == .gifs }) {
                if case .animated = transition {
                    if !self.animatingGifPaneOut {
                        self.animatingGifPaneOut = true
                        var toLeft = false
                        if let index = self.paneArrangement.panes.firstIndex(of: .gifs), index < self.paneArrangement.currentIndex {
                            toLeft = true
                        }
                        transition.animatePosition(node: self.gifPane, to: CGPoint(x: (toLeft ? -width : width) + width / 2.0, y: self.gifPane.layer.position.y), removeOnCompletion: false, completion: { [weak self] value in
                            if let strongSelf = self, value {
                                strongSelf.animatingGifPaneOut = false
                                strongSelf.gifPane.removeFromSupernode()
                            }
                        })
                    }
                } else {
                    self.animatingGifPaneOut = false
                    self.gifPane.removeFromSupernode()
                }
            }
        } else {
            self.animatingGifPaneOut = false
        }
        
        if self.stickerPane.supernode != nil {
            if !visiblePanes.contains(where: { $0.0 == .stickers }) {
                if case .animated = transition {
                    if !self.animatingStickerPaneOut {
                        self.animatingStickerPaneOut = true
                        var toLeft = false
                        if let index = self.paneArrangement.panes.firstIndex(of: .stickers), index < self.paneArrangement.currentIndex {
                            toLeft = true
                        }
                        transition.animatePosition(node: self.stickerPane, to: CGPoint(x: (toLeft ? -width : width) + width / 2.0, y: self.stickerPane.layer.position.y), removeOnCompletion: false, completion: { [weak self] value in
                            if let strongSelf = self, value {
                                strongSelf.animatingStickerPaneOut = false
                                strongSelf.stickerPane.removeFromSupernode()
                            }
                        })
                    }
                } else {
                    self.animatingStickerPaneOut = false
                    self.stickerPane.removeFromSupernode()
                }
            }
        } else {
            self.animatingStickerPaneOut = false
        }
        
        if self.trendingPane.supernode != nil {
            if !visiblePanes.contains(where: { $0.0 == .trending }) {
                if case .animated = transition {
                    if !self.animatingTrendingPaneOut {
                        self.animatingTrendingPaneOut = true
                        var toLeft = false
                        if let index = self.paneArrangement.panes.firstIndex(of: .trending), index < self.paneArrangement.currentIndex {
                            toLeft = true
                        }
                        transition.animatePosition(node: self.trendingPane, to: CGPoint(x: (toLeft ? -width : width) + width / 2.0, y: self.trendingPane.layer.position.y), removeOnCompletion: false, completion: { [weak self] value in
                            if let strongSelf = self, value {
                                strongSelf.animatingTrendingPaneOut = false
                                strongSelf.trendingPane.removeFromSupernode()
                            }
                        })
                    }
                } else {
                    self.animatingTrendingPaneOut = false
                    self.trendingPane.removeFromSupernode()
                }
            }
        } else {
            self.animatingTrendingPaneOut = false
        }
        
        if !displaySearch, let searchContainerNode = self.searchContainerNode {
            self.searchContainerNode = nil
            self.searchContainerNodeLoadedDisposable.set(nil)
            
            var paneIsEmpty = false
            var placeholderNode: PaneSearchBarPlaceholderNode?
            if let searchMode = searchMode {
                switch searchMode {
                    case .gif:
                        placeholderNode = self.gifPane.searchPlaceholderNode
                        paneIsEmpty = self.gifPane.isEmpty
                    case .sticker:
                        self.stickerPane.gridNode.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? PaneSearchBarPlaceholderNode {
                                placeholderNode = itemNode
                            }
                        }
                }
            }
            if let placeholderNode = placeholderNode {
                searchContainerNode.animateOut(to: placeholderNode, animateOutSearchBar: !paneIsEmpty, transition: transition, completion: { [weak searchContainerNode] in
                    searchContainerNode?.removeFromSupernode()
                })
            } else {
                searchContainerNode.removeFromSupernode()
            }
        }
        
        if let panRecognizer = self.panRecognizer, panRecognizer.isEnabled != !displaySearch {
            panRecognizer.isEnabled = !displaySearch
        }
        
        if isVisible && !wasVisible {
            transition.updateFrame(node: self.gifPane, frame: self.gifPane.frame, force: true, completion: { [weak self] _ in
                self?.gifPane.initializeIfNeeded()
            })
        }
        
        return (standardInputHeight, max(0.0, panelHeight - standardInputHeight))
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
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    strongSelf._ready.set(.single(Void()))
                }
            }
        })
    }
    
    private func enqueueGridTransition(_ transition: ChatMediaInputGridTransition, firstTime: Bool) {
        var itemTransition: ContainedViewLayoutTransition = .immediate
        if transition.animated {
            itemTransition = .animated(duration: 0.3, curve: .spring)
        }
        self.stickerPane.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: itemTransition, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset, updateOpaqueState: transition.updateOpaqueState), completion: { _ in })
    }
    
    private func updatePreviewingItem(item: StickerPreviewPeekItem?, animated: Bool) {
        if self.inputNodeInteraction.previewedStickerPackItem != item {
            self.inputNodeInteraction.previewedStickerPackItem = item
            
            self.stickerPane.gridNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMediaInputStickerGridItemNode {
                    itemNode.updatePreviewing(animated: animated)
                }
            }
            
            self.searchContainerNode?.contentNode.updatePreviewing(animated: animated)
            self.trendingPane.updatePreviewing(animated: animated)
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                if self.animatingGifPaneOut {
                    self.animatingGifPaneOut = false
                    self.gifPane.removeFromSupernode()
                }
                self.gifPane.layer.removeAllAnimations()
                self.stickerPane.layer.removeAllAnimations()
                if self.animatingStickerPaneOut {
                    self.animatingStickerPaneOut = false
                    self.stickerPane.removeFromSupernode()
                }
                self.trendingPane.layer.removeAllAnimations()
                if self.animatingTrendingPaneOut {
                    self.animatingTrendingPaneOut = false
                    self.trendingPane.removeFromSupernode()
            }
            case .changed:
                if let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible) = self.validLayout {
                    let translationX = -recognizer.translation(in: self.view).x
                    var indexTransition = translationX / width
                    if self.paneArrangement.currentIndex == 0 {
                        indexTransition = max(0.0, indexTransition)
                    } else if self.paneArrangement.currentIndex == self.paneArrangement.panes.count - 1 {
                        indexTransition = min(0.0, indexTransition)
                    }
                    self.paneArrangement = self.paneArrangement.withIndexTransition(indexTransition)
                    let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .immediate, interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible)
                }
            case .ended:
                if let (width, _, _, _, _, _, _, _, _, _, _) = self.validLayout {
                    var updatedIndex = self.paneArrangement.currentIndex
                    if abs(self.paneArrangement.indexTransition * width) > 30.0 {
                        if self.paneArrangement.indexTransition < 0.0 {
                            updatedIndex = max(0, self.paneArrangement.currentIndex - 1)
                        } else {
                            updatedIndex = min(self.paneArrangement.panes.count - 1, self.paneArrangement.currentIndex + 1)
                        }
                    }
                    self.paneArrangement = self.paneArrangement.withIndexTransition(0.0)
                    self.setCurrentPane(self.paneArrangement.panes[updatedIndex], transition: .animated(duration: 0.25, curve: .spring))
                }
            case .cancelled:
                if let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible) = self.validLayout {
                    self.paneArrangement = self.paneArrangement.withIndexTransition(0.0)
                    let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .animated(duration: 0.25, curve: .spring), interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible)
                }
            default:
                break
        }
    }
    
    private var isExpanded: Bool {
        var isExpanded: Bool = false
        if let validLayout = self.validLayout, case let .media(_, maybeExpanded) = validLayout.8.inputMode, maybeExpanded != nil {
            isExpanded = true
        }
        return isExpanded
    }
    
    private func updatePaneDidScroll(pane: ChatMediaInputPane, state: ChatMediaInputPaneScrollState, transition: ContainedViewLayoutTransition) {
        if self.isExpanded {
            pane.collectionListPanelOffset = 0.0
        } else {
            var computedAbsoluteOffset: CGFloat
            if let absoluteOffset = state.absoluteOffset, absoluteOffset >= 0.0 {
                computedAbsoluteOffset = 0.0
            } else {
                computedAbsoluteOffset = pane.collectionListPanelOffset + state.relativeChange
            }
            computedAbsoluteOffset = max(-41.0, min(computedAbsoluteOffset, 0.0))
            pane.collectionListPanelOffset = computedAbsoluteOffset
            if transition.isAnimated {
                if pane.collectionListPanelOffset < -41.0 / 2.0 {
                    pane.collectionListPanelOffset = -41.0
                } else {
                    pane.collectionListPanelOffset = 0.0
                }
            }
        }
        
        let collectionListPanelOffset = self.currentCollectionListPanelOffset()
        
        self.updateAppearanceTransition(transition: transition)
        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: collectionListPanelOffset), size: self.collectionListPanel.bounds.size))
        transition.updateFrame(node: self.collectionListSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 41.0 + collectionListPanelOffset), size: self.collectionListSeparator.bounds.size))
        transition.updatePosition(node: self.listView, position: CGPoint(x: self.listView.position.x, y: (41.0 - collectionListPanelOffset) / 2.0))
    }
    
    private func fixPaneScroll(pane: ChatMediaInputPane, state: ChatMediaInputPaneScrollState) {
        if let absoluteOffset = state.absoluteOffset, absoluteOffset >= 0.0 {
            pane.collectionListPanelOffset = 0.0
        } else {
            if pane.collectionListPanelOffset < -41.0 / 2.0 {
                pane.collectionListPanelOffset = -41.0
            } else {
                pane.collectionListPanelOffset = 0.0
            }
        }
        
        let collectionListPanelOffset = self.currentCollectionListPanelOffset()
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .spring)
        self.updateAppearanceTransition(transition: transition)
        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: collectionListPanelOffset), size: self.collectionListPanel.bounds.size))
        transition.updateFrame(node: self.collectionListSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 41.0 + collectionListPanelOffset), size: self.collectionListSeparator.bounds.size))
        transition.updatePosition(node: self.listView, position: CGPoint(x: self.listView.position.x, y: (41.0 - collectionListPanelOffset) / 2.0))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let searchContainerNode = self.searchContainerNode {
            if let result = searchContainerNode.hitTest(point.offsetBy(dx: -searchContainerNode.frame.minX, dy: -searchContainerNode.frame.minY), with: event) {
                return result
            }
        }
        return super.hitTest(point, with: event)
    }
    
    static func setupPanelIconInsets(item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> UIEdgeInsets {
        var insets = UIEdgeInsets()
        if previousItem != nil {
            insets.top += 3.0
        }
        if nextItem != nil {
            insets.bottom += 3.0
        }
        return insets
    }
    
    private func dismissPeerSpecificPackSetup() {
        guard let peerId = self.peerId else {
            return
        }
        self.dismissedPeerSpecificStickerPack.set(.single(true))
        let _ = (self.context.account.postbox.transaction { transaction -> Void in
            transaction.updatePeerChatInterfaceState(peerId, update: { current in
                if let current = current as? ChatInterfaceState {
                    return current.withUpdatedMessageActionsState({ value in
                        var value = value
                        value.closedPeerSpecificPackSetup = true
                        return value
                    })
                } else {
                    return current
                }
            })
        }).start()
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    let sourceRect: CGRect
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = false
    
    init(controller: ViewController, sourceNode: ASDisplayNode?, sourceRect: CGRect) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.sourceRect = sourceRect
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        let sourceRect = self.sourceRect
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode, sourceRect)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
        if let controller = self.controller as? GalleryController {
            controller.viewDidAppear(false)
        }
    }
}

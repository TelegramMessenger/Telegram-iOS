import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramNotices
import MergeLists
import AccountContext
import StickerPackPreviewUI
import PeerInfoUI
import SettingsUI
import ContextUI
import GalleryUI
import OverlayStatusController
import PresentationDataUtils
import ChatInterfaceState
import ChatPresentationInterfaceState
import UndoUI

struct PeerSpecificPackData {
    let peer: Peer
    let info: StickerPackCollectionInfo
    let items: [ItemCollectionItem]
}

enum CanInstallPeerSpecificPack {
    case none
    case available(peer: Peer, dismissed: Bool)
}

final class ChatMediaInputPanelOpaqueState {
    let entries: [ChatMediaInputPanelEntry]
    
    init(entries: [ChatMediaInputPanelEntry]) {
        self.entries = entries
    }
}

struct ChatMediaInputPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let scrollToItem: ListViewScrollToItem?
    let updateOpaqueState: ChatMediaInputPanelOpaqueState?
}

struct ChatMediaInputGridTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
    let updateOpaqueState: ChatMediaInputStickerPaneOpaqueState?
    let animated: Bool
}

func preparedChatMediaInputPanelEntryTransition(context: AccountContext, from fromEntries: [ChatMediaInputPanelEntry], to toEntries: [ChatMediaInputPanelEntry], inputNodeInteraction: ChatMediaInputNodeInteraction, scrollToItem: ListViewScrollToItem?) -> ChatMediaInputPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, inputNodeInteraction: inputNodeInteraction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, inputNodeInteraction: inputNodeInteraction), directionHint: nil) }
    
    return ChatMediaInputPanelTransition(deletions: deletions, insertions: insertions, updates: updates, scrollToItem: scrollToItem, updateOpaqueState: ChatMediaInputPanelOpaqueState(entries: toEntries))
}

func preparedChatMediaInputGridEntryTransition(account: Account, view: ItemCollectionsView, from fromEntries: [ChatMediaInputGridEntry], to toEntries: [ChatMediaInputGridEntry], update: StickerPacksCollectionUpdate, interfaceInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction, trendingInteraction: TrendingPaneInteraction) -> ChatMediaInputGridTransition {
    var stationaryItems: GridNodeStationaryItems = .none
    var scrollToItem: GridNodeScrollToItem?
    var animated = false
    switch update {
        case .initial:
            for i in (0 ..< toEntries.count).reversed() {
                switch toEntries[i] {
                case .search, .peerSpecificSetup, .trending:
                    break
                case .trendingList, .sticker:
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
        case .search, .trendingList, .peerSpecificSetup, .trending:
            break
        case let .collectionIndex(index):
            firstIndexInSectionOffset = Int(index.itemIndex.index)
        }
    }
        
    let opaqueState = ChatMediaInputStickerPaneOpaqueState(hasLower: view.lower != nil)
    
    return ChatMediaInputGridTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: firstIndexInSectionOffset, stationaryItems: stationaryItems, scrollToItem: scrollToItem, updateOpaqueState: opaqueState, animated: animated)
}

func chatMediaInputPanelEntries(view: ItemCollectionsView, savedStickers: OrderedItemListView?, recentStickers: OrderedItemListView?, temporaryPackOrder: [ItemCollectionId]? = nil, trendingIsDismissed: Bool = false, peerSpecificPack: PeerSpecificPackData?, canInstallPeerSpecificPack: CanInstallPeerSpecificPack, theme: PresentationTheme, strings: PresentationStrings, hasGifs: Bool = true, hasSettings: Bool = true, expanded: Bool = false, reorderable: Bool = false) -> [ChatMediaInputPanelEntry] {
    var entries: [ChatMediaInputPanelEntry] = []
    if hasGifs {
        entries.append(.recentGifs(theme, strings, expanded))
    }
    if trendingIsDismissed {
        entries.append(.trending(true, theme, strings, expanded))
    }
    if let savedStickers = savedStickers, !savedStickers.items.isEmpty {
        entries.append(.savedStickers(theme, strings, expanded))
    }
    var savedStickerIds = Set<Int64>()
    if let savedStickers = savedStickers, !savedStickers.items.isEmpty {
        for i in 0 ..< savedStickers.items.count {
            if let item = savedStickers.items[i].contents.get(SavedStickerItem.self) {
                savedStickerIds.insert(item.file.fileId.id)
            }
        }
    }
    if let recentStickers = recentStickers, !recentStickers.items.isEmpty {
        var found = false
        for item in recentStickers.items {
            if let item = item.contents.get(RecentMediaItem.self), let mediaId = item.media.id {
                if !savedStickerIds.contains(mediaId.id) {
                    found = true
                    break
                }
            }
        }
        if found {
            entries.append(.recentPacks(theme, strings, expanded))
        }
    }
    if let peerSpecificPack = peerSpecificPack {
        entries.append(.peerSpecific(theme: theme, peer: peerSpecificPack.peer, expanded: expanded))
    } else if case let .available(peer, false) = canInstallPeerSpecificPack {
        entries.append(.peerSpecific(theme: theme, peer: peer, expanded: expanded))
    }
    var index = 0
    
    var sortedPacks: [(ItemCollectionId, StickerPackCollectionInfo, StickerPackItem?)] = []
    for (id, info, item) in view.collectionInfos {
        if let info = info as? StickerPackCollectionInfo, let item = item as? StickerPackItem {
            sortedPacks.append((id, info, item))
        }
    }
    
    if let temporaryPackOrder = temporaryPackOrder {
        var packDict: [ItemCollectionId: Int] = [:]
        for i in 0 ..< sortedPacks.count {
            packDict[sortedPacks[i].0] = i
        }
        var tempSortedPacks: [(ItemCollectionId, StickerPackCollectionInfo, StickerPackItem?)] = []
        var processedPacks = Set<ItemCollectionId>()
        for id in temporaryPackOrder {
            if let index = packDict[id] {
                tempSortedPacks.append(sortedPacks[index])
                processedPacks.insert(id)
            }
        }
        let restPacks = sortedPacks.filter { !processedPacks.contains($0.0) }
        sortedPacks = restPacks + tempSortedPacks
    }
    
    for (_, info, topItem) in sortedPacks {
        entries.append(.stickerPack(index: index, info: info, topItem: topItem, theme: theme, expanded: expanded, reorderable: reorderable))
        index += 1
    }
  
    if peerSpecificPack == nil, case let .available(peer, true) = canInstallPeerSpecificPack {
        entries.append(.peerSpecific(theme: theme, peer: peer, expanded: expanded))
    }
    
    if hasSettings {
        entries.append(.settings(theme, strings, expanded))
    }
    return entries
}

func chatMediaInputPanelGifModeEntries(theme: PresentationTheme, strings: PresentationStrings, reactions: [String], animatedEmojiStickers: [String: [StickerPackItem]], expanded: Bool) -> [ChatMediaInputPanelEntry] {
    var entries: [ChatMediaInputPanelEntry] = []
    entries.append(.stickersMode(theme, strings, expanded))
    entries.append(.savedGifs(theme, strings, expanded))
    entries.append(.trendingGifs(theme, strings, expanded))
    
    for reaction in reactions {
        entries.append(.gifEmotion(entries.count, theme, strings, reaction, animatedEmojiStickers[reaction]?.first?.file, expanded))
    }
    
    return entries
}

func chatMediaInputGridEntries(view: ItemCollectionsView, savedStickers: OrderedItemListView?, recentStickers: OrderedItemListView?, peerSpecificPack: PeerSpecificPackData?, canInstallPeerSpecificPack: CanInstallPeerSpecificPack, trendingPacks: [FeaturedStickerPackItem], installedPacks: Set<ItemCollectionId>, trendingIsDismissed: Bool = false, hasSearch: Bool = true, hasAccessories: Bool = true, strings: PresentationStrings, theme: PresentationTheme) -> [ChatMediaInputGridEntry] {
    var entries: [ChatMediaInputGridEntry] = []
    
    if hasSearch && view.lower == nil {
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
            let packInfo = StickerPackCollectionInfo(id: ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue, id: 0), flags: [], accessHash: 0, title: strings.Stickers_FavoriteStickers.uppercased(), shortName: "", thumbnail: nil, immediateThumbnailData: nil, hash: 0, count: 0)
            for i in 0 ..< savedStickers.items.count {
                if let item = savedStickers.items[i].contents.get(SavedStickerItem.self) {
                    savedStickerIds.insert(item.file.fileId.id)
                    let index = ItemCollectionItemIndex(index: Int32(i), id: item.file.fileId.id)
                    let stickerItem = StickerPackItem(index: index, file: item.file, indexKeys: [])
                    entries.append(.sticker(index: ItemCollectionViewEntryIndex(collectionIndex: -3, collectionId: packInfo.id, itemIndex: index), stickerItem: stickerItem, stickerPackInfo: packInfo, canManagePeerSpecificPack: nil, maybeManageable: hasAccessories, theme: theme))
                }
            }
        }
        
        let filteredTrending = trendingPacks.filter { !installedPacks.contains($0.info.id) }
        if !trendingIsDismissed && !filteredTrending.isEmpty {
            entries.append(.trendingList(theme: theme, strings: strings, packs: filteredTrending))
        }
        
        if let recentStickers = recentStickers, !recentStickers.items.isEmpty {
            let packInfo = StickerPackCollectionInfo(id: ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue, id: 0), flags: [], accessHash: 0, title: strings.Stickers_FrequentlyUsed.uppercased(), shortName: "", thumbnail: nil, immediateThumbnailData: nil, hash: 0, count: 0)
            var addedCount = 0
            for i in 0 ..< recentStickers.items.count {
                if addedCount >= 20 {
                    break
                }
                if let item = recentStickers.items[i].contents.get(RecentMediaItem.self), let mediaId = item.media.id {
                    let file = item.media

                    if !savedStickerIds.contains(mediaId.id) {
                        let index = ItemCollectionItemIndex(index: Int32(i), id: mediaId.id)
                        let stickerItem = StickerPackItem(index: index, file: file, indexKeys: [])
                        entries.append(.sticker(index: ItemCollectionViewEntryIndex(collectionIndex: -2, collectionId: packInfo.id, itemIndex: index), stickerItem: stickerItem, stickerPackInfo: packInfo, canManagePeerSpecificPack: nil, maybeManageable: hasAccessories, theme: theme))
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
                let packInfo = StickerPackCollectionInfo(id: ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue, id: 0), flags: [], accessHash: 0, title: strings.Stickers_GroupStickers, shortName: "", thumbnail: nil, immediateThumbnailData: nil, hash: 0, count: 0)
                
                if let item = peerSpecificPack.items[i] as? StickerPackItem {
                    let index = ItemCollectionItemIndex(index: Int32(i), id: item.file.fileId.id)
                    let stickerItem = StickerPackItem(index: index, file: item.file, indexKeys: [])
                    entries.append(.sticker(index: ItemCollectionViewEntryIndex(collectionIndex: -1, collectionId: packInfo.id, itemIndex: index), stickerItem: stickerItem, stickerPackInfo: packInfo, canManagePeerSpecificPack: canManagePeerSpecificPack, maybeManageable: hasAccessories, theme: theme))
                }
            }
        }
    }
    
    for entry in view.entries {
        if let item = entry.item as? StickerPackItem {
            entries.append(.sticker(index: entry.index, stickerItem: item, stickerPackInfo: stickerPackInfos[entry.index.collectionId], canManagePeerSpecificPack: false, maybeManageable: hasAccessories, theme: theme))
        }
    }
    
    if view.higher == nil {
        if peerSpecificPack == nil, case .available(_, true) = canInstallPeerSpecificPack {
            entries.append(.peerSpecificSetup(theme: theme, strings: strings, dismissed: true))
        }
    }
    return entries
}

enum StickerPacksCollectionPosition: Equatable {
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

enum StickerPacksCollectionUpdate {
    case initial
    case generic
    case scroll
    case navigate(ItemCollectionViewEntryIndex?, ItemCollectionId?)
}

enum ChatMediaInputGifMode: Equatable {
    case recent
    case trending
    case emojiSearch(String)
}

final class ChatMediaInputNodeInteraction {
    let navigateToCollectionId: (ItemCollectionId) -> Void
    let navigateBackToStickers: () -> Void
    let setGifMode: (ChatMediaInputGifMode) -> Void
    let openSettings: () -> Void
    let openTrending: (ItemCollectionId?) -> Void
    let dismissTrendingPacks: ([ItemCollectionId]) -> Void
    let toggleSearch: (Bool, ChatMediaInputSearchMode?, String) -> Void
    let openPeerSpecificSettings: () -> Void
    let dismissPeerSpecificSettings: () -> Void
    let clearRecentlyUsedStickers: () -> Void
    
    var stickerSettings: ChatInterfaceStickerSettings?
    var highlightedStickerItemCollectionId: ItemCollectionId?
    var highlightedItemCollectionId: ItemCollectionId?
    var highlightedGifMode: ChatMediaInputGifMode = .recent
    var previewedStickerPackItem: StickerPreviewPeekItem?
    var appearanceTransition: CGFloat = 1.0
    var displayStickerPlaceholder = true
    var displayStickerPackManageControls = true
    
    init(navigateToCollectionId: @escaping (ItemCollectionId) -> Void, navigateBackToStickers: @escaping () -> Void, setGifMode: @escaping (ChatMediaInputGifMode) -> Void, openSettings: @escaping () -> Void, openTrending: @escaping (ItemCollectionId?) -> Void, dismissTrendingPacks: @escaping ([ItemCollectionId]) -> Void, toggleSearch: @escaping (Bool, ChatMediaInputSearchMode?, String) -> Void, openPeerSpecificSettings: @escaping () -> Void, dismissPeerSpecificSettings: @escaping () -> Void, clearRecentlyUsedStickers: @escaping () -> Void) {
        self.navigateToCollectionId = navigateToCollectionId
        self.navigateBackToStickers = navigateBackToStickers
        self.setGifMode = setGifMode
        self.openSettings = openSettings
        self.openTrending = openTrending
        self.dismissTrendingPacks = dismissTrendingPacks
        self.toggleSearch = toggleSearch
        self.openPeerSpecificSettings = openPeerSpecificSettings
        self.dismissPeerSpecificSettings = dismissPeerSpecificSettings
        self.clearRecentlyUsedStickers = clearRecentlyUsedStickers
    }
}

func clipScrollPosition(_ position: StickerPacksCollectionPosition) -> StickerPacksCollectionPosition {
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

enum ChatMediaInputPaneType {
    case gifs
    case stickers
}

struct ChatMediaInputPaneArrangement {
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

final class CollectionListContainerNode: ASDisplayNode {
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
    private var trendingInteraction: TrendingPaneInteraction?

    private let collectionListPanel: ASDisplayNode
    private let collectionListSeparator: ASDisplayNode
    private let collectionListContainer: CollectionListContainerNode
    
    private weak var peekController: PeekController?
    
    private let disposable = MetaDisposable()
    
    private let listView: ListView
    private let gifListView: ListView
    private var searchContainerNode: PaneSearchContainerNode?
    private let searchContainerNodeLoadedDisposable = MetaDisposable()

    private let paneClippingContainer: ASDisplayNode
    private let panesBackgroundNode: ASDisplayNode
    private let stickerPane: ChatMediaInputStickerPane
    private var animatingStickerPaneOut = false
    private let gifPane: ChatMediaInputGifPane
    private var animatingGifPaneOut = false
    private var animatingTrendingPaneOut = false
    
    private var panRecognizer: UIPanGestureRecognizer?
    
    private let itemCollectionsViewPosition = Promise<StickerPacksCollectionPosition>()
    private var currentStickerPacksCollectionPosition: StickerPacksCollectionPosition?
    private var currentView: ItemCollectionsView?
    private let dismissedPeerSpecificStickerPack = Promise<Bool>()
    
    private var scrollingStickerPacksListPromise = ValuePromise<Bool>(false)
    private var scrollingStickersGridPromise = ValuePromise<Bool>(false)
    private var previewingStickersPromise = ValuePromise<Bool>(false)
    private var choosingSticker: Signal<Bool, NoError> {
        return combineLatest(self.scrollingStickerPacksListPromise.get(), self.scrollingStickersGridPromise.get(), self.previewingStickersPromise.get())
        |> map { scrollingStickerPacksList, scrollingStickersGrid, previewingStickers -> Bool in
            return scrollingStickerPacksList || scrollingStickersGrid || previewingStickers
        }
        |> distinctUntilChanged
    }
    private var choosingStickerDisposable: Disposable?
    
    private var panelFocusScrollToIndex: Int?
    private var panelFocusInitialPosition: CGPoint?
    private let panelIsFocusedPromise = ValuePromise<Bool>(false)
    private var panelIsFocused: Bool = false {
        didSet {
            self.panelIsFocusedPromise.set(self.panelIsFocused)
        }
    }
    private var panelFocusTimer: SwiftSignalKit.Timer?
    private var lastReorderItemIndex: Int?
    
    var requestDisableStickerAnimations: ((Bool) -> Void)?
    
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
    
    init(context: AccountContext, peerId: PeerId?, chatLocation: ChatLocation?, controllerInteraction: ChatControllerInteraction, chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, gifPaneIsActiveUpdated: @escaping (Bool) -> Void) {
        self.context = context
        self.peerId = peerId
        self.controllerInteraction = controllerInteraction
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        self.gifPaneIsActiveUpdated = gifPaneIsActiveUpdated

        self.paneClippingContainer = ASDisplayNode()
        self.paneClippingContainer.clipsToBounds = true

        self.panesBackgroundNode = ASDisplayNode()
        
        self.themeAndStringsPromise = Promise((theme, strings))

        self.collectionListPanel = ASDisplayNode()
        
        self.collectionListSeparator = ASDisplayNode()
        self.collectionListSeparator.isLayerBacked = true
        self.collectionListSeparator.backgroundColor = theme.chat.inputMediaPanel.panelSeparatorColor
        
        self.collectionListContainer = CollectionListContainerNode()
        
        self.listView = ListView()
        self.listView.useSingleDimensionTouchPoint = true
        self.listView.reorderedItemHasShadow = false
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(Double.pi / 2.0), 0.0, 0.0, 1.0)
        self.listView.scroller.panGestureRecognizer.cancelsTouchesInView = true
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.gifListView = ListView()
        self.gifListView.useSingleDimensionTouchPoint = true
        self.gifListView.transform = CATransform3DMakeRotation(-CGFloat(Double.pi / 2.0), 0.0, 0.0, 1.0)
        self.gifListView.scroller.panGestureRecognizer.cancelsTouchesInView = true
        self.gifListView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        var paneDidScrollImpl: ((ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void)?
        var fixPaneScrollImpl: ((ChatMediaInputPane, ChatMediaInputPaneScrollState) -> Void)?
        var openGifContextMenuImpl: ((MultiplexedVideoNodeFile, ASDisplayNode, CGRect, ContextGesture, Bool) -> Void)?
        
        self.stickerPane = ChatMediaInputStickerPane(theme: theme, strings: strings, paneDidScroll: { pane, state, transition in
            paneDidScrollImpl?(pane, state, transition)
        }, fixPaneScroll: { pane, state in
            fixPaneScrollImpl?(pane, state)
        })
        self.gifPane = ChatMediaInputGifPane(context: context, theme: theme, strings: strings, controllerInteraction: controllerInteraction, paneDidScroll: { pane, state, transition in
            paneDidScrollImpl?(pane, state, transition)
        }, fixPaneScroll: { pane, state in
            fixPaneScrollImpl?(pane, state)
        }, openGifContextMenu: { file, sourceNode, sourceRect, gesture, isSaved in
            openGifContextMenuImpl?(file, sourceNode, sourceRect, gesture, isSaved)
        })
        
        var getItemIsPreviewedImpl: ((StickerPackItem) -> Bool)?
        
        self.paneArrangement = ChatMediaInputPaneArrangement(panes: [.gifs, .stickers], currentIndex: 1, indexTransition: 0.0)
        
        super.init()
        
        self.stickerPane.beganScrolling = { [weak self] in
            self?.scrollingStickersGridPromise.set(true)
        }
        self.stickerPane.endedScrolling = { [weak self] in
            self?.scrollingStickersGridPromise.set(false)
        }
        
        let temporaryPackOrder = Promise<[ItemCollectionId]?>(nil)
        
        self.listView.willBeginReorder = { [weak self] point in
            self?.listView.beganInteractiveDragging(point)
        }
        
        self.listView.reorderBegan = { [weak self] in
            self?.stopCollapseTimer()
        }
        
        self.listView.reorderItem = { [weak self] fromIndex, toIndex, opaqueState in
            guard let entries = (opaqueState as? ChatMediaInputPanelOpaqueState)?.entries else {
                return .single(false)
            }
            self?.lastReorderItemIndex = toIndex
                        
            let fromEntry = entries[fromIndex]
            guard case let .stickerPack(_, fromPackInfo, _, _, _, _) = fromEntry else {
                return .single(false)
            }
            var referenceId: ItemCollectionId?
            var beforeAll = false
            var afterAll = false
            if toIndex < entries.count {
                switch entries[toIndex] {
                    case let .stickerPack(_, toPackInfo, _, _, _, _):
                        referenceId = toPackInfo.id
                    default:
                        if entries[toIndex] < fromEntry {
                            beforeAll = true
                        } else {
                            afterAll = true
                        }
                }
            } else {
                afterAll = true
            }
            
            var currentIds: [ItemCollectionId] = []
            for entry in entries {
                switch entry {
                case let .stickerPack(_, info, _, _, _, _):
                    currentIds.append(info.id)
                default:
                    break
                }
            }
            
            var previousIndex: Int?
            for i in 0 ..< currentIds.count {
                if currentIds[i] == fromPackInfo.id {
                    previousIndex = i
                    currentIds.remove(at: i)
                    break
                }
            }
            
            var didReorder = false
            
            if let referenceId = referenceId {
                var inserted = false
                for i in 0 ..< currentIds.count {
                    if currentIds[i] == referenceId {
                        if fromIndex < toIndex {
                            didReorder = previousIndex != i + 1
                            currentIds.insert(fromPackInfo.id, at: i + 1)
                        } else {
                            didReorder = previousIndex != i
                            currentIds.insert(fromPackInfo.id, at: i)
                        }
                        inserted = true
                        break
                    }
                }
                if !inserted {
                    didReorder = previousIndex != currentIds.count
                    currentIds.append(fromPackInfo.id)
                }
            } else if beforeAll {
                didReorder = previousIndex != 0
                currentIds.insert(fromPackInfo.id, at: 0)
            } else if afterAll {
                didReorder = previousIndex != currentIds.count
                currentIds.append(fromPackInfo.id)
            }
            
            temporaryPackOrder.set(.single(currentIds))
            
            return .single(didReorder)
        }
        self.listView.reorderCompleted = { [weak self] opaqueState in
            guard let entries = (opaqueState as? ChatMediaInputPanelOpaqueState)?.entries else {
                return
            }
            
            var currentIds: [ItemCollectionId] = []
            for entry in entries {
                switch entry {
                case let .stickerPack(_, info, _, _, _, _):
                    currentIds.append(info.id)
                default:
                    break
                }
            }
            let _ = (context.account.postbox.transaction { transaction -> Void in
                let namespace = Namespaces.ItemCollection.CloudStickerPacks
                let infos = transaction.getItemCollectionsInfos(namespace: namespace)
                
                var packDict: [ItemCollectionId: Int] = [:]
                for i in 0 ..< infos.count {
                    packDict[infos[i].0] = i
                }
                var tempSortedPacks: [(ItemCollectionId, ItemCollectionInfo)] = []
                var processedPacks = Set<ItemCollectionId>()
                for id in currentIds {
                    if let index = packDict[id] {
                        tempSortedPacks.append(infos[index])
                        processedPacks.insert(id)
                    }
                }
                let restPacks = infos.filter { !processedPacks.contains($0.0) }
                let sortedPacks = restPacks + tempSortedPacks
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: namespace, content: .sync, noDelay: false)
                transaction.replaceItemCollectionInfos(namespace: namespace, itemCollectionInfos: sortedPacks)
            }
            |> deliverOnMainQueue).start(completed: { [weak self] in
                temporaryPackOrder.set(.single(nil))
                
                if let strongSelf = self {
                    if let lastReorderItemIndex = strongSelf.lastReorderItemIndex {
                        strongSelf.lastReorderItemIndex = nil
                        if strongSelf.panelIsFocused {
                            strongSelf.panelFocusScrollToIndex = lastReorderItemIndex
                        }
                    }
                }
                
                self?.startCollapseTimer(timeout: 2.0)
            })
        }
        
        self.inputNodeInteraction = ChatMediaInputNodeInteraction(navigateToCollectionId: { [weak self] collectionId in
            if let strongSelf = self, let currentView = strongSelf.currentView, (collectionId != strongSelf.inputNodeInteraction.highlightedItemCollectionId || true) {
                var index: Int32 = 0
                if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue {
                    strongSelf.setCurrentPane(.gifs, transition: .animated(duration: 0.25, curve: .spring))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue {
                    strongSelf.controllerInteraction.navigationController()?.pushViewController(FeaturedStickersScreen(
                        context: strongSelf.context,
                        highlightedPackId: nil,
                        sendSticker: {
                            fileReference, sourceNode, sourceRect in
                            if let strongSelf = self {
                                return strongSelf.controllerInteraction.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect)
                            } else {
                                return false
                            }
                        }
                    ))
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
        }, navigateBackToStickers: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
        }, setGifMode: { [weak self] mode in
            guard let strongSelf = self else {
                return
            }
            strongSelf.gifPane.setMode(mode: mode)
            strongSelf.inputNodeInteraction.highlightedGifMode = strongSelf.gifPane.mode
            
            strongSelf.gifListView.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMediaInputMetaSectionItemNode {
                    itemNode.updateIsHighlighted()
                }
            }
        }, openSettings: { [weak self] in
            if let strongSelf = self {
                let controller = installedStickerPacksController(context: context, mode: .modal)
                controller.navigationPresentation = .modal
                strongSelf.controllerInteraction.navigationController()?.pushViewController(controller)
            }
        }, openTrending: { [weak self] packId in
            if let strongSelf = self {
                strongSelf.controllerInteraction.navigationController()?.pushViewController(FeaturedStickersScreen(
                    context: strongSelf.context,
                    highlightedPackId: packId,
                    sendSticker: {
                        fileReference, sourceNode, sourceRect in
                        if let strongSelf = self {
                            return strongSelf.controllerInteraction.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect)
                        } else {
                            return false
                        }
                    }
                ))
            }
        }, dismissTrendingPacks: { _ in
            let _ = (context.account.viewTracker.featuredStickerPacks()
            |> take(1)
            |> deliverOnMainQueue).start(next: { packs in
                let ids = packs.map { $0.info.id.id }
                let _ = ApplicationSpecificNotice.setDismissedTrendingStickerPacks(accountManager: context.sharedContext.accountManager, values: ids).start()
            })
        }, toggleSearch: { [weak self] value, searchMode, query in
            if let strongSelf = self {
                if let searchMode = searchMode, value {
                    var searchContainerNode: PaneSearchContainerNode?
                    if let current = strongSelf.searchContainerNode {
                        searchContainerNode = current
                    } else {
                        searchContainerNode = PaneSearchContainerNode(context: strongSelf.context, theme: strongSelf.theme, strings: strongSelf.strings, controllerInteraction: strongSelf.controllerInteraction, inputNodeInteraction: strongSelf.inputNodeInteraction, mode: searchMode, trendingGifsPromise: strongSelf.gifPane.trendingPromise, cancel: {
                            self?.searchContainerNode?.deactivate()
                            self?.inputNodeInteraction.toggleSearch(false, nil, "")
                        })
                        searchContainerNode?.openGifContextMenu = { file, sourceNode, sourceRect, gesture, isSaved in
                            self?.openGifContextMenu(file: file, sourceNode: sourceNode, sourceRect: sourceRect, gesture: gesture, isSaved: isSaved)
                        }
                        strongSelf.searchContainerNode = searchContainerNode
                        if !query.isEmpty {
                            DispatchQueue.main.async {
                                searchContainerNode?.updateQuery(query)
                            }
                        }
                    }
                    if let searchContainerNode = searchContainerNode {
                        strongSelf.searchContainerNodeLoadedDisposable.set((searchContainerNode.ready
                        |> deliverOnMainQueue).start(next: {
                            if let strongSelf = self {
                                strongSelf.controllerInteraction.updateInputMode { current in
                                    switch current {
                                        case let .media(mode, _, focused):
                                            return .media(mode: mode, expanded: .search(searchMode), focused: focused)
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
                            case let .media(mode, _, focused):
                                return .media(mode: mode, expanded: nil, focused: focused)
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
        
        self.panesBackgroundNode.backgroundColor = theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0)

        self.addSubnode(self.paneClippingContainer)
        self.paneClippingContainer.addSubnode(self.panesBackgroundNode)
        self.collectionListPanel.addSubnode(self.listView)
        self.collectionListPanel.addSubnode(self.gifListView)
        self.gifListView.isHidden = true
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
        
        let previousEntries = Atomic<([ChatMediaInputPanelEntry], [ChatMediaInputPanelEntry], [ChatMediaInputGridEntry])>(value: ([], [], []))
        
        let inputNodeInteraction = self.inputNodeInteraction!
        let peerSpecificPack: Signal<(PeerSpecificPackData?, CanInstallPeerSpecificPack), NoError>
        if let peerId = peerId {
            self.dismissedPeerSpecificStickerPack.set(
                context.engine.peers.getOpaqueChatInterfaceState(peerId: peerId, threadId: nil)
                |> map { opaqueState -> Bool in
                    guard let opaqueState = opaqueState else {
                        return false
                    }
                    let interfaceState = ChatInterfaceState.parse(opaqueState)

                    if interfaceState.messageActionsState.closedPeerSpecificPackSetup {
                        return true
                    }
                    return false
                }
            )
            peerSpecificPack = combineLatest(context.engine.peers.peerSpecificStickerPack(peerId: peerId), context.account.postbox.multiplePeersView([peerId]), self.dismissedPeerSpecificStickerPack.get())
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
            guard let info = info as? StickerPackCollectionInfo else {
                return
            }
            let _ = (context.engine.stickers.loadedStickerPack(reference: .id(id: info.id.id, accessHash: info.accessHash), forceActualized: false)
            |> mapToSignal { result -> Signal<Void, NoError> in
                switch result {
                    case let .result(info, items, installed):
                        if installed {
                            return .complete()
                        } else {
                            return context.engine.stickers.addStickerPackInteractively(info: info, items: items)
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
            let controller = StickerPackScreen(context: strongSelf.context, updatedPresentationData: strongSelf.controllerInteraction.updatedPresentationData, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controllerInteraction.navigationController(), sendSticker: { fileReference, sourceNode, sourceRect in
                if let strongSelf = self {
                    return strongSelf.controllerInteraction.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect)
                } else {
                    return false
                }
            })
            strongSelf.controllerInteraction.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }, getItemIsPreviewed: { item in
            return getItemIsPreviewedImpl?(item) ?? false
        }, openSearch: {
        })
        self.trendingInteraction = trendingInteraction
        
        let preferencesViewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.appConfiguration]))
        let reactions: Signal<[String], NoError> = context.account.postbox.combinedView(keys: [preferencesViewKey])
        |> map { views -> [String] in
            let defaultReactions: [String] = ["👍", "👎", "😍", "😂", "😯", "😕", "😢", "😡", "💪", "👏", "🙈", "😒"]
            guard let view = views.views[preferencesViewKey] as? PreferencesView else {
                return defaultReactions
            }
            guard let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) else {
                return defaultReactions
            }
            guard let data = appConfiguration.data, let emojis = data["gif_search_emojies"] as? [String] else {
                return defaultReactions
            }
            return emojis
        }
        |> distinctUntilChanged
        
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                            let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                            if animatedEmojiStickers[strippedEmoji] == nil {
                                animatedEmojiStickers[strippedEmoji] = [item]
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        
        let previousView = Atomic<ItemCollectionsView?>(value: nil)
        let transitionQueue = Queue()
        let transitions = combineLatest(queue: transitionQueue, itemCollectionsView, peerSpecificPack, context.account.viewTracker.featuredStickerPacks(), self.themeAndStringsPromise.get(), reactions, self.panelIsFocusedPromise.get(), ApplicationSpecificNotice.dismissedTrendingStickerPacks(accountManager: context.sharedContext.accountManager), temporaryPackOrder.get(), animatedEmojiStickers)
        |> map { viewAndUpdate, peerSpecificPack, trendingPacks, themeAndStrings, reactions, panelExpanded, dismissedTrendingStickerPacks, temporaryPackOrder, animatedEmojiStickers -> (ItemCollectionsView, ChatMediaInputPanelTransition, ChatMediaInputPanelTransition, Bool, ChatMediaInputGridTransition, Bool) in
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
            
            var trendingIsDismissed = false
            if let dismissedTrendingStickerPacks = dismissedTrendingStickerPacks, Set(trendingPacks.map({ $0.info.id.id })) == Set(dismissedTrendingStickerPacks) {
                trendingIsDismissed = true
            }
                        
            let panelEntries = chatMediaInputPanelEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, temporaryPackOrder: temporaryPackOrder, trendingIsDismissed: trendingIsDismissed, peerSpecificPack: peerSpecificPack.0, canInstallPeerSpecificPack: peerSpecificPack.1, theme: theme, strings: strings, expanded: panelExpanded, reorderable: true)
            let gifPaneEntries = chatMediaInputPanelGifModeEntries(theme: theme, strings: strings, reactions: reactions, animatedEmojiStickers: animatedEmojiStickers, expanded: panelExpanded)
            var gridEntries = chatMediaInputGridEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, peerSpecificPack: peerSpecificPack.0, canInstallPeerSpecificPack: peerSpecificPack.1, trendingPacks: trendingPacks, installedPacks: installedPacks, trendingIsDismissed: trendingIsDismissed, strings: strings, theme: theme)
            
            if view.higher == nil {
                var hasTopSeparator = true
                if gridEntries.count == 1, case .search = gridEntries[0] {
                    hasTopSeparator = false
                }
                
                var index = 0
                for item in trendingPacks {
                    if !installedPacks.contains(item.info.id) {
                        gridEntries.append(.trending(TrendingPanePackEntry(index: index, info: item.info, theme: theme, strings: strings, topItems: item.topItems, installed: installedPacks.contains(item.info.id), unread: item.unread, topSeparator: hasTopSeparator)))
                        hasTopSeparator = true
                        index += 1
                    }
                }
            }

            let (previousPanelEntries, previousGifPaneEntries, previousGridEntries) = previousEntries.swap((panelEntries, gifPaneEntries, gridEntries))
            return (view, preparedChatMediaInputPanelEntryTransition(context: context, from: previousPanelEntries, to: panelEntries, inputNodeInteraction: inputNodeInteraction, scrollToItem: nil), preparedChatMediaInputPanelEntryTransition(context: context, from: previousGifPaneEntries, to: gifPaneEntries, inputNodeInteraction: inputNodeInteraction, scrollToItem: nil), previousPanelEntries.isEmpty, preparedChatMediaInputGridEntryTransition(account: context.account, view: view, from: previousGridEntries, to: gridEntries, update: update, interfaceInteraction: controllerInteraction, inputNodeInteraction: inputNodeInteraction, trendingInteraction: trendingInteraction), previousGridEntries.isEmpty)
        }
        
        self.disposable.set((transitions
        |> deliverOnMainQueue).start(next: { [weak self] (view, panelTransition, gifPaneTransition, panelFirstTime, gridTransition, gridFirstTime) in
            if let strongSelf = self {
                strongSelf.currentView = view
                strongSelf.enqueuePanelTransition(panelTransition, firstTime: panelFirstTime, thenGridTransition: gridTransition, gridFirstTime: gridFirstTime)
                strongSelf.enqueueGifPanelTransition(gifPaneTransition, firstTime: false)
                if !strongSelf.initializedArrangement {
                    strongSelf.initializedArrangement = true
                    let currentPane = strongSelf.paneArrangement.panes[strongSelf.paneArrangement.currentIndex]
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
                    if let _ = topVisible.1 as? StickerPaneTrendingListGridItem {
                        topVisibleCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue, id: 0)
                    } else if let item = topVisible.1 as? ChatMediaInputStickerGridItem {
                        topVisibleCollectionId = item.index.collectionId
                    } else if let _ = topVisible.1 as? StickerPanePeerSpecificSetupGridItem {
                        topVisibleCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue, id: 0)
                    }
                }
                if let collectionId = topVisibleCollectionId {
                    if strongSelf.inputNodeInteraction.highlightedItemCollectionId != collectionId && strongSelf.inputNodeInteraction.highlightedItemCollectionId?.namespace != ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue {
                        strongSelf.setHighlightedItemCollectionId(collectionId)
                    }
                }
                
                if let currentView = strongSelf.currentView, let (topIndex, topItem) = visibleItems.top, let (bottomIndex, bottomItem) = visibleItems.bottom {
                    if topIndex <= 10 && currentView.lower != nil {
                        if let topItem = topItem as? ChatMediaInputStickerGridItem {
                            let position: StickerPacksCollectionPosition = clipScrollPosition(.scroll(aroundIndex: topItem.index))
                            if strongSelf.currentStickerPacksCollectionPosition != position {
                                strongSelf.currentStickerPacksCollectionPosition = position
                                strongSelf.itemCollectionsViewPosition.set(.single(position))
                            }
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
        
        openGifContextMenuImpl = { [weak self] file, sourceNode, sourceRect, gesture, isSaved in
            self?.openGifContextMenu(file: file, sourceNode: sourceNode, sourceRect: sourceRect, gesture: gesture, isSaved: isSaved)
        }
        
        self.listView.beganInteractiveDragging = { [weak self] position in
            if let strongSelf = self {
                strongSelf.stopCollapseTimer()
                
                strongSelf.scrollingStickerPacksListPromise.set(true)

                var position = position
                var index = strongSelf.listView.itemIndexAtPoint(CGPoint(x: 0.0, y: position.y))
                if index == nil {
                    position.y += 10.0
                    index = strongSelf.listView.itemIndexAtPoint(CGPoint(x: 0.0, y: position.y))
                }
                if let index = index {
                    strongSelf.panelFocusScrollToIndex = index
                    strongSelf.panelFocusInitialPosition = position
                }
                strongSelf.interfaceInteraction?.updateTextInputStateAndMode { inputTextState, inputMode in
                    if case let .media(mode, expanded, _) = inputMode {
                        return (inputTextState, .media(mode: mode, expanded: expanded, focused: true))
                    } else {
                        return (inputTextState, inputMode)
                    }
                }
            }
        }
        
        self.listView.endedInteractiveDragging = { [weak self] position in
            if let strongSelf = self {
                strongSelf.panelFocusInitialPosition = position
            }
        }
        
        self.listView.didEndScrolling = { [weak self] decelerated in
            if let strongSelf = self {
                if decelerated {
                    strongSelf.panelFocusScrollToIndex = nil
                    strongSelf.panelFocusInitialPosition = nil
                }
                strongSelf.startCollapseTimer(timeout: decelerated ? 0.5 : 2.5)
                
                strongSelf.scrollingStickerPacksListPromise.set(false)
            }
        }
        
        self.gifListView.beganInteractiveDragging = { [weak self] position in
            if let strongSelf = self {
                strongSelf.stopCollapseTimer()
                var position = position
                var index = strongSelf.gifListView.itemIndexAtPoint(CGPoint(x: 0.0, y: position.y))
                if index == nil {
                    position.y += 10.0
                    index = strongSelf.gifListView.itemIndexAtPoint(CGPoint(x: 0.0, y: position.y))
                }
                if let index = index {
                    strongSelf.panelFocusScrollToIndex = index
                    strongSelf.panelFocusInitialPosition = position
                }
                strongSelf.interfaceInteraction?.updateTextInputStateAndMode { inputTextState, inputMode in
                    if case let .media(mode, expanded, _) = inputMode {
                        return (inputTextState, .media(mode: mode, expanded: expanded, focused: true))
                    } else {
                        return (inputTextState, inputMode)
                    }
                }
            }
        }
        
        self.gifListView.endedInteractiveDragging = { [weak self] position in
            if let strongSelf = self {
                strongSelf.panelFocusInitialPosition = position
            }
        }
        
        self.gifListView.didEndScrolling = { [weak self] decelerated in
            if let strongSelf = self {
                if decelerated {
                    strongSelf.panelFocusScrollToIndex = nil
                    strongSelf.panelFocusInitialPosition = nil
                }
                strongSelf.startCollapseTimer(timeout: decelerated ? 0.5 : 2.5)
            }
        }
        
        self.choosingStickerDisposable = (self.choosingSticker
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.controllerInteraction.updateChoosingSticker(value)
            }
        })
    }
    
    deinit {
        self.disposable.dispose()
        self.choosingStickerDisposable?.dispose()
        self.searchContainerNodeLoadedDisposable.dispose()
        self.panelFocusTimer?.invalidate()
    }
    
    private func updateIsFocused(_ isExpanded: Bool) {
        guard self.panelIsFocused != isExpanded else {
            return
        }
    
        self.panelIsFocused = isExpanded
        self.updatePaneClippingContainer(size: self.paneClippingContainer.bounds.size, offset: self.currentCollectionListPanelOffset(), transition: .animated(duration: 0.3, curve: .spring))
    }
    
    private func startCollapseTimer(timeout: Double) {
        self.panelFocusTimer?.invalidate()
        
        let timer = SwiftSignalKit.Timer(timeout: timeout, repeat: false, completion: { [weak self] in
            self?.interfaceInteraction?.updateTextInputStateAndMode { inputTextState, inputMode in
                if case let .media(mode, expanded, _) = inputMode {
                    return (inputTextState, .media(mode: mode, expanded: expanded, focused: false))
                } else {
                    return (inputTextState, inputMode)
                }
            }
        }, queue: Queue.mainQueue())
        self.panelFocusTimer = timer
        timer.start()
    }
    
    private func stopCollapseTimer() {
        self.panelFocusTimer?.invalidate()
        self.panelFocusTimer = nil
    }
    
    private func openGifContextMenu(file: MultiplexedVideoNodeFile, sourceNode: ASDisplayNode, sourceRect: CGRect, gesture: ContextGesture, isSaved: Bool) {
        let canSaveGif: Bool
        if file.file.media.fileId.namespace == Namespaces.Media.CloudFile {
            canSaveGif = true
        } else {
            canSaveGif = false
        }
        
        let _ = (self.context.account.postbox.transaction { transaction -> Bool in
            if !canSaveGif {
                return false
            }
            return isGifSaved(transaction: transaction, mediaId: file.file.media.fileId)
        }
        |> deliverOnMainQueue).start(next: { [weak self] isGifSaved in
            guard let strongSelf = self else {
                return
            }
            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            
            let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: PeerId(0), namespace: Namespaces.Message.Local, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [file.file.media], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [])
            
            let gallery = GalleryController(context: strongSelf.context, source: .standaloneMessage(message), streamSingleVideo: true, replaceRootController: { _, _ in
            }, baseNavigationController: nil)
            gallery.setHintWillBePresentedInPreviewingContext(true)
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: strongSelf.strings.MediaPicker_Send, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                f(.default)
                if isSaved {
                    let _ = self?.controllerInteraction.sendGif(file.file, sourceNode, sourceRect, false, false)
                } else if let (collection, result) = file.contextResult {
                    let _ = self?.controllerInteraction.sendBotContextResultAsGif(collection, result, sourceNode, sourceRect, false)
                }
            })))
            
            if let (_, _, _, _, _, _, _, _, interfaceState, _, _) = strongSelf.validLayout {
                var isScheduledMessages = false
                if case .scheduledMessages = interfaceState.subject {
                    isScheduledMessages = true
                }
                if !isScheduledMessages {
                    if case let .peer(peerId) = interfaceState.chatLocation {
                        if peerId != self?.context.account.peerId && peerId.namespace != Namespaces.Peer.SecretChat  {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.default)
                                if isSaved {
                                    let _ = self?.controllerInteraction.sendGif(file.file, sourceNode, sourceRect, true, false)
                                } else if let (collection, result) = file.contextResult {
                                    let _ = self?.controllerInteraction.sendBotContextResultAsGif(collection, result, sourceNode, sourceRect, true)
                                }
                            })))
                        }
                    
                        if isSaved {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.default)
                                
                                let _ = self?.controllerInteraction.sendGif(file.file, sourceNode, sourceRect, false, true)
                            })))
                        }
                    }
                }
            }
            
            if isSaved || isGifSaved {
                items.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = removeSavedGif(postbox: strongSelf.context.account.postbox, mediaId: file.file.media.fileId).start()
                })))
            } else if canSaveGif && !isGifSaved {
                items.append(.action(ContextMenuActionItem(text: strongSelf.strings.Preview_SaveGif, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = addSavedGif(postbox: strongSelf.context.account.postbox, fileReference: file.file).start()
                    
                    strongSelf.controllerInteraction.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: presentationData.strings.Gallery_GifSaved), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), nil)
                })))
            }
            
            let contextController = ContextController(account: strongSelf.context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceNode: sourceNode, sourceRect: sourceRect)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            strongSelf.controllerInteraction.presentGlobalOverlayController(contextController, nil)
        })
    }
    
    private func updateThemeAndStrings(chatWallpaper: TelegramWallpaper, theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            
            self.collectionListSeparator.backgroundColor = theme.chat.inputMediaPanel.panelSeparatorColor
            self.panesBackgroundNode.backgroundColor = theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0)
            
            self.searchContainerNode?.updateThemeAndStrings(theme: theme, strings: strings)
            
            self.stickerPane.updateThemeAndStrings(theme: theme, strings: strings)
            self.gifPane.updateThemeAndStrings(theme: theme, strings: strings)
            
            self.themeAndStringsPromise.set(.single((theme, strings)))
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        let peekRecognizer = PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
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
                                    var menuItems: [ContextMenuItem] = []                                    
                                    if let (_, _, _, _, _, _, _, _, interfaceState, _, _) = strongSelf.validLayout {
                                        var isScheduledMessages = false
                                        if case .scheduledMessages = interfaceState.subject {
                                            isScheduledMessages = true
                                        }
                                        if !isScheduledMessages {
                                            if case let .peer(peerId) = interfaceState.chatLocation {
                                                if peerId != self?.context.account.peerId && peerId.namespace != Namespaces.Peer.SecretChat  {
                                                    menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                                                    }, action: { _, f in
                                                        if let strongSelf = self, let peekController = strongSelf.peekController {
                                                            if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                                                let _ = strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), true, false, nil, false, animationNode, animationNode.bounds)
                                                            } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                                                let _ = strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), true, false, nil, false, imageNode, imageNode.bounds)
                                                            }
                                                        }
                                                        f(.default)
                                                    })))
                                                }
                                            
                                                menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                                                }, action: { _, f in
                                                    if let strongSelf = self, let peekController = strongSelf.peekController {
                                                        if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                                            let _ = strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), false, true, nil, false, animationNode, animationNode.bounds)
                                                        } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                                            let _ = strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), false, true, nil, false, imageNode, imageNode.bounds)
                                                        }
                                                    }
                                                    f(.default)
                                                })))
                                            }
                                        }
                                    }
                                    menuItems.append(
                                        .action(ContextMenuActionItem(text: isStarred ? strongSelf.strings.Stickers_RemoveFromFavorites : strongSelf.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unstar") : UIImage(bundleImageName: "Chat/Context Menu/Rate"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                            f(.default)
                                            
                                            if let strongSelf = self {
                                                if isStarred {
                                                    let _ = removeSavedSticker(postbox: strongSelf.context.account.postbox, mediaId: item.file.fileId).start()
                                                } else {
                                                    let _ = addSavedSticker(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, file: item.file).start()
                                                }
                                            }
                                        }))
                                    )
                                    menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.StickerPack_ViewPack, icon: { theme in
                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.actionSheet.primaryTextColor)
                                        }, action: { _, f in
                                            f(.default)
                                            
                                            if let strongSelf = self {
                                                loop: for attribute in item.file.attributes {
                                                    switch attribute {
                                                    case let .Sticker(_, packReference, _):
                                                        if let packReference = packReference {
                                                            let controller = StickerPackScreen(context: strongSelf.context, updatedPresentationData: strongSelf.controllerInteraction.updatedPresentationData,  mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controllerInteraction.navigationController(), sendSticker: { file, sourceNode, sourceRect in
                                                                if let strongSelf = self {
                                                                    return strongSelf.controllerInteraction.sendSticker(file, false, false, nil, false, sourceNode, sourceRect)
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
                                    })))
                                    return (itemNode, StickerPreviewPeekContent(account: strongSelf.context.account, item: item, menu: menuItems))
                                } else {
                                    return nil
                                }
                            }
                        } else if let _ = item as? FileMediaReference {
                            return nil
                        }
                    }
                } else {
                    panes = [strongSelf.gifPane, strongSelf.stickerPane]
                }
                let panelPoint = strongSelf.view.convert(point, to: strongSelf.collectionListPanel.view)
                if panelPoint.y < strongSelf.collectionListPanel.frame.maxY {
                    return .single(nil)
                }
                
                for pane in panes {
                    if pane.supernode != nil, pane.frame.contains(point) {
                        if let pane = pane as? ChatMediaInputGifPane {
                            if let (_, _, _) = pane.fileAt(point: point.offsetBy(dx: -pane.frame.minX, dy: -pane.frame.minY)) {
                                return nil
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
                                        var menuItems: [ContextMenuItem] = []
                                        if let (_, _, _, _, _, _, _, _, interfaceState, _, _) = strongSelf.validLayout {
                                            var isScheduledMessages = false
                                            if case .scheduledMessages = interfaceState.subject {
                                                isScheduledMessages = true
                                            }
                                            if !isScheduledMessages {
                                                if case let .peer(peerId) = interfaceState.chatLocation {
                                                    if peerId != self?.context.account.peerId && peerId.namespace != Namespaces.Peer.SecretChat  {
                                                        menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                                                        }, action: { _, f in
                                                            if let strongSelf = self, let peekController = strongSelf.peekController {
                                                                if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                                                    let _ = strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), true, false, nil, false, animationNode, animationNode.bounds)
                                                                } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                                                    let _ = strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), true, false, nil, false, imageNode, imageNode.bounds)
                                                                }
                                                            }
                                                            f(.default)
                                                        })))
                                                    }
                                                
                                                    menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                                                    }, action: { _, f in
                                                        if let strongSelf = self, let peekController = strongSelf.peekController {
                                                            if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                                                let _ = strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), false, true, nil, false, animationNode, animationNode.bounds)
                                                            } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                                                let _ = strongSelf.controllerInteraction.sendSticker(.standalone(media: item.file), false, true, nil, false, imageNode, imageNode.bounds)
                                                            }
                                                        }
                                                        f(.default)
                                                    })))
                                                }
                                            }
                                        }
                                        
                                        menuItems.append(
                                            .action(ContextMenuActionItem(text: isStarred ? strongSelf.strings.Stickers_RemoveFromFavorites : strongSelf.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unstar") : UIImage(bundleImageName: "Chat/Context Menu/Rate"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                                f(.default)
                                                
                                                if let strongSelf = self {
                                                    if isStarred {
                                                        let _ = removeSavedSticker(postbox: strongSelf.context.account.postbox, mediaId: item.file.fileId).start()
                                                    } else {
                                                        let _ = addSavedSticker(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, file: item.file).start()
                                                    }
                                                }
                                            }))
                                        )
                                        menuItems.append(
                                            .action(ContextMenuActionItem(text: strongSelf.strings.StickerPack_ViewPack, icon: { theme in
                                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.actionSheet.primaryTextColor)
                                            }, action: { _, f in
                                                f(.default)
                                                
                                                if let strongSelf = self {
                                                    loop: for attribute in item.file.attributes {
                                                        switch attribute {
                                                        case let .Sticker(_, packReference, _):
                                                            if let packReference = packReference {
                                                                let controller = StickerPackScreen(context: strongSelf.context, updatedPresentationData: strongSelf.controllerInteraction.updatedPresentationData, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controllerInteraction.navigationController(), sendSticker: { file, sourceNode, sourceRect in
                                                                    if let strongSelf = self {
                                                                        return strongSelf.controllerInteraction.sendSticker(file, false, false, nil, false, sourceNode, sourceRect)
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
                                            }))
                                        )
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
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let controller = PeekController(presentationData: presentationData, content: content, sourceNode: {
                    return sourceNode
                })
                controller.visibilityUpdated = { [weak self] visible in
                    self?.previewingStickersPromise.set(visible)
                    self?.requestDisableStickerAnimations?(visible)
                    self?.simulateUpdateLayout(isVisible: !visible)
                }
                strongSelf.peekController = controller
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
        })
        self.view.addGestureRecognizer(peekRecognizer)
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.panRecognizer = panRecognizer
        self.view.addGestureRecognizer(panRecognizer)
    }
    
    private func setCurrentPane(_ pane: ChatMediaInputPaneType, transition: ContainedViewLayoutTransition, collectionIdHint: Int32? = nil) {
        if let index = self.paneArrangement.panes.firstIndex(of: pane), index != self.paneArrangement.currentIndex {
            let previousGifPanelWasActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .gifs
            self.paneArrangement = self.paneArrangement.withIndexTransition(0.0).withCurrentIndex(index)
            let updatedGifPanelWasActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .gifs
  
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
            }
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
        } else {
            self.inputNodeInteraction.highlightedStickerItemCollectionId = collectionId
            if self.paneArrangement.panes[self.paneArrangement.currentIndex] == .stickers {
                self.inputNodeInteraction.highlightedItemCollectionId = collectionId
            }
        }
        
        if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue && self.gifListView.isHidden {
            self.listView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: self.bounds.width, y: 0.0), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak self] completed in
                guard let strongSelf = self, completed else {
                    return
                }
                strongSelf.listView.isHidden = true
                strongSelf.listView.layer.removeAllAnimations()
            })
            self.gifListView.layer.removeAllAnimations()
            self.gifListView.isHidden = false
            self.gifListView.layer.animatePosition(from: CGPoint(x: -self.bounds.width, y: 0.0), to: CGPoint(), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        } else if !self.gifListView.isHidden {
            self.gifListView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -self.bounds.width, y: 0.0), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak self] completed in
                guard let strongSelf = self, completed else {
                    return
                }
                strongSelf.gifListView.isHidden = true
                strongSelf.gifListView.layer.removeAllAnimations()
            })
            self.listView.layer.removeAllAnimations()
            self.listView.isHidden = false
            self.listView.layer.animatePosition(from: CGPoint(x: self.bounds.width, y: 0.0), to: CGPoint(), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
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
                    if self.panelIsFocused, let targetIndex = self.listView.indexOf(itemNode: itemNode) {
                        self.panelFocusScrollToIndex = targetIndex
                        self.panelFocusInitialPosition = nil
                        self.interfaceInteraction?.updateTextInputStateAndMode { inputTextState, inputMode in
                            if case let .media(mode, expanded, _) = inputMode {
                                return (inputTextState, .media(mode: mode, expanded: expanded, focused: false))
                            } else {
                                return (inputTextState, inputMode)
                            }
                        }
                    } else {
                        self.panelFocusScrollToIndex = nil
                        self.panelFocusInitialPosition = nil
                        self.listView.ensureItemNodeVisible(itemNode)
                    }
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputMetaSectionItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    if self.panelIsFocused, let targetIndex = self.listView.indexOf(itemNode: itemNode) {
                        self.panelFocusScrollToIndex = targetIndex
                        self.panelFocusInitialPosition = nil
                        self.interfaceInteraction?.updateTextInputStateAndMode { inputTextState, inputMode in
                            if case let .media(mode, expanded, _) = inputMode {
                                return (inputTextState, .media(mode: mode, expanded: expanded, focused: false))
                            } else {
                                return (inputTextState, inputMode)
                            }
                        }
                    } else {
                        self.panelFocusScrollToIndex = nil
                        self.panelFocusInitialPosition = nil
                        self.listView.ensureItemNodeVisible(itemNode)
                    }
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputRecentGifsItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    if self.panelIsFocused, let targetIndex = self.listView.indexOf(itemNode: itemNode) {
                        self.panelFocusScrollToIndex = targetIndex
                        self.panelFocusInitialPosition = nil
                        self.interfaceInteraction?.updateTextInputStateAndMode { inputTextState, inputMode in
                            if case let .media(mode, expanded, _) = inputMode {
                                return (inputTextState, .media(mode: mode, expanded: expanded, focused: false))
                            } else {
                                return (inputTextState, inputMode)
                            }
                        }
                    } else {
                        self.panelFocusScrollToIndex = nil
                        self.panelFocusInitialPosition = nil
                        self.listView.ensureItemNodeVisible(itemNode)
                    }
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputTrendingItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    if self.panelIsFocused, let targetIndex = self.listView.indexOf(itemNode: itemNode) {
                        self.panelFocusScrollToIndex = targetIndex
                        self.panelFocusInitialPosition = nil
                        self.interfaceInteraction?.updateTextInputStateAndMode { inputTextState, inputMode in
                            if case let .media(mode, expanded, _) = inputMode {
                                return (inputTextState, .media(mode: mode, expanded: expanded, focused: false))
                            } else {
                                return (inputTextState, inputMode)
                            }
                        }
                    } else {
                        self.panelFocusScrollToIndex = nil
                        self.panelFocusInitialPosition = nil
                        self.listView.ensureItemNodeVisible(itemNode)
                    }
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputPeerSpecificItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    if self.panelIsFocused, let targetIndex = self.listView.indexOf(itemNode: itemNode) {
                        self.panelFocusScrollToIndex = targetIndex
                        self.panelFocusInitialPosition = nil
                        self.interfaceInteraction?.updateTextInputStateAndMode { inputTextState, inputMode in
                            if case let .media(mode, expanded, _) = inputMode {
                                return (inputTextState, .media(mode: mode, expanded: expanded, focused: false))
                            } else {
                                return (inputTextState, inputMode)
                            }
                        }
                    } else {
                        self.panelFocusScrollToIndex = nil
                        self.panelFocusInitialPosition = nil
                        self.listView.ensureItemNodeVisible(itemNode)
                    }
                    ensuredNodeVisible = true
                }
            }
        }
        
        if let currentView = self.currentView, let firstVisibleCollectionId = firstVisibleCollectionId, !ensuredNodeVisible {
            let targetIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == collectionId })
            let firstVisibleIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == firstVisibleCollectionId })
            if let targetIndex = targetIndex, let firstVisibleIndex = firstVisibleIndex {
                let toRight = targetIndex > firstVisibleIndex
                if self.panelIsFocused {
                    self.panelFocusScrollToIndex = targetIndex
                    self.panelFocusInitialPosition = nil
                    self.interfaceInteraction?.updateTextInputStateAndMode { inputTextState, inputMode in
                        if case let .media(mode, expanded, _) = inputMode {
                            return (inputTextState, .media(mode: mode, expanded: expanded, focused: false))
                        } else {
                            return (inputTextState, inputMode)
                        }
                    }
                } else {
                    self.panelFocusScrollToIndex = nil
                    self.panelFocusInitialPosition = nil
                    self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [], scrollToItem: ListViewScrollToItem(index: targetIndex, position: toRight ? .bottom(0.0) : .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: toRight ? .Down : .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil)
                }
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
        transition.updateAlpha(node: self.gifListView, alpha: value)
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
        self.gifListView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMediaInputMetaSectionItemNode {
                itemNode.updateAppearanceTransition(transition: transition)
            }
        }
    }
    
    func simulateUpdateLayout(isVisible: Bool) {
        if let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, _) = self.validLayout {
            let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .immediate, interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool) -> (CGFloat, CGFloat) {
        var searchMode: ChatMediaInputSearchMode?
        if let (_, _, _, _, _, _, _, _, interfaceState, _, _) = self.validLayout, case let .media(_, maybeExpanded, _) = interfaceState.inputMode, let expanded = maybeExpanded, case let .search(mode) = expanded {
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
        
        var isFocused = false
        var isExpanded: Bool = false
        if case let .media(_, _, focused) = interfaceState.inputMode {
            isFocused = focused
        }
        if case let .media(_, maybeExpanded, _) = interfaceState.inputMode, let expanded = maybeExpanded {
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
            self.updateAppearanceTransition(transition: transition)
        } else {
            panelHeight = standardInputHeight
        }
        
        self.updateIsFocused(isFocused)
        
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
                    let anchorTop = CGPoint(x: 0.0, y: 0.0)
                    let anchorTopView: UIView = self.view
                    if let searchMode = searchMode {
                        switch searchMode {
                        case .gif:
                            placeholderNode = self.gifPane.visibleSearchPlaceholderNode
                        case .sticker:
                            self.stickerPane.gridNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? PaneSearchBarPlaceholderNode {
                                    placeholderNode = itemNode
                                }
                            }
                        case .trending:
                            break
                        }
                    }
                    
                    searchContainerNode.animateIn(from: placeholderNode, anchorTop: anchorTop, anhorTopView: anchorTopView, transition: transition, completion: { [weak self] in
                        self?.gifPane.removeFromSupernode()
                    })
                }
            }
        }
        
        let contentVerticalOffset: CGFloat = displaySearch ? -(inputPanelHeight + 41.0) : 0.0
        
        let collectionListPanelOffset = self.currentCollectionListPanelOffset()
        
        transition.updateFrame(node: self.collectionListContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: contentVerticalOffset), size: CGSize(width: width, height: max(0.0, 41.0 + UIScreenPixel))))
        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: collectionListPanelOffset), size: CGSize(width: width, height: 41.0)))
        transition.updateFrame(node: self.collectionListSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 41.0 + collectionListPanelOffset), size: CGSize(width: width, height: separatorHeight)))
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: 41.0 + 31.0 + 40.0, height: width)
        transition.updatePosition(node: self.listView, position: CGPoint(x: width / 2.0, y: (41.0 - collectionListPanelOffset) / 2.0))
        
        self.gifListView.bounds = CGRect(x: 0.0, y: 0.0, width: 41.0 + 31.0 + 40.0, height: width)
        transition.updatePosition(node: self.gifListView, position: CGPoint(x: width / 2.0, y: (41.0 - collectionListPanelOffset) / 2.0))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: 41.0 + 31.0 + 20.0, height: width), insets: UIEdgeInsets(top: 4.0 + leftInset, left: 0.0, bottom: 4.0 + rightInset, right: 0.0), duration: duration, curve: curve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.gifListView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
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
                            self.paneClippingContainer.addSubnode(self.gifPane)
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
                        self.paneClippingContainer.addSubnode(self.stickerPane)
                        self.stickerPane.frame = CGRect(origin: CGPoint(x: width, y: 0.0), size: CGSize(width: width, height: panelHeight))
                    }
                    if self.stickerPane.frame != paneFrame {
                        self.stickerPane.layer.removeAnimation(forKey: "position")
                        transition.updateFrame(node: self.stickerPane, frame: paneFrame)
                    }
            }
        }
        
        self.gifPane.updateLayout(size: CGSize(width: width - leftInset - rightInset, height: panelHeight), topInset: 41.0, bottomInset: bottomInset, isExpanded: isExpanded, isVisible: isVisible, deviceMetrics: deviceMetrics, transition: transition)
        self.trendingInteraction?.itemContext.canPlayMedia = isVisible
        self.stickerPane.updateLayout(size: CGSize(width: width - leftInset - rightInset, height: panelHeight), topInset: 41.0, bottomInset: bottomInset, isExpanded: isExpanded, isVisible: isVisible && visiblePanes.contains(where: { $0.0 == .stickers }), deviceMetrics: deviceMetrics, transition: transition)
        
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
        
        if !displaySearch, let searchContainerNode = self.searchContainerNode {
            self.searchContainerNode = nil
            self.searchContainerNodeLoadedDisposable.set(nil)
            
            var paneIsEmpty = false
            var placeholderNode: PaneSearchBarPlaceholderNode?
            if let searchMode = searchMode {
                switch searchMode {
                case .gif:
                    placeholderNode = self.gifPane.visibleSearchPlaceholderNode
                    paneIsEmpty = placeholderNode != nil
                case .sticker:
                    paneIsEmpty = true
                    self.stickerPane.gridNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? PaneSearchBarPlaceholderNode {
                            placeholderNode = itemNode
                        }
                        if let _ = itemNode as? ChatMediaInputStickerGridItemNode {
                            paneIsEmpty = false
                        }
                    }
                case .trending:
                    break
                }
            }
            if let placeholderNode = placeholderNode {
                placeholderNode.isHidden = false
                searchContainerNode.animateOut(to: placeholderNode, animateOutSearchBar: !paneIsEmpty, transition: transition, completion: { [weak searchContainerNode] in
                    searchContainerNode?.removeFromSupernode()
                })
            } else {
                transition.updateAlpha(node: searchContainerNode, alpha: 0.0, completion: { [weak searchContainerNode] _ in
                    searchContainerNode?.removeFromSupernode()
                })
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

        self.updatePaneClippingContainer(size: CGSize(width: width, height: panelHeight), offset: self.currentCollectionListPanelOffset(), transition: transition)

        transition.updateFrame(node: self.panesBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: panelHeight)))
        
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
        
        var scrollToItem: ListViewScrollToItem?
        if self.paneArrangement.currentIndex == 1 {
            if let targetIndex = self.panelFocusScrollToIndex, !self.listView.isReordering {
                var position: ListViewScrollPosition
                if self.panelIsFocused {
                    if let initialPosition = self.panelFocusInitialPosition {
                        position = .top(96.0 + (initialPosition.y - self.listView.frame.height / 2.0) * 0.5)
                    } else {
                        position = .top(96.0)
                    }
                } else {
                    if let initialPosition = self.panelFocusInitialPosition {
                        position = .top(self.listView.frame.height / 2.0 + 96.0 + (initialPosition.y - self.listView.frame.height / 2.0))
                    } else {
                        position = .top(self.listView.frame.height / 2.0 + 96.0)
                    }
                    self.panelFocusScrollToIndex = nil
                    self.panelFocusInitialPosition = nil
                }
                scrollToItem = ListViewScrollToItem(index: targetIndex, position: position, animated: true, curve: .Spring(duration: 0.4), directionHint: .Down, displayLink: true)
            }
        }
        
        self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateOpaqueState: transition.updateOpaqueState, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.enqueueGridTransition(gridTransition, firstTime: gridFirstTime)
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    strongSelf._ready.set(.single(Void()))
                }
            }
        })
    }
    
    private func enqueueGifPanelTransition(_ transition: ChatMediaInputPanelTransition, firstTime: Bool) {
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.Synchronous)
            options.insert(.LowLatency)
        } else {
            options.insert(.AnimateInsertion)
        }
        
        var scrollToItem: ListViewScrollToItem?
        if self.paneArrangement.currentIndex == 0 {
            if let targetIndex = self.panelFocusScrollToIndex {
                var position: ListViewScrollPosition
                if self.panelIsFocused {
                    if let initialPosition = self.panelFocusInitialPosition {
                        position = .top(96.0 + (initialPosition.y - self.gifListView.frame.height / 2.0) * 0.5)
                    } else {
                        position = .top(96.0)
                    }
                } else {
                    if let initialPosition = self.panelFocusInitialPosition {
                        position = .top(self.gifListView.frame.height / 2.0 + 96.0 + (initialPosition.y - self.gifListView.frame.height / 2.0))
                    } else {
                        position = .top(self.gifListView.frame.height / 2.0 + 96.0)
                    }
                    self.panelFocusScrollToIndex = nil
                    self.panelFocusInitialPosition = nil
                }
                scrollToItem = ListViewScrollToItem(index: targetIndex, position: position, animated: true, curve: .Spring(duration: 0.4), directionHint: .Down, displayLink: true)
            }
        }
        
        self.gifListView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateOpaqueState: nil, completion: { _ in
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
        if let validLayout = self.validLayout, case let .media(_, maybeExpanded, _) = validLayout.8.inputMode, maybeExpanded != nil {
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
        
        var collectionListPanelOffset = self.currentCollectionListPanelOffset()
        if self.panelIsFocused {
            collectionListPanelOffset = 0.0
        }
        
        let listPanelOffset = collectionListPanelOffset * 2.0
        
        self.updateAppearanceTransition(transition: transition)
        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: listPanelOffset), size: self.collectionListPanel.bounds.size))
        transition.updatePosition(node: self.listView, position: CGPoint(x: self.listView.position.x, y: (41.0 - listPanelOffset) / 2.0))
        transition.updatePosition(node: self.gifListView, position: CGPoint(x: self.gifListView.position.x, y: (41.0 - listPanelOffset) / 2.0))

        self.updatePaneClippingContainer(size: self.paneClippingContainer.bounds.size, offset: collectionListPanelOffset, transition: transition)
    }

    private func updatePaneClippingContainer(size: CGSize, offset: CGFloat, transition: ContainedViewLayoutTransition) {
        var offset = offset
        if self.panelIsFocused {
            offset = 0.0
        }
        transition.updateFrame(node: self.collectionListSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: offset + 41.0), size: self.collectionListSeparator.bounds.size))
        transition.updateFrame(node: self.paneClippingContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: offset + 41.0), size: size))
        transition.updateSublayerTransformOffset(layer: self.paneClippingContainer.layer, offset: CGPoint(x: 0.0, y: -offset - 41.0))
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
        
        var collectionListPanelOffset = self.currentCollectionListPanelOffset()
        if self.panelIsFocused {
            collectionListPanelOffset = 0.0
        }
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .spring)
        self.updateAppearanceTransition(transition: transition)
        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: collectionListPanelOffset), size: self.collectionListPanel.bounds.size))
        transition.updatePosition(node: self.listView, position: CGPoint(x: self.listView.position.x, y: (41.0 - collectionListPanelOffset) / 2.0))
        transition.updatePosition(node: self.gifListView, position: CGPoint(x: self.gifListView.position.x, y: (41.0 - collectionListPanelOffset) / 2.0))

        self.updatePaneClippingContainer(size: self.paneClippingContainer.bounds.size, offset: collectionListPanelOffset, transition: transition)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.panelIsFocused {
            if point.y > -41.0 && point.y < 38.0 {
                let convertedPoint = CGPoint(x: max(0.0, point.y), y: point.x)
                if let result = self.listView.hitTest(convertedPoint, with: event) {
                    return result
                }
                if let result = self.gifListView.hitTest(convertedPoint, with: event) {
                    return result
                }
            }
        }
        if let searchContainerNode = self.searchContainerNode {
            if let result = searchContainerNode.hitTest(point.offsetBy(dx: -searchContainerNode.frame.minX, dy: -searchContainerNode.frame.minY), with: event) {
                return result
            }
        }
        let result = super.hitTest(point, with: event)
        return result
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
        let _ = ChatInterfaceState.update(engine: self.context.engine, peerId: peerId, threadId: nil, { current in
            return current.withUpdatedMessageActionsState({ value in
                var value = value
                value.closedPeerSpecificPackSetup = true
                return value
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

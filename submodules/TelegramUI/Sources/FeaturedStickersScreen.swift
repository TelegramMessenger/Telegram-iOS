import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import StickerPackPreviewUI
import StickerPeekUI
import OverlayStatusController
import PresentationDataUtils
import SearchBarNode
import UndoUI
import ContextUI
import PremiumUI

private final class FeaturedInteraction {
    let installPack: (ItemCollectionInfo, Bool) -> Void
    let openPack: (ItemCollectionInfo) -> Void
    let getItemIsPreviewed: (StickerPackItem) -> Bool
    let openSearch: () -> Void
    let itemContext = StickerPaneSearchGlobalItemContext()
    
    init(installPack: @escaping (ItemCollectionInfo, Bool) -> Void, openPack: @escaping (ItemCollectionInfo) -> Void, getItemIsPreviewed: @escaping (StickerPackItem) -> Bool, openSearch: @escaping () -> Void) {
        self.installPack = installPack
        self.openPack = openPack
        self.getItemIsPreviewed = getItemIsPreviewed
        self.openSearch = openSearch
    }
}

private final class FeaturedPackEntry: Identifiable, Comparable {
    let index: Int
    let info: StickerPackCollectionInfo
    let theme: PresentationTheme
    let strings: PresentationStrings
    let topItems: [StickerPackItem]
    let installed: Bool
    let unread: Bool
    let topSeparator: Bool
    let regularInsets: Bool
    
    init(index: Int, info: StickerPackCollectionInfo, theme: PresentationTheme, strings: PresentationStrings, topItems: [StickerPackItem], installed: Bool, unread: Bool, topSeparator: Bool, regularInsets: Bool = false) {
        self.index = index
        self.info = info
        self.theme = theme
        self.strings = strings
        self.topItems = topItems
        self.installed = installed
        self.unread = unread
        self.topSeparator = topSeparator
        self.regularInsets = regularInsets
    }
    
    var stableId: ItemCollectionId {
        return self.info.id
    }
    
    static func ==(lhs: FeaturedPackEntry, rhs: FeaturedPackEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.info != rhs.info {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.topItems != rhs.topItems {
            return false
        }
        if lhs.installed != rhs.installed {
            return false
        }
        if lhs.unread != rhs.unread {
            return false
        }
        if lhs.topSeparator != rhs.topSeparator {
            return false
        }
        if lhs.regularInsets != rhs.regularInsets {
            return false
        }
        return true
    }
    
    static func <(lhs: FeaturedPackEntry, rhs: FeaturedPackEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, interaction: FeaturedInteraction, isOther: Bool) -> GridItem {
        let info = self.info
        return StickerPaneSearchGlobalItem(account: account, theme: self.theme, strings: self.strings, listAppearance: true, fillsRow: false, info: self.info, topItems: self.topItems, topSeparator: self.topSeparator, regularInsets: self.regularInsets, installed: self.installed, unread: self.unread, open: {
            interaction.openPack(info)
        }, install: {
            interaction.installPack(info, !self.installed)
        }, getItemIsPreviewed: { item in
            return interaction.getItemIsPreviewed(item)
        }, itemContext: interaction.itemContext, sectionTitle: isOther ? self.strings.FeaturedStickers_OtherSection : nil)
    }
}

private enum FeaturedEntryId: Hashable {
    case pack(ItemCollectionId)
}

private enum FeaturedEntry: Identifiable, Comparable {
    case pack(FeaturedPackEntry, Bool)
    
    var stableId: FeaturedEntryId {
        switch self {
        case let .pack(pack, _):
            return .pack(pack.stableId)
        }
    }
    
    static func ==(lhs: FeaturedEntry, rhs: FeaturedEntry) -> Bool {
        switch lhs {
        case let .pack(pack, isOther):
            if case .pack(pack, isOther) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: FeaturedEntry, rhs: FeaturedEntry) -> Bool {
        switch lhs {
        case let .pack(lhsPack, _):
            switch rhs {
            case let .pack(rhsPack, _):
                return lhsPack < rhsPack
            }
        }
    }
    
    func item(account: Account, interaction: FeaturedInteraction) -> GridItem {
        switch self {
        case let .pack(pack, isOther):
            return pack.item(account: account, interaction: interaction, isOther: isOther)
        }
    }
}

private struct FeaturedTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let initial: Bool
    let scrollToItem: GridNodeScrollToItem?
}

private func preparedTransition(from fromEntries: [FeaturedEntry], to toEntries: [FeaturedEntry], account: Account, interaction: FeaturedInteraction, initial: Bool, scrollToItem: GridNodeScrollToItem?) -> FeaturedTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction)) }
    
    return FeaturedTransition(deletions: deletions, insertions: insertions, updates: updates, initial: initial, scrollToItem: scrollToItem)
}

private func featuredScreenEntries(featuredEntries: [FeaturedStickerPackItem], installedPacks: Set<ItemCollectionId>, theme: PresentationTheme, strings: PresentationStrings, fixedUnread: Set<ItemCollectionId>, additionalPacks: [FeaturedStickerPackItem]) -> [FeaturedEntry] {
    var result: [FeaturedEntry] = []
    var index = 0
    var existingIds = Set<ItemCollectionId>()
    for item in featuredEntries {
        if !existingIds.contains(item.info.id) {
            existingIds.insert(item.info.id)
            result.append(.pack(FeaturedPackEntry(index: index, info: item.info, theme: theme, strings: strings, topItems: item.topItems, installed: installedPacks.contains(item.info.id), unread: item.unread || fixedUnread.contains(item.info.id), topSeparator: index != 0, regularInsets: true), false))
            index += 1
        }
    }
    for item in additionalPacks {
        if !existingIds.contains(item.info.id) {
            existingIds.insert(item.info.id)
            result.append(.pack(FeaturedPackEntry(index: index, info: item.info, theme: theme, strings: strings, topItems: item.topItems, installed: installedPacks.contains(item.info.id), unread: item.unread || fixedUnread.contains(item.info.id), topSeparator: index != 0, regularInsets: true), true))
            index += 1
        }
    }
    return result
}

private final class FeaturedStickersScreenNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private weak var controller: FeaturedStickersScreen?
    private let sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?
    private var searchItemContext = StickerPaneSearchGlobalItemContext()
    
    let gridNode: GridNode
    
    private let additionalPacks = Promise<[FeaturedStickerPackItem]>([])
    private var additionalPacksValue: [FeaturedStickerPackItem] = []
    private var canLoadMore: Bool = true
    private var isLoadingMore: Bool = false
    
    private var interaction: FeaturedInteraction?
    
    private var enqueuedTransitions: [FeaturedTransition] = []
    
    private var validLayout: ContainerViewLayout?
    
    private var disposable: Disposable?
    private let installDisposable = MetaDisposable()
    private let loadMoreDisposable = MetaDisposable()
    
    private var searchNode: FeaturedPaneSearchContentNode?
    
    private weak var peekController: PeekController?
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady: Bool = false
    
    init(context: AccountContext, controller: FeaturedStickersScreen, sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.controller = controller
        self.sendSticker = sendSticker
        
        self.gridNode = GridNode()
        self.gridNode.floatingSections = true
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.gridNode)
        
        self.gridNode.scrollingInitiated = { [weak self] in
            self?.controller?.view.endEditing(true)
        }
        
        var processedRead = Set<ItemCollectionId>()
        
        self.gridNode.visibleItemsUpdated = { [weak self] visibleItems in
            guard let strongSelf = self else {
                return
            }
            if let (topIndex, _) = visibleItems.topVisible, let (bottomIndex, _) = visibleItems.bottomVisible {
                var addedRead: [ItemCollectionId] = []
                for i in topIndex ... bottomIndex {
                    if i >= 0 && i < strongSelf.gridNode.items.count {
                        let item = strongSelf.gridNode.items[i]
                        if let item = item as? StickerPaneSearchGlobalItem, item.unread {
                            let info = item.info
                            if !processedRead.contains(info.id) {
                                processedRead.insert(info.id)
                                addedRead.append(info.id)
                            }
                        }
                    }
                }
                if !addedRead.isEmpty {
                    let _ = strongSelf.context.engine.stickers.markFeaturedStickerPacksAsSeenInteractively(ids: addedRead).start()
                }
                
                if bottomIndex >= strongSelf.gridNode.items.count - 15 {
                    if strongSelf.canLoadMore {
                        strongSelf.loadMore()
                    }
                }
            }
        }
        
        let inputNodeInteraction = ChatMediaInputNodeInteraction(
            navigateToCollectionId: { _ in
            },
            navigateBackToStickers: {
            },
            setGifMode: { _ in
            },
            openSettings: {
            },
            openTrending: { _ in
            },
            dismissTrendingPacks: { _ in
            },
            toggleSearch: { _, _, _ in
            },
            openPeerSpecificSettings: {
            },
            dismissPeerSpecificSettings: {
            },
            clearRecentlyUsedStickers: {
            }
        )
        
        let interaction = FeaturedInteraction(
            installPack: { [weak self] info, install in
                guard let strongSelf = self, let info = info as? StickerPackCollectionInfo else {
                    return
                }
                if install {
                    let _ = strongSelf.context.engine.stickers.addStickerPackInteractively(info: info, items: []).start()
                } else {
                    let _ = (strongSelf.context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .delete)
                    |> deliverOnMainQueue).start(next: { _ in
                    })
                }
            },
            openPack: { [weak self] info in
                if let strongSelf = self, let info = info as? StickerPackCollectionInfo {
                    strongSelf.view.window?.endEditing(true)
                    let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
                    let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controller?.navigationController as? NavigationController, sendSticker: { fileReference, sourceNode, sourceRect in
                        if let strongSelf = self {
                            return strongSelf.sendSticker?(fileReference, sourceNode, sourceRect) ?? false
                        } else {
                            return false
                        }
                    })
                    strongSelf.controller?.present(controller, in: .window(.root))
                }
            },
            getItemIsPreviewed: { item in
                return false
            },
            openSearch: {
            }
        )
        self.interaction = interaction
        
        self.searchNode = FeaturedPaneSearchContentNode(
            context: context,
            theme: self.presentationData.theme,
            strings: self.presentationData.strings,
            inputNodeInteraction: inputNodeInteraction,
            controller: controller,
            sendSticker: sendSticker,
            itemContext: self.searchItemContext
        )
        
        self.searchNode?.isActiveUpdated = { [weak self] in
            self?.updateCanPlayMedia()
        }
        self.searchNode?.updateActivity = { [weak self] activity in
            self?.controller?.searchNavigationNode?.setActivity(activity)
        }
        self.searchNode?.deactivateSearchBar = { [weak self] in
            self?.controller?.view.endEditing(true)
        }
        
        let previousEntries = Atomic<[FeaturedEntry]?>(value: nil)
        let context = self.context
        
        var fixedUnread = Set<ItemCollectionId>()
        
        let mappedFeatured = context.account.viewTracker.featuredStickerPacks()
        |> map { items -> ([FeaturedStickerPackItem], Set<ItemCollectionId>) in
            for item in items {
                if item.unread {
                    fixedUnread.insert(item.info.id)
                }
            }
            return (items, fixedUnread)
        }
        
        let highlightedPackId = controller.highlightedPackId
        
        self.disposable = (combineLatest(queue: .mainQueue(),
            mappedFeatured,
            self.additionalPacks.get(),
            context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])]),
            context.sharedContext.presentationData
        )
        |> map { featuredEntries, additionalPacks, view, presentationData -> FeaturedTransition in
            var installedPacks = Set<ItemCollectionId>()
            if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
                if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
                    for entry in packsEntries {
                        installedPacks.insert(entry.id)
                    }
                }
            }
            let entries = featuredScreenEntries(featuredEntries: featuredEntries.0, installedPacks: installedPacks, theme: presentationData.theme, strings: presentationData.strings, fixedUnread: featuredEntries.1, additionalPacks: additionalPacks)
            let previous = previousEntries.swap(entries)
            
            var scrollToItem: GridNodeScrollToItem?
            let initial = previous == nil
            if initial, let highlightedPackId = highlightedPackId {
                var index = 0
                for entry in entries {
                    if case let .pack(packEntry, _) = entry, packEntry.info.id == highlightedPackId {
                        scrollToItem = GridNodeScrollToItem(index: index, position: .center(0.0), transition: .immediate, directionHint: .down, adjustForSection: false)
                        break
                    }
                    index += 1
                }
            }
            
            return preparedTransition(from: previous ?? [], to: entries, account: context.account, interaction: interaction, initial: initial, scrollToItem: scrollToItem)
        }
        |> deliverOnMainQueue).start(next: { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.enqueueTransition(transition)
            if !strongSelf.didSetReady {
                strongSelf.didSetReady = true
                strongSelf._ready.set(.single(true))
            }
        })
        
        self.controller?.searchNavigationNode?.setQueryUpdated({ [weak self] query, languageCode in
            guard let strongSelf = self else {
                return
            }
            strongSelf.searchNode?.updateText(query, languageCode: languageCode)
        })
        
        if let searchNode = self.searchNode {
            self.addSubnode(searchNode)
        }
    }
    
    deinit {
        self.disposable?.dispose()
        self.installDisposable.dispose()
        self.loadMoreDisposable.dispose()
    }
    
    func updatePresentationData(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.searchNode?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
        
    }
    
    private func loadMore() {
        if self.isLoadingMore || !self.canLoadMore {
            return
        }
        self.isLoadingMore = true
        self.loadMoreDisposable.set((requestOldFeaturedStickerPacks(network: self.context.account.network, postbox: self.context.account.postbox, offset: self.additionalPacksValue.count, limit: 50)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            var existingIds = Set(strongSelf.additionalPacksValue.map { $0.info.id })
            var updatedItems = strongSelf.additionalPacksValue
            for item in result {
                if !existingIds.contains(item.info.id) {
                    existingIds.insert(item.info.id)
                    updatedItems.append(item)
                }
            }
            strongSelf.additionalPacksValue = updatedItems
            strongSelf.additionalPacks.set(.single(strongSelf.additionalPacksValue))
            strongSelf.canLoadMore = result.count >= 50
            strongSelf.isLoadingMore = false
        }))
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
            guard let strongSelf = self else {
                return nil
            }
            if let searchNode = strongSelf.searchNode, searchNode.isActive {
                if let (itemNode, item) = searchNode.itemAt(point: strongSelf.view.convert(point, to: searchNode.view)) {
                    if let item = item as? StickerPreviewPeekItem {
                        return strongSelf.context.engine.stickers.isStickerSaved(id: item.file.fileId)
                        |> deliverOnMainQueue
                        |> map { isStarred -> (UIView, CGRect, PeekControllerContent)? in
                            if let strongSelf = self {
                                var menuItems: [ContextMenuItem] = []
                                menuItems = [
                                    .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.StickerPack_Send, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                        if let strongSelf = self, let peekController = strongSelf.peekController {
                                            if let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                                let _ = strongSelf.sendSticker?(.standalone(media: item.file), animationNode.view, animationNode.bounds)
                                            } else if let imageNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.imageNode {
                                                let _ = strongSelf.sendSticker?(.standalone(media: item.file), imageNode.view, imageNode.bounds)
                                            }
                                        }
                                        f(.default)
                                    })),
                                    .action(ContextMenuActionItem(text: isStarred ? strongSelf.presentationData.strings.Stickers_RemoveFromFavorites : strongSelf.presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                        f(.default)
                                        
                                        if let strongSelf = self {
                                            let _ = (strongSelf.context.engine.stickers.toggleStickerSaved(file: item.file, saved: !isStarred)
                                            |> deliverOnMainQueue).start(next: { result in
                                                switch result {
                                                    case .generic:
                                                        strongSelf.controller?.presentInGlobalOverlay(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: item.file, title: nil, text: !isStarred ? strongSelf.presentationData.strings.Conversation_StickerAddedToFavorites : strongSelf.presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), with: nil)
                                                    case let .limitExceeded(limit, premiumLimit):
                                                        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: strongSelf.context.currentAppConfiguration.with { $0 })
                                                        let text: String
                                                        if limit == premiumLimit || premiumConfiguration.isPremiumDisabled  {
                                                            text = strongSelf.presentationData.strings.Premium_MaxFavedStickersFinalText
                                                        } else {
                                                            text = strongSelf.presentationData.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
                                                        }
                                                        strongSelf.controller?.presentInGlobalOverlay(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: item.file, title: strongSelf.presentationData.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil, customAction: nil), elevatedLayout: false, action: { [weak self] action in
                                                            if let strongSelf = self {
                                                                if case .info = action {
                                                                    let controller = PremiumIntroScreen(context: strongSelf.context, source: .savedStickers)
                                                                    strongSelf.controller?.push(controller)
                                                                    return true
                                                                }
                                                            }
                                                            return false
                                                        }), with: nil)
                                                }
                                            })
                                        }
                                    })),
                                    .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.StickerPack_ViewPack, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                        f(.default)
                                        
                                        if let strongSelf = self {
                                            loop: for attribute in item.file.attributes {
                                                switch attribute {
                                                case let .Sticker(_, packReference, _):
                                                    if let packReference = packReference {
                                                        let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controller?.navigationController as? NavigationController, sendSticker: { file, sourceNode, sourceRect in
                                                            if let strongSelf = self {
                                                                return strongSelf.sendSticker?(file, sourceNode, sourceRect) ?? false
                                                            } else {
                                                                return false
                                                            }
                                                        })
                                                        
                                                        strongSelf.controller?.view.endEditing(true)
                                                        strongSelf.controller?.present(controller, in: .window(.root))
                                                    }
                                                    break loop
                                                default:
                                                    break
                                                }
                                            }
                                        }
                                    }))
                                ]
                                return (itemNode.view, itemNode.bounds, StickerPreviewPeekContent(account: strongSelf.context.account, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, item: item, menu: menuItems, openPremiumIntro: { [weak self] in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    let controller = PremiumIntroScreen(context: strongSelf.context, source: .stickers)
                                    strongSelf.controller?.push(controller)
                                }))
                            } else {
                                return nil
                            }
                        }
                    }
                }
                return nil
            }
            
            let itemNodeAndItem: (ASDisplayNode, StickerPackItem)? = strongSelf.itemAt(point: point)
            if let (itemNode, item) = itemNodeAndItem {
                return strongSelf.context.engine.stickers.isStickerSaved(id: item.file.fileId)
                |> deliverOnMainQueue
                |> map { isStarred -> (UIView, CGRect, PeekControllerContent)? in
                    if let strongSelf = self {
                        var menuItems: [ContextMenuItem] = []
                        menuItems = [
                            .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.StickerPack_Send, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                if let strongSelf = self, let peekController = strongSelf.peekController, let animationNode = (peekController.contentNode as? StickerPreviewPeekContentNode)?.animationNode {
                                    let _ = strongSelf.sendSticker?(.standalone(media: item.file), animationNode.view, animationNode.bounds)
                                }
                                f(.default)
                            })),
                            .action(ContextMenuActionItem(text: isStarred ? strongSelf.presentationData.strings.Stickers_RemoveFromFavorites : strongSelf.presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                f(.default)
                                
                                if let strongSelf = self {
                                    let _ = (strongSelf.context.engine.stickers.toggleStickerSaved(file: item.file, saved: !isStarred)
                                    |> deliverOnMainQueue).start(next: { result in
                                        switch result {
                                            case .generic:
                                            strongSelf.controller?.presentInGlobalOverlay(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: item.file, title: nil, text: !isStarred ? strongSelf.presentationData.strings.Conversation_StickerAddedToFavorites : strongSelf.presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), with: nil)
                                            case let .limitExceeded(limit, premiumLimit):
                                                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: strongSelf.context.currentAppConfiguration.with { $0 })
                                                let text: String
                                                if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                                    text = strongSelf.presentationData.strings.Premium_MaxFavedStickersFinalText
                                                } else {
                                                    text = strongSelf.presentationData.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
                                                }
                                                strongSelf.controller?.presentInGlobalOverlay(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: item.file, title: strongSelf.presentationData.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil, customAction: nil), elevatedLayout: false, action: { [weak self] action in
                                                    if let strongSelf = self {
                                                        if case .info = action {
                                                            let controller = PremiumIntroScreen(context: strongSelf.context, source: .savedStickers)
                                                            strongSelf.controller?.push(controller)
                                                            return true
                                                        }
                                                    }
                                                    return false
                                                }), with: nil)
                                        }
                                    })
                                }
                            })),
                            .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.StickerPack_ViewPack, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                f(.default)
                                
                                if let strongSelf = self {
                                    loop: for attribute in item.file.attributes {
                                        switch attribute {
                                        case let .Sticker(_, packReference, _):
                                            if let packReference = packReference {
                                                let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controller?.navigationController as? NavigationController, sendSticker: { file, sourceNode, sourceRect in
                                                    if let strongSelf = self {
                                                        return strongSelf.sendSticker?(file, sourceNode, sourceRect) ?? false
                                                    } else {
                                                        return false
                                                    }
                                                })
                                                
                                                strongSelf.controller?.view.endEditing(true)
                                                strongSelf.controller?.present(controller, in: .window(.root))
                                            }
                                            break loop
                                        default:
                                            break
                                        }
                                    }
                                }
                            }))
                        ]
                        return (itemNode.view, itemNode.bounds, StickerPreviewPeekContent(account: strongSelf.context.account, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, item: .pack(item.file), menu: menuItems, openPremiumIntro: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            let controller = PremiumIntroScreen(context: strongSelf.context, source: .stickers)
                            strongSelf.controller?.push(controller)
                        }))
                    } else {
                        return nil
                    }
                }
            }
            return nil
        }, present: { [weak self] content, sourceView, sourceRect in
            if let strongSelf = self {
                let controller = PeekController(presentationData: strongSelf.presentationData, content: content, sourceView: {
                    return (sourceView, sourceRect)
                })
                strongSelf.peekController = controller
                strongSelf.controller?.presentInGlobalOverlay(controller)
                return controller
            }
            return nil
        }, updateContent: { _ in
        }))
    }
    
    private var isInFocus: Bool = false
    
    func inFocusUpdated(isInFocus: Bool) {
        self.isInFocus = isInFocus
        
        if let searchNode = self.searchNode {
            self.searchItemContext.canPlayMedia = isInFocus
            searchNode.updateCanPlayMedia()
        }
        
        self.updateCanPlayMedia()
    }
    
    func updateCanPlayMedia() {
        var isSearchActive = false
        if let searchNode = self.searchNode {
            isSearchActive = searchNode.isActive
        }
        
        self.interaction?.itemContext.canPlayMedia = self.isInFocus && !isSearchActive
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                itemNode.updateCanPlayMedia()
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let firstTime = self.validLayout == nil
        
        self.validLayout = layout
        
        var insets = layout.insets(options: [.statusBar])
        insets.top += navigationHeight
        
        if let searchNode = self.searchNode {
            let searchNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top))
            transition.updateFrame(node: searchNode, frame: searchNodeFrame)
            searchNode.updateLayout(size: searchNodeFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: insets.bottom + layout.safeInsets.bottom, inputHeight: layout.inputHeight ?? 0.0, deviceMetrics: layout.deviceMetrics, transition: transition)
        }
        
        var itemSize = CGSize(width: layout.size.width, height: 128.0)
        if case .regular = layout.metrics.widthClass, layout.size.width > 480.0 {
            itemSize.width -= 60.0
            insets.left += 30.0
            insets.right += 30.0
        }
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: UIEdgeInsets(top: insets.top, left: insets.left + layout.safeInsets.left, bottom: insets.bottom + layout.safeInsets.bottom, right: insets.right + layout.safeInsets.right), preloadSize: 300.0, type: .fixed(itemSize: itemSize, fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        transition.updateFrame(node: self.gridNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: layout.size.height)))
        
        if firstTime {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
            if !self.didSetReady {
                self.didSetReady = true
                self._ready.set(.single(true))
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        
        return super.hitTest(point, with: event)
    }
    
    private func enqueueTransition(_ transition: FeaturedTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let itemTransition: ContainedViewLayoutTransition = .immediate
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: itemTransition, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, synchronousLoads: transition.initial), completion: { [weak self] _ in
                if let strongSelf = self, transition.initial {
                    strongSelf.gridNode.forEachItemNode({ itemNode in
                        if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode, itemNode.item?.info.id == strongSelf.controller?.highlightedPackId {
                            itemNode.highlight()
                        }
                    })
                }
            })
        }
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, StickerPackItem)? {
        let localPoint = self.view.convert(point, to: self.gridNode.view)
        var resultNode: StickerPaneSearchGlobalItemNode?
        self.gridNode.forEachItemNode { itemNode in
            if itemNode.frame.contains(localPoint), let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                resultNode = itemNode
            }
        }
        if let resultNode = resultNode {
            return resultNode.itemAt(point: self.gridNode.view.convert(localPoint, to: resultNode.view))
        }
        return nil
    }
    
    func updatePreviewing(animated: Bool) {
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                itemNode.updatePreviewing(animated: animated)
            }
        }
    }
}

final class FeaturedStickersScreen: ViewController {
    private let context: AccountContext
    fileprivate let highlightedPackId: ItemCollectionId?
    private let sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?
    
    private var controllerNode: FeaturedStickersScreenNode {
        return self.displayNode as! FeaturedStickersScreenNode
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    fileprivate var searchNavigationNode: SearchNavigationContentNode?
    
    public init(context: AccountContext, highlightedPackId: ItemCollectionId?, sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)? = nil) {
        self.context = context
        self.highlightedPackId = highlightedPackId
        self.sendSticker = sendSticker
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.navigationPresentation = .modal
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        let searchNavigationNode = SearchNavigationContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, placeholder: { strings in return strings.Stickers_Search }, cancel: { [weak self] in
            self?.dismiss()
        })
        self.searchNavigationNode = searchNavigationNode
        
        self.navigationBar?.setContentNode(searchNavigationNode, animated: false)
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previous = strongSelf.presentationData
                strongSelf.presentationData = presentationData
                
                if previous.theme !== presentationData.theme || previous.strings !== presentationData.strings {
                    strongSelf.updatePresentationData()
                }
            }
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updatePresentationData() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.searchNavigationNode?.updatePresentationData(theme: self.presentationData.theme, strings: self.presentationData.strings)
        
        self.controllerNode.updatePresentationData(presentationData: presentationData)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = FeaturedStickersScreenNode(
            context: self.context,
            controller: self,
            sendSticker: self.sendSticker.flatMap { [weak self] sendSticker in
                return { file, sourceNode, sourceRect in
                    if sendSticker(file, sourceNode, sourceRect) {
                        self?.dismiss()
                        return true
                    } else {
                        return false
                    }
                }
            }
        )
        
        self._ready.set(self.controllerNode.ready.get())
        
        super.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override public func inFocusUpdated(isInFocus: Bool) {
        self.controllerNode.inFocusUpdated(isInFocus: isInFocus)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private final class SearchNavigationContentNode: NavigationBarContentNode {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let cancel: () -> Void
    
    private let searchBar: SearchBarNode
    
    private var queryUpdated: ((String, String?) -> Void)?
    private var placeholder: ((PresentationStrings) -> String)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, placeholder: ((PresentationStrings) -> String)? = nil, cancel: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.placeholder = placeholder
        
        self.cancel = cancel
        
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: theme), strings: strings, fieldStyle: .modern, cancelText: strings.Common_Done)
        let placeholderText = placeholder?(strings) ?? strings.Common_Search
        let searchBarFont = Font.regular(17.0)
        
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        
        super.init()
        
        self.addSubnode(self.searchBar)
        
        self.searchBar.cancel = { [weak self] in
            //self?.searchBar.deactivate(clear: false)
            self?.cancel()
        }
        
        self.searchBar.textUpdated = { [weak self] query, languageCode in
            self?.queryUpdated?(query, languageCode)
        }
    }
    
    func updatePresentationData(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: theme), strings: strings)
    }
    
    func setQueryUpdated(_ f: @escaping (String, String?) -> Void) {
        self.queryUpdated = f
    }
    
    func setActivity(_ value: Bool) {
        self.searchBar.activity = value
    }
    
    override var nominalHeight: CGFloat {
        return 54.0
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: 1.0 + size.height - self.nominalHeight), size: CGSize(width: size.width, height: 54.0))
        self.searchBar.frame = searchBarFrame
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func activate() {
        self.searchBar.activate()
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
}

private enum FeaturedSearchEntryId: Equatable, Hashable {
    case sticker(String?, Int64)
    case global(ItemCollectionId)
}

private enum FeaturedSearchEntry: Identifiable, Comparable {
    case sticker(index: Int, code: String?, stickerItem: FoundStickerItem, theme: PresentationTheme)
    case global(index: Int, info: StickerPackCollectionInfo, topItems: [StickerPackItem], installed: Bool, topSeparator: Bool)
    
    var stableId: FeaturedSearchEntryId {
        switch self {
        case let .sticker(_, code, stickerItem, _):
            return .sticker(code, stickerItem.file.fileId.id)
        case let .global(_, info, _, _, _):
            return .global(info.id)
        }
    }
    
    static func ==(lhs: FeaturedSearchEntry, rhs: FeaturedSearchEntry) -> Bool {
        switch lhs {
        case let .sticker(lhsIndex, lhsCode, lhsStickerItem, lhsTheme):
            if case let .sticker(rhsIndex, rhsCode, rhsStickerItem, rhsTheme) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsCode != rhsCode {
                    return false
                }
                if lhsStickerItem != rhsStickerItem {
                    return false
                }
                if lhsTheme !== rhsTheme {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .global(index, info, topItems, installed, topSeparator):
            if case .global(index, info, topItems, installed, topSeparator) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: FeaturedSearchEntry, rhs: FeaturedSearchEntry) -> Bool {
        switch lhs {
        case let .sticker(lhsIndex, _, _, _):
            switch rhs {
            case let .sticker(rhsIndex, _, _, _):
                return lhsIndex < rhsIndex
            default:
                return true
            }
        case let .global(lhsIndex, _, _, _, _):
            switch rhs {
            case .sticker:
                return false
            case let .global(rhsIndex, _, _, _, _):
                return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, interaction: StickerPaneSearchInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction, itemContext: StickerPaneSearchGlobalItemContext) -> GridItem {
        switch self {
        case let .sticker(_, code, stickerItem, theme):
            return StickerPaneSearchStickerItem(account: account, code: code, stickerItem: stickerItem, inputNodeInteraction: inputNodeInteraction, theme: theme, selected: { node, rect in
                interaction.sendSticker(.standalone(media: stickerItem.file), node.view, rect)
            })
        case let .global(_, info, topItems, installed, topSeparator):
            return StickerPaneSearchGlobalItem(account: account, theme: theme, strings: strings, listAppearance: true, fillsRow: true, info: info, topItems: topItems, topSeparator: topSeparator, regularInsets: false, installed: installed, unread: false, open: {
                interaction.open(info)
            }, install: {
                interaction.install(info, topItems, !installed)
            }, getItemIsPreviewed: { item in
                return interaction.getItemIsPreviewed(item)
            }, itemContext: itemContext)
        }
    }
}

private struct FeaturedSearchGridTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
    let animated: Bool
}

private func preparedFeaturedSearchEntryTransition(account: Account, theme: PresentationTheme, strings: PresentationStrings, from fromEntries: [FeaturedSearchEntry], to toEntries: [FeaturedSearchEntry], interaction: StickerPaneSearchInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction, itemContext: StickerPaneSearchGlobalItemContext) -> FeaturedSearchGridTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    var animated = false
    animated = true
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction, itemContext: itemContext), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction, itemContext: itemContext)) }
    
    let firstIndexInSectionOffset = 0
    
    return FeaturedSearchGridTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: firstIndexInSectionOffset, stationaryItems: stationaryItems, scrollToItem: scrollToItem, animated: animated)
}

private final class FeaturedPaneSearchContentNode: ASDisplayNode {
    private let context: AccountContext
    private let inputNodeInteraction: ChatMediaInputNodeInteraction
    private var interaction: StickerPaneSearchInteraction?
    private weak var controller: FeaturedStickersScreen?
    private let sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?
    private let itemContext: StickerPaneSearchGlobalItemContext
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let gridNode: GridNode
    private let notFoundNode: ASImageNode
    private let notFoundLabel: ImmediateTextNode
    
    private var validLayout: CGSize?
    
    private var enqueuedTransitions: [FeaturedSearchGridTransition] = []
    
    private let searchDisposable = MetaDisposable()
    
    private let queue = Queue()
    private let currentEntries = Atomic<[FeaturedSearchEntry]?>(value: nil)
    private let currentRemotePacks = Atomic<FoundStickerSets?>(value: nil)
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    var deactivateSearchBar: (() -> Void)?
    var updateActivity: ((Bool) -> Void)?
    
    private let installDisposable = MetaDisposable()
    
    var isActive: Bool {
        return !self.gridNode.isHidden
    }
    var isActiveUpdated: (() -> Void)?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, inputNodeInteraction: ChatMediaInputNodeInteraction, controller: FeaturedStickersScreen, sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?, itemContext: StickerPaneSearchGlobalItemContext) {
        self.context = context
        self.inputNodeInteraction = inputNodeInteraction
        self.controller = controller
        self.sendSticker = sendSticker
        self.itemContext = itemContext
        
        self.theme = theme
        self.strings = strings
        
        self.gridNode = GridNode()
        self.gridNode.backgroundColor = theme.list.plainBackgroundColor
        
        self.notFoundNode = ASImageNode()
        self.notFoundNode.displayWithoutProcessing = true
        self.notFoundNode.displaysAsynchronously = false
        self.notFoundNode.clipsToBounds = false
        
        self.notFoundLabel = ImmediateTextNode()
        self.notFoundLabel.displaysAsynchronously = false
        self.notFoundLabel.isUserInteractionEnabled = false
        self.notFoundNode.addSubnode(self.notFoundLabel)
        
        self.gridNode.isHidden = true
        self.notFoundNode.isHidden = true
        
        super.init()
        
        self.addSubnode(self.gridNode)
        self.addSubnode(self.notFoundNode)
        
        self.gridNode.scrollView.alwaysBounceVertical = true
        self.gridNode.scrollingInitiated = { [weak self] in
            self?.deactivateSearchBar?()
        }
        
        self.interaction = StickerPaneSearchInteraction(open: { [weak self] info in
            if let strongSelf = self {
                strongSelf.view.window?.endEditing(true)
                let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
                let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.controller?.navigationController as? NavigationController, sendSticker: { [weak self] fileReference, sourceNode, sourceRect in
                    if let strongSelf = self {
                        return strongSelf.sendSticker?(fileReference, sourceNode, sourceRect) ?? false
                    } else {
                        return false
                    }
                })
                strongSelf.controller?.present(controller, in: .window(.root))
            }
        }, install: { [weak self] info, items, install in
            guard let strongSelf = self else {
                return
            }
            if install {
                let _ = strongSelf.context.engine.stickers.addStickerPackInteractively(info: info, items: []).start()
            } else {
                let _ = (strongSelf.context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .delete)
                |> deliverOnMainQueue).start(next: { _ in
                })
            }
        }, sendSticker: { [weak self] file, sourceView, sourceRect in
            if let strongSelf = self {
                let _ = strongSelf.sendSticker?(file, sourceView, sourceRect)
            }
        }, getItemIsPreviewed: { item in
            return inputNodeInteraction.previewedStickerPackItem == .pack(item.file)
        })
        
        self._ready.set(.single(Void()))
    
        self.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    deinit {
        self.searchDisposable.dispose()
        self.installDisposable.dispose()
    }
    
    func updateText(_ text: String, languageCode: String?) {
        let signal: Signal<([(String?, FoundStickerItem)], FoundStickerSets, Bool, FoundStickerSets?)?, NoError>
        if !text.isEmpty {
            let context = self.context
            let stickers: Signal<[(String?, FoundStickerItem)], NoError> = Signal { subscriber in
                var signals: Signal<[Signal<(String?, [FoundStickerItem]), NoError>], NoError> = .single([])
                
                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if query.isSingleEmoji {
                    signals = .single([context.engine.stickers.searchStickers(query: text.basicEmoji.0)
                    |> map { (nil, $0) }])
                } else if query.count > 1, let languageCode = languageCode, !languageCode.isEmpty && languageCode != "emoji" {
                    var signal = context.engine.stickers.searchEmojiKeywords(inputLanguageCode: languageCode, query: query.lowercased(), completeMatch: query.count < 3)
                    if !languageCode.lowercased().hasPrefix("en") {
                        signal = signal
                        |> mapToSignal { keywords in
                            return .single(keywords)
                            |> then(
                                context.engine.stickers.searchEmojiKeywords(inputLanguageCode: "en-US", query: query.lowercased(), completeMatch: query.count < 3)
                                |> map { englishKeywords in
                                    return keywords + englishKeywords
                                }
                            )
                        }
                    }
                    
                    signals = signal
                    |> map { keywords -> [Signal<(String?, [FoundStickerItem]), NoError>] in
                        var signals: [Signal<(String?, [FoundStickerItem]), NoError>] = []
                        let emoticons = keywords.flatMap { $0.emoticons }
                        for emoji in emoticons {
                            signals.append(context.engine.stickers.searchStickers(query: emoji.basicEmoji.0)
                            |> take(1)
                            |> map { (emoji, $0) })
                        }
                        return signals
                    }
                }
                
                return (signals
                |> mapToSignal { signals in
                    return combineLatest(signals)
                }).start(next: { results in
                    var result: [(String?, FoundStickerItem)] = []
                    for (emoji, stickers) in results {
                        for sticker in stickers {
                            result.append((emoji, sticker))
                        }
                    }
                    subscriber.putNext(result)
                }, completed: {
                    subscriber.putCompletion()
                })
            }
            
            let local = context.engine.stickers.searchStickerSets(query: text)
            let remote = context.engine.stickers.searchStickerSetsRemotely(query: text)
            |> delay(0.2, queue: Queue.mainQueue())
            let rawPacks = local
            |> mapToSignal { result -> Signal<(FoundStickerSets, Bool, FoundStickerSets?), NoError> in
                var localResult = result
                if let currentRemote = self.currentRemotePacks.with ({ $0 }) {
                    localResult = localResult.merge(with: currentRemote)
                }
                return .single((localResult, false, nil))
                |> then(
                    remote
                    |> map { remote -> (FoundStickerSets, Bool, FoundStickerSets?) in
                        return (result.merge(with: remote), true, remote)
                    }
                )
            }
            
            let installedPackIds = context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])])
            |> map { view -> Set<ItemCollectionId> in
                var installedPacks = Set<ItemCollectionId>()
                if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
                    if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
                        for entry in packsEntries {
                            installedPacks.insert(entry.id)
                        }
                    }
                }
                return installedPacks
            }
            |> distinctUntilChanged
            let packs = combineLatest(rawPacks, installedPackIds)
            |> map { packs, installedPackIds -> (FoundStickerSets, Bool, FoundStickerSets?) in
                var (localPacks, completed, remotePacks) = packs
                
                for i in 0 ..< localPacks.infos.count {
                    let installed = installedPackIds.contains(localPacks.infos[i].0)
                    if installed != localPacks.infos[i].3 {
                        localPacks.infos[i].3 = installed
                    }
                }
                
                if remotePacks != nil {
                    for i in 0 ..< remotePacks!.infos.count {
                        let installed = installedPackIds.contains(remotePacks!.infos[i].0)
                        if installed != remotePacks!.infos[i].3 {
                            remotePacks!.infos[i].3 = installed
                        }
                    }
                }
                
                return (localPacks, completed, remotePacks)
            }
            
            signal = combineLatest(stickers, packs)
            |> map { stickers, packs -> ([(String?, FoundStickerItem)], FoundStickerSets, Bool, FoundStickerSets?)? in
                return (stickers, packs.0, packs.1, packs.2)
            }
            self.updateActivity?(true)
        } else {
            signal = .single(nil)
            self.updateActivity?(false)
        }
        
        self.searchDisposable.set((signal
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            Queue.mainQueue().async {
                guard let strongSelf = self, let interaction = strongSelf.interaction else {
                    return
                }
                
                var displayResults: Bool = false
                
                var entries: [FeaturedSearchEntry] = []
                if let (stickers, packs, final, remote) = result {
                    if let remote = remote {
                        let _ = strongSelf.currentRemotePacks.swap(remote)
                    }
                    
                    if final {
                        strongSelf.updateActivity?(false)
                    }
                    
                    var index = 0
                    var existingStickerIds = Set<MediaId>()
                    var previousCode: String?
                    for (code, sticker) in stickers {
                        if let id = sticker.file.id, !existingStickerIds.contains(id) {
                            entries.append(.sticker(index: index, code: code != previousCode ? code : nil, stickerItem: sticker, theme: strongSelf.theme))
                            index += 1
                            
                            previousCode = code
                            existingStickerIds.insert(id)
                        }
                    }
                    var isFirstGlobal = true
                    for (collectionId, info, _, installed) in packs.infos {
                        if let info = info as? StickerPackCollectionInfo {
                            var topItems: [StickerPackItem] = []
                            for e in packs.entries {
                                if let item = e.item as? StickerPackItem {
                                    if e.index.collectionId == collectionId {
                                        topItems.append(item)
                                    }
                                }
                            }
                            entries.append(.global(index: index, info: info, topItems: topItems, installed: installed, topSeparator: !isFirstGlobal))
                            isFirstGlobal = false
                            index += 1
                        }
                    }
                    
                    if final || !entries.isEmpty {
                        strongSelf.notFoundNode.isHidden = !entries.isEmpty
                    }
                    
                    displayResults = true
                } else {
                    let _ = strongSelf.currentRemotePacks.swap(nil)
                    strongSelf.updateActivity?(false)
                }
                
                let previousEntries = strongSelf.currentEntries.swap(entries)
                let transition = preparedFeaturedSearchEntryTransition(account: strongSelf.context.account, theme: strongSelf.theme, strings: strongSelf.strings, from: previousEntries ?? [], to: entries, interaction: interaction, inputNodeInteraction: strongSelf.inputNodeInteraction, itemContext: strongSelf.itemContext)
                strongSelf.enqueueTransition(transition)
                
                if displayResults {
                    strongSelf.gridNode.isHidden = false
                } else {
                    strongSelf.gridNode.isHidden = true
                    strongSelf.notFoundNode.isHidden = true
                }
                strongSelf.isActiveUpdated?()
            }
        }))
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.notFoundNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/StickersNotFoundIcon"), color: theme.list.freeMonoIconColor)
        self.notFoundLabel.attributedText = NSAttributedString(string: strings.Stickers_NoStickersFound, font: Font.medium(14.0), textColor: theme.list.freeTextColor)
    }
    
    private func enqueueTransition(_ transition: FeaturedSearchGridTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let itemTransition: ContainedViewLayoutTransition = .immediate
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: itemTransition, stationaryItems: .none, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset, synchronousLoads: true), completion: { _ in })
            self.gridNode.recursivelyEnsureDisplaySynchronously(true)
        }
    }
    
    func updatePreviewing(animated: Bool) {
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? StickerPaneSearchStickerItemNode {
                itemNode.updatePreviewing(animated: animated)
            } else if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                itemNode.updatePreviewing(animated: animated)
            }
        }
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, Any)? {
        if let itemNode = self.gridNode.itemNodeAtPoint(self.view.convert(point, to: self.gridNode.view)) {
            if let itemNode = itemNode as? StickerPaneSearchStickerItemNode, let stickerItem = itemNode.stickerItem {
                return (itemNode, StickerPreviewPeekItem.found(stickerItem))
            } else if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                if let (node, item) = itemNode.itemAt(point: self.view.convert(point, to: itemNode.view)) {
                    return (node, StickerPreviewPeekItem.pack(item.file))
                }
            }
        }
        return nil
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        let firstLayout = self.validLayout == nil

        self.validLayout = size
        
        if let image = self.notFoundNode.image {
            let areaHeight = size.height - inputHeight
            
            let labelSize = self.notFoundLabel.updateLayout(CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude))
            
            transition.updateFrame(node: self.notFoundNode, frame: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((areaHeight - image.size.height - labelSize.height) / 2.0)), size: image.size))
            transition.updateFrame(node: self.notFoundLabel, frame: CGRect(origin: CGPoint(x: floor((image.size.width - labelSize.width) / 2.0), y: image.size.height + 8.0), size: labelSize))
        }
        
        let contentFrame = CGRect(origin: CGPoint(), size: size)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: contentFrame.size, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 4.0 + bottomInset, right: 0.0), preloadSize: 300.0, type: .fixed(itemSize: CGSize(width: 75.0, height: 75.0), fillWidth: nil, lineSpacing: 0.0, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        transition.updateFrame(node: self.gridNode, frame: contentFrame)
        if firstLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    func animateIn(additivePosition: CGFloat, transition: ContainedViewLayoutTransition) {
        self.gridNode.alpha = 0.0
        transition.updateAlpha(node: self.gridNode, alpha: 1.0, completion: { _ in
        })
    }
    
    func animateOut(transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.gridNode, alpha: 0.0, completion: { _ in
        })
        transition.updateAlpha(node: self.notFoundNode, alpha: 0.0, completion: { _ in
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        
        if self.gridNode.isHidden {
            return nil
        }
        
        return super.hitTest(point, with: event)
    }
    
    func updateCanPlayMedia() {
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? StickerPaneSearchGlobalItemNode {
                itemNode.updateCanPlayMedia()
            }
        }
    }
}

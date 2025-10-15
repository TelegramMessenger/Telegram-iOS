import AsyncDisplayKit
import UIKit
import Display
import ComponentFlow
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListPeerItem
import ItemListPeerActionItem
import MergeLists
import ItemListUI
import ChatControllerInteraction
import MultilineTextComponent
import BalancedTextComponent
import Markdown
import PeerInfoPaneNode
import GiftItemComponent
import PlainButtonComponent
import GiftViewScreen
import ButtonComponent
import UndoUI
import CheckComponent
import LottieComponent
import ContextUI
import TabSelectorComponent
import BundleIconComponent
import EmojiTextAttachmentView
import TextFormat
import PromptUI
import CollectionTabItemComponent

public final class PeerInfoGiftsPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate {
    public enum GiftCollection: Equatable {
        case all
        case collection(Int32)
        case create
        
        init(rawValue: Int32) {
            switch rawValue {
            case 0:
                self = .all
            case -1:
                self = .create
            default:
                self = .collection(rawValue)
            }
        }
        
        public var rawValue: Int32 {
            switch self {
            case .all:
                return 0
            case .create:
                return -1
            case let .collection(id):
                return id
            }
        }
    }
    
    private let context: AccountContext
    private let peerId: PeerId
    private let profileGiftsCollections: ProfileGiftsCollectionsContext
    private let profileGifts: ProfileGiftsContext
    private let canManage: Bool
    private let canGift: Bool
    private var peer: EnginePeer?
    private let initialGiftCollectionId: Int64?
    
    private var resultsAreEmpty = false
    
    private let chatControllerInteraction: ChatControllerInteraction
    
    public weak var parentController: ViewController? {
        didSet {
            self.giftsListView.parentController = self.parentController
        }
    }
    
    private let backgroundNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    private var giftsListView: GiftsListView
    
    private let tabSelector = ComponentView<Empty>()
    public private(set) var currentCollection: GiftCollection = .all
    
    private var panelBackground: NavigationBackgroundNode?
    private var panelSeparator: ASDisplayNode?
    private var panelButton: ComponentView<Empty>?
    private var panelCheck: ComponentView<Empty>?
        
    private var currentParams: (size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData)?
    
    private var theme: PresentationTheme?
    private let presentationDataPromise = Promise<PresentationData>()
    
    private var collectionsDisposable: Disposable?
    private var collections: [StarGiftCollection]?
    private var reorderedCollectionIds: [Int32]?
    private var isReordering = false
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    public var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    public var status: Signal<PeerInfoStatusData?, NoError> {
        self.statusPromise.get()
    }
    
    public var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    public var tabBarOffset: CGFloat {
        return 0.0
    }
    
    public var giftsContext: ProfileGiftsContext {
        return self.giftsListView.profileGifts
    }
    
    public var openShareLink: ((String) -> Void)?
    
    private let collectionsMaxCount: Int
    
    public init(context: AccountContext, peerId: PeerId, chatControllerInteraction: ChatControllerInteraction, profileGiftsCollections: ProfileGiftsCollectionsContext, profileGifts: ProfileGiftsContext, canManage: Bool, canGift: Bool, initialGiftCollectionId: Int64?) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        self.profileGiftsCollections = profileGiftsCollections
        self.profileGifts = profileGifts
        self.canManage = canManage
        self.canGift = canGift
        self.initialGiftCollectionId = initialGiftCollectionId
        
        if let value = context.currentAppConfiguration.with({ $0 }).data?["stargifts_collections_limit"] as? Double {
            self.collectionsMaxCount = Int(value)
        } else {
            self.collectionsMaxCount = 6
        }
        
        self.backgroundNode = ASDisplayNode()
        self.scrollNode = ASScrollNode()
        self.giftsListView = GiftsListView(context: context, peerId: peerId, profileGifts: profileGifts, giftsCollections: profileGiftsCollections, canSelect: false)
                
        super.init()
                
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.scrollNode)
        
        self.statusPromise.set(self.giftsListView.status)
        self.ready.set(self.giftsListView.isReady)
        
        self.giftsListView.onContentUpdated = { [weak self] in
            guard let self else {
                return
            }
            if let params = self.currentParams {
                self.update(size: params.size, topInset: params.topInset, sideInset: params.sideInset, bottomInset: params.bottomInset, deviceMetrics: params.deviceMetrics, visibleHeight: params.visibleHeight, isScrollingLockedAtTop: params.isScrollingLockedAtTop, expandProgress: params.expandProgress, navigationHeight: params.navigationHeight, presentationData: params.presentationData, synchronous: true, transition: .immediate)
            }
        }
        self.giftsListView.contextAction = { [weak self] gift, view, gesture in
            guard let self else {
                return
            }
            self.contextAction(gift: gift, view: view, gesture: gesture)
        }
        self.giftsListView.displayUnpinScreen = { [weak self] gift, completion in
            guard let self else {
                return
            }
            self.displayUnpinScreen(gift: gift, completion: completion)
        }
        
        self.collectionsDisposable = (profileGiftsCollections.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self else {
                return
            }
            self.collections = state.collections
            self.updateScrolling(transition: .easeInOut(duration: 0.2))
        })
        
        if let initialGiftCollectionId {
            self.setCurrentCollection(collection: .collection(Int32(initialGiftCollectionId)))
        }
        
        let _ = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self else {
                return
            }
            self.peer = peer
            self.updateScrolling(transition: .immediate)
        })
    }
    
    deinit {
        self.collectionsDisposable?.dispose()
    }
        
    public override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        self.scrollNode.view.delegate = self
        
        if let tabSelectorView = self.tabSelector.view {
            self.scrollNode.view.insertSubview(self.giftsListView, aboveSubview: tabSelectorView)
        } else {
            self.scrollNode.view.insertSubview(self.giftsListView, at: 0)
        }
    }
    
    private func item(at point: CGPoint) -> (AnyHashable, ComponentView<Empty>)? {
        return self.giftsListView.item(at: self.giftsListView.convert(point, from: self.view))
    }
    
    public func createCollection(gifts: [ProfileGiftsContext.State.StarGift] = []) {
        guard let params = self.currentParams else {
            return
        }
        if let collections = self.collections, collections.count >= self.collectionsMaxCount {
            let alertController = textAlertController(context: self.context, title: params.presentationData.strings.PeerInfo_Gifts_CollectionLimitReached_Title, text: params.presentationData.strings.PeerInfo_Gifts_CollectionLimitReached_Text, actions: [TextAlertAction(type: .defaultAction, title: params.presentationData.strings.Common_OK, action: {})])
            self.parentController?.present(alertController, in: .window(.root))
            return
        }
        
        let promptController = promptController(sharedContext: self.context.sharedContext, updatedPresentationData: nil, text: params.presentationData.strings.PeerInfo_Gifts_CreateCollection_Title, titleFont: .bold, subtitle: params.presentationData.strings.PeerInfo_Gifts_CreateCollection_Text, value: "", placeholder: params.presentationData.strings.PeerInfo_Gifts_CreateCollection_Placeholder, characterLimit: 12, displayCharacterLimit: true, apply: { [weak self] value in
            guard let self, let value else {
                return
            }
            let _ = self.profileGiftsCollections.createCollection(title: value, starGifts: gifts).start(next: { [weak self] collection in
                guard let self else {
                    return
                }
                if let collection {
                    self.setCurrentCollection(collection: .collection(collection.id))
                    
                    if let tabSelectorView = self.tabSelector.view as? TabSelectorComponent.View {
                        tabSelectorView.scrollToEnd()
                    }
                }
            })
        })
        self.parentController?.present(promptController, in: .window(.root))
    }
    
    public func deleteCollection(id: Int32) {
        guard let params = self.currentParams else {
            return
        }
        let actionSheet = ActionSheetController(presentationData: params.presentationData)
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: params.presentationData.strings.PeerInfo_Gifts_RemoveCollectionConfirmation),
                ActionSheetButtonItem(title: params.presentationData.strings.PeerInfo_Gifts_RemoveCollectionAction, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    self?.setCurrentCollection(collection: .all)
                    let _ = self?.profileGiftsCollections.deleteCollection(id: id).start()
                    
                    if let tabSelectorView = self?.tabSelector.view as? TabSelectorComponent.View {
                        tabSelectorView.scrollToStart()
                    }
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: params.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        self.parentController?.present(actionSheet, in: .window(.root))
    }
    
    public func addGiftsToCollection(id: Int32) {
        var collectionGiftsMaxCount: Int32 = 1000
        if let value = self.context.currentAppConfiguration.with({ $0 }).data?["stargifts_collection_gifts_limit"] as? Double {
            collectionGiftsMaxCount = Int32(value)
        }
        var remainingCount = collectionGiftsMaxCount
        if let currentCount = self.giftsListView.profileGifts.currentState?.count {
            remainingCount = max(0, collectionGiftsMaxCount - currentCount)
        }
        let screen = AddGiftsScreen(context: self.context, peerId: self.peerId, collectionId: id, remainingCount: remainingCount, completion: { [weak self] gifts in
            guard let self else {
                return
            }
            let _ = self.profileGiftsCollections.addGifts(id: id, gifts: gifts).start()
        })
        self.parentController?.push(screen)
    }
    
    public func renameCollection(id: Int32) {
        guard let params = self.currentParams, let collection = self.collections?.first(where: { $0.id == id }) else {
            return
        }
        
        let promptController = promptController(sharedContext: self.context.sharedContext, updatedPresentationData: nil, text: params.presentationData.strings.PeerInfo_Gifts_RenameCollection_Title, titleFont: .bold, value: collection.title, placeholder: params.presentationData.strings.PeerInfo_Gifts_CreateCollection_Placeholder, characterLimit: 12, displayCharacterLimit: true, apply: { [weak self] value in
            guard let self, let value else {
                return
            }
            let _ = self.profileGiftsCollections.renameCollection(id: id, title: value).start()
        })
        self.parentController?.present(promptController, in: .window(.root))
    }
    
    public func beginReordering() {
        self.giftsListView.beginReordering()
    }
    
    public func endReordering() {
        self.giftsListView.endReordering()
    }
    
    public func updateIsReordering(isReordering: Bool, animated: Bool) {
        if self.isReordering != isReordering {
            self.isReordering = isReordering
            
            if let collections = self.collections {
                if isReordering {
                    var collectionIds: [Int32] = []
                    for collection in collections {
                        collectionIds.append(collection.id)
                    }
                    self.reorderedCollectionIds = collectionIds
                } else if let reorderedCollectionIds = self.reorderedCollectionIds {
                    let _ = self.profileGiftsCollections.reorderCollections(order: reorderedCollectionIds).start()
                    Queue.mainQueue().after(1.0, {
                        self.reorderedCollectionIds = nil
                    })
                }
            }
         
            self.giftsListView.updateIsReordering(isReordering: isReordering, animated: animated)
            self.updateScrolling(transition: .easeInOut(duration: 0.2))
        }
    }
    
    public func ensureMessageIsVisible(id: MessageId) {
    }
    
    public func scrollToTop() -> Bool {
        self.scrollNode.view.setContentOffset(.zero, animated: true)
        return true
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrolling(interactive: true, transition: .immediate)
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        cancelContextGestures(view: scrollView)
    }
    
    private func displayUnpinScreen(gift: ProfileGiftsContext.State.StarGift, completion: (() -> Void)? = nil) {
        guard let pinnedGifts = self.profileGifts.currentState?.gifts.filter({ $0.pinnedToTop }), let presentationData = self.currentParams?.presentationData else {
            return
        }
        let controller = GiftUnpinScreen(
            context: self.context,
            gift: gift,
            pinnedGifts: pinnedGifts,
            completion: { [weak self] unpinnedReference in
                guard let self else {
                    return
                }
                completion?()
                
                var replacingTitle = ""
                for gift in pinnedGifts {
                    if gift.reference == unpinnedReference, case let .unique(uniqueGift) = gift.gift {
                        replacingTitle = "\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: presentationData.dateTimeFormat))"
                    }
                }
                
                var updatedPinnedGifts = self.giftsListView.pinnedReferences
                if let index = updatedPinnedGifts.firstIndex(of: unpinnedReference), let reference = gift.reference {
                    updatedPinnedGifts[index] = reference
                }
                self.profileGifts.updatePinnedToTopStarGifts(references: updatedPinnedGifts)
                
                var title = ""
                if case let .unique(uniqueGift) = gift.gift {
                    title = "\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: presentationData.dateTimeFormat))"
                }
                                                       
                let _ = self.scrollToTop()
                Queue.mainQueue().after(0.35) {
                    let toastTitle = presentationData.strings.PeerInfo_Gifts_ToastPinned_TitleNew(title).string
                    let toastText = presentationData.strings.PeerInfo_Gifts_ToastPinned_ReplacingText(replacingTitle).string
                    self.parentController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_toastpin", scale: 0.06, colors: [:], title: toastTitle, text: toastText, customUndoText: nil, timeout: 5), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                }
            }
        )
        self.parentController?.push(controller)
    }
    
    func setCurrentCollection(collection: GiftCollection) {
        guard self.currentCollection != collection else {
            return
        }
        var animateRight = false
        if case let .collection(currentId) = self.currentCollection {
            if case let .collection(nextId) = collection {
                if let currentIndex = self.collections?.firstIndex(where: { $0.id == currentId }), let nextIndex = self.collections?.firstIndex(where: { $0.id == nextId }) {
                    animateRight = nextIndex > currentIndex
                }
            }
        } else {
            animateRight = true
        }

        let previousGiftsListView = self.giftsListView
        
        let profileGifts: ProfileGiftsContext
        switch collection {
        case let .collection(id):
            profileGifts = self.profileGiftsCollections.giftsContextForCollection(id: id)
        default:
            profileGifts = self.profileGifts
        }
        if case .ready = profileGifts.currentState?.dataState {
            profileGifts.reload()
        }

        self.giftsListView = GiftsListView(context: self.context, peerId: self.peerId, profileGifts: profileGifts, giftsCollections: self.profileGiftsCollections, canSelect: false)
        self.giftsListView.addToCollection = { [weak self] in
            guard let self else {
                return
            }
            if case let .collection(id) = collection {
                self.addGiftsToCollection(id: id)
            }
        }
        self.giftsListView.onContentUpdated = { [weak self] in
            guard let self else {
                return
            }
            if case .collection = collection {
                self.resultsAreEmpty = self.giftsListView.resultsAreEmpty
            } else {
                self.resultsAreEmpty = false
            }
            if let params = self.currentParams {
                self.update(size: params.size, topInset: params.topInset, sideInset: params.sideInset, bottomInset: params.bottomInset, deviceMetrics: params.deviceMetrics, visibleHeight: params.visibleHeight, isScrollingLockedAtTop: params.isScrollingLockedAtTop, expandProgress: params.expandProgress, navigationHeight: params.navigationHeight, presentationData: params.presentationData, synchronous: true, transition: .immediate)
            }
        }
        self.giftsListView.displayUnpinScreen = { [weak self] gift, completion in
            guard let self else {
                return
            }
            self.displayUnpinScreen(gift: gift, completion: completion)
        }
        self.giftsListView.contextAction = { [weak self] gift, view, gesture in
            guard let self else {
                return
            }
            self.contextAction(gift: gift, view: view, gesture: gesture)
        }
        self.giftsListView.parentController = self.parentController
        self.giftsListView.frame = previousGiftsListView.frame
                                        
        self.scrollNode.view.insertSubview(self.giftsListView, aboveSubview: previousGiftsListView)
        
        let multiplier = animateRight ? 1.0 : -1.0
        
        previousGiftsListView.layer.animatePosition(from: .zero, to: CGPoint(x: previousGiftsListView.frame.width * multiplier * -1.0, y: 0.0), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
            previousGiftsListView.removeFromSuperview()
        })
        self.giftsListView.layer.animatePosition(from: CGPoint(x: previousGiftsListView.frame.width * multiplier, y: 0.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        
        self.currentCollection = collection
        self.updateScrolling(transition: .spring(duration: 0.25))
        
        if let params = self.currentParams {
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -10.0)
            let _ = self.giftsListView.update(size: params.size, sideInset: params.sideInset, bottomInset: params.bottomInset, deviceMetrics: params.deviceMetrics, visibleHeight: params.visibleHeight, isScrollingLockedAtTop: params.isScrollingLockedAtTop, expandProgress: params.expandProgress, presentationData: params.presentationData, synchronous: true, visibleBounds: visibleBounds, transition: .immediate)
        }
    }
    
    func openCollectionContextMenu(id: Int32, sourceNode: ASDisplayNode, gesture: ContextGesture?) {
        guard let params = self.currentParams, let sourceNode = sourceNode as? ContextExtractedContentContainingNode else {
            return
        }
        
        var canEditCollections = false
        if self.peerId == self.context.account.peerId || self.canManage {
            canEditCollections = true
        }
        
        var items: [ContextMenuItem] = []
        
        if canEditCollections {
            items.append(.action(ContextMenuActionItem(text: params.presentationData.strings.PeerInfo_Gifts_AddGifts, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/Gifts/AddGift"), color: theme.actionSheet.primaryTextColor)
            }, action: { [weak self] _, f in
                guard let self else {
                    return
                }
                f(.default)
                
                self.setCurrentCollection(collection: .collection(id))
                self.addGiftsToCollection(id: id)
            })))
            
            items.append(.action(ContextMenuActionItem(text: params.presentationData.strings.PeerInfo_Gifts_RenameCollection, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.actionSheet.primaryTextColor)
            }, action: { [weak self] _, f in
                guard let self else {
                    return
                }
                f(.default)
                
                Queue.mainQueue().after(0.15) {
                    self.renameCollection(id: id)
                }
            })))
        }

        if let peer = self.peer, let addressName = peer.addressName, !addressName.isEmpty {
            items.append(.action(ContextMenuActionItem(text: params.presentationData.strings.PeerInfo_Gifts_ShareCollection, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.actionSheet.primaryTextColor)
            }, action: { [weak self] _, f in
                guard let self else {
                    return
                }
                f(.default)
                
                self.openShareLink?("https://t.me/\(addressName)/c/\(id)")
            })))
        }
        
        if canEditCollections {
            items.append(.action(ContextMenuActionItem(text: params.presentationData.strings.PeerInfo_Gifts_Reorder, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.actionSheet.primaryTextColor)
            }, action: { [weak self] c, f in
                c?.dismiss(completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.beginReordering()
                })
            })))
            
            items.append(.action(ContextMenuActionItem(text: params.presentationData.strings.PeerInfo_Gifts_DeleteCollection, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { [weak self] _, f in
                guard let self else {
                    return
                }
                f(.default)
                
                Queue.mainQueue().after(0.15) {
                    self.deleteCollection(id: id)
                }
            })))
        }
        
        let contextController = ContextController(
            presentationData: params.presentationData,
            source: .extracted(GiftsExtractedContentSource(sourceNode: sourceNode)),
            items: .single(ContextController.Items(content: .list(items))),
            recognizer: nil,
            gesture: gesture
        )
        self.parentController?.presentInGlobalOverlay(contextController)
    }
    
    func updateScrolling(interactive: Bool = false, transition: ComponentTransition) {
        if let params = self.currentParams {
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -10.0)
                
            var topInset: CGFloat = 60.0
            
            var canEditCollections = false
            if self.peerId == self.context.account.peerId || self.canManage {
                canEditCollections = true
            }
            var canShare = false
            if let peer = self.peer, let addressName = peer.addressName, !addressName.isEmpty {
                canShare = true
            }
            
            let hasNonEmptyCollections = self.collections?.contains(where: { $0.count > 0 }) ?? false
            if let collections = self.collections, !collections.isEmpty && (hasNonEmptyCollections || canEditCollections) {
                var tabSelectorItems: [TabSelectorComponent.Item] = []
                tabSelectorItems.append(TabSelectorComponent.Item(
                    id: AnyHashable(GiftCollection.all.rawValue),
                    title: params.presentationData.strings.PeerInfo_Gifts_Collections_All
                ))
                                
                var effectiveCollections: [StarGiftCollection] = collections
                if let reorderedCollectionIds = self.reorderedCollectionIds {
                    var collectionMap: [Int32: StarGiftCollection] = [:]
                    for collection in collections {
                        collectionMap[collection.id] = collection
                    }
                    var reorderedCollections: [StarGiftCollection] = []
                    for id in reorderedCollectionIds {
                        if let collection = collectionMap[id] {
                            reorderedCollections.append(collection)
                        }
                    }
                    effectiveCollections = reorderedCollections
                }
                
                for collection in effectiveCollections {
                    if !canEditCollections && collection.count == 0 {
                        continue
                    }
                    tabSelectorItems.append(TabSelectorComponent.Item(
                        id: AnyHashable(GiftCollection.collection(collection.id).rawValue),
                        content: .component(AnyComponent(
                            CollectionTabItemComponent(
                                context: self.context,
                                icon: collection.icon.flatMap { .collection($0) },
                                title: collection.title,
                                theme: params.presentationData.theme
                            )
                        )),
                        isReorderable: collections.count > 1,
                        contextAction: canEditCollections || canShare ? { [weak self] sourceNode, gesture in
                            guard let self else {
                                return
                            }
                            self.openCollectionContextMenu(id: collection.id, sourceNode: sourceNode, gesture: gesture)
                        } : nil
                    ))
                }
                        
                if canEditCollections {
                    tabSelectorItems.append(TabSelectorComponent.Item(
                        id: AnyHashable(GiftCollection.create.rawValue),
                        content: .component(AnyComponent(
                            CollectionTabItemComponent(
                                context: self.context,
                                icon: .add,
                                title: params.presentationData.strings.PeerInfo_Gifts_Collections_Add,
                                theme: params.presentationData.theme
                            )
                        )),
                        isReorderable: false
                    ))
                }
                
                let tabSelectorSize = self.tabSelector.update(
                    transition: transition,
                    component: AnyComponent(TabSelectorComponent(
                        context: self.context,
                        colors: TabSelectorComponent.Colors(
                            foreground: params.presentationData.theme.list.itemSecondaryTextColor,
                            selection: params.presentationData.theme.list.itemSecondaryTextColor.withMultipliedAlpha(0.15),
                            simple: true
                        ),
                        theme: params.presentationData.theme,
                        customLayout: TabSelectorComponent.CustomLayout(
                            font: Font.medium(14.0),
                            spacing: 2.0
                        ),
                        items: tabSelectorItems,
                        selectedId: AnyHashable(self.currentCollection.rawValue),
                        reorderItem: self.isReordering ? { [weak self] fromId, toId in
                            guard let self, var reorderedCollectionIds = self.reorderedCollectionIds else {
                                return
                            }
                            guard let sourceId = fromId.base as? Int32 else {
                                return
                            }
                            guard let targetId = toId.base as? Int32 else {
                                return
                            }
                            guard let sourceIndex = reorderedCollectionIds.firstIndex(of: sourceId), let targetIndex = reorderedCollectionIds.firstIndex(of: targetId) else {
                                return
                            }
                            reorderedCollectionIds[sourceIndex] = targetId
                            reorderedCollectionIds[targetIndex] = sourceId
                            self.reorderedCollectionIds = reorderedCollectionIds
                                
                            self.updateScrolling(transition: .easeInOut(duration: 0.2))
                        } : nil,
                        setSelectedId: { [weak self] id in
                            guard let self, let idValue = id.base as? Int32 else {
                                return
                            }
                            
                            let giftCollection = GiftCollection(rawValue: idValue)
                            if case .create = giftCollection {
                                self.createCollection()
                            } else {
                                self.setCurrentCollection(collection: giftCollection)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: params.size.width - 10.0 * 2.0, height: 50.0)
                )
                if let tabSelectorView = self.tabSelector.view {
                    if tabSelectorView.superview == nil {
                        tabSelectorView.alpha = 1.0
                        self.scrollNode.view.insertSubview(tabSelectorView, at: 0)
                        
                        if !transition.animation.isImmediate {
                            tabSelectorView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                    transition.setFrame(view: tabSelectorView, frame: CGRect(origin: CGPoint(x: floor((params.size.width - tabSelectorSize.width) / 2.0), y: 60.0), size: tabSelectorSize))
                    
                    topInset += tabSelectorSize.height + 14.0
                }
            } else if let tabSelectorView = self.tabSelector.view {
                tabSelectorView.alpha = 0.0
                tabSelectorView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, completion: { _ in
                    tabSelectorView.removeFromSuperview()
                })
            }
            
            var contentHeight = self.giftsListView.updateScrolling(topInset: topInset, visibleBounds: visibleBounds, transition: transition)
            
            var bottomScrollInset: CGFloat = 0.0
            let size = params.size
            let sideInset = params.sideInset
            let bottomInset = params.bottomInset
            let presentationData = params.presentationData
          
            let themeUpdated = self.theme !== presentationData.theme
            self.theme = presentationData.theme
            
            let panelBackground: NavigationBackgroundNode
            let panelSeparator: ASDisplayNode
            
            var panelVisibility = params.expandProgress < 1.0 ? 0.0 : 1.0
            if !self.canGift || self.resultsAreEmpty {
                panelVisibility = 0.0
            }
            
            let panelTransition: ComponentTransition = .immediate
            if let current = self.panelBackground {
                panelBackground = current
            } else {
                panelBackground = NavigationBackgroundNode(color: presentationData.theme.rootController.tabBar.backgroundColor)
                self.addSubnode(panelBackground)
                self.panelBackground = panelBackground
            }
            
            if let current = self.panelSeparator {
                panelSeparator = current
            } else {
                panelSeparator = ASDisplayNode()
                panelBackground.addSubnode(panelSeparator)
                self.panelSeparator = panelSeparator
            }
                    
            let panelButton: ComponentView<Empty>
            if let current = self.panelButton {
                panelButton = current
            } else {
                panelButton = ComponentView<Empty>()
                self.panelButton = panelButton
            }
            
            let buttonSideInset = sideInset + 16.0
            
            let buttonTitle: String
            var buttonIconName: String?
            if self.peerId == self.context.account.peerId {
                if case .all = self.currentCollection {
                    buttonTitle = params.presentationData.strings.PeerInfo_Gifts_Send
                } else {
                    buttonTitle = params.presentationData.strings.PeerInfo_Gifts_AddGiftsButton
                    buttonIconName = "Item List/AddItemIcon"
                }
            } else {
                buttonTitle = params.presentationData.strings.PeerInfo_Gifts_SendGift
            }
            
            let buttonAttributedString = NSAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .center)
            var buttonTitleContent: AnyComponent<Empty> = AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
            if let buttonIconName {
                buttonTitleContent = AnyComponent(HStack([
                    AnyComponentWithIdentity(id: "_icon", component: AnyComponent(BundleIconComponent(
                        name: buttonIconName,
                        tintColor: presentationData.theme.list.itemCheckColors.foregroundColor,
                        maxSize: CGSize(width: 18.0, height: 18.0)
                    ))),
                    AnyComponentWithIdentity(id: "_title", component: buttonTitleContent)
                ], spacing: 7.0))
            }
            
            let panelButtonSize = panelButton.update(
                transition: transition,
                component: AnyComponent(
                    ButtonComponent(
                        background: ButtonComponent.Background(
                            color: presentationData.theme.list.itemCheckColors.fillColor,
                            foreground: presentationData.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: presentationData.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(buttonTitle),
                            component: buttonTitleContent
                        ),
                        isEnabled: true,
                        action: { [weak self] in
                            self?.buttonPressed()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: size.width - buttonSideInset * 2.0, height: 50.0)
            )
            
            var scrollOffset: CGFloat = max(0.0, size.height - params.visibleHeight)
            
            let effectiveBottomInset = max(8.0, bottomInset)
            var bottomPanelHeight = effectiveBottomInset + panelButtonSize.height + 8.0
            if params.visibleHeight < 110.0 {
                scrollOffset -= bottomPanelHeight
            }
            
            if let panelButtonView = panelButton.view {
                if panelButtonView.superview == nil {
                    panelBackground.view.addSubview(panelButtonView)
                }
                panelButtonView.frame = CGRect(origin: CGPoint(x: buttonSideInset, y: 8.0), size: panelButtonSize)
            }
            
            if themeUpdated {
                panelBackground.updateColor(color: presentationData.theme.rootController.tabBar.backgroundColor, transition: .immediate)
                panelSeparator.backgroundColor = presentationData.theme.rootController.tabBar.separatorColor
            }
            
            if self.canManage {
                bottomPanelHeight -= 9.0
                
                let panelCheck: ComponentView<Empty>
                if let current = self.panelCheck {
                    panelCheck = current
                } else {
                    panelCheck = ComponentView<Empty>()
                    self.panelCheck = panelCheck
                }
                let checkTheme = CheckComponent.Theme(
                    backgroundColor: presentationData.theme.list.itemCheckColors.fillColor,
                    strokeColor: presentationData.theme.list.itemCheckColors.foregroundColor,
                    borderColor: presentationData.theme.list.itemCheckColors.strokeColor,
                    overlayBorder: false,
                    hasInset: false,
                    hasShadow: false
                )
                
                let panelCheckSize = panelCheck.update(
                    transition: .immediate,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                                    theme: checkTheme,
                                    size: CGSize(width: 22.0, height: 22.0),
                                    selected: self.profileGifts.currentState?.notificationsEnabled ?? false
                                ))),
                                AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(string: presentationData.strings.PeerInfo_Gifts_ChannelNotify, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor))
                                )))
                            ],
                            spacing: 16.0
                            )),
                            effectAlignment: .center,
                            action: { [weak self] in
                                guard let self, let currentState = self.profileGifts.currentState else {
                                    return
                                }
                                let enabled = !(currentState.notificationsEnabled ?? false)
                                self.profileGifts.toggleStarGiftsNotifications(enabled: enabled)
                                
                                let animation = enabled ? "anim_profileunmute" : "anim_profilemute"
                                let text = enabled ? presentationData.strings.PeerInfo_Gifts_ChannelNotifyTooltip : presentationData.strings.PeerInfo_Gifts_ChannelNotifyDisabledTooltip
                                
                                let controller = UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .universal(animation: animation, scale: 0.075, colors: ["__allcolors__": UIColor.white], title: nil, text: text, customUndoText: nil, timeout: nil),
                                    appearance: UndoOverlayController.Appearance(bottomInset: 53.0),
                                    action: { _ in return true }
                                )
                                self.chatControllerInteraction.presentController(controller, nil)
                              
                                self.updateScrolling(transition: .immediate)
                            },
                            animateAlpha: false,
                            animateScale: false
                        )
                    ),
                    environment: {},
                    containerSize: panelButtonSize
                )
                if let panelCheckView = panelCheck.view {
                    if panelCheckView.superview == nil {
                        panelBackground.view.addSubview(panelCheckView)
                    }
                    panelCheckView.frame = CGRect(origin: CGPoint(x: floor((size.width - panelCheckSize.width) / 2.0), y: 16.0), size: panelCheckSize)
                }
                if let panelButtonView = panelButton.view {
                    panelButtonView.isHidden = true
                }
            }
            
            panelTransition.setFrame(view: panelBackground.view, frame: CGRect(x: 0.0, y: size.height - bottomPanelHeight - scrollOffset, width: size.width, height: bottomPanelHeight))
            ComponentTransition.spring(duration: 0.4).setSublayerTransform(view: panelBackground.view, transform: CATransform3DMakeTranslation(0.0, bottomPanelHeight * (1.0 - panelVisibility), 0.0))
            
            panelBackground.update(size: CGSize(width: size.width, height: bottomPanelHeight), transition: transition.containedViewLayoutTransition)
            panelTransition.setFrame(view: panelSeparator.view, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: UIScreenPixel))
            
            contentHeight += bottomPanelHeight
            bottomScrollInset = bottomPanelHeight - 40.0
            contentHeight += params.bottomInset
            
            self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: 50.0, left: 0.0, bottom: bottomScrollInset, right: 0.0)
            
            let contentSize = CGSize(width: params.size.width, height: contentHeight)
            if self.scrollNode.view.contentSize != contentSize {
                self.scrollNode.view.contentSize = contentSize
            }
        }
        
        let bottomContentOffset = max(0.0, self.scrollNode.view.contentSize.height - self.scrollNode.view.contentOffset.y - self.scrollNode.view.frame.height)
        if bottomContentOffset < 200.0 {
            self.giftsListView.loadMore()
        }
    }
        
    @objc private func buttonPressed() {
        if self.peerId == self.context.account.peerId || self.canManage {
            if case let .collection(id) = self.currentCollection {
                self.addGiftsToCollection(id: id)
            } else {
                let _ = (self.context.account.stateManager.contactBirthdays
                         |> take(1)
                         |> deliverOnMainQueue).start(next: { [weak self] birthdays in
                    guard let self else {
                        return
                    }
                    let controller = self.context.sharedContext.makePremiumGiftController(context: self.context, source: .settings(birthdays), completion: nil)
                    controller.navigationPresentation = .modal
                    self.chatControllerInteraction.navigationController()?.pushViewController(controller)
                })
            }
        } else {
            self.chatControllerInteraction.sendGift(self.peerId)
        }
    }
    
    private func contextAction(gift: ProfileGiftsContext.State.StarGift, view: UIView, gesture: ContextGesture) {
        guard let currentParams = self.currentParams else {
            return
        }
        let presentationData = currentParams.presentationData
        let strings = presentationData.strings
        
        let canManage = self.peerId == self.context.account.peerId || self.canManage
        var canReorder = false
        if case .all = self.currentCollection, let currentState = self.profileGifts.currentState {
            if case .All = currentState.filter {
                for gift in currentState.gifts {
                    if gift.pinnedToTop {
                        canReorder = true
                        break
                    }
                }
            }
        } else {
            canReorder = true
        }
        
        let profileGifts: ProfileGiftsContext
        switch self.currentCollection {
        case let .collection(id):
            profileGifts = self.profileGiftsCollections.giftsContextForCollection(id: id)
        default:
            profileGifts = self.profileGifts
        }
        
        var items: [ContextMenuItem] = []
        if canManage {
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Context_AddToCollection, textLayout: .twoLinesMax, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Peer Info/Gifts/AddToCollection"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                var subItems: [ContextMenuItem] = []
                
                subItems.append(.action(ContextMenuActionItem(text: strings.Common_Back, textColor: .primary, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
                }, iconSource: nil, iconPosition: .left, action: { c, _ in
                    c?.popItems()
                })))
                
                subItems.append(.separator)
                
                subItems.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Context_NewCollection, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Peer Info/Gifts/AddCollection"), color: theme.contextMenu.primaryColor) }, iconPosition: .left, action: { [weak self] c, f in
                    f(.default)
                    
                    self?.createCollection(gifts: [gift])
                })))
                
                var entityFiles: [Int64: TelegramMediaFile] = [:]
                
                if let collections = self?.collections {
                    for collection in collections {
                        if let file = collection.icon {
                            entityFiles[file.fileId.id] = file
                        }
                    }
                    
                    for collection in collections {
                        let title: String
                        var entities: [MessageTextEntity] = []
                        if let icon = collection.icon {
                            title = "#   \(collection.title)"
                            entities = [
                                MessageTextEntity(
                                    range: 0..<1,
                                    type: .CustomEmoji(stickerPack: nil, fileId: icon.fileId.id)
                                )
                            ]
                        } else {
                            title = collection.title
                        }
                        
                        let isAdded = gift.collectionIds?.contains(collection.id) ?? false
                        
                        subItems.append(.action(ContextMenuActionItem(text: title, entities: entities, entityFiles: entityFiles, enableEntityAnimations: false, icon: { theme in
                            return entities.isEmpty ? generateTintedImage(image: UIImage(bundleImageName: "Peer Info/Gifts/Collection"), color: theme.contextMenu.primaryColor) : (isAdded ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil)
                        }, iconPosition: collection.icon == nil ? .left : .right, action: { [weak self] _, f in
                            f(.default)
                            
                            guard let self else {
                                return
                            }
                            
                            if isAdded, let giftReference = gift.reference {
                                let _ = self.profileGiftsCollections.removeGifts(id: collection.id, gifts: [giftReference]).start()
                            } else {
                                let _ = self.profileGiftsCollections.addGifts(id: collection.id, gifts: [gift]).start()
                            }
                            
                            var giftFile: TelegramMediaFile?
                            var giftTitle: String?
                            switch gift.gift {
                            case let .generic(gift):
                                giftFile = gift.file
                            case let .unique(uniqueGift):
                                giftTitle = uniqueGift.title + " #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: currentParams.presentationData.dateTimeFormat))"
                                for attribute in uniqueGift.attributes {
                                    if case let .model(_, file, _) = attribute {
                                        giftFile = file
                                    }
                                }
                            }
                            
                            if let giftFile {
                                let text: String
                                if let giftTitle {
                                    if isAdded {
                                        text = currentParams.presentationData.strings.PeerInfo_Gifts_RemovedFromCollectionUnique(giftTitle, collection.title).string
                                    } else {
                                        text = currentParams.presentationData.strings.PeerInfo_Gifts_AddedToCollectionUnique(giftTitle, collection.title).string
                                    }
                                } else {
                                    if isAdded {
                                        text = currentParams.presentationData.strings.PeerInfo_Gifts_RemovedFromCollection(collection.title).string
                                    } else {
                                        text = currentParams.presentationData.strings.PeerInfo_Gifts_AddedToCollection(collection.title).string
                                    }
                                }
                                
                                let undoController = UndoOverlayController(
                                    presentationData: currentParams.presentationData,
                                    content: .sticker(context: self.context, file: giftFile, loop: false, title: nil, text: text, undoText: nil, customAction: nil),
                                    elevatedLayout: true,
                                    action: { _ in return true }
                                )
                                self.parentController?.present(undoController, in: .current)
                            }
                        })))
                    }
                }
                
                c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
            })))
            items.append(.separator)
        }
        
        if canManage {
            if case .unique = gift.gift, case .all = self.currentCollection {
                items.append(.action(ContextMenuActionItem(text: gift.pinnedToTop ? strings.PeerInfo_Gifts_Context_Unpin : strings.PeerInfo_Gifts_Context_Pin, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: gift.pinnedToTop ? "Chat/Context Menu/Unpin" : "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                    c?.dismiss(completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        let pinnedToTop = !gift.pinnedToTop
                        guard let reference = gift.reference else {
                            return
                        }
                        
                        if pinnedToTop && self.giftsListView.pinnedReferences.count >= self.giftsListView.maxPinnedCount {
                            self.displayUnpinScreen(gift: gift)
                            return
                        }
                        
                        profileGifts.updateStarGiftPinnedToTop(reference: reference, pinnedToTop: pinnedToTop)
                        
                        let toastTitle: String?
                        let toastText: String
                        if !pinnedToTop {
                            toastTitle = nil
                            toastText = strings.PeerInfo_Gifts_ToastUnpinned_Text
                        } else {
                            var title = ""
                            if case let .unique(uniqueGift) = gift.gift {
                                title = "\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: presentationData.dateTimeFormat))"
                            }
                            toastTitle = strings.PeerInfo_Gifts_ToastPinned_TitleNew(title).string
                            toastText = strings.PeerInfo_Gifts_ToastPinned_Text
                        }
                        self.parentController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: !pinnedToTop ? "anim_toastunpin" : "anim_toastpin", scale: 0.06, colors: [:], title: toastTitle, text: toastText, customUndoText: nil, timeout: 5), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    })
                })))
            }
            
            var isReorderableGift = false
            if case .unique = gift.gift {
                isReorderableGift = true
            } else if case .collection = self.currentCollection {
                isReorderableGift = true
            }
            
            if isReorderableGift && canManage && canReorder {
                items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Context_Reorder, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                    c?.dismiss(completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.beginReordering()
                    })
                })))
            }
            
            if case let .unique(uniqueGift) = gift.gift, self.peerId == self.context.account.peerId {
                items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Context_Wear, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Peer Info/WearIcon"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                    c?.dismiss(completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        if self.context.isPremium {
                            let _ = self.context.engine.accountData.setStarGiftStatus(starGift: uniqueGift, expirationDate: nil).startStandalone()
                        } else {
                            let text = strings.Gift_View_TooltipPremiumWearing
                            let tooltipController = UndoOverlayController(
                                presentationData: presentationData,
                                content: .premiumPaywall(title: nil, text: text, customUndoText: nil, timeout: nil, linkAction: nil),
                                position: .bottom,
                                animateInAsReplacement: false,
                                appearance: UndoOverlayController.Appearance(sideInset: 16.0, bottomInset: 62.0),
                                action: { [weak self] action in
                                    if let self, case .info = action {
                                        let premiumController = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .messageEffects, forceDark: false, dismissed: nil)
                                        self.parentController?.push(premiumController)
                                    }
                                    return false
                                }
                            )
                            self.parentController?.present(tooltipController, in: .current)
                        }
                    })
                })))
            }
        }
        
        if case let .unique(gift) = gift.gift {
            let link = "https://t.me/nft/\(gift.slug)"
            
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Context_CopyLink, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                c?.dismiss(completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    UIPasteboard.general.string = link
                    
                    self.parentController?.present(UndoOverlayController(presentationData: currentParams.presentationData, content: .linkCopied(title: nil, text: currentParams.presentationData.strings.Conversation_LinkCopied), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                })
            })))
            
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Context_Share, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                c?.dismiss(completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    let context = self.context
                    let shareController = context.sharedContext.makeShareController(
                        context: context,
                        subject: .url(link),
                        forceExternal: false,
                        shareStory: { [weak self] in
                            guard let self, let parentController = self.parentController else {
                                return
                            }
                            Queue.mainQueue().after(0.15) {
                                let controller = self.context.sharedContext.makeStorySharingScreen(context: self.context, subject: .gift(gift), parentController: parentController)
                                parentController.push(controller)
                            }
                        },
                        enqueued: { [weak self] peerIds, _ in
                            let _ = (context.engine.data.get(
                                EngineDataList(
                                    peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                                )
                            )
                            |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                                guard let self, let parentController = self.parentController else {
                                    return
                                }
                                
                                let peers = peerList.compactMap { $0 }
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                let text: String
                                var savedMessages = false
                                if peerIds.count == 1, let peerId = peerIds.first, peerId == context.account.peerId {
                                    text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
                                    savedMessages = true
                                } else {
                                    if peers.count == 1, let peer = peers.first {
                                        var peerName = peer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        peerName = peerName.replacingOccurrences(of: "**", with: "")
                                        text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string
                                    } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                        var firstPeerName = firstPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                                        var secondPeerName = secondPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                                        text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                                    } else if let peer = peers.first {
                                        var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                        peerName = peerName.replacingOccurrences(of: "**", with: "")
                                        text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                                    } else {
                                        text = ""
                                    }
                                }
                                
                                parentController.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: true, animateInAsReplacement: false, action: { [weak self] action in
                                    if savedMessages, action == .info {
                                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                                            guard let peer, let navigationController = self?.parentController?.navigationController as? NavigationController else {
                                                return
                                            }
                                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), subject: nil, botStart: nil, updateTextInputState: nil, keepStack: .always, useExisting: true, purposefulAction: nil, scrollToEndIfExists: false, activateMessageSearch: nil, animated: true))
                                        })
                                    }
                                    return false
                                }, additionalView: nil), in: .current)
                            })
                        },
                        actionCompleted: { [weak self] in
                            self?.parentController?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                        }
                    )
                    self.parentController?.present(shareController, in: .window(.root))
                })
            })))
        }
        
        if canManage {
            items.append(.action(ContextMenuActionItem(text: gift.savedToProfile ? strings.PeerInfo_Gifts_Context_Hide : strings.PeerInfo_Gifts_Context_Show, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: gift.savedToProfile ? "Peer Info/HideIcon" : "Peer Info/ShowIcon"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                c?.dismiss(completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    if let reference = gift.reference {
                        let added = !gift.savedToProfile
                        profileGifts.updateStarGiftAddedToProfile(reference: reference, added: added)
                        
                        var animationFile: TelegramMediaFile?
                        switch gift.gift {
                        case let .generic(gift):
                            animationFile = gift.file
                        case let .unique(gift):
                            for attribute in gift.attributes {
                                if case let .model(_, file, _) = attribute {
                                    animationFile = file
                                    break
                                }
                            }
                        }
                                                
                        let text: String
                        if self.peerId.namespace == Namespaces.Peer.CloudChannel {
                            text = added ? presentationData.strings.Gift_Displayed_ChannelText : presentationData.strings.Gift_Hidden_ChannelText
                        } else {
                            text = added ? presentationData.strings.Gift_Displayed_NewText : presentationData.strings.Gift_Hidden_NewText
                        }
                        
                        if let animationFile {
                            let resultController = UndoOverlayController(
                                presentationData: presentationData,
                                content: .sticker(context: context, file: animationFile, loop: false, title: nil, text: text, undoText: nil, customAction: nil),
                                elevatedLayout: true,
                                action: { _ in
                                    return true
                                }
                            )
                            self.parentController?.present(resultController, in: .window(.root))
                        }
                    }
                })
            })))
            
            if case let .unique(uniqueGift) = gift.gift {
                items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Context_Transfer, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Peer Info/TransferIcon"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                    c?.dismiss(completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        let context = self.context
                        
                        guard uniqueGift.hostPeerId == nil else {
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let alertController = textAlertController(
                                context: context,
                                title: presentationData.strings.Gift_UnavailableAction_Title,
                                text: presentationData.strings.Gift_UnavailableAction_Text,
                                actions: [
                                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_UnavailableAction_OpenFragment, action: {
                                        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://fragment.com/gift/\(uniqueGift.slug)", forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                                    }),
                                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
                                ],
                                actionLayout: .vertical
                            )
                            self.parentController?.present(alertController, in: .window(.root))
                            return
                        }
                        
                        let _ = (context.account.stateManager.contactBirthdays
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] birthdays in
                            guard let self, let reference = gift.reference else {
                                return
                            }
                            var showSelf = false
                            if self.peerId.namespace == Namespaces.Peer.CloudChannel {
                                showSelf = true
                            }
                            let transferStars = gift.transferStars ?? 0
                            let controller = context.sharedContext.makePremiumGiftController(context: context, source: .starGiftTransfer(birthdays, reference, uniqueGift, transferStars, gift.canExportDate, showSelf), completion: { peerIds in
                                guard let peerId = peerIds.first else {
                                    return .complete()
                                }
                                Queue.mainQueue().after(1.5, {
                                    if transferStars > 0 {
                                        context.starsContext?.load(force: true)
                                    }
                                })
                                return profileGifts.transferStarGift(prepaid: transferStars == 0, reference: reference, peerId: peerId)
                            })
                            self.parentController?.push(controller)
                        })
                    })
                })))
            }
        }
        
        if canManage, case let .collection(id) = self.currentCollection {
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Context_RemoveFromCollection, textColor: .destructive, textLayout: .twoLinesMax, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Peer Info/Gifts/RemoveFromCollection"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, f in
                f(.default)
                
                guard let self else {
                    return
                }
                
                if let reference = gift.reference {
                    let _ = self.profileGiftsCollections.removeGifts(id: id, gifts: [reference]).start()
                }
                
                var giftFile: TelegramMediaFile?
                var giftTitle: String?
                switch gift.gift {
                case let .generic(gift):
                    giftFile = gift.file
                case let .unique(uniqueGift):
                    giftTitle = uniqueGift.title + " #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: currentParams.presentationData.dateTimeFormat))"
                    for attribute in uniqueGift.attributes {
                        if case let .model(_, file, _) = attribute {
                            giftFile = file
                        }
                    }
                }
                
                if let giftFile, let collection = self.collections?.first(where: { $0.id == id }) {
                    let text: String
                    if let giftTitle {
                        text = currentParams.presentationData.strings.PeerInfo_Gifts_RemovedFromCollectionUnique(giftTitle, collection.title).string
                    } else {
                        text = currentParams.presentationData.strings.PeerInfo_Gifts_RemovedFromCollection(collection.title).string
                    }
                    
                    let undoController = UndoOverlayController(
                        presentationData: currentParams.presentationData,
                        content: .sticker(context: self.context, file: giftFile, loop: false, title: nil, text: text, undoText: nil, customAction: nil),
                        elevatedLayout: true,
                        action: { _ in return true }
                    )
                    self.parentController?.present(undoController, in: .current)
                }
            })))
        }
        
        guard !items.isEmpty else {
            return
        }
        
        let previewController = GiftContextPreviewController(context: self.context, gift: gift)
        let contextController = ContextController(
            context: self.context,
            presentationData: currentParams.presentationData,
            source: .controller(ContextControllerContentSourceImpl(controller: previewController, sourceView: view)),
            items: .single(ContextController.Items(content: .list(items))), gesture: gesture
        )
        self.parentController?.presentInGlobalOverlay(contextController)
    }
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, topInset, sideInset, bottomInset, deviceMetrics, visibleHeight, isScrollingLockedAtTop, expandProgress, navigationHeight, presentationData)
        self.presentationDataPromise.set(.single(presentationData))
        
        self.backgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -10.0)
        
        let contentHeight = self.giftsListView.update(size: size, sideInset: sideInset, bottomInset: bottomInset, deviceMetrics: deviceMetrics, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: synchronous, visibleBounds: visibleBounds, transition: transition)
        transition.updateFrame(view: self.giftsListView, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: max(size.height, contentHeight))))
        
        if isScrollingLockedAtTop {
            self.scrollNode.view.contentOffset = .zero
        }
        self.scrollNode.view.isScrollEnabled = !isScrollingLockedAtTop
        
        self.updateScrolling(transition: ComponentTransition(transition))
    }
    
    public func findLoadedMessage(id: MessageId) -> Message? {
        return nil
    }
    
    public func updateHiddenMedia() {
    }
    
    public func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
//            self.scrollNode.transferVelocity(velocity)
        }
    }
    
    public func cancelPreviewGestures() {
    }
    
    public func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    public func addToTransitionSurface(view: UIView) {
    }
    
    public func updateSelectedMessages(animated: Bool) {
    }
}

private func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceView: UIView?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = false
    
    init(controller: ViewController, sourceView: UIView?) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceView = self.sourceView
        
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceView] in
            if let sourceView {
                return (sourceView, sourceView.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
        self.controller.didAppearInContextPreview()
    }
}

private final class GiftsExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(sourceNode: ContextExtractedContentContainingNode) {
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

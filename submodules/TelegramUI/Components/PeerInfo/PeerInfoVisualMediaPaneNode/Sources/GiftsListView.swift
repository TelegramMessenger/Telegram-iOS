import AsyncDisplayKit
import UIKit
import Display
import ComponentFlow
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListPeerItem
import ItemListPeerActionItem
import MergeLists
import ItemListUI
import MultilineTextComponent
import BalancedTextComponent
import Markdown
import PeerInfoPaneNode
import GiftItemComponent
import PlainButtonComponent
import GiftViewScreen
import SolidRoundedButtonNode
import UndoUI
import LottieComponent
import ButtonComponent
import ContextUI

final class GiftsListView: UIView {
    private let context: AccountContext
    private let peerId: PeerId
    let profileGifts: ProfileGiftsContext
    private let giftsCollections: ProfileGiftsCollectionsContext?
    
    private let canSelect: Bool
    private let ignoreCollection: Int32?
    private let remainingSelectionCount: Int32
    
    private var dataDisposable: Disposable?
        
    weak var parentController: ViewController?
        
    private var footerText: ComponentView<Empty>?
    
    private let emptyResultsClippingView = UIView()
    private let emptyResultsAnimation = ComponentView<Empty>()
    private let emptyResultsTitle = ComponentView<Empty>()
    private let emptyResultsText = ComponentView<Empty>()
    private let emptyResultsAction = ComponentView<Empty>()
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData)?
    private var visibleBounds: CGRect?
    private var topInset: CGFloat?
    
    private var theme: PresentationTheme?
    private let presentationDataPromise = Promise<PresentationData>()
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    var status: Signal<PeerInfoStatusData?, NoError> {
        self.statusPromise.get()
    }
            
    private var starsProducts: [ProfileGiftsContext.State.StarGift]?
    private var starsItems: [AnyHashable: (StarGiftReference?, ComponentView<Empty>)] = [:]

    private(set) var resultsAreEmpty = false
    private var filteredResultsAreEmpty = false
    
    var onContentUpdated: () -> Void = { }
    
    private(set) var selectedItemIds = Set<AnyHashable>()
    private var selectedItemsMap: [AnyHashable: ProfileGiftsContext.State.StarGift] = [:]
    var selectionUpdated: () -> Void = { }
    
    var displayUnpinScreen: ((ProfileGiftsContext.State.StarGift, (() -> Void)?) -> Void)?
    
    var selectedItems: [ProfileGiftsContext.State.StarGift] {
        var gifts: [ProfileGiftsContext.State.StarGift] = []
        var existingIds = Set<AnyHashable>()
        if let currentGifts = self.profileGifts.currentState?.gifts {
            for gift in currentGifts {
                if let itemId = gift.reference?.stringValue {
                    if self.selectedItemIds.contains(itemId) {
                        gifts.append(gift)
                        existingIds.insert(itemId)
                    }
                }
            }
        }
        for itemId in self.selectedItemIds {
            if !existingIds.contains(itemId), let item = self.selectedItemsMap[itemId] {
                gifts.append(item)
            }
        }
        return gifts
    }
    
    private(set) var pinnedReferences: [StarGiftReference] = []
    private var isReordering: Bool = false
    private var reorderingItem: (id: AnyHashable, initialPosition: CGPoint, position: CGPoint)?
    private var reorderedReferences: [StarGiftReference]? {
        didSet {
            self.reorderedReferencesPromise.set(self.reorderedReferences)
        }
    }
    private var reorderedReferencesPromise = ValuePromise<[StarGiftReference]?>(nil)
    
    private var reorderedPinnedReferences: Set<StarGiftReference>? {
        didSet {
            self.reorderedPinnedReferencesPromise.set(self.reorderedPinnedReferences)
        }
    }
    private var reorderedPinnedReferencesPromise = ValuePromise<Set<StarGiftReference>?>(nil)
    
    private var reorderRecognizer: ReorderGestureRecognizer?
    
    let maxPinnedCount: Int
    
    var contextAction: ((ProfileGiftsContext.State.StarGift, UIView, ContextGesture) -> Void)?
    var addToCollection: (() -> Void)?
    
    init(context: AccountContext, peerId: PeerId, profileGifts: ProfileGiftsContext, giftsCollections: ProfileGiftsCollectionsContext?, canSelect: Bool, ignoreCollection: Int32? = nil, remainingSelectionCount: Int32 = 0) {
        self.context = context
        self.peerId = peerId
        self.profileGifts = profileGifts
        self.giftsCollections = giftsCollections
        self.canSelect = canSelect
        self.ignoreCollection = ignoreCollection
        self.remainingSelectionCount = remainingSelectionCount
                
        if let value = context.currentAppConfiguration.with({ $0 }).data?["stargifts_pinned_to_top_limit"] as? Double {
            self.maxPinnedCount = Int(value)
        } else {
            self.maxPinnedCount = 6
        }
        
        super.init(frame: .zero)
                                        
        self.dataDisposable = combineLatest(
            queue: Queue.mainQueue(),
            profileGifts.state,
            self.reorderedReferencesPromise.get()
        ).startStrict(next: { [weak self] state, reorderedReferences in
            guard let self else {
                return
            }
            let isFirstTime = self.starsProducts == nil
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.statusPromise.set(.single(PeerInfoStatusData(text: presentationData.strings.SharedMedia_GiftCount(state.count ?? 0), isActivity: true, key: .gifts)))
            
            if self.isReordering {
                var stateItems: [ProfileGiftsContext.State.StarGift] = state.gifts
                if let reorderedReferences {
                    var fixedStateItems: [ProfileGiftsContext.State.StarGift] = []
                    
                    var seenIds = Set<StarGiftReference>()
                    for reference in reorderedReferences {
                        if let index = stateItems.firstIndex(where: { $0.reference == reference }) {
                            seenIds.insert(reference)
                            var item = stateItems[index]
                            if self.reorderedPinnedReferences?.contains(reference) == true, !item.pinnedToTop {
                                item = item.withPinnedToTop(true)
                            }
                            fixedStateItems.append(item)
                        }
                    }
                    
                    for item in stateItems {
                        if let reference = item.reference, !seenIds.contains(reference) {
                            var item = item
                            if self.reorderedPinnedReferences?.contains(reference) == true, !item.pinnedToTop {
                                item = item.withPinnedToTop(true)
                            }
                            fixedStateItems.append(item)
                        }
                    }
                    stateItems = fixedStateItems
                }
                self.starsProducts = stateItems
                self.pinnedReferences = Array(stateItems.filter { $0.pinnedToTop }.compactMap { $0.reference })
            } else {
                self.starsProducts = state.filteredGifts
                self.pinnedReferences = Array(state.gifts.filter { $0.pinnedToTop }.compactMap { $0.reference })
            }
            
            self.resultsAreEmpty = state.filter == .All && state.gifts.isEmpty && state.dataState != .loading
            self.filteredResultsAreEmpty = state.filter != .All && state.filteredGifts.isEmpty
        
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(.single(true))
            }
            
            let _ = self.updateScrolling(transition: isFirstTime ? .immediate : .easeInOut(duration: 0.25))
            
            Queue.mainQueue().justDispatch {
                self.onContentUpdated()
            }
        })
        
        self.emptyResultsClippingView.clipsToBounds = true
        self.emptyResultsClippingView.isHidden = true
        self.addSubview(self.emptyResultsClippingView)
        
        let reorderRecognizer = ReorderGestureRecognizer(
            shouldBegin: { [weak self] point in
                guard let self, let (id, item) = self.item(at: point) else {
                    return (allowed: false, requiresLongPress: false, id: nil, item: nil)
                }
                return (allowed: true, requiresLongPress: false, id: id, item: item)
            },
            willBegin: { point in
            },
            began: { [weak self] item in
                guard let self else {
                    return
                }
                self.setReorderingItem(item: item)
            },
            ended: { [weak self] in
                guard let self else {
                    return
                }
                self.setReorderingItem(item: nil)
            },
            moved: { [weak self] distance in
                guard let self else {
                    return
                }
                self.moveReorderingItem(distance: distance)
            },
            isActiveUpdated: { _ in
            }
        )
        self.reorderRecognizer = reorderRecognizer
        self.addGestureRecognizer(reorderRecognizer)
        reorderRecognizer.isEnabled = false
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    deinit {
        self.dataDisposable?.dispose()
    }
        
    func item(at point: CGPoint) -> (AnyHashable, ComponentView<Empty>)? {
        for (id, visibleItem) in self.starsItems {
            if let view = visibleItem.1.view, view.frame.contains(point), let reference = visibleItem.0, self.isCollection || self.pinnedReferences.contains(reference) {
                return (id, visibleItem.1)
            }
        }
        return nil
    }
        
    func beginReordering() {
        self.profileGifts.updateFilter(.All)
        self.profileGifts.updateSorting(.date)
        
        if let parentController = self.parentController as? PeerInfoScreen {
            parentController.togglePaneIsReordering(isReordering: true)
        } else {
            self.updateIsReordering(isReordering: true, animated: true)
        }
    }
    
    func endReordering() {
        if let parentController = self.parentController as? PeerInfoScreen {
            parentController.togglePaneIsReordering(isReordering: false)
        } else {
            self.updateIsReordering(isReordering: false, animated: true)
        }
    }
    
    func updateIsReordering(isReordering: Bool, animated: Bool) {
        if self.isReordering != isReordering {
            self.isReordering = isReordering
            
            self.reorderRecognizer?.isEnabled = isReordering
            
            if !isReordering, let _ = self.reorderedReferences, let starsProducts = self.starsProducts {
                if let collectionId = self.profileGifts.collectionId {
                    var orderedReferences: [StarGiftReference] = []
                    for gift in starsProducts {
                        if let reference = gift.reference {
                            orderedReferences.append(reference)
                        }
                    }
                    let _ = self.giftsCollections?.reorderGifts(id: collectionId, gifts: orderedReferences).start()
                } else {
                    var pinnedReferences: [StarGiftReference] = []
                    for gift in starsProducts.prefix(self.maxPinnedCount) {
                        if gift.pinnedToTop, let reference = gift.reference {
                            pinnedReferences.append(reference)
                        }
                    }
                    self.profileGifts.updatePinnedToTopStarGifts(references: pinnedReferences)
                }
                
                Queue.mainQueue().after(1.0) {
                    self.reorderedReferences = nil
                    self.reorderedPinnedReferences = nil
                }
            }
            
            self.updateScrolling(transition: animated ? .spring(duration: 0.4) : .immediate)
        }
    }
    
    func setReorderingItem(item: AnyHashable?) {
        var mappedItem: (AnyHashable, ComponentView<Empty>)?
        for (id, visibleItem) in self.starsItems {
            if id == item {
                mappedItem = (id, visibleItem.1)
                break
            }
        }
        
        if self.reorderingItem?.id != mappedItem?.0 {
            if let (id, visibleItem) = mappedItem, let view = visibleItem.view {
                self.addSubview(view)
                self.reorderingItem = (id, view.center, view.center)
            } else {
                self.reorderingItem = nil
            }
            self.updateScrolling(transition: item == nil ? .spring(duration: 0.3) : .immediate)
        }
    }
    
    func moveReorderingItem(distance: CGPoint) {
        if let (id, initialPosition, _) = self.reorderingItem {
            let targetPosition = CGPoint(x: initialPosition.x + distance.x, y: initialPosition.y + distance.y)
            self.reorderingItem = (id, initialPosition, targetPosition)
            self.updateScrolling(transition: .immediate)
            
            if let starsProducts = self.starsProducts, let visibleReorderingItem = self.starsItems[id] {
                for (_, visibleItem) in self.starsItems {
                    if visibleItem.1 === visibleReorderingItem.1 {
                        continue
                    }
                    if let view = visibleItem.1.view, view.frame.contains(targetPosition), let reorderItemReference = self.starsItems[id]?.0 {
                        if let targetIndex = starsProducts.firstIndex(where: { $0.reference == visibleItem.0 }) {
                            self.reorderIfPossible(reference: reorderItemReference, toIndex: targetIndex)
                        }
                        break
                    }
                }
            }
        }
    }
    
    private var isCollection: Bool {
        return self.profileGifts.collectionId != nil
    }
    
    private func reorderIfPossible(reference: StarGiftReference, toIndex: Int) {
        if let items = self.starsProducts {
            var toIndex = toIndex
            
            let maxPinnedIndex: Int?
            if self.isCollection {
                maxPinnedIndex = items.count - 1
            } else {
                maxPinnedIndex = items.lastIndex(where: { $0.pinnedToTop })
            }
            if let maxPinnedIndex {
                toIndex = min(toIndex, maxPinnedIndex)
            } else {
                return
            }
            
            var ids = items.compactMap { item -> StarGiftReference? in
                return item.reference
            }
            
            if let fromIndex = ids.firstIndex(of: reference) {
                if fromIndex < toIndex {
                    ids.insert(reference, at: toIndex + 1)
                    ids.remove(at: fromIndex)
                } else if fromIndex > toIndex {
                    ids.remove(at: fromIndex)
                    ids.insert(reference, at: toIndex)
                }
            }
            if self.reorderedReferences != ids {
                self.reorderedReferences = ids
                
                HapticFeedback().tap()
            }
        }
    }
                    
    func loadMore() {
        self.profileGifts.loadMore()
    }
    
    @discardableResult
    private func updateScrolling(interactive: Bool = false, transition: ComponentTransition) -> CGFloat {
        guard let topInset = self.topInset, let visibleBounds = self.visibleBounds else {
            return 0.0
        }
        return self.updateScrolling(interactive: interactive, topInset: topInset, visibleBounds: visibleBounds, transition: transition)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let topInset = self.topInset, point.y < topInset {
            return false
        }
        return super.point(inside: point, with: event)
    }
        
    func updateScrolling(interactive: Bool = false, topInset: CGFloat, visibleBounds: CGRect, transition: ComponentTransition) -> CGFloat {
        self.topInset = topInset
        self.visibleBounds = visibleBounds
        
        guard let starsProducts = self.starsProducts, let params = self.currentParams else {
            return 0.0
        }
        
        let optionSpacing: CGFloat = 10.0
        let itemsSideInset = params.sideInset + 16.0
        
        let defaultItemsInRow: Int
        if params.size.width > params.size.height || params.size.width > 480.0 {
            if case .tablet = params.deviceMetrics.type {
                defaultItemsInRow = 4
            } else {
                defaultItemsInRow = 5
            }
        } else {
            defaultItemsInRow = 3
        }
        let itemsInRow = max(1, min(starsProducts.count, defaultItemsInRow))
        let defaultOptionWidth = (params.size.width - itemsSideInset * 2.0 - optionSpacing * CGFloat(defaultItemsInRow - 1)) / CGFloat(defaultItemsInRow)
        let optionWidth = (params.size.width - itemsSideInset * 2.0 - optionSpacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow)
        
        let starsOptionSize = CGSize(width: optionWidth, height: defaultOptionWidth)
                    
        var validIds: [AnyHashable] = []
        var itemFrame = CGRect(origin: CGPoint(x: itemsSideInset, y: topInset), size: starsOptionSize)
        
        var index: Int32 = 0
        for product in starsProducts {
            var isVisible = false
            if visibleBounds.intersects(itemFrame) {
                isVisible = true
            }
            
            if isVisible {
                let info: String
                switch product.gift {
                case let .generic(gift):
                    info = "g_\(gift.id)"
                case let .unique(gift):
                    info = "u_\(gift.id)"
                }
                let stableId = product.reference?.stringValue ?? "\(index)"
                let id = "\(stableId)_\(info)"
                let itemId = AnyHashable(id)
                validIds.append(itemId)
                
                var itemTransition = transition
                let visibleItem: ComponentView<Empty>
                if let (_, current) = self.starsItems[itemId] {
                    visibleItem = current
                } else {
                    visibleItem = ComponentView()
                    self.starsItems[itemId] = (product.reference, visibleItem)
                    itemTransition = .immediate
                }
                
                var ribbonText: String?
                var ribbonColor: GiftItemComponent.Ribbon.Color = .blue
                var ribbonFont: GiftItemComponent.Ribbon.Font = .generic
                var ribbonOutline: UIColor?
                
                let peer: GiftItemComponent.Peer?
                let subject: GiftItemComponent.Subject
                var resellAmount: CurrencyAmount?
                
                switch product.gift {
                case let .generic(gift):
                    subject = .starGift(gift: gift, price: "# \(gift.price)")
                    peer = product.fromPeer.flatMap { .peer($0) } ?? .anonymous
                    
                    if let availability = gift.availability {
                        ribbonText = params.presentationData.strings.PeerInfo_Gifts_OneOf(compactNumericCountString(Int(availability.total), decimalSeparator: params.presentationData.dateTimeFormat.decimalSeparator)).string
                    } else {
                        ribbonText = nil
                    }
                case let .unique(gift):
                    subject = .uniqueGift(gift: gift, price: nil)
                    peer = nil
                    resellAmount = gift.resellAmounts?.first(where: { $0.currency == .stars })
                    
                    if !(gift.resellAmounts ?? []).isEmpty {
                        ribbonText = params.presentationData.strings.PeerInfo_Gifts_Sale
                        ribbonFont = .larger
                        ribbonColor = .green
                        ribbonOutline =  params.presentationData.theme.list.blocksBackgroundColor
                    } else {
                        if product.pinnedToTop || self.canSelect || self.isCollection {
                            ribbonFont = .monospaced
                            ribbonText = "#\(gift.number)"
                        } else {
                            ribbonText = params.presentationData.strings.PeerInfo_Gifts_OneOf(compactNumericCountString(Int(gift.availability.issued), decimalSeparator: params.presentationData.dateTimeFormat.decimalSeparator)).string
                        }
                        for attribute in gift.attributes {
                            if case let .backdrop(_, _, innerColor, outerColor, _, _, _) = attribute {
                                ribbonColor = .custom(outerColor, innerColor)
                                break
                            }
                        }
                    }
                }
                
                let itemReferenceId = product.reference?.stringValue ?? ""
                
                var isAdded = false
                if let ignoreCollection = self.ignoreCollection, let collectionIds = product.collectionIds, collectionIds.contains(ignoreCollection) {
                    isAdded = true
                }
                
                var itemAlpha: CGFloat = 1.0
                if isAdded {
                    itemAlpha = 0.3
                }
                
                let _ = visibleItem.update(
                    transition: itemTransition,
                    component: AnyComponent(
                        GiftItemComponent(
                            context: self.context,
                            theme: params.presentationData.theme,
                            strings: params.presentationData.strings,
                            peer: peer,
                            subject: subject,
                            ribbon: ribbonText.flatMap { GiftItemComponent.Ribbon(text: $0, font: ribbonFont, color: ribbonColor, outline: ribbonOutline) },
                            resellPrice: resellAmount?.amount.value,
                            isHidden: !product.savedToProfile,
                            isSelected: self.selectedItemIds.contains(itemReferenceId),
                            isPinned: !self.canSelect && product.pinnedToTop,
                            isEditing: self.isReordering && !self.isCollection,
                            mode: self.canSelect && !isAdded ? .select : .profile,
                            action: { [weak self] in
                                guard let self, !isAdded, let presentationData = self.currentParams?.presentationData else {
                                    return
                                }
                                if self.canSelect {
                                    if self.selectedItemIds.contains(itemReferenceId) {
                                        self.selectedItemIds.remove(itemReferenceId)
                                    } else {
                                        if self.selectedItemIds.count < self.remainingSelectionCount {
                                            self.selectedItemIds.insert(itemReferenceId)
                                            self.selectedItemsMap[itemReferenceId] = product
                                        }
                                    }
                                    self.selectionUpdated()
                                    self.updateScrolling(transition: .easeInOut(duration: 0.25))
                                } else if self.isReordering {
                                    if case .unique = product.gift, !product.pinnedToTop, let reference = product.reference, let items = self.starsProducts {
                                        if self.pinnedReferences.count >= self.maxPinnedCount {
                                            self.parentController?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.PeerInfo_Gifts_ToastPinLimit_Text(Int32(self.maxPinnedCount)), timeout: nil, customUndoText: nil), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                            return
                                        }
                                        
                                        var reorderedPinnedReferences = Set<StarGiftReference>()
                                        if let current = self.reorderedPinnedReferences {
                                            reorderedPinnedReferences = current
                                        }
                                        reorderedPinnedReferences.insert(reference)
                                        self.reorderedPinnedReferences = reorderedPinnedReferences
                                                                                    
                                        if let maxPinnedIndex = items.lastIndex(where: { $0.pinnedToTop }) {
                                            var reorderedReferences: [StarGiftReference]
                                            if let current = self.reorderedReferences {
                                                reorderedReferences = current
                                            } else {
                                                let ids = items.compactMap { item -> StarGiftReference? in
                                                    return item.reference
                                                }
                                                reorderedReferences = ids
                                            }
                                            reorderedReferences.removeAll(where: { $0 == reference })
                                            reorderedReferences.insert(reference, at: maxPinnedIndex + 1)
                                            self.reorderedReferences = reorderedReferences
                                        }
                                    }
                                } else {
                                    let allSubjects: [GiftViewScreen.Subject] = (self.starsProducts ?? []).map { .profileGift(self.peerId, $0) }
                                    let index = self.starsProducts?.firstIndex(where: { $0 == product }) ?? 0
                                    
                                    var dismissImpl: (() -> Void)?
                                    let controller = GiftViewScreen(
                                        context: self.context,
                                        subject: .profileGift(self.peerId, product),
                                        allSubjects: allSubjects,
                                        index: index,
                                        updateSavedToProfile: { [weak self] reference, added in
                                            guard let self else {
                                                return
                                            }
                                            self.profileGifts.updateStarGiftAddedToProfile(reference: reference, added: added)
                                        },
                                        convertToStars: { [weak self] reference in
                                            guard let self else {
                                                return
                                            }
                                            self.profileGifts.convertStarGift(reference: reference)
                                        },
                                        dropOriginalDetails: { [weak self] reference in
                                            guard let self else {
                                                return .complete()
                                            }
                                            return self.profileGifts.dropOriginalDetails(reference: reference)
                                        },
                                        transferGift: { [weak self] prepaid, reference, peerId in
                                            guard let self else {
                                                return .complete()
                                            }
                                            return self.profileGifts.transferStarGift(prepaid: prepaid, reference: reference, peerId: peerId)
                                        },
                                        upgradeGift: { [weak self] formId, reference, keepOriginalInfo in
                                            guard let self else {
                                                return .never()
                                            }
                                            return self.profileGifts.upgradeStarGift(formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo)
                                        },
                                        buyGift: { [weak self] slug, peerId, price in
                                            guard let self else {
                                                return .never()
                                            }
                                            return self.profileGifts.buyStarGift(slug: slug, peerId: peerId, price: price)
                                        },
                                        updateResellStars: { [weak self] reference, price in
                                            guard let self else {
                                                return .never()
                                            }
                                            return self.profileGifts.updateStarGiftResellPrice(reference: reference, price: price)
                                        },
                                        togglePinnedToTop: { [weak self] reference, pinnedToTop in
                                            guard let self else {
                                                return false
                                            }
                                            if pinnedToTop && self.pinnedReferences.count >= self.maxPinnedCount {
                                                self.displayUnpinScreen?(product, {
                                                    dismissImpl?()
                                                })
                                                return false
                                            }
                                            self.profileGifts.updateStarGiftPinnedToTop(reference: reference, pinnedToTop: pinnedToTop)
                                            
                                            var title = ""
                                            if case let .unique(uniqueGift) = product.gift {
                                                title = "\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: params.presentationData.dateTimeFormat))"
                                            }
                                            
                                            if pinnedToTop {
                                                Queue.mainQueue().after(0.35) {
                                                    let toastTitle = params.presentationData.strings.PeerInfo_Gifts_ToastPinned_TitleNew(title).string
                                                    let toastText = params.presentationData.strings.PeerInfo_Gifts_ToastPinned_Text
                                                    self.parentController?.present(UndoOverlayController(presentationData: params.presentationData, content: .universal(animation: "anim_toastpin", scale: 0.06, colors: [:], title: toastTitle, text: toastText, customUndoText: nil, timeout: 5), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                                }
                                            }
                                            return true
                                        },
                                        shareStory: { [weak self] uniqueGift in
                                            guard let self, let parentController = self.parentController else {
                                                return
                                            }
                                            Queue.mainQueue().after(0.15) {
                                                let controller = self.context.sharedContext.makeStorySharingScreen(context: self.context, subject: .gift(uniqueGift), parentController: parentController)
                                                parentController.push(controller)
                                            }
                                        }
                                    )
                                    dismissImpl = { [weak controller] in
                                        controller?.dismissAnimated()
                                    }
                                    self.parentController?.push(controller)
                                }
                            },
                            contextAction: self.isReordering || self.canSelect ? nil : { [weak self] view, gesture in
                                guard let self else {
                                    return
                                }
                                self.contextAction?(product, view, gesture)
                            }
                        )
                    ),
                    environment: {},
                    containerSize: starsOptionSize
                )
                if let itemView = visibleItem.view {
                    if itemView.superview == nil {
                        self.addSubview(itemView)
                        
                        if !transition.animation.isImmediate {
                            itemView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                            itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                    var itemFrame = itemFrame
                    var isReordering = false
                    if let reorderingItem = self.reorderingItem, itemId == reorderingItem.id {
                        itemFrame = itemFrame.size.centered(around: reorderingItem.position)
                        isReordering = true
                    }
                    if self.isReordering, itemView.layer.animation(forKey: "position") != nil && !isReordering {
                    } else {
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                    
                    itemTransition.setAlpha(view: itemView, alpha: itemAlpha)
                    if itemAlpha < 1.0 {
                        itemView.layer.allowsGroupOpacity = true
                    }
                    
                    if self.isReordering && (product.pinnedToTop || self.isCollection) {
                        if itemView.layer.animation(forKey: "shaking_position") == nil {
                            itemView.layer.addReorderingShaking()
                        }
                    } else {
                        if itemView.layer.animation(forKey: "shaking_position") != nil {
                            itemView.layer.removeAnimation(forKey: "shaking_position")
                            itemView.layer.removeAnimation(forKey: "shaking_rotation")
                        }
                    }
                }
            }
            itemFrame.origin.x += itemFrame.width + optionSpacing
            if itemFrame.maxX > params.size.width {
                itemFrame.origin.x = itemsSideInset
                itemFrame.origin.y += starsOptionSize.height + optionSpacing
            }
            index += 1
        }
        
        var removeIds: [AnyHashable] = []
        for (id, item) in self.starsItems {
            if !validIds.contains(id) {
                removeIds.append(id)
                if let itemView = item.1.view {
                    if !transition.animation.isImmediate {
                        itemView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                        itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                            itemView.removeFromSuperview()
                        })
                    } else {
                        itemView.removeFromSuperview()
                    }
                }
            }
        }
        for id in removeIds {
            self.starsItems.removeValue(forKey: id)
        }
        
        var contentHeight = ceil(CGFloat(starsProducts.count) / CGFloat(defaultItemsInRow)) * (starsOptionSize.height + optionSpacing) - optionSpacing + topInset + 16.0
        
        let size = params.size
        let sideInset = params.sideInset
        let bottomInset = params.bottomInset
        let presentationData = params.presentationData
      
        self.theme = presentationData.theme
        
        let textFont = Font.regular(13.0)
        let boldTextFont = Font.semibold(13.0)
        let textColor = presentationData.theme.list.itemSecondaryTextColor
        let linkColor = presentationData.theme.list.itemAccentColor
        let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: boldTextFont, textColor: linkColor), linkAttribute: { _ in
            return nil
        })
        
        let buttonSideInset = sideInset + 16.0
        let buttonSize = CGSize(width: size.width - buttonSideInset * 2.0, height: 50.0)
        let effectiveBottomInset = max(8.0, bottomInset)
        let bottomPanelHeight = effectiveBottomInset + buttonSize.height + 8.0
        let visibleHeight = params.visibleHeight
        
        let panelTransition = ComponentTransition.immediate
        let fadeTransition = ComponentTransition.easeInOut(duration: 0.25)
        if self.resultsAreEmpty && self.isCollection {
            let sideInset: CGFloat = 44.0
            let topInset: CGFloat = 52.0
            let emptyTextSpacing: CGFloat = 18.0
            
            self.emptyResultsClippingView.isHidden = false
            
            panelTransition.setFrame(view: self.emptyResultsClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: params.size))
            panelTransition.setBounds(view: self.emptyResultsClippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: params.size))
            
            let emptyResultsTitleSize = self.emptyResultsTitle.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: presentationData.strings.PeerInfo_Gifts_EmptyCollection_Title, font: Font.semibold(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor)),
                        horizontalAlignment: .center
                    )
                ),
                environment: {},
                containerSize: CGSize(width: params.size.width - sideInset * 2.0, height: params.size.height)
            )
            let emptyResultsTextSize = self.emptyResultsText.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: presentationData.strings.PeerInfo_Gifts_EmptyCollection_Text, font: Font.regular(15.0), textColor: presentationData.theme.list.itemSecondaryTextColor)),
                        horizontalAlignment: .center
                    )
                ),
                environment: {},
                containerSize: CGSize(width: params.size.width - sideInset * 2.0, height: params.size.height)
            )
            let buttonAttributedString = NSAttributedString(string: presentationData.strings.PeerInfo_Gifts_EmptyCollection_Action, font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .center)
            let emptyResultsActionSize = self.emptyResultsAction.update(
                transition: .immediate,
                component: AnyComponent(
                    ButtonComponent(
                        background: ButtonComponent.Background(
                            color: presentationData.theme.list.itemCheckColors.fillColor,
                            foreground: presentationData.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: presentationData.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(buttonAttributedString.string),
                            component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                        ),
                        isEnabled: true,
                        action: { [weak self] in
                            self?.addToCollection?()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 240.0, height: 50.0)
            )
  
            let emptyTotalHeight = emptyResultsTitleSize.height + emptyTextSpacing + emptyResultsTextSize.height + emptyTextSpacing + emptyResultsActionSize.height
            let emptyTitleY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
            
            let emptyResultsTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - emptyResultsTitleSize.width) / 2.0), y: emptyTitleY), size: emptyResultsTitleSize)
            let emptyResultsTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - emptyResultsTextSize.width) / 2.0), y: emptyResultsTitleFrame.maxY + emptyTextSpacing), size: emptyResultsTextSize)
            let emptyResultsActionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - emptyResultsActionSize.width) / 2.0), y: emptyResultsTextFrame.maxY + emptyTextSpacing), size: emptyResultsActionSize)
            
            if let view = self.emptyResultsTitle.view {
                if view.superview == nil {
                    view.alpha = 0.0
                    fadeTransition.setAlpha(view: view, alpha: 1.0)
                    self.emptyResultsClippingView.addSubview(view)
                }
                view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                panelTransition.setPosition(view: view, position: emptyResultsTitleFrame.center)
            }
            if let view = self.emptyResultsText.view {
                if view.superview == nil {
                    view.alpha = 0.0
                    fadeTransition.setAlpha(view: view, alpha: 1.0)
                    self.emptyResultsClippingView.addSubview(view)
                }
                view.bounds = CGRect(origin: .zero, size: emptyResultsTextFrame.size)
                panelTransition.setPosition(view: view, position: emptyResultsTextFrame.center)
            }
            if let view = self.emptyResultsAction.view {
                if view.superview == nil {
                    view.alpha = 0.0
                    fadeTransition.setAlpha(view: view, alpha: 1.0)
                    self.emptyResultsClippingView.addSubview(view)
                }
                view.bounds = CGRect(origin: .zero, size: emptyResultsActionFrame.size)
                panelTransition.setPosition(view: view, position: emptyResultsActionFrame.center)
            }
        } else if self.filteredResultsAreEmpty {
            let sideInset: CGFloat = 44.0
            let emptyAnimationHeight = 148.0
            let topInset: CGFloat = 0.0
            let bottomInset: CGFloat = bottomPanelHeight
            let emptyAnimationSpacing: CGFloat = 20.0
            let emptyTextSpacing: CGFloat = 18.0
            
            self.emptyResultsClippingView.isHidden = false
                            
            panelTransition.setFrame(view: self.emptyResultsClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: params.size))
            panelTransition.setBounds(view: self.emptyResultsClippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: params.size))
            
            let emptyResultsTitleSize = self.emptyResultsTitle.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: presentationData.strings.PeerInfo_Gifts_NoResults, font: Font.semibold(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor)),
                        horizontalAlignment: .center
                    )
                ),
                environment: {},
                containerSize: params.size
            )
            let emptyResultsActionSize = self.emptyResultsAction.update(
                transition: .immediate,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            MultilineTextComponent(
                                text: .plain(NSAttributedString(string: presentationData.strings.PeerInfo_Gifts_NoResults_ViewAll, font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor)),
                                horizontalAlignment: .center,
                                maximumNumberOfLines: 0
                            )
                        ),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.profileGifts.updateFilter(.All)
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: CGSize(width: params.size.width - sideInset * 2.0, height: visibleHeight)
            )
            let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                )),
                environment: {},
                containerSize: CGSize(width: emptyAnimationHeight, height: emptyAnimationHeight)
            )
  
            let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyResultsTitleSize.height + emptyResultsActionSize.height + emptyTextSpacing
            let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
            
            let emptyResultsAnimationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - emptyResultsAnimationSize.width) / 2.0), y: emptyAnimationY), size: emptyResultsAnimationSize)
            
            let emptyResultsTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - emptyResultsTitleSize.width) / 2.0), y: emptyResultsAnimationFrame.maxY + emptyAnimationSpacing), size: emptyResultsTitleSize)
            
            let emptyResultsActionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.size.width - emptyResultsActionSize.width) / 2.0), y: emptyResultsTitleFrame.maxY + emptyTextSpacing), size: emptyResultsActionSize)
            
            if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                if view.superview == nil {
                    view.alpha = 0.0
                    fadeTransition.setAlpha(view: view, alpha: 1.0)
                    self.emptyResultsClippingView.addSubview(view)
                    view.playOnce()
                }
                view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                panelTransition.setPosition(view: view, position: emptyResultsAnimationFrame.center)
            }
            if let view = self.emptyResultsTitle.view {
                if view.superview == nil {
                    view.alpha = 0.0
                    fadeTransition.setAlpha(view: view, alpha: 1.0)
                    self.emptyResultsClippingView.addSubview(view)
                }
                view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                panelTransition.setPosition(view: view, position: emptyResultsTitleFrame.center)
            }
            if let view = self.emptyResultsAction.view {
                if view.superview == nil {
                    view.alpha = 0.0
                    fadeTransition.setAlpha(view: view, alpha: 1.0)
                    self.emptyResultsClippingView.addSubview(view)
                }
                view.bounds = CGRect(origin: .zero, size: emptyResultsActionFrame.size)
                panelTransition.setPosition(view: view, position: emptyResultsActionFrame.center)
            }
        } else {
            if let view = self.emptyResultsAnimation.view {
                fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                    view.removeFromSuperview()
                })
            }
            if let view = self.emptyResultsTitle.view {
                fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                    self.emptyResultsClippingView.isHidden = true
                    view.removeFromSuperview()
                })
            }
            if let view = self.emptyResultsText.view {
                fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                    view.removeFromSuperview()
                })
            }
            if let view = self.emptyResultsAction.view {
                fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                    view.removeFromSuperview()
                })
            }
        }
        
        fadeTransition.setAlpha(view: self.emptyResultsClippingView, alpha: visibleHeight < 300.0 ? 0.0 : 1.0)
        
        if self.peerId == self.context.account.peerId, !self.canSelect && !self.filteredResultsAreEmpty && self.profileGifts.collectionId == nil && self.emptyResultsClippingView.isHidden {
            let footerText: ComponentView<Empty>
            if let current = self.footerText {
                footerText = current
            } else {
                footerText = ComponentView<Empty>()
                self.footerText = footerText
            }
            let footerTextSize = footerText.update(
                transition: .immediate,
                component: AnyComponent(
                    BalancedTextComponent(
                        text: .markdown(text: presentationData.strings.PeerInfo_Gifts_Info, attributes: markdownAttributes),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: size.width - 32.0, height: 200.0)
            )
            if let view = footerText.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: floor((size.width - footerTextSize.width) / 2.0), y: contentHeight), size: footerTextSize))
            }
            contentHeight += footerTextSize.height
        } else if let footerText = self.footerText {
            self.footerText = nil
            if let view = footerText.view {
                fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                    view.removeFromSuperview()
                })
            }
        }
                        
        return contentHeight
    }
        
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, visibleBounds: CGRect, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.currentParams = (size, sideInset, bottomInset, deviceMetrics, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
        self.presentationDataPromise.set(.single(presentationData))
        
        return self.updateScrolling(topInset: self.topInset ?? 0.0, visibleBounds: visibleBounds, transition: ComponentTransition(transition))
    }
}

private extension StarGiftReference {
    var stringValue: String {
        switch self {
        case let .message(messageId):
            return "m_\(messageId.id)"
        case let .peer(peerId, id):
            return "p_\(peerId.toInt64())_\(id)"
        case let .slug(slug):
            return "s_\(slug)"
        }
    }
}


private final class ReorderGestureRecognizer: UIGestureRecognizer {
    private let shouldBegin: (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, id: AnyHashable?, item: ComponentView<Empty>?)
    private let willBegin: (CGPoint) -> Void
    private let began: (AnyHashable) -> Void
    private let ended: () -> Void
    private let moved: (CGPoint) -> Void
    private let isActiveUpdated: (Bool) -> Void
    
    private var initialLocation: CGPoint?
    private var longTapTimer: SwiftSignalKit.Timer?
    private var longPressTimer: SwiftSignalKit.Timer?
    
    private var id: AnyHashable?
    private var itemView: ComponentView<Empty>?
    
    init(shouldBegin: @escaping (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, id: AnyHashable?, item: ComponentView<Empty>?), willBegin: @escaping (CGPoint) -> Void, began: @escaping (AnyHashable) -> Void, ended: @escaping () -> Void, moved: @escaping (CGPoint) -> Void, isActiveUpdated: @escaping (Bool) -> Void) {
        self.shouldBegin = shouldBegin
        self.willBegin = willBegin
        self.began = began
        self.ended = ended
        self.moved = moved
        self.isActiveUpdated = isActiveUpdated
        
        super.init(target: nil, action: nil)
    }
    
    deinit {
        self.longTapTimer?.invalidate()
        self.longPressTimer?.invalidate()
    }
    
    private func startLongTapTimer() {
        self.longTapTimer?.invalidate()
        let longTapTimer = SwiftSignalKit.Timer(timeout: 0.25, repeat: false, completion: { [weak self] in
            self?.longTapTimerFired()
        }, queue: Queue.mainQueue())
        self.longTapTimer = longTapTimer
        longTapTimer.start()
    }
    
    private func stopLongTapTimer() {
        self.itemView = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
    }
    
    private func startLongPressTimer() {
        self.longPressTimer?.invalidate()
        let longPressTimer = SwiftSignalKit.Timer(timeout: 0.6, repeat: false, completion: { [weak self] in
            self?.longPressTimerFired()
        }, queue: Queue.mainQueue())
        self.longPressTimer = longPressTimer
        longPressTimer.start()
    }
    
    private func stopLongPressTimer() {
        self.itemView = nil
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
    }
    
    override func reset() {
        super.reset()
        
        self.itemView = nil
        self.stopLongTapTimer()
        self.stopLongPressTimer()
        self.initialLocation = nil
        
        self.isActiveUpdated(false)
    }
    
    private func longTapTimerFired() {
        guard let location = self.initialLocation else {
            return
        }
        
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        
        self.willBegin(location)
    }
    
    private func longPressTimerFired() {
        guard let _ = self.initialLocation else {
            return
        }
        
        self.isActiveUpdated(true)
        self.state = .began
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        if let id = self.id {
            self.began(id)
        }
        self.isActiveUpdated(true)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.numberOfTouches > 1 {
            self.isActiveUpdated(false)
            self.state = .failed
            self.ended()
            return
        }
        
        if self.state == .possible {
            if let location = touches.first?.location(in: self.view) {
                let (allowed, requiresLongPress, id, itemView) = self.shouldBegin(location)
                if allowed {
                    self.isActiveUpdated(true)
                    
                    self.id = id
                    self.itemView = itemView
                    self.initialLocation = location
                    if requiresLongPress {
                        self.startLongTapTimer()
                        self.startLongPressTimer()
                    } else {
                        self.state = .began
                        if let id = self.id {
                            self.began(id)
                        }
                    }
                } else {
                    self.isActiveUpdated(false)
                    self.state = .failed
                }
            } else {
                self.isActiveUpdated(false)
                self.state = .failed
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.initialLocation = nil
        
        self.stopLongTapTimer()
        if self.longPressTimer != nil {
            self.stopLongPressTimer()
            self.isActiveUpdated(false)
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.isActiveUpdated(false)
            self.ended()
            self.state = .failed
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.initialLocation = nil
        
        self.stopLongTapTimer()
        if self.longPressTimer != nil {
            self.isActiveUpdated(false)
            self.stopLongPressTimer()
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.isActiveUpdated(false)
            self.ended()
            self.state = .failed
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if (self.state == .began || self.state == .changed), let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) {
            self.state = .changed
            let offset = CGPoint(x: location.x - initialLocation.x, y: location.y - initialLocation.y)
            self.moved(offset)
        } else if let touch = touches.first, let initialTapLocation = self.initialLocation, self.longPressTimer != nil {
            let touchLocation = touch.location(in: self.view)
            let dX = touchLocation.x - initialTapLocation.x
            let dY = touchLocation.y - initialTapLocation.y
            
            if dX * dX + dY * dY > 3.0 * 3.0 {
                self.stopLongTapTimer()
                self.stopLongPressTimer()
                self.initialLocation = nil
                self.isActiveUpdated(false)
                self.state = .failed
            }
        }
    }
}

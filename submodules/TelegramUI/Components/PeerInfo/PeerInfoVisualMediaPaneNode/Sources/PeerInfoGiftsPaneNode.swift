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
import ChatControllerInteraction
import MultilineTextComponent
import BalancedTextComponent
import Markdown
import PeerInfoPaneNode
import GiftItemComponent
import PlainButtonComponent
import GiftViewScreen
import SolidRoundedButtonNode
import UndoUI
import CheckComponent
import LottieComponent
import ContextUI

public final class PeerInfoGiftsPaneNode: ASDisplayNode, PeerInfoPaneNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let peerId: PeerId
    private let profileGifts: ProfileGiftsContext
    private let canManage: Bool
    private let canGift: Bool
    
    private var dataDisposable: Disposable?
    
    private let chatControllerInteraction: ChatControllerInteraction
    
    public weak var parentController: ViewController?
    
    private let backgroundNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    
    private var footerText: ComponentView<Empty>?
    private var panelBackground: NavigationBackgroundNode?
    private var panelSeparator: ASDisplayNode?
    private var panelButton: SolidRoundedButtonNode?
    private var panelCheck: ComponentView<Empty>?
    
    private let emptyResultsClippingView = UIView()
    private let emptyResultsAnimation = ComponentView<Empty>()
    private let emptyResultsTitle = ComponentView<Empty>()
    private let emptyResultsAction = ComponentView<Empty>()
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData)?
    
    private var theme: PresentationTheme?
    private let presentationDataPromise = Promise<PresentationData>()
    
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
            
    private var starsProducts: [ProfileGiftsContext.State.StarGift]?
    private var starsItems: [AnyHashable: (StarGiftReference?, ComponentView<Empty>)] = [:]
    private var resultsAreFiltered = false
    private var resultsAreEmpty = false
    
    private var pinnedReferences: [StarGiftReference] = []
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
    
    private let maxPinnedCount: Int
    
    public init(context: AccountContext, peerId: PeerId, chatControllerInteraction: ChatControllerInteraction, profileGifts: ProfileGiftsContext, canManage: Bool, canGift: Bool) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        self.profileGifts = profileGifts
        self.canManage = canManage
        self.canGift = canGift
        
        self.backgroundNode = ASDisplayNode()
        self.scrollNode = ASScrollNode()
        
        if let value = context.currentAppConfiguration.with({ $0 }).data?["stargifts_pinned_to_top_limit"] as? Double {
            self.maxPinnedCount = Int(value)
        } else {
            self.maxPinnedCount = 6
        }
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.scrollNode)
                                
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
            
            self.resultsAreFiltered = state.filter != .All
            self.resultsAreEmpty = state.filter != .All && state.filteredGifts.isEmpty
        
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(.single(true))
            }
            
            self.updateScrolling(transition: isFirstTime ? .immediate : .easeInOut(duration: 0.25))
        })
    }
    
    deinit {
        self.dataDisposable?.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        self.scrollNode.view.delegate = self
        
        self.emptyResultsClippingView.clipsToBounds = true
        self.scrollNode.view.addSubview(self.emptyResultsClippingView)
        
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
        self.view.addGestureRecognizer(reorderRecognizer)
        reorderRecognizer.isEnabled = false
    }
    
    private func item(at point: CGPoint) -> (AnyHashable, ComponentView<Empty>)? {
        let localPoint = self.scrollNode.view.convert(point, from: self.view)
        for (id, visibleItem) in self.starsItems {
            if let view = visibleItem.1.view, view.frame.contains(localPoint), let reference = visibleItem.0, self.pinnedReferences.contains(reference) {
                return (id, visibleItem.1)
            }
        }
        return nil
    }
    
    public func beginReordering() {
        self.profileGifts.updateFilter(.All)
        self.profileGifts.updateSorting(.date)
        
        if let parentController = self.parentController as? PeerInfoScreen {
            parentController.togglePaneIsReordering(isReordering: true)
        } else {
            self.updateIsReordering(isReordering: true, animated: true)
        }
    }
    
    public func endReordering() {
        if let parentController = self.parentController as? PeerInfoScreen {
            parentController.togglePaneIsReordering(isReordering: false)
        } else {
            self.updateIsReordering(isReordering: false, animated: true)
        }
    }
    
    public func updateIsReordering(isReordering: Bool, animated: Bool) {
        if self.isReordering != isReordering {
            self.isReordering = isReordering
            
            self.reorderRecognizer?.isEnabled = isReordering
            
            if !isReordering, let _ = self.reorderedReferences, let starsProducts = self.starsProducts {
                var pinnedReferences: [StarGiftReference] = []
                for gift in starsProducts.prefix(self.maxPinnedCount) {
                    if gift.pinnedToTop, let reference = gift.reference {
                        pinnedReferences.append(reference)
                    }
                }
                self.profileGifts.updatePinnedToTopStarGifts(references: pinnedReferences)
                
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
                self.scrollNode.view.addSubview(view)
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
    
    private func reorderIfPossible(reference: StarGiftReference, toIndex: Int) {
        if let items = self.starsProducts {
            var toIndex = toIndex
            
            let maxPinnedIndex = items.lastIndex(where: { $0.pinnedToTop })
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
                        replacingTitle = "\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, presentationData.dateTimeFormat.groupingSeparator))"
                    }
                }
                
                var updatedPinnedGifts = self.pinnedReferences
                if let index = updatedPinnedGifts.firstIndex(of: unpinnedReference), let reference = gift.reference {
                    updatedPinnedGifts[index] = reference
                }
                self.profileGifts.updatePinnedToTopStarGifts(references: updatedPinnedGifts)
                
                var title = ""
                if case let .unique(uniqueGift) = gift.gift {
                    title = "\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, presentationData.dateTimeFormat.groupingSeparator))"
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
    
    private var notify = false
    func updateScrolling(interactive: Bool = false, transition: ComponentTransition) {
        if let starsProducts = self.starsProducts, let params = self.currentParams {
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
            
            let visibleBounds = self.scrollNode.bounds.insetBy(dx: 0.0, dy: -10.0)
            
            let topInset: CGFloat = 60.0
            
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
                    var resellPrice: Int64?
                    
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
                        resellPrice = gift.resellStars
                        
                        if let _ = resellPrice {
                            ribbonText = params.presentationData.strings.PeerInfo_Gifts_Sale
                            ribbonFont = .larger
                            ribbonColor = .green
                            ribbonOutline =  params.presentationData.theme.list.blocksBackgroundColor
                        } else {
                            if product.pinnedToTop {
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
                                resellPrice: resellPrice,
                                isHidden: !product.savedToProfile,
                                isPinned: product.pinnedToTop,
                                isEditing: self.isReordering,
                                mode: .profile,
                                action: { [weak self] in
                                    guard let self, let presentationData = self.currentParams?.presentationData else {
                                        return
                                    }
                                    if self.isReordering {
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
                                            convertToStars: { [weak self] in
                                                guard let self, let reference = product.reference else {
                                                    return
                                                }
                                                self.profileGifts.convertStarGift(reference: reference)
                                            },
                                            transferGift: { [weak self] prepaid, peerId in
                                                guard let self, let reference = product.reference else {
                                                    return .complete()
                                                }
                                                return self.profileGifts.transferStarGift(prepaid: prepaid, reference: reference, peerId: peerId)
                                            },
                                            upgradeGift: { [weak self] formId, keepOriginalInfo in
                                                guard let self, let reference = product.reference else {
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
                                            updateResellStars: { [weak self] price in
                                                guard let self, let reference = product.reference else {
                                                    return .never()
                                                }
                                                return self.profileGifts.updateStarGiftResellPrice(reference: reference, price: price)
                                            },
                                            togglePinnedToTop: { [weak self] pinnedToTop in
                                                guard let self else {
                                                    return false
                                                }
                                                if let reference = product.reference {
                                                    if pinnedToTop && self.pinnedReferences.count >= self.maxPinnedCount {
                                                        self.displayUnpinScreen(gift: product, completion: {
                                                            dismissImpl?()
                                                        })
                                                        return false
                                                    }
                                                    self.profileGifts.updateStarGiftPinnedToTop(reference: reference, pinnedToTop: pinnedToTop)
                                                    
                                                    var title = ""
                                                    if case let .unique(uniqueGift) = product.gift {
                                                        title = "\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, params.presentationData.dateTimeFormat.groupingSeparator))"
                                                    }
                                                    
                                                    if pinnedToTop {
                                                        let _ = self.scrollToTop()
                                                        Queue.mainQueue().after(0.35) {
                                                            let toastTitle = params.presentationData.strings.PeerInfo_Gifts_ToastPinned_TitleNew(title).string
                                                            let toastText = params.presentationData.strings.PeerInfo_Gifts_ToastPinned_Text
                                                            self.parentController?.present(UndoOverlayController(presentationData: params.presentationData, content: .universal(animation: "anim_toastpin", scale: 0.06, colors: [:], title: toastTitle, text: toastText, customUndoText: nil, timeout: 5), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                                        }
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
                                contextAction: self.isReordering ? nil : { [weak self] view, gesture in
                                    guard let self else {
                                        return
                                    }
                                    self.contextAction(gift: product, view: view, gesture: gesture)
                                }
                            )
                        ),
                        environment: {},
                        containerSize: starsOptionSize
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.scrollNode.view.addSubview(itemView)
                            
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
                        
                        if self.isReordering && product.pinnedToTop {
                            if itemView.layer.animation(forKey: "shaking_position") == nil {
                                startShaking(layer: itemView.layer)
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
            
            var bottomScrollInset: CGFloat = 0.0
            var contentHeight = ceil(CGFloat(starsProducts.count) / CGFloat(defaultItemsInRow)) * (starsOptionSize.height + optionSpacing) - optionSpacing + topInset + 16.0
            
            let size = params.size
            let sideInset = params.sideInset
            let bottomInset = params.bottomInset
            let presentationData = params.presentationData
          
            let themeUpdated = self.theme !== presentationData.theme
            self.theme = presentationData.theme
            
            let panelBackground: NavigationBackgroundNode
            let panelSeparator: ASDisplayNode
            let panelButton: SolidRoundedButtonNode
            
            var panelAlpha = params.expandProgress
            if !self.canGift {
                panelAlpha = 0.0
            }
            
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
                self.addSubnode(panelSeparator)
                self.panelSeparator = panelSeparator
            }
                                    
            if let current = self.panelButton {
                panelButton = current
            } else {
                panelButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: presentationData.theme), height: 50.0, cornerRadius: 10.0)
                self.view.addSubview(panelButton.view)
                self.panelButton = panelButton
            
                panelButton.title = self.peerId == self.context.account.peerId ? params.presentationData.strings.PeerInfo_Gifts_Send : params.presentationData.strings.PeerInfo_Gifts_SendGift
                
                panelButton.pressed = { [weak self] in
                    self?.buttonPressed()
                }
            }
        
            if themeUpdated {
                panelBackground.updateColor(color: presentationData.theme.rootController.tabBar.backgroundColor, transition: .immediate)
                panelSeparator.backgroundColor = presentationData.theme.rootController.tabBar.separatorColor
                panelButton.updateTheme(SolidRoundedButtonTheme(theme: presentationData.theme))
            }
            
            let textFont = Font.regular(13.0)
            let boldTextFont = Font.semibold(13.0)
            let textColor = presentationData.theme.list.itemSecondaryTextColor
            let linkColor = presentationData.theme.list.itemAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: boldTextFont, textColor: linkColor), linkAttribute: { _ in
                return nil
            })
            
            var scrollOffset: CGFloat = max(0.0, size.height - params.visibleHeight)
            
            let buttonSideInset = sideInset + 16.0
            let buttonSize = CGSize(width: size.width - buttonSideInset * 2.0, height: 50.0)
            let effectiveBottomInset = max(8.0, bottomInset)
            var bottomPanelHeight = effectiveBottomInset + buttonSize.height + 8.0
            if params.visibleHeight < 110.0 {
                scrollOffset -= bottomPanelHeight
            }
            
            let panelTransition = ComponentTransition.immediate
            panelTransition.setFrame(view: panelButton.view, frame: CGRect(origin: CGPoint(x: buttonSideInset, y: size.height - effectiveBottomInset - buttonSize.height - scrollOffset), size: buttonSize))
            panelTransition.setAlpha(view: panelButton.view, alpha: panelAlpha)
            let _ = panelButton.updateLayout(width: buttonSize.width, transition: .immediate)
            
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
                    containerSize: buttonSize
                )
                if let panelCheckView = panelCheck.view {
                    if panelCheckView.superview == nil {
                        self.view.addSubview(panelCheckView)
                    }
                    panelCheckView.frame = CGRect(origin: CGPoint(x: floor((size.width - panelCheckSize.width) / 2.0), y: size.height - effectiveBottomInset - panelCheckSize.height - 11.0 - scrollOffset), size: panelCheckSize)
                    panelTransition.setAlpha(view: panelCheckView, alpha: panelAlpha)
                }
                panelButton.isHidden = true
            }
            
            panelTransition.setFrame(view: panelBackground.view, frame: CGRect(x: 0.0, y: size.height - bottomPanelHeight - scrollOffset, width: size.width, height: bottomPanelHeight))
            panelTransition.setAlpha(view: panelBackground.view, alpha: panelAlpha)
            panelBackground.update(size: CGSize(width: size.width, height: bottomPanelHeight), transition: transition.containedViewLayoutTransition)
            panelTransition.setFrame(view: panelSeparator.view, frame: CGRect(x: 0.0, y: size.height - bottomPanelHeight - scrollOffset, width: size.width, height: UIScreenPixel))
            panelTransition.setAlpha(view: panelSeparator.view, alpha: panelAlpha)
            
            let fadeTransition = ComponentTransition.easeInOut(duration: 0.25)
            if self.resultsAreEmpty {
                let sideInset: CGFloat = 44.0
                let emptyAnimationHeight = 148.0
                let topInset: CGFloat = 0.0
                let bottomInset: CGFloat = bottomPanelHeight
                let visibleHeight = params.visibleHeight
                let emptyAnimationSpacing: CGFloat = 20.0
                let emptyTextSpacing: CGFloat = 18.0
                
                self.emptyResultsClippingView.isHidden = false
                                
                panelTransition.setFrame(view: self.emptyResultsClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: self.scrollNode.frame.size))
                panelTransition.setBounds(view: self.emptyResultsClippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: self.scrollNode.frame.size))
                
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
                        self.emptyResultsClippingView.isHidden = true
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsTitle.view {
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
            
            if self.peerId == self.context.account.peerId, !self.resultsAreEmpty {
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
                        self.scrollNode.view.addSubview(view)
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: floor((size.width - footerTextSize.width) / 2.0), y: contentHeight), size: footerTextSize))
                }
                contentHeight += footerTextSize.height
            }
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
        if interactive, bottomContentOffset < 200.0 {
            self.profileGifts.loadMore()
        }
    }
        
    @objc private func buttonPressed() {
        if self.peerId == self.context.account.peerId {
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
        } else {
            self.chatControllerInteraction.sendGift(self.peerId)
        }
    }
    
    private func contextAction(gift: ProfileGiftsContext.State.StarGift, view: UIView, gesture: ContextGesture) {
        guard let currentParams = self.currentParams, let currentState = self.profileGifts.currentState else {
            return
        }
        let presentationData = currentParams.presentationData
        let strings = presentationData.strings
        
        let canManage = self.peerId == self.context.account.peerId || self.canManage
        var canReorder = false
        if case .All = currentState.filter {
            for gift in currentState.gifts {
                if gift.pinnedToTop {
                    canReorder = true
                    break
                }
            }
        }
        
        var items: [ContextMenuItem] = []
        if canManage {
            if case .unique = gift.gift {
                items.append(.action(ContextMenuActionItem(text: gift.pinnedToTop ? strings.PeerInfo_Gifts_Context_Unpin  : strings.PeerInfo_Gifts_Context_Pin , icon: { theme in generateTintedImage(image: UIImage(bundleImageName: gift.pinnedToTop ? "Chat/Context Menu/Unpin" : "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                    c?.dismiss(completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        let pinnedToTop = !gift.pinnedToTop
                        guard let reference = gift.reference else {
                            return
                        }
                        
                        if pinnedToTop && self.pinnedReferences.count >= self.maxPinnedCount {
                            self.displayUnpinScreen(gift: gift)
                            return
                        }
                        
                        self.profileGifts.updateStarGiftPinnedToTop(reference: reference, pinnedToTop: pinnedToTop)
                        
                        let toastTitle: String?
                        let toastText: String
                        if !pinnedToTop {
                            toastTitle = nil
                            toastText = strings.PeerInfo_Gifts_ToastUnpinned_Text
                        } else {
                            var title = ""
                            if case let .unique(uniqueGift) = gift.gift {
                                title = "\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, presentationData.dateTimeFormat.groupingSeparator))"
                            }
                            toastTitle = strings.PeerInfo_Gifts_ToastPinned_TitleNew(title).string
                            toastText = strings.PeerInfo_Gifts_ToastPinned_Text
                        }
                        self.parentController?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: !pinnedToTop ? "anim_toastunpin" : "anim_toastpin", scale: 0.06, colors: [:], title: toastTitle, text: toastText, customUndoText: nil, timeout: 5), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    })
                })))
            }
            
            if case .unique = gift.gift, canManage && canReorder {
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
                        self.profileGifts.updateStarGiftAddedToProfile(reference: reference, added: added)
                        
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
                            let controller = context.sharedContext.makePremiumGiftController(context: context, source: .starGiftTransfer(birthdays, reference, uniqueGift, transferStars, gift.canExportDate, showSelf), completion: { [weak self] peerIds in
                                guard let self, let peerId = peerIds.first else {
                                    return .complete()
                                }
                                Queue.mainQueue().after(1.5, {
                                    if transferStars > 0 {
                                        context.starsContext?.load(force: true)
                                    }
                                })
                                return self.profileGifts.transferStarGift(prepaid: transferStars == 0, reference: reference, peerId: peerId)
                            })
                            self.parentController?.push(controller)
                        })
                    })
                })))
            }
        }
        
        guard !items.isEmpty else {
            return
        }
        
        let previewController = GiftContextPreviewController(context: self.context, gift: gift)
        let contextController = ContextController(
            presentationData: currentParams.presentationData,
            source: .controller(ContextControllerContentSourceImpl(controller: previewController, sourceView: view)),
            items: .single(ContextController.Items(content: .list(items))), gesture: gesture
        )
        self.parentController?.presentInGlobalOverlay(contextController)
    }
    
    public func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, deviceMetrics: DeviceMetrics, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, sideInset, bottomInset, deviceMetrics, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
        self.presentationDataPromise.set(.single(presentationData))
        
        self.backgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 48.0), size: size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))

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

private func startShaking(layer: CALayer) {
    func degreesToRadians(_ x: CGFloat) -> CGFloat {
        return .pi * x / 180.0
    }

    let duration: Double = 0.4
    let displacement: CGFloat = 1.0
    let degreesRotation: CGFloat = 2.0
    
    let negativeDisplacement = -1.0 * displacement
    let position = CAKeyframeAnimation.init(keyPath: "position")
    position.beginTime = 0.8
    position.duration = duration
    position.values = [
        NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement)),
        NSValue(cgPoint: CGPoint(x: 0, y: 0)),
        NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: 0)),
        NSValue(cgPoint: CGPoint(x: 0, y: negativeDisplacement)),
        NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement))
    ]
    position.calculationMode = .linear
    position.isRemovedOnCompletion = false
    position.repeatCount = Float.greatestFiniteMagnitude
    position.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))
    position.isAdditive = true

    let transform = CAKeyframeAnimation.init(keyPath: "transform")
    transform.beginTime = 2.6
    transform.duration = 0.3
    transform.valueFunction = CAValueFunction(name: CAValueFunctionName.rotateZ)
    transform.values = [
        degreesToRadians(-1.0 * degreesRotation),
        degreesToRadians(degreesRotation),
        degreesToRadians(-1.0 * degreesRotation)
    ]
    transform.calculationMode = .linear
    transform.isRemovedOnCompletion = false
    transform.repeatCount = Float.greatestFiniteMagnitude
    transform.isAdditive = true
    transform.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))

    layer.add(position, forKey: "shaking_position")
    layer.add(transform, forKey: "shaking_rotation")
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
    
    public init(shouldBegin: @escaping (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, id: AnyHashable?, item: ComponentView<Empty>?), willBegin: @escaping (CGPoint) -> Void, began: @escaping (AnyHashable) -> Void, ended: @escaping () -> Void, moved: @escaping (CGPoint) -> Void, isActiveUpdated: @escaping (Bool) -> Void) {
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
    
    override public func reset() {
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
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
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
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
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
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
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
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
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

import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import ViewControllerComponent
import BundleIconComponent
import MultilineTextComponent
import GiftItemComponent
import AccountContext
import AnimatedTextComponent
import Markdown
import PresentationDataUtils
import GiftViewScreen
import NavigationStackComponent
import GiftStoreScreen
import ResizableSheetComponent
import TooltipUI
import GlassBarButtonComponent
import ConfettiEffect
import GiftLoadingShimmerView

final class SelectGiftPageContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let craftContext: CraftGiftsContext
    let resaleContext: ResaleGiftsContext
    let gift: StarGift.UniqueGift
    let genericGift: StarGift.Gift
    let selectedGiftIds: Set<Int64>
    let starsTopUpOptions: Signal<[StarsTopUpOption]?, NoError>
    let selectGift: (GiftItem) -> Void
    let dismiss: () -> Void
    let boundsUpdated: ActionSlot<ResizableSheetComponentEnvironment.BoundsUpdate>
    
    init(
        context: AccountContext,
        craftContext: CraftGiftsContext,
        resaleContext: ResaleGiftsContext,
        gift: StarGift.UniqueGift,
        genericGift: StarGift.Gift,
        selectedGiftIds: Set<Int64>,
        starsTopUpOptions: Signal<[StarsTopUpOption]?, NoError>,
        selectGift: @escaping (GiftItem) -> Void,
        dismiss: @escaping () -> Void,
        boundsUpdated: ActionSlot<ResizableSheetComponentEnvironment.BoundsUpdate>
    ) {
        self.context = context
        self.craftContext = craftContext
        self.resaleContext = resaleContext
        self.gift = gift
        self.genericGift = genericGift
        self.selectedGiftIds = selectedGiftIds
        self.starsTopUpOptions = starsTopUpOptions
        self.selectGift = selectGift
        self.dismiss = dismiss
        self.boundsUpdated = boundsUpdated
    }
    
    static func ==(lhs: SelectGiftPageContent, rhs: SelectGiftPageContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        if lhs.selectedGiftIds != rhs.selectedGiftIds {
            return false
        }
        return true
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let myGiftsTitle = ComponentView<Empty>()
        private var gifts: [AnyHashable: ComponentView<Empty>] = [:]
        private let myGiftsPlaceholder = ComponentView<Empty>()
        private let loadingView = GiftLoadingShimmerView()
        
        private let storeGiftsTitle = ComponentView<Empty>()
        private let storeGifts = ComponentView<Empty>()
        
        private var craftState: CraftGiftsContext.State?
        private var craftStateDisposable: Disposable?
                
        private var availableGifts: [GiftItem] = []
        private var giftMap: [Int64: ProfileGiftsContext.State.StarGift] = [:]
                
        private var availableSize: CGSize?
        private var currentBounds: CGRect?
        
        private var component: SelectGiftPageContent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.cornerRadius = 40.0
            self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                        
            self.addSubview(self.loadingView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.craftStateDisposable?.dispose()
        }
        
        func updateScrolling(interactive: Bool, transition: ComponentTransition) -> CGFloat {
            guard let bounds = self.currentBounds, let availableSize = self.availableSize, let component = self.component, let environment = self.environment else {
                return 0.0
            }
            
            let visibleBounds = bounds.insetBy(dx: 0.0, dy: -10.0)
            
            var contentHeight: CGFloat = 88.0 + 32.0
            
            let itemSpacing: CGFloat = 10.0
            let itemSideInset = 16.0
            let itemsInRow: Int
            if availableSize.width > availableSize.height || availableSize.width > 480.0 {
                if case .tablet = environment.deviceMetrics.type {
                    itemsInRow = 4
                } else {
                    itemsInRow = 5
                }
            } else {
                itemsInRow = 3
            }
            let itemWidth = (availableSize.width - itemSideInset * 2.0 - itemSpacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow)
            let itemSize = CGSize(width: itemWidth, height: itemWidth)

            var isLoading = false
            if self.availableGifts.isEmpty, case .loading = (self.craftState?.dataState ?? .loading) {
                isLoading = true
            }
            let loadingTransition: ComponentTransition = .easeInOut(duration: 0.25)
            let loadingSize = CGSize(width: availableSize.width, height: 180.0)
            if isLoading {
                contentHeight += 120.0
                self.loadingView.update(size: loadingSize, theme: environment.theme, itemSize: itemSize, showFilters: false, isPlain: true, transition: .immediate)
                loadingTransition.setAlpha(view: self.loadingView, alpha: 1.0)
            } else {
                loadingTransition.setAlpha(view: self.loadingView, alpha: 0.0)
            }
            transition.setFrame(view: self.loadingView, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight - 170.0), size: loadingSize))
            
            var itemFrame = CGRect(origin: CGPoint(x: itemSideInset, y: contentHeight), size: itemSize)
            var itemsHeight: CGFloat = 0.0
            var validIds: [AnyHashable] = []
            for gift in self.availableGifts {
                var isVisible = false
                if visibleBounds.intersects(itemFrame) {
                    isVisible = true
                }
                if isVisible {
                    let itemId = AnyHashable(gift.gift.id)
                    validIds.append(itemId)
                    
                    var itemTransition = transition
                    let visibleItem: ComponentView<Empty>
                    if let current = self.gifts[itemId] {
                        visibleItem = current
                    } else {
                        visibleItem = ComponentView()
                        self.gifts[itemId] = visibleItem
                        itemTransition = .immediate
                    }
                    
                    var ribbonColor: GiftItemComponent.Ribbon.Color = .blue
                    let ribbonText = "#\(gift.gift.number)"
                    for attribute in gift.gift.attributes {
                        if case let .backdrop(_, _, innerColor, outerColor, _, _, _) = attribute {
                            ribbonColor = .custom(outerColor, innerColor)
                            break
                        }
                    }
                    
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(
                            GiftItemComponent(
                                context: component.context,
                                style: .glass,
                                theme: environment.theme,
                                strings: environment.strings,
                                peer: nil,
                                subject: .uniqueGift(gift: gift.gift, price: nil),
                                ribbon: GiftItemComponent.Ribbon(text: ribbonText, font: .monospaced, color: ribbonColor, outline: nil),
                                badge: gift.gift.craftChancePermille.flatMap { "+\($0 / 10)%" },
                                resellPrice: nil,
                                isHidden: false,
                                isSelected: false,
                                isPinned: false,
                                isEditing: false,
                                mode: .grid,
                                action: { [weak self] in
                                    guard let self, let component = self.component, let environment = self.environment else {
                                        return
                                    }
                                    HapticFeedback().impact(.light)
                                    
                                    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                                    if let profileGift = self.giftMap[gift.gift.id], let canCraftDate = profileGift.canCraftAt, currentTime < canCraftDate {
                                        let dateString = stringForFullDate(timestamp: canCraftDate, strings: environment.strings, dateTimeFormat: environment.dateTimeFormat)
                                        let alertController = textAlertController(
                                            context: component.context,
                                            title: environment.strings.Gift_Craft_Unavailable_Title,
                                            text: environment.strings.Gift_Craft_Unavailable_Text(dateString).string,
                                            actions: [
                                                TextAlertAction(type: .defaultAction, title: environment.strings.Common_OK, action: {})
                                            ],
                                            parseMarkdown: true
                                        )
                                        environment.controller()?.present(alertController, in: .window(.root))
                                        return
                                    }
                                    
                                    component.selectGift(gift)
                                    component.dismiss()
                                },
                                contextAction: { _, _ in }
                            )
                        ),
                        environment: {},
                        containerSize: itemSize
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            if let _ = self.loadingView.superview {
                                self.insertSubview(itemView, belowSubview: self.loadingView)
                            } else {
                                self.addSubview(itemView)
                            }
                            if !transition.animation.isImmediate {
                                itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                }
                
                itemsHeight = itemFrame.maxY - contentHeight
                
                itemFrame.origin.x += itemFrame.width + itemSpacing
                if itemFrame.maxX > availableSize.width {
                    itemFrame.origin.x = itemSideInset
                    itemFrame.origin.y += itemSize.height + itemSpacing
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.gifts {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = item.view {
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
                self.gifts.removeValue(forKey: id)
            }
                        
            if let state = self.craftState, case .ready = state.dataState, self.availableGifts.isEmpty {
                contentHeight += 10.0
                let myGiftsPlaceholderSize = self.myGiftsPlaceholder.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.Gift_Craft_Select_NoGiftsFromCollection, font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 3,
                            lineSpacing: 0.1
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 32.0, height: .greatestFiniteMagnitude)
                )
                let myGiftsPlaceholderFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - myGiftsPlaceholderSize.width) / 2.0), y: contentHeight), size: myGiftsPlaceholderSize)
                if let myGiftsPlaceholderView = self.myGiftsPlaceholder.view {
                    if myGiftsPlaceholderView.superview == nil {
                        self.addSubview(myGiftsPlaceholderView)
                    }
                    myGiftsPlaceholderView.frame = myGiftsPlaceholderFrame
                }
                contentHeight += myGiftsPlaceholderSize.height
                contentHeight += 32.0
            } else {
                contentHeight += itemsHeight
                contentHeight += 24.0
            }
            
            if let storeGiftsView = self.storeGifts.view as? GiftStoreContentComponent.View {
                storeGiftsView.updateScrolling(bounds: bounds.offsetBy(dx: 0.0, dy: -contentHeight), interactive: interactive, transition: .immediate)
            }
            
            let bottomContentOffset = max(0.0, contentHeight - bounds.origin.y - bounds.height)
            if interactive, bottomContentOffset < 800.0 {
                Queue.mainQueue().justDispatch {
                    component.craftContext.loadMore()
                }
            }
            
            return contentHeight
        }
                
        func update(component: SelectGiftPageContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.availableSize = availableSize
            if self.component == nil {
                self.currentBounds = CGRect(origin: .zero, size: availableSize)
                
                component.boundsUpdated.connect { [weak self] update in
                    guard let self else {
                        return
                    }
                    self.currentBounds = update.bounds
                    let _ = self.updateScrolling(interactive: update.isInteractive, transition: .immediate)
                }
                
                let initialGiftItem = GiftItem(
                    gift: component.gift,
                    reference: .slug(slug: component.gift.slug)
                )
                self.availableGifts = [
                    initialGiftItem
                ]
                
                self.craftStateDisposable = (component.craftContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    self.craftState = state
                    
                    var items: [GiftItem] = []
                    var giftMap: [Int64: ProfileGiftsContext.State.StarGift] = [:]
                    var existingIds = Set<Int64>()
                    for gift in state.gifts {
                        guard let reference = gift.reference, case let .unique(uniqueGift) = gift.gift, !existingIds.contains(uniqueGift.id) else {
                            continue
                        }
                        existingIds.insert(uniqueGift.id)
                        
                        let giftItem = GiftItem(
                            gift: uniqueGift,
                            reference: reference
                        )
                        giftMap[uniqueGift.id] = gift
   
                        if component.selectedGiftIds.contains(uniqueGift.id) {
                            continue
                        }
                        items.append(giftItem)
                    }
                    
                    self.availableGifts = items
                    self.giftMap = giftMap
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                })
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            self.component = component
            self.state = state
            self.environment = environment
            
            self.backgroundColor = environment.theme.actionSheet.opaqueItemBackgroundColor
                                    
            var contentHeight: CGFloat = 88.0
                                   
            let myGiftsTitleSize = self.myGiftsTitle.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_Craft_Select_YourGifts.uppercased(), font: Font.semibold(14.0), textColor: environment.theme.actionSheet.secondaryTextColor)))
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let myGiftsTitleFrame = CGRect(origin: CGPoint(x: 26.0, y: contentHeight), size: myGiftsTitleSize)
            if let myGiftsTitleView = self.myGiftsTitle.view {
                if myGiftsTitleView.superview == nil {
                    self.addSubview(myGiftsTitleView)
                }
                transition.setFrame(view: myGiftsTitleView, frame: myGiftsTitleFrame)
            }
            
            contentHeight += 32.0
                        
            contentHeight = self.updateScrolling(interactive: false, transition: transition)
            
            let resaleCount = component.genericGift.availability?.resale ?? 0
            let saleTitle = environment.strings.Gift_Craft_Select_SaleGiftsCount(Int32(clamping: resaleCount)).uppercased()
            
            let storeGiftsTitleSize = self.storeGiftsTitle.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: saleTitle, font: Font.semibold(14.0), textColor: environment.theme.actionSheet.secondaryTextColor)))
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let storeGiftsTitleFrame = CGRect(origin: CGPoint(x: 26.0, y: contentHeight), size: storeGiftsTitleSize)
            if let storeGiftsTitleView = self.storeGiftsTitle.view {
                if storeGiftsTitleView.superview == nil {
                    self.addSubview(storeGiftsTitleView)
                }
                transition.setFrame(view: storeGiftsTitleView, frame: storeGiftsTitleFrame)
            }
            contentHeight += 28.0
            
            self.storeGifts.parentState = state
            let storeGiftsSize = self.storeGifts.update(
                transition: transition,
                component: AnyComponent(
                    GiftStoreContentComponent(
                        context: component.context,
                        resaleGiftsContext: component.resaleContext,
                        theme: environment.theme,
                        strings: environment.strings,
                        dateTimeFormat: environment.dateTimeFormat,
                        safeInsets: UIEdgeInsets(),
                        statusBarHeight: contentHeight - 62.0,
                        navigationHeight: 0.0,
                        overNavigationContainer: self,
                        starsContext: component.context.starsContext!,
                        peerId: component.context.account.peerId,
                        gift: component.genericGift,
                        isPlain: true,
                        confirmPurchaseImmediately: true,
                        starsTopUpOptions: component.starsTopUpOptions,
                        scrollToTop: {},
                        controller: environment.controller,
                        completion: { [weak self] uniqueGift in
                            guard let self, let component = self.component, let controller = self.environment?.controller() as? SelectCraftGiftScreen, let navigationController = controller.navigationController else {
                                return
                            }
                            let giftItem = GiftItem(gift: uniqueGift, reference: .slug(slug: uniqueGift.slug))
                            component.selectGift(giftItem)
                            component.dismiss()
                                    
                            navigationController.view.addSubview(ConfettiView(frame: navigationController.view.bounds))
                            
                            Queue.mainQueue().after(1.0) {
                                component.craftContext.reload()
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
            )
            let storeGiftsFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: storeGiftsSize)
            if let storeGiftsView = self.storeGifts.view as? GiftStoreContentComponent.View {
                if storeGiftsView.superview == nil {
                    self.insertSubview(storeGiftsView, at: 0)
                }
                transition.setFrame(view: storeGiftsView, frame: storeGiftsFrame)
                
                storeGiftsView.updateScrolling(bounds: CGRect(origin: .zero, size: availableSize), transition: .immediate)
            }
            contentHeight += storeGiftsSize.height
            contentHeight += 90.0
                        
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let craftContext: CraftGiftsContext
    let resaleContext: ResaleGiftsContext
    let gift: StarGift.UniqueGift
    let genericGift: StarGift.Gift
    let selectedGiftIds: Set<Int64>
    let starsTopUpOptions: Signal<[StarsTopUpOption]?, NoError>
    let selectGift: (GiftItem) -> Void
    
    init(
        context: AccountContext,
        craftContext: CraftGiftsContext,
        resaleContext: ResaleGiftsContext,
        gift: StarGift.UniqueGift,
        genericGift: StarGift.Gift,
        selectedGiftIds: Set<Int64>,
        starsTopUpOptions: Signal<[StarsTopUpOption]?, NoError>,
        selectGift: @escaping (GiftItem) -> Void
    ) {
        self.context = context
        self.craftContext = craftContext
        self.resaleContext = resaleContext
        self.gift = gift
        self.genericGift = genericGift
        self.selectedGiftIds = selectedGiftIds
        self.starsTopUpOptions = starsTopUpOptions
        self.selectGift = selectGift
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let boundsUpdated = ActionSlot<ResizableSheetComponentEnvironment.BoundsUpdate>()
                        
        return { context in
            let component = context.component
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else {
                    if let controller = controller() {
                        controller.dismiss(completion: nil)
                    }
                }
            }
            
            let theme = environment.theme
                        
            let backgroundColor = environment.theme.list.modalPlainBackgroundColor
            
            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(
                        SelectGiftPageContent(
                            context: component.context,
                            craftContext: component.craftContext,
                            resaleContext: component.resaleContext,
                            gift: component.gift,
                            genericGift: component.genericGift,
                            selectedGiftIds: component.selectedGiftIds,
                            starsTopUpOptions: component.starsTopUpOptions,
                            selectGift: component.selectGift,
                            dismiss: {
                                dismiss(true)
                            },
                            boundsUpdated: boundsUpdated
                        )
                    ),
                    titleItem: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_Craft_Select_Title, font: Font.semibold(17.0), textColor: environment.theme.actionSheet.primaryTextColor)))
                    ),
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    rightItem: nil,
                    bottomItem: nil,
                    backgroundColor: .color(backgroundColor),
                    isFullscreen: false,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        },
                        boundsUpdated: boundsUpdated
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
                        
            return context.availableSize
        }
    }
}

final class SelectCraftGiftScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        craftContext: CraftGiftsContext,
        resaleContext: ResaleGiftsContext,
        gift: StarGift.UniqueGift,
        genericGift: StarGift.Gift,
        selectedGiftIds: Set<Int64>,
        starsTopUpOptions: Signal<[StarsTopUpOption]?, NoError>,
        selectGift: @escaping (GiftItem) -> Void
    ) {
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                craftContext: craftContext,
                resaleContext: resaleContext,
                gift: gift,
                genericGift: genericGift,
                selectedGiftIds: selectedGiftIds,
                starsTopUpOptions: starsTopUpOptions,
                selectGift: selectGift
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            return true
        })
    }
    
    public func dismissAnimated() {
        self.dismissAllTooltips()
        
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

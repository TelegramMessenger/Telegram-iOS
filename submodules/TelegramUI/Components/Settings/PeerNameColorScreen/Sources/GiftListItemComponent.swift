import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import GiftItemComponent
import PlainButtonComponent
import TelegramPresentationData
import AccountContext
import TabSelectorComponent
import CollectionTabItemComponent
import LottieComponent
import MultilineTextComponent
import BalancedTextComponent
import GiftLoadingShimmerView

final class GiftListItemComponent: Component {
    enum Subject {
        case profile
        case name
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let subject: Subject
    let gifts: [StarGift.UniqueGift]
    let starGifts: [StarGift]
    let selectedId: Int64?
    let selectionUpdated: (StarGift.UniqueGift) -> Void
    let onTabChange: () -> Void
    let tag: AnyObject?
    let updated: (ComponentTransition) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        subject: Subject,
        gifts: [StarGift.UniqueGift],
        starGifts: [StarGift],
        selectedId: Int64?,
        selectionUpdated: @escaping (StarGift.UniqueGift) -> Void,
        onTabChange: @escaping () -> Void,
        tag: AnyObject?,
        updated: @escaping (ComponentTransition) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.subject = subject
        self.gifts = gifts
        self.starGifts = starGifts
        self.selectedId = selectedId
        self.selectionUpdated = selectionUpdated
        self.onTabChange = onTabChange
        self.tag = tag
        self.updated = updated
    }
    
    static func ==(lhs: GiftListItemComponent, rhs: GiftListItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.gifts != rhs.gifts {
            return false
        }
        if lhs.starGifts != rhs.starGifts {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        return true
    }
    
    final class View: UIView, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private let tabSelector = ComponentView<Empty>()
        
        private var selectedGiftId: Int64 = 0
        private var resaleGiftsContexts: [Int64: ResaleGiftsContext] = [:]
        private var resaleGiftsState: ResaleGiftsContext.State?
        private var resaleGiftsDisposable = MetaDisposable()
        
        private let emptyResultsAnimation = ComponentView<Empty>()
        private let emptyResultsText = ComponentView<Empty>()
        private let emptyResultsAction = ComponentView<Empty>()
        
        private let loadingView = GiftLoadingShimmerView()
        
        private var giftItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private(set) var visibleBounds: CGRect?
        
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
        private var component: GiftListItemComponent?
        private var state: EmptyComponentState?
        
        private var isUpdating: Bool = false
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.resaleGiftsDisposable.dispose()
        }
        
        func updateVisibleBounds(_ bounds: CGRect) {
            self.visibleBounds = bounds
            if !self.isUpdating {
                self.state?.updated()
            }
        }
        
        func loadMore() -> Bool {
            guard self.selectedGiftId != 0 else {
                return false
            }
            if let resaleGiftsContext = self.resaleGiftsContexts[self.selectedGiftId] {
                resaleGiftsContext.loadMore()
            }
            return true
        }
                
        func setSelectedGift(id: Int64) {
            guard let component = self.component, self.selectedGiftId != id else {
                return
            }
            
            let previousGiftId = self.selectedGiftId
            self.selectedGiftId = id
            
            if id == 0 {
                self.resaleGiftsState = nil
                self.resaleGiftsDisposable.set(nil)
            } else {
                if previousGiftId == 0 {
                    component.onTabChange()
                }
                
                let resaleGiftsContext: ResaleGiftsContext
                if let current = self.resaleGiftsContexts[id] {
                    resaleGiftsContext = current
                } else {
                    resaleGiftsContext = ResaleGiftsContext(account: component.context.account, giftId: id)
                    self.resaleGiftsContexts[id] = resaleGiftsContext
                }
                
                var isFirstTime = true
                self.resaleGiftsDisposable.set((resaleGiftsContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    self.resaleGiftsState = state
                    if !self.isUpdating {
                        let transition: ComponentTransition = isFirstTime ? .easeInOut(duration: 0.25) : .immediate
                        component.updated(transition)
                    }
                    isFirstTime = false
                }))
            }
            
            if !self.isUpdating {
                let transition: ComponentTransition = .easeInOut(duration: 0.25)
                component.updated(transition)
            }
        }
                
        func update(component: GiftListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                  
            let sideInset: CGFloat = self.selectedGiftId != 0 ? 18.0 : 16.0
            let edgeInset: CGFloat = 16.0
            var topInset: CGFloat = edgeInset
            let columnSpacing: CGFloat = self.selectedGiftId != 0 ? 14.0 : 10.0
            let rowSpacing: CGFloat = 10.0
            let itemsInRow = 3
            
            var tabSelectorItems: [TabSelectorComponent.Item] = []
            tabSelectorItems.append(TabSelectorComponent.Item(
                id: AnyHashable(Int64(0)),
                title: component.strings.ProfileColorSetup_MyGifts
            ))
            
            for gift in component.starGifts {
                guard case let .generic(gift) = gift, let title = gift.title else {
                    continue
                }
                tabSelectorItems.append(TabSelectorComponent.Item(
                    id: AnyHashable(gift.id),
                    content: .component(AnyComponent(
                        CollectionTabItemComponent(
                            context: component.context,
                            icon: .collection(gift.file),
                            title: title,
                            theme: component.theme
                        )
                    )),
                    isReorderable: false,
                    contextAction: nil
                ))
            }
            
            let tabSelectorSize = self.tabSelector.update(
                transition: transition,
                component: AnyComponent(TabSelectorComponent(
                    context: component.context,
                    colors: TabSelectorComponent.Colors(
                        foreground: component.theme.list.itemSecondaryTextColor,
                        selection: component.theme.list.itemSecondaryTextColor.withMultipliedAlpha(0.15),
                        simple: true
                    ),
                    theme: component.theme,
                    customLayout: TabSelectorComponent.CustomLayout(
                        font: Font.medium(14.0),
                        spacing: 2.0
                    ),
                    items: tabSelectorItems,
                    selectedId: AnyHashable(self.selectedGiftId),
                    reorderItem: nil,
                    setSelectedId: { [weak self] id in
                        guard let self, let idValue = id.base as? Int64 else {
                            return
                        }
                        self.setSelectedGift(id: idValue)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 14.0 * 2.0, height: 50.0)
            )
            if let tabSelectorView = self.tabSelector.view {
                if tabSelectorView.superview == nil {
                    tabSelectorView.alpha = 1.0
                    self.insertSubview(tabSelectorView, at: 0)
                }
                transition.setFrame(view: tabSelectorView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - tabSelectorSize.width) / 2.0), y: topInset), size: tabSelectorSize))
                
                topInset += tabSelectorSize.height + 16.0
            }
            
            var effectiveGifts: [StarGift.UniqueGift] = []
            var isLoading = false
            if self.selectedGiftId == 0 {
                effectiveGifts = component.gifts
            } else if let resaleGiftsState = self.resaleGiftsState {
                var uniqueGifts: [StarGift.UniqueGift] = []
                for gift in resaleGiftsState.gifts {
                    if case let .unique(uniqueGift) = gift {
                        if case let .peerId(peerId) = uniqueGift.owner, component.context.account.peerId == peerId {
                            continue
                        }
                        uniqueGifts.append(uniqueGift)
                    }
                }
                effectiveGifts = uniqueGifts
                
                if effectiveGifts.isEmpty, case .loading = resaleGiftsState.dataState {
                    isLoading = true
                }
            }
            
            let rowsCount = Int(ceil(CGFloat(effectiveGifts.count) / CGFloat(itemsInRow)))
            let itemWidth = floorToScreenPixels((availableSize.width - sideInset * 2.0 - columnSpacing * CGFloat(itemsInRow - 1)) / CGFloat(itemsInRow))
            let itemHeight: CGFloat = self.selectedGiftId == 0 ? itemWidth : 154.0
            var validIds: [AnyHashable] = []
            var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: CGSize(width: itemWidth, height: itemHeight))
            
            var contentHeight = topInset + edgeInset + itemHeight * CGFloat(rowsCount) + rowSpacing * CGFloat(rowsCount - 1)

            let fadeTransition: ComponentTransition = .easeInOut(duration: 0.25)
            if self.selectedGiftId == 0 && effectiveGifts.isEmpty {
                let emptyTextSpacing: CGFloat = 16.0
                let emptyAnimationHeight: CGFloat = 100.0
                
                let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "Style")
                    )),
                    environment: {},
                    containerSize: CGSize(width: emptyAnimationHeight, height: emptyAnimationHeight)
                )
                
 
                let emptyText: String
                switch component.subject {
                case .profile:
                    emptyText = component.strings.ProfileColorSetup_NoProfileGiftsPlaceholder
                case .name:
                    emptyText = component.strings.ProfileColorSetup_NoNameGiftsPlaceholder
                }
                
                let emptyResultsTextSize = self.emptyResultsText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        BalancedTextComponent(
                            text: .plain(NSAttributedString(string: emptyText, font: Font.regular(13.0), textColor: component.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude)
                )
                
                if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== component.theme {
                    self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: component.theme.list.itemAccentColor)!, component.theme)
                }
                
                let buttonAttributedString = NSMutableAttributedString(string: component.strings.ProfileColorSetup_BrowseGiftsForPurchase, font: Font.regular(15.0), textColor: component.theme.list.itemAccentColor, paragraphAlignment: .center)
                if let range = buttonAttributedString.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                    buttonAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: buttonAttributedString.string))
                }
                
                let emptyResultsActionSize = self.emptyResultsAction.update(
                    transition: .immediate,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: AnyComponent(MultilineTextComponent(
                                text: .plain(buttonAttributedString),
                                horizontalAlignment: .center,
                                maximumNumberOfLines: 0
                            )),
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                if case let .generic(gift) = component.starGifts.first {
                                    self.setSelectedGift(id: gift.id)
                                }
                            },
                            animateScale: false
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 3.0, height: 50.0)
                )
      
                let emptyTotalHeight = emptyResultsAnimationSize.height + emptyTextSpacing + emptyResultsTextSize.height + emptyTextSpacing + emptyResultsActionSize.height
                let emptyAnimationY = topInset
                
                let emptyResultsAnimationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - emptyResultsAnimationSize.width) / 2.0), y: emptyAnimationY), size: emptyResultsAnimationSize)
                let emptyResultsTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - emptyResultsTextSize.width) / 2.0), y: emptyResultsAnimationFrame.maxY + emptyTextSpacing), size: emptyResultsTextSize)
                let emptyResultsActionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - emptyResultsActionSize.width) / 2.0), y: emptyResultsTextFrame.maxY + emptyTextSpacing), size: emptyResultsActionSize)
                
                if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.addSubview(view)
                        view.playOnce()
                    }
                    view.frame = emptyResultsAnimationFrame
                }
                if let view = self.emptyResultsText.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.addSubview(view)
                    }
                    view.frame = emptyResultsTextFrame
                }
                if let view = self.emptyResultsAction.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.addSubview(view)
                    }
                    view.frame = emptyResultsActionFrame
                }
                
                contentHeight = topInset + emptyTotalHeight + 21.0
            } else {
                if let view = self.emptyResultsAnimation.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
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
            
            
            var index: Int32 = 0
            for gift in effectiveGifts {
                var isVisible = false
                if let visibleBounds = self.visibleBounds, visibleBounds.intersects(itemFrame) {
                    isVisible = true
                }
                if isVisible {
                    let id = gift.id
                    let itemId = AnyHashable(id)
                    validIds.append(itemId)
                    
                    var itemTransition = transition
                    let visibleItem: ComponentView<Empty>
                    if let current = self.giftItems[itemId] {
                        visibleItem = current
                    } else {
                        visibleItem = ComponentView()
                        self.giftItems[itemId] = visibleItem
                        itemTransition = .immediate
                    }
                                        
                    let subject: GiftItemComponent.Subject = .uniqueGift(
                        gift: gift,
                        price: self.selectedGiftId != 0 ? "# \(presentationStringsFormattedNumber(Int32(gift.resellAmounts?.first(where: { $0.currency == .stars })?.amount.value ?? 0), presentationData.dateTimeFormat.groupingSeparator))" : nil
                    )
                    
                    var ribbon: GiftItemComponent.Ribbon?
                    if self.selectedGiftId != 0 {
                        var ribbonColor: GiftItemComponent.Ribbon.Color = .blue
                        for attribute in gift.attributes {
                            if case let .backdrop(_, _, innerColor, outerColor, _, _, _) = attribute {
                                ribbonColor = .custom(outerColor, innerColor)
                                break
                            }
                        }
                        ribbon = GiftItemComponent.Ribbon(
                            text: "#\(gift.number)",
                            font: .monospaced,
                            color: ribbonColor
                        )
                    }
                    
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(
                            PlainButtonComponent(
                                content: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: component.theme,
                                        strings: presentationData.strings,
                                        peer: nil,
                                        subject: subject,
                                        ribbon: ribbon,
                                        isHidden: false,
                                        isSelected: gift.id == component.selectedId,
                                        mode: self.selectedGiftId != 0 ? .generic : .grid
                                    )
                                ),
                                effectAlignment: .center,
                                action: { [weak self] in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.selectionUpdated(gift)
                                },
                                animateAlpha: false
                            )
                        ),
                        environment: {},
                        containerSize: itemFrame.insetBy(dx: -2.0, dy: -2.0).size
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            if self.loadingView.superview != nil {
                                self.insertSubview(itemView, at: self.subviews.count - 2)
                            } else {
                                self.insertSubview(itemView, at: self.subviews.count - 1)
                            }
                            
                            if !transition.animation.isImmediate {
                                itemView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                                itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame.insetBy(dx: -2.0, dy: -2.0))
                    }
                }
                itemFrame.origin.x += itemFrame.width + columnSpacing
                if itemFrame.maxX > availableSize.width {
                    itemFrame.origin.x = sideInset
                    itemFrame.origin.y += itemFrame.height + rowSpacing
                }
                index += 1
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.giftItems {
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
                self.giftItems.removeValue(forKey: id)
            }
            
            let loadingTransition: ComponentTransition = .easeInOut(duration: 0.25)
            if isLoading {
                if let tabSelectorView = self.tabSelector.view {
                    if self.subviews.last !== tabSelectorView || self.loadingView.superview == nil {
                        self.addSubview(self.loadingView)
                        self.addSubview(tabSelectorView)
                    }
                }
                contentHeight = 568.0
                let loadingSize = CGSize(width: availableSize.width, height: contentHeight)
                self.loadingView.update(size: loadingSize, theme: component.theme, isPlain: true, transition: .immediate)
                transition.setFrame(view: self.loadingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset - 50.0), size: loadingSize))
                loadingTransition.setAlpha(view: self.loadingView, alpha: 1.0)
            } else {
                loadingTransition.setAlpha(view: self.loadingView, alpha: 0.0)
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

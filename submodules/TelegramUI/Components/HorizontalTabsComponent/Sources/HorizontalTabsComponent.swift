import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextWithEntitiesComponent
import TextBadgeComponent
import LiquidLens
import HeaderPanelContainerComponent

private class ReorderingGestureRecognizerTimerTarget: NSObject {
    private let f: () -> Void
    
    init(_ f: @escaping () -> Void) {
        self.f = f
        
        super.init()
    }
    
    @objc func timerEvent() {
        self.f()
    }
}

private final class InternalGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        } else {
            return false
        }
    }
}

private final class ReorderingGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let internalDelegate = InternalGestureRecognizerDelegate()
    
    private let shouldBegin: (CGPoint) -> Bool
    private let began: (CGPoint) -> Void
    private let ended: () -> Void
    private let moved: (CGFloat) -> Void
    
    private var initialLocation: CGPoint?
    private var delayTimer: Foundation.Timer?
    
    var currentLocation: CGPoint?
    
    init(shouldBegin: @escaping (CGPoint) -> Bool, began: @escaping (CGPoint) -> Void, ended: @escaping () -> Void, moved: @escaping (CGFloat) -> Void) {
        self.shouldBegin = shouldBegin
        self.began = began
        self.ended = ended
        self.moved = moved
        
        super.init(target: nil, action: nil)
        
        self.delegate = self.internalDelegate
    }
    
    override func reset() {
        super.reset()
        
        self.initialLocation = nil
        self.delayTimer?.invalidate()
        self.delayTimer = nil
        self.currentLocation = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        guard let location = touches.first?.location(in: self.view) else {
            self.state = .failed
            return
        }
        
        if self.state == .possible {
            if self.delayTimer == nil {
                if !self.shouldBegin(location) {
                    self.state = .failed
                    return
                }
                self.initialLocation = location
                let timer = Foundation.Timer(timeInterval: 0.2, target: ReorderingGestureRecognizerTimerTarget { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.delayTimer = nil
                    strongSelf.state = .began
                    strongSelf.began(location)
                }, selector: #selector(ReorderingGestureRecognizerTimerTarget.timerEvent), userInfo: nil, repeats: false)
                self.delayTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            } else {
                self.state = .failed
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.delayTimer?.invalidate()
        
        if self.state == .began || self.state == .changed {
            self.ended()
        }
        
        self.state = .failed
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if self.state == .began || self.state == .changed {
            self.delayTimer?.invalidate()
            self.ended()
            self.state = .failed
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        guard let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) else {
            return
        }
        let offset = location.x - initialLocation.x
        self.currentLocation = location
        
        if self.delayTimer != nil {
            if abs(offset) > 4.0 {
                self.delayTimer?.invalidate()
                self.state = .failed
                return
            }
        } else {
            if self.state == .began || self.state == .changed {
                self.state = .changed
                self.moved(offset)
            }
        }
    }
}


public final class HorizontalTabsComponent: Component {
    public final class Tab: Equatable {
        public typealias Id = AnyHashable
        
        public struct Badge: Equatable {
            public var title: String
            public var isAccent: Bool
            
            public init(title: String, isAccent: Bool) {
                self.title = title
                self.isAccent = isAccent
            }
        }
        
        public struct Title: Equatable {
            public let text: String
            public let entities: [MessageTextEntity]
            public let enableAnimations: Bool
            
            public init(text: String, entities: [MessageTextEntity], enableAnimations: Bool) {
                self.text = text
                self.entities = entities
                self.enableAnimations = enableAnimations
            }
        }
        
        public enum Content: Equatable {
            case title(Title)
            case custom(AnyComponent<Empty>)
        }
        
        public let id: AnyHashable
        public let content: Content
        public let badge: Badge?
        public let action: () -> Void
        public let contextAction: ((ContextExtractedContentContainingView, ContextGesture?) -> Void)?
        public let deleteAction: (() -> Void)?
        
        public init(id: AnyHashable, content: Content, badge: Badge?, action: @escaping () -> Void, contextAction: ((ContextExtractedContentContainingView, ContextGesture?) -> Void)?, deleteAction: (() -> Void)?) {
            self.id = id
            self.content = content
            self.badge = badge
            self.action = action
            self.contextAction = contextAction
            self.deleteAction = deleteAction
        }
        
        public static func ==(lhs: Tab, rhs: Tab) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.content != rhs.content {
                return false
            }
            if lhs.badge != rhs.badge {
                return false
            }
            if (lhs.contextAction == nil) != (rhs.contextAction == nil) {
                return false
            }
            if (lhs.deleteAction == nil) != (rhs.deleteAction == nil) {
                return false
            }
            return true
        }
    }
    
    public enum Layout {
        case fit
        case fill
    }
    
    public let context: AccountContext?
    public let theme: PresentationTheme
    public let tabs: [Tab]
    public let selectedTab: Tab.Id?
    public let isEditing: Bool
    public let layout: Layout
    public let liftWhileSwitching: Bool
    
    public init(
        context: AccountContext?,
        theme: PresentationTheme,
        tabs: [Tab],
        selectedTab: Tab.Id?,
        isEditing: Bool,
        layout: Layout = .fill,
        liftWhileSwitching: Bool = true
    ) {
        self.context = context
        self.theme = theme
        self.tabs = tabs
        self.selectedTab = selectedTab
        self.isEditing = isEditing
        self.layout = layout
        self.liftWhileSwitching = liftWhileSwitching
    }
    
    public static func ==(lhs: HorizontalTabsComponent, rhs: HorizontalTabsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.tabs != rhs.tabs {
            return false
        }
        if lhs.selectedTab != rhs.selectedTab {
            return false
        }
        if lhs.isEditing != rhs.isEditing {
            return false
        }
        if lhs.layout != rhs.layout {
            return false
        }
        if lhs.liftWhileSwitching != rhs.liftWhileSwitching {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct LayoutData {
        var size: CGSize
        var selectedItemFrame: CGRect
        
        init(size: CGSize, selectedItemFrame: CGRect) {
            self.size = size
            self.selectedItemFrame = selectedItemFrame
        }
    }
    
    private final class ItemView {
        var frame: CGRect = CGRect()
        var selectionFrame: CGRect = CGRect()
        let regularView = ComponentView<Empty>()
        let selectedView = ComponentView<Empty>()
        
        init() {
        }
    }
    
    public final class View: UIView, UIScrollViewDelegate, HeaderPanelContainerChildView {
        private let lensView: LiquidLensView
        private let scrollView: ScrollView
        private let selectedScrollView: UIView
        private var itemViews: [Tab.Id: ItemView] = [:]
        
        private var ignoreScrolling: Bool = false
        private var tabSwitchFraction: CGFloat = 0.0
        private var isDraggingTabs: Bool = false
        private var temporaryLiftTimer: Foundation.Timer?
        private var didTapOnAnItem: Bool = false
        private var didTapOnAnItemTimer: Foundation.Timer?
        
        private var tapRecognizer: UITapGestureRecognizer?
        
        private var reorderingGesture: ReorderingGestureRecognizer?
        private var reorderingItem: AnyHashable?
        private var reorderingItemPosition: (initial: CGFloat, offset: CGFloat)?
        private var reorderingAutoScrollAnimator: ConstantDisplayLinkAnimator?
        private var initialReorderedItemIds: [AnyHashable]?
        public private(set) var reorderedItemIds: [AnyHashable]?
        
        private var layoutData: LayoutData?
        
        private var component: HorizontalTabsComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.lensView = LiquidLensView(kind: .noContainer)
            self.scrollView = ScrollView()
            
            self.selectedScrollView = UIView()
            self.selectedScrollView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = false
            self.scrollView.scrollsToTop = false
            self.scrollView.clipsToBounds = true
            self.scrollView.delegate = self
            
            self.scrollView.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
                guard let self else {
                    return false
                }
                return self.scrollView.contentOffset.x > .ulpOfOne
            }
            
            self.addSubview(self.lensView)
            
            self.lensView.contentView.addSubview(self.scrollView)
            self.lensView.selectedContentView.addSubview(self.selectedScrollView)
            /*self.lensView.onUpdatedIsAnimating = { [weak self] _ in
                guard let self else {
                    return
                }
                self.alpha = self.lensView.isAnimating ? 1.0 : 0.7
            }*/
            /*self.lensView.isLiftedAnimationCompleted = { [weak self] in
                guard let self else {
                    return
                }
                if let temporaryLiftTimer = self.temporaryLiftTimer {
                    let _ = temporaryLiftTimer
                    /*self.temporaryLiftTimer = nil
                    temporaryLiftTimer.invalidate()
                    if !self.isUpdating {
                        self.state?.updated(transition: .spring(duration: 0.5))
                    }*/
                }
            }*/
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:)))
            self.tapRecognizer = tapRecognizer
            self.addGestureRecognizer(tapRecognizer)
            
            let reorderingGesture = ReorderingGestureRecognizer(shouldBegin: { [weak self] point in
                guard let self else {
                    return false
                }
                for (_, itemView) in self.itemViews {
                    guard let itemView = itemView.regularView.view else {
                        continue
                    }
                    if itemView.convert(itemView.bounds, to: self).contains(point) {
                        return true
                    }
                }
                return false
            }, began: { [weak self] point in
                guard let self else {
                    return
                }
                self.initialReorderedItemIds = self.reorderedItemIds
                for (id, itemView) in self.itemViews {
                    guard let regularItemView = itemView.regularView.view, let selectedItemView = itemView.selectedView.view else {
                        continue
                    }
                    let itemFrame = regularItemView.convert(regularItemView.bounds, to: self)
                    if itemFrame.contains(point) {
                        HapticFeedback().impact()
                        
                        self.reorderingItem = id
                        regularItemView.frame = itemFrame
                        selectedItemView.frame = itemFrame
                        
                        self.reorderingAutoScrollAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
                            guard let self, let currentLocation = self.reorderingGesture?.currentLocation else {
                                return
                            }
                            let edgeWidth: CGFloat = 20.0
                            if currentLocation.x <= edgeWidth {
                                var contentOffset = self.scrollView.contentOffset
                                contentOffset.x = max(0.0, contentOffset.x - 3.0)
                                self.scrollView.setContentOffset(contentOffset, animated: false)
                            } else if currentLocation.x >= self.bounds.width - edgeWidth {
                                var contentOffset = self.scrollView.contentOffset
                                contentOffset.x = max(0.0, min(self.scrollView.contentSize.width - self.scrollView.bounds.width, contentOffset.x + 3.0))
                                self.scrollView.setContentOffset(contentOffset, animated: false)
                            }
                        })
                        self.reorderingAutoScrollAnimator?.isPaused = false
                        self.addSubview(regularItemView)
                        self.addSubview(selectedItemView)
                        
                        self.reorderingItemPosition = (regularItemView.frame.minX, 0.0)
                        self.state?.updated(transition: .easeInOut(duration: 0.25))
                        
                        return
                    }
                }
            }, ended: { [weak self] in
                guard let self, let reorderingItem = self.reorderingItem else {
                    return
                }
                
                if let itemView = self.itemViews[reorderingItem], let regularItemView = itemView.regularView.view, let selectedItemView = itemView.selectedView.view {
                    let projectedItemFrame = regularItemView.convert(regularItemView.bounds, to: self.scrollView)
                    regularItemView.frame = projectedItemFrame
                    selectedItemView.frame = projectedItemFrame
                    self.scrollView.addSubview(regularItemView)
                    self.selectedScrollView.addSubview(selectedItemView)
                }
                
                /*if strongSelf.currentParams?.canReorderAllChats == false, let firstItem = strongSelf.reorderedItemIds?.first, case .filter = firstItem {
                    strongSelf.reorderedItemIds = strongSelf.initialReorderedItemIds
                    strongSelf.presentPremiumTip?()
                }*/
                
                self.reorderingItem = nil
                self.reorderingItemPosition = nil
                self.reorderingAutoScrollAnimator?.invalidate()
                self.reorderingAutoScrollAnimator = nil
                
                self.state?.updated(transition: .easeInOut(duration: 0.25))
            }, moved: { [weak self] offset in
                guard let self, let reorderingItem = self.reorderingItem else {
                    return
                }
                
                let minIndex = 0
                if let reorderingItemView = self.itemViews[reorderingItem], let regularItemView = reorderingItemView.regularView.view, let _ = reorderingItemView.selectedView.view, let (initial, _) = self.reorderingItemPosition, let reorderedItemIds = self.reorderedItemIds, let currentItemIndex = reorderedItemIds.firstIndex(of: reorderingItem) {
                    
                    for (id, otherItemView) in self.itemViews {
                        guard let itemIndex = reorderedItemIds.firstIndex(of: id) else {
                            continue
                        }
                        guard let otherRegularItemView = otherItemView.regularView.view else {
                            continue
                        }
                        if id != reorderingItem {
                            let itemFrame = otherRegularItemView.convert(otherRegularItemView.bounds, to: self)
                            if regularItemView.frame.intersects(itemFrame) {
                                let targetIndex: Int
                                if regularItemView.frame.midX < itemFrame.midX {
                                    targetIndex = max(minIndex, itemIndex - 1)
                                } else {
                                    targetIndex = max(minIndex, min(reorderedItemIds.count - 1, itemIndex))
                                }
                                if targetIndex != currentItemIndex {
                                    HapticFeedback().tap()
                                    
                                    var updatedReorderedItemIds = reorderedItemIds
                                    if targetIndex > currentItemIndex {
                                        updatedReorderedItemIds.insert(reorderingItem, at: targetIndex + 1)
                                        updatedReorderedItemIds.remove(at: currentItemIndex)
                                    } else {
                                        updatedReorderedItemIds.remove(at: currentItemIndex)
                                        updatedReorderedItemIds.insert(reorderingItem, at: targetIndex)
                                    }
                                    self.reorderedItemIds = updatedReorderedItemIds
                                    
                                    self.state?.updated(transition: .easeInOut(duration: 0.25))
                                }
                                break
                            }
                        }
                    }
                    
                    self.reorderingItemPosition = (initial, offset)
                }
                
                self.state?.updated(transition: .immediate)
            })
            self.reorderingGesture = reorderingGesture
            self.addGestureRecognizer(reorderingGesture)
            reorderingGesture.isEnabled = false
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func setOverlayContainerView(overlayContainerView: UIView) {
            self.lensView.setLiftedContainer(view: overlayContainerView)
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return self.scrollView.hitTest(self.convert(point, to: self.scrollView), with: event)
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                let point = recognizer.location(in: self)
                for (id, itemView) in self.itemViews {
                    if self.scrollView.convert(itemView.selectionFrame, to: self).contains(point) {
                        if let tab = component.tabs.first(where: { $0.id == id }) {
                            self.didTapOnAnItem = true
                            self.didTapOnAnItemTimer?.invalidate()
                            self.didTapOnAnItemTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.didTapOnAnItem = false
                            })
                            tab.action()
                        }
                    }
                }
            }
        }
        
        public func updateTabSwitchFraction(fraction: CGFloat, isDragging: Bool, transition: ComponentTransition) {
            self.tabSwitchFraction = -fraction
            self.isDraggingTabs = isDragging
            self.state?.updated(transition: transition, isLocal: true)
            
            /*if self.isDraggingTabs != isDragging {
                self.isDraggingTabs = isDragging
                
                if !isDragging {
                    self.temporaryLiftTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false, block: { [weak self] timer in
                        guard let self else {
                            return
                        }
                        if self.temporaryLiftTimer === timer {
                            self.temporaryLiftTimer = nil
                            self.state?.updated(transition: .spring(duration: 0.5))
                        }
                    })
                } else {
                    self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                }
            }*/
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            self.updateScrolling(transition: .immediate)
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let layoutData = self.layoutData else {
                return
            }
            var isLifted = self.temporaryLiftTimer != nil
            if !component.liftWhileSwitching {
                isLifted = false
            }
            if #available(iOS 26.0, *) {
            } else {
                isLifted = false
            }
            self.lensView.update(size: CGSize(width: layoutData.size.width - 3.0 * 2.0, height: layoutData.size.height - 3.0 * 2.0), selectionOrigin: CGPoint(x:  -self.scrollView.contentOffset.x + layoutData.selectedItemFrame.minX, y: 0.0), selectionSize: CGSize(width: layoutData.selectedItemFrame.width, height: layoutData.size.height - 3.0 * 2.0), inset: 0.0, liftedInset: 6.0, isDark: component.theme.overallDarkAppearance, isLifted: isLifted, transition: transition)
            
            transition.setPosition(view: self.selectedScrollView, position: CGRect(origin: CGPoint(x: 3.0, y: 0.0), size: CGSize(width: layoutData.size.width - 3.0 * 2.0, height: layoutData.size.height - 3.0 * 2.0)).center)
            transition.setBounds(view: self.selectedScrollView, bounds: CGRect(origin: CGPoint(x: self.scrollView.contentOffset.x, y: 0.0), size: CGSize(width: layoutData.size.width - 3.0 * 2.0, height: layoutData.size.height - 3.0 * 2.0)))
        }
        
        func update(component: HorizontalTabsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            var shouldFocusOnSelectedTab = self.isDraggingTabs
            
            if component.isEditing {
                if self.reorderedItemIds == nil {
                    self.reorderedItemIds = component.tabs.map(\.id)
                }
            } else {
                self.reorderedItemIds = nil
            }
            
            if self.component?.selectedTab != component.selectedTab {
                self.tabSwitchFraction = 0.0
                if !self.isDraggingTabs {
                    self.temporaryLiftTimer?.invalidate()
                    self.temporaryLiftTimer = nil
                    
                    if !transition.animation.isImmediate && self.didTapOnAnItem {
                        self.temporaryLiftTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.temporaryLiftTimer = nil
                            if !self.isUpdating {
                                self.state?.updated(transition: .easeInOut(duration: 0.2), isLocal: true)
                            }
                        })
                    }
                }
                shouldFocusOnSelectedTab = true
            }
            
            self.component = component
            self.state = state
            
            self.didTapOnAnItem = false
            if let didTapOnAnItemTimer = self.didTapOnAnItemTimer {
                self.didTapOnAnItemTimer = nil
                didTapOnAnItemTimer.invalidate()
            }
            
            self.reorderingGesture?.isEnabled = component.isEditing
            
            let sizeHeight: CGFloat = availableSize.height
            
            let sideInset: CGFloat = 0.0
            
            var validIds: [Tab.Id] = []
            
            var orderedTabs = component.tabs
            if let reorderedItemIds = self.reorderedItemIds {
                orderedTabs.removeAll()
                for id in reorderedItemIds {
                    if let item = component.tabs.first(where: { $0.id == id }) {
                        orderedTabs.append(item)
                    }
                }
                for tab in component.tabs {
                    if !orderedTabs.contains(where: { $0.id == tab.id }) {
                        orderedTabs.append(tab)
                    }
                }
            }
            
            var items: [(tabId: AnyHashable, itemView: ItemView, size: CGSize, itemTransition: ComponentTransition)] = []
            
            for tab in orderedTabs {
                let tabId = tab.id
                validIds.append(tabId)
                
                var itemTransition = transition
                let itemView: ItemView
                if let current = self.itemViews[tabId] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ItemView()
                    self.itemViews[tabId] = itemView
                }
                
                var itemEditing: ItemComponent.Editing?
                if component.isEditing {
                    itemEditing = ItemComponent.Editing(isEditable: true)
                }
                
                let itemSize = itemView.regularView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        context: component.context,
                        theme: component.theme,
                        tab: tab,
                        isSelected: false,
                        editing: itemEditing
                    )),
                    environment: {},
                    containerSize: CGSize(width: 1000.0, height: sizeHeight - 3.0 * 2.0)
                )
                let _ = itemView.selectedView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        context: component.context,
                        theme: component.theme,
                        tab: tab,
                        isSelected: true,
                        editing: itemEditing
                    )),
                    environment: {},
                    containerSize: CGSize(width: 1000.0, height: sizeHeight - 3.0 * 2.0)
                )
                
                items.append((tabId, itemView, itemSize, itemTransition))
            }
            
            var totalContentWidth: CGFloat = sideInset
            for item in items {
                totalContentWidth += item.size.width
            }
            totalContentWidth += sideInset
            
            let scrollContentWidth: CGFloat
            if case .fill = component.layout, totalContentWidth < availableSize.width {
                let regularItemWidth = floor((availableSize.width - 3.0 * 2.0 - sideInset * 2.0) / CGFloat(items.count))
                let lastItemWidth = (availableSize.width - 3.0 * 2.0 - sideInset * 2.0) - regularItemWidth * CGFloat(items.count - 1)
                for i in 0 ..< items.count {
                    let item = items[i]
                    let itemWidth = (i == items.count - 1) ? lastItemWidth : regularItemWidth
                    var itemFrame = CGRect(origin: CGPoint(x: sideInset + regularItemWidth * CGFloat(i) + floor((itemWidth - item.size.width) * 0.5), y: 0.0), size: item.size)
                    if item.tabId == self.reorderingItem, let (initial, offset) = self.reorderingItemPosition {
                        itemFrame.origin = CGPoint(x: initial + offset, y: 3.0 + itemFrame.minY)
                    }
                    item.itemView.frame = itemFrame
                    item.itemView.selectionFrame = CGRect(origin: CGPoint(x: sideInset + regularItemWidth * CGFloat(i), y: 0.0), size: CGSize(width: itemWidth, height: item.size.height))
                }
                
                scrollContentWidth = availableSize.width - 3.0 * 2.0
            } else {
                var contentWidth: CGFloat = sideInset
                for item in items {
                    var itemFrame = CGRect(origin: CGPoint(x: contentWidth - 3.0, y: 0.0), size: item.size)
                    if item.tabId == self.reorderingItem, let (initial, offset) = self.reorderingItemPosition {
                        itemFrame.origin = CGPoint(x: initial + offset, y: 3.0 + itemFrame.minY)
                    }
                    item.itemView.frame = itemFrame
                    item.itemView.selectionFrame = itemFrame
                    item.itemView.selectionFrame.size.width += 3.0
                    contentWidth += item.size.width
                }
                contentWidth += sideInset
                scrollContentWidth = contentWidth
            }
            
            for (tabId, itemView, _, itemTransition) in items {
                let itemFrame = itemView.frame
                
                if let itemRegularView = itemView.regularView.view, let itemSelectedView = itemView.selectedView.view {
                    if itemRegularView.superview == nil {
                        self.scrollView.addSubview(itemRegularView)
                        self.selectedScrollView.addSubview(itemSelectedView)
                        
                        transition.animateAlpha(view: itemRegularView, from: 0.0, to: 1.0)
                        transition.animateScale(view: itemRegularView, from: 0.001, to: 1.0)
                        
                        transition.animateAlpha(view: itemSelectedView, from: 0.0, to: 1.0)
                        transition.animateScale(view: itemSelectedView, from: 0.001, to: 1.0)
                    }
                    itemTransition.setFrame(view: itemRegularView, frame: itemFrame)
                    itemTransition.setFrame(view: itemSelectedView, frame: itemFrame)
                    
                    if tabId == self.reorderingItem {
                        itemTransition.setSublayerTransform(view: itemRegularView, transform: CATransform3DMakeScale(1.2, 1.2, 1.0))
                        itemTransition.setSublayerTransform(view: itemSelectedView, transform: CATransform3DMakeScale(1.2, 1.2, 1.0))
                        itemTransition.setAlpha(view: itemRegularView, alpha: 0.9)
                        itemTransition.setAlpha(view: itemSelectedView, alpha: 0.0)
                    } else {
                        itemTransition.setSublayerTransform(view: itemRegularView, transform: CATransform3DIdentity)
                        itemTransition.setSublayerTransform(view: itemSelectedView, transform: CATransform3DIdentity)
                        itemTransition.setAlpha(view: itemRegularView, alpha: 1.0)
                        itemTransition.setAlpha(view: itemSelectedView, alpha: 1.0)
                    }
                }
            }
            
            var removedIds: [Tab.Id] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    if let itemRegularView = itemView.regularView.view, let itemSelectedView = itemView.selectedView.view {
                        transition.setScale(view: itemRegularView, scale: 0.001)
                        transition.setAlpha(view: itemRegularView, alpha: 0.0, completion: { [weak itemRegularView] _ in
                            itemRegularView?.removeFromSuperview()
                        })
                        transition.setScale(view: itemSelectedView, scale: 0.001)
                        transition.setAlpha(view: itemSelectedView, alpha: 0.0, completion: { [weak itemSelectedView] _ in
                            itemSelectedView?.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removedIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            var selectedItemFrame: CGRect?
            if let selectedTab = component.selectedTab {
                for i in 0 ..< component.tabs.count {
                    if component.tabs[i].id == selectedTab {
                        if let itemView = self.itemViews[component.tabs[i].id] {
                            var selectedItemFrameValue = itemView.selectionFrame
                            if selectedTab == self.reorderingItem, let itemSuperview = itemView.regularView.view?.superview {
                                selectedItemFrameValue = itemSuperview.convert(itemView.selectionFrame, to: self.scrollView)
                            }
                            
                            var pendingItemFrame: CGRect?
                            if self.tabSwitchFraction != 0.0 {
                                if self.tabSwitchFraction > 0.0 && i != component.tabs.count - 1 {
                                    if let nextItemView = self.itemViews[component.tabs[i + 1].id] {
                                        pendingItemFrame = nextItemView.selectionFrame
                                    }
                                } else if self.tabSwitchFraction < 0.0 && i != 0 {
                                    if let previousItemView = self.itemViews[component.tabs[i - 1].id] {
                                        pendingItemFrame = previousItemView.selectionFrame
                                    }
                                }
                            }
                            if let pendingItemFrame {
                                let fraction = abs(self.tabSwitchFraction)
                                selectedItemFrameValue.origin.x = selectedItemFrameValue.minX * (1.0 - fraction) + pendingItemFrame.minX * fraction
                                selectedItemFrameValue.size.width = selectedItemFrameValue.width * (1.0 - fraction) + pendingItemFrame.width * fraction
                            }
                            
                            selectedItemFrame = selectedItemFrameValue
                        }
                        break
                    }
                }
            }
            
            let contentSize = CGSize(width: scrollContentWidth, height: sizeHeight - 3.0 * 2.0)
            
            let sizeWidth: CGFloat
            switch component.layout {
            case .fill:
                sizeWidth = availableSize.width
            case .fit:
                sizeWidth = min(availableSize.width, scrollContentWidth + 3.0 * 2.0)
            }
            
            let size = CGSize(width: sizeWidth, height: sizeHeight)
            
            self.layoutData = LayoutData(
                size: size,
                selectedItemFrame: selectedItemFrame ?? CGRect()
            )
            
            self.ignoreScrolling = true
            let scrollViewFrame = CGRect(origin: CGPoint(x: 3.0, y: 0.0), size: CGSize(width: size.width - 3.0 * 2.0, height: size.height - 3.0 * 2.0))
            transition.setPosition(view: self.scrollView, position: scrollViewFrame.center)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            
            var scrollViewBounds = CGRect(origin: self.scrollView.bounds.origin, size: scrollViewFrame.size)
            if shouldFocusOnSelectedTab || self.scrollView.bounds.size != scrollViewBounds.size {
                if shouldFocusOnSelectedTab, let selectedItemFrame {
                    let scrollLookahead: CGFloat = 100.0
                    
                    if scrollViewBounds.minX + scrollViewBounds.width - scrollLookahead < selectedItemFrame.maxX {
                        scrollViewBounds.origin.x = selectedItemFrame.maxX - scrollViewBounds.width + scrollLookahead
                    }
                    if scrollViewBounds.minX > selectedItemFrame.minX - scrollLookahead {
                        scrollViewBounds.origin.x = selectedItemFrame.minX - scrollLookahead
                    }
                    if scrollViewBounds.origin.x + scrollViewBounds.width > contentSize.width {
                        scrollViewBounds.origin.x = contentSize.width - scrollViewBounds.width
                    }
                    if scrollViewBounds.origin.x < 0.0 {
                        scrollViewBounds.origin.x = 0.0
                    }
                }
                transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
            }
            
            self.scrollView.layer.cornerRadius = (size.height - 3.0 * 2.0) * 0.5
            self.selectedScrollView.layer.cornerRadius = (size.height - 3.0 * 2.0) * 0.5
            
            transition.setFrame(view: self.lensView, frame: CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: CGSize(width: size.width - 3.0 * 2.0, height: size.height - 3.0 * 2.0)))
            self.lensView.clipsToBounds = true
            self.lensView.layer.cornerRadius = (size.height - 3.0 * 2.0) * 0.5
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ItemComponent: Component {
    struct Editing: Equatable {
        var isEditable: Bool
        
        init(isEditable: Bool) {
            self.isEditable = isEditable
        }
    }
    
    let context: AccountContext?
    let theme: PresentationTheme
    let tab: HorizontalTabsComponent.Tab
    let isSelected: Bool
    let editing: Editing?
    
    init(context: AccountContext?, theme: PresentationTheme, tab: HorizontalTabsComponent.Tab, isSelected: Bool, editing: Editing?) {
        self.context = context
        self.theme = theme
        self.tab = tab
        self.isSelected = isSelected
        self.editing = editing
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.tab != rhs.tab {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let extractedContainerView: ContextExtractedContentContainingView
        let containerView: ContextControllerSourceView
        
        var titleContent: ComponentView<Empty>?
        var customContent: ComponentView<Empty>?
        var badge: ComponentView<Empty>?
        var deleteIcon: (button: HighlightTrackingButton, icon: UIImageView)?
        
        var tapRecognizer: UITapGestureRecognizer?
        
        var component: ItemComponent?
        
        override init(frame: CGRect) {
            self.extractedContainerView = ContextExtractedContentContainingView()
            self.containerView = ContextControllerSourceView()
            
            super.init(frame: frame)
            
            //self.extractedContainerView.contentView.addSubview(self.extractedBackgroundNode)
            
            self.containerView.addSubview(self.extractedContainerView)
            self.containerView.targetViewForActivationProgress = self.extractedContainerView.contentView
            self.addSubview(self.containerView)
            
            self.containerView.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    return
                }
                component.tab.contextAction?(self.extractedContainerView, gesture)
            }
            
            self.extractedContainerView.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
                guard let self, let component else {
                    return
                }
                let _ = component
                
                /*if isExtracted, let theme = strongSelf.theme {
                    strongSelf.extractedBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: theme.contextMenu.backgroundColor)
                }
                transition.updateAlpha(node: strongSelf.extractedBackgroundNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                    if !isExtracted {
                        self?.extractedBackgroundNode.image = nil
                    }
                })*/
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateIsShaking(animated: Bool) {
            guard let component = self.component else {
                return
            }
            
            if component.editing != nil {
                if self.layer.animation(forKey: "shaking_position") == nil {
                    let degreesToRadians: (_ x: CGFloat) -> CGFloat = { x in
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
                    
                    self.layer.add(position, forKey: "shaking_position")
                    self.layer.add(transform, forKey: "shaking_rotation")
                }
            } else if self.layer.animation(forKey: "shaking_position") != nil {
                if let presentationLayer = self.layer.presentation() {
                    let transition: ComponentTransition = .easeInOut(duration: 0.1)
                    if presentationLayer.position != self.layer.position {
                        transition.animatePosition(layer: self.layer, from: CGPoint(x: presentationLayer.position.x - self.layer.position.x, y: presentationLayer.position.y - self.layer.position.y), to: CGPoint(), additive: true)
                    }
                    if !CATransform3DIsIdentity(presentationLayer.transform) {
                        transition.setTransform(layer: self.layer, transform: CATransform3DIdentity)
                    }
                }
                
                self.layer.removeAnimation(forKey: "shaking_position")
                self.layer.removeAnimation(forKey: "shaking_rotation")
            }
        }
        
        @objc private func deleteButtonPressed() {
            self.component?.tab.deleteAction?()
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            self.containerView.isGestureEnabled = component.editing == nil
            self.tapRecognizer?.isEnabled = component.editing == nil
            
            let sideInset: CGFloat = 16.0
            let badgeSpacing: CGFloat = 5.0
            
            var size = CGSize(width: sideInset, height: availableSize.height)
            
            var titleContentSize: CGSize?
            if case let .title(title) = component.tab.content {
                let titleContent: ComponentView<Empty>
                if let current = self.titleContent {
                    titleContent = current
                } else {
                    titleContent = ComponentView()
                    self.titleContent = titleContent
                }
                
                let font = Font.medium(15.0)
                
                let rawAttributedString = ChatTextInputStateText(text: title.text, attributes: title.entities.compactMap { entity -> ChatTextInputStateTextAttribute? in
                    if case let .CustomEmoji(_, fileId) = entity.type {
                        return ChatTextInputStateTextAttribute(type: .customEmoji(stickerPack: nil, fileId: fileId, enableAnimation: title.enableAnimations), range: entity.range)
                    }
                    return nil
                }).attributedText()
                
                let titleString = NSMutableAttributedString(attributedString: rawAttributedString)
                titleString.addAttributes([
                    .font: font,
                    .foregroundColor: component.theme.chat.inputPanel.panelControlColor
                ], range: NSRange(location: 0, length: titleString.length))
                
                titleContentSize = titleContent.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context?.animationCache,
                        animationRenderer: component.context?.animationRenderer,
                        placeholderColor: component.theme.chat.inputPanel.panelControlColor.withMultipliedAlpha(0.1),
                        text: .plain(titleString),
                        displaysAsynchronously: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 300.0, height: 100.0)
                )
            } else if let titleContent = self.titleContent {
                self.titleContent = nil
                titleContent.view?.removeFromSuperview()
            }
            
            var customContentSize: CGSize?
            if case let .custom(custom) = component.tab.content {
                let customContent: ComponentView<Empty>
                if let current = self.customContent {
                    customContent = current
                } else {
                    customContent = ComponentView()
                    self.customContent = customContent
                }
                
                customContentSize = customContent.update(
                    transition: transition,
                    component: custom,
                    environment: {},
                    containerSize: CGSize(width: 300.0, height: 100.0)
                )
            } else if let customContent = self.customContent {
                self.customContent = nil
                customContent.view?.removeFromSuperview()
            }
            
            if let titleContentSize {
                size.width += titleContentSize.width
            }
            if let customContentSize {
                size.width += customContentSize.width
            }
            
            if let badgeData = component.tab.badge, component.tab.deleteAction == nil {
                let badge: ComponentView<Empty>
                var badgeTransition = transition
                if let current = self.badge {
                    badge = current
                } else {
                    badgeTransition = badgeTransition.withAnimation(.none)
                    badge = ComponentView()
                    self.badge = badge
                }
                let badgeSize = badge.update(
                    transition: badgeTransition,
                    component: AnyComponent(TextBadgeComponent(
                        text: badgeData.title,
                        font: Font.medium(12.0),
                        background: badgeData.isAccent ? component.theme.list.itemCheckColors.fillColor : component.theme.chatList.unreadBadgeInactiveBackgroundColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        insets: UIEdgeInsets(top: 1.0, left: 5.0, bottom: 2.0, right: 5.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                size.width += badgeSpacing
                let badgeFrame = CGRect(origin: CGPoint(x: size.width, y: floorToScreenPixels((size.height - badgeSize.height) * 0.5)), size: badgeSize)
                if let badgeView = badge.view {
                    if badgeView.superview == nil {
                        self.extractedContainerView.contentView.addSubview(badgeView)
                        transition.animateAlpha(view: badgeView, from: 0.0, to: 1.0)
                        transition.animateScale(view: badgeView, from: 0.001, to: 1.0)
                    }
                    badgeTransition.setFrame(view: badgeView, frame: badgeFrame)
                }
                size.width += badgeSize.width - 2.0
            } else if let badge = self.badge {
                self.badge = nil
                if let badgeView = badge.view {
                    transition.setFrame(view: badgeView, frame: badgeView.bounds.size.centered(around: CGPoint(x: size.width + sideInset - badgeView.bounds.width * 0.5, y: size.height * 0.5)))
                    transition.setScale(view: badgeView, scale: 0.001)
                    transition.setAlpha(view: badgeView, alpha: 0.0, completion: { [weak badgeView] _ in
                        badgeView?.removeFromSuperview()
                    })
                }
            }
            
            if component.tab.deleteAction != nil {
                let deleteIcon: (button: HighlightTrackingButton, icon: UIImageView)
                if let current = self.deleteIcon {
                    deleteIcon = current
                } else {
                    deleteIcon = (HighlightTrackingButton(), UIImageView())
                    self.deleteIcon = deleteIcon
                    deleteIcon.button.addSubview(deleteIcon.icon)
                    deleteIcon.icon.image = generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setStrokeColor(UIColor.white.cgColor)
                        context.setLineWidth(1.33)
                        context.setLineCap(.round)
                        context.move(to: CGPoint(x: 1.0, y: 1.0))
                        context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
                        context.strokePath()
                        context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
                        context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
                        context.strokePath()
                    })?.withRenderingMode(.alwaysTemplate)
                    deleteIcon.button.addTarget(self, action: #selector(self.deleteButtonPressed), for: .touchUpInside)
                }
                deleteIcon.icon.tintColor = component.theme.chat.inputPanel.panelControlColor
                if let image = deleteIcon.icon.image {
                    let deleteButtonFrame = CGRect(origin: CGPoint(x: size.width + 2.0, y: 0.0), size: CGSize(width: image.size.width + 6.0 * 2.0, height: size.height))
                    let deleteIconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((deleteButtonFrame.width - image.size.width) * 0.5), y: floorToScreenPixels((deleteButtonFrame.height - image.size.height) * 0.5)), size: image.size)
                    if deleteIcon.button.superview == nil {
                        self.addSubview(deleteIcon.button)
                        deleteIcon.button.frame = deleteButtonFrame
                        deleteIcon.icon.frame = deleteIconFrame
                        transition.animateAlpha(view: deleteIcon.button, from: 0.0, to: 1.0)
                        transition.animateScale(view: deleteIcon.button, from: 0.001, to: 1.0)
                    }
                    transition.setFrame(view: deleteIcon.button, frame: deleteButtonFrame)
                    transition.setFrame(view: deleteIcon.icon, frame: deleteIconFrame)
                    size.width += deleteButtonFrame.width - 3.0
                }
            } else if let deleteIcon = self.deleteIcon {
                self.deleteIcon = nil
                let (button, _) = deleteIcon
                transition.setScale(view: button, scale: 0.001)
                transition.setAlpha(view: button, alpha: 0.0, completion: { [weak button] _ in
                    button?.removeFromSuperview()
                })
            }
            
            size.width += sideInset
            
            if let titleView = self.titleContent?.view, let titleContentSize {
                let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((size.height - titleContentSize.height) * 0.5)), size: titleContentSize)
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.extractedContainerView.contentView.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            if let customView = self.customContent?.view, let customContentSize {
                let customFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((size.height - customContentSize.height) * 0.5)), size: customContentSize)
                if customView.superview == nil {
                    customView.layer.anchorPoint = CGPoint()
                    self.extractedContainerView.contentView.addSubview(customView)
                }
                transition.setFrame(view: customView, frame: customFrame)
            }
            
            transition.setFrame(view: self.extractedContainerView, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: self.extractedContainerView.contentView, frame: CGRect(origin: CGPoint(), size: size))
            
            let extractedBackgroundFrame = CGRect(origin: CGPoint(), size: size)
            
            self.extractedContainerView.contentRect = CGRect(origin: CGPoint(x: extractedBackgroundFrame.minX, y: 0.0), size: CGSize(width: extractedBackgroundFrame.width, height: size.height))
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(), size: size))
            
            self.updateIsShaking(animated: !transition.animation.isImmediate)
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import TelegramPresentationData
import HorizontalTabsComponent
import GlassBackgroundComponent
import EdgeEffect

final class StarsTransactionsPanelContainerEnvironment: Equatable {
    let isScrollable: Bool
    
    init(
        isScrollable: Bool
    ) {
        self.isScrollable = isScrollable
    }

    static func ==(lhs: StarsTransactionsPanelContainerEnvironment, rhs: StarsTransactionsPanelContainerEnvironment) -> Bool {
        if lhs.isScrollable != rhs.isScrollable {
            return false
        }
        return true
    }
}

final class StarsTransactionsPanelEnvironment: Equatable {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let containerInsets: UIEdgeInsets
    let isScrollable: Bool
    let isCurrent: Bool
    let externalScrollBounds: CGRect?
    let externalBottomOffset: CGFloat?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        containerInsets: UIEdgeInsets,
        isScrollable: Bool,
        isCurrent: Bool,
        externalScrollBounds: CGRect? = nil,
        externalBottomOffset: CGFloat? = nil
    ) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.containerInsets = containerInsets
        self.isScrollable = isScrollable
        self.isCurrent = isCurrent
        self.externalScrollBounds = externalScrollBounds
        self.externalBottomOffset = externalBottomOffset
    }

    static func ==(lhs: StarsTransactionsPanelEnvironment, rhs: StarsTransactionsPanelEnvironment) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.containerInsets != rhs.containerInsets {
            return false
        }
        if lhs.isScrollable != rhs.isScrollable {
            return false
        }
        if lhs.isCurrent != rhs.isCurrent {
            return false
        }
        if lhs.externalScrollBounds != rhs.externalScrollBounds {
            return false
        }
        if lhs.externalBottomOffset != rhs.externalBottomOffset {
            return false
        }
        return true
    }
}

final class StarsTransactionsPanelContainerComponent: Component {
    typealias EnvironmentType = StarsTransactionsPanelContainerEnvironment
    
    struct Item: Equatable {
        let id: AnyHashable
        let title: String
        let panel: AnyComponent<StarsTransactionsPanelEnvironment>

        init(
            id: AnyHashable,
            title: String,
            panel: AnyComponent<StarsTransactionsPanelEnvironment>
        ) {
            self.id = id
            self.title = title
            self.panel = panel
        }
    }

    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let insets: UIEdgeInsets
    let items: [Item]
    let currentPanelUpdated: (AnyHashable, ComponentTransition) -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        insets: UIEdgeInsets,
        items: [Item],
        currentPanelUpdated: @escaping (AnyHashable, ComponentTransition) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.insets = insets
        self.items = items
        self.currentPanelUpdated = currentPanelUpdated
    }
    
    static func ==(lhs: StarsTransactionsPanelContainerComponent, rhs: StarsTransactionsPanelContainerComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    class View: UIView, UIGestureRecognizerDelegate {
        private let edgeEffectView: EdgeEffectView
        private let tabsBackgroundContainer: GlassBackgroundContainerView
        private let tabsBackgroundView: GlassBackgroundView
        private let tabsContainer = ComponentView<Empty>()
        
        private var component: StarsTransactionsPanelContainerComponent?
        private weak var state: EmptyComponentState?
        
        private let clippingView: UIView
        private var visiblePanels: [AnyHashable: ComponentView<StarsTransactionsPanelEnvironment>] = [:]
        private var actualVisibleIds = Set<AnyHashable>()
        private var currentId: AnyHashable?
        private var transitionFraction: CGFloat = 0.0
        private var isDraggingTabs: Bool = false
        private var animatingTransition: Bool = false
        
        override init(frame: CGRect) {
            self.edgeEffectView = EdgeEffectView()
            self.edgeEffectView.isUserInteractionEnabled = false
            self.tabsBackgroundContainer = GlassBackgroundContainerView()
            self.tabsBackgroundView = GlassBackgroundView()

            self.clippingView = UIView()
            self.clippingView.clipsToBounds = true

            super.init(frame: frame)

            self.addSubview(self.clippingView)
            self.addSubview(self.edgeEffectView)
            self.tabsBackgroundContainer.contentView.addSubview(self.tabsBackgroundView)
            self.addSubview(self.tabsBackgroundContainer)

            let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
                guard let self, let component = self.component, let currentId = self.currentId else {
                    return []
                }
                guard let index = component.items.firstIndex(where: { $0.id == currentId }) else {
                    return []
                }
                
                if index == 0 {
                    return .left
                }
                return [.left, .right]
            })
            panRecognizer.delegate = self
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.addGestureRecognizer(panRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        var currentPanelView: UIView? {
            guard let currentId = self.currentId, let panel = self.visiblePanels[currentId] else {
                return nil
            }
            return panel.view
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
                return false
            }
            if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                func cancelContextGestures(view: UIView) {
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
                
                cancelContextGestures(view: self)
                self.isDraggingTabs = true

                //self.animatingTransition = true
            case .changed:
                guard let component = self.component, let currentId = self.currentId else {
                    return
                }
                guard let index = component.items.firstIndex(where: { $0.id == currentId }) else {
                    return
                }
                
                let translation = recognizer.translation(in: self)
                var transitionFraction = translation.x / self.bounds.width
                if index <= 0 {
                    transitionFraction = min(0.0, transitionFraction)
                }
                if index >= component.items.count - 1 {
                    transitionFraction = max(0.0, transitionFraction)
                }
                self.transitionFraction = transitionFraction
                self.state?.updated(transition: .immediate)
            case .cancelled, .ended:
                self.isDraggingTabs = false

                guard let component = self.component, let currentId = self.currentId else {
                    return
                }
                guard let index = component.items.firstIndex(where: { $0.id == currentId }) else {
                    return
                }
                
                let translation = recognizer.translation(in: self)
                let velocity = recognizer.velocity(in: self)
                var directionIsToRight: Bool?
                if abs(velocity.x) > 10.0 {
                    directionIsToRight = velocity.x < 0.0
                } else {
                    if abs(translation.x) > self.bounds.width / 2.0 {
                        directionIsToRight = translation.x > self.bounds.width / 2.0
                    }
                }
                if let directionIsToRight = directionIsToRight {
                    var updatedIndex = index
                    if directionIsToRight {
                        updatedIndex = min(updatedIndex + 1, component.items.count - 1)
                    } else {
                        updatedIndex = max(updatedIndex - 1, 0)
                    }
                    self.currentId = component.items[updatedIndex].id
                }
                self.transitionFraction = 0.0
                
                let transition = ComponentTransition(animation: .curve(duration: 0.35, curve: .spring))
                if let currentId = self.currentId {
                    self.state?.updated(transition: transition)
                    component.currentPanelUpdated(currentId, transition)
                }
                
                self.animatingTransition = false
                //self.currentPaneUpdated?(false)
                
                //self.currentPaneStatusPromise.set(self.currentPane?.node.status ?? .single(nil))
            default:
                break
            }
        }
        
        func updateNavigationMergeFactor(value: CGFloat, transition: ComponentTransition) {
        }
        
        func transferVelocity(_ velocity: CGFloat) {
            if let currentPanelView = self.currentPanelView as? StarsTransactionsListPanelComponent.View {
                currentPanelView.transferVelocity(velocity)
            }
        }
        
        func scrollToTop() -> Bool {
            if let currentPanelView = self.currentPanelView as? StarsTransactionsListPanelComponent.View {
                return currentPanelView.scrollToTop()
            }
            return false
        }
        
        func update(component: StarsTransactionsPanelContainerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StarsTransactionsPanelContainerEnvironment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[StarsTransactionsPanelContainerEnvironment.self].value
            
            self.component = component
            self.state = state
            
            let tabsHeight: CGFloat = 40.0
            let tabsTopInset: CGFloat = component.insets.top + 10.0
            let tabsBottomInset: CGFloat = 16.0
            let tabsSideInset: CGFloat = 16.0 + component.insets.left
            let tabsContainerSize = CGSize(width: availableSize.width - tabsSideInset * 2.0, height: tabsHeight)

            let panelsFrame = CGRect(origin: CGPoint(x: 0.0, y: component.insets.top), size: CGSize(width: availableSize.width, height: availableSize.height - component.insets.top))

            if let currentIdValue = self.currentId, !component.items.contains(where: { $0.id == currentIdValue }) {
                self.currentId = nil
            }
            if self.currentId == nil {
                self.currentId = component.items.first?.id
            }
            
            var visibleIds = Set<AnyHashable>()
            var currentIndex: Int?
            if let currentId = self.currentId {
                visibleIds.insert(currentId)
                
                if let index = component.items.firstIndex(where: { $0.id == currentId }) {
                    currentIndex = index
                    if index != 0 {
                        visibleIds.insert(component.items[index - 1].id)
                    }
                    if index != component.items.count - 1 {
                        visibleIds.insert(component.items[index + 1].id)
                    }
                }
            }
            
            let tabsContainerEffectiveSize = self.tabsContainer.update(
                transition: transition,
                component: AnyComponent(HorizontalTabsComponent(
                    context: nil,
                    theme: component.theme,
                    tabs: component.items.map { item -> HorizontalTabsComponent.Tab in
                        return HorizontalTabsComponent.Tab(
                            id: item.id,
                            content: .title(HorizontalTabsComponent.Tab.Title(text: item.title, entities: [], enableAnimations: false)),
                            badge: nil,
                            action: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if component.items.contains(where: { $0.id == item.id }) {
                                    self.currentId = item.id
                                    let transition = ComponentTransition(animation: .curve(duration: 0.35, curve: .spring))
                                    self.state?.updated(transition: transition)
                                    component.currentPanelUpdated(item.id, transition)
                                }
                            }
                        )
                    },
                    selectedTab: self.currentId,
                    isEditing: false,
                    layout: .fit,
                    liftWhileSwitching: true
                )),
                environment: {},
                containerSize: tabsContainerSize
            )

            let tabContainerFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableSize.width - tabsContainerEffectiveSize.width) / 2.0),
                    y: tabsTopInset
                ),
                size: tabsContainerEffectiveSize
            )

            transition.setFrame(view: self.tabsBackgroundContainer, frame: tabContainerFrame)
            self.tabsBackgroundContainer.update(size: tabContainerFrame.size, isDark: component.theme.overallDarkAppearance, transition: transition)

            transition.setFrame(view: self.tabsBackgroundView, frame: CGRect(origin: CGPoint(), size: tabContainerFrame.size))
            self.tabsBackgroundView.update(size: tabContainerFrame.size, cornerRadius: tabContainerFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: transition)

            if let tabsContainerView = self.tabsContainer.view as? HorizontalTabsComponent.View {
                if tabsContainerView.superview == nil {
                    self.tabsBackgroundView.contentView.addSubview(tabsContainerView)
                    tabsContainerView.setOverlayContainerView(overlayContainerView: self)
                }
                transition.setFrame(view: tabsContainerView, frame: CGRect(origin: CGPoint(), size: tabContainerFrame.size))
                tabsContainerView.updateTabSwitchFraction(fraction: self.transitionFraction, isDragging: self.isDraggingTabs, transition: transition)
            }

            let effectiveTabsHeight = tabsTopInset + tabContainerFrame.height + tabsBottomInset
            let edgeEffectFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: effectiveTabsHeight))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: component.theme.list.blocksBackgroundColor, blur: false, alpha: 1.0, rect: edgeEffectFrame, edge: .top, edgeSize: min(64.0, effectiveTabsHeight), transition: transition)

            let centralPanelFrame = CGRect(origin: CGPoint(), size: availableSize)

            if self.animatingTransition {
                visibleIds = visibleIds.filter({ self.visiblePanels[$0] != nil })
            }
            
            self.actualVisibleIds = visibleIds
            
            for (id, _) in self.visiblePanels {
                visibleIds.insert(id)
            }
                        
            var validIds = Set<AnyHashable>()
            if let currentIndex {
                var anyAnchorOffset: CGFloat = 0.0
                for (id, panel) in self.visiblePanels {
                    guard let itemIndex = component.items.firstIndex(where: { $0.id == id }), let panelView = panel.view else {
                        continue
                    }
                    var itemFrame = centralPanelFrame.offsetBy(dx: self.transitionFraction * availableSize.width, dy: 0.0)
                    if itemIndex < currentIndex {
                        itemFrame.origin.x -= itemFrame.width
                    } else if itemIndex > currentIndex {
                        itemFrame.origin.x += itemFrame.width
                    }
                    
                    anyAnchorOffset = itemFrame.minX - panelView.frame.minX
                    
                    break
                }
                
                for id in visibleIds {
                    guard let itemIndex = component.items.firstIndex(where: { $0.id == id }) else {
                        continue
                    }
                    let panelItem = component.items[itemIndex]
                    
                    var itemFrame = centralPanelFrame.offsetBy(dx: self.transitionFraction * availableSize.width, dy: 0.0)
                    if itemIndex < currentIndex {
                        itemFrame.origin.x -= itemFrame.width
                    } else if itemIndex > currentIndex {
                        itemFrame.origin.x += itemFrame.width
                    }
                        
                    validIds.insert(panelItem.id)
                    
                    let panel: ComponentView<StarsTransactionsPanelEnvironment>
                    var panelTransition = transition
                    var animateInIfNeeded = false
                    if let current = self.visiblePanels[panelItem.id] {
                        panel = current
                        
                        if let panelView = panel.view, !panelView.bounds.isEmpty {
                            var wasHidden = false
                            if abs(panelView.frame.minX - availableSize.width) < .ulpOfOne || abs(panelView.frame.maxX - 0.0) < .ulpOfOne {
                                wasHidden = true
                            }
                            var isHidden = false
                            if abs(itemFrame.minX - availableSize.width) < .ulpOfOne || abs(itemFrame.maxX - 0.0) < .ulpOfOne {
                                isHidden = true
                            }
                            if wasHidden && isHidden {
                                panelTransition = .immediate
                            }
                        }
                    } else {
                        panelTransition = .immediate
                        animateInIfNeeded = true
                        
                        panel = ComponentView()
                        self.visiblePanels[panelItem.id] = panel
                    }
                    
                    let childEnvironment = StarsTransactionsPanelEnvironment(
                        theme: component.theme,
                        strings: component.strings,
                        dateTimeFormat: component.dateTimeFormat,
                        containerInsets: UIEdgeInsets(top: effectiveTabsHeight, left: component.insets.left, bottom: component.insets.bottom, right: component.insets.right),
                        isScrollable: environment.isScrollable,
                        isCurrent: self.currentId == panelItem.id
                    )
                    
                    let _ = panel.update(
                        transition: panelTransition,
                        component: panelItem.panel,
                        environment: {
                            childEnvironment
                        },
                        containerSize: centralPanelFrame.size
                    )
                    if let panelView = panel.view {
                        if panelView.superview == nil {
                            self.clippingView.addSubview(panelView)
                        }
                        
                        panelTransition.setFrame(view: panelView, frame: itemFrame, completion: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            if !self.actualVisibleIds.contains(id) {
                                if let panel = self.visiblePanels[id] {
                                    self.visiblePanels.removeValue(forKey: id)
                                    panel.view?.removeFromSuperview()
                                }
                            }
                        })
                        if animateInIfNeeded && anyAnchorOffset != 0.0 {
                            transition.animatePosition(view: panelView, from: CGPoint(x: -anyAnchorOffset, y: 0.0), to: CGPoint(), additive: true)
                        }
                    }
                }
            }
            
            transition.setPosition(view: self.clippingView, position: panelsFrame.center)
            transition.setBounds(view: self.clippingView, bounds: panelsFrame)
            
            var removeIds: [AnyHashable] = []
            for (id, panel) in self.visiblePanels {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let panelView = panel.view {
                        panelView.removeFromSuperview()
                    }
                }
            }
            for id in removeIds {
                self.visiblePanels.removeValue(forKey: id)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StarsTransactionsPanelContainerEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

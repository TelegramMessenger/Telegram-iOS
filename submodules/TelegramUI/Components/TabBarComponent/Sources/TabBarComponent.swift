import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import MultilineTextComponent
import LottieComponent
import UIKitRuntimeUtils
import BundleIconComponent
import TextBadgeComponent
import LiquidLens
import AppBundle

private final class TabSelectionRecognizer: UIGestureRecognizer {
    private var initialLocation: CGPoint?
    private var currentLocation: CGPoint?
    private var previousLocation: CGPoint?
    private var previousTimestamp: TimeInterval?
    private var currentVelocity: CGPoint = .zero

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }
    
    override func reset() {
        super.reset()
        
        self.initialLocation = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.initialLocation == nil {
            self.initialLocation = touches.first?.location(in: self.view)
        }
        self.currentLocation = self.initialLocation
        
        self.state = .began
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.state = .ended
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.state = .cancelled
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        self.currentLocation = touches.first?.location(in: self.view)
        let currentTimestamp = event.timestamp
        if let previousLocation = self.previousLocation,
           let previousTimestamp = self.previousTimestamp,
           currentTimestamp > previousTimestamp {
            let deltaTime = CGFloat(currentTimestamp - previousTimestamp)
            let deltaX = self.currentLocation!.x - previousLocation.x
            let deltaY = self.currentLocation!.y - previousLocation.y
            self.currentVelocity = CGPoint(
                x: deltaX / deltaTime,
                y: deltaY / deltaTime
            )
        }

        self.previousLocation = self.currentLocation
        self.previousTimestamp = currentTimestamp

        self.state = .changed
    }
    
    func translation(in: UIView?) -> CGPoint {
        if let initialLocation = self.initialLocation, let currentLocation = self.currentLocation {
            return CGPoint(x: currentLocation.x - initialLocation.x, y: currentLocation.y - initialLocation.y)
        }
        return CGPoint()
    }

    func velocity(in view: UIView?) -> CGPoint {
        self.currentVelocity
    }
}

public final class TabBarSearchView: UIView {
    private let backgroundView: GlassBackgroundView
    private let iconView: GlassBackgroundView.ContentImageView
    
    override public init(frame: CGRect) {
        self.backgroundView = GlassBackgroundView()
        self.iconView = GlassBackgroundView.ContentImageView()

        super.init(frame: frame)

        self.addSubview(self.backgroundView)
        self.backgroundView.contentView.addSubview(self.iconView)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(size: CGSize, isDark: Bool, tintColor: GlassBackgroundView.TintColor, iconColor: UIColor, transition: ComponentTransition) { 
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: isDark, tintColor: tintColor, transition: transition)

        if self.iconView.image == nil {
            self.iconView.image = UIImage(bundleImageName: "Navigation/Search")?.withRenderingMode(.alwaysTemplate)
        }
        self.iconView.tintColor = iconColor
        
        if let image = self.iconView.image {
            transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) * 0.5), y: floor((size.height - image.size.height) * 0.5)), size: image.size))
        }
    }
}

public final class TabBarComponent: Component {
    public final class Item: Equatable {
        public let item: UITabBarItem
        public let action: (Bool) -> Void
        public let contextAction: ((ContextGesture, ContextExtractedContentContainingView) -> Void)?
        
        fileprivate var id: AnyHashable {
            return AnyHashable(ObjectIdentifier(self.item))
        }
        
        public init(item: UITabBarItem, action: @escaping (Bool) -> Void, contextAction: ((ContextGesture, ContextExtractedContentContainingView) -> Void)?) {
            self.item = item
            self.action = action
            self.contextAction = contextAction
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.item !== rhs.item {
                return false
            }
            if (lhs.contextAction == nil) != (rhs.contextAction == nil) {
                return false
            }
            return true
        }
    }
    
    public let theme: PresentationTheme
    public let items: [Item]
    public let selectedId: AnyHashable?
    public let isTablet: Bool
    
    public init(
        theme: PresentationTheme,
        items: [Item],
        selectedId: AnyHashable?,
        isTablet: Bool
    ) {
        self.theme = theme
        self.items = items
        self.selectedId = selectedId
        self.isTablet = isTablet
    }
    
    public static func ==(lhs: TabBarComponent, rhs: TabBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        if lhs.isTablet != rhs.isTablet {
            return false
        }
        return true
    }
    
    public final class View: UIView, UITabBarDelegate, UIGestureRecognizerDelegate {
        private let liquidLensView: LiquidLensView
        private let contextGestureContainerView: ContextControllerSourceView
        
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        private var selectedItemViews: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var tabSelectionRecognizer: TabSelectionRecognizer?
        private var itemWithActiveContextGesture: AnyHashable?
        
        private var component: TabBarComponent?
        private weak var state: EmptyComponentState?

        private var selectionGestureState: (startX: CGFloat, currentX: CGFloat)?
        private var overrideSelectedItemId: AnyHashable?
        
        public override init(frame: CGRect) {
            self.liquidLensView = LiquidLensView()
            
            self.contextGestureContainerView = ContextControllerSourceView()
            self.contextGestureContainerView.isGestureEnabled = true
            
            super.init(frame: frame)
            
            if #available(iOS 17.0, *) {
                self.traitOverrides.verticalSizeClass = .compact
                self.traitOverrides.horizontalSizeClass = .compact
            }
            
            self.addSubview(self.contextGestureContainerView)
            
            self.contextGestureContainerView.addSubview(self.liquidLensView)
            let tabSelectionRecognizer = TabSelectionRecognizer(target: self, action: #selector(self.onTabSelectionGesture(_:)))
            self.tabSelectionRecognizer = tabSelectionRecognizer
            self.addGestureRecognizer(tabSelectionRecognizer)
            
            self.contextGestureContainerView.shouldBegin = { [weak self] point in
                guard let self, let component = self.component else {
                    return false
                }
                
                if let itemId = self.item(at: point) {
                    guard let item = component.items.first(where: { $0.id == itemId }) else {
                            return false
                        }
                        if item.contextAction == nil {
                            return false
                        }
                        
                        self.itemWithActiveContextGesture = itemId
                        
                        let startPoint = point
                        self.contextGestureContainerView.contextGesture?.externalUpdated = { [weak self] _, point in
                            guard let self else {
                                return
                            }
                            
                            let dist = sqrt(pow(startPoint.x - point.x, 2.0) + pow(startPoint.y - point.y, 2.0))
                            if dist > 10.0 {
                                self.contextGestureContainerView.contextGesture?.cancel()
                            }
                        }
                        
                        return true
                }

                return false
            }
            self.contextGestureContainerView.customActivationProgress = { _, _ in
            }
            self.contextGestureContainerView.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    return
                }
                guard let itemWithActiveContextGesture = self.itemWithActiveContextGesture else {
                    return
                }
                
                var itemView: ItemComponent.View?
                itemView = self.itemViews[itemWithActiveContextGesture]?.view as? ItemComponent.View
                
                guard let itemView else {
                    return
                }

                if let tabSelectionRecognizer = self.tabSelectionRecognizer {
                    tabSelectionRecognizer.state = .cancelled
                }
                
                guard let item = component.items.first(where: { $0.id == itemWithActiveContextGesture }) else {
                    return
                }
                item.contextAction?(gesture, itemView.contextContainerView)
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            guard let component = self.component else {
                return
            }
            if let index = tabBar.items?.firstIndex(where: { $0 === item }) {
                if index < component.items.count {
                    component.items[index].action(false)
                }
            }
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        @objc private func onTabSelectionGesture(_ recognizer: TabSelectionRecognizer) {
            switch recognizer.state {
            case .began:
                if let itemId = self.item(at: recognizer.location(in: self)), let itemView = self.itemViews[itemId]?.view {
                    let startX = itemView.frame.minX - 4.0
                    self.selectionGestureState = (startX, startX)
                    self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                }
                let location = recognizer.location(in: self)
                self.liquidLensView.beganGesture(location.x)
            case .changed:
                if var selectionGestureState = self.selectionGestureState {
                    selectionGestureState.currentX = selectionGestureState.startX + recognizer.translation(in: self).x
                    self.selectionGestureState = selectionGestureState
                    self.state?.updated(transition: .immediate, isLocal: true)
                    let velocity = recognizer.velocity(in: self)
                    let location = recognizer.location(in: self)
                    self.liquidLensView.changedGesture(velocity.x, location.x)
                }
            case .ended, .cancelled:
                self.selectionGestureState = nil
                if let component = self.component, let itemId = self.item(at: recognizer.location(in: self)) {
                    guard let item = component.items.first(where: { $0.id == itemId }) else {
                        return
                    }
                    self.overrideSelectedItemId = itemId
                    item.action(false)
                }
                self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                self.liquidLensView.endedGesture()
            default:
                break
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        public func frameForItem(at index: Int) -> CGRect? {
            guard let component = self.component else {
                return nil
            }
            if index < 0 || index >= component.items.count {
                return nil
            }
            guard let itemView = self.itemViews[component.items[index].id]?.view else {
                return nil
            }
            return self.convert(itemView.bounds, from: itemView)
        }

        private func item(at point: CGPoint) -> AnyHashable? {
            var closestItem: (AnyHashable, CGFloat)?
            for (id, itemView) in self.itemViews {
                guard let itemView = itemView.view else {
                    continue
                }
                if itemView.frame.contains(point) {
                    return id
                } else {
                    let distance = abs(point.x - itemView.center.x)
                    if let closestItemValue = closestItem {
                        if closestItemValue.1 > distance {
                            closestItem = (id, distance)
                        }
                    } else {
                        closestItem = (id, distance)
                    }
                }
            }
            return closestItem?.0
        }
        
        public override func didMoveToWindow() {
            super.didMoveToWindow()
            
            self.state?.updated()
        }
        
        func update(component: TabBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let innerInset: CGFloat = 4.0
            let availableSize = CGSize(width: min(500.0, availableSize.width), height: availableSize.height)
            
            let previousComponent = self.component
            self.component = component
            self.state = state

            let _ = innerInset
            let _ = availableSize
            let _ = previousComponent
            
            self.overrideUserInterfaceStyle = component.theme.overallDarkAppearance ? .dark : .light

            let itemSize = CGSize(width: floor((availableSize.width - innerInset * 2.0) / CGFloat(component.items.count)), height: 56.0)
            let contentWidth: CGFloat = innerInset * 2.0 + CGFloat(component.items.count) * itemSize.width
            let size = CGSize(width: min(availableSize.width, contentWidth), height: itemSize.height + innerInset * 2.0)

            var validIds: [AnyHashable] = []
            var selectionFrame: CGRect?
            for index in 0 ..< component.items.count {
                let item = component.items[index]
                validIds.append(item.id)
                
                let itemView: ComponentView<Empty>
                var itemTransition = transition
                
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ComponentView()
                    self.itemViews[item.id] = itemView
                }
                
                let selectedItemView: ComponentView<Empty>
                if let current = self.selectedItemViews[item.id] {
                    selectedItemView = current
                } else {
                    selectedItemView = ComponentView()
                    self.selectedItemViews[item.id] = selectedItemView
                }
                
                let isItemSelected: Bool
                if let overrideSelectedItemId = self.overrideSelectedItemId {
                    isItemSelected = overrideSelectedItemId == item.id
                } else {
                    isItemSelected = component.selectedId == item.id
                }
                
                let _ = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        item: item,
                        theme: component.theme,
                        isSelected: false
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                let _ = selectedItemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        item: item,
                        theme: component.theme,
                        isSelected: true
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                
                let itemFrame = CGRect(origin: CGPoint(x: innerInset + CGFloat(index) * itemSize.width, y: floor((size.height - itemSize.height) * 0.5)), size: itemSize)
                if let itemComponentView = itemView.view as? ItemComponent.View, let selectedItemComponentView = selectedItemView.view as? ItemComponent.View {
                    if itemComponentView.superview == nil {
                        itemComponentView.isUserInteractionEnabled = false
                        selectedItemComponentView.isUserInteractionEnabled = false

                        self.liquidLensView.contentView.addSubview(itemComponentView)
                        self.liquidLensView.selectedContentView.addSubview(selectedItemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    itemTransition.setPosition(view: selectedItemComponentView, position: itemFrame.center)
                    itemTransition.setBounds(view: selectedItemComponentView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                    itemTransition.setScale(view: selectedItemComponentView, scale: self.selectionGestureState != nil ? 1.15 : 1.0)
                    
                    if let previousComponent, previousComponent.selectedId != item.id, isItemSelected {
                        itemComponentView.playSelectionAnimation()
                        selectedItemComponentView.playSelectionAnimation()
                    }
                }
                if isItemSelected {
                    selectionFrame = itemFrame
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.view?.removeFromSuperview()
                    self.selectedItemViews[id]?.view?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
                self.selectedItemViews.removeValue(forKey: id)
            }

            transition.setFrame(view: self.contextGestureContainerView, frame: CGRect(origin: CGPoint(), size: size))

            transition.setFrame(view: self.liquidLensView, frame: CGRect(origin: CGPoint(), size: size))
            
            let lensSelection: (x: CGFloat, width: CGFloat)
            if let selectionGestureState = self.selectionGestureState {
                lensSelection = (selectionGestureState.currentX, itemSize.width + innerInset * 2.0)
            } else if let selectionFrame {
                lensSelection = (selectionFrame.minX - innerInset, itemSize.width + innerInset * 2.0)
            } else {
                lensSelection = (0.0, itemSize.width)
            }

            self.liquidLensView.update(size: size, selectionX: lensSelection.x, selectionWidth: lensSelection.width, isDark: component.theme.overallDarkAppearance, isLifted: self.selectionGestureState != nil, transition: transition)

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
    let item: TabBarComponent.Item
    let theme: PresentationTheme
    let isSelected: Bool
    
    init(item: TabBarComponent.Item, theme: PresentationTheme, isSelected: Bool) {
        self.item = item
        self.theme = theme
        self.isSelected = isSelected
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.item != rhs.item {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let contextContainerView: ContextExtractedContentContainingView
        
        private var imageIcon: ComponentView<Empty>?
        private var animationIcon: ComponentView<Empty>?
        private let title = ComponentView<Empty>()
        private var badge: ComponentView<Empty>?
        
        private var component: ItemComponent?
        private weak var state: EmptyComponentState?
        
        private var setImageListener: Int?
        private var setSelectedImageListener: Int?
        private var setBadgeListener: Int?
        
        override init(frame: CGRect) {
            self.contextContainerView = ContextExtractedContentContainingView()
            
            super.init(frame: frame)
            
            self.addSubview(self.contextContainerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            if let component = self.component {
                if let setImageListener = self.setImageListener {
                    component.item.item.removeSetImageListener(setImageListener)
                }
                if let setSelectedImageListener = self.setSelectedImageListener {
                    component.item.item.removeSetSelectedImageListener(setSelectedImageListener)
                }
                if let setBadgeListener = self.setBadgeListener {
                    component.item.item.removeSetBadgeListener(setBadgeListener)
                }
            }
        }
        
        func playSelectionAnimation() {
            if let animationIconView = self.animationIcon?.view as? LottieComponent.View {
                animationIconView.playOnce()
            }
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            
            if previousComponent?.item.item !== component.item.item {
                if let setImageListener = self.setImageListener {
                    self.component?.item.item.removeSetImageListener(setImageListener)
                }
                if let setSelectedImageListener = self.setSelectedImageListener {
                    self.component?.item.item.removeSetSelectedImageListener(setSelectedImageListener)
                }
                if let setBadgeListener = self.setBadgeListener {
                    self.component?.item.item.removeSetBadgeListener(setBadgeListener)
                }
                self.setImageListener = component.item.item.addSetImageListener { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
                self.setSelectedImageListener = component.item.item.addSetSelectedImageListener { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
                self.setBadgeListener = UITabBarItem_addSetBadgeListener(component.item.item) { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
            }
            
            self.component = component
            self.state = state
            
            if let animationName = component.item.item.animationName {
                if let imageIcon = self.imageIcon {
                    self.imageIcon = nil
                    imageIcon.view?.removeFromSuperview()
                }
                
                let animationIcon: ComponentView<Empty>
                var iconTransition = transition
                if let current = self.animationIcon {
                    animationIcon = current
                } else {
                    iconTransition = iconTransition.withAnimation(.none)
                    animationIcon = ComponentView()
                    self.animationIcon = animationIcon
                }
                
                let iconSize = animationIcon.update(
                    transition: iconTransition,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: animationName
                        ),
                        color: component.isSelected ? component.theme.rootController.tabBar.selectedTextColor : component.theme.rootController.tabBar.textColor,
                        placeholderColor: nil,
                        startingPosition: .end,
                        size: CGSize(width: 48.0, height: 48.0),
                        loop: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 48.0, height: 48.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: -4.0), size: iconSize).offsetBy(dx: component.item.item.animationOffset.x, dy: component.item.item.animationOffset.y)
                if let animationIconView = animationIcon.view {
                    if animationIconView.superview == nil {
                        if let badgeView = self.badge?.view {
                            self.contextContainerView.contentView.insertSubview(animationIconView, belowSubview: badgeView)
                        } else {
                            self.contextContainerView.contentView.addSubview(animationIconView)
                        }
                    }
                    iconTransition.setFrame(view: animationIconView, frame: iconFrame)
                }
            } else {
                if let animationIcon = self.animationIcon {
                    self.animationIcon = nil
                    animationIcon.view?.removeFromSuperview()
                }
                
                let imageIcon: ComponentView<Empty>
                var iconTransition = transition
                if let current = self.imageIcon {
                    imageIcon = current
                } else {
                    iconTransition = iconTransition.withAnimation(.none)
                    imageIcon = ComponentView()
                    self.imageIcon = imageIcon
                }
                
                let iconSize = imageIcon.update(
                    transition: iconTransition,
                    component: AnyComponent(Image(
                        image: component.isSelected ? component.item.item.selectedImage : component.item.item.image,
                        tintColor: nil,
                        contentMode: .center
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: 3.0), size: iconSize)
                if let imageIconView = imageIcon.view {
                    if imageIconView.superview == nil {
                        if let badgeView = self.badge?.view {
                            self.contextContainerView.contentView.insertSubview(imageIconView, belowSubview: badgeView)
                        } else {
                            self.contextContainerView.contentView.addSubview(imageIconView)
                        }
                    }
                    iconTransition.setFrame(view: imageIconView, frame: iconFrame)
                }
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.item.item.title ?? " ", font: Font.semibold(10.0), textColor: component.isSelected ? component.theme.rootController.tabBar.selectedTextColor : component.theme.rootController.tabBar.textColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: availableSize.height - 8.0 - titleSize.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.contextContainerView.contentView.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            if let badgeText = component.item.item.badgeValue, !badgeText.isEmpty {
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
                        text: badgeText,
                        font: Font.regular(13.0),
                        background: component.theme.rootController.tabBar.badgeBackgroundColor,
                        foreground: component.theme.rootController.tabBar.badgeTextColor,
                        insets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 1.0, right: 6.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let contentWidth: CGFloat = 25.0
                let badgeFrame = CGRect(origin: CGPoint(x: floor(availableSize.width / 2.0) + contentWidth - badgeSize.width - 1.0, y: 5.0), size: badgeSize)
                if let badgeView = badge.view {
                    if badgeView.superview == nil {
                        self.contextContainerView.contentView.addSubview(badgeView)
                    }
                    badgeTransition.setFrame(view: badgeView, frame: badgeFrame)
                }
            } else if let badge = self.badge {
                self.badge = nil
                badge.view?.removeFromSuperview()
            }
            
            transition.setFrame(view: self.contextContainerView, frame: CGRect(origin: CGPoint(), size: availableSize))
            transition.setFrame(view: self.contextContainerView.contentView, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.contextContainerView.contentRect = CGRect(origin: CGPoint(), size: availableSize)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

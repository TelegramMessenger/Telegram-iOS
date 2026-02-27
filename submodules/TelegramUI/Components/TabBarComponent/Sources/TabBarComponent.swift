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
import SearchBarNode
import TabSelectionRecognizer

public final class NavigationSearchView: UIView {
    private struct Params: Equatable {
        let size: CGSize
        let theme: PresentationTheme
        let strings: PresentationStrings
        let isActive: Bool

        init(size: CGSize, theme: PresentationTheme, strings: PresentationStrings, isActive: Bool) {
            self.size = size
            self.theme = theme
            self.strings = strings
            self.isActive = isActive
        }

        static func ==(lhs: Params, rhs: Params) -> Bool {
            if lhs.size != rhs.size {
                return false
            }
            if lhs.theme !== rhs.theme {
                return false
            }
            if lhs.strings !== rhs.strings {
                return false
            }
            if lhs.isActive != rhs.isActive {
                return false
            }
            return true
        }
    }

    private let action: () -> Void
    private let closeAction: () -> Void

    private let backgroundView: GlassBackgroundView
    private let iconView: UIImageView
    private(set) var searchBarNode: SearchBarNode?
    
    private var close: (background: GlassBackgroundView, icon: UIImageView)?

    private var params: Params?
    
    public init(action: @escaping () -> Void, closeAction: @escaping () -> Void) {
        self.action = action
        self.closeAction = closeAction

        self.backgroundView = GlassBackgroundView()
        self.backgroundView.contentView.clipsToBounds = true
        self.iconView = UIImageView()

        super.init(frame: CGRect())

        self.addSubview(self.backgroundView)
        self.backgroundView.contentView.addSubview(self.iconView)

        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
    }

    @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.action()
        }
    }
    
    @objc private func onCloseTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.closeAction()
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(size: CGSize, theme: PresentationTheme, strings: PresentationStrings, isActive: Bool, transition: ComponentTransition) { 
        let params = Params(size: size, theme: theme, strings: strings, isActive: isActive)
        if self.params == params {
            return
        }
        self.params = params
        self.update(params: params, transition: transition)
    }

    private func update(params: Params, transition: ComponentTransition) {
        let backgroundSize: CGSize
        if params.isActive {
            backgroundSize = CGSize(width: params.size.width - 48.0 - 8.0, height: params.size.height)
        } else {
            backgroundSize = CGSize(width: params.size.width, height: params.size.height)
        }
        
        let previousBackgroundFrame = self.backgroundView.frame
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: backgroundSize))
        let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.25)

        self.backgroundView.update(size: backgroundSize, cornerRadius: backgroundSize.height * 0.5, isDark: params.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)

        if self.iconView.image == nil {
            self.iconView.image = UIImage(bundleImageName: "Navigation/Search")?.withRenderingMode(.alwaysTemplate)
        }
        transition.setTintColor(view: self.iconView, color: params.isActive ? params.theme.rootController.navigationSearchBar.inputIconColor : params.theme.chat.inputPanel.panelControlColor)
        
        if let image = self.iconView.image {
            let imageSize: CGSize
            let iconFrame: CGRect
            if params.isActive {
                let iconFraction: CGFloat = 0.8
                imageSize = CGSize(width: image.size.width * iconFraction, height: image.size.height * iconFraction)
                iconFrame = CGRect(origin: CGPoint(x: 12.0, y: floor((params.size.height - imageSize.height) * 0.5)), size: imageSize)
            } else {
                iconFrame = CGRect(origin: CGPoint(x: floor((backgroundSize.width - image.size.width) * 0.5), y: floor((params.size.height - image.size.height) * 0.5)), size: image.size)
            }
            transition.setPosition(view: self.iconView, position: iconFrame.center)
            transition.setBounds(view: self.iconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
        }

        if params.isActive {
            let searchBarNode: SearchBarNode
            var searchBarNodeTransition = transition
            if let current = self.searchBarNode {
                searchBarNode = current
            } else {
                searchBarNodeTransition = searchBarNodeTransition.withAnimation(.none)
                searchBarNode = SearchBarNode(
                    theme: SearchBarNodeTheme(
                        background: .clear,
                        separator: .clear,
                        inputFill: .clear,
                        primaryText: params.theme.chat.inputPanel.panelControlColor,
                        placeholder: params.theme.chat.inputPanel.inputPlaceholderColor,
                        inputIcon: params.theme.chat.inputPanel.inputControlColor,
                        inputClear: params.theme.chat.inputPanel.panelControlColor,
                        accent: params.theme.chat.inputPanel.panelControlAccentColor,
                        keyboard: params.theme.rootController.keyboardColor
                    ),
                    presentationTheme: params.theme,
                    strings: params.strings,
                    fieldStyle: .inlineNavigation,
                    icon: .loupe,
                    forceSeparator: false,
                    displayBackground: false,
                    cancelText: nil
                )
                searchBarNode.placeholderString = NSAttributedString(string: params.strings.Common_Search, font: Font.regular(17.0), textColor: params.theme.chat.inputPanel.inputPlaceholderColor)
                self.searchBarNode = searchBarNode
                self.backgroundView.contentView.addSubview(searchBarNode.view)
                searchBarNode.view.alpha = 0.0
            }
            let searchBarFrame = CGRect(origin: CGPoint(x: 36.0, y: 0.0), size: CGSize(width: backgroundSize.width - 36.0 - 4.0, height: params.size.height))
            transition.setFrame(view: searchBarNode.view, frame: searchBarFrame)
            searchBarNode.updateLayout(boundingSize: searchBarFrame.size, leftInset: 0.0, rightInset: 0.0, transition: transition.containedViewLayoutTransition)
            alphaTransition.setAlpha(view: searchBarNode.view, alpha: 1.0)
        } else {
            if let searchBarNode = self.searchBarNode {
                self.searchBarNode = nil
                let searchBarNodeView = searchBarNode.view
                alphaTransition.setAlpha(view: searchBarNode.view, alpha: 0.0, completion: { [weak searchBarNodeView] _ in
                    searchBarNodeView?.removeFromSuperview()
                })
            }
        }
        
        if params.isActive {
            let closeFrame = CGRect(origin: CGPoint(x: params.size.width - 48.0, y: 0.0), size: CGSize(width: 48.0, height: 48.0))
            
            let close: (background: GlassBackgroundView, icon: UIImageView)
            var closeTransition = transition
            if let current = self.close {
                close = current
            } else {
                closeTransition = closeTransition.withAnimation(.none)
                close = (GlassBackgroundView(), UIImageView())
                self.close = close
                
                close.icon.image = generateImage(CGSize(width: 40.0, height: 40.0), contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    context.setLineWidth(2.0)
                    context.setLineCap(.round)
                    context.setStrokeColor(UIColor.white.cgColor)
                    
                    context.beginPath()
                    context.move(to: CGPoint(x: 12.0, y: 12.0))
                    context.addLine(to: CGPoint(x: size.width - 12.0, y: size.height - 12.0))
                    context.move(to: CGPoint(x: size.width - 12.0, y: 12.0))
                    context.addLine(to: CGPoint(x: 12.0, y: size.height - 12.0))
                    context.strokePath()
                })?.withRenderingMode(.alwaysTemplate)
                
                close.background.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onCloseTapGesture(_:))))
                
                close.background.contentView.addSubview(close.icon)
                self.insertSubview(close.background, at: 0)
                
                if let image = close.icon.image {
                    close.icon.frame = image.size.centered(in: CGRect(origin: CGPoint(), size: closeFrame.size))
                }
                
                close.background.frame = closeFrame.size.centered(in: previousBackgroundFrame)
                close.background.update(size: close.background.bounds.size, cornerRadius: close.background.bounds.height * 0.5, isDark: params.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: .immediate)
                ComponentTransition.immediate.setScale(view: close.background, scale: 0.001)
            }
            
            close.icon.tintColor = params.theme.chat.inputPanel.panelControlColor
            
            transition.setPosition(view: close.background, position: closeFrame.center)
            transition.setBounds(view: close.background, bounds: CGRect(origin: CGPoint(), size: closeFrame.size))
            transition.setScale(view: close.background, scale: 1.0)
            
            if let image = close.icon.image {
                transition.setFrame(view: close.icon, frame: image.size.centered(in: CGRect(origin: CGPoint(), size: closeFrame.size)))
            }
            
            close.background.update(size: closeFrame.size, cornerRadius: closeFrame.height * 0.5, isDark: params.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: closeTransition)
        } else {
            if let close = self.close {
                self.close = nil
                let closeBackground = close.background
                let closeFrame = CGSize(width: 48.0, height: 48.0).centered(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: params.size))
                transition.setPosition(view: closeBackground, position: closeFrame.center)
                transition.setBounds(view: closeBackground, bounds: CGRect(origin: CGPoint(), size: closeFrame.size))
                closeBackground.update(size: closeFrame.size, cornerRadius: closeFrame.height * 0.5, isDark: params.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
                transition.setScale(view: closeBackground, scale: 0.001, completion: { [weak closeBackground] _ in
                    closeBackground?.removeFromSuperview()
                })
            }
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

    public final class Search: Equatable {
        public let isActive: Bool
        public let activate: () -> Void
        public let deactivate: () -> Void

        public init(isActive: Bool, activate: @escaping () -> Void, deactivate: @escaping () -> Void) {
            self.isActive = isActive
            self.activate = activate
            self.deactivate = deactivate
        }

        public static func ==(lhs: Search, rhs: Search) -> Bool {
            if lhs.isActive != rhs.isActive {
                return false
            }
            return true
        }
    }
    
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let items: [Item]
    public let search: Search?
    public let selectedId: AnyHashable?
    public let outerInsets: UIEdgeInsets
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        items: [Item],
        search: Search?,
        selectedId: AnyHashable?,
        outerInsets: UIEdgeInsets
    ) {
        self.theme = theme
        self.strings = strings
        self.items = items
        self.search = search
        self.selectedId = selectedId
        self.outerInsets = outerInsets
    }
    
    public static func ==(lhs: TabBarComponent, rhs: TabBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.search != rhs.search {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        if lhs.outerInsets != rhs.outerInsets {
            return false
        }
        return true
    }
    
    public final class View: UIView, UITabBarDelegate, UIGestureRecognizerDelegate {
        private let backgroundContainer: GlassBackgroundContainerView
        private let liquidLensView: LiquidLensView
        private let contextGestureContainerView: ContextControllerSourceView
        
        private var measureItemViews: [AnyHashable: ComponentView<Empty>] = [:]
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        private var selectedItemViews: [AnyHashable: ComponentView<Empty>] = [:]

        private var searchView: NavigationSearchView?
        
        private var tabSelectionRecognizer: TabSelectionRecognizer?
        private var itemWithActiveContextGesture: AnyHashable?
        
        private var component: TabBarComponent?
        private weak var state: EmptyComponentState?

        private var selectionGestureState: (startX: CGFloat, currentX: CGFloat, itemWidth: CGFloat, itemId: AnyHashable)?
        private var overrideSelectedItemId: AnyHashable?

        public var currentSearchNode: ASDisplayNode? {
            return self.searchView?.searchBarNode
        }
        
        public override init(frame: CGRect) {
            self.backgroundContainer = GlassBackgroundContainerView()
            self.liquidLensView = LiquidLensView(kind: .externalContainer)
            
            self.contextGestureContainerView = ContextControllerSourceView()
            self.contextGestureContainerView.isGestureEnabled = true
            
            super.init(frame: frame)
            
            if #available(iOS 17.0, *) {
                self.traitOverrides.verticalSizeClass = .compact
                self.traitOverrides.horizontalSizeClass = .compact
            }
            
            self.addSubview(self.backgroundContainer)
            self.backgroundContainer.contentView.addSubview(self.contextGestureContainerView)
            
            self.contextGestureContainerView.addSubview(self.liquidLensView)
            let tabSelectionRecognizer = TabSelectionRecognizer(target: self, action: #selector(self.onTabSelectionGesture(_:)))
            self.tabSelectionRecognizer = tabSelectionRecognizer
            self.contextGestureContainerView.addGestureRecognizer(tabSelectionRecognizer)
            
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
            guard let component = self.component else {
                return
            }
            switch recognizer.state {
            case .began:
                if let search = component.search, search.isActive {
                } else if let itemId = self.item(at: recognizer.location(in: self)), let itemView = self.itemViews[itemId]?.view {
                    let startX = itemView.frame.minX - 4.0
                    self.selectionGestureState = (startX, startX, itemView.bounds.width, itemId)
                    self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                }
            case .changed:
                if let search = component.search, search.isActive {
                } else if var selectionGestureState = self.selectionGestureState {
                    selectionGestureState.currentX = selectionGestureState.startX + recognizer.translation(in: self).x
                    if let itemId = self.item(at: recognizer.location(in: self)) {
                        selectionGestureState.itemId = itemId
                    }
                    self.selectionGestureState = selectionGestureState
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
            case .ended, .cancelled:
                if let search = component.search, search.isActive {
                    search.deactivate()
                } else if let selectionGestureState = self.selectionGestureState {
                    self.selectionGestureState = nil
                    if case .ended = recognizer.state, let component = self.component {
                        guard let item = component.items.first(where: { $0.id == selectionGestureState.itemId }) else {
                            return
                        }
                        self.overrideSelectedItemId = selectionGestureState.itemId
                        item.action(false)
                    }
                    self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
                }
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
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.25)
            let _ = alphaTransition

            let innerInset: CGFloat = 4.0
            let availableSize = CGSize(width: min(500.0, availableSize.width), height: availableSize.height)
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            self.overrideUserInterfaceStyle = component.theme.overallDarkAppearance ? .dark : .light

            let barHeight: CGFloat = 56.0 + innerInset * 2.0

            var availableItemsWidth: CGFloat = availableSize.width - innerInset * 2.0
            if component.search != nil {
                availableItemsWidth -= barHeight + 8.0
            }
            
            var unboundItemWidths: [CGFloat] = []
            
            var validIds: [AnyHashable] = []
            var unboundItemWidthSum: CGFloat = 0.0
            for index in 0 ..< component.items.count {
                let item = component.items[index]
                validIds.append(item.id)
                
                let measureItemView: ComponentView<Empty>
                if let current = self.measureItemViews[item.id] {
                    measureItemView = current
                } else {
                    measureItemView = ComponentView()
                    self.measureItemViews[item.id] = measureItemView
                }
                
                let itemSize = measureItemView.update(
                    transition: .immediate,
                    component: AnyComponent(ItemComponent(
                        item: item,
                        theme: component.theme,
                        isCompact: false,
                        isSelected: false,
                        isUnconstrained: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 56.0)
                )
                
                unboundItemWidths.append(itemSize.width)
                unboundItemWidthSum += itemSize.width
            }
            
            let itemWidths: [CGFloat]
            let totalItemsWidth: CGFloat

            let equalWidth = floorToScreenPixels(availableItemsWidth / CGFloat(component.items.count))
            if unboundItemWidths.allSatisfy({ $0 <= equalWidth }) {
                // All items fit in equal width — use equal widths for optical alignment
                itemWidths = Array(repeating: equalWidth, count: component.items.count)
                totalItemsWidth = equalWidth * CGFloat(component.items.count)
            } else {
                // Some items need more space — use weighted fit
                let itemWeightNorm: CGFloat = availableItemsWidth / unboundItemWidthSum
                var widths: [CGFloat] = []
                var total: CGFloat = 0.0
                for index in 0 ..< component.items.count {
                    let itemWidth = floorToScreenPixels(unboundItemWidths[index] * itemWeightNorm)
                    widths.append(itemWidth)
                    total += itemWidth
                }
                itemWidths = widths
                totalItemsWidth = total
            }

            let itemHeight: CGFloat = 56.0
            let contentWidth: CGFloat = innerInset * 2.0 + totalItemsWidth
            let tabsSize = CGSize(width: min(availableSize.width, contentWidth), height: itemHeight + innerInset * 2.0)

            var selectionFrame: CGRect?
            var nextItemX: CGFloat = innerInset
            for index in 0 ..< component.items.count {
                let item = component.items[index]
                
                let itemSize = CGSize(width: itemWidths[index], height: itemHeight)
                
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
                        isCompact: component.search?.isActive == true,
                        isSelected: false,
                        isUnconstrained: false
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                let _ = selectedItemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        item: item,
                        theme: component.theme,
                        isCompact: component.search?.isActive == true,
                        isSelected: true,
                        isUnconstrained: false
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                
                var itemFrame = CGRect(origin: CGPoint(x: nextItemX, y: floor((tabsSize.height - itemSize.height) * 0.5)), size: itemSize)
                nextItemX += itemSize.width
                if isItemSelected {
                    selectionFrame = itemFrame
                }
                
                if let itemComponentView = itemView.view as? ItemComponent.View, let selectedItemComponentView = selectedItemView.view as? ItemComponent.View {
                    let itemAlphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.25)

                    if itemComponentView.superview == nil {
                        itemComponentView.isUserInteractionEnabled = false
                        selectedItemComponentView.isUserInteractionEnabled = false

                        self.liquidLensView.contentView.addSubview(itemComponentView)
                        self.liquidLensView.selectedContentView.addSubview(selectedItemComponentView)
                    }

                    if let search = component.search, search.isActive {
                        if isItemSelected {
                            itemFrame.origin.x = floor((48.0 - itemSize.width) * 0.5)
                            itemTransition.setAlpha(view: itemComponentView, alpha: 1.0)
                            itemAlphaTransition.setBlur(layer: itemComponentView.layer, radius: 0.0)
                            itemTransition.setAlpha(view: selectedItemComponentView, alpha: 1.0)
                            itemAlphaTransition.setBlur(layer: selectedItemComponentView.layer, radius: 0.0)
                        } else {
                            itemTransition.setAlpha(view: itemComponentView, alpha: 0.0)
                            itemAlphaTransition.setBlur(layer: itemComponentView.layer, radius: 10.0)
                            itemTransition.setAlpha(view: selectedItemComponentView, alpha: 0.0)
                            itemAlphaTransition.setBlur(layer: selectedItemComponentView.layer, radius: 10.0)
                        }
                    } else {
                        itemTransition.setAlpha(view: itemComponentView, alpha: 1.0)
                        itemAlphaTransition.setBlur(layer: itemComponentView.layer, radius: 0.0)
                        itemTransition.setAlpha(view: selectedItemComponentView, alpha: 1.0)
                        itemAlphaTransition.setBlur(layer: selectedItemComponentView.layer, radius: 0.0)
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
                self.measureItemViews.removeValue(forKey: id)
            }
            
            var tabsFrame = CGRect(origin: CGPoint(), size: tabsSize)
            if let search = component.search, search.isActive {
                tabsFrame.size = CGSize(width: 48.0, height: 48.0)
                tabsFrame.origin.y = tabsSize.height - 48.0
                tabsFrame.origin.x = -component.outerInsets.left - tabsFrame.width
            }

            transition.setFrame(view: self.contextGestureContainerView, frame: tabsFrame)
            transition.setFrame(view: self.liquidLensView, frame: CGRect(origin: CGPoint(), size: tabsSize))
            
            var lensSelection: (x: CGFloat, width: CGFloat)
            if let selectionGestureState = self.selectionGestureState {
                lensSelection = (selectionGestureState.currentX, selectionGestureState.itemWidth + innerInset * 2.0)
            } else if let selectionFrame {
                lensSelection = (selectionFrame.minX - innerInset, selectionFrame.width + innerInset * 2.0)
            } else {
                lensSelection = (0.0, 56.0)
            }

            var lensSize: CGSize = tabsSize
            var isLensCollapsed = false
            if let search = component.search, search.isActive {
                isLensCollapsed = true
                lensSize = CGSize(width: 48.0, height: 48.0)
                lensSelection = (0.0, 48.0)
            }
            
            lensSelection.x = max(0.0, min(lensSelection.x, lensSize.width - lensSelection.width))
            
            self.liquidLensView.update(size: lensSize, selectionOrigin: CGPoint(x: lensSelection.x, y: 0.0), selectionSize: CGSize(width: lensSelection.width, height: lensSize.height), inset: 4.0, isDark: component.theme.overallDarkAppearance, isLifted: self.selectionGestureState != nil, isCollapsed: isLensCollapsed, transition: transition)

            var size = tabsSize

            if let search = component.search {
                let searchSize: CGSize
                let searchFrame: CGRect
                if search.isActive {
                    size.width = availableSize.width
                    searchSize = CGSize(width: availableSize.width, height: 48.0)
                    searchFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - searchSize.height), size: searchSize)
                } else {
                    searchSize = CGSize(width: barHeight, height: barHeight)
                    size.width += barHeight + 8.0
                    searchFrame = CGRect(origin: CGPoint(x: availableSize.width - searchSize.width, y: 0.0), size: searchSize)
                }

                let searchView: NavigationSearchView
                var searchViewTransition = transition
                if let current = self.searchView {
                    searchView = current
                } else {
                    searchViewTransition = searchViewTransition.withAnimation(.none)
                    searchView = NavigationSearchView(
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.search?.activate()
                        },
                        closeAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.search?.deactivate()
                        }
                    )
                    self.searchView = searchView
                    self.backgroundContainer.contentView.addSubview(searchView)
                    searchView.frame = CGRect(origin: CGPoint(x: availableSize.width + 50.0, y: 0.0), size: searchSize)
                }
                searchView.update(size: searchSize, theme: component.theme, strings: component.strings, isActive: search.isActive, transition: searchViewTransition)
                transition.setFrame(view: searchView, frame: searchFrame)
            } else {
                if let searchView = self.searchView {
                    self.searchView = nil
                    transition.setFrame(view: searchView, frame: CGRect(origin: CGPoint(x: availableSize.width + 50.0, y: 0.0), size: searchView.bounds.size), completion: { [weak searchView] completed in
                        guard let searchView, completed else {
                            return
                        }
                        searchView.removeFromSuperview()
                    })
                }
            }

            transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundContainer.update(size: size, isDark: component.theme.overallDarkAppearance, transition: transition)

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
    let isCompact: Bool
    let isSelected: Bool
    let isUnconstrained: Bool
    
    init(item: TabBarComponent.Item, theme: PresentationTheme, isCompact: Bool, isSelected: Bool, isUnconstrained: Bool) {
        self.item = item
        self.theme = theme
        self.isCompact = isCompact
        self.isSelected = isSelected
        self.isUnconstrained = isUnconstrained
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.item != rhs.item {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.isCompact != rhs.isCompact {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.isUnconstrained != rhs.isUnconstrained {
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
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.25)

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
                        color: (component.isSelected && !component.isCompact) ? component.theme.rootController.tabBar.selectedTextColor : component.theme.rootController.tabBar.textColor,
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
                alphaTransition.setAlpha(view: titleView, alpha: component.isCompact ? 0.0 : 1.0)
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
                        insets: UIEdgeInsets(top: 0.0, left: 5.0, bottom: 1.0, right: 5.0)
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
                    alphaTransition.setAlpha(view: badgeView, alpha: component.isCompact ? 0.0 : 1.0)
                }
            } else if let badge = self.badge {
                self.badge = nil
                badge.view?.removeFromSuperview()
            }
            
            transition.setFrame(view: self.contextContainerView, frame: CGRect(origin: CGPoint(), size: availableSize))
            transition.setFrame(view: self.contextContainerView.contentView, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.contextContainerView.contentRect = CGRect(origin: CGPoint(), size: availableSize)
            
            if component.isUnconstrained {
                return CGSize(width: titleSize.width + 10.0 * 2.0, height: availableSize.height)
            } else {
                return availableSize
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

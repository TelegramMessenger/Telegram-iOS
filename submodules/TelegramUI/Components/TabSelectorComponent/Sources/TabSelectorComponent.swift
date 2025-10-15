import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import PlainButtonComponent
import MultilineTextWithEntitiesComponent
import TextFormat
import AccountContext
import TelegramPresentationData

public final class TabSelectorComponent: Component {
    public final class TransitionHint {
        public let scrollToEnd: Bool
        
        public init(scrollToEnd: Bool) {
            self.scrollToEnd = scrollToEnd
        }
    }
    
    public final class ItemEnvironment: Equatable {
        public let selectionFraction: CGFloat
        
        init(selectionFraction: CGFloat) {
            self.selectionFraction = selectionFraction
        }
        
        public static func ==(lhs: ItemEnvironment, rhs: ItemEnvironment) -> Bool {
            if lhs.selectionFraction != rhs.selectionFraction {
                return false
            }
            return true
        }
    }
    
    public struct Colors: Equatable {
        public var foreground: UIColor
        public var selection: UIColor
        public var normal: UIColor?
        public var simple: Bool

        public init(
            foreground: UIColor,
            selection: UIColor,
            normal: UIColor? = nil,
            simple: Bool = false
        ) {
            self.foreground = foreground
            self.selection = selection
            self.normal = normal
            self.simple = simple
        }
    }
    
    public struct CustomLayout: Equatable {
        public var font: UIFont
        public var spacing: CGFloat
        public var innerSpacing: CGFloat?
        public var fillWidth: Bool
        public var lineSelection: Bool
        public var verticalInset: CGFloat
        public var allowScroll: Bool
        
        public init(font: UIFont, spacing: CGFloat = 2.0, innerSpacing: CGFloat? = nil, fillWidth: Bool = false, lineSelection: Bool = false, verticalInset: CGFloat = 0.0, allowScroll: Bool = true) {
            self.font = font
            self.spacing = spacing
            self.innerSpacing = innerSpacing
            self.fillWidth = fillWidth
            self.lineSelection = lineSelection
            self.verticalInset = verticalInset
            self.allowScroll = allowScroll
        }
    }
    
    public final class Item: Equatable {
        public enum Content: Equatable {
            case text(String)
            case component(AnyComponent<ItemEnvironment>)
        }
        
        public let id: AnyHashable
        public let content: Content
        public let isReorderable: Bool
        public let contextAction: ((ASDisplayNode, ContextGesture) -> Void)?

        public init(
            id: AnyHashable,
            content: Content,
            isReorderable: Bool = false,
            contextAction: ((ASDisplayNode, ContextGesture) -> Void)? = nil
        ) {
            self.id = id
            self.content = content
            self.isReorderable = isReorderable
            self.contextAction = contextAction
        }
        
        convenience public init(
            id: AnyHashable,
            title: String,
            isReorderable: Bool = false,
            contextAction: ((ASDisplayNode, ContextGesture) -> Void)? = nil
        ) {
            self.init(id: id, content: .text(title), isReorderable: isReorderable, contextAction: contextAction)
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.content != rhs.content {
                return false
            }
            if lhs.isReorderable != rhs.isReorderable {
                return false
            }
            if (lhs.contextAction == nil) != (rhs.contextAction == nil) {
                return false
            }
            return true
        }
    }

    public let context: AccountContext?
    public let colors: Colors
    public let theme: PresentationTheme
    public let customLayout: CustomLayout?
    public let items: [Item]
    public let selectedId: AnyHashable?
    public let reorderItem: ((AnyHashable, AnyHashable) -> Void)?
    public let setSelectedId: (AnyHashable) -> Void
    public let transitionFraction: CGFloat?
    
    public init(
        context: AccountContext? = nil,
        colors: Colors,
        theme: PresentationTheme,
        customLayout: CustomLayout? = nil,
        items: [Item],
        selectedId: AnyHashable?,
        reorderItem: ((AnyHashable, AnyHashable) -> Void)? = nil,
        setSelectedId: @escaping (AnyHashable) -> Void,
        transitionFraction: CGFloat? = nil
    ) {
        self.context = context
        self.colors = colors
        self.theme = theme
        self.customLayout = customLayout
        self.items = items
        self.selectedId = selectedId
        self.reorderItem = reorderItem
        self.setSelectedId = setSelectedId
        self.transitionFraction = transitionFraction
    }
    
    public static func ==(lhs: TabSelectorComponent, rhs: TabSelectorComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.customLayout != rhs.customLayout {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        if (lhs.reorderItem == nil) != (rhs.reorderItem == nil) {
            return false
        }
        if lhs.transitionFraction != rhs.transitionFraction {
            return false
        }
        return true
    }
    
    final class VisibleItem: UIView {
        let action: () -> Void
        let contextAction: (ASDisplayNode, ContextGesture) -> Void
        
        let extractedContainerNode: ContextExtractedContentContainingNode
        let containerNode: ContextControllerSourceNode
        
        let containerButton: UIView
        var extractedBackgroundView: UIImageView?
        
        let title = ComponentView<Empty>()
        
        var item: Item?
        
        var tapGesture: UITapGestureRecognizer?
        var theme: PresentationTheme?
        var size: CGSize?
        var isReordering: Bool = false
        
        init(action: @escaping () -> Void, contextAction: @escaping (ASDisplayNode, ContextGesture) -> Void) {
            self.action = action
            self.contextAction = contextAction
            
            self.extractedContainerNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
            
            self.containerButton = UIView()
            
            super.init(frame: CGRect())
            
            self.extractedContainerNode.contentNode.view.addSubview(self.containerButton)
            
            self.containerNode.addSubnode(self.extractedContainerNode)
            self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
            self.addSubview(self.containerNode.view)
            
            //self.containerButton.addSubview(self.iconContainer)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:)))
            self.tapGesture = tapGesture
            self.containerButton.addGestureRecognizer(tapGesture)
            tapGesture.isEnabled = false
            
            self.containerNode.activated = { [weak self] gesture, _ in
                guard let self else {
                    return
                }
                self.contextAction(self.extractedContainerNode, gesture)
            }
            
            self.extractedContainerNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
                guard let self, let theme = self.theme, let size = self.size else {
                    return
                }
                
                if isExtracted {
                    let extractedBackgroundView: UIImageView
                    if let current = self.extractedBackgroundView {
                        extractedBackgroundView = current
                    } else {
                        extractedBackgroundView = UIImageView(image: generateStretchableFilledCircleImage(diameter: size.height, color: theme.contextMenu.backgroundColor))
                        self.extractedBackgroundView = extractedBackgroundView
                        self.extractedContainerNode.contentNode.view.insertSubview(extractedBackgroundView, at: 0)
                        extractedBackgroundView.frame = self.extractedContainerNode.contentNode.bounds.insetBy(dx: 0.0, dy: 0.0)
                        extractedBackgroundView.alpha = 0.0
                    }
                    transition.updateAlpha(layer: extractedBackgroundView.layer, alpha: 1.0)
                } else if let extractedBackgroundView = self.extractedBackgroundView {
                    self.extractedBackgroundView = nil
                    let alphaTransition: ContainedViewLayoutTransition
                    if transition.isAnimated {
                        alphaTransition = .animated(duration: 0.18, curve: .easeInOut)
                    } else {
                        alphaTransition = .immediate
                    }
                    alphaTransition.updateAlpha(layer: extractedBackgroundView.layer, alpha: 0.0, completion: { [weak extractedBackgroundView] _ in
                        extractedBackgroundView?.removeFromSuperview()
                    })
                }
            }
            
            self.containerNode.isGestureEnabled = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.action()
            }
        }
        
        private func updateIsShaking(animated: Bool) {
            if self.isReordering {
                if self.containerButton.layer.animation(forKey: "shaking_position") == nil {
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
                    
                    self.containerButton.layer.add(position, forKey: "shaking_position")
                    self.containerButton.layer.add(transform, forKey: "shaking_rotation")
                }
            } else if self.containerButton.layer.animation(forKey: "shaking_position") != nil {
                if let presentationLayer = self.containerButton.layer.presentation() {
                    let transition: ComponentTransition = .easeInOut(duration: 0.1)
                    if presentationLayer.position != self.containerButton.layer.position {
                        transition.animatePosition(layer: self.containerButton.layer, from: CGPoint(x: presentationLayer.position.x - self.containerButton.layer.position.x, y: presentationLayer.position.y - self.containerButton.layer.position.y), to: CGPoint(), additive: true)
                    }
                    if !CATransform3DIsIdentity(presentationLayer.transform) {
                        transition.setTransform(layer: self.containerButton.layer, transform: CATransform3DIdentity)
                    }
                }
                
                self.containerButton.layer.removeAnimation(forKey: "shaking_position")
                self.containerButton.layer.removeAnimation(forKey: "shaking_rotation")
            }
        }
        
        func update(theme: PresentationTheme, size: CGSize, item: Item, isReordering: Bool, transition: ComponentTransition) {
            self.theme = theme
            self.size = size
            self.isReordering = isReordering
            self.item = item
            
            self.containerNode.isGestureEnabled = item.contextAction != nil && !isReordering
            self.tapGesture?.isEnabled = !isReordering
            
            transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: size))
            
            self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            
            self.updateIsShaking(animated: !transition.animation.isImmediate)
        }
    }
    
    public final class View: UIScrollView {
        private var component: TabSelectorComponent?
        private weak var state: EmptyComponentState?
        
        private let selectionView: UIImageView
        private var visibleItems: [AnyHashable: VisibleItem] = [:]
        
        private var didInitiallyScroll = false
        
        private var reorderRecognizer: ReorderGestureRecognizer?
        private weak var reorderingItem: VisibleItem?
        private var reorderingItemPosition: (initial: CGFloat, offset: CGFloat) = (0.0, 0.0)
        
        override init(frame: CGRect) {
            self.selectionView = UIImageView()
            
            super.init(frame: frame)
            
            self.showsVerticalScrollIndicator = false
            self.showsHorizontalScrollIndicator = false
            self.scrollsToTop = false
            self.delaysContentTouches = false
            self.canCancelContentTouches = true
            self.contentInsetAdjustmentBehavior = .never
            self.alwaysBounceVertical = false
            self.clipsToBounds = false
            
            self.addSubview(self.selectionView)
            
            let reorderRecognizer = ReorderGestureRecognizer(
                shouldBegin: { [weak self] point in
                    guard let self, let component = self.component, component.reorderItem != nil else {
                        return (allowed: false, requiresLongPress: false, item: nil)
                    }
                    
                    var item: VisibleItem?
                    for (_, visibleItem) in self.visibleItems {
                        if visibleItem.bounds.contains(self.convert(point, to: visibleItem)) {
                            item = visibleItem
                            break
                        }
                    }
                    
                    if let item, let itemValue = item.item, itemValue.isReorderable {
                        return (allowed: true, requiresLongPress: false, item: item)
                    } else {
                        return (allowed: false, requiresLongPress: false, item: nil)
                    }
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
                    self.moveReorderingItem(distance: distance.x)
                },
                isActiveUpdated: { _ in
                }
            )
            self.reorderRecognizer = reorderRecognizer
            self.addGestureRecognizer(reorderRecognizer)
            reorderRecognizer.isEnabled = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        override public func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
        
        private func setReorderingItem(item: VisibleItem?) {
            self.reorderingItem = item
            if let item {
                self.reorderingItemPosition.initial = item.frame.minX
                self.reorderingItemPosition.offset = 0.0
            } else {
                self.reorderingItemPosition = (0.0, 0.0)
            }
            self.state?.updated(transition: .easeInOut(duration: 0.2))
        }
        
        private func moveReorderingItem(distance: CGFloat) {
            guard let reorderingItem = self.reorderingItem else {
                return
            }
            let previousPosition = self.reorderingItemPosition.initial + self.reorderingItemPosition.offset + reorderingItem.bounds.width * 0.5
            self.reorderingItemPosition.offset = distance
            let updatedPosition = self.reorderingItemPosition.initial + self.reorderingItemPosition.offset + reorderingItem.bounds.width * 0.5
            
            self.state?.updated(transition: .immediate)
            
            if let component = self.component, let reorderItem = component.reorderItem {
                var currentId: AnyHashable?
                var reorderToId: AnyHashable?
                for (id, item) in self.visibleItems {
                    if item === reorderingItem {
                        currentId = id
                        continue
                    }
                    guard let targetItem = item.item else {
                        continue
                    }
                    if !targetItem.isReorderable {
                        continue
                    }
                    if reorderToId != nil {
                        continue
                    }
                    let itemCenter = item.center.x
                    if previousPosition < itemCenter && updatedPosition > itemCenter {
                        reorderToId = id
                    } else if previousPosition > itemCenter && updatedPosition < itemCenter {
                        reorderToId = id
                    }
                }
                if let currentId, let reorderToId {
                    reorderItem(currentId, reorderToId)
                }
            }
        }
        
        public func scrollToStart() {
            self.setContentOffset(.zero, animated: true)
        }
        
        public func scrollToEnd() {
            self.setContentOffset(CGPoint(x: self.contentSize.width - self.bounds.width, y: 0.0), animated: true)
        }
        
        public func frameForItem(_ id: AnyHashable) -> CGRect? {
            if let item = self.visibleItems[id] {
                return item.convert(item.bounds, to: self)
            }
            return nil
        }
        
        func update(component: TabSelectorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let selectionColorUpdated = component.colors.selection != self.component?.colors.selection
           
            self.component = component
            self.state = state
            
            self.reorderRecognizer?.isEnabled = component.reorderItem != nil
            
            let baseHeight: CGFloat = 28.0
            
            var verticalInset: CGFloat = 0.0
            if let customLayout = component.customLayout {
                verticalInset = customLayout.verticalInset * 2.0
            }
            
            var innerInset: CGFloat = component.customLayout?.innerSpacing ?? 12.0
            var spacing: CGFloat = component.customLayout?.spacing ?? 2.0
            
            let itemFont: UIFont
            var isLineSelection = false
            let allowScroll: Bool
            if let customLayout = component.customLayout {
                itemFont = customLayout.font
                isLineSelection = customLayout.lineSelection
                allowScroll = customLayout.allowScroll || component.items.count > 3
            } else {
                itemFont = Font.semibold(14.0)
                allowScroll = true
            }
            
            if selectionColorUpdated {
                if isLineSelection {
                    self.selectionView.image = generateImage(CGSize(width: 5.0, height: 3.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(component.colors.selection.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: 4.0, height: 4.0)))
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - 4.0, y: 0.0), size: CGSize(width: 4.0, height: 4.0)))
                        context.fill(CGRect(x: 2.0, y: 0.0, width: size.width - 4.0, height: 4.0))
                        context.fill(CGRect(x: 0.0, y: 2.0, width: size.width, height: 2.0))
                    })?.resizableImage(withCapInsets: UIEdgeInsets(top: 3.0, left: 3.0, bottom: 0.0, right: 3.0), resizingMode: .stretch)
                } else {
                    self.selectionView.image = generateStretchableFilledCircleImage(diameter: baseHeight, color: component.colors.selection)
                }
            }
            
            var innerContentWidth: CGFloat = 0.0
            
            let selectedIndex = component.items.firstIndex(where: { $0.id == component.selectedId })
            
            var validIds: [AnyHashable] = []
            var index = 0
            var itemViews: [AnyHashable: (VisibleItem, CGSize, ComponentTransition)] = [:]
            
            for item in component.items {
                var itemTransition = transition
                let itemView: VisibleItem
                if let current = self.visibleItems[item.id] {
                    itemView = current
                } else {
                    let itemId = item.id
                    itemView = VisibleItem(action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let item = component.items.first(where: { $0.id == itemId }) else {
                            return
                        }
                        component.setSelectedId(item.id)
                    }, contextAction: { [weak self] sourceNode, gesture in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let item = component.items.first(where: { $0.id == itemId }) else {
                            return
                        }
                        item.contextAction?(sourceNode, gesture)
                    })
                    self.visibleItems[item.id] = itemView
                    itemTransition = itemTransition.withAnimation(.none)
                }
                
                let itemId = item.id
                validIds.append(itemId)
                
                var selectionFraction: CGFloat = 0.0
                if let transitionFraction = component.transitionFraction, let selectedIndex {
                    if item.id == component.selectedId {
                        selectionFraction = 1.0 - abs(transitionFraction)
                    } else {
                        if index == selectedIndex - 1 && transitionFraction < 0.0 {
                            selectionFraction = abs(transitionFraction)
                        } else if index == selectedIndex + 1 && transitionFraction > 0.0 {
                            selectionFraction = abs(transitionFraction)
                        }
                    }
                } else {
                    selectionFraction = item.id == component.selectedId ? 1.0 : 0.0
                }
                
                var useSelectionFraction = isLineSelection
                if case .component = item.content {
                    useSelectionFraction = true
                }
                if let _ = component.colors.normal {
                    useSelectionFraction = true
                }
                
                let itemSize = itemView.title.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        context: component.context,
                        content: item.content,
                        font: itemFont,
                        color: component.colors.foreground,
                        normalColor: component.colors.normal,
                        selectedColor: component.colors.selection,
                        selectionFraction: useSelectionFraction ? selectionFraction : 0.0
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                
                innerContentWidth += itemSize.width
                itemViews[item.id] = (itemView, itemSize, itemTransition)
                index += 1
            }
            
            let estimatedContentWidth = 2.0 * spacing + innerContentWidth + (CGFloat(component.items.count - 1) * (spacing + innerInset))
            if component.customLayout?.fillWidth == true && estimatedContentWidth < availableSize.width && component.items.count > 1 {
                spacing = (availableSize.width - innerContentWidth) / CGFloat(component.items.count + 1) - innerInset * 2.0
            } else if estimatedContentWidth > availableSize.width && !allowScroll {
                spacing = (availableSize.width - innerContentWidth) / CGFloat(component.items.count + 1)
                innerInset = 0.0
            }
            
            var contentWidth: CGFloat = spacing
            var previousBackgroundRect: CGRect?
            var selectedBackgroundRect: CGRect?
            var nextBackgroundRect: CGRect?
            var selectedItemIsReordering = false
            
            for item in component.items {
                guard let (itemView, itemSize, itemTransition) = itemViews[item.id] else {
                    continue
                }
                if contentWidth > spacing {
                    contentWidth += spacing
                }
                let baseItemTitleFrame = CGRect(origin: CGPoint(x: contentWidth + innerInset, y: verticalInset + floor((baseHeight - itemSize.height) * 0.5)), size: itemSize)
                var itemBackgroundRect = CGRect(origin: CGPoint(x: contentWidth, y: verticalInset), size: CGSize(width: innerInset + itemSize.width + innerInset, height: baseHeight))
                let itemTitleFrame = CGRect(origin: CGPoint(x: baseItemTitleFrame.minX - itemBackgroundRect.minX, y: baseItemTitleFrame.minY - itemBackgroundRect.minY), size: baseItemTitleFrame.size)
                contentWidth = itemBackgroundRect.maxX
                
                if self.reorderingItem === itemView {
                    itemBackgroundRect.origin.x = self.reorderingItemPosition.initial + self.reorderingItemPosition.offset
                    if item.id == component.selectedId {
                        selectedItemIsReordering = true
                    }
                }
                
                if item.id == component.selectedId {
                    selectedBackgroundRect = itemBackgroundRect
                }
                if selectedBackgroundRect == nil {
                    previousBackgroundRect = itemBackgroundRect
                } else if nextBackgroundRect == nil, itemBackgroundRect != selectedBackgroundRect {
                    nextBackgroundRect = itemBackgroundRect
                }
                
                if itemView.superview == nil {
                    self.addSubview(itemView)
                }
                
                if let itemTitleView = itemView.title.view {
                    if itemTitleView.superview == nil {
                        itemTitleView.layer.anchorPoint = CGPoint()
                        itemTitleView.isUserInteractionEnabled = false
                        itemView.containerButton.addSubview(itemTitleView)
                    }
                    
                    itemTransition.setPosition(view: itemView, position: itemBackgroundRect.center)
                    itemTransition.setBounds(view: itemView, bounds: CGRect(origin: CGPoint(), size: itemBackgroundRect.size))
                    
                    if self.reorderingItem === itemView {
                        itemTransition.setTransform(view: itemView, transform: CATransform3DMakeScale(1.1, 1.1, 1.0))
                    } else {
                        itemTransition.setTransform(view: itemView, transform: CATransform3DIdentity)
                    }
                    
                    itemView.update(theme: component.theme, size: itemBackgroundRect.size, item: item, isReordering: item.isReorderable && component.reorderItem != nil, transition: itemTransition)
                    
                    itemTransition.setPosition(view: itemTitleView, position: CGPoint(x: itemTitleFrame.minX, y: itemTitleFrame.minY))
                    itemTransition.setBounds(view: itemTitleView, bounds: CGRect(origin: CGPoint(), size: itemTitleFrame.size))
                    
                    var itemAlpha: CGFloat = item.id == component.selectedId || isLineSelection || component.colors.simple ? 1.0 : 0.4
                    if component.reorderItem != nil && !item.isReorderable {
                        itemAlpha *= 0.5
                        itemView.isUserInteractionEnabled = false
                    } else {
                        itemView.isUserInteractionEnabled = true
                    }
                    
                    itemTransition.setAlpha(view: itemTitleView, alpha: itemAlpha)
                }
            }
            contentWidth += spacing
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            if let selectedBackgroundRect {
                self.selectionView.alpha = 1.0
                                
                if isLineSelection {
                    var effectiveBackgroundRect = selectedBackgroundRect
                    if let transitionFraction = component.transitionFraction {
                        if transitionFraction < 0.0 {
                            if let previousBackgroundRect {
                                effectiveBackgroundRect = effectiveBackgroundRect.interpolate(with: previousBackgroundRect, fraction: abs(transitionFraction))
                            }
                        } else if transitionFraction > 0.0 {
                            if let nextBackgroundRect {
                                effectiveBackgroundRect = effectiveBackgroundRect.interpolate(with: nextBackgroundRect, fraction: abs(transitionFraction))
                            }
                        }
                    }
                    
                    var mappedSelectionFrame = effectiveBackgroundRect.insetBy(dx: innerInset, dy: 0.0)
                    mappedSelectionFrame.origin.y = mappedSelectionFrame.maxY + 7.0
                    mappedSelectionFrame.size.height = 3.0
                    transition.setPosition(view: self.selectionView, position: mappedSelectionFrame.center)
                    transition.setBounds(view: self.selectionView, bounds: CGRect(origin: CGPoint(), size: mappedSelectionFrame.size))
                    transition.setTransform(view: self.selectionView, transform: CATransform3DIdentity)
                } else {
                    transition.setPosition(view: self.selectionView, position: selectedBackgroundRect.center)
                    transition.setBounds(view: self.selectionView, bounds: CGRect(origin: CGPoint(), size: selectedBackgroundRect.size))
                    if selectedItemIsReordering {
                        transition.setTransform(view: self.selectionView, transform: CATransform3DMakeScale(1.1, 1.1, 1.0))
                    } else {
                        transition.setTransform(view: self.selectionView, transform: CATransform3DIdentity)
                    }
                }
            } else {
                self.selectionView.alpha = 0.0
            }
            
            let contentSize = CGSize(width: contentWidth, height: baseHeight + verticalInset * 2.0)
            if self.contentSize != contentSize {
                self.contentSize = contentSize
            }
            self.disablesInteractiveTransitionGestureRecognizer = contentWidth > availableSize.width
            
            let size = CGSize(width: min(contentWidth, availableSize.width), height: baseHeight + verticalInset * 2.0)
            
            if self.bounds.width > 0.0 {
                if let hint = transition.userData(TransitionHint.self), hint.scrollToEnd {
                    self.setContentOffset(CGPoint(x: max(0.0, contentSize.width - size.width), y: 0.0), animated: false)
                    self.didInitiallyScroll = true
                } else if let selectedBackgroundRect, !self.didInitiallyScroll {
                    self.scrollRectToVisible(selectedBackgroundRect.insetBy(dx: -spacing, dy: 0.0), animated: false)
                    self.didInitiallyScroll = true
                }
            }
            
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

extension CGRect {
    func interpolate(with other: CGRect, fraction: CGFloat) -> CGRect {
         return CGRect(
            x: self.origin.x * (1.0 - fraction) + (other.origin.x) * fraction,
            y: self.origin.y * (1.0 - fraction) + (other.origin.y) * fraction,
            width: self.size.width * (1.0 - fraction) + (other.size.width) * fraction,
            height: self.size.height * (1.0 - fraction) + (other.size.height) * fraction
         )
     }
}

private final class ItemComponent: CombinedComponent {
    let context: AccountContext?
    let content: TabSelectorComponent.Item.Content
    let font: UIFont
    let color: UIColor
    let normalColor: UIColor?
    let selectedColor: UIColor
    let selectionFraction: CGFloat
    
    init(
        context: AccountContext?,
        content: TabSelectorComponent.Item.Content,
        font: UIFont,
        color: UIColor,
        normalColor: UIColor?,
        selectedColor: UIColor,
        selectionFraction: CGFloat
    ) {
        self.context = context
        self.content = content
        self.font = font
        self.color = color
        self.normalColor = normalColor
        self.selectedColor = selectedColor
        self.selectionFraction = selectionFraction
    }

    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.font != rhs.font {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.normalColor != rhs.normalColor {
            return false
        }
        if lhs.selectedColor != rhs.selectedColor {
            return false
        }
        if lhs.selectionFraction != rhs.selectionFraction {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextWithEntitiesComponent.self)
        let selectedTitle = Child(MultilineTextWithEntitiesComponent.self)
        let contentComponent = Child(environment: TabSelectorComponent.ItemEnvironment.self)
        
        return { context in
            let component = context.component
            
            switch component.content {
            case let .text(text):
                let attributedTitle = NSMutableAttributedString(string: text, font: component.font, textColor: component.normalColor ?? component.color)
                var range = (attributedTitle.string as NSString).range(of: "⭐️")
                if range.location != NSNotFound {
                    attributedTitle.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                }
                
                let title = title.update(
                    component: MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context?.animationCache,
                        animationRenderer: component.context?.animationRenderer,
                        placeholderColor: .white,
                        text: .plain(attributedTitle),
                        displaysAsynchronously: false
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(title
                    .position(CGPoint(x: title.size.width / 2.0, y: title.size.height / 2.0))
                    .opacity(1.0 - component.selectionFraction)
                )
                
                var selectedColor = component.selectedColor
                if let _ = component.normalColor {
                    selectedColor = component.color
                }
                
                let selectedAttributedTitle = NSMutableAttributedString(string: text, font: component.font, textColor: selectedColor)
                range = (selectedAttributedTitle.string as NSString).range(of: "⭐️")
                if range.location != NSNotFound {
                    selectedAttributedTitle.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                }
                
                let selectedTitle = selectedTitle.update(
                    component: MultilineTextWithEntitiesComponent(
                        context: nil,
                        animationCache: nil,
                        animationRenderer: nil,
                        placeholderColor: .white,
                        text: .plain(selectedAttributedTitle),
                        displaysAsynchronously: false
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(selectedTitle
                    .position(CGPoint(x: selectedTitle.size.width / 2.0, y: selectedTitle.size.height / 2.0))
                    .opacity(component.selectionFraction)
                )
                
                return title.size
            case let .component(contentComponentValue):
                let content = contentComponent.update(
                    contentComponentValue,
                    environment: {
                        TabSelectorComponent.ItemEnvironment(selectionFraction: component.selectionFraction)
                    },
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(content
                    .position(CGPoint(x: content.size.width / 2.0, y: content.size.height / 2.0))
                )
                
                return content.size
            }
        }
    }
}

private final class ReorderGestureRecognizer: UIGestureRecognizer {
    private let shouldBegin: (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, item: TabSelectorComponent.VisibleItem?)
    private let willBegin: (CGPoint) -> Void
    private let began: (TabSelectorComponent.VisibleItem) -> Void
    private let ended: () -> Void
    private let moved: (CGPoint) -> Void
    private let isActiveUpdated: (Bool) -> Void
    
    private var initialLocation: CGPoint?
    private var longTapTimer: Foundation.Timer?
    private var longPressTimer: Foundation.Timer?
    
    private var itemView: TabSelectorComponent.VisibleItem?
    
    public init(shouldBegin: @escaping (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, item: TabSelectorComponent.VisibleItem?), willBegin: @escaping (CGPoint) -> Void, began: @escaping (TabSelectorComponent.VisibleItem) -> Void, ended: @escaping () -> Void, moved: @escaping (CGPoint) -> Void, isActiveUpdated: @escaping (Bool) -> Void) {
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
        let longTapTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false, block: { [weak self] _ in
            self?.longTapTimerFired()
        })
        self.longTapTimer = longTapTimer
    }
    
    private func stopLongTapTimer() {
        self.itemView = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
    }
    
    private func startLongPressTimer() {
        self.longPressTimer?.invalidate()
        let longPressTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false, block: { [weak self] _ in
            self?.longPressTimerFired()
        })
        self.longPressTimer = longPressTimer
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
        if let itemView = self.itemView {
            self.began(itemView)
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
                let (allowed, requiresLongPress, itemView) = self.shouldBegin(location)
                if allowed {
                    self.isActiveUpdated(true)
                    
                    self.itemView = itemView
                    self.initialLocation = location
                    if requiresLongPress {
                        self.startLongTapTimer()
                        self.startLongPressTimer()
                    } else {
                        self.state = .began
                        if let itemView = self.itemView {
                            self.began(itemView)
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
            let offset = CGPoint(x: location.x - initialLocation.x, y: 0.0)
            self.moved(offset)
        } else if let touch = touches.first, let initialTapLocation = self.initialLocation, self.longPressTimer != nil {
            let touchLocation = touch.location(in: self.view)
            let dX = touchLocation.x - initialTapLocation.x
            
            if dX > 3.0 {
                self.stopLongTapTimer()
                self.stopLongPressTimer()
                self.initialLocation = nil
                self.isActiveUpdated(false)
                self.state = .failed
            }
        }
    }
}


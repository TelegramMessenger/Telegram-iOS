import Foundation
import UIKit
import Display
import ComponentFlow
import PlainButtonComponent
import MultilineTextWithEntitiesComponent
import TextFormat
import AccountContext

public final class TabSelectorComponent: Component {
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
        public var simple: Bool

        public init(
            foreground: UIColor,
            selection: UIColor,
            simple: Bool = false
        ) {
            self.foreground = foreground
            self.selection = selection
            self.simple = simple
        }
    }
    
    public struct CustomLayout: Equatable {
        public var font: UIFont
        public var spacing: CGFloat
        public var innerSpacing: CGFloat?
        public var lineSelection: Bool
        public var verticalInset: CGFloat
        public var allowScroll: Bool
        
        public init(font: UIFont, spacing: CGFloat, innerSpacing: CGFloat? = nil, lineSelection: Bool = false, verticalInset: CGFloat = 0.0, allowScroll: Bool = true) {
            self.font = font
            self.spacing = spacing
            self.innerSpacing = innerSpacing
            self.lineSelection = lineSelection
            self.verticalInset = verticalInset
            self.allowScroll = allowScroll
        }
    }
    
    public struct Item: Equatable {
        public enum Content: Equatable {
            case text(String)
            case component(AnyComponent<ItemEnvironment>)
        }
        
        public var id: AnyHashable
        public var content: Content

        public init(
            id: AnyHashable,
            content: Content
        ) {
            self.id = id
            self.content = content
        }
        
        public init(
            id: AnyHashable,
            title: String
        ) {
            self.init(id: id, content: .text(title))
        }
    }

    public let context: AccountContext?
    public let colors: Colors
    public let customLayout: CustomLayout?
    public let items: [Item]
    public let selectedId: AnyHashable?
    public let setSelectedId: (AnyHashable) -> Void
    public let transitionFraction: CGFloat?
    
    public init(
        context: AccountContext? = nil,
        colors: Colors,
        customLayout: CustomLayout? = nil,
        items: [Item],
        selectedId: AnyHashable?,
        setSelectedId: @escaping (AnyHashable) -> Void,
        transitionFraction: CGFloat? = nil
    ) {
        self.context = context
        self.colors = colors
        self.customLayout = customLayout
        self.items = items
        self.selectedId = selectedId
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
        if lhs.customLayout != rhs.customLayout {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        if lhs.transitionFraction != rhs.transitionFraction {
            return false
        }
        return true
    }
    
    private final class VisibleItem {
        let title = ComponentView<Empty>()
        
        init() {
        }
    }
    
    public final class View: UIScrollView {
        private var component: TabSelectorComponent?
        private weak var state: EmptyComponentState?
        
        private let selectionView: UIImageView
        private var visibleItems: [AnyHashable: VisibleItem] = [:]
        
        private var didInitiallyScroll = false
        
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
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        override public func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
        
        func update(component: TabSelectorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let selectionColorUpdated = component.colors.selection != self.component?.colors.selection
           
            self.component = component
            self.state = state
            
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
                    itemView = VisibleItem()
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
                
                let itemSize = itemView.title.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(ItemComponent(
                            context: component.context,
                            content: item.content,
                            font: itemFont,
                            color: component.colors.foreground,
                            selectedColor: component.colors.selection,
                            selectionFraction: useSelectionFraction ? selectionFraction : 0.0
                        )),
                        effectAlignment: .center,
                        minSize: nil,
                        action: { [weak self, weak itemView] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.setSelectedId(itemId)
                            
                            if let view = itemView?.title.view, allowScroll && self.contentSize.width > self.bounds.width {
                                self.scrollRectToVisible(view.frame.insetBy(dx: -64.0, dy: 0.0), animated: true)
                            }
                        },
                        animateScale: !isLineSelection
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                innerContentWidth += itemSize.width
                itemViews[item.id] = (itemView, itemSize, itemTransition)
                index += 1
            }
            
            let estimatedContentWidth = 2.0 * spacing + innerContentWidth + (CGFloat(component.items.count - 1) * (spacing + innerInset))
            if estimatedContentWidth > availableSize.width && !allowScroll {
                spacing = (availableSize.width - innerContentWidth) / CGFloat(component.items.count + 1)
                innerInset = 0.0
            }
            
            var contentWidth: CGFloat = spacing
            var previousBackgroundRect: CGRect?
            var selectedBackgroundRect: CGRect?
            var nextBackgroundRect: CGRect?
            
            for item in component.items {
                guard let (itemView, itemSize, itemTransition) = itemViews[item.id] else {
                    continue
                }
                if contentWidth > spacing {
                    contentWidth += spacing
                }
                let itemTitleFrame = CGRect(origin: CGPoint(x: contentWidth + innerInset, y: verticalInset + floor((baseHeight - itemSize.height) * 0.5)), size: itemSize)
                let itemBackgroundRect = CGRect(origin: CGPoint(x: contentWidth, y: verticalInset), size: CGSize(width: innerInset + itemSize.width + innerInset, height: baseHeight))
                contentWidth = itemBackgroundRect.maxX
                
                if item.id == component.selectedId {
                    selectedBackgroundRect = itemBackgroundRect
                }
                if selectedBackgroundRect == nil {
                    previousBackgroundRect = itemBackgroundRect
                } else if nextBackgroundRect == nil, itemBackgroundRect != selectedBackgroundRect {
                    nextBackgroundRect = itemBackgroundRect
                }
                
                if let itemTitleView = itemView.title.view {
                    if itemTitleView.superview == nil {
                        itemTitleView.layer.anchorPoint = CGPoint()
                        self.addSubview(itemTitleView)
                    }
                    itemTransition.setPosition(view: itemTitleView, position: itemTitleFrame.origin)
                    itemTransition.setBounds(view: itemTitleView, bounds: CGRect(origin: CGPoint(), size: itemTitleFrame.size))
                    itemTransition.setAlpha(view: itemTitleView, alpha: item.id == component.selectedId || isLineSelection || component.colors.simple ? 1.0 : 0.4)
                }
            }
            contentWidth += spacing
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.title.view?.removeFromSuperview()
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
                    mappedSelectionFrame.origin.y = mappedSelectionFrame.maxY + 6.0
                    mappedSelectionFrame.size.height = 3.0
                    transition.setFrame(view: self.selectionView, frame: mappedSelectionFrame)
                } else {
                    transition.setFrame(view: self.selectionView, frame: selectedBackgroundRect)
                }
            } else {
                self.selectionView.alpha = 0.0
            }
            
            let contentSize = CGSize(width: contentWidth, height: baseHeight + verticalInset * 2.0)
            if self.contentSize != contentSize {
                self.contentSize = contentSize
            }
            self.disablesInteractiveTransitionGestureRecognizer = contentWidth > availableSize.width
            
            if let selectedBackgroundRect, self.bounds.width > 0.0 && !self.didInitiallyScroll {
                self.scrollRectToVisible(selectedBackgroundRect.insetBy(dx: -spacing, dy: 0.0), animated: false)
                self.didInitiallyScroll = true
            }
            
            return CGSize(width: min(contentWidth, availableSize.width), height: baseHeight + verticalInset * 2.0)
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
    let selectedColor: UIColor
    let selectionFraction: CGFloat
    
    init(
        context: AccountContext?,
        content: TabSelectorComponent.Item.Content,
        font: UIFont,
        color: UIColor,
        selectedColor: UIColor,
        selectionFraction: CGFloat
    ) {
        self.context = context
        self.content = content
        self.font = font
        self.color = color
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
                let attributedTitle = NSMutableAttributedString(string: text, font: component.font, textColor: component.color)
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
                        text: .plain(attributedTitle)
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(title
                    .position(CGPoint(x: title.size.width / 2.0, y: title.size.height / 2.0))
                    .opacity(1.0 - component.selectionFraction)
                )
                
                let selectedAttributedTitle = NSMutableAttributedString(string: text, font: component.font, textColor: component.selectedColor)
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
                        text: .plain(selectedAttributedTitle)
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

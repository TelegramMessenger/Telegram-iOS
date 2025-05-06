import Foundation
import UIKit
import Display
import ComponentFlow
import PlainButtonComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import TextFormat
import AccountContext

public final class FilterSelectorComponent: Component {
    public struct Colors: Equatable {
        public var foreground: UIColor
        public var background: UIColor

        public init(
            foreground: UIColor,
            background: UIColor
        ) {
            self.foreground = foreground
            self.background = background
        }
    }
    
    public struct Item: Equatable {
        public var id: AnyHashable
        public var iconName: String?
        public var title: String
        public var action: (UIView) -> Void

        public init(
            id: AnyHashable,
            iconName: String? = nil,
            title: String,
            action: @escaping (UIView) -> Void
        ) {
            self.id = id
            self.iconName = iconName
            self.title = title
            self.action = action
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            return lhs.id == rhs.id && lhs.iconName == rhs.iconName && lhs.title == rhs.title
        }
    }

    public let context: AccountContext?
    public let colors: Colors
    public let items: [Item]
    
    public init(
        context: AccountContext? = nil,
        colors: Colors,
        items: [Item]
    ) {
        self.context = context
        self.colors = colors
        self.items = items
    }
    
    public static func ==(lhs: FilterSelectorComponent, rhs: FilterSelectorComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.items != rhs.items {
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
        private var component: FilterSelectorComponent?
        private weak var state: EmptyComponentState?
        
        private var visibleItems: [AnyHashable: VisibleItem] = [:]
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.showsVerticalScrollIndicator = false
            self.showsHorizontalScrollIndicator = false
            self.scrollsToTop = false
            self.delaysContentTouches = false
            self.canCancelContentTouches = true
            self.contentInsetAdjustmentBehavior = .never
            self.alwaysBounceVertical = false
            self.clipsToBounds = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        override public func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
        
        func animateIn() {
            for (_, item) in self.visibleItems {
                if let itemView = item.title.view {
                    itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    itemView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
            }
        }
        
        func update(component: FilterSelectorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let baseHeight: CGFloat = 28.0
                        
            var spacing: CGFloat = 6.0
            
            let itemFont = Font.semibold(14.0)
            let allowScroll = true
                    
            var innerContentWidth: CGFloat = 0.0
                        
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
                
                let itemSize = itemView.title.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(ItemComponent(
                            context: component.context,
                            iconName: item.iconName,
                            text: item.title,
                            font: itemFont,
                            color: component.colors.foreground,
                            backgroundColor: component.colors.background
                        )),
                        effectAlignment: .center,
                        minSize: nil,
                        action: { [weak itemView] in
                            if let view = itemView?.title.view {
                                item.action(view)
                            }
                        },
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                innerContentWidth += itemSize.width
                itemViews[item.id] = (itemView, itemSize, itemTransition)
                index += 1
            }
            
            let estimatedContentWidth = 2.0 * spacing + innerContentWidth + (CGFloat(component.items.count - 1) * spacing)
            if estimatedContentWidth > availableSize.width && !allowScroll {
                spacing = (availableSize.width - innerContentWidth) / CGFloat(component.items.count + 1)
            }
            
            var contentWidth: CGFloat = spacing
            for item in component.items {
                guard let (itemView, itemSize, itemTransition) = itemViews[item.id] else {
                    continue
                }
                if contentWidth > spacing {
                    contentWidth += spacing
                }
                let itemFrame = CGRect(origin: CGPoint(x: contentWidth, y: floor((baseHeight - itemSize.height) * 0.5)), size: itemSize)
                contentWidth = itemFrame.maxX
                
                if let itemTitleView = itemView.title.view {
                    if itemTitleView.superview == nil {
                        itemTitleView.layer.anchorPoint = CGPoint()
                        self.addSubview(itemTitleView)
                    }
                    itemTransition.setPosition(view: itemTitleView, position: itemFrame.origin)
                    itemTransition.setBounds(view: itemTitleView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
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
            
            self.contentSize = CGSize(width: contentWidth, height: baseHeight)
            self.disablesInteractiveTransitionGestureRecognizer = contentWidth > availableSize.width

            return CGSize(width: min(contentWidth, availableSize.width), height: baseHeight)
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
    let iconName: String?
    let text: String
    let font: UIFont
    let color: UIColor
    let backgroundColor: UIColor
    
    init(
        context: AccountContext?,
        iconName: String?,
        text: String,
        font: UIFont,
        color: UIColor,
        backgroundColor: UIColor
    ) {
        self.context = context
        self.iconName = iconName
        self.text = text
        self.font = font
        self.color = color
        self.backgroundColor = backgroundColor
    }

    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.font != rhs.font {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let title = Child(MultilineTextWithEntitiesComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
            
            let attributedTitle = NSMutableAttributedString(string: component.text, font: component.font, textColor: component.color)
            let range = (attributedTitle.string as NSString).range(of: "⭐️")
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
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName ?? "Item List/ExpandableSelectorArrows",
                    tintColor: component.color,
                    maxSize: component.iconName != nil ? CGSize(width: 22.0, height: 22.0) : nil
                ),
                availableSize: CGSize(width: 100, height: 100),
                transition: .immediate
            )
            
            let padding: CGFloat = 12.0
            var leftPadding = padding
            if let _ = component.iconName {
                leftPadding -= 4.0
            }
            let spacing: CGFloat = 4.0
            let totalWidth = title.size.width + icon.size.width + spacing
            let size = CGSize(width: totalWidth + leftPadding + padding, height: 28.0)
            let background = background.update(
                component: RoundedRectangle(
                    color: component.backgroundColor,
                    cornerRadius: 14.0
                ),
                availableSize: size,
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0))
            )
            if let _ = component.iconName {
                context.add(title
                    .position(CGPoint(x: size.width - padding - title.size.width / 2.0, y: size.height / 2.0))
                )
                context.add(icon
                    .position(CGPoint(x: leftPadding + icon.size.width / 2.0, y: size.height / 2.0))
                )
            } else {
                context.add(title
                    .position(CGPoint(x: padding + title.size.width / 2.0, y: size.height / 2.0))
                )
                context.add(icon
                    .position(CGPoint(x: size.width - padding - icon.size.width / 2.0, y: size.height / 2.0))
                )
            }
            return size
        }
    }
}

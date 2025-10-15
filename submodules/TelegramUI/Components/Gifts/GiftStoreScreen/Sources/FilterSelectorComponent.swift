import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import PlainButtonComponent
import MultilineTextComponent
import BundleIconComponent
import TextFormat
import AccountContext
import LottieComponent

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
        public var index: Int
        public var iconName: String?
        public var title: String
        public var action: (UIView) -> Void
        
        public init(
            id: AnyHashable,
            index: Int = 0,
            iconName: String? = nil,
            title: String,
            action: @escaping (UIView) -> Void
        ) {
            self.id = id
            self.index = index
            self.iconName = iconName
            self.title = title
            self.action = action
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            return lhs.id == rhs.id && lhs.index == rhs.index && lhs.iconName == rhs.iconName && lhs.title == rhs.title
        }
    }
    
    public let context: AccountContext?
    public let colors: Colors
    public let items: [Item]
    public let selectedItemId: AnyHashable?
    
    public init(
        context: AccountContext? = nil,
        colors: Colors,
        items: [Item],
        selectedItemId: AnyHashable?
    ) {
        self.context = context
        self.colors = colors
        self.items = items
        self.selectedItemId = selectedItemId
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
        if lhs.selectedItemId != rhs.selectedItemId {
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
                    transition: transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(ItemComponent(
                            context: component.context,
                            index: item.index,
                            iconName: item.iconName,
                            text: item.title,
                            font: itemFont,
                            color: component.colors.foreground,
                            backgroundColor: component.colors.background,
                            isSelected: itemId == component.selectedItemId
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

private final class ItemComponent: Component {
    let context: AccountContext?
    let index: Int
    let iconName: String?
    let text: String
    let font: UIFont
    let color: UIColor
    let backgroundColor: UIColor
    let isSelected: Bool
    
    init(
        context: AccountContext?,
        index: Int,
        iconName: String?,
        text: String,
        font: UIFont,
        color: UIColor,
        backgroundColor: UIColor,
        isSelected: Bool
    ) {
        self.context = context
        self.index = index
        self.iconName = iconName
        self.text = text
        self.font = font
        self.color = color
        self.backgroundColor = backgroundColor
        self.isSelected = isSelected
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.index != rhs.index {
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
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: ItemComponent?
        private weak var state: EmptyComponentState?
        
        private let background = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        
        private var isSelected = false
        private var iconName: String?
        
        private let playOnce = ActionSlot<Void>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            var animateTitleInDirection: CGFloat?
            if let previousComponent, previousComponent.text != component.text, !transition.animation.isImmediate, let titleView = self.title.view, let snapshotView = titleView.snapshotView(afterScreenUpdates: false) {
                snapshotView.frame = titleView.frame
                self.addSubview(snapshotView)
                
                var direction: CGFloat = 1.0
                if previousComponent.index < component.index {
                    direction = -1.0
                }
                
                snapshotView.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: 6.0 * direction), duration: 0.2, removeOnCompletion: false, additive: true)
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    snapshotView.removeFromSuperview()
                })
                
                animateTitleInDirection = direction
            }
            
            let attributedTitle = NSAttributedString(string: component.text, font: component.font, textColor: component.color)
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(attributedTitle)
                )),
                environment: {},
                containerSize: availableSize
            )
            
            let animationName = component.iconName ?? (component.isSelected ? "GiftFilterMenuOpen" : "GiftFilterMenuClose")
            let animationSize = component.iconName != nil ? CGSize(width: 22.0, height: 22.0) : CGSize(width: 10.0, height: 22.0)
            
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: animationName),
                    color: component.color,
                    playOnce: self.playOnce
                )),
                environment: {},
                containerSize: CGSize(width: 22.0, height: 22.0)
            )
        
            var playAnimation = false
            if self.isSelected != component.isSelected || self.iconName != component.iconName {
                if let iconName = component.iconName {
                    if component.isSelected {
                        playAnimation = true
                    } else if self.iconName != iconName {
                        playAnimation = true
                    }
                    self.iconName = iconName
                } else {
                    playAnimation = true
                }
                self.isSelected = component.isSelected
            }
            if playAnimation {
                self.playOnce.invoke(Void())
            }
            
            let padding: CGFloat = 12.0
            var leftPadding = padding
            if let _ = component.iconName {
                leftPadding -= 4.0
            }
            let spacing: CGFloat = 4.0
            let totalWidth = titleSize.width + animationSize.width + spacing
            let size = CGSize(width: totalWidth + leftPadding + padding, height: 28.0)
            
            let backgroundSize = self.background.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: component.backgroundColor,
                    cornerRadius: 14.0
                )),
                environment: {},
                containerSize: size
            )
            
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setPosition(view: backgroundView, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
                transition.setBounds(view: backgroundView, bounds: CGRect(origin: CGPoint(), size: backgroundSize))
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                let titlePosition: CGPoint
                if let _ = component.iconName {
                    titlePosition = CGPoint(x: size.width - padding - titleSize.width / 2.0, y: size.height / 2.0)
                } else {
                    titlePosition = CGPoint(x: padding + titleSize.width / 2.0, y: size.height / 2.0)
                }
                if let animateTitleInDirection {
                    titleView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    titleView.center = CGPoint(x: titlePosition.x, y: titlePosition.y - 6.0 * animateTitleInDirection)
                }
                transition.setPosition(view: titleView, position: titlePosition)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleSize)
            }
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                let iconPosition: CGPoint
                if let _ = component.iconName {
                    iconPosition = CGPoint(x: leftPadding + iconSize.width / 2.0, y: size.height / 2.0)
                } else {
                    iconPosition = CGPoint(x: size.width - padding - animationSize.width / 2.0, y: size.height / 2.0)
                }
                transition.setPosition(view: iconView, position: iconPosition)
                transition.setBounds(view: iconView, bounds: CGRect(origin: CGPoint(), size: iconSize))
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

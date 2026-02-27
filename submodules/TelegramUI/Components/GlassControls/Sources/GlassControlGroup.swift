import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import PlainButtonComponent
import BundleIconComponent
import MultilineTextComponent
import LottieComponent

public final class GlassControlGroupComponent: Component {
    public final class Item: Equatable {
        public enum Content: Equatable {
            case icon(String)
            case text(String)
            case animation(String)
            case customIcon(id: AnyHashable, component: AnyComponent<Empty>)
            
            enum Id: Hashable {
                case icon(String)
                case text(String)
                case animation(String)
                case customIcon(AnyHashable)
            }
            
            var id: Id {
                switch self {
                case let .icon(icon):
                    return .icon(icon)
                case let .text(text):
                    return .text(text)
                case let .animation(animation):
                    return .animation(animation)
                case let .customIcon(id, _):
                    return .customIcon(id)
                }
            }
        }
        
        public let id: AnyHashable
        public let content: Content
        public let action: (() -> Void)?

        public init(id: AnyHashable, content: Content, action: (() -> Void)?) {
            self.id = id
            self.content = content
            self.action = action
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.content != rhs.content {
                return false
            }
            if (lhs.action == nil) != (rhs.action == nil) {
                return false
            }
            return true
        }
    }

    public enum Background: Equatable {
        case panel
        case activeTint
        case color(UIColor)
    }

    public let theme: PresentationTheme
    public let preferClearGlass: Bool
    public let background: Background
    public let items: [Item]
    public let minWidth: CGFloat

    public init(
        theme: PresentationTheme,
        preferClearGlass: Bool,
        background: Background,
        items: [Item],
        minWidth: CGFloat
    ) {
        self.theme = theme
        self.preferClearGlass = preferClearGlass
        self.background = background
        self.items = items
        self.minWidth = minWidth
    }

    public static func ==(lhs: GlassControlGroupComponent, rhs: GlassControlGroupComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.preferClearGlass != rhs.preferClearGlass {
            return false
        }
        if lhs.background != rhs.background {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.minWidth != rhs.minWidth {
            return false
        }
        return true
    }
    
    private struct ItemId: Hashable {
        let id: AnyHashable
        let contentId: AnyHashable
        
        init(id: AnyHashable, contentId: AnyHashable) {
            self.id = id
            self.contentId = contentId
        }
    }

    public final class View: UIView {
        private let backgroundView: GlassBackgroundView
        private var itemViews: [ItemId: ComponentView<Empty>] = [:]
        private var animations: [ItemId: ActionSlot<Void>] = [:]
        
        private var component: GlassControlGroupComponent?
        private weak var state: EmptyComponentState?

        override public init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required public init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public func itemView(id: AnyHashable) -> UIView? {
            for (itemId, itemView) in self.itemViews {
                if itemId.id == id {
                    return itemView.view
                }
            }
            return nil
        }
        
        func update(component: GlassControlGroupComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            self.component = component
            self.state = state
            
            let foregroundColor: UIColor
            let tintColor: GlassBackgroundView.TintColor
            switch component.background {
            case .panel:
                foregroundColor = component.theme.chat.inputPanel.panelControlColor
                tintColor = .init(kind: component.preferClearGlass ? .clear : .panel)
            case .activeTint:
                foregroundColor = component.theme.list.itemCheckColors.foregroundColor
                tintColor = .init(kind: component.preferClearGlass ? .clear : .panel, innerColor: component.theme.list.itemCheckColors.fillColor)
            case let .color(color):
                foregroundColor = .white
                tintColor = .init(kind: .custom(style: component.preferClearGlass ? .clear : .default, color: color))
            }
            
            var contentsWidth: CGFloat = 0.0
            var validIds: [AnyHashable] = []
            var isInteractive = false
            for item in component.items {
                let itemId = ItemId(id: item.id, contentId: item.content.id)
                
                validIds.append(itemId)
                
                let itemView: ComponentView<Empty>
                var itemTransition = transition
                if let current = self.itemViews[itemId] {
                    itemView = current
                } else {
                    itemView = ComponentView()
                    self.itemViews[itemId] = itemView
                    itemTransition = itemTransition.withAnimation(.none)
                }
                
                if item.action != nil {
                    isInteractive = true
                }
                
                let content: AnyComponent<Empty>
                var itemInsets = UIEdgeInsets()
                switch item.content {
                case let .icon(name):
                    content = AnyComponent(BundleIconComponent(
                        name: name,
                        tintColor: foregroundColor
                    ))
                case let .text(string):
                    content = AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: string, font: Font.medium(17.0), textColor: foregroundColor))
                    ))
                    itemInsets.left = 10.0
                    itemInsets.right = itemInsets.left
                case let .animation(name):
                    let playOnce: ActionSlot<Void>
                    if let current = self.animations[itemId] {
                        playOnce = current
                    } else {
                        playOnce = ActionSlot()
                        self.animations[itemId] = playOnce
                    }
                    content = AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: name),
                        color: foregroundColor,
                        size: CGSize(width: 32.0, height: 32.0),
                        playOnce: playOnce
                    ))
                case let .customIcon(_, customIcon):
                    content = customIcon
                }
                
                var minItemWidth: CGFloat = availableSize.height
                if component.items.count == 1 {
                    minItemWidth = max(minItemWidth, component.minWidth)
                }
                
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: content,
                        minSize: CGSize(width: minItemWidth, height: availableSize.height),
                        contentInsets: itemInsets,
                        action: { [weak self] in
                            item.action?()
                            
                            if case .animation = item.content {
                                self?.animations[itemId]?.invoke(Void())
                            }
                        },
                        isEnabled: item.action != nil,
                        animateAlpha: false,
                        animateScale: false,
                        animateContents: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height)
                )
                let itemFrame = CGRect(origin: CGPoint(x: contentsWidth, y: 0.0), size: itemSize)
                
                if let itemComponentView = itemView.view {
                    var animateIn = false
                    if itemComponentView.superview == nil {
                        animateIn = true
                        self.backgroundView.contentView.addSubview(itemComponentView)
                        itemComponentView.alpha = 0.0
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    alphaTransition.setAlpha(view: itemComponentView, alpha: item.action != nil ? 1.0 : 0.5)
                    
                    if animateIn {
                        alphaTransition.animateBlur(layer: itemComponentView.layer, fromRadius: 8.0, toRadius: 0.0)
                    }
                }
                
                contentsWidth += itemSize.width
            }
            
            var removeIds: [ItemId] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemComponentView = itemView.view {
                        alphaTransition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                        alphaTransition.animateBlur(layer: itemComponentView.layer, fromRadius: 0.0, toRadius: 8.0, removeOnCompletion: false)
                    }
                    self.animations[id] = nil
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            let size = CGSize(width: contentsWidth, height: availableSize.height)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            isInteractive = true
            self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: tintColor, isInteractive: isInteractive, transition: transition)
            
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

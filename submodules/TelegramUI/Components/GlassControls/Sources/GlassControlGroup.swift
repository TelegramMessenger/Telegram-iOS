import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import PlainButtonComponent
import BundleIconComponent
import MultilineTextComponent

public final class GlassControlGroupComponent: Component {
    public final class Item: Equatable {
        public enum Content: Hashable {
            case icon(String)
            case text(String)
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

    public enum Background {
        case panel
        case activeTint
    }

    public let theme: PresentationTheme
    public let background: Background
    public let items: [Item]
    public let minWidth: CGFloat

    public init(
        theme: PresentationTheme,
        background: Background,
        items: [Item],
        minWidth: CGFloat
    ) {
        self.theme = theme
        self.background = background
        self.items = items
        self.minWidth = minWidth
    }

    public static func ==(lhs: GlassControlGroupComponent, rhs: GlassControlGroupComponent) -> Bool {
        if lhs.theme !== rhs.theme {
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

    public final class View: UIView {
        private let backgroundView: GlassBackgroundView
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        
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
            return self.itemViews[id]?.view
        }
        
        func update(component: GlassControlGroupComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            self.component = component
            self.state = state
            
            struct ItemId: Hashable {
                var id: AnyHashable
                var contentId: AnyHashable
                
                init(id: AnyHashable, contentId: AnyHashable) {
                    self.id = id
                    self.contentId = contentId
                }
            }
            
            var contentsWidth: CGFloat = 0.0
            var validIds: [AnyHashable] = []
            var isInteractive = false
            for item in component.items {
                let itemId = ItemId(id: item.id, contentId: item.content)
                
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
                        tintColor: component.background == .activeTint ? component.theme.list.itemCheckColors.foregroundColor :  component.theme.chat.inputPanel.panelControlColor
                    ))
                case let .text(string):
                    content = AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: string, font: Font.medium(17.0), textColor: component.background == .activeTint ? component.theme.list.itemCheckColors.foregroundColor :  component.theme.chat.inputPanel.panelControlColor))
                    ))
                    itemInsets.left = 10.0
                    itemInsets.right = itemInsets.left
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
                        action: {
                            item.action?()
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
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemComponentView = itemView.view {
                        alphaTransition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                        alphaTransition.animateBlur(layer: itemComponentView.layer, fromRadius: 0.0, toRadius: 8.0, removeOnCompletion: false)
                    }
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            let size = CGSize(width: contentsWidth, height: availableSize.height)
            let tintColor: GlassBackgroundView.TintColor
            switch component.background {
            case .panel:
                tintColor = .init(kind: .panel, color: component.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7))
            case .activeTint:
                tintColor = .init(kind: .panel, color: component.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7), innerColor: component.theme.list.itemCheckColors.fillColor)
            }
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

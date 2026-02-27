import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext

public final class AvatarComponent: Component {
    public enum ClipStyle {
        case round
        case roundedRect
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer
    let clipStyle: ClipStyle
    let icon: AnyComponent<Empty>?

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        peer: EnginePeer,
        clipStyle: ClipStyle = .round,
        icon: AnyComponent<Empty>? = nil
    ) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.clipStyle = clipStyle
        self.icon = icon
    }

    public static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.clipStyle != rhs.clipStyle {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let avatarNode: AvatarNode
        private var icon: ComponentView<Empty>?
        
        private var component: AvatarComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 42.0))
            
            super.init(frame: frame)
            
            self.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                self.avatarNode.font = avatarPlaceholderFont(size: ceil(42.0 * availableSize.width / 100.0))
            }
            
            self.component = component
            self.state = state
            
            var cutoutRect: CGRect?
            if let icon = component.icon {
                let iconView: ComponentView<Empty>
                if let current = self.icon {
                    iconView = current
                } else {
                    iconView = ComponentView()
                    self.icon = iconView
                }
                let iconSize = iconView.update(
                    transition: .immediate,
                    component: icon,
                    environment: {},
                    containerSize: CGSize(width: 24.0, height: 24.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: availableSize.width - iconSize.width + 2.0, y: availableSize.height - iconSize.height + 2.0), size: iconSize)
                if let iconView = iconView.view {
                    if iconView.superview == nil {
                        self.addSubview(iconView)
                    }
                    iconView.frame = iconFrame
                }
                cutoutRect = CGRect(origin: CGPoint(x: iconFrame.minX, y: availableSize.height - iconFrame.maxY), size: iconFrame.size).insetBy(dx: -2.0 + UIScreenPixel, dy: -2.0 + UIScreenPixel)
            }
            
            var clipStyle: AvatarNodeClipStyle = .round
            if case .roundedRect = component.clipStyle {
                clipStyle = .roundedRect
            }
            
            self.avatarNode.frame = CGRect(origin: .zero, size: availableSize)
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.peer,
                clipStyle: clipStyle,
                synchronousLoad: true,
                displayDimensions: availableSize,
                cutoutRect: cutoutRect
            )
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

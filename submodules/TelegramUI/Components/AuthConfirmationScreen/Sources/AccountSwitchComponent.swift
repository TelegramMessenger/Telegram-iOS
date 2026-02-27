import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import GlassBackgroundComponent
import AvatarComponent
import BundleIconComponent
import AccountContext

final class AccountSwitchComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer
    let canSwitch: Bool
    let action: ((GlassContextExtractableContainer) -> Void)

    init(
        context: AccountContext,
        theme: PresentationTheme,
        peer: EnginePeer,
        canSwitch: Bool,
        action: @escaping ((GlassContextExtractableContainer) -> Void)
    ) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.canSwitch = canSwitch
        self.action = action
    }

    static func ==(lhs: AccountSwitchComponent, rhs: AccountSwitchComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.canSwitch != rhs.canSwitch {
            return false
        }
        return true
    }

    final class View: UIView {
        private let backgroundView = GlassContextExtractableContainer()
        private let avatar = ComponentView<Empty>()
        private let arrow = ComponentView<Empty>()
        private let button = HighlightTrackingButton()
        
        private var component: AccountSwitchComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func buttonPressed() {
            if let component = self.component {
                component.action(self.backgroundView)
            }
        }
        
        func update(component: AccountSwitchComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let size = CGSize(width: component.canSwitch ? 76.0 : 44.0, height: 44.0)
            
            let avatarSize = self.avatar.update(
                transition: .immediate,
                component: AnyComponent(
                    AvatarComponent(
                        context: component.context,
                        theme: component.theme,
                        peer: component.peer,
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 36.0, height: 36.0)
            )
            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    avatarView.isUserInteractionEnabled = false
                    self.backgroundView.contentView.addSubview(avatarView)
                }
                avatarView.frame = CGRect(origin: CGPoint(x: 4.0, y: 4.0), size: avatarSize)
            }
            
            let arrowSize = self.arrow.update(
                transition: .immediate,
                component: AnyComponent(
                    BundleIconComponent(name: "Navigation/Disclosure", tintColor: component.theme.rootController.navigationBar.secondaryTextColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            if let arrowView = self.arrow.view {
                if arrowView.superview == nil {
                    arrowView.isUserInteractionEnabled = false
                    self.backgroundView.contentView.addSubview(arrowView)
                    self.backgroundView.contentView.addSubview(self.button)
                }
                arrowView.frame = CGRect(origin: CGPoint(x: size.width - arrowSize.width - 8.0, y: floorToScreenPixels((size.height - arrowSize.height) / 2.0)), size: arrowSize)
                transition.setAlpha(view: arrowView, alpha: component.canSwitch ? 1.0 : 0.0)
            }
            
            self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: component.canSwitch, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            transition.setFrame(view: self.button, frame: CGRect(origin: .zero, size: size))
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

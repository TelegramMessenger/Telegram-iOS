import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import ComponentDisplayAdapters
import TelegramPresentationData
import AnimatedTextComponent
import ButtonComponent
import EdgeEffect
import MultilineTextComponent

public final class BottomButtonPanelComponent: Component {
    let theme: PresentationTheme
    let title: String
    let label: String?
    let icon: AnyComponentWithIdentity<Empty>?
    let isEnabled: Bool
    let insets: UIEdgeInsets
    let action: () -> Void
    
    public init(
        theme: PresentationTheme,
        title: String,
        label: String?,
        icon: AnyComponentWithIdentity<Empty>? = nil,
        isEnabled: Bool,
        insets: UIEdgeInsets,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.label = label
        self.icon = icon
        self.isEnabled = isEnabled
        self.insets = insets
        self.action = action
    }
    
    public static func ==(lhs: BottomButtonPanelComponent, rhs: BottomButtonPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.label != rhs.label {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
    
    public class View: UIView {
        private let edgeEffectView: EdgeEffectView
        private let actionButton = ComponentView<Empty>()

        private var component: BottomButtonPanelComponent?
        
        override public init(frame: CGRect) {
            self.edgeEffectView = EdgeEffectView()
            self.edgeEffectView.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.addSubview(self.edgeEffectView)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BottomButtonPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let topInset: CGFloat = 8.0
            
            let bottomInset: CGFloat
            if component.insets.bottom == 0.0 {
                bottomInset = topInset
            } else {
                bottomInset = component.insets.bottom + 10.0
            }
            
            let buttonHeight: CGFloat = 52.0
            let height: CGFloat = topInset + buttonHeight + bottomInset

            let edgeEffectFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: component.theme.list.blocksBackgroundColor, blur: true, alpha: 1.0, rect: edgeEffectFrame, edge: .bottom, edgeSize: edgeEffectFrame.height, transition: transition)

            var buttonTitleVStack: [AnyComponentWithIdentity<Empty>] = []
            buttonTitleVStack.append(AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(AnimatedTextComponent(
                font: Font.with(size: 18.0, weight: .semibold, traits: .monospacedNumbers),
                color: component.theme.list.itemCheckColors.foregroundColor,
                items: [
                    AnimatedTextComponent.Item(id: AnyHashable("title"), content: .text(component.title))
                ],
                noDelay: true,
                blur: false
            ))))
            
            if let label = component.label {
                buttonTitleVStack.append(AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(size: 11.0, weight: .semibold, traits: .monospacedNumbers),
                    color: component.theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7),
                    items: [
                        AnimatedTextComponent.Item(id: AnyHashable("label"), content: .text(label))
                    ],
                    noDelay: true,
                    blur: false
                ))))
            }
            
            var buttonTitleContent: AnyComponent<Empty> = AnyComponent(VStack(buttonTitleVStack, spacing: 1.0))
            if let icon = component.icon {
                buttonTitleContent = AnyComponent(HStack([
                    icon,
                    AnyComponentWithIdentity(id: "_title", component: buttonTitleContent)
                ], spacing: 7.0))
            }
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: 0,
                        component: buttonTitleContent
                    ),
                    isEnabled: component.isEnabled,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.component?.action()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - component.insets.left - component.insets.right, height: buttonHeight)
            )
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: CGRect(origin: CGPoint(x: component.insets.left, y: topInset), size: actionButtonSize))
            }
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

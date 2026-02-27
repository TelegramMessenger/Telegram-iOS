import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import ComponentDisplayAdapters
import TelegramPresentationData
import ButtonComponent
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
        private let backgroundView: BlurredBackgroundView
        private let separatorLayer: SimpleLayer
        private let actionButton = ComponentView<Empty>()
        
        private var component: BottomButtonPanelComponent?
        
        override public init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.separatorLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.separatorLayer)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: BottomButtonPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component
            
            let topInset: CGFloat = 8.0
            
            let bottomInset: CGFloat
            if component.insets.bottom == 0.0 {
                bottomInset = topInset
            } else {
                bottomInset = component.insets.bottom + 10.0
            }
            
            let height: CGFloat = topInset + 50.0 + bottomInset

            if themeUpdated {
                self.backgroundView.updateColor(color: component.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.separatorLayer.backgroundColor = component.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: height))
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            self.backgroundView.update(size: backgroundFrame.size, transition: transition.containedViewLayoutTransition)
            
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
            
            var buttonTitleVStack: [AnyComponentWithIdentity<Empty>] = []
            
            let titleString = NSMutableAttributedString(string: component.title, font: Font.semibold(17.0), textColor: component.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            buttonTitleVStack.append(AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(text: .plain(titleString)))))
            
            if let label = component.label {
                let labelString = NSMutableAttributedString(string: label, font: Font.semibold(11.0), textColor: component.theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7), paragraphAlignment: .center)
                buttonTitleVStack.append(AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(text: .plain(labelString)))))
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
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
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
                containerSize: CGSize(width: availableSize.width - component.insets.left - component.insets.right, height: 50.0)
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

import Foundation
import UIKit
import Display
import ComponentFlow
import AnimatedStickerComponent
import ButtonComponent
import TelegramPresentationData
import AccountContext
import MultilineTextComponent

public final class EmptyStateIndicatorComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let animationName: String
    public let title: String
    public let text: String
    public let actionTitle: String?
    public let action: () -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        animationName: String,
        title: String,
        text: String,
        actionTitle: String?,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.animationName = animationName
        self.title = title
        self.text = text
        self.actionTitle = actionTitle
        self.action = action
    }

    public static func ==(lhs: EmptyStateIndicatorComponent, rhs: EmptyStateIndicatorComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.animationName != rhs.animationName {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.actionTitle != rhs.actionTitle {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: EmptyStateIndicatorComponent?
        private weak var componentState: EmptyComponentState?

        private let animation = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private var button: ComponentView<Empty>?
        
        override public init(frame: CGRect) {
            super.init(frame: frame)
        }

        required public init(coder: NSCoder) {
            preconditionFailure()
        }

        public func update(component: EmptyStateIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.componentState = state
            
            let animationSize = self.animation.update(
                transition: transition,
                component: AnyComponent(AnimatedStickerComponent(
                    account: component.context.account,
                    animation: AnimatedStickerComponent.Animation(source: .bundle(name: component.animationName), loop: true),
                    size: CGSize(width: 120.0, height: 120.0)
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 120.0)
            )
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: min(300.0, availableSize.width - 16.0 * 2.0), height: 1000.0)
            )
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.text, font: Font.regular(15.0), textColor: component.theme.list.itemSecondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: min(300.0, availableSize.width - 16.0 * 2.0), height: 1000.0)
            )
            var buttonSize: CGSize?
            if let actionTitle = component.actionTitle {
                let button: ComponentView<Empty>
                if let current = self.button {
                    button = current
                } else {
                    button = ComponentView()
                    self.button = button
                }
                
                buttonSize = button.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            color: component.theme.list.itemCheckColors.fillColor,
                            foreground: component.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        ),
                        content: AnyComponentWithIdentity(id: 0, component: AnyComponent(
                            Text(text: actionTitle, font: Font.semibold(17.0), color: component.theme.list.itemCheckColors.foregroundColor)
                        )),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.action()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 240.0, height: 50.0)
                )
            } else {
                if let button = self.button {
                    self.button = nil
                    button.view?.removeFromSuperview()
                }
            }
            
            let animationSpacing: CGFloat = 11.0
            let titleSpacing: CGFloat = 17.0
            let buttonSpacing: CGFloat = 17.0
            
            var totalHeight: CGFloat = animationSize.height + animationSpacing + titleSize.height + titleSpacing + textSize.height
            if let buttonSize {
                totalHeight += buttonSpacing + buttonSize.height
            }
            
            var contentY = floor((availableSize.height - totalHeight) * 0.5)
            
            if let animationView = self.animation.view {
                if animationView.superview == nil {
                    self.addSubview(animationView)
                }
                transition.setFrame(view: animationView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - animationSize.width) * 0.5), y: contentY), size: animationSize))
                contentY += animationSize.height + animationSpacing
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentY), size: titleSize))
                contentY += titleSize.height + titleSpacing
            }
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - textSize.width) * 0.5), y: contentY), size: textSize))
                contentY += textSize.height + buttonSpacing
            }
            if let buttonSize, let buttonView = self.button?.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - buttonSize.width) * 0.5), y: contentY), size: buttonSize))
                contentY += buttonSize.height
            }
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

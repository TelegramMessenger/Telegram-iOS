import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AppBundle
import ButtonComponent
import MultilineTextComponent
import BalancedTextComponent
import LottieComponent

final class QuickReplyEmptyStateComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let insets: UIEdgeInsets
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        insets: UIEdgeInsets,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.insets = insets
        self.action = action
    }

    static func ==(lhs: QuickReplyEmptyStateComponent, rhs: QuickReplyEmptyStateComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }

    final class View: UIView {
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let button = ComponentView<Empty>()

        private var component: QuickReplyEmptyStateComponent?
        private weak var componentState: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: QuickReplyEmptyStateComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.componentState = state
            
            let _ = previousComponent
            
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(ButtonTextContentComponent(
                            text: component.strings.QuickReplies_EmptyState_AddButton,
                            badge: 0,
                            textColor: component.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: component.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: component.theme.list.itemCheckColors.fillColor
                        ))
                    ),
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
                containerSize: CGSize(width: min(availableSize.width - 16.0 * 2.0, 280.0), height: 50.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - buttonSize.width) * 0.5), y: availableSize.height - component.insets.bottom - 14.0 - buttonSize.height), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            
            let iconTitleSpacing: CGFloat = 13.0
            let titleTextSpacing: CGFloat = 9.0
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "WriteEmoji"),
                    loop: false
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 120.0)
            )
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.QuickReplies_EmptyState_Title, font: Font.semibold(17.0), textColor: component.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 100.0)
            )
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.QuickReplies_EmptyState_Text, font: Font.regular(15.0), textColor: component.theme.list.itemSecondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 20,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 100.0)
            )
            
            let topInset: CGFloat = component.insets.top
            
            let centralContentsHeight: CGFloat = iconSize.height + iconTitleSpacing + titleSize.height + titleTextSpacing
            var centralContentsY: CGFloat = topInset + floor((buttonFrame.minY - topInset - centralContentsHeight) * 0.426)
            
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: centralContentsY), size: iconSize)
            
            if let iconView = self.icon.view as? LottieComponent.View {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                    iconView.playOnce()
                }
                transition.setFrame(view: iconView, frame: iconFrame)
            }
            centralContentsY += iconSize.height + iconTitleSpacing
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: centralContentsY), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                transition.setPosition(view: titleView, position: titleFrame.center)
            }
            centralContentsY += titleSize.height + titleTextSpacing
            
            let textFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - textSize.width) * 0.5), y: centralContentsY), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
                transition.setPosition(view: textView, position: textFrame.center)
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

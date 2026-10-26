import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import MultilineTextComponent
import PlainButtonComponent

/// An empty-state or error row: centered text and an optional action ("Retry").
public final class NewsStatusRowComponent: Component {
    public let theme: PresentationTheme
    public let text: String
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(theme: PresentationTheme, text: String, actionTitle: String?, action: (() -> Void)?) {
        self.theme = theme
        self.text = text
        self.actionTitle = actionTitle
        self.action = action
    }

    public static func ==(lhs: NewsStatusRowComponent, rhs: NewsStatusRowComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.text == rhs.text && lhs.actionTitle == rhs.actionTitle
    }

    public final class View: UIView {
        private let textView = ComponentView<Empty>()
        private let button = ComponentView<Empty>()

        func update(component: NewsStatusRowComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let theme = component.theme
            let sideInset: CGFloat = 32.0
            let textSize = self.textView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.text, font: Font.regular(15.0), textColor: theme.list.itemSecondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let textFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - textSize.width) * 0.5), y: 32.0), size: textSize)
            if let view = self.textView.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                transition.setFrame(view: view, frame: textFrame)
            }
            var bottom = textFrame.maxY
            if let actionTitle = component.actionTitle, let action = component.action {
                let buttonSize = self.button.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: actionTitle, font: Font.semibold(17.0), textColor: theme.list.itemAccentColor)))),
                        effectAlignment: .center,
                        action: action
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 44.0)
                )
                if let view = self.button.view {
                    if view.superview == nil {
                        self.addSubview(view)
                    }
                    view.isHidden = false
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - buttonSize.width) * 0.5), y: bottom + 12.0), size: buttonSize))
                }
                bottom += 12.0 + buttonSize.height
            } else {
                self.button.view?.isHidden = true
            }
            return CGSize(width: availableSize.width, height: bottom + 32.0)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import GlassBackgroundComponent
import MultilineTextComponent

/// The floating "↑ New posts" / "↑ N new" pill over the Added list.
public final class NewsNewPostsPillComponent: Component {
    public let theme: PresentationTheme
    public let title: String
    public let action: () -> Void

    public init(theme: PresentationTheme, title: String, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.action = action
    }

    public static func ==(lhs: NewsNewPostsPillComponent, rhs: NewsNewPostsPillComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.title == rhs.title
    }

    public final class View: UIView {
        private let backgroundView = GlassBackgroundView()
        private let label = ComponentView<Empty>()
        private var component: NewsNewPostsPillComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.backgroundView)
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        @objc private func tapped() {
            self.component?.action()
        }

        func update(component: NewsNewPostsPillComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            let height: CGFloat = 36.0
            let horizontalInset: CGFloat = 16.0
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.title, font: Font.semibold(15.0), textColor: component.theme.list.itemAccentColor)))),
                environment: {},
                containerSize: CGSize(width: availableSize.width - horizontalInset * 2.0, height: height)
            )
            let size = CGSize(width: labelSize.width + horizontalInset * 2.0, height: height)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundView.update(size: size, cornerRadius: height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            if let view = self.label.view {
                if view.superview == nil {
                    self.backgroundView.contentView.addSubview(view)
                }
                transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: horizontalInset, y: floor((height - labelSize.height) * 0.5)), size: labelSize))
            }
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

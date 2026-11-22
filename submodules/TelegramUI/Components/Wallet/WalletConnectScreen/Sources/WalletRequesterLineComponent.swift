import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent

/// The line that names a Telegram peer asking instead of a dApp (a message widget's bot, widget-sandbox v0.5.0, sdk-v1
/// §5.13: name, username). The name is the bot's to choose, the username is not, so the username is never the part that
/// gives way: the name on one line, shortened to what `· @username` leaves it; when that is not even a few of the name's
/// letters, `@username` alone, shortened in the middle only when even it does not fit, so its `…_bot` end stays. The name
/// takes `nameColor` and the username `usernameColor`: a name that reads like a username does not look like one. Each part
/// is laid out on its own, so a right-to-left name keeps the username's `@` where it belongs.
final class WalletRequesterLineComponent: Component {
    let name: String
    let username: String?
    let font: UIFont
    let nameColor: UIColor
    let usernameColor: UIColor

    init(name: String, username: String?, font: UIFont, nameColor: UIColor, usernameColor: UIColor) {
        self.name = name
        self.username = username
        self.font = font
        self.nameColor = nameColor
        self.usernameColor = usernameColor
    }

    static func ==(lhs: WalletRequesterLineComponent, rhs: WalletRequesterLineComponent) -> Bool {
        return lhs.name == rhs.name && lhs.username == rhs.username && lhs.font == rhs.font && lhs.nameColor == rhs.nameColor && lhs.usernameColor == rhs.usernameColor
    }

    final class View: UIView {
        private let name = ComponentView<Empty>()
        private let username = ComponentView<Empty>()

        func update(component: WalletRequesterLineComponent, availableSize: CGSize) -> CGSize {
            let spacing: CGFloat = 4.0
            let name = component.name.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let username = component.username else {
                self.username.view?.removeFromSuperview()
                let nameSize = self.updateName(name, component: component, width: availableSize.width, height: availableSize.height)
                self.name.view?.frame = CGRect(origin: CGPoint(), size: nameSize)
                return nameSize
            }

            if !name.isEmpty {
                let text = NSMutableAttributedString(string: "· ", font: component.font, textColor: component.nameColor)
                text.append(NSAttributedString(string: "@\(username)", font: component.font, textColor: component.usernameColor))
                let usernameSize = self.updateUsername(text, availableSize: availableSize)
                let nameWidth = availableSize.width - usernameSize.width - spacing
                if nameWidth >= ceil(component.font.pointSize * 3.0) {
                    let nameSize = self.updateName(name, component: component, width: nameWidth, height: availableSize.height)
                    let height = max(nameSize.height, usernameSize.height)
                    self.name.view?.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((height - nameSize.height) / 2.0)), size: nameSize)
                    self.username.view?.frame = CGRect(origin: CGPoint(x: nameSize.width + spacing, y: floor((height - usernameSize.height) / 2.0)), size: usernameSize)
                    return CGSize(width: nameSize.width + spacing + usernameSize.width, height: height)
                }
            }

            self.name.view?.removeFromSuperview()
            let usernameSize = self.updateUsername(NSAttributedString(string: "@\(username)", font: component.font, textColor: component.usernameColor), availableSize: availableSize)
            self.username.view?.frame = CGRect(origin: CGPoint(), size: usernameSize)
            return usernameSize
        }

        private func updateName(_ name: String, component: WalletRequesterLineComponent, width: CGFloat, height: CGFloat) -> CGSize {
            let size = self.name.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: name, font: component.font, textColor: component.nameColor)),
                    truncationType: .end,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: width, height: height)
            )
            if let view = self.name.view, view.superview == nil {
                self.addSubview(view)
            }
            return size
        }

        private func updateUsername(_ text: NSAttributedString, availableSize: CGSize) -> CGSize {
            let size = self.username.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(text),
                    truncationType: .middle,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.username.view, view.superview == nil {
                self.addSubview(view)
            }
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

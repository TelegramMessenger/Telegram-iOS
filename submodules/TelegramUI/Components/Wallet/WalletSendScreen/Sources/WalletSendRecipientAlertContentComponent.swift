import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AlertComponent
import MultilineTextComponent
import PlainButtonComponent

final class WalletSendRecipientAlertContentComponent: Component {
    typealias EnvironmentType = AlertComponentEnvironment

    let title: String
    let recipientName: String?
    let address: String
    let openChat: (() -> Void)?
    let copyAddress: () -> Void

    init(title: String, recipientName: String?, address: String, openChat: (() -> Void)?, copyAddress: @escaping () -> Void) {
        self.title = title
        self.recipientName = recipientName
        self.address = address
        self.openChat = openChat
        self.copyAddress = copyAddress
    }

    static func ==(lhs: WalletSendRecipientAlertContentComponent, rhs: WalletSendRecipientAlertContentComponent) -> Bool {
        return lhs.title == rhs.title
            && lhs.recipientName == rhs.recipientName
            && lhs.address == rhs.address
            && (lhs.openChat == nil) == (rhs.openChat == nil)
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let address = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletSendRecipientAlertContentComponent, availableSize: CGSize, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            let theme = environment[AlertComponentEnvironment.self].theme
            let strings = environment[AlertComponentEnvironment.self].strings
            let textInset: CGFloat = -6.0
            let addressInset: CGFloat = -14.0
            let textWidth = availableSize.width - textInset * 2.0
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.bold(17.0), textColor: theme.actionSheet.primaryTextColor)),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: .greatestFiniteMagnitude)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.isAccessibilityElement = true
                titleView.accessibilityLabel = component.title
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: textInset, y: 0.0), size: titleSize))
            }

            let text = NSMutableAttributedString()
            let recipientLinkAttribute = NSAttributedString.Key("WalletRecipientPeer")
            if let recipientName = component.recipientName {
                let linkedAddress = strings.Wallet_Recipient_LinkedAddress(recipientName)
                text.append(NSAttributedString(string: linkedAddress.string, font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor))
                for range in linkedAddress.ranges where range.index == 0 {
                    text.addAttribute(.foregroundColor, value: theme.actionSheet.controlAccentColor, range: range.range)
                    if component.openChat != nil {
                        text.addAttribute(recipientLinkAttribute, value: true, range: range.range)
                    }
                }
            } else {
                text.append(NSAttributedString(string: strings.Wallet_Recipient_UnlinkedAddress, font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor))
            }
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(text),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: theme.actionSheet.controlAccentColor.withMultipliedAlpha(0.2),
                    highlightAction: { attributes in
                        return attributes[recipientLinkAttribute] != nil ? recipientLinkAttribute : nil
                    },
                    tapAction: { attributes, _ in
                        if attributes[recipientLinkAttribute] != nil {
                            component.openChat?()
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: .greatestFiniteMagnitude)
            )
            let textFrame = CGRect(origin: CGPoint(x: textInset, y: titleSize.height + 12.0), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.isAccessibilityElement = true
                textView.accessibilityLabel = text.string
                if let recipientName = component.recipientName, let openChat = component.openChat {
                    textView.accessibilityCustomActions = [UIAccessibilityCustomAction(name: recipientName, actionHandler: { _ in
                        openChat()
                        return true
                    })]
                } else {
                    textView.accessibilityCustomActions = nil
                }
                transition.setFrame(view: textView, frame: textFrame)
            }

            let addressText = NSMutableAttributedString()
            let addressFont = Font.monospace(18.0)
            var index = component.address.startIndex
            var groupIndex = 0
            while index < component.address.endIndex {
                let row = groupIndex / 4
                let column = groupIndex % 4
                let color = (row + column).isMultiple(of: 2) ? theme.actionSheet.primaryTextColor : theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.32)
                if groupIndex != 0 {
                    addressText.append(NSAttributedString(string: column == 0 ? "\n" : " ", font: addressFont, textColor: color))
                }
                let endIndex = component.address.index(index, offsetBy: 4, limitedBy: component.address.endIndex) ?? component.address.endIndex
                addressText.append(NSAttributedString(string: String(component.address[index ..< endIndex]), font: addressFont, textColor: color))
                index = endIndex
                groupIndex += 1
            }
            let addressWidth = availableSize.width - addressInset * 2.0
            let addressSize = self.address.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(addressText),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    background: AnyComponent(RoundedRectangle(
                        color: theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1),
                        cornerRadius: 14.0
                    )),
                    minSize: CGSize(width: addressWidth, height: 0.0),
                    contentInsets: UIEdgeInsets(top: 16.0, left: 16.0, bottom: 13.0, right: 16.0),
                    action: component.copyAddress,
                    isEnabled: !component.address.isEmpty
                )),
                environment: {},
                containerSize: CGSize(width: addressWidth, height: .greatestFiniteMagnitude)
            )
            let addressFrame = CGRect(x: addressInset, y: textFrame.maxY + 14.0, width: addressWidth, height: addressSize.height)
            if let addressView = self.address.view {
                if addressView.superview == nil {
                    self.addSubview(addressView)
                }
                addressView.isAccessibilityElement = true
                addressView.accessibilityLabel = component.address
                transition.setFrame(view: addressView, frame: addressFrame)
            }

            return CGSize(width: availableSize.width, height: addressFrame.maxY)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ChatListTitleView
import NavigationBarComponent

/// The chat list's proxy status as a bar button's content (`NavigationBarComponent.Button.Content.custom`):
/// a 30pt `ChatTitleProxyNode` centered in a 44pt cell. The bar handles taps and highlight.
public final class ChatListProxyButtonComponent: Component {
    public typealias EnvironmentType = NavigationButtonEnvironment

    public let theme: PresentationTheme
    public let status: ChatTitleProxyStatus

    public init(theme: PresentationTheme, status: ChatTitleProxyStatus) {
        self.theme = theme
        self.status = status
    }

    public static func ==(lhs: ChatListProxyButtonComponent, rhs: ChatListProxyButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var proxyNode: ChatTitleProxyNode?

        func update(component: ChatListProxyButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonEnvironment>, transition: ComponentTransition) -> CGSize {
            let proxyNode: ChatTitleProxyNode
            if let current = self.proxyNode {
                proxyNode = current
            } else {
                proxyNode = ChatTitleProxyNode(theme: component.theme)
                proxyNode.isUserInteractionEnabled = false
                self.proxyNode = proxyNode
                self.addSubnode(proxyNode)
            }

            let size = CGSize(width: 44.0, height: availableSize.height)
            let proxySize = CGSize(width: 30.0, height: 30.0)

            proxyNode.theme = component.theme
            proxyNode.status = component.status

            proxyNode.frame = CGRect(origin: CGPoint(x: floor((size.width - proxySize.width) / 2.0), y: floor((availableSize.height - proxySize.height) / 2.0)), size: proxySize)

            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

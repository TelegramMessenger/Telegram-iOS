import UIKit
import ComponentFlow
import ViewControllerComponent

// Hosts an existing, virtualized sheet page in the navigation stack. Inactive
// pages retain their scroll position while the sheet scrolls the active page.
final class ShareScreenNavigationPage: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    let content: UIView
    let size: CGSize
    let offset: CGFloat
    let backgroundColor: UIColor

    init(content: UIView, size: CGSize, offset: CGFloat, backgroundColor: UIColor) {
        self.content = content
        self.size = size
        self.offset = offset
        self.backgroundColor = backgroundColor
    }

    static func ==(lhs: ShareScreenNavigationPage, rhs: ShareScreenNavigationPage) -> Bool {
        return lhs.content === rhs.content && lhs.size == rhs.size && lhs.offset == rhs.offset && lhs.backgroundColor == rhs.backgroundColor
    }

    func makeView() -> UIView { return UIView() }

    func update(view: UIView, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        view.backgroundColor = self.backgroundColor
        if self.content.superview !== view { view.addSubview(self.content) }
        self.content.frame = CGRect(origin: CGPoint(x: 0.0, y: self.offset), size: self.size)
        return self.size
    }
}

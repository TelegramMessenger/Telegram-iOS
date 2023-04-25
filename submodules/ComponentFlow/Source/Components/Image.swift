import Foundation
import UIKit

public final class Image: Component {
    public let image: UIImage?
    public let tintColor: UIColor?
    public let size: CGSize?

    public init(
        image: UIImage?,
        tintColor: UIColor? = nil,
        size: CGSize? = nil
    ) {
        self.image = image
        self.tintColor = tintColor
        self.size = size
    }

    public static func ==(lhs: Image, rhs: Image) -> Bool {
        if lhs.image !== rhs.image {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }

    public final class View: UIImageView {
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: Image, availableSize: CGSize, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.image = component.image
            self.tintColor = component.tintColor

            return component.size ?? availableSize
        }
    }

    public func makeView() -> View {
        return View()
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

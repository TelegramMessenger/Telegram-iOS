import Foundation
import UIKit

public final class Image: Component {
    public let image: UIImage?
    public let tintColor: UIColor?
    public let size: CGSize?
    public let contentMode: UIImageView.ContentMode
    public let cornerRadius: CGFloat
    public let flipHorizontally: Bool

    public init(
        image: UIImage?,
        tintColor: UIColor? = nil,
        size: CGSize? = nil,
        contentMode: UIImageView.ContentMode = .scaleToFill,
        cornerRadius: CGFloat = 0.0,
        flipHorizontally: Bool = false
    ) {
        self.image = image
        self.tintColor = tintColor
        self.size = size
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.flipHorizontally = flipHorizontally
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
        if lhs.contentMode != rhs.contentMode {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        if lhs.flipHorizontally != rhs.flipHorizontally {
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

        func update(component: Image, availableSize: CGSize, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if component.flipHorizontally, let cgImage = component.image?.cgImage {
                self.image = UIImage(cgImage: cgImage, scale: component.image?.scale ?? 0.0, orientation: .upMirrored)
            } else {
                self.image = component.image
            }
            self.contentMode = component.contentMode
            self.clipsToBounds = component.cornerRadius > 0.0
            
            transition.setCornerRadius(layer: self.layer, cornerRadius: component.cornerRadius)
            transition.setTintColor(view: self, color: component.tintColor ?? .white)
            
            switch component.contentMode {
            case .center:
                return component.image?.size ?? availableSize
            default:
                return component.size ?? availableSize
            }
        }
    }

    public func makeView() -> View {
        return View()
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

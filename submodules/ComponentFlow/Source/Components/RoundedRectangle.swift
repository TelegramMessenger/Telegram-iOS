import Foundation
import UIKit

public final class RoundedRectangle: Component {
    public let color: UIColor
    public let cornerRadius: CGFloat

    public init(color: UIColor, cornerRadius: CGFloat) {
        self.color = color
        self.cornerRadius = cornerRadius
    }

    public static func ==(lhs: RoundedRectangle, rhs: RoundedRectangle) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.cornerRadius != rhs.cornerRadius {
            return false
        }
        return true
    }
    
    public final class View: UIImageView {
        var component: RoundedRectangle?
        
        func update(component: RoundedRectangle, availableSize: CGSize, transition: Transition) -> CGSize {
            if self.component != component {
                let imageSize = CGSize(width: component.cornerRadius * 2.0, height: component.cornerRadius * 2.0)
                UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
                if let context = UIGraphicsGetCurrentContext() {
                    context.setFillColor(component.color.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: imageSize))
                }
                self.image = UIGraphicsGetImageFromCurrentImageContext()?.stretchableImage(withLeftCapWidth: Int(component.cornerRadius), topCapHeight: Int(component.cornerRadius))
                UIGraphicsEndImageContext()
            }

            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

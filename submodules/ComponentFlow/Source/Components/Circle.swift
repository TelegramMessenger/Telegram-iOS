import Foundation
import UIKit

public final class Circle: Component {
    public let color: UIColor
    public let size: CGSize
    public let width: CGFloat
    
    public init(color: UIColor, size: CGSize, width: CGFloat) {
        self.color = color
        self.size = size
        self.width = width
    }

    public static func ==(lhs: Circle, rhs: Circle) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.width != rhs.width {
            return false
        }
        return true
    }
    
    public final class View: UIImageView {
        var component: Circle?
        var currentSize: CGSize?
        
        func update(component: Circle, availableSize: CGSize, transition: Transition) -> CGSize {
            let size = CGSize(width: min(availableSize.width, component.size.width), height: min(availableSize.height, component.size.height))
            
            if self.currentSize != size || self.component != component {
                self.currentSize = size
                self.component = component
                
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                if let context = UIGraphicsGetCurrentContext() {
                    context.setStrokeColor(component.color.cgColor)
                    context.setLineWidth(component.width)
                    context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: component.width / 2.0, dy: component.width / 2.0))
                }
                self.image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }

            return size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

import Foundation
import UIKit

public final class Circle: Component {
    public let fillColor: UIColor
    public let strokeColor: UIColor
    public let strokeWidth: CGFloat
    public let size: CGSize
    
    public init(fillColor: UIColor = .clear, strokeColor: UIColor = .clear, strokeWidth: CGFloat = 0.0, size: CGSize) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.size = size
    }

    public static func ==(lhs: Circle, rhs: Circle) -> Bool {
        if !lhs.fillColor.isEqual(rhs.fillColor) {
            return false
        }
        if !lhs.strokeColor.isEqual(rhs.strokeColor) {
            return false
        }
        if lhs.strokeWidth != rhs.strokeWidth {
            return false
        }
        if lhs.size != rhs.size {
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
                    context.setFillColor(component.fillColor.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                    if component.strokeWidth > 0.0 {
                        context.setStrokeColor(component.strokeColor.cgColor)
                        context.setLineWidth(component.strokeWidth)
                        context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: component.strokeWidth / 2.0, dy: component.strokeWidth / 2.0))
                    }
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

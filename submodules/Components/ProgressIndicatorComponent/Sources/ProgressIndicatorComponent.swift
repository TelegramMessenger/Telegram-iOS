import Foundation
import UIKit
import Display
import ComponentFlow

public final class ProgressIndicatorComponent: Component {
    public let diameter: CGFloat
    public let value: Double
    public let backgroundColor: UIColor
    public let foregroundColor: UIColor
    
    public init(
        diameter: CGFloat,
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        value: Double
    ) {
        self.diameter = diameter
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.value = value
    }

    public static func ==(lhs: ProgressIndicatorComponent, rhs: ProgressIndicatorComponent) -> Bool {
        if lhs.diameter != rhs.diameter {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var currentComponent: ProgressIndicatorComponent?
        
        private let foregroundShapeLayer: SimpleShapeLayer
        
        public init() {
            self.foregroundShapeLayer = SimpleShapeLayer()
            self.foregroundShapeLayer.isOpaque = false
            self.foregroundShapeLayer.backgroundColor = nil
            self.foregroundShapeLayer.fillColor = nil
            self.foregroundShapeLayer.lineCap = .round
            
            super.init(frame: CGRect())
            
            let shapeLayer = self.layer as! CAShapeLayer
            shapeLayer.isOpaque = false
            shapeLayer.backgroundColor = nil
            shapeLayer.fillColor = nil
            
            self.layer.addSublayer(self.foregroundShapeLayer)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public static var layerClass: AnyClass {
            return CAShapeLayer.self
        }
        
        func update(component: ProgressIndicatorComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            let lineWidth: CGFloat = 1.33
            let size = CGSize(width: component.diameter, height: component.diameter)

            let shapeLayer = self.layer as! CAShapeLayer
            
            if self.currentComponent?.backgroundColor != component.backgroundColor {
                shapeLayer.strokeColor = component.backgroundColor.cgColor
                shapeLayer.lineWidth = lineWidth
            }
            
            if self.currentComponent?.foregroundColor != component.foregroundColor {
                self.foregroundShapeLayer.strokeColor = component.foregroundColor.cgColor
                self.foregroundShapeLayer.lineWidth = lineWidth
            }
            
            if self.currentComponent?.diameter != component.diameter {
                let path = UIBezierPath(arcCenter: CGPoint(x: component.diameter / 2.0, y: component.diameter / 2.0), radius: component.diameter / 2.0, startAngle: -CGFloat.pi / 2.0, endAngle: 2.0 * CGFloat.pi - CGFloat.pi / 2.0, clockwise: true).cgPath
                shapeLayer.path = path
                self.foregroundShapeLayer.path = path
                
                self.foregroundShapeLayer.frame = CGRect(origin: CGPoint(), size: size)
            }
            
            if self.currentComponent != nil {
                let previousValue: CGFloat = self.foregroundShapeLayer.presentation()?.strokeEnd ?? self.foregroundShapeLayer.strokeEnd
                self.foregroundShapeLayer.animate(from: CGFloat(previousValue) as NSNumber, to: CGFloat(component.value) as NSNumber, keyPath: "strokeEnd", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.12)
            }
            self.foregroundShapeLayer.strokeEnd = CGFloat(component.value)
            
            self.currentComponent = component
            
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

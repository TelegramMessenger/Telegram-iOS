import Foundation
import UIKit
import Display

private extension SimpleShapeLayer {
    func animateStrokeStart(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "strokeStart", timingFunction: timingFunction, duration: duration, delay: delay, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animateStrokeEnd(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "strokeEnd", timingFunction: timingFunction, duration: duration, delay: delay, removeOnCompletion: removeOnCompletion, completion: completion)
    }
}

final class RecordingProgressView: UIView {
    let shapeLayer = SimpleShapeLayer()
    
    var value: CGFloat = 0.0 {
        didSet {
            if abs(self.shapeLayer.strokeEnd - self.value) >= 0.01 {
                if abs(oldValue - self.value) < 0.1 {
                    let previousStrokeEnd = self.shapeLayer.strokeEnd
                    self.shapeLayer.strokeEnd = self.value
                    self.shapeLayer.animateStrokeEnd(from: previousStrokeEnd, to: self.shapeLayer.strokeEnd, duration: abs(previousStrokeEnd - self.value) * 60.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue)
                } else {
                    self.shapeLayer.strokeEnd = self.value
                    self.shapeLayer.removeAllAnimations()
                }
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.shapeLayer.fillColor = UIColor.clear.cgColor
        self.shapeLayer.strokeColor = UIColor(white: 1.0, alpha: 0.6).cgColor
        self.shapeLayer.lineWidth = 4.0
        self.shapeLayer.lineCap = .round
        self.shapeLayer.transform = CATransform3DMakeRotation(-.pi / 2.0, 0.0, 0.0, 1.0)
        self.shapeLayer.strokeEnd = 0.0
        
        self.layer.addSublayer(self.shapeLayer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if self.shapeLayer.frame != self.bounds {
            self.shapeLayer.frame = self.bounds
            
            self.shapeLayer.path = CGPath(ellipseIn: self.bounds.insetBy(dx: self.shapeLayer.lineWidth, dy: self.shapeLayer.lineWidth), transform: nil)
        }
    }
}

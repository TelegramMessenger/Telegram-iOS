import UIKit

extension CALayer {
    internal func animate(from from: NSValue, to: NSValue, keyPath: String, timingFunction: String, duration: NSTimeInterval) {
        let k = Float(UIView.animationDurationFactor())
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)
        animation.removedOnCompletion = true
        animation.fillMode = kCAFillModeForwards
        animation.speed = speed
        
        self.addAnimation(animation, forKey: keyPath)
        
        self.setValue(to, forKey: keyPath)
    }
    
    internal func animateAlpha(from from: CGFloat, to: CGFloat, duration: NSTimeInterval) {
        self.animate(from: NSNumber(float: Float(from)), to: NSNumber(float: Float(to)), keyPath: "opacity", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration)
    }
    
    internal func animatePosition(from from: CGPoint, to: CGPoint, duration: NSTimeInterval) {
        self.animate(from: NSValue(CGPoint: from), to: NSValue(CGPoint: to), keyPath: "position", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration)
    }
}

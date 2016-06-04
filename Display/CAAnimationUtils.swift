import UIKit

@objc private class CALayerAnimationDelegate: NSObject {
    var completion: (Bool -> Void)?
    
    init(completion: (Bool -> Void)?) {
        self.completion = completion
        
        super.init()
    }
    
    @objc override func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        if let completion = self.completion {
            completion(flag)
        }
    }
}

private let completionKey = "CAAnimationUtils_completion"

public extension CAAnimation {
    public var completion: (Bool -> Void)? {
        get {
            if let delegate = self.delegate as? CALayerAnimationDelegate {
                return delegate.completion
            } else {
                return nil
            }
        } set(value) {
            if let delegate = self.delegate as? CALayerAnimationDelegate {
                delegate.completion = value
            } else {
                self.delegate = CALayerAnimationDelegate(completion: value)
            }
        }
    }
}

public extension CALayer {
    public func animate(from from: NSValue, to: NSValue, keyPath: String, timingFunction: String, duration: NSTimeInterval, removeOnCompletion: Bool = true, completion: (Bool -> Void)? = nil) {
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
        animation.removedOnCompletion = removeOnCompletion
        animation.fillMode = kCAFillModeForwards
        animation.speed = speed
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        self.addAnimation(animation, forKey: keyPath)
        
        //self.setValue(to, forKey: keyPath)
    }
    
    public func animateAdditive(from from: NSValue, to: NSValue, keyPath: String, key: String, timingFunction: String, duration: NSTimeInterval, removeOnCompletion: Bool = true, completion: (Bool -> Void)? = nil) {
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
        animation.removedOnCompletion = removeOnCompletion
        animation.fillMode = kCAFillModeForwards
        animation.speed = speed
        animation.additive = true
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        self.addAnimation(animation, forKey: key)
    }
    
    public func animateAlpha(from from: CGFloat, to: CGFloat, duration: NSTimeInterval, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(float: Float(from)), to: NSNumber(float: Float(to)), keyPath: "opacity", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    public func animateScale(from from: CGFloat, to: CGFloat, duration: NSTimeInterval) {
        self.animate(from: NSNumber(float: Float(from)), to: NSNumber(float: Float(to)), keyPath: "transform.scale", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration, removeOnCompletion: true, completion: nil)
    }
    
    internal func animatePosition(from from: CGPoint, to: CGPoint, duration: NSTimeInterval, completion: (Bool -> Void)? = nil) {
        self.animate(from: NSValue(CGPoint: from), to: NSValue(CGPoint: to), keyPath: "position", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration, removeOnCompletion: true, completion: completion)
    }
    
    public func animateBoundsOriginYAdditive(from from: CGFloat, to: CGFloat, duration: NSTimeInterval) {
        self.animateAdditive(from: from as NSNumber, to: to as NSNumber, keyPath: "bounds.origin.y", key: "boundsOriginYAdditive", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration, removeOnCompletion: true)
    }
}

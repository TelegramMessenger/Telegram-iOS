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
private let springKey = "CAAnimationUtilsSpringCurve"

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
        if timingFunction == springKey {
            let animation = CASpringAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.damping = 500.0
            animation.stiffness = 1000.0
            animation.mass = 3.0
            animation.duration = animation.settlingDuration
            animation.removedOnCompletion = removeOnCompletion
            animation.fillMode = kCAFillModeForwards
            if let completion = completion {
                animation.delegate = CALayerAnimationDelegate(completion: completion)
            }
            
            let k = Float(UIView.animationDurationFactor())
            var speed: Float = 1.0
            if k != 0 && k != 1 {
                speed = Float(1.0) / k
            }
            
            animation.speed = speed * Float(animation.duration / duration)
            
            self.addAnimation(animation, forKey: keyPath)
        } else {
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
        }
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
        if from == to {
            return
        }
        self.animate(from: NSValue(CGPoint: from), to: NSValue(CGPoint: to), keyPath: "position", timingFunction: springKey, duration: duration, removeOnCompletion: true, completion: completion)
    }
    
    internal func animateBounds(from from: CGRect, to: CGRect, duration: NSTimeInterval, completion: (Bool -> Void)? = nil) {
        if from == to {
            return
        }
        self.animate(from: NSValue(CGRect: from), to: NSValue(CGRect: to), keyPath: "bounds", timingFunction: springKey, duration: duration, removeOnCompletion: true, completion: completion)
    }
    
    public func animateBoundsOriginYAdditive(from from: CGFloat, to: CGFloat, duration: NSTimeInterval) {
        self.animateAdditive(from: from as NSNumber, to: to as NSNumber, keyPath: "bounds.origin.y", key: "boundsOriginYAdditive", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration, removeOnCompletion: true)
    }
    
    public func animateFrame(from from: CGRect, to: CGRect, duration: NSTimeInterval, spring: Bool = false, completion: (Bool -> Void)? = nil) {
        if from == to {
            return
        }
        self.animatePosition(from: CGPoint(x: from.midX, y: from.midY), to: CGPoint(x: to.midX, y: to.midY), duration: duration, completion: nil)
        self.animateBounds(from: CGRect(origin: self.bounds.origin, size: from.size), to: CGRect(origin: self.bounds.origin, size: to.size), duration: duration, completion: completion)
    }
}

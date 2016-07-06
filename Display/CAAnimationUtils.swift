import UIKit

@objc private class CALayerAnimationDelegate: NSObject {
    var completion: ((Bool) -> Void)?
    
    init(completion: ((Bool) -> Void)?) {
        self.completion = completion
        
        super.init()
    }
    
    @objc override func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let completion = self.completion {
            completion(flag)
        }
    }
}

private let completionKey = "CAAnimationUtils_completion"

public let kCAMediaTimingFunctionSpring = "CAAnimationUtilsSpringCurve"

public extension CAAnimation {
    public var completion: ((Bool) -> Void)? {
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
    public func animate(from: NSValue, to: NSValue, keyPath: String, timingFunction: String, duration: Double, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        if timingFunction == kCAMediaTimingFunctionSpring {
            let animation = makeSpringAnimation(keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.isRemovedOnCompletion = removeOnCompletion
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
            
            self.add(animation, forKey: keyPath)
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
            animation.isRemovedOnCompletion = removeOnCompletion
            animation.fillMode = kCAFillModeForwards
            animation.speed = speed
            if let completion = completion {
                animation.delegate = CALayerAnimationDelegate(completion: completion)
            }
            
            self.add(animation, forKey: keyPath)
        }
    }
    
    public func animateAdditive(from: NSValue, to: NSValue, keyPath: String, key: String, timingFunction: String, duration: Double, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
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
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = kCAFillModeForwards
        animation.speed = speed
        animation.isAdditive = true
        if let completion = completion {
            animation.delegate = CALayerAnimationDelegate(completion: completion)
        }
        
        self.add(animation, forKey: key)
    }
    
    public func animateAlpha(from: CGFloat, to: CGFloat, duration: Double, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "opacity", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    public func animateScale(from: CGFloat, to: CGFloat, duration: Double) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "transform.scale", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration, removeOnCompletion: true, completion: nil)
    }
    
    func animatePosition(from: CGPoint, to: CGPoint, duration: Double, timingFunction: String, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        if from == to {
            return
        }
        self.animate(from: NSValue(cgPoint: from), to: NSValue(cgPoint: to), keyPath: "position", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animateBounds(from: CGRect, to: CGRect, duration: Double, timingFunction: String, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        if from == to {
            return
        }
        self.animate(from: NSValue(cgRect: from), to: NSValue(cgRect: to), keyPath: "bounds", timingFunction: timingFunction, duration: duration, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    public func animateBoundsOriginYAdditive(from: CGFloat, to: CGFloat, duration: Double) {
        self.animateAdditive(from: from as NSNumber, to: to as NSNumber, keyPath: "bounds.origin.y", key: "boundsOriginYAdditive", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: duration, removeOnCompletion: true)
    }
    
    public func animateFrame(from: CGRect, to: CGRect, duration: Double, timingFunction: String, completion: ((Bool) -> Void)? = nil) {
        if from == to {
            return
        }
        self.animatePosition(from: CGPoint(x: from.midX, y: from.midY), to: CGPoint(x: to.midX, y: to.midY), duration: duration, timingFunction: timingFunction, completion: nil)
        self.animateBounds(from: CGRect(origin: self.bounds.origin, size: from.size), to: CGRect(origin: self.bounds.origin, size: to.size), duration: duration, timingFunction: timingFunction, completion: completion)
    }
}

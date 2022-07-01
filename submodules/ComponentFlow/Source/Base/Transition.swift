import Foundation
import UIKit

#if targetEnvironment(simulator)
@_silgen_name("UIAnimationDragCoefficient") func UIAnimationDragCoefficient() -> Float
#endif

private extension UIView {
    static var animationDurationFactor: Double {
        #if targetEnvironment(simulator)
        return Double(UIAnimationDragCoefficient())
        #else
        return 1.0
        #endif
    }
}

@objc private class CALayerAnimationDelegate: NSObject, CAAnimationDelegate {
    private let keyPath: String?
    var completion: ((Bool) -> Void)?

    init(animation: CAAnimation, completion: ((Bool) -> Void)?) {
        if let animation = animation as? CABasicAnimation {
            self.keyPath = animation.keyPath
        } else {
            self.keyPath = nil
        }
        self.completion = completion

        super.init()
    }

    @objc func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let anim = anim as? CABasicAnimation {
            if anim.keyPath != self.keyPath {
                return
            }
        }
        if let completion = self.completion {
            completion(flag)
        }
    }
}

private func makeSpringAnimation(keyPath: String) -> CASpringAnimation {
    let springAnimation = CASpringAnimation(keyPath: keyPath)
    springAnimation.mass = 3.0;
    springAnimation.stiffness = 1000.0
    springAnimation.damping = 500.0
    springAnimation.duration = 0.5
    springAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    return springAnimation
}

private extension CALayer {
    func makeAnimation(from: AnyObject, to: AnyObject, keyPath: String, duration: Double, delay: Double, curve: Transition.Animation.Curve, removeOnCompletion: Bool, additive: Bool, completion: ((Bool) -> Void)? = nil) -> CAAnimation {
        switch curve {
        case .spring:
            let animation = makeSpringAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.isRemovedOnCompletion = removeOnCompletion
            animation.fillMode = .forwards
            if let completion = completion {
                animation.delegate = CALayerAnimationDelegate(animation: animation, completion: completion)
            }

            let k = Float(UIView.animationDurationFactor)
            var speed: Float = 1.0
            if k != 0 && k != 1 {
                speed = Float(1.0) / k
            }

            animation.speed = speed * Float(animation.duration / duration)
            animation.isAdditive = additive

            if !delay.isZero {
                animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil) + delay * UIView.animationDurationFactor
                animation.fillMode = .both
            }

            return animation
        default:
            let k = Float(UIView.animationDurationFactor)
            var speed: Float = 1.0
            if k != 0 && k != 1 {
                speed = Float(1.0) / k
            }

            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.duration = duration
            animation.timingFunction = curve.asTimingFunction()
            animation.isRemovedOnCompletion = removeOnCompletion
            animation.fillMode = .forwards
            animation.speed = speed
            animation.isAdditive = additive
            if let completion = completion {
                animation.delegate = CALayerAnimationDelegate(animation: animation, completion: completion)
            }

            if !delay.isZero {
                animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil) + delay * UIView.animationDurationFactor
                animation.fillMode = .both
            }

            return animation
        }
    }

    func animate(from: AnyObject, to: AnyObject, keyPath: String, duration: Double, delay: Double, curve: Transition.Animation.Curve, removeOnCompletion: Bool, additive: Bool, completion: ((Bool) -> Void)? = nil) {
        let animation = self.makeAnimation(from: from, to: to, keyPath: keyPath, duration: duration, delay: delay, curve: curve, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)
        self.add(animation, forKey: additive ? nil : keyPath)
    }
}

private extension Transition.Animation.Curve {
    func asTimingFunction() -> CAMediaTimingFunction {
        switch self {
        case .easeInOut:
            return CAMediaTimingFunction(name: .easeInEaseOut)
        case let .custom(a, b, c, d):
            return CAMediaTimingFunction(controlPoints: a, b, c, d)
        case .spring:
            preconditionFailure()
        }
    }
}

public struct Transition {
    public enum Animation {
        public enum Curve {
            case easeInOut
            case spring
            case custom(Float, Float, Float, Float)
        }

        case none
        case curve(duration: Double, curve: Curve)
    }
    
    public var animation: Animation
    private var _userData: [Any] = []

    public func userData<T>(_ type: T.Type) -> T? {
        for item in self._userData {
            if let item = item as? T {
                return item
            }
        }
        return nil
    }

    public func withUserData(_ userData: Any) -> Transition {
        var result = self
        result._userData.append(userData)
        return result
    }
    
    public func withAnimation(_ animation: Animation) -> Transition {
        var result = self
        result.animation = animation
        return result
    }
    
    public func withAnimationIfAnimated(_ animation: Animation) -> Transition {
        switch self.animation {
        case .none:
            return self
        default:
            var result = self
            result.animation = animation
            return result
        }
    }
    
    public static var immediate: Transition = Transition(animation: .none)
    
    public static func easeInOut(duration: Double) -> Transition {
        return Transition(animation: .curve(duration: duration, curve: .easeInOut))
    }

    public init(animation: Animation) {
        self.animation = animation
    }
    
    public func setFrame(view: UIView, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        if view.frame == frame {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.bounds = CGRect(origin: view.bounds.origin, size: frame.size)
            view.layer.position = CGPoint(x: frame.midX, y: frame.midY)
            view.layer.removeAnimation(forKey: "position")
            view.layer.removeAnimation(forKey: "bounds")
            completion?(true)
        case .curve:
            let previousPosition = view.layer.presentation()?.position ?? view.center
            let previousBounds = view.layer.presentation()?.bounds ?? view.bounds
            
            view.bounds = CGRect(origin: previousBounds.origin, size: frame.size)
            view.center = CGPoint(x: frame.midX, y: frame.midY)

            self.animatePosition(view: view, from: previousPosition, to: view.center, completion: completion)
            self.animateBounds(view: view, from: previousBounds, to: view.bounds)
        }
    }
    
    public func setBounds(view: UIView, bounds: CGRect, completion: ((Bool) -> Void)? = nil) {
        if view.bounds == bounds {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.bounds = bounds
            view.layer.removeAnimation(forKey: "bounds")
            completion?(true)
        case .curve:
            let previousBounds = view.layer.presentation()?.bounds ?? view.bounds
            view.bounds = bounds

            self.animateBounds(view: view, from: previousBounds, to: view.bounds, completion: completion)
        }
    }
    
    public func setPosition(view: UIView, position: CGPoint, completion: ((Bool) -> Void)? = nil) {
        if view.center == position {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.center = position
            view.layer.removeAnimation(forKey: "position")
            completion?(true)
        case .curve:
            let previousPosition = view.layer.presentation()?.position ?? view.center
            view.center = position

            self.animatePosition(view: view, from: previousPosition, to: view.center, completion: completion)
        }
    }
    
    public func setAlpha(view: UIView, alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        if view.alpha == alpha {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.alpha = alpha
            view.layer.removeAnimation(forKey: "opacity")
            completion?(true)
        case .curve:
            let previousAlpha = (view.layer.presentation()?.opacity).flatMap(CGFloat.init) ?? view.alpha
            view.alpha = alpha
            self.animateAlpha(view: view, from: previousAlpha, to: alpha, completion: completion)
        }
    }
    
    public func setScale(view: UIView, scale: CGFloat, completion: ((Bool) -> Void)? = nil) {
        let t = view.layer.presentation()?.transform ?? view.layer.transform
        let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        if currentScale == scale {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            completion?(true)
        case let .curve(duration, curve):
            let previousScale = currentScale
            view.layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            view.layer.animate(
                from: previousScale as NSNumber,
                to: scale as NSNumber,
                keyPath: "transform.scale",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }
    
    public func setSublayerTransform(view: UIView, transform: CATransform3D, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            view.layer.sublayerTransform = transform
            completion?(true)
        case let .curve(duration, curve):
            let previousValue: CATransform3D
            if let presentation = view.layer.presentation() {
                previousValue = presentation.sublayerTransform
            } else {
                previousValue = view.layer.sublayerTransform
            }
            view.layer.sublayerTransform = transform
            view.layer.animate(
                from: NSValue(caTransform3D: previousValue),
                to: NSValue(caTransform3D: transform),
                keyPath: "sublayerTransform",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }

    public func animateScale(view: UIView, from fromValue: CGFloat, to toValue: CGFloat, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            view.layer.animate(
                from: fromValue as NSNumber,
                to: toValue as NSNumber,
                keyPath: "transform.scale",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animateAlpha(view: UIView, from fromValue: CGFloat, to toValue: CGFloat, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            view.layer.animate(
                from: fromValue as NSNumber,
                to: toValue as NSNumber,
                keyPath: "opacity",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animatePosition(view: UIView, from fromValue: CGPoint, to toValue: CGPoint, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            view.layer.animate(
                from: NSValue(cgPoint: fromValue),
                to: NSValue(cgPoint: toValue),
                keyPath: "position",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animateBounds(view: UIView, from fromValue: CGRect, to toValue: CGRect, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            break
        case let .curve(duration, curve):
            view.layer.animate(
                from: NSValue(cgRect: fromValue),
                to: NSValue(cgRect: toValue),
                keyPath: "bounds",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }
}

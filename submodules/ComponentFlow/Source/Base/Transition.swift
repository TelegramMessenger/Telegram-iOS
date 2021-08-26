import Foundation
import UIKit

private extension UIView {
    static var animationDurationFactor: Double {
        return 1.0
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
            view.frame = frame
            completion?(true)
        case .curve:
            let previousPosition = view.center
            let previousBounds = view.bounds
            view.frame = frame

            self.animatePosition(view: view, from: previousPosition, to: view.center, completion: completion)
            self.animateBounds(view: view, from: previousBounds, to: view.bounds)
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
            completion?(true)
        case .curve:
            let previousAlpha = view.alpha
            view.alpha = alpha
            self.animateAlpha(view: view, from: previousAlpha, to: alpha, completion: completion)
        }
    }

    public func setSublayerTransform(view: UIView, transform: CATransform3D, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            view.layer.sublayerTransform = transform
            completion?(true)
        case let .curve(duration, curve):
            let previousValue = view.layer.sublayerTransform
            view.layer.sublayerTransform = transform
            view.layer.animate(
                from: NSValue(caTransform3D: previousValue),
                to: NSValue(caTransform3D: transform),
                keyPath: "transform",
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

import Foundation
import UIKit
import Display

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

private extension CALayer {
    func animate(from: AnyObject, to: AnyObject, keyPath: String, duration: Double, delay: Double, curve: Transition.Animation.Curve, removeOnCompletion: Bool, additive: Bool, completion: ((Bool) -> Void)? = nil) {
        let timingFunction: String
        let mediaTimingFunction: CAMediaTimingFunction?
        switch curve {
        case .spring:
            timingFunction = kCAMediaTimingFunctionSpring
            mediaTimingFunction = nil
        default:
            timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
            mediaTimingFunction = curve.asTimingFunction()
        }
        
        self.animate(
            from: from,
            to: to,
            keyPath: keyPath,
            timingFunction: timingFunction,
            duration: duration,
            delay: delay,
            mediaTimingFunction: mediaTimingFunction,
            removeOnCompletion: removeOnCompletion,
            additive: additive,
            completion: completion
        )
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

public extension Transition.Animation {
    var isImmediate: Bool {
        if case .none = self {
            return true
        } else {
            return false
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
            view.frame = frame
            //view.bounds = CGRect(origin: view.bounds.origin, size: frame.size)
            //view.layer.position = CGPoint(x: frame.midX, y: frame.midY)
            view.layer.removeAnimation(forKey: "position")
            view.layer.removeAnimation(forKey: "bounds")
            view.layer.removeAnimation(forKey: "bounds.size")
            completion?(true)
        case .curve:
            let previousPosition: CGPoint
            let previousBounds: CGRect
            if (view.layer.animation(forKey: "position") != nil || view.layer.animation(forKey: "bounds") != nil || view.layer.animation(forKey: "bounds.size") != nil), let presentation = view.layer.presentation() {
                previousPosition = presentation.position
                previousBounds = presentation.bounds
            } else {
                previousPosition = view.layer.position
                previousBounds = view.layer.bounds
            }
            
            view.frame = frame
            //view.bounds = CGRect(origin: previousBounds.origin, size: frame.size)
            //view.center = CGPoint(x: frame.midX, y: frame.midY)
            
            let anchorPoint = view.layer.anchorPoint
            let updatedPosition = CGPoint(x: frame.minX + frame.width * anchorPoint.x, y: frame.minY + frame.height * anchorPoint.y)

            self.animatePosition(view: view, from: previousPosition, to: updatedPosition, completion: completion)
            if previousBounds.size != frame.size {
                self.animateBoundsSize(view: view, from: previousBounds.size, to: frame.size)
            }
        }
    }
    
    public func setFrame(layer: CALayer, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        if layer.frame == frame {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.frame = frame
            //view.bounds = CGRect(origin: view.bounds.origin, size: frame.size)
            //view.layer.position = CGPoint(x: frame.midX, y: frame.midY)
            layer.removeAnimation(forKey: "position")
            layer.removeAnimation(forKey: "bounds")
            completion?(true)
        case .curve:
            let previousFrame: CGRect
            if (layer.animation(forKey: "position") != nil || layer.animation(forKey: "bounds") != nil), let presentation = layer.presentation() {
                previousFrame = presentation.frame
            } else {
                previousFrame = layer.frame
            }
            
            layer.frame = frame
            //view.bounds = CGRect(origin: previousBounds.origin, size: frame.size)
            //view.center = CGPoint(x: frame.midX, y: frame.midY)

            self.animatePosition(layer: layer, from: CGPoint(x: previousFrame.midX, y: previousFrame.midY), to: CGPoint(x: frame.midX, y: frame.midY), completion: completion)
            self.animateBounds(layer: layer, from: CGRect(origin: layer.bounds.origin, size: previousFrame.size), to: CGRect(origin: layer.bounds.origin, size: frame.size))
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
            view.layer.removeAnimation(forKey: "bounds.origin")
            view.layer.removeAnimation(forKey: "bounds.size")
            completion?(true)
        case .curve:
            let previousBounds: CGRect
            if (view.layer.animation(forKey: "bounds") != nil || view.layer.animation(forKey: "bounds.origin") != nil || view.layer.animation(forKey: "bounds.size") != nil), let presentation = view.layer.presentation() {
                previousBounds = presentation.bounds
            } else {
                previousBounds = view.layer.bounds
            }
            view.bounds = bounds

            self.animateBounds(view: view, from: previousBounds, to: view.bounds, completion: completion)
        }
    }
    
    public func setBoundsOrigin(view: UIView, origin: CGPoint, completion: ((Bool) -> Void)? = nil) {
        if view.bounds.origin == origin {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.bounds = CGRect(origin: origin, size: view.bounds.size)
            view.layer.removeAnimation(forKey: "bounds")
            view.layer.removeAnimation(forKey: "bounds.origin")
            completion?(true)
        case .curve:
            let previousOrigin: CGPoint
            if (view.layer.animation(forKey: "bounds") != nil || view.layer.animation(forKey: "bounds.origin") != nil), let presentation = view.layer.presentation() {
                previousOrigin = presentation.bounds.origin
            } else {
                previousOrigin = view.layer.bounds.origin
            }
            view.bounds = CGRect(origin: origin, size: view.bounds.size)

            self.animateBoundsOrigin(view: view, from: previousOrigin, to: origin, completion: completion)
        }
    }
    
    public func setBoundsSize(view: UIView, size: CGSize, completion: ((Bool) -> Void)? = nil) {
        if view.bounds.size == size {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            view.bounds.size = size
            view.layer.removeAnimation(forKey: "bounds.size")
            completion?(true)
        case .curve:
            let previousBounds: CGRect
            if view.layer.animation(forKey: "bounds.size") != nil, let presentation = view.layer.presentation() {
                previousBounds = presentation.bounds
            } else {
                previousBounds = view.layer.bounds
            }
            view.bounds = CGRect(origin: view.bounds.origin, size: size)

            self.animateBoundsSize(view: view, from: previousBounds.size, to: size, completion: completion)
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
            let previousPosition: CGPoint
            if view.layer.animation(forKey: "position") != nil, let presentation = view.layer.presentation() {
                previousPosition = presentation.position
            } else {
                previousPosition = view.layer.position
            }
            view.center = position

            self.animatePosition(view: view, from: previousPosition, to: view.center, completion: completion)
        }
    }
    
    public func setBounds(layer: CALayer, bounds: CGRect, completion: ((Bool) -> Void)? = nil) {
        if layer.bounds == bounds {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.bounds = bounds
            layer.removeAnimation(forKey: "bounds")
            completion?(true)
        case .curve:
            let previousBounds: CGRect
            if layer.animation(forKey: "bounds") != nil, let presentation = layer.presentation() {
                previousBounds = presentation.bounds
            } else {
                previousBounds = layer.bounds
            }
            layer.bounds = bounds

            self.animateBounds(layer: layer, from: previousBounds, to: layer.bounds, completion: completion)
        }
    }
    
    public func setPosition(layer: CALayer, position: CGPoint, completion: ((Bool) -> Void)? = nil) {
        if layer.position == position {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.position = position
            layer.removeAnimation(forKey: "position")
            completion?(true)
        case .curve:
            let previousPosition: CGPoint
            if layer.animation(forKey: "position") != nil, let presentation = layer.presentation() {
                previousPosition = presentation.position
            } else {
                previousPosition = layer.position
            }
            layer.position = position

            self.animatePosition(layer: layer, from: previousPosition, to: layer.position, completion: completion)
        }
    }
    
    public func attachAnimation(view: UIView, id: String, completion: @escaping (Bool) -> Void) {
        switch self.animation {
        case .none:
            completion(true)
        case let .curve(duration, curve):
            view.layer.animate(
                from: 0.0 as NSNumber,
                to: 1.0 as NSNumber,
                keyPath: id,
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: true,
                completion: completion
            )
        }
    }
    
    public func setAlpha(view: UIView, alpha: CGFloat, delay: Double = 0.0, completion: ((Bool) -> Void)? = nil) {
        self.setAlpha(layer: view.layer, alpha: alpha, delay: delay, completion: completion)
    }
    
    public func setAlpha(layer: CALayer, alpha: CGFloat, delay: Double = 0.0, completion: ((Bool) -> Void)? = nil) {
        if layer.opacity == Float(alpha) {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.opacity = Float(alpha)
            layer.removeAnimation(forKey: "opacity")
            completion?(true)
        case .curve:
            let previousAlpha = layer.presentation()?.opacity ?? layer.opacity
            layer.opacity = Float(alpha)
            self.animateAlpha(layer: layer, from: CGFloat(previousAlpha), to: alpha, delay: delay, completion: completion)
        }
    }
    
    public func setScale(view: UIView, scale: CGFloat, delay: Double = 0.0, completion: ((Bool) -> Void)? = nil) {
        self.setScale(layer: view.layer, scale: scale, delay: delay, completion: completion)
    }
    
    public func setScale(layer: CALayer, scale: CGFloat, delay: Double = 0.0, completion: ((Bool) -> Void)? = nil) {
        let t = layer.presentation()?.transform ?? layer.transform
        let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        if currentScale == scale {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            completion?(true)
        case let .curve(duration, curve):
            let previousScale = currentScale
            layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            layer.animate(
                from: previousScale as NSNumber,
                to: scale as NSNumber,
                keyPath: "transform.scale",
                duration: duration,
                delay: delay,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }
    
    public func setTransform(view: UIView, transform: CATransform3D, completion: ((Bool) -> Void)? = nil) {
        self.setTransform(layer: view.layer, transform: transform, completion: completion)
    }
    
    public func setTransform(layer: CALayer, transform: CATransform3D, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            layer.transform = transform
            completion?(true)
        case let .curve(duration, curve):
            let previousValue: CATransform3D
            if let presentation = layer.presentation() {
                previousValue = presentation.transform
            } else {
                previousValue = layer.transform
            }
            layer.transform = transform
            layer.animate(
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
    
    public func setSublayerTransform(view: UIView, transform: CATransform3D, completion: ((Bool) -> Void)? = nil) {
        self.setSublayerTransform(layer: view.layer, transform: transform, completion: completion)
    }
    
    public func setSublayerTransform(layer: CALayer, transform: CATransform3D, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            layer.sublayerTransform = transform
            completion?(true)
        case let .curve(duration, curve):
            let previousValue: CATransform3D
            if let presentation = layer.presentation() {
                previousValue = presentation.sublayerTransform
            } else {
                previousValue = layer.sublayerTransform
            }
            layer.sublayerTransform = transform
            layer.animate(
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

    public func animateScale(view: UIView, from fromValue: CGFloat, to toValue: CGFloat, delay: Double = 0.0, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            view.layer.animate(
                from: fromValue as NSNumber,
                to: toValue as NSNumber,
                keyPath: "transform.scale",
                duration: duration,
                delay: delay,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }
    
    public func animateSublayerScale(view: UIView, from fromValue: CGFloat, to toValue: CGFloat, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            view.layer.animate(
                from: fromValue as NSNumber,
                to: toValue as NSNumber,
                keyPath: "sublayerTransform.scale",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animateAlpha(view: UIView, from fromValue: CGFloat, to toValue: CGFloat, delay: Double = 0.0, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animateAlpha(layer: view.layer, from: fromValue, to: toValue, delay: delay, additive: additive, completion: completion)
    }
    
    public func animateAlpha(layer: CALayer, from fromValue: CGFloat, to toValue: CGFloat, delay: Double = 0.0, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
                from: fromValue as NSNumber,
                to: toValue as NSNumber,
                keyPath: "opacity",
                duration: duration,
                delay: delay,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }

    public func animatePosition(view: UIView, from fromValue: CGPoint, to toValue: CGPoint, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animatePosition(layer: view.layer, from: fromValue, to: toValue, additive: additive, completion: completion)
    }

    public func animateBounds(view: UIView, from fromValue: CGRect, to toValue: CGRect, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animateBounds(layer: view.layer, from: fromValue, to: toValue, additive: additive, completion: completion)
    }
    
    public func animateBoundsOrigin(view: UIView, from fromValue: CGPoint, to toValue: CGPoint, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animateBoundsOrigin(layer: view.layer, from: fromValue, to: toValue, additive: additive, completion: completion)
    }
    
    public func animateBoundsSize(view: UIView, from fromValue: CGSize, to toValue: CGSize, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        self.animateBoundsSize(layer: view.layer, from: fromValue, to: toValue, additive: additive, completion: completion)
    }
    
    public func animatePosition(layer: CALayer, from fromValue: CGPoint, to toValue: CGPoint, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
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

    public func animateBounds(layer: CALayer, from fromValue: CGRect, to toValue: CGRect, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
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
    
    public func animateBoundsOrigin(layer: CALayer, from fromValue: CGPoint, to toValue: CGPoint, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
                from: NSValue(cgPoint: fromValue),
                to: NSValue(cgPoint: toValue),
                keyPath: "bounds.origin",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }
    
    public func animateBoundsSize(layer: CALayer, from fromValue: CGSize, to toValue: CGSize, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            completion?(true)
        case let .curve(duration, curve):
            layer.animate(
                from: NSValue(cgSize: fromValue),
                to: NSValue(cgSize: toValue),
                keyPath: "bounds.size",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: additive,
                completion: completion
            )
        }
    }
    
    public func setCornerRadius(layer: CALayer, cornerRadius: CGFloat, completion: ((Bool) -> Void)? = nil) {
        if layer.cornerRadius == cornerRadius {
            completion?(true)
            return
        }
        switch self.animation {
        case .none:
            layer.cornerRadius = cornerRadius
            completion?(true)
        case let .curve(duration, curve):
            let fromValue: CGFloat
            if layer.animation(forKey: "cornerRadius") != nil, let presentation = layer.presentation() {
                fromValue = presentation.cornerRadius
            } else {
                fromValue = layer.cornerRadius
            }
            layer.cornerRadius = cornerRadius
            layer.animate(
                from: fromValue as NSNumber,
                to: cornerRadius as NSNumber,
                keyPath: "cornerRadius",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }
    
    public func setShapeLayerPath(layer: CAShapeLayer, path: CGPath, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            layer.path = path
            completion?(true)
        case let .curve(duration, curve):
            if let previousPath = layer.path, previousPath != path {
                layer.animate(
                    from: previousPath,
                    to: path,
                    keyPath: "path",
                    duration: duration,
                    delay: 0.0,
                    curve: curve,
                    removeOnCompletion: true,
                    additive: false,
                    completion: completion
                )
                layer.path = path
            } else {
                layer.path = path
                completion?(true)
            }
        }
    }
    
    public func setShapeLayerLineWidth(layer: CAShapeLayer, lineWidth: CGFloat, completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            layer.lineWidth = lineWidth
            completion?(true)
        case let .curve(duration, curve):
            let previousLineWidth = layer.lineWidth
            layer.lineWidth = lineWidth
            
            layer.animate(
                from: previousLineWidth as NSNumber,
                to: lineWidth as NSNumber,
                keyPath: "lineWidth",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }
    
    public func setShapeLayerLineDashPattern(layer: CAShapeLayer, pattern: [NSNumber], completion: ((Bool) -> Void)? = nil) {
        switch self.animation {
        case .none:
            layer.lineDashPattern = pattern
            completion?(true)
        case let .curve(duration, curve):
            if let previousLineDashPattern = layer.lineDashPattern {
                layer.lineDashPattern = pattern
                
                layer.animate(
                    from: previousLineDashPattern as CFArray,
                    to: pattern as CFArray,
                    keyPath: "lineDashPattern",
                    duration: duration,
                    delay: 0.0,
                    curve: curve,
                    removeOnCompletion: true,
                    additive: false,
                    completion: completion
                )
            } else {
                layer.lineDashPattern = pattern
                completion?(true)
            }
        }
    }
    
    public func setBackgroundColor(view: UIView, color: UIColor, completion: ((Bool) -> Void)? = nil) {
        self.setBackgroundColor(layer: view.layer, color: color, completion: completion)
    }
    
    public func setBackgroundColor(layer: CALayer, color: UIColor, completion: ((Bool) -> Void)? = nil) {
        if let current = layer.backgroundColor, current == color.cgColor {
            completion?(true)
            return
        }
        
        switch self.animation {
        case .none:
            layer.backgroundColor = color.cgColor
            completion?(true)
        case let .curve(duration, curve):
            let previousColor: CGColor = layer.backgroundColor ?? UIColor.clear.cgColor
            layer.backgroundColor = color.cgColor
            
            layer.animate(
                from: previousColor,
                to: color.cgColor,
                keyPath: "backgroundColor",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }
    
    public func setTintColor(view: UIView, color: UIColor, completion: ((Bool) -> Void)? = nil) {
        if let current = view.tintColor, current == color {
            completion?(true)
            return
        }
        
        switch self.animation {
        case .none:
            view.tintColor = color
            completion?(true)
        case let .curve(duration, curve):
            let previousColor: UIColor = view.tintColor ?? UIColor.clear
            view.tintColor = color
            
            view.layer.animate(
                from: previousColor,
                to: color.cgColor,
                keyPath: "contentsMultiplyColor",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }
    
    public func setTintColor(layer: CALayer, color: UIColor, completion: ((Bool) -> Void)? = nil) {
        if let current = layer.layerTintColor, current == color.cgColor {
            completion?(true)
            return
        }
        
        switch self.animation {
        case .none:
            layer.layerTintColor = color.cgColor
            completion?(true)
        case let .curve(duration, curve):
            let previousColor: CGColor = layer.layerTintColor ?? UIColor.clear.cgColor
            layer.layerTintColor = color.cgColor
            
            layer.animate(
                from: previousColor,
                to: color.cgColor,
                keyPath: "contentsMultiplyColor",
                duration: duration,
                delay: 0.0,
                curve: curve,
                removeOnCompletion: true,
                additive: false,
                completion: completion
            )
        }
    }
}

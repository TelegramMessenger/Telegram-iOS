import Foundation
import UIKit

public enum AnimationCurve {
    case linear
    case easeInOut
    case spring
}

extension AnimationCurve {
    func map(_ fraction: CGFloat) -> CGFloat {
        switch self {
        case .linear:
            return fraction
        case .easeInOut:
            return bezierPoint(0.42, 0.0, 0.58, 1.0, fraction)
        case .spring:
            return bezierPoint(0.23, 1.0, 0.32, 1.0, fraction)
        }
    }
}

open class AnyAnimation {
}

open class AnimationInterpolator<T> {
    private let impl: (T, T, CGFloat) -> T
    
    init(_ impl: @escaping (T, T, CGFloat) -> T) {
        self.impl = impl
    }
    
    public func interpolate(from: T, to: T, fraction: CGFloat) -> T {
        return self.impl(from, to, fraction)
    }
}

public protocol AnimationInterpolatable {
    static var animationInterpolator: AnimationInterpolator<Self> { get }
}

private let CGFloatInterpolator = AnimationInterpolator<CGFloat> { from, to, fraction in
    return from * (1.0 - fraction) + to * fraction
}
extension CGFloat: AnimationInterpolatable {
    public static var animationInterpolator: AnimationInterpolator<CGFloat> {
        return CGFloatInterpolator
    }
}

private let CGPointInterpolator = AnimationInterpolator<CGPoint> { from, to, fraction in
    return CGPoint(
        x: CGFloatInterpolator.interpolate(from: from.x, to: to.x, fraction: fraction),
        y: CGFloatInterpolator.interpolate(from: from.y, to: to.y, fraction: fraction)
    )
}
extension CGPoint: AnimationInterpolatable {
    public static var animationInterpolator: AnimationInterpolator<CGPoint> {
        return CGPointInterpolator
    }
}

#if targetEnvironment(simulator)
@_silgen_name("UIAnimationDragCoefficient") func UIAnimationDragCoefficient() -> Float
#endif

public final class Animation<T: AnimationInterpolatable>: AnyAnimation {
    private let from: T
    private let to: T
    private let duration: Double
    private let curve: AnimationCurve
    private let interpolator: AnimationInterpolator<T>
    
    private var startTime: Double?
    public private(set) var isFinished: Bool = false
    
    var didStart: (() -> Void)?
    
    public init(from: T, to: T, duration: Double, curve: AnimationCurve) {
        self.from = from
        self.to = to
        #if targetEnvironment(simulator)
        self.duration = duration * Double(UIAnimationDragCoefficient())
        #else
        self.duration = duration
        #endif
        self.curve = curve
        self.interpolator = T.animationInterpolator
    }
    
    func start() {
        self.startTime = CACurrentMediaTime()
    }
    
    func update(at timestamp: Double) -> T {
        guard let startTime = self.startTime else {
            return self.from
        }
        if self.isFinished {
            return self.to
        }
        let fraction = max(0.0, min(1.0, (timestamp - startTime) / self.duration))
        if timestamp > startTime + self.duration {
            self.isFinished = true
        }
        if fraction >= 1.0 {
            return self.to
        }
        return self.interpolator.interpolate(from: self.from, to: self.to, fraction: self.curve.map(fraction))
    }
}

public class AnyAnimatedProperty {
    var didStartAnimation: (() -> Void)?
    var hasRunningAnimation: Bool {
        return false
    }
    
    public func update() {
    }
}

public final class AnimatedProperty<T: AnimationInterpolatable>: AnyAnimatedProperty {
    private var animation: Animation<T>?
    
    override var hasRunningAnimation: Bool {
        return self.animation != nil
    }
    
    public private(set) var value: T
    
    public init(_ value: T) {
        self.value = value
    }
    
    public func animate(to: T, duration: Double, curve: AnimationCurve) {
        let timestamp = CACurrentMediaTime()
        
        let fromValue: T
        if let animation = self.animation {
            fromValue = animation.update(at: timestamp)
        } else {
            fromValue = self.value
        }
        self.animation = Animation(from: fromValue, to: to, duration: duration, curve: curve)
        self.animation?.start()
        self.didStartAnimation?()
    }
    
    public func animate(from: T, to: T, duration: Double, curve: AnimationCurve) {
        self.value = from
        self.animation = Animation(from: from, to: to, duration: duration, curve: curve)
        self.animation?.start()
        self.didStartAnimation?()
    }
    
    public func set(to: T) {
        self.animation = nil
        self.value = to
    }
    
    override public func update() {
        if let animation = self.animation {
            self.value = animation.update(at: CACurrentMediaTime())
            if animation.isFinished {
                self.animation = nil
            }
        }
    }
}

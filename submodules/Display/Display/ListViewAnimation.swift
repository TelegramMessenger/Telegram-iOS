import Foundation
import UIKit

public protocol Interpolatable {
    static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> (Interpolatable)
}

private func floorToPixels(_ value: CGFloat) -> CGFloat {
    return round(value * 10.0) / 10.0
}

private func floorToPixels(_ value: CGPoint) -> CGPoint {
    return CGPoint(x: round(value.x * 10.0) / 10.0, y: round(value.y * 10.0) / 10.0)
}

private func floorToPixels(_ value: CGSize) -> CGSize {
    return CGSize(width: round(value.width * 10.0) / 10.0, height: round(value.height * 10.0) / 10.0)
}

private func floorToPixels(_ value: CGRect) -> CGRect {
    return CGRect(origin: floorToPixels(value.origin), size: floorToPixels(value.size))
}

private func floorToPixels(_ value: UIEdgeInsets) -> UIEdgeInsets {
    return UIEdgeInsets(top: round(value.top * 10.0) / 10.0, left: round(value.left * 10.0) / 10.0, bottom: round(value.bottom * 10.0) / 10.0, right: round(value.right * 10.0) / 10.0)
}

extension CGFloat: Interpolatable {
    public static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> Interpolatable {
        return { from, to, t -> Interpolatable in
            let fromValue: CGFloat = from as! CGFloat
            let toValue: CGFloat = to as! CGFloat
            let invT: CGFloat = 1.0 - t
            let term: CGFloat = toValue * t + fromValue * invT
            return floorToPixels(term)
        }
    }
}

extension UIEdgeInsets: Interpolatable {
    public static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> Interpolatable {
        return { from, to, t -> Interpolatable in
            let fromValue = from as! UIEdgeInsets
            let toValue = to as! UIEdgeInsets
            return floorToPixels(UIEdgeInsets(top: toValue.top * t + fromValue.top * (1.0 - t), left: toValue.left * t + fromValue.left * (1.0 - t), bottom: toValue.bottom * t + fromValue.bottom * (1.0 - t), right: toValue.right * t + fromValue.right * (1.0 - t)))
        }
    }
}

extension CGRect: Interpolatable {
    public static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> Interpolatable {
        return { from, to, t -> Interpolatable in
            let fromValue = from as! CGRect
            let toValue = to as! CGRect
            return floorToPixels(CGRect(x: toValue.origin.x * t + fromValue.origin.x * (1.0 - t), y: toValue.origin.y * t + fromValue.origin.y * (1.0 - t), width: toValue.size.width * t + fromValue.size.width * (1.0 - t), height: toValue.size.height * t + fromValue.size.height * (1.0 - t)))
        }
    }
}

extension CGPoint: Interpolatable {
    public static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> Interpolatable {
        return { from, to, t -> Interpolatable in
            let fromValue = from as! CGPoint
            let toValue = to as! CGPoint
            return floorToPixels(CGPoint(x: toValue.x * t + fromValue.x * (1.0 - t), y: toValue.y * t + fromValue.y * (1.0 - t)))
        }
    }
}

private let springAnimationIn: CABasicAnimation = {
    let animation = makeSpringAnimation("")
    return animation
}()

private let springAnimationSolver: (CGFloat) -> CGFloat = { () -> (CGFloat) -> CGFloat in
    if #available(iOS 9.0, *) {
        return { t in
            return springAnimationValueAt(springAnimationIn, t)
        }
    } else {
        return { t in
            return bezierPoint(0.23, 1.0, 0.32, 1.0, t)
        }
    }
}()

public let listViewAnimationCurveSystem: (CGFloat) -> CGFloat = { t in
    return springAnimationSolver(t)
}

public let listViewAnimationCurveLinear: (CGFloat) -> CGFloat = { t in
    return t
}

#if os(iOS)
public func listViewAnimationCurveFromAnimationOptions(animationOptions: UIView.AnimationOptions) -> (CGFloat) -> CGFloat {
    if animationOptions.rawValue == UInt(7 << 16) {
        return listViewAnimationCurveSystem
    } else {
        return listViewAnimationCurveLinear
    }
}
#endif

public final class ListViewAnimation {
    let from: Interpolatable
    let to: Interpolatable
    let duration: Double
    let startTime: Double
    private let curve: (CGFloat) -> CGFloat
    private let interpolator: (Interpolatable, Interpolatable, CGFloat) -> Interpolatable
    private let update: (CGFloat, Interpolatable) -> Void
    private let completed: (Bool) -> Void
    
    public init<T: Interpolatable>(from: T, to: T, duration: Double, curve: @escaping (CGFloat) -> CGFloat, beginAt: Double, update: @escaping (CGFloat, T) -> Void, completed: @escaping (Bool) -> Void = { _ in }) {
        self.from = from
        self.to = to
        self.duration = duration
        self.curve = curve
        self.startTime = beginAt
        self.interpolator = T.interpolator()
        self.update = { progress, value in
            update(progress, value as! T)
        }
        self.completed = completed
    }
    
    init<T: Interpolatable>(copying: ListViewAnimation, update: @escaping (CGFloat, T) -> Void, completed: @escaping (Bool) -> Void = { _ in }) {
        self.from = copying.from
        self.to = copying.to
        self.duration = copying.duration
        self.curve = copying.curve
        self.startTime = copying.startTime
        self.interpolator = copying.interpolator
        self.update = { progress, value in
            update(progress, value as! T)
        }
        self.completed = completed
    }
    
    public func completeAt(_ timestamp: Double) -> Bool {
        if timestamp >= self.startTime + self.duration {
            self.completed(true)
            return true
        } else {
            return false
        }
    }
    
    public func cancel() {
        self.completed(false)
    }
    
    private func valueAt(_ t: CGFloat) -> Interpolatable {
        if t <= 0.0 {
            return self.from
        } else if t >= 1.0 {
            return self.to
        } else {
            return self.interpolator(self.from, self.to, t)
        }
    }
    
    public func applyAt(_ timestamp: Double) {
        var t = CGFloat((timestamp - self.startTime) / self.duration)
        let ct: CGFloat
        if t <= 0.0 + CGFloat.ulpOfOne {
            t = 0.0
            ct = 0.0
        } else if t >= 1.0 - CGFloat.ulpOfOne {
            t = 1.0
            ct = 1.0
        } else {
            ct = self.curve(t)
        }
        self.update(ct, self.valueAt(ct))
    }
}

public func listViewAnimationDurationAndCurve(transition: ContainedViewLayoutTransition) -> (Double, ListViewAnimationCurve) {
    var duration: Double = 0.0
    var curve: UInt = 0
    switch transition {
        case .immediate:
            break
        case let .animated(animationDuration, animationCurve):
            duration = animationDuration
            switch animationCurve {
                case .easeInOut, .custom:
                    break
                case .spring:
                    curve = 7
            }
    }
    
    let listViewCurve: ListViewAnimationCurve
    if curve == 7 {
        listViewCurve = .Spring(duration: duration)
    } else {
        listViewCurve = .Default(duration: duration)
    }
    
    return (duration, listViewCurve)
}

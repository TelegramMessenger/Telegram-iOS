import Foundation
import Display

public protocol Interpolatable {
    static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> (Interpolatable)
}

private func floorToPixels(value: CGFloat) -> CGFloat {
    return round(value * 10.0) / 10.0
}

private func floorToPixels(value: CGPoint) -> CGPoint {
    return CGPoint(x: round(value.x * 10.0) / 10.0, y: round(value.y * 10.0) / 10.0)
}

private func floorToPixels(value: CGSize) -> CGSize {
    return CGSize(width: round(value.width * 10.0) / 10.0, height: round(value.height * 10.0) / 10.0)
}

private func floorToPixels(value: CGRect) -> CGRect {
    return CGRect(origin: floorToPixels(value.origin), size: floorToPixels(value.size))
}

private func floorToPixels(value: UIEdgeInsets) -> UIEdgeInsets {
    return UIEdgeInsets(top: round(value.top * 10.0) / 10.0, left: round(value.left * 10.0) / 10.0, bottom: round(value.bottom * 10.0) / 10.0, right: round(value.right * 10.0) / 10.0)
}

extension CGFloat: Interpolatable {
    public static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> Interpolatable {
        return { from, to, t -> Interpolatable in
            return floorToPixels((to as! CGFloat) * t + (from as! CGFloat) * (1.0 - t))
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

extension CGPoint: Interpolatable {
    public static func interpolator() -> (Interpolatable, Interpolatable, CGFloat) -> Interpolatable {
        return { from, to, t -> Interpolatable in
            let fromValue = from as! CGPoint
            let toValue = to as! CGPoint
            return floorToPixels(CGPoint(x: toValue.x * t + fromValue.x * (1.0 - t), y: toValue.y * t + fromValue.y * (1.0 - t)))
        }
    }
}

private let springAnimationIn: CASpringAnimation = {
    let animation = CASpringAnimation()
    animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
    animation.duration = 0.6
    animation.damping = 500.0
    animation.stiffness = 1000.0
    animation.mass = 3.0
    return animation
}()

public let listViewAnimationCurveSystem: CGFloat -> CGFloat = { t in
    //return bezierPoint(0.23, 1.0, 0.32, 1.0, t)
    return springAnimationIn.valueAt(t)
}

public let listViewAnimationCurveLinear: CGFloat -> CGFloat = { t in
    return t
}

public func listViewAnimationCurveFromAnimationOptions(animationOptions: UIViewAnimationOptions) -> CGFloat -> CGFloat {
    if animationOptions.rawValue == UInt(7 << 16) {
        return listViewAnimationCurveSystem
    } else {
        return listViewAnimationCurveLinear
    }
}

public final class ListViewAnimation {
    let from: Interpolatable
    let to: Interpolatable
    let duration: Double
    let startTime: Double
    private let curve: CGFloat -> CGFloat
    private let interpolator: (Interpolatable, Interpolatable, CGFloat) -> Interpolatable
    private let update: Interpolatable -> Void
    private let completed: Bool -> Void
    
    public init<T: Interpolatable>(from: T, to: T, duration: Double, curve: CGFloat -> CGFloat, beginAt: Double, update: T -> Void, completed: Bool -> Void = { _ in }) {
        self.from = from
        self.to = to
        self.duration = duration
        self.curve = curve
        self.startTime = beginAt
        self.interpolator = T.interpolator()
        self.update = { value in
            update(value as! T)
        }
        self.completed = completed
    }
    
    public func completeAt(timestamp: Double) -> Bool {
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
    
    private func valueAt(timestamp: Double) -> Interpolatable {
        if timestamp < self.startTime {
            return self.from
        }
        
        let t = CGFloat((timestamp - self.startTime) / self.duration)
        
        if t >= 1.0 {
            return self.to
        } else {
            return self.interpolator(self.from, self.to, self.curve(t))
        }
    }
    
    public func applyAt(timestamp: Double) {
        self.update(self.valueAt(timestamp))
    }
}

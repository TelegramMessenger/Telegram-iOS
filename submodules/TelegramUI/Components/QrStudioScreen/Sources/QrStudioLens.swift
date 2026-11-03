import Foundation
import CoreGraphics

enum QrStudioLens {
    static let openDuration: Double = 0.5
    static let closeDuration: Double = 0.36
    static let holdDuration: Double = 2.2

    static func size(_ p: CGFloat, width: CGFloat, height: CGFloat) -> CGSize {
        let q = max(p, 0.0)
        if q <= 0.0 {
            return .zero
        }
        let h = height * (min(1.0, q / 0.55) + max(0.0, q - 1.0))
        let w = h + (width - h) * (q > 1.0 ? q : self.ramp(q, 0.15, 1.0))
        return CGSize(width: max(0.0, w), height: max(0.0, h))
    }

    static func closesAfterHold(holding: Double) -> Bool {
        return holding >= self.holdDuration - self.openDuration * 0.6
    }

    static func approach(_ value: CGFloat, to target: CGFloat, dt: Double) -> CGFloat {
        let next = value + (target - value) * CGFloat(min(1.0, dt * 12.0))
        if abs(target - next) < 0.1 {
            return target
        }
        return next
    }

    static func ramp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let u = min(max((x - a) / (b - a), 0.0), 1.0)
        return u * u * (3.0 - 2.0 * u)
    }

    static func opening(_ t: Double) -> CGFloat {
        if t <= 0.0 {
            return 0.0
        }
        if t >= self.openDuration * 1.6 {
            return 1.0
        }
        let omega = 2.0 * Double.pi / self.openDuration
        let zeta = 0.7
        let damped = omega * (1.0 - zeta * zeta).squareRoot()
        let envelope = exp(-zeta * omega * t)
        return CGFloat(1.0 - envelope * (cos(damped * t) + zeta * omega / damped * sin(damped * t)))
    }

    static func closing(_ t: Double) -> CGFloat {
        if t >= self.closeDuration {
            return 0.0
        }
        let x = max(0.0, t / self.closeDuration)
        return CGFloat(1.0 - self.bezier(x, 0.5, 0.0, 0.9, 0.5))
    }

    private static func bezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        func curve(_ s: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1.0 - s
            return 3.0 * u * u * s * a + 3.0 * u * s * s * b + s * s * s
        }
        var lo = 0.0
        var hi = 1.0
        for _ in 0 ..< 32 {
            let mid = (lo + hi) * 0.5
            if curve(mid, x1, x2) < x {
                lo = mid
            } else {
                hi = mid
            }
        }
        return curve((lo + hi) * 0.5, y1, y2)
    }
}

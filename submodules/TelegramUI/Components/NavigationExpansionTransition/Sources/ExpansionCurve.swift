import Foundation
import UIKit

/// The prototype's curves (`Helpers.swift`, `Curve`).
public enum ExpansionCurve {
    /// 0…1 inside [a, b], clamped outside.
    public static func ramp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        return min(max((x - a) / (b - a), 0.0), 1.0)
    }

    public static func smooth(_ x: CGFloat) -> CGFloat {
        return x * x * (3.0 - 2.0 * x)
    }

    /// The same path 0…1 with the first half faster (0.7 by the middle), smooth everywhere and still climbing at 1:
    /// a spring's overshoot continues the motion rather than starting a new one.
    public static func lead(_ x: CGFloat) -> CGFloat {
        return x + 0.8 * x * (1.0 - x)
    }

    /// Two layouts of one label (the lower screen's and the upper screen's, by `t` from 0 to 1) without a dip: the
    /// incoming one is whole before the outgoing one fades, so the letters never pale midway.
    public static func crossfade(_ t: CGFloat) -> (source: CGFloat, destination: CGFloat) {
        return (1.0 - smooth(ramp(t, 0.5, 0.7)), smooth(ramp(t, 0.3, 0.5)))
    }

    /// 0…1 so that every step adds the same fraction of the size (a growth by `ratio`): even to the eye.
    public static func geometric(_ x: CGFloat, ratio: CGFloat) -> CGFloat {
        return (pow(ratio, x) - 1.0) / (ratio - 1.0)
    }

    public static func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }

    public static func mix(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        return CGPoint(x: mix(a.x, b.x, t), y: mix(a.y, b.y, t))
    }

    public static func mix(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        return CGRect(x: mix(a.minX, b.minX, t), y: mix(a.minY, b.minY, t), width: mix(a.width, b.width, t), height: mix(a.height, b.height, t))
    }
}

/// One clock for the whole transition: 0 the lower screen, 1 the upper one, past both on the spring's overshoot.
/// Colours and other stepped things have their own window on opening and on closing: the way back is not the way in
/// played backwards (`Clock`, `ProfileMorph.swift:326`).
public struct ExpansionClock: Equatable {
    public var time: CGFloat
    public var isOpening: Bool

    public init(time: CGFloat, isOpening: Bool) {
        self.time = time
        self.isOpening = isOpening
    }

    public func phase(_ open: (CGFloat, CGFloat), _ close: (CGFloat, CGFloat)) -> CGFloat {
        if self.isOpening {
            return ExpansionCurve.smooth(ExpansionCurve.ramp(self.time, open.0, open.1))
        } else {
            return 1.0 - ExpansionCurve.smooth(ExpansionCurve.ramp(1.0 - self.time, close.0, close.1))
        }
    }
}

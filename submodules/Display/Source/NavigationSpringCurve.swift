import Foundation
import UIKit

/// When a spring counts as at rest: closer to its target than `value` and slower than `velocity`.
public struct NavigationSpringRest: Equatable {
    public let value: CGFloat
    public let velocity: CGFloat

    public init(value: CGFloat, velocity: CGFloat) {
        self.value = value
        self.velocity = velocity
    }

    /// A transition's progress: within a fifth of a point and a couple of points per second on a phone-width screen.
    public static let progress = NavigationSpringRest(value: 0.0005, velocity: 0.005)

    /// The glass springs' rule: within `threshold` of the target and slower than ten times it.
    public static func glass(_ threshold: CGFloat) -> NavigationSpringRest {
        return NavigationSpringRest(value: threshold, velocity: threshold * 10.0)
    }
}

/// A spring's motion toward a target from a start state, as a function of time: seconds of animation time on the clock
/// of the group it belongs to (`NavigationAnimationClock`). It holds `from` until `startTime` and is exactly at `target`
/// from `restTime` on; in between it is `NavigationTransitionSpring.advance`'s closed form, so the motion does not
/// depend on how it is sampled.
public struct NavigationSpringCurve: Equatable {
    public let startTime: Double
    public let from: CGFloat
    public let initialVelocity: CGFloat
    public let target: CGFloat
    public let spring: NavigationTransitionSpring
    /// False: the motion stops at its first crossing of the target instead of carrying past it.
    public let overshoots: Bool
    public let rest: NavigationSpringRest
    /// When the curve comes to rest (or, not overshooting, reaches its target); on the same clock as `startTime`.
    public let restTime: Double

    /// How finely rest and the crossing are searched for, before the crossing is bisected.
    private static let searchStep: Double = 1.0 / 480.0
    /// A spring still moving by then is taken as at rest; none of ours comes near it.
    private static let searchLimit: Double = 10.0

    public init(startTime: Double = 0.0, from: CGFloat, velocity: CGFloat = 0.0, target: CGFloat, spring: NavigationTransitionSpring, overshoots: Bool = true, rest: NavigationSpringRest) {
        let settle = NavigationSpringCurve.settleDuration(from: from, velocity: velocity, target: target, spring: spring, overshoots: overshoots, rest: rest)
        self.init(startTime: startTime, from: from, velocity: velocity, target: target, spring: spring, overshoots: overshoots, rest: rest, restTime: startTime + settle)
    }

    private init(startTime: Double, from: CGFloat, velocity: CGFloat, target: CGFloat, spring: NavigationTransitionSpring, overshoots: Bool, rest: NavigationSpringRest, restTime: Double) {
        self.startTime = startTime
        self.from = from
        self.initialVelocity = velocity
        self.target = target
        self.spring = spring
        self.overshoots = overshoots
        self.rest = rest
        self.restTime = restTime
    }

    /// A curve that stays at `value`.
    public static func constant(_ value: CGFloat, rest: NavigationSpringRest = .progress) -> NavigationSpringCurve {
        return NavigationSpringCurve(startTime: 0.0, from: value, velocity: 0.0, target: value, spring: .noninteractive, overshoots: true, rest: rest, restTime: 0.0)
    }

    public func value(at time: Double) -> CGFloat {
        if time >= self.restTime {
            return self.target
        }
        if time <= self.startTime {
            return self.from
        }
        return self.spring.advance(value: self.from, velocity: self.initialVelocity, target: self.target, time: CGFloat(time - self.startTime)).value
    }

    public func velocity(at time: Double) -> CGFloat {
        if time >= self.restTime || time < self.startTime {
            return 0.0
        }
        return self.spring.advance(value: self.from, velocity: self.initialVelocity, target: self.target, time: CGFloat(time - self.startTime)).velocity
    }

    /// From `time` on, toward `target` on `spring`: starting where this curve is then, at its velocity there.
    public func retargeted(at time: Double, to target: CGFloat, spring: NavigationTransitionSpring, overshoots: Bool = true) -> NavigationSpringCurve {
        return NavigationSpringCurve(startTime: time, from: self.value(at: time), velocity: self.velocity(at: time), target: target, spring: spring, overshoots: overshoots, rest: self.rest)
    }

    /// The same motion on a clock whose zero is this one's `time` (a new bake's origin).
    public func rebased(by time: Double) -> NavigationSpringCurve {
        return NavigationSpringCurve(startTime: self.startTime - time, from: self.from, velocity: self.initialVelocity, target: self.target, spring: self.spring, overshoots: self.overshoots, rest: self.rest, restTime: self.restTime - time)
    }

    private static func settleDuration(from: CGFloat, velocity: CGFloat, target: CGFloat, spring: NavigationTransitionSpring, overshoots: Bool, rest: NavigationSpringRest) -> Double {
        func state(_ t: Double) -> (value: CGFloat, velocity: CGFloat) {
            return spring.advance(value: from, velocity: velocity, target: target, time: CGFloat(t))
        }
        func isAtRest(_ state: (value: CGFloat, velocity: CGFloat)) -> Bool {
            return abs(state.value - target) < rest.value && abs(state.velocity) < rest.velocity
        }
        if isAtRest((from, velocity)) {
            return 0.0
        }
        // The side of the target the motion starts on (or, starting on it, first moves to).
        var side = from - target
        var previous = 0.0
        var t = NavigationSpringCurve.searchStep
        while t <= NavigationSpringCurve.searchLimit {
            let current = state(t)
            if !overshoots {
                if side == 0.0 {
                    side = current.value - target
                } else if (current.value - target) * side <= 0.0 {
                    var low = previous
                    var high = t
                    for _ in 0 ..< 30 {
                        let middle = (low + high) * 0.5
                        if (state(middle).value - target) * side <= 0.0 {
                            high = middle
                        } else {
                            low = middle
                        }
                    }
                    return high
                }
            }
            if isAtRest(current) {
                return t
            }
            previous = t
            t += NavigationSpringCurve.searchStep
        }
        return NavigationSpringCurve.searchLimit
    }
}

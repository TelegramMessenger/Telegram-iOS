import Foundation
import CoreGraphics

/// Where the lens's glass is: moving from `from` at `startTime` to `to` over `duration`, along `progress` (the part of
/// the move done at a fraction of `duration`), or resting at `to` when `duration` is 0. Times are in
/// `LiquidLensMotionPlan`'s timeline.
///
/// A move that starts while the lens is already moving keeps its velocity: on top of the curve it carries the
/// difference between that velocity and the curve's own at its start, decaying like a critically damped spring that
/// settles within the move, and gone exactly at its end. The lens leaves with its momentum and still lands on time.
public struct LiquidLensPositionSegment {
    /// How fast the carried velocity decays: a critically damped spring at this many radians per second of the move's
    /// duration settles (to 0.1%) within it.
    static let velocityDecayFactor: Double = 7.0

    public let from: CGPoint
    public let to: CGPoint
    public let startTime: Double
    public let duration: Double
    public let progress: (Double) -> CGFloat
    /// The velocity at `startTime`, in points per second.
    public let initialVelocity: CGPoint
    private let carriedVelocity: CGPoint
    private let velocityDecay: Double

    public init(from: CGPoint, to: CGPoint, startTime: Double, duration: Double, progress: @escaping (Double) -> CGFloat, initialVelocity: CGPoint = CGPoint()) {
        self.from = from
        self.to = to
        self.startTime = startTime
        self.duration = max(0.0, duration)
        self.progress = progress
        self.initialVelocity = initialVelocity

        if self.duration > 0.0 {
            let fraction = 1.0e-4
            let slope = Double(progress(fraction) - progress(0.0)) / fraction / self.duration
            let curveVelocity = CGPoint(x: (to.x - from.x) * CGFloat(slope), y: (to.y - from.y) * CGFloat(slope))
            self.carriedVelocity = CGPoint(x: initialVelocity.x - curveVelocity.x, y: initialVelocity.y - curveVelocity.y)
            self.velocityDecay = LiquidLensPositionSegment.velocityDecayFactor / self.duration
        } else {
            self.carriedVelocity = CGPoint()
            self.velocityDecay = 0.0
        }
    }

    public static func resting(at position: CGPoint, time: Double) -> LiquidLensPositionSegment {
        return LiquidLensPositionSegment(from: position, to: position, startTime: time, duration: 0.0, progress: { _ in 1.0 })
    }

    public var endTime: Double {
        return self.startTime + self.duration
    }

    public func position(at time: Double) -> CGPoint {
        if self.duration <= 0.0 || time >= self.endTime {
            return self.to
        }
        if time <= self.startTime {
            return self.from
        }
        let elapsed = time - self.startTime
        let progress = self.progress(elapsed / self.duration)
        let carried = CGFloat(self.carriedDisplacement(elapsed: elapsed))
        return CGPoint(x: self.from.x + (self.to.x - self.from.x) * progress + self.carriedVelocity.x * carried, y: self.from.y + (self.to.y - self.from.y) * progress + self.carriedVelocity.y * carried)
    }

    /// The velocity at `time`, in points per second; zero when not moving.
    public func velocity(at time: Double) -> CGPoint {
        if self.duration <= 0.0 || time >= self.endTime || time < self.startTime {
            return CGPoint()
        }
        let step = min(1.0e-4, self.duration * 0.25)
        let lower = max(self.startTime, time - step)
        let upper = min(self.endTime, time + step)
        if upper <= lower {
            return CGPoint()
        }
        let a = self.position(at: lower)
        let b = self.position(at: upper)
        return CGPoint(x: (b.x - a.x) / CGFloat(upper - lower), y: (b.y - a.y) / CGFloat(upper - lower))
    }

    /// The displacement per unit of carried velocity after `elapsed` seconds: `t·e^(−ωt)`, a critically damped spring
    /// released from rest with unit velocity, less the small cubic that takes out what is left of it at the end of the
    /// move, so that it starts with a slope of 1 and ends at 0 with a slope of 0.
    private func carriedDisplacement(elapsed: Double) -> Double {
        if self.carriedVelocity.x == 0.0 && self.carriedVelocity.y == 0.0 {
            return 0.0
        }
        let duration = self.duration
        let decay = self.velocityDecay
        let endValue = duration * exp(-decay * duration)
        let endSlope = exp(-decay * duration) * (1.0 - decay * duration)
        let a = (3.0 * endValue - endSlope * duration) / (duration * duration)
        let b = (endSlope - 2.0 * endValue / duration) / (duration * duration)
        return elapsed * exp(-decay * elapsed) - (a * elapsed * elapsed + b * elapsed * elapsed * elapsed)
    }
}

/// The progress of a cubic bezier timing curve at `fraction` of its duration, as `CAMediaTimingFunction` computes it:
/// the curve from (0, 0) to (1, 1) with control points (x1, y1) and (x2, y2), solved for x.
public func liquidLensBezierProgress(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ fraction: Double) -> CGFloat {
    if fraction <= 0.0 {
        return 0.0
    }
    if fraction >= 1.0 {
        return 1.0
    }
    func sample(_ a: Double, _ b: Double, _ s: Double) -> Double {
        let u = 1.0 - s
        return 3.0 * u * u * s * a + 3.0 * u * s * s * b + s * s * s
    }
    func slope(_ a: Double, _ b: Double, _ s: Double) -> Double {
        let u = 1.0 - s
        return 3.0 * u * u * a + 6.0 * u * s * (b - a) + 3.0 * s * s * (1.0 - b)
    }
    var s = fraction
    for _ in 0 ..< 8 {
        let error = sample(x1, x2, s) - fraction
        if abs(error) < 1.0e-7 {
            return CGFloat(sample(y1, y2, s))
        }
        let derivative = slope(x1, x2, s)
        if abs(derivative) < 1.0e-6 {
            break
        }
        s -= error / derivative
    }
    var lower = 0.0
    var upper = 1.0
    s = fraction
    for _ in 0 ..< 40 {
        let value = sample(x1, x2, s)
        if abs(value - fraction) < 1.0e-7 {
            break
        }
        if value < fraction {
            lower = s
        } else {
            upper = s
        }
        s = (lower + upper) * 0.5
    }
    return CGFloat(sample(y1, y2, s))
}

/// The flex's state at an instant: the motion estimate and the springs.
public struct LiquidLensMotionState {
    public var time: Double
    public var motion: LiquidLensMotion
    public var animator: LiquidLensFlexAnimator

    public init(time: Double, motion: LiquidLensMotion = LiquidLensMotion(), animator: LiquidLensFlexAnimator = LiquidLensFlexAnimator()) {
        self.time = time
        self.motion = motion
        self.animator = animator
    }

    /// One frame of the flex, as `_UIFlexInteraction` runs one per `UIUpdateLink` tick: while it is active it samples
    /// where the lens is and retargets its springs to the flex of that motion; otherwise its springs settle back.
    public mutating func advance(to time: Double, segment: LiquidLensPositionSegment, isFlexActive: Bool, size: CGSize) {
        let deltaTime = time - self.time
        if deltaTime <= 0.0 {
            return
        }
        var target = LiquidLensFlex.identity
        if isFlexActive {
            self.motion.add(position: segment.position(at: time), timestamp: time)
            target = LiquidLensFlex.target(size: size, velocity: self.motion.velocity, acceleration: self.motion.acceleration)
        }
        self.animator.step(toward: target, size: size, isTracking: isFlexActive, deltaTime: deltaTime)
        self.time = time
    }
}

/// The lens's motion worked out in advance, for Core Animation to play as keyframes: the position along `segment`
/// and the flex it produces, every 1/120 s from `start` until both are at rest. A change in the middle replaces the
/// plan with one that starts from `state(at:)` of this one, so the flex carries on where it is.
public struct LiquidLensMotionPlan {
    public static let frameDuration: Double = 1.0 / 120.0
    /// A flex that keeps moving (the lens dragged around) is worked out this far ahead; the next change replans it.
    public static let maxDuration: Double = 3.0

    public let segment: LiquidLensPositionSegment
    public let isFlexActive: Bool
    public let size: CGSize
    /// The flex at `startTime` and every frame after it.
    public let states: [LiquidLensMotionState]

    public init(start: LiquidLensMotionState, segment: LiquidLensPositionSegment, isFlexActive: Bool, size: CGSize) {
        self.segment = segment
        self.isFlexActive = isFlexActive
        self.size = size

        var states: [LiquidLensMotionState] = [start]
        // An inactive flex does not follow the lens: once it has settled, nothing is left to animate.
        if isFlexActive || !start.animator.isSettled {
            var state = start
            let maxFrames = Int(LiquidLensMotionPlan.maxDuration / LiquidLensMotionPlan.frameDuration)
            var frame = 1
            while frame <= maxFrames {
                let time = start.time + Double(frame) * LiquidLensMotionPlan.frameDuration
                state.advance(to: time, segment: segment, isFlexActive: isFlexActive, size: size)
                states.append(state)
                if (time >= segment.endTime || !isFlexActive) && state.animator.isSettled && abs(state.motion.velocity.x) < 1.0 && abs(state.motion.velocity.y) < 1.0 {
                    break
                }
                frame += 1
            }
        }
        self.states = states
    }

    public var startTime: Double {
        return self.states[0].time
    }

    public var endTime: Double {
        return self.states[self.states.count - 1].time
    }

    /// The flex as this plan has it at `time`: the frame before it, run on to `time`.
    public func state(at time: Double) -> LiquidLensMotionState {
        if time <= self.startTime {
            return self.states[0]
        }
        let index = min(self.states.count - 1, Int((time - self.startTime) / LiquidLensMotionPlan.frameDuration))
        var state = self.states[index]
        state.advance(to: time, segment: self.segment, isFlexActive: self.isFlexActive, size: self.size)
        return state
    }

    /// Whether the lens flexes at all during the plan.
    public var hasFlex: Bool {
        return self.states.contains(where: { $0.animator.flex != .identity })
    }

    /// The glass's positions from `startTime` to the end of the move, a frame apart, with their times from
    /// `startTime`; empty when it is not moving.
    public var positionKeyframes: [(time: Double, position: CGPoint)] {
        let duration = self.segment.endTime - self.startTime
        if duration <= 0.0 {
            return []
        }
        let count = Int(ceil(duration / LiquidLensMotionPlan.frameDuration))
        var result: [(time: Double, position: CGPoint)] = []
        result.reserveCapacity(count + 1)
        for frame in 0 ... count {
            let time = min(duration, Double(frame) * LiquidLensMotionPlan.frameDuration)
            result.append((time, self.segment.position(at: self.startTime + time)))
        }
        return result
    }
}

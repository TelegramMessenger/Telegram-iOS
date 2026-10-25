import Foundation
import CoreGraphics

/// Where the lens's glass is: moving from `from` at `startTime` to `to` over `duration`, along `progress` (the part of
/// the move done at a fraction of `duration`), or resting at `to` when `duration` is 0. Times are in
/// `LiquidLensMotionPlan`'s timeline.
public struct LiquidLensPositionSegment {
    public let from: CGPoint
    public let to: CGPoint
    public let startTime: Double
    public let duration: Double
    public let progress: (Double) -> CGFloat

    public init(from: CGPoint, to: CGPoint, startTime: Double, duration: Double, progress: @escaping (Double) -> CGFloat) {
        self.from = from
        self.to = to
        self.startTime = startTime
        self.duration = max(0.0, duration)
        self.progress = progress
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
        let progress = self.progress((time - self.startTime) / self.duration)
        return CGPoint(x: self.from.x + (self.to.x - self.from.x) * progress, y: self.from.y + (self.to.y - self.from.y) * progress)
    }
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

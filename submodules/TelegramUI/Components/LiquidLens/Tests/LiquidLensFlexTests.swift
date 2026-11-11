import XCTest
import CoreGraphics
import LiquidLens

final class LiquidLensFlexTests: XCTestCase {
    /// What UIKit's `-[_UIFlexInteraction updateFlex]` computed for the iOS 27 tab bar's lifted lens (95 x 70), read
    /// from its registers in the iOS 27.0 simulator: (acceleration, velocity) -> (scaleX, scaleY, driftX).
    func testTargetMatchesUIKit() {
        let size = CGSize(width: 95.0, height: 70.0)
        let cases: [(acceleration: CGFloat, velocity: CGFloat, scaleX: CGFloat, scaleY: CGFloat, driftX: CGFloat)] = [
            (3255.3728, 108.5124, 1.1746, 0.7097, -8.2954),
            (1612.8375, 53.7612, 1.0968, 0.8387, -4.5966),
            (223.9126, 7.4638, 1.0134, 0.9776, -0.6382),
            (10.1147, -1.1239, 1.0006, 0.9990, 0.0288),
        ]
        for item in cases {
            let flex = LiquidLensFlex.target(size: size, velocity: CGPoint(x: item.velocity, y: 0.0), acceleration: CGPoint(x: item.acceleration, y: 0.0))
            XCTAssertEqual(flex.scaleX, item.scaleX, accuracy: 0.0001)
            XCTAssertEqual(flex.scaleY, item.scaleY, accuracy: 0.0001)
            XCTAssertEqual(flex.driftX, item.driftX, accuracy: 0.0001)
            XCTAssertEqual(flex.driftY, 0.0)
        }
    }

    /// `_UIVelocityIntegrator`, set up as `_UIFlexInteraction` sets it up, on the same 120 Hz samples of a critically
    /// damped move of 68 points, in the iOS 27.0 simulator: (position, velocity, acceleration) per sample.
    func testMotionMatchesUIKitIntegrator() {
        let reference: [(position: CGFloat, velocity: CGFloat, acceleration: CGFloat)] = [
            (200.0000, 0.0000, 0.0000),
            (200.6926, 24.9359, 2992.4269),
            (202.5117, 42.3350, 2721.0173),
            (205.1299, 75.3302, 3092.5849),
            (208.2893, 118.8413, 3731.2723),
            (211.7884, 167.2476, 4354.3774),
            (215.4712, 215.6975, 4792.3306),
            (219.2187, 260.4995, 4967.5702),
            (222.9413, 299.2000, 4870.4040),
            (226.5734, 330.4728, 4535.1506),
            (230.0679, 353.7957, 4014.2633),
            (233.3926, 369.2763, 3367.2399),
            (236.5271, 377.4909, 2652.8063),
            (239.4598, 379.2167, 1919.0930),
            (242.1862, 375.3655, 1204.7339),
            (244.7068, 366.9282, 539.5581),
        ]
        var motion = LiquidLensMotion()
        for (index, item) in reference.enumerated() {
            motion.add(position: CGPoint(x: item.position, y: 30.0), timestamp: 1000.0 + Double(index) / 120.0)
            XCTAssertEqual(motion.velocity.x, item.velocity, accuracy: 0.1)
            XCTAssertEqual(motion.acceleration.x, item.acceleration, accuracy: 5.0)
            XCTAssertEqual(motion.velocity.y, 0.0)
        }
    }

    /// The same move to the left and to the right flexes the same, mirrored: equal scales, opposite drifts.
    func testMovesInOppositeDirectionsAreMirrored() {
        let size = CGSize(width: 95.0, height: 70.0)
        for axis in 0 ..< 2 {
            var forward = Run(size: size)
            var backward = Run(size: size)
            for frame in 0 ..< 90 {
                let time = Double(frame) / 120.0
                let offset = 68.0 * CGFloat(1.0 - exp(-time * 18.0) * (1.0 + time * 18.0))
                let forwardPosition = axis == 0 ? CGPoint(x: 180.0 + offset, y: 31.0) : CGPoint(x: 31.0, y: 180.0 + offset)
                let backwardPosition = axis == 0 ? CGPoint(x: 180.0 - offset, y: 31.0) : CGPoint(x: 31.0, y: 180.0 - offset)
                forward.add(position: forwardPosition, timestamp: 1000.0 + time, isActive: frame < 60)
                backward.add(position: backwardPosition, timestamp: 1000.0 + time, isActive: frame < 60)

                let a = forward.animator.flex
                let b = backward.animator.flex
                XCTAssertEqual(a.scaleX, b.scaleX, accuracy: 0.000001)
                XCTAssertEqual(a.scaleY, b.scaleY, accuracy: 0.000001)
                XCTAssertEqual(a.driftX, -b.driftX, accuracy: 0.000001)
                XCTAssertEqual(a.driftY, -b.driftY, accuracy: 0.000001)
            }
            let peak = forward.peakStretch
            XCTAssertGreaterThan(peak, 1.05)
        }
    }

    /// Speeding up stretches the lens along its path with the trailing edge lagging: the drift points backwards.
    func testSpeedingUpStretchesBehindTheLens() {
        let size = CGSize(width: 95.0, height: 70.0)
        let right = LiquidLensFlex.target(size: size, velocity: CGPoint(x: 400.0, y: 0.0), acceleration: CGPoint(x: 3000.0, y: 0.0))
        XCTAssertGreaterThan(right.scaleX, 1.0)
        XCTAssertLessThan(right.scaleY, 1.0)
        XCTAssertLessThan(right.driftX, 0.0)

        let left = LiquidLensFlex.target(size: size, velocity: CGPoint(x: -400.0, y: 0.0), acceleration: CGPoint(x: 3000.0, y: 0.0))
        XCTAssertEqual(left.scaleX, right.scaleX)
        XCTAssertEqual(left.scaleY, right.scaleY)
        XCTAssertEqual(left.driftX, -right.driftX)
    }

    /// UIKit takes the drift's direction from the sign of the velocity, so a velocity of +0 drifted one way and -0 the
    /// other; without a velocity there is no drift.
    func testNoVelocityNoDrift() {
        let size = CGSize(width: 95.0, height: 70.0)
        let flex = LiquidLensFlex.target(size: size, velocity: CGPoint(), acceleration: CGPoint(x: -2000.0, y: 0.0))
        XCTAssertLessThan(flex.scaleX, 1.0)
        XCTAssertEqual(flex.driftX, 0.0)
    }

    func testSettlesBackToIdentity() {
        let size = CGSize(width: 95.0, height: 70.0)
        var animator = LiquidLensFlexAnimator()
        let target = LiquidLensFlex.target(size: size, velocity: CGPoint(x: 400.0, y: 0.0), acceleration: CGPoint(x: 3000.0, y: 0.0))
        for _ in 0 ..< 30 {
            animator.step(toward: target, size: size, isTracking: true, deltaTime: 1.0 / 120.0)
        }
        XCTAssertFalse(animator.isSettled)
        for _ in 0 ..< 360 {
            animator.step(toward: .identity, size: size, isTracking: false, deltaTime: 1.0 / 120.0)
        }
        XCTAssertTrue(animator.isSettled)
    }
}

final class LiquidLensMotionPlanTests: XCTestCase {
    private let size = CGSize(width: 95.0, height: 70.0)

    private func smoothStep(_ t: Double) -> CGFloat {
        let t = CGFloat(min(1.0, max(0.0, t)))
        return t * t * (3.0 - 2.0 * t)
    }

    func testPlannedMovesInOppositeDirectionsAreMirrored() {
        let start = LiquidLensMotionState(time: 100.0)
        let right = LiquidLensMotionPlan(start: start, segment: LiquidLensPositionSegment(from: CGPoint(x: 180.0, y: 31.0), to: CGPoint(x: 248.25, y: 31.0), startTime: 100.0, duration: 0.4, progress: self.smoothStep), isFlexActive: true, size: self.size)
        let left = LiquidLensMotionPlan(start: start, segment: LiquidLensPositionSegment(from: CGPoint(x: 248.25, y: 31.0), to: CGPoint(x: 180.0, y: 31.0), startTime: 100.0, duration: 0.4, progress: self.smoothStep), isFlexActive: true, size: self.size)
        XCTAssertEqual(right.states.count, left.states.count)
        var peak: CGFloat = 1.0
        for (a, b) in zip(right.states, left.states) {
            XCTAssertEqual(a.animator.flex.scaleX, b.animator.flex.scaleX, accuracy: 0.000001)
            XCTAssertEqual(a.animator.flex.scaleY, b.animator.flex.scaleY, accuracy: 0.000001)
            XCTAssertEqual(a.animator.flex.driftX, -b.animator.flex.driftX, accuracy: 0.000001)
            peak = max(peak, a.animator.flex.scaleX)
        }
        XCTAssertGreaterThan(peak, 1.03)
    }

    func testPlanEndsAtRest() {
        let plan = LiquidLensMotionPlan(start: LiquidLensMotionState(time: 0.0), segment: LiquidLensPositionSegment(from: CGPoint(x: 0.0, y: 0.0), to: CGPoint(x: 100.0, y: 0.0), startTime: 0.0, duration: 0.4, progress: self.smoothStep), isFlexActive: true, size: self.size)
        XCTAssertGreaterThan(plan.endTime, 0.4)
        XCTAssertLessThan(plan.endTime, LiquidLensMotionPlan.maxDuration)
        let last = plan.states[plan.states.count - 1].animator.flex
        XCTAssertEqual(last.scaleX, 1.0, accuracy: 0.001)
        XCTAssertEqual(last.scaleY, 1.0, accuracy: 0.001)
        XCTAssertEqual(last.driftX, 0.0, accuracy: 0.02)
    }

    /// A move replaced in the middle, between two frames, carries on from the flex where it is.
    func testInterruptedPlanContinuesFromItsState() {
        let first = LiquidLensMotionPlan(start: LiquidLensMotionState(time: 0.0), segment: LiquidLensPositionSegment(from: CGPoint(x: 0.0, y: 0.0), to: CGPoint(x: 140.0, y: 0.0), startTime: 0.0, duration: 0.4, progress: self.smoothStep), isFlexActive: true, size: self.size)
        let interruptionTime = 0.137
        let state = first.state(at: interruptionTime)
        XCTAssertEqual(state.time, interruptionTime)
        let position = first.segment.position(at: interruptionTime)
        let second = LiquidLensMotionPlan(start: state, segment: LiquidLensPositionSegment(from: position, to: CGPoint(x: -70.0, y: 0.0), startTime: interruptionTime, duration: 0.4, progress: self.smoothStep), isFlexActive: true, size: self.size)

        XCTAssertEqual(second.states[0].animator.flex, state.animator.flex)
        XCTAssertGreaterThan(state.animator.flex.scaleX, 1.01)
        // One frame later the flex has moved by about as much as a frame moves it, not jumped.
        let before = first.state(at: interruptionTime - LiquidLensMotionPlan.frameDuration).animator.flex
        let change = abs(second.states[1].animator.flex.scaleX - second.states[0].animator.flex.scaleX)
        let previousChange = abs(state.animator.flex.scaleX - before.scaleX)
        XCTAssertLessThan(change, max(0.01, previousChange * 3.0))
        XCTAssertEqual(second.positionKeyframes.first?.position.x ?? 0.0, position.x, accuracy: 0.0001)
    }

    func testPositionKeyframesFollowTheSegment() {
        let segment = LiquidLensPositionSegment(from: CGPoint(x: 10.0, y: 5.0), to: CGPoint(x: 90.0, y: 5.0), startTime: 2.0, duration: 0.4, progress: self.smoothStep)
        let plan = LiquidLensMotionPlan(start: LiquidLensMotionState(time: 2.0), segment: segment, isFlexActive: false, size: self.size)
        let keyframes = plan.positionKeyframes
        XCTAssertEqual(keyframes.count, 49)
        XCTAssertEqual(keyframes.first?.time, 0.0)
        XCTAssertEqual(keyframes.last?.time ?? 0.0, 0.4, accuracy: 0.000001)
        XCTAssertEqual(keyframes.first?.position, CGPoint(x: 10.0, y: 5.0))
        XCTAssertEqual(keyframes.last?.position, CGPoint(x: 90.0, y: 5.0))
        // An inactive flex at rest is not animated, whatever the lens does.
        XCTAssertEqual(plan.states.count, 1)
        XCTAssertFalse(plan.hasFlex)
    }

    func testBezierProgressMatchesTheCurve() {
        let cases: [(x1: Double, y1: Double, x2: Double, y2: Double, fraction: Double, progress: CGFloat)] = [
            (0.42, 0.0, 0.58, 1.0, 0.25, 0.129161931),
            (0.42, 0.0, 0.58, 1.0, 0.5, 0.5),
            (0.38, 0.7, 0.125, 1.0, 0.1, 0.205670047),
            (0.38, 0.7, 0.125, 1.0, 0.5, 0.930837858),
            (0.38, 0.7, 0.125, 1.0, 0.99, 0.999986803),
        ]
        for item in cases {
            XCTAssertEqual(liquidLensBezierProgress(item.x1, item.y1, item.x2, item.y2, item.fraction), item.progress, accuracy: 0.000001)
        }
    }

    /// A move that interrupts another starts with its velocity and still ends where and when the curve does.
    func testRetargetCarriesVelocity() {
        let first = LiquidLensPositionSegment(from: CGPoint(x: 0.0, y: 0.0), to: CGPoint(x: 140.0, y: 0.0), startTime: 0.0, duration: 0.4, progress: { liquidLensBezierProgress(0.380, 0.700, 0.125, 1.000, $0) })
        let time = 0.08
        let velocity = first.velocity(at: time)
        XCTAssertGreaterThan(velocity.x, 300.0)

        let second = LiquidLensPositionSegment(from: first.position(at: time), to: CGPoint(x: -70.0, y: 0.0), startTime: time, duration: 0.4, progress: { liquidLensBezierProgress(0.380, 0.700, 0.125, 1.000, $0) }, initialVelocity: velocity)
        XCTAssertEqual(second.position(at: time).x, first.position(at: time).x, accuracy: 0.0001)
        XCTAssertEqual(second.velocity(at: time).x, velocity.x, accuracy: abs(velocity.x) * 0.01)
        XCTAssertEqual(second.velocity(at: time).y, 0.0, accuracy: 0.0001)
        // It keeps going right for a moment before it turns back.
        XCTAssertGreaterThan(second.position(at: time + 0.02).x, second.position(at: time).x)
        XCTAssertEqual(second.position(at: second.endTime - 0.000001).x, -70.0, accuracy: 0.01)
        XCTAssertEqual(second.position(at: second.endTime).x, -70.0)
        XCTAssertLessThan(abs(second.velocity(at: second.endTime - 0.001).x), 0.5)

        let still = LiquidLensPositionSegment(from: first.position(at: time), to: CGPoint(x: -70.0, y: 0.0), startTime: time, duration: 0.4, progress: { liquidLensBezierProgress(0.380, 0.700, 0.125, 1.000, $0) })
        XCTAssertLessThan(still.position(at: time + 0.02).x, still.position(at: time).x)
    }

    func testCarriedVelocityIsMirrored() {
        let progress: (Double) -> CGFloat = { liquidLensBezierProgress(0.380, 0.700, 0.125, 1.000, $0) }
        let right = LiquidLensPositionSegment(from: CGPoint(x: 200.0, y: 31.0), to: CGPoint(x: 260.0, y: 31.0), startTime: 1.0, duration: 0.4, progress: progress, initialVelocity: CGPoint(x: -500.0, y: 0.0))
        let left = LiquidLensPositionSegment(from: CGPoint(x: 200.0, y: 31.0), to: CGPoint(x: 140.0, y: 31.0), startTime: 1.0, duration: 0.4, progress: progress, initialVelocity: CGPoint(x: 500.0, y: 0.0))
        for frame in 0 ... 48 {
            let time = 1.0 + Double(frame) / 120.0
            XCTAssertEqual(right.position(at: time).x - 200.0, 200.0 - left.position(at: time).x, accuracy: 0.0001)
        }
    }

    func testRestingInactivePlanIsEmpty() {
        let plan = LiquidLensMotionPlan(start: LiquidLensMotionState(time: 5.0), segment: .resting(at: CGPoint(x: 1.0, y: 2.0), time: 5.0), isFlexActive: false, size: self.size)
        XCTAssertEqual(plan.states.count, 1)
        XCTAssertFalse(plan.hasFlex)
        XCTAssertTrue(plan.positionKeyframes.isEmpty)
    }
}

private struct Run {
    let size: CGSize
    var motion = LiquidLensMotion()
    var animator = LiquidLensFlexAnimator()
    var timestamp: Double?
    var peakStretch: CGFloat = 1.0

    init(size: CGSize) {
        self.size = size
    }

    mutating func add(position: CGPoint, timestamp: Double, isActive: Bool) {
        let deltaTime = self.timestamp.map { timestamp - $0 } ?? 0.0
        self.timestamp = timestamp
        var target = LiquidLensFlex.identity
        if isActive {
            self.motion.add(position: position, timestamp: timestamp)
            target = LiquidLensFlex.target(size: self.size, velocity: self.motion.velocity, acceleration: self.motion.acceleration)
        }
        self.animator.step(toward: target, size: self.size, isTracking: isActive, deltaTime: deltaTime)
        self.peakStretch = max(self.peakStretch, self.animator.flex.scaleX, self.animator.flex.scaleY)
    }
}

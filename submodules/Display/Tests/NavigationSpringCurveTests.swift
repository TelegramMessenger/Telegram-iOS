import XCTest
import UIKit
@testable import Display

/// A spring's motion as a function of time: the same closed form the frame-by-frame springs stepped, so a curve gives
/// the values the display link gave, independent of how time is split.
final class NavigationSpringCurveTests: XCTestCase {
    private func stepped(_ spring: NavigationTransitionSpring, from: CGFloat, velocity: CGFloat = 0.0, to target: CGFloat, until time: Double, step: Double = 1.0 / 120.0) -> (value: CGFloat, velocity: CGFloat) {
        var state = (value: from, velocity: velocity)
        var t = 0.0
        while t + step <= time + 1e-9 {
            state = spring.advance(value: state.value, velocity: state.velocity, target: target, time: CGFloat(step))
            t += step
        }
        return state
    }

    // A tap push after 0.1 s: progress = 1 - (1 + w t) e^(-w t), w = 2 pi / 0.3, exactly as twelve 1/120 s steps.
    func test_value_isTheClosedForm_andMatchesSteppedFrames() {
        let curve = NavigationSpringCurve(from: 0.0, target: 1.0, spring: .noninteractive, rest: .progress)
        let omegaT = 2.0 * CGFloat.pi / 0.3 * 0.1
        XCTAssertEqual(curve.value(at: 0.1), 1.0 - (1.0 + omegaT) * exp(-omegaT), accuracy: 1e-9)
        let stepped = self.stepped(.noninteractive, from: 0.0, to: 1.0, until: 0.1)
        XCTAssertEqual(curve.value(at: 0.1), stepped.value, accuracy: 1e-9)
        XCTAssertEqual(curve.velocity(at: 0.1), stepped.velocity, accuracy: 1e-6)
    }

    // The glass transition spring (0.416, bounce 0.25), measured values (glass RE §2.2).
    func test_glassTransitionSpring_givesTheMeasuredValues() {
        let curve = NavigationSpringCurve(from: 0.0, target: 1.0, spring: NavigationTransitionSpring(duration: 0.416, bounce: 0.25), rest: .glass(0.001))
        XCTAssertEqual(curve.value(at: 0.05), 0.1935, accuracy: 0.0005)
        XCTAssertEqual(curve.value(at: 0.1), 0.5185, accuracy: 0.0005)
        XCTAssertEqual(curve.value(at: 0.2), 0.9359, accuracy: 0.0005)
        XCTAssertEqual(curve.value(at: 0.3), 1.0276, accuracy: 0.0005)
    }

    // Rest is today's rule, found within one 120 Hz frame of where the display link found it; from there the curve is
    // exactly at its target.
    func test_restTime_isTodaysSettleRule_andTheValueSnapsThere() {
        let curve = NavigationSpringCurve(from: 0.0, target: 1.0, spring: .noninteractive, rest: .progress)
        var state = (value: CGFloat(0.0), velocity: CGFloat(0.0))
        var frames = 0
        while !(abs(state.value - 1.0) < 0.0005 && abs(state.velocity) < 0.005) {
            state = NavigationTransitionSpring.noninteractive.advance(value: state.value, velocity: state.velocity, target: 1.0, time: 1.0 / 120.0)
            frames += 1
        }
        XCTAssertEqual(curve.restTime, Double(frames) / 120.0, accuracy: 1.0 / 120.0)
        XCTAssertEqual(curve.value(at: curve.restTime), 1.0)
        XCTAssertEqual(curve.velocity(at: curve.restTime + 0.1), 0.0)
    }

    // A released swipe stops at its target instead of overshooting it: the rest time is the first crossing.
    func test_notOvershooting_stopsAtTheFirstCrossing() {
        let curve = NavigationSpringCurve(from: 0.6, velocity: 4.0, target: 1.0, spring: .interactive, overshoots: false, rest: .progress)
        var maximum: CGFloat = 0.0
        for i in 0 ... 600 {
            maximum = max(maximum, curve.value(at: Double(i) / 600.0))
        }
        XCTAssertEqual(maximum, 1.0)
        XCTAssertLessThan(curve.value(at: curve.restTime - 0.001), 1.0)
        XCTAssertLessThan(curve.restTime, 0.3)
    }

    // A curve that starts later holds its start value until then (the pulse's delayed falling springs).
    func test_delayedCurve_holdsItsStartValue() {
        let curve = NavigationSpringCurve(startTime: 0.113, from: 1.0, target: 0.0, spring: NavigationTransitionSpring(duration: 0.416, bounce: 0.416), rest: .glass(0.001))
        XCTAssertEqual(curve.value(at: 0.05), 1.0)
        XCTAssertEqual(curve.velocity(at: 0.05), 0.0)
        XCTAssertLessThan(curve.value(at: 0.2), 1.0)
    }

    // Re-aiming keeps the value and velocity where it happens; re-basing moves the clock without moving the motion.
    func test_retargetedAndRebased_areContinuous() {
        let curve = NavigationSpringCurve(from: 0.0, target: 1.0, spring: .noninteractive, rest: .progress)
        let retargeted = curve.retargeted(at: 0.1, to: 0.0, spring: .interactive, overshoots: false)
        XCTAssertEqual(retargeted.value(at: 0.1), curve.value(at: 0.1), accuracy: 1e-12)
        XCTAssertEqual(retargeted.velocity(at: 0.1), curve.velocity(at: 0.1), accuracy: 1e-9)
        let rebased = retargeted.rebased(by: 0.1)
        XCTAssertEqual(rebased.value(at: 0.05), retargeted.value(at: 0.15), accuracy: 1e-12)
        XCTAssertEqual(rebased.restTime, retargeted.restTime - 0.1, accuracy: 1e-12)
    }

    func test_constant_isAtRestAtOnce() {
        let curve = NavigationSpringCurve.constant(44.0, rest: .glass(0.01))
        XCTAssertEqual(curve.restTime, 0.0)
        XCTAssertEqual(curve.value(at: 3.0), 44.0)
    }
}

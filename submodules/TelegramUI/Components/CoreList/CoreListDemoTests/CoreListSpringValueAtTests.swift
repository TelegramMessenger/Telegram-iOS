import XCTest
import QuartzCore
@testable import CoreListDemo

/// `valueAt:` is a private CASpringAnimation selector. Display calls it with a unit phase
/// (`listViewAnimationCurveSystem` passes `offset ∈ [0,1]`) but builds the animation with
/// `duration: 0.5`, so a seconds domain is equally plausible from the call site alone. Getting it
/// wrong yields a silently wrong curve, so it is pinned here before anything depends on it.
final class CoreListSpringValueAtTests: XCTestCase {
    func testSpringKindResolvesFromLogicalDuration() {
        XCTAssertEqual(coreListSpringKind(logicalDuration: 0.5), .system05)
        XCTAssertEqual(coreListSpringKind(logicalDuration: 0.4), .adjustedBezier)
        XCTAssertEqual(coreListSpringKind(logicalDuration: 0.3), .adjustedBezier)
        // A Slow-Animations-scaled 0.5 must NOT resolve as the system spring.
        XCTAssertEqual(coreListSpringKind(logicalDuration: 5.0), .adjustedBezier)
        if #available(iOS 26.0, *) {
            XCTAssertEqual(coreListSpringKind(logicalDuration: 0.3832), .system26)
            XCTAssertEqual(coreListSpringKind(logicalDuration: 0.38325), .system26)
            XCTAssertEqual(coreListSpringKind(logicalDuration: 0.3840), .adjustedBezier)
        }
    }

    /// The domain assertion. A unit-phase evaluator is 0 at 0 and 1 at 1; a seconds evaluator fed
    /// a unit phase would still be mid-flight at 1.0 for the 0.5s spring.
    func testValueAtTakesUnitPhaseAndSpansZeroToOne() throws {
        let atZero = try XCTUnwrap(coreListSpringValue(kind: .system05, phase: 0))
        let atOne = try XCTUnwrap(coreListSpringValue(kind: .system05, phase: 1))
        XCTAssertEqual(atZero, 0, accuracy: 1e-6,
                       "valueAt: is not a unit-phase evaluator — see the plan's fallback note")
        XCTAssertEqual(atOne, 1, accuracy: 1e-3,
                       "valueAt: is not a unit-phase evaluator — see the plan's fallback note")
    }

    func testSystemSpringIsMonotonicAndOvershootFree() throws {
        // mass 3 / stiffness 1000 / damping 500 is heavily overdamped (critical ≈ 109.5),
        // so it approaches its target without overshoot.
        var previous: CGFloat = -1
        for step in 0...100 {
            let value = try XCTUnwrap(coreListSpringValue(kind: .system05,
                                                          phase: CGFloat(step) / 100.0))
            XCTAssertGreaterThanOrEqual(value, previous - 1e-9, "regressed at step \(step)")
            XCTAssertLessThanOrEqual(value, 1.0 + 1e-6, "overshot at step \(step)")
            previous = value
        }
    }

    func testAdjustedBezierKindHasNoSpringEvaluator() {
        XCTAssertNil(coreListSpringValue(kind: .adjustedBezier, phase: 0.5),
                     "the bezier branch is solved by Curve.solve, not by a CASpringAnimation")
    }

    func testTrackWithSystemSpringUsesTheSpringEvaluatorNotTheBezier() throws {
        let spring = ListAnimationTrack(generation: 1, from: 0, to: 100,
                                        startTime: 0, duration: 0.5,
                                        curve: .spring, springKind: .system05)
        let bezier = ListAnimationTrack(generation: 2, from: 0, to: 100,
                                        startTime: 0, duration: 0.5,
                                        curve: .spring, springKind: .adjustedBezier)

        XCTAssertEqual(spring.value(at: 0), 0, accuracy: 1e-6)
        XCTAssertEqual(spring.value(at: 0.5), 100, accuracy: 0.1)

        // The two branches are genuinely different curves; if springKind were ignored these would
        // coincide and the test would be vacuous.
        var maxDifference: CGFloat = 0
        for step in 0...100 {
            let t = 0.5 * Double(step) / 100.0
            maxDifference = max(maxDifference, abs(spring.value(at: t) - bezier.value(at: t)))
        }
        XCTAssertGreaterThan(maxDifference, 1.0,
                             "system spring and adjusted bezier should not coincide")
    }

    func testZeroDurationTrackStillSettlesRegardlessOfSpringKind() {
        let track = ListAnimationTrack(generation: 3, from: 0, to: 100,
                                       startTime: 0, duration: 0,
                                       curve: .spring, springKind: .system05)
        XCTAssertEqual(track.value(at: 0), 100)
        XCTAssertEqual(track.value(at: 99), 100)
    }

}

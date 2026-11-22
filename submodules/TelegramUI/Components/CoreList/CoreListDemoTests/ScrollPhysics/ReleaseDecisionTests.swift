import XCTest
@testable import CoreListDemo

/// `-[UIScrollView _endPanNormal:]` release-path parity. Velocities in the assertions are
/// points/MILLISECOND, content-signed: a finger moving up (negative recognizer velocity) sends the
/// content offset up (positive).
final class ReleaseDecisionTests: XCTestCase {

    /// Recognizer velocity (pts/s, finger-signed) that produces `v` pts/ms of content velocity.
    private func recognizer(_ v: CGFloat) -> CGPoint { CGPoint(x: 0, y: -v * 1000) }

    private func releasedVelocity(_ outcome: ReleaseDecision.Outcome) -> CGPoint? {
        if case let .decelerate(velocity, _) = outcome { return velocity }
        return nil
    }

    // MARK: - D1: the blend is guarded

    func test_beganOnlyFlick_releasesAtFullVelocity_becauseTheBlendIsGuarded() throws {
        var d = ReleaseDecision()
        d.beginGesture()
        d.note(recognizerVelocity: recognizer(3.0), translation: CGPoint(x: 0, y: -12))
        let out = d.release(recognizerVelocity: recognizer(3.0), at: 0)

        XCTAssertEqual(try XCTUnwrap(releasedVelocity(out)).y, 3.0, accuracy: 1e-9,
                       "no .changed event ⇒ previous is zero ⇒ UIKit skips the blend entirely (0x179f94c)")
    }

    func test_beganOnlyFlick_nonVacuity_theUnguardedBlendWouldBeAQuarter() {
        // The control for the test above: state the value the DEFECT produces, so the guard test
        // cannot pass against the behaviour it names.
        var d = ReleaseDecision()
        d.beginGesture()
        d.note(recognizerVelocity: recognizer(3.0), translation: CGPoint(x: 0, y: -12))
        let unguarded = ReleaseDecision.previousWeight * d.previous.y
            + ReleaseDecision.latestWeight * d.latest.y

        XCTAssertEqual(unguarded, 0.75, accuracy: 1e-9, "0.75·0 + 0.25·3.0 — a quarter of the flick")
        XCTAssertNotEqual(unguarded, 3.0, accuracy: 1e-9)
    }

    func test_oneChangedEvent_blendsBeganAndChanged() throws {
        var d = ReleaseDecision()
        d.beginGesture()
        d.note(recognizerVelocity: recognizer(2.0), translation: CGPoint(x: 0, y: -12))   // .began
        d.note(recognizerVelocity: recognizer(4.0), translation: CGPoint(x: 0, y: -40))   // .changed #1
        let out = d.release(recognizerVelocity: recognizer(4.0), at: 0)

        XCTAssertEqual(try XCTUnwrap(releasedVelocity(out)).y, 0.75 * 2.0 + 0.25 * 4.0, accuracy: 1e-9)
    }

    func test_manyChangedEvents_matchTheLastTwoSamples() throws {
        // The medium-flick regression control: at high event counts the model is unchanged, which is
        // why every existing fixture agrees today.
        var d = ReleaseDecision()
        d.beginGesture()
        for (i, v) in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0].enumerated() {
            d.note(recognizerVelocity: recognizer(CGFloat(v)),
                   translation: CGPoint(x: 0, y: CGFloat(-12 * (i + 1))))
        }
        let out = d.release(recognizerVelocity: recognizer(6.0), at: 0)

        XCTAssertEqual(try XCTUnwrap(releasedVelocity(out)).y, 0.75 * 5.0 + 0.25 * 6.0, accuracy: 1e-9)
    }

    // MARK: - D2: the threshold is raw, pre-blend, 2-D

    func test_threshold_readsTheRawLatestSample_notTheBlendedOne() throws {
        // latest 0.5 clears 0.25; the blended value 0.75·0.1 + 0.25·0.5 = 0.2 does not.
        var d = ReleaseDecision()
        d.beginGesture()
        d.note(recognizerVelocity: recognizer(0.1), translation: CGPoint(x: 0, y: -12))
        d.note(recognizerVelocity: recognizer(0.5), translation: CGPoint(x: 0, y: -20))
        let out = d.release(recognizerVelocity: recognizer(0.5), at: 0)

        XCTAssertEqual(try XCTUnwrap(releasedVelocity(out)).y, 0.2, accuracy: 1e-9,
                       "decelerates on the RAW 0.5, at the BLENDED 0.2 (0x179f6d8 precedes 0x179f94c)")
    }

    func test_threshold_nonVacuity_theBlendedValueWouldHaveStopped() {
        let blended: CGFloat = 0.75 * 0.1 + 0.25 * 0.5
        XCTAssertLessThan(blended * blended, ReleaseDecision.decelerateThresholdSquared,
                          "the blended value fails the threshold — so the test above is not vacuous")
    }

    func test_threshold_isTwoDimensional() {
        // |v|² = 0.08 ≥ 0.0625 clears it; neither axis clears 0.25 alone.
        var d = ReleaseDecision()
        d.beginGesture()
        d.note(recognizerVelocity: CGPoint(x: -200, y: -200), translation: CGPoint(x: 8, y: -8))
        let out = d.release(recognizerVelocity: CGPoint(x: -200, y: -200), at: 0)

        XCTAssertNotNil(releasedVelocity(out), "0.2² + 0.2² = 0.08 ≥ 0.0625")
        XCTAssertLessThan(0.2 * 0.2, ReleaseDecision.decelerateThresholdSquared,
                          "non-vacuity: a per-axis test would have stopped")
    }

    /// Migrated from `ScrollAxisTests.testTwoAxisEndDragForwardsToBothAxes`, whose expectation the
    /// 2-D threshold overturns: it asserted the slow axis reported `.stop` INDEPENDENTLY. UIKit tests
    /// `vx² + vy²` once (`0x179f6d8`), so a slow axis rides a fast one into deceleration.
    func test_aSlowAxisRidesAFastOneBecauseTheThresholdIsJoint() throws {
        var d = ReleaseDecision()
        d.beginGesture()
        // x slow (0.05 pts/ms), y fast (2.0 pts/ms).
        d.note(recognizerVelocity: CGPoint(x: -50, y: -2000), translation: CGPoint(x: -1, y: -40))
        let out = d.release(recognizerVelocity: CGPoint(x: -50, y: -2000), at: 0)

        let v = try XCTUnwrap(releasedVelocity(out))
        XCTAssertEqual(v.x, 0.05, accuracy: 1e-9, "the slow axis decelerates too")
        XCTAssertEqual(v.y, 2.0, accuracy: 1e-9)
        XCTAssertLessThan(0.05 * 0.05, ReleaseDecision.decelerateThresholdSquared,
                          "non-vacuity: alone, x would have stopped — which is what the old test asserted")
    }

    func test_belowThreshold_stopsAndZeroesEverything() {
        var d = ReleaseDecision()
        d.beginGesture()
        d.note(recognizerVelocity: recognizer(0.1), translation: CGPoint(x: 0, y: -4))
        d.note(recognizerVelocity: recognizer(0.1), translation: CGPoint(x: 0, y: -6))
        let out = d.release(recognizerVelocity: recognizer(0.1), at: 0)

        XCTAssertEqual(out, .stop)
        XCTAssertEqual(d.latest, .zero)
        XCTAssertEqual(d.previous, .zero)
    }

    func test_exactlyZeroRecognizerVelocityAtRelease_zeroesTheStoredSample() {
        // 0x179f5e0 — UIKit re-reads velocityInView at release and zeroes on an exact CGPointZero.
        var d = ReleaseDecision()
        d.beginGesture()
        d.note(recognizerVelocity: recognizer(3.0), translation: CGPoint(x: 0, y: -12))
        d.note(recognizerVelocity: recognizer(3.0), translation: CGPoint(x: 0, y: -40))
        let out = d.release(recognizerVelocity: .zero, at: 0)

        XCTAssertEqual(out, .stop)
        XCTAssertEqual(d.latest, .zero)
    }

    func test_beginGesture_clearsBothPairs() {
        // handlePan: case 1 zeroes all four ivars BEFORE .began's own _updatePanGesture, which is
        // what arms the D1 guard for a zero-.changed flick.
        var d = ReleaseDecision()
        d.beginGesture()
        d.note(recognizerVelocity: recognizer(3.0), translation: CGPoint(x: 0, y: -12))
        d.note(recognizerVelocity: recognizer(3.0), translation: CGPoint(x: 0, y: -40))
        XCTAssertNotEqual(d.previous, .zero)

        d.beginGesture()
        XCTAssertEqual(d.latest, .zero)
        XCTAssertEqual(d.previous, .zero)
    }

    func test_noteConvertsPointsPerSecondToPointsPerMillisecond_andNegates() {
        var d = ReleaseDecision()
        d.beginGesture()
        d.note(recognizerVelocity: CGPoint(x: 500, y: -3000), translation: .zero)
        XCTAssertEqual(d.latest.x, -0.5, accuracy: 1e-12)
        XCTAssertEqual(d.latest.y, 3.0, accuracy: 1e-12)
    }
}

// MARK: - D3: repeated-flick acceleration

extension ReleaseDecisionTests {

    /// Drive one whole flick gesture at `v` pts/ms over `frames` pan callbacks, travelling
    /// `distance` points, releasing at `t`.
    @discardableResult
    private func flick(_ d: inout ReleaseDecision, v: CGFloat, distance: CGFloat,
                       frames: Int = 4, at t: TimeInterval,
                       touchDownAt touchDown: TimeInterval? = nil) -> ReleaseDecision.Outcome {
        d.beginTouchTracking(at: touchDown ?? t)
        d.beginGesture()
        for i in 1...frames {
            let travelled = -distance * CGFloat(i) / CGFloat(frames)
            d.note(recognizerVelocity: CGPoint(x: 0, y: -v * 1000),
                   translation: CGPoint(x: 0, y: travelled))
        }
        return d.release(recognizerVelocity: CGPoint(x: 0, y: -v * 1000), at: t)
    }

    private func scale(_ outcome: ReleaseDecision.Outcome) -> CGFloat? {
        if case let .decelerate(_, vScale) = outcome { return vScale }
        return nil
    }

    func test_firstFastFlick_hasNoMultiplier() throws {
        var d = ReleaseDecision()
        let out = flick(&d, v: 3.0, distance: 300, at: 0)
        XCTAssertEqual(try XCTUnwrap(scale(out)), 1.0, accuracy: 1e-9,
                       "growth needs count >= 3 (0x179d8cc)")
        XCTAssertEqual(d.streakCount, 1)
    }

    func test_fourthConsecutiveFastFlick_multipliesTheDeceleration() throws {
        // count reaches 3 during the FOURTH gesture's drag, so that gesture is the first to grow.
        var d = ReleaseDecision()
        for i in 0..<3 { flick(&d, v: 3.0, distance: 300, at: TimeInterval(i) * 0.4) }
        XCTAssertEqual(d.streakCount, 3)

        let out = flick(&d, v: 3.0, distance: 300, at: 1.2)
        // startMultiplier 1.0 + (1 + (3-3)/2) · min(300/240, 0.9) = 1.0 + 1 · 0.9 = 1.9
        XCTAssertEqual(try XCTUnwrap(scale(out)), 1.9, accuracy: 1e-6)
    }

    func test_multiplierGrowsWithStreakLengthAndDragDistance() throws {
        var d = ReleaseDecision()
        for i in 0..<5 { flick(&d, v: 3.0, distance: 120, at: TimeInterval(i) * 0.4) }
        XCTAssertEqual(d.streakCount, 5)

        // dist 120 ⇒ min(120/240, 0.9) = 0.5 ; count 5 ⇒ (1 + (5-3)/2) = 2 ; start = carried multiplier
        let before = d.multiplier
        let out = flick(&d, v: 3.0, distance: 120, at: 2.0)
        XCTAssertEqual(try XCTUnwrap(scale(out)), before + 2.0 * 0.5, accuracy: 1e-6)
    }

    func test_multiplierIsCappedAt16() {
        var d = ReleaseDecision()
        for i in 0..<40 { flick(&d, v: 3.0, distance: 400, at: TimeInterval(i) * 0.4) }
        XCTAssertEqual(d.multiplier, 16.0, accuracy: 1e-9, "0x179d940")
    }

    func test_aPauseLongerThanOneSecondExpiresTheStreak() throws {
        var d = ReleaseDecision()
        for i in 0..<4 { flick(&d, v: 3.0, distance: 300, at: TimeInterval(i) * 0.4) }
        XCTAssertGreaterThan(d.multiplier, 1.0)

        // Released at 1.2; the next touch-down lands at 2.4, more than 1.0 s later.
        let out = flick(&d, v: 3.0, distance: 300, at: 2.5, touchDownAt: 2.4)
        XCTAssertEqual(try XCTUnwrap(scale(out)), 1.0, accuracy: 1e-9,
                       "0x17b1488 — one second since you last let go")
        XCTAssertEqual(d.streakCount, 1, "the expiry reset the count before this flick counted itself")
    }

    func test_aPauseShorterThanOneSecondKeepsTheStreak() throws {
        var d = ReleaseDecision()
        for i in 0..<4 { flick(&d, v: 3.0, distance: 300, at: TimeInterval(i) * 0.4) }
        let carried = d.multiplier

        let out = flick(&d, v: 3.0, distance: 300, at: 2.0, touchDownAt: 1.9)
        XCTAssertGreaterThan(try XCTUnwrap(scale(out)), carried,
                             "the streak compounds from the carried multiplier")
    }

    func test_aSlowReleaseBreaksTheStreak() {
        var d = ReleaseDecision()
        for i in 0..<4 { flick(&d, v: 3.0, distance: 300, at: TimeInterval(i) * 0.4) }
        XCTAssertGreaterThan(d.multiplier, 1.0)

        // |v| = 0.3 ⇒ |v|² = 0.09, above the 0.0625 decelerate floor but below the 0.36 fast floor.
        flick(&d, v: 0.3, distance: 40, at: 1.6)
        XCTAssertEqual(d.streakCount, 0, "0x179fc7c")
        XCTAssertEqual(d.multiplier, 1.0, accuracy: 1e-9)
    }

    func test_aDirectionReversalMidDragBreaksTheStreak() {
        var d = ReleaseDecision()
        for i in 0..<4 { flick(&d, v: 3.0, distance: 300, at: TimeInterval(i) * 0.4) }
        XCTAssertGreaterThan(d.multiplier, 1.0)

        d.beginTouchTracking(at: 1.6)
        d.beginGesture()
        d.note(recognizerVelocity: CGPoint(x: 0, y: -3000), translation: CGPoint(x: 0, y: -100))
        d.note(recognizerVelocity: CGPoint(x: 0, y: 3000), translation: CGPoint(x: 0, y: -40))  // reversed
        XCTAssertEqual(d.streakCount, 0, "0x179d5ec — bit 11 holds the vertical sign")
        XCTAssertEqual(d.multiplier, 1.0, accuracy: 1e-9)
    }

    func test_slowingBelowThirteenHundredthsMidDragBreaksTheStreak() {
        var d = ReleaseDecision()
        for i in 0..<4 { flick(&d, v: 3.0, distance: 300, at: TimeInterval(i) * 0.4) }

        d.beginTouchTracking(at: 1.6)
        d.beginGesture()
        d.note(recognizerVelocity: CGPoint(x: 0, y: -3000), translation: CGPoint(x: 0, y: -100))
        d.note(recognizerVelocity: CGPoint(x: 0, y: -100), translation: CGPoint(x: 0, y: -102))  // 0.1 pts/ms
        XCTAssertEqual(d.streakCount, 0, "|v|² = 0.01 < 0.0169 (0x179d61c)")
        XCTAssertEqual(d.multiplier, 1.0, accuracy: 1e-9)
    }

    func test_theIntegratorReachingSpringOrSettleResetsTheStreak() {
        var d = ReleaseDecision()
        for i in 0..<4 { flick(&d, v: 3.0, distance: 300, at: TimeInterval(i) * 0.4) }
        XCTAssertGreaterThan(d.multiplier, 1.0)

        d.resetStreakAfterDeceleration()            // 0x17a87bc (spring) / 0x17a8844 (settle)
        XCTAssertEqual(d.multiplier, 1.0, accuracy: 1e-9)
        XCTAssertEqual(d.streakCount, 0)
    }

    func test_aStoppedReleaseResetsTheStreak() {
        var d = ReleaseDecision()
        for i in 0..<4 { flick(&d, v: 3.0, distance: 300, at: TimeInterval(i) * 0.4) }

        // |v| = 0.1 ⇒ below the decelerate floor entirely.
        let out = flick(&d, v: 0.1, distance: 5, at: 1.6)
        XCTAssertEqual(out, .stop)
        XCTAssertEqual(d.multiplier, 1.0, accuracy: 1e-9)
        XCTAssertEqual(d.streakCount, 0)
    }

    func test_distanceTermIsClampedAtNinetyPercent() throws {
        var d = ReleaseDecision()
        // 400 pt travel ⇒ 400/240 = 1.67, clamped to 0.9.
        for i in 0..<3 { flick(&d, v: 3.0, distance: 400, at: TimeInterval(i) * 0.4) }
        let out = flick(&d, v: 3.0, distance: 400, at: 1.2)
        XCTAssertEqual(try XCTUnwrap(scale(out)), 1.0 + 1.0 * 0.9, accuracy: 1e-6, "0x179d924")
    }
}

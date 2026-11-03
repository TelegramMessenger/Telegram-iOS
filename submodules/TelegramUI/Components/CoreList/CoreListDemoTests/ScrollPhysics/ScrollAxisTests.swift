import XCTest
import CoreGraphics
import Foundation
@testable import CoreListDemo

/// `ScrollAxis` owns position, bounds and the integrator. It does NOT own the release decision —
/// that is two-dimensional (the threshold is `vx² + vy²`, the low-pass guard tests both axes
/// jointly) and lives in `ReleaseDecision`, covered by `ReleaseDecisionTests`. The release tests
/// that used to live here moved there when the responsibility did; see in particular
/// `test_oneChangedEvent_blendsBeganAndChanged` (the old
/// `testEndDragFiltersVelocityAndDeceleratesAboveThreshold`),
/// `test_belowThreshold_stopsAndZeroesEverything` (the old `testEndDragBelowThresholdStops`) and
/// `test_aSlowAxisRidesAFastOneBecauseTheThresholdIsJoint` (the old
/// `testTwoAxisEndDragForwardsToBothAxes`, whose per-axis expectation the 2-D threshold overturns).
final class ScrollAxisTests: XCTestCase {
    private func makeAxis(offset: CGFloat = 0) -> ScrollAxis {
        ScrollAxis(offset: offset, min: 0, max: 1000, range: 400,
                   rate: 0.998, scale: 2, vScale: 1)
    }

    func testDragMapsOffsetToStartMinusTranslation() {
        var a = makeAxis()
        a.beginDrag()
        a.drag(translation: -100)                          // offset = 0 − (−100) = 100
        XCTAssertEqual(a.offset, 100, accuracy: 1e-9)
    }

    func testDragPastTopRubberBands() {
        var a = makeAxis()
        a.beginDrag()
        a.drag(translation: 50)                            // proposed = −50 → rubber-band
        XCTAssertEqual(a.offset, -25.7307, accuracy: 1e-3) // −400·(1−1/(1+0.55·50/400))
    }

    func testApplyReleaseEntersDeceleration() {
        var a = makeAxis()
        a.beginDrag()
        a.drag(translation: 0)
        a.applyRelease(velocity: 1.25)
        XCTAssertEqual(a.velocity, 1.25, accuracy: 1e-9)
        XCTAssertEqual(a.phase, .decelerating)
    }

    /// An axis released while overscrolled springs back even at zero velocity — which is how
    /// `PhysicsScrollCore` handles a tap or tiny drag during a bounce, since a `.stop` outcome there
    /// still installs a zero-velocity release rather than freezing the content off the edge.
    func testZeroVelocityReleaseInOverscrollStillSpringsBack() {
        var a = ScrollAxis(offset: 1100, min: 0, max: 1000, range: 400,   // 100px past the bottom edge
                           rate: 0.998, scale: 2, vScale: 1)
        a.beginDrag()
        a.applyRelease(velocity: 0)
        let before = a.offset
        _ = a.step(dtMs: 16.667)
        XCTAssertLessThan(a.offset, before)                 // springs toward the edge
        XCTAssertGreaterThan(a.offset, 1000)                // ...monotonically, not past it
    }

    func testStepReturnsPixelRoundedWrittenOffset() {
        var a = makeAxis()
        a.beginDrag()
        a.drag(translation: 0)
        a.applyRelease(velocity: 2.0)
        let (written, settled, _) = a.step(dtMs: 16.667)
        XCTAssertFalse(settled)
        XCTAssertGreaterThan(written, 0)                                       // moved forward
        // written lands on the 1/scale grid (scale 2 → multiples of 0.5)
        XCTAssertEqual(written.truncatingRemainder(dividingBy: 0.5), 0, accuracy: 1e-9)
        // ...while the internal offset keeps full precision (proves rounding actually occurred)
        XCTAssertNotEqual(written, a.offset)
    }

    /// The integrator clears its own `vScale` on the frame that ends the deceleration, which is what
    /// `Trajectory.build` observes to re-time the reset onto a baked keyframe path.
    func testEndingTheDecelerationClearsTheVelocityScale() {
        // At vScale 4 a 3.0 pts/ms release advances ~196.5pt in one 16.667ms frame, so max = 100 is
        // genuinely crossed; max = 200 would NOT be, and the test would assert nothing.
        var a = ScrollAxis(offset: 0, min: 0, max: 100, range: 400,
                           rate: 0.998, scale: 2, vScale: 4)
        a.beginDrag()
        a.applyRelease(velocity: 3.0)
        let (_, _, ended) = a.step(dtMs: 16.667)
        XCTAssertTrue(ended, "crossed the edge into the spring")
        XCTAssertEqual(a.vScale, 1, accuracy: 1e-12, "0x17a87bc")
    }

    func testTwoAxisPhysicsDragsBothIndependently() {
        var p = ScrollPhysics(
            x: ScrollAxis(offset: 0, min: 0, max: 500, range: 300, rate: 0.998, scale: 2, vScale: 1),
            y: ScrollAxis(offset: 0, min: 0, max: 1000, range: 400, rate: 0.998, scale: 2, vScale: 1))
        p.beginDrag()
        p.drag(translation: CGPoint(x: -30, y: -60))
        XCTAssertEqual(p.x.offset, 30, accuracy: 1e-9)
        XCTAssertEqual(p.y.offset, 60, accuracy: 1e-9)
    }

    /// `ScrollPhysics.step` ORs the two axes' "ended a deceleration" flags, which is right — one axis
    /// reaching its edge is a real end. But `PhysicsScrollCore` pins x to a DEAD axis (offset 0,
    /// min == max == 0, no velocity), and an axis that is in bounds and below the velocity floor
    /// settles on its very first frame. Left ungated, the pair therefore reported a deceleration
    /// ending on every single frame, and the fast-scroll streak — which the core clears on exactly
    /// that signal — could never survive to the three consecutive flicks its multiplier needs.
    func testADeadAxisDoesNotReportEndingADecelerationTheOtherAxisIsStillRunning() {
        var p = ScrollPhysics(
            x: ScrollAxis(offset: 0, min: 0, max: 0, range: 390, rate: 0.998, scale: 2, vScale: 1),
            y: ScrollAxis(offset: 0, min: -100_000, max: 100_000, range: 800,
                          rate: 0.998, scale: 2, vScale: 4))
        p.beginDrag()
        p.applyRelease(velocity: CGPoint(x: 0, y: -3.0))

        let r = p.step(dtMs: 1000.0 / 120.0)
        XCTAssertTrue(p.x.phase == .idle, "x really does settle immediately — the premise holds")
        XCTAssertFalse(r.settled, "y is still travelling at 3 pts/ms")
        XCTAssertFalse(r.endedDeceleration,
                       "x was already at rest; it cannot end a deceleration it never ran")
        XCTAssertEqual(p.y.vScale, 4, accuracy: 1e-12,
                       "and the live axis keeps the fast-scroll scale it was launched with")
    }

    func testTwoAxisApplyReleaseForwardsToBothAxes() {
        var p = ScrollPhysics(
            x: ScrollAxis(offset: 0, min: 0, max: 500, range: 300, rate: 0.998, scale: 2, vScale: 1),
            y: ScrollAxis(offset: 0, min: 0, max: 1000, range: 400, rate: 0.998, scale: 2, vScale: 1))
        p.beginDrag()
        p.applyRelease(velocity: CGPoint(x: 0.05, y: 2.0))
        XCTAssertEqual(p.x.velocity, 0.05, accuracy: 1e-9)
        XCTAssertEqual(p.y.velocity, 2.0, accuracy: 1e-9)
        XCTAssertEqual(p.x.phase, .decelerating)
        XCTAssertEqual(p.y.phase, .decelerating)
    }
}

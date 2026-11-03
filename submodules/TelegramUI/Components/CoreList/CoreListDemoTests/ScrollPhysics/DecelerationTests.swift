import XCTest
import CoreGraphics
import Foundation
@testable import CoreListDemo

final class DecelerationTests: XCTestCase {
    // rate 0.998 per ms (decay = rate^dtMs)
    private func makeDecel(offset: CGFloat, velocity: CGFloat,
                           min: CGFloat = 0, max: CGFloat = 1000) -> Deceleration {
        Deceleration(offset: offset, velocity: velocity, min: min, max: max,
                     rate: 0.998, vScale: 1)
    }

    func testDecayIsRateToThePowerOfMilliseconds() {
        // 0.998^16.667 = exp(16.667·ln0.998) ≈ 0.967183
        XCTAssertEqual(Deceleration.decay(dtMs: 16.667, rate: 0.998), 0.967183, accuracy: 1e-5)
    }

    func testInBoundsStepAdvancesByAnalyticIncrementAndDecaysVelocity() {
        var d = makeDecel(offset: 0, velocity: 2.0)
        let settled = d.step(dtMs: 16.667).settled
        // dx = v·rate·(1−decay)/(1−rate)·vScale = 2·0.998·(1−0.967183)/0.002 ≈ 32.7514
        XCTAssertFalse(settled)
        XCTAssertEqual(d.offset, 32.7514, accuracy: 1e-3)
        XCTAssertEqual(d.velocity, 1.934366, accuracy: 1e-4) // 2.0·0.967183
    }

    func testNearZeroVelocityInBoundsSettles() {
        var d = makeDecel(offset: 500, velocity: 0.005) // below 0.01 pts/ms floor
        XCTAssertTrue(d.step(dtMs: 16.667).settled)
    }

    func testOverscrolledAtRestSpringsTowardEdge() {
        var d = makeDecel(offset: 1010, velocity: 0)    // overshot past max = 1000, no residual velocity
        _ = d.step(dtMs: 16.667)
        XCTAssertLessThan(d.offset, 1010)               // pulled back toward the edge
        XCTAssertGreaterThan(d.offset, 1000)            // but not past it
    }

    func testCrossesBoundaryMidFrameThenSprings() {
        // offset 40, v 2.0, max 50: proposed ≈ 72.75 overshoots → integrate to ≈edge, spring the remainder.
        // Residual outward velocity carries it past the edge this frame, but less than the un-sprung proposed.
        var d = makeDecel(offset: 40, velocity: 2.0, min: 0, max: 50)
        let settled = d.step(dtMs: 16.667).settled
        XCTAssertFalse(settled)
        XCTAssertGreaterThan(d.offset, 50)        // crossed the edge
        XCTAssertLessThan(d.offset, 72.75)        // but the spring damped it below the un-sprung proposed
    }

    func testBounceEventuallySettlesAtEdge() {
        var d = makeDecel(offset: 1010, velocity: 2.0)
        var settled = false
        for _ in 0..<600 where !settled { settled = d.step(dtMs: 16.667).settled }
        XCTAssertTrue(settled)
        XCTAssertEqual(d.offset, 1000, accuracy: 0.5)   // within the settle tolerance of the edge
    }

    // MARK: - D4: the spring is not scaled

    func test_springDoesNotApplyTheVelocityScale() {
        // 0x17a8784 — _getBouncingDecelerationOffset's spring term carries no _fastScrollMultiplier,
        // unlike the free-deceleration term at 0x17a85f8. Invisible at vScale == 1, which is why it
        // survived; a real error the moment the fast-scroll streak moves it.
        func springOnly(vScale: CGFloat) -> CGFloat {
            // Overscrolled past the top AND still moving outward, so the spring's velocity term —
            // the only place vScale could enter — is non-zero and the comparison discriminates.
            var d = Deceleration(offset: -100, velocity: -0.5, min: 0, max: 1000,
                                 rate: 0.998, vScale: vScale)
            _ = d.step(dtMs: 16.667)
            return d.offset
        }
        XCTAssertEqual(springOnly(vScale: 1.0), springOnly(vScale: 4.0), accuracy: 1e-12,
                       "an overscrolled spring-back is independent of vScale")
    }

    func test_freeDecelerationDoesApplyTheVelocityScale() {
        // Non-vacuity for the test above: the free-decel term at 0x17a85f8 DOES scale, so the
        // equality above is a real property of the spring and not of a dead vScale.
        func freeOnly(vScale: CGFloat) -> CGFloat {
            var d = Deceleration(offset: 100, velocity: 2.0, min: 0, max: 100_000,
                                 rate: 0.998, vScale: vScale)
            _ = d.step(dtMs: 16.667)
            return d.offset
        }
        XCTAssertGreaterThan(freeOnly(vScale: 4.0), freeOnly(vScale: 1.0) + 1.0,
                             "vScale multiplies the free-deceleration distance")
    }

    func test_stepReportsWhenItEndedTheDeceleration() {
        // Settling and entering the spring are the two integrator-side streak resets
        // (0x17a8844 and 0x17a87bc).
        var settling = Deceleration(offset: 500, velocity: 0.001, min: 0, max: 100_000,
                                    rate: 0.998, vScale: 1)
        XCTAssertTrue(settling.step(dtMs: 16.667).endedDeceleration, "settled")

        var crossing = Deceleration(offset: 990, velocity: 2.0, min: 0, max: 1000,
                                    rate: 0.998, vScale: 1)
        XCTAssertTrue(crossing.step(dtMs: 16.667).endedDeceleration, "crossed the edge into the spring")

        var coasting = Deceleration(offset: 500, velocity: 2.0, min: 0, max: 100_000,
                                    rate: 0.998, vScale: 1)
        XCTAssertFalse(coasting.step(dtMs: 16.667).endedDeceleration, "still coasting in bounds")
    }
}

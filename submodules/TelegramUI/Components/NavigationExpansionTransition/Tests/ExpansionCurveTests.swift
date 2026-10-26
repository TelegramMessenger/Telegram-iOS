import XCTest
import UIKit
@testable import NavigationExpansionTransition

final class ExpansionCurveTests: XCTestCase {
    func test_ramp_clampsOutsideItsWindow() {
        XCTAssertEqual(ExpansionCurve.ramp(0.1, 0.2, 0.6), 0.0)
        XCTAssertEqual(ExpansionCurve.ramp(0.4, 0.2, 0.6), 0.5, accuracy: 1e-9)
        XCTAssertEqual(ExpansionCurve.ramp(0.9, 0.2, 0.6), 1.0)
    }

    // `x + 0.8x(1 − x)`: 0.7 by the middle, and still climbing at 1 so an overshoot continues the motion.
    func test_lead_isAheadInTheFirstHalf_andContinuesPastOne() {
        XCTAssertEqual(ExpansionCurve.lead(0.5), 0.7, accuracy: 1e-9)
        XCTAssertEqual(ExpansionCurve.lead(1.0), 1.0, accuracy: 1e-9)
        XCTAssertGreaterThan(ExpansionCurve.lead(1.05), 1.0)
    }

    // The incoming layout is whole before the outgoing fades: their sum never drops below 1.
    func test_crossfade_neverPales() {
        for i in 0 ... 100 {
            let t = CGFloat(i) / 100.0
            let (source, destination) = ExpansionCurve.crossfade(t)
            XCTAssertGreaterThanOrEqual(source + destination, 1.0 - 1e-9, "t = \(t)")
        }
        XCTAssertEqual(ExpansionCurve.crossfade(0.0).source, 1.0)
        XCTAssertEqual(ExpansionCurve.crossfade(0.0).destination, 0.0)
        XCTAssertEqual(ExpansionCurve.crossfade(1.0).source, 0.0)
        XCTAssertEqual(ExpansionCurve.crossfade(1.0).destination, 1.0)
    }

    func test_geometric_runsZeroToOne_slowFirst() {
        XCTAssertEqual(ExpansionCurve.geometric(0.0, ratio: 6.0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(ExpansionCurve.geometric(1.0, ratio: 6.0), 1.0, accuracy: 1e-9)
        XCTAssertLessThan(ExpansionCurve.geometric(0.5, ratio: 6.0), 0.5)
    }

    // Closing is not opening played backwards: a closing window applies to 1 − t.
    func test_clockPhase_usesEachDirectionsWindow() {
        let opening = ExpansionClock(time: 0.45, isOpening: true)
        XCTAssertEqual(opening.phase((0.06, 0.45), (0.30, 0.85)), 1.0, accuracy: 1e-9)
        let closing = ExpansionClock(time: 0.45, isOpening: false)
        // 1 − t = 0.55, inside the closing window (0.30, 0.85) at 0.4545…: 1 − smooth(0.4545)
        let u: CGFloat = (0.55 - 0.30) / (0.85 - 0.30)
        XCTAssertEqual(closing.phase((0.06, 0.45), (0.30, 0.85)), 1.0 - u * u * (3.0 - 2.0 * u), accuracy: 1e-9)
        XCTAssertEqual(ExpansionClock(time: 1.0, isOpening: false).phase((0.06, 0.45), (0.30, 0.85)), 1.0)
        XCTAssertEqual(ExpansionClock(time: 0.0, isOpening: false).phase((0.06, 0.45), (0.30, 0.85)), 0.0)
    }

    func test_mixRect_interpolatesEdges() {
        let a = CGRect(x: 0.0, y: 0.0, width: 10.0, height: 10.0)
        let b = CGRect(x: 10.0, y: 20.0, width: 30.0, height: 50.0)
        XCTAssertEqual(ExpansionCurve.mix(a, b, 0.5), CGRect(x: 5.0, y: 10.0, width: 20.0, height: 30.0))
    }
}

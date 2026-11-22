import XCTest
import CoreGraphics
@testable import CoreListDemo

final class RubberBandTests: XCTestCase {
    func testWithinBoundsReturnsOffsetUnchanged() {
        XCTAssertEqual(RubberBand.offset(50, min: 0, max: 100, range: 400), 50, accuracy: 1e-9)
    }

    func testPastMaxAppliesAsymptoticResistance() {
        // d = 20, c = 0.55, range = 400 → 100 + 400·(1 − 1/(1 + 0.55·20/400)) = 110.705596…
        XCTAssertEqual(RubberBand.offset(120, min: 0, max: 100, range: 400), 110.705596, accuracy: 1e-4)
    }

    func testPastMinIsSymmetric() {
        // d = 20, c = 0.55, range = 400 → 0 − 400·(1 − 1/(1 + 0.55·20/400)) = −10.705596…
        XCTAssertEqual(RubberBand.offset(-20, min: 0, max: 100, range: 400), -10.705596, accuracy: 1e-4)
    }

    func testZeroRangeReturnsOffsetUnchanged() {
        XCTAssertEqual(RubberBand.offset(120, min: 0, max: 100, range: 0), 120, accuracy: 1e-9)
    }
}

import XCTest
import CoreGraphics
@testable import CoreListDemo

final class OffsetMathTests: XCTestCase {
    func testPixelRoundRetinaSnapsToHalfPoint() {
        // scale 2 → grid of 0.5: floor(10.3)=10, round(0.3·2=0.6)=1.0, /2=0.5 → 10.5
        XCTAssertEqual(OffsetMath.pixelRound(10.3, scale: 2), 10.5, accuracy: 1e-9)
        XCTAssertEqual(OffsetMath.pixelRound(10.8, scale: 2), 11.0, accuracy: 1e-9)
        // ties-to-even on the sub-pixel fraction (scale > 1 branch):
        // (10.25−10)·2 = 0.5 → even round → 0 → 10.0
        XCTAssertEqual(OffsetMath.pixelRound(10.25, scale: 2), 10.0, accuracy: 1e-9)
        // (10.75−10)·2 = 1.5 → even round → 2 → 10 + 2/2 = 11.0
        XCTAssertEqual(OffsetMath.pixelRound(10.75, scale: 2), 11.0, accuracy: 1e-9)
    }

    func testPixelRoundScaleOneRoundsToNearestEven() {
        XCTAssertEqual(OffsetMath.pixelRound(10.3, scale: 1), 10.0, accuracy: 1e-9)
        XCTAssertEqual(OffsetMath.pixelRound(0.5, scale: 1), 0.0, accuracy: 1e-9)   // ties-to-even
    }

    func testMinOffsetIsNegativeLeadingInset() {
        XCTAssertEqual(OffsetMath.minOffset(insetLeadingTop: 50, scale: 2), -50, accuracy: 1e-9)
        // non-default baseOrigin: pixelRound(10 − 50) = −40
        XCTAssertEqual(OffsetMath.minOffset(insetLeadingTop: 50, baseOrigin: 10, scale: 2), -40, accuracy: 1e-9)
    }

    func testMaxOffsetIsContentMinusBoundsPlusInset() {
        XCTAssertEqual(
            OffsetMath.maxOffset(contentSize: 2000, insetTrailingBottom: 0,
                                 boundsSize: 800, minOffset: 0, scale: 2),
            1200, accuracy: 1e-9)
        // non-zero trailing inset is summed BEFORE rounding: pixelRound(1000+50) − 800 = 250
        XCTAssertEqual(
            OffsetMath.maxOffset(contentSize: 1000, insetTrailingBottom: 50,
                                 boundsSize: 800, minOffset: 0, scale: 2),
            250, accuracy: 1e-9)
    }

    func testMaxOffsetPinsToMinWhenContentSmallerThanViewport() {
        XCTAssertEqual(
            OffsetMath.maxOffset(contentSize: 500, insetTrailingBottom: 0,
                                 boundsSize: 800, minOffset: 0, scale: 2),
            0, accuracy: 1e-9)
    }
}

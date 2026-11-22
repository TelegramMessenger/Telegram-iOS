import XCTest
import CoreGraphics
@testable import NewsFeedSupport

final class NewsRefreshCurvesTests: XCTestCase {
    private typealias C = NewsRefreshCurves

    func testHelpersClampAndHitTheirKeyPoints() {
        XCTAssertEqual(C.ramp(0.5, 0.0, 1.0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(C.ramp(-1.0, 0.0, 1.0), 0.0)
        XCTAssertEqual(C.ramp(2.0, 0.0, 1.0), 1.0)
        XCTAssertEqual(C.smooth(0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(C.smooth(2.0), 1.0)
        XCTAssertEqual(C.smooth(-1.0), 0.0)
        XCTAssertEqual(C.outQuad(0.5), 0.75, accuracy: 1e-9)
        XCTAssertEqual(C.inQuad(0.5), 0.25, accuracy: 1e-9)
        XCTAssertEqual(C.inOutCubic(0.25), 0.0625, accuracy: 1e-9)
        XCTAssertEqual(C.inOutCubic(0.75), 0.9375, accuracy: 1e-9)
        XCTAssertEqual(C.mix(10.0, 44.0, 0.75), 35.5, accuracy: 1e-9)
    }

    func testFollowIsTheCriticallyDampedSmooth() {
        XCTAssertEqual(C.follow(0.0, duration: 0.5), 0.0)
        XCTAssertEqual(C.follow(-1.0, duration: 0.5), 0.0)
        // ω = 4π: 1 - (1 + 2π)e^{-2π} ≈ 0.98640.
        XCTAssertEqual(C.follow(0.5, duration: 0.5), 0.98640, accuracy: 0.0001)
    }

    func testSpreadSpringIsTheSmoothHalfSecond() {
        XCTAssertEqual(NewsSpring.spread.dampingRatio, 1.0, accuracy: 1e-9)
        XCTAssertEqual(NewsSpring.spread.stiffness, CGFloat(pow(2.0 * Double.pi / 0.5, 2.0)), accuracy: 1e-6)
    }
}

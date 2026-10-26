import XCTest
import UIKit
import QuartzCore
@testable import CoreListDemo

final class PhysicsScrollViewTests: XCTestCase {
    /// The flight sampler MUST read layer-LOCAL time (convertTime), not media time, so it tracks CA
    /// under slowed playback (CLAUDE.md: "the analytic slide clock is the layer's LOCAL time").
    /// A frozen layer (speed == 0) makes convertTime == timeOffset regardless of media time.
    func testLocalTimeRoutesThroughConvertTime() {
        let layer = CALayer()
        layer.speed = 0
        layer.timeOffset = 5
        XCTAssertEqual(PhysicsScrollView.localTime(of: layer), 5, accuracy: 1e-9)
    }

    /// The recognizer must accept continuous (trackpad two-finger) indirect scroll, so trackpad
    /// input drives the same handlePan → ScrollPhysics path as touch (design §4.1).
    func testRecognizerAllowsContinuousScrollType() {
        let pan = PhysicsPanGestureRecognizer(target: nil, action: nil)
        XCTAssertTrue(pan.allowedScrollTypesMask.contains(.continuous))
    }
}

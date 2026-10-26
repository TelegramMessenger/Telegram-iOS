import XCTest
import CoreGraphics
import QuartzCore
@testable import NewsFeedSupport

/// The Feed2 mockup's springs (Motion.swift), ported from SwiftUI.
final class NewsMotionTests: XCTestCase {
    // `Motion.appear` = .smooth(duration: 0.45): critically damped, stiffness (2π/0.45)².
    func testAppearSpringIsTheMockupsSmoothSpring() {
        let spring = NewsSpring.appear
        XCTAssertEqual(spring.mass, 1.0)
        XCTAssertEqual(spring.stiffness, 194.9551, accuracy: 0.001)
        XCTAssertEqual(spring.damping, 27.9253, accuracy: 0.001)
        XCTAssertEqual(spring.dampingRatio, 1.0, accuracy: 0.0001)
        XCTAssertEqual(spring.settlingDuration, 0.700, accuracy: 0.005)
    }

    // `Motion.pick` = .spring(duration: 0.42, bounce: 0.2): damping ratio 1 − bounce.
    func testBouncySpringUsesOneMinusBounceAsItsDampingRatio() {
        let spring = NewsSpring(duration: 0.42, bounce: 0.2)
        XCTAssertEqual(spring.stiffness, 223.8006, accuracy: 0.001)
        XCTAssertEqual(spring.damping, 23.9359, accuracy: 0.001)
        XCTAssertEqual(spring.dampingRatio, 0.8, accuracy: 0.0001)
        XCTAssertEqual(spring.settlingDuration, 0.648, accuracy: 0.005)
    }

    // A spring runs for its own settling time; Display's makeAnimation would time-scale it.
    func testAnimationRunsForTheSettlingTime() {
        let animation = NewsSpring.appear.makeAnimation(keyPath: "opacity", from: 0.0 as NSNumber, to: 1.0 as NSNumber)
        XCTAssertEqual(animation.duration, animation.settlingDuration, accuracy: 0.0001)
        XCTAssertEqual(animation.mass, 1.0)
        XCTAssertEqual(animation.stiffness, NewsSpring.appear.stiffness)
        XCTAssertEqual(animation.damping, NewsSpring.appear.damping)
        XCTAssertEqual(animation.beginTime, 0.0)
    }

    // A delayed one holds its start value until it begins.
    func testDelayedAnimationHoldsItsStartValue() {
        let animation = NewsSpring.appear.makeAnimation(keyPath: "opacity", from: 0.0 as NSNumber, to: 1.0 as NSNumber, delay: 0.09)
        XCTAssertEqual(animation.fillMode, .backwards)
        XCTAssertGreaterThan(animation.beginTime, CACurrentMediaTime())
    }
}

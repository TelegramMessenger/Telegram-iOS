import XCTest
import UIKit
@testable import Display

/// UIKit's navigation transition springs (`_UIFluidParallaxTransitionSettings`, UIKitCore 26.0–27.0): checked by their
/// physics rather than against a copy of the formula.
final class NavigationTransitionSpringTests: XCTestCase {
    private func run(_ spring: NavigationTransitionSpring, from value: CGFloat, to target: CGFloat, velocity: CGFloat = 0.0, duration: CGFloat, step: CGFloat = 1.0 / 240.0) -> [CGFloat] {
        var state = (value: value, velocity: velocity)
        var samples: [CGFloat] = []
        var time: CGFloat = 0.0
        while time < duration {
            state = spring.advance(value: state.value, velocity: state.velocity, target: target, time: step)
            samples.append(state.value)
            time += step
        }
        return samples
    }

    // A tap push: critically damped with a 0.3 s response, so it never overshoots and is 99% there after ~0.317 s.
    func test_noninteractiveSpring_isCriticallyDamped_andSettlesLikeUIKits() {
        let spring = NavigationTransitionSpring.noninteractive
        XCTAssertEqual(spring.dampingRatio, 1.0)
        XCTAssertEqual(spring.response, 0.3)
        let samples = self.run(spring, from: 0.0, to: 1.0, duration: 1.0)
        XCTAssertLessThanOrEqual(samples.max() ?? 2.0, 1.0)
        let ninetyNine = samples.firstIndex(where: { $0 >= 0.99 }).map { CGFloat($0 + 1) / 240.0 } ?? 0.0
        XCTAssertEqual(ninetyNine, 0.317, accuracy: 0.005)
    }

    // A released swipe: dampingRatio 0.85 overshoots once by exp(-pi * zeta / sqrt(1 - zeta^2)), about 0.63%.
    func test_interactiveSpring_overshootsByItsDampingRatio() {
        let spring = NavigationTransitionSpring.interactive
        XCTAssertEqual(spring.dampingRatio, 0.85)
        XCTAssertEqual(spring.response, 0.3)
        let samples = self.run(spring, from: 0.0, to: 1.0, duration: 1.0, step: 1.0 / 2000.0)
        let zeta: CGFloat = 0.85
        let expected = exp(-CGFloat.pi * zeta / (1.0 - zeta * zeta).squareRoot())
        XCTAssertEqual((samples.max() ?? 0.0) - 1.0, expected, accuracy: 0.0002)
    }

    func test_trackingSpring_isUIKits() {
        XCTAssertEqual(NavigationTransitionSpring.tracking.dampingRatio, 0.85)
        XCTAssertEqual(NavigationTransitionSpring.tracking.response, 0.08)
    }

    // The step is the exact solution, so two half steps land where one full step does, velocity included.
    func test_advance_isExact_acrossStepSizes() {
        for spring in [NavigationTransitionSpring.noninteractive, .interactive, .tracking] {
            let whole = spring.advance(value: 0.2, velocity: 3.0, target: 1.0, time: 0.05)
            let half = spring.advance(value: 0.2, velocity: 3.0, target: 1.0, time: 0.025)
            let twoHalves = spring.advance(value: half.value, velocity: half.velocity, target: 1.0, time: 0.025)
            XCTAssertEqual(whole.value, twoHalves.value, accuracy: 1e-9)
            XCTAssertEqual(whole.velocity, twoHalves.velocity, accuracy: 1e-9)
        }
    }

    // As UIKit hands it to Core Animation: mass 1, stiffness (2 pi / response)^2, damping 2 zeta sqrt(stiffness).
    func test_coreAnimationParameters() {
        let spring = NavigationTransitionSpring.noninteractive
        XCTAssertEqual(spring.stiffness, pow(2.0 * .pi / 0.3, 2.0), accuracy: 0.001)
        XCTAssertEqual(spring.damping, 2.0 * spring.stiffness.squareRoot(), accuracy: 0.001)
    }

    // SwiftUI's Spring(duration:bounce:) (SwiftUICore 27 Spring.init): response = duration, dampingRatio = 1 - bounce.
    func test_swiftUIConversion() {
        let transition = NavigationTransitionSpring(duration: 0.416, bounce: 0.25)
        XCTAssertEqual(transition.response, 0.416)
        XCTAssertEqual(transition.dampingRatio, 0.75, accuracy: 1e-12)
        XCTAssertEqual(transition.stiffness, 228.13, accuracy: 0.01)
        XCTAssertEqual(NavigationTransitionSpring(duration: 0.2, bounce: 0.0).dampingRatio, 1.0)
        XCTAssertEqual(NavigationTransitionSpring(duration: 0.5, bounce: -0.5).dampingRatio, 2.0, accuracy: 1e-12)
    }

    // Slow Animations (the animation duration factor) slows the spring like every other animation: with a factor of 10,
    // 0.1 s of real time advances it by 0.01 s.
    func test_driver_respectsTheAnimationDurationFactor() {
        var slowed: [CGFloat] = []
        var reference: [CGFloat] = []
        let slowDriver = NavigationTransitionProgressDriver(value: 0.0, update: { slowed.append($0) })
        slowDriver.durationFactor = { 10.0 }
        let referenceDriver = NavigationTransitionProgressDriver(value: 0.0, update: { reference.append($0) })
        slowDriver.animate(to: 1.0, spring: .noninteractive, velocity: 0.0, settled: nil)
        referenceDriver.animate(to: 1.0, spring: .noninteractive, velocity: 0.0, settled: nil)
        slowDriver.advance(realTime: 0.1)
        referenceDriver.tick(dt: 0.01)
        XCTAssertEqual(slowed.last ?? -1.0, reference.last ?? -2.0, accuracy: 1e-9)
        slowDriver.stop()
        referenceDriver.stop()
    }

    // The first frame after a transition starts shows where it starts, however long the rest of the run-loop turn and
    // the commit took: Core Animation started its clock at the commit, and a heavy screen's first frame can come 50 ms
    // after the push began. Later frames advance by the time between them.
    func test_driver_firstFrame_advancesNothing() {
        let driver = NavigationTransitionProgressDriver(value: 0.0, update: { _ in })
        driver.durationFactor = { 1.0 }
        let start = CACurrentMediaTime()
        driver.animate(to: 1.0, spring: .noninteractive, velocity: 0.0, settled: nil)
        driver.displayLinkFrame(at: start + 0.05)
        XCTAssertEqual(driver.value, 0.0)
        driver.displayLinkFrame(at: start + 0.05 + 1.0 / 60.0)
        XCTAssertGreaterThan(driver.value, 0.0)
        driver.stop()
    }
}

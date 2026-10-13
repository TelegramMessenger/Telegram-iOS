import XCTest
import UIKit
import ObjectiveC
import QuartzCore
@testable import CoreListDemo

/// Pins `Curve.uiKitSmoothDeceleration` to the spring `UIScrollView` actually runs for
/// **scroll-to-top** (`__smoothDecelerationAnimation()`), which is a different animation from the
/// one `setContentOffset(_:animated:)` uses — see `UIScrollViewCurveParityTests` for that one.
///
/// Three legs, so no part of this rests on the disassembly alone:
///
/// 1. our emitted `CASpringAnimation` matches the one UIKit builds, field for field;
/// 2. our closed form matches what Core Animation's own spring solver renders;
/// 3. `Curve.solve(at:)` routes to that closed form, so the analytic model and the render server
///    evaluate the same function.
///
/// Legs 1 and 2 use private API and skip rather than fail if UIKit moves; nothing private ships.
final class SmoothDecelerationParityTests: XCTestCase {
    /// Drives UIKit into building its smooth-deceleration animation and hands back the live object.
    private func uiKitSmoothDecelerationAnimation() throws -> CASpringAnimation {
        let selector = NSSelectorFromString("_setContentOffsetWithDecelerationAnimation:")
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        guard scrollView.responds(to: selector) else {
            throw XCTSkip("-[UIScrollView _setContentOffsetWithDecelerationAnimation:] is unavailable.")
        }

        scrollView.contentSize = CGSize(width: 400, height: 20_000)
        scrollView.contentOffset = CGPoint(x: 0, y: 5_000)

        // A window is required: `_setContentOffset:animated:animationCurve:…` only installs an
        // animation when the scroll view has one, and otherwise sets the offset outright.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.addSubview(scrollView)
        window.makeKeyAndVisible()

        typealias SetOffsetFunction = @convention(c) (AnyObject, Selector, CGPoint) -> Void
        let setOffset = unsafeBitCast(scrollView.method(for: selector), to: SetOffsetFunction.self)
        setOffset(scrollView, selector, .zero)

        guard let scrollAnimation = scrollView.value(forKey: "_animation") as? NSObject,
              let spring = scrollAnimation.value(forKey: "_customAnimation") as? CASpringAnimation
        else {
            throw XCTSkip("UIKit did not install a CASpringAnimation for the deceleration scroll.")
        }
        return spring
    }

    // MARK: - Leg 1: our factory vs UIKit's live object

    func testFactoryMatchesUIKitsLiveAnimation() throws {
        let uiKit = try uiKitSmoothDecelerationAnimation()
        let ours = makeCoreListSmoothDecelerationAnimation("position.y")

        XCTAssertEqual(ours.mass, uiKit.mass, accuracy: 1e-9, "mass")
        XCTAssertEqual(ours.stiffness, uiKit.stiffness, accuracy: 1e-9, "stiffness")
        XCTAssertEqual(ours.damping, uiKit.damping, accuracy: 1e-9, "damping")
        XCTAssertEqual(ours.duration, uiKit.duration, accuracy: 1e-9, "duration")
        XCTAssertEqual(ours.initialVelocity, uiKit.initialVelocity, accuracy: 1e-9, "initialVelocity")

        // The dead timing function is reproduced too, so the emitted object is UIKit's field for
        // field even though `progressForFraction:` overwrites its contribution.
        var oursPoints = [Float](repeating: 0, count: 4)
        var uiKitPoints = [Float](repeating: 0, count: 4)
        ours.timingFunction?.getControlPoint(at: 1, values: &oursPoints)
        ours.timingFunction?.getControlPoint(at: 2, values: &oursPoints[2])
        uiKit.timingFunction?.getControlPoint(at: 1, values: &uiKitPoints)
        uiKit.timingFunction?.getControlPoint(at: 2, values: &uiKitPoints[2])
        XCTAssertEqual(oursPoints, uiKitPoints, "timing function control points")
    }

    // MARK: - Leg 2: closed form vs Core Animation's spring solver

    func testClosedFormMatchesCoreAnimationSpringSolver() throws {
        let selector = NSSelectorFromString("_" + "solveForInput:")
        guard let method = class_getInstanceMethod(CASpringAnimation.self, selector) else {
            throw XCTSkip("CASpringAnimation _solveForInput: is unavailable.")
        }

        var argumentType = [CChar](repeating: 0, count: 16)
        method_getArgumentType(method, 2, &argumentType, argumentType.count)
        let imp = method_getImplementation(method)
        let spring = makeCoreListSmoothDecelerationAnimation("position.y")

        func solve(_ t: Double) -> Double {
            if argumentType[0] == CChar(UInt8(ascii: "f")) {
                let f = unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector, Float) -> Float).self)
                return Double(f(spring, selector, Float(t)))
            }
            let d = unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector, Double) -> Double).self)
            return d(spring, selector, t)
        }

        // Float-precision tolerance: `_solveForInput:` takes a float argument on some builds, so the
        // phase itself is quantized before the spring ever sees it.
        for i in 0...500 {
            let phase = Double(i) / 500.0
            XCTAssertEqual(coreListSmoothDecelerationProgress(phase: CGFloat(phase)), CGFloat(solve(phase)),
                           accuracy: 2e-6,
                           "closed form diverged from CA's spring solver at phase \(phase)")
        }
    }

    // MARK: - Deterministic legs

    func testSpringIsExactlyCriticallyDamped() {
        let spring = makeCoreListSmoothDecelerationAnimation("position.y")
        let dampingRatio = spring.damping / (2.0 * (spring.stiffness * spring.mass).squareRoot())
        // Critical damping is the whole character of this curve: it is the fastest settle with no
        // overshoot. Any drift here means it has become a bouncy spring.
        XCTAssertEqual(dampingRatio, 1.0, accuracy: 1e-12)
        XCTAssertEqual(2.0 * Double.pi / coreListSmoothDecelerationOmega, 0.6, accuracy: 1e-12,
                       "response should be UIKit's 0.6")
    }

    func testCurveSolveRoutesToTheClosedForm() {
        for i in 0...200 {
            let phase = CGFloat(i) / 200.0
            XCTAssertEqual(CoreListTransition.Animation.Curve.uiKitSmoothDeceleration.solve(at: phase),
                           coreListSmoothDecelerationProgress(phase: phase), accuracy: 1e-12)
        }
    }

    func testCurveShapeIsMonotonicAndEssentiallyComplete() {
        let curve = CoreListTransition.Animation.Curve.uiKitSmoothDeceleration
        XCTAssertEqual(curve.solve(at: 0.0), 0.0, accuracy: 1e-12)

        var previous: CGFloat = 0.0
        for i in 0...10_000 {
            let value = curve.solve(at: CGFloat(i) / 10_000.0)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-12, "reversed at \(CGFloat(i) / 10_000.0)")
            previous = value
        }

        // A critically damped spring approaches its target asymptotically: it lands at 0.9999991
        // rather than exactly 1. That residual is what CA genuinely renders, so `solve` reports it
        // rather than normalising — but it must stay far below a device pixel on any real travel.
        XCTAssertEqual(curve.solve(at: 1.0), 1.0, accuracy: 1e-5)
        XCTAssertLessThan(curve.solve(at: 1.0), 1.0)

        // The perceptual shape: most of the motion is early, the tail is invisible.
        XCTAssertEqual(curve.solve(at: 0.10), 0.499, accuracy: 0.002)
        XCTAssertGreaterThan(curve.solve(at: 0.30), 0.96)
    }

    func testEmitsARealSpringAnimationRatherThanATimingFunction() {
        let animation = makeCoreListAnimation(from: 0.0, to: 100.0, keyPath: "position.y",
                                              curve: .uiKitSmoothDeceleration,
                                              springKind: .adjustedBezier,
                                              logicalDuration: coreListSmoothDecelerationNaturalDuration,
                                              durationFactor: 1.0, additive: false)

        XCTAssertTrue(animation is CASpringAnimation,
                      "uiKitSmoothDeceleration must emit a real spring, not a bezier approximation")
        // At its natural duration the spring plays at speed 1; `makeCoreListAnimation` maps any
        // other pass duration on via `speed`, leaving `duration` at the spring's own settle time.
        XCTAssertEqual(animation.speed, 1.0, accuracy: 1e-6)
        XCTAssertEqual(animation.duration, coreListSmoothDecelerationNaturalDuration, accuracy: 1e-9)
    }

    /// CoreList plays the curve at 1.15s while UIKit's own settle is 1.6s. That difference must reach
    /// Core Animation as PLAYBACK SPEED, leaving the emitted spring identical to UIKit's — not as
    /// retuned spring constants, which would be a different curve wearing the same name.
    func testDefaultDurationIsTimeCompressionRatherThanADifferentSpring() {
        XCTAssertEqual(coreListSmoothDecelerationDefaultDuration, 1.15, accuracy: 1e-12)

        let animation = makeCoreListAnimation(from: 0.0, to: 100.0, keyPath: "position.y",
                                              curve: .uiKitSmoothDeceleration,
                                              springKind: .adjustedBezier,
                                              logicalDuration: coreListSmoothDecelerationDefaultDuration,
                                              durationFactor: 1.0, additive: false)

        guard let spring = animation as? CASpringAnimation else {
            return XCTFail("expected a CASpringAnimation")
        }
        // Spring parameters stay UIKit's: same stiffness, same damping, same natural duration.
        XCTAssertEqual(spring.stiffness,
                       coreListSmoothDecelerationOmega * coreListSmoothDecelerationOmega,
                       accuracy: 1e-9)
        XCTAssertEqual(spring.damping, 2.0 * coreListSmoothDecelerationOmega, accuracy: 1e-9)
        XCTAssertEqual(animation.duration, coreListSmoothDecelerationNaturalDuration, accuracy: 1e-9)

        // …and the compression is entirely in `speed` = natural / logical = 1.6 / 1.15.
        XCTAssertEqual(animation.speed, Float(1.6 / 1.15), accuracy: 1e-6)

        // The transition's own reported duration is the wall time the pass takes.
        XCTAssertEqual(CoreListTransition.uiKitSmoothDeceleration().duration, 1.15, accuracy: 1e-12)

        // Sanity on the compressed timeline: the unit curve is unchanged, so the phase landmarks
        // simply arrive ~1.39x sooner in wall time — half the travel by ~0.115s, ~96% by ~0.35s.
        let curve = CoreListTransition.Animation.Curve.uiKitSmoothDeceleration
        XCTAssertEqual(curve.solve(at: CGFloat(0.115 / 1.15)), 0.499, accuracy: 0.002)
        XCTAssertGreaterThan(curve.solve(at: CGFloat(0.345 / 1.15)), 0.96)
    }
}

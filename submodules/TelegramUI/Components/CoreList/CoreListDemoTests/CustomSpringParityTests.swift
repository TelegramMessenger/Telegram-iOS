import XCTest
import ObjectiveC
import QuartzCore
@testable import CoreListDemo

/// Pins `Curve.customSpring`, the list half of the chat's send transition: the history must scroll on
/// the same spring Display animates the new bubble with (`CALayer.makeAnimation`'s custom-spring
/// branch), or the bubble drifts against its neighbours.
///
/// Three legs:
///
/// 1. the closed form matches what Core Animation's own spring solver renders (private API — skips
///    rather than fails if it moves; nothing private ships);
/// 2. `Curve.solve(at:)` and a model track route to that closed form, so the analytic model and the
///    render server evaluate the same function;
/// 3. the emitter installs Display's object — the parameters, `duration = settlingDuration`, a linear
///    timing function — with the settle mapped onto the pass, and Slow Animations, as `speed`.
final class CustomSpringParityTests: XCTestCase {
    private struct Spring {
        let mass: CGFloat
        let stiffness: CGFloat
        let damping: CGFloat
        let initialVelocity: CGFloat

        var curve: CoreListTransition.Animation.Curve {
            .customSpring(mass: mass, stiffness: stiffness, damping: damping, initialVelocity: initialVelocity)
        }
    }

    /// The send transition's springs, plus the shapes that exercise every branch of the closed form.
    private let springs: [Spring] = [
        Spring(mass: 1.0, stiffness: 300.0, damping: 26.0, initialVelocity: 0.0),   // vertical, ζ ≈ 0.75
        Spring(mass: 1.0, stiffness: 400.0, damping: 40.0, initialVelocity: 0.0),   // horizontal / scale, ζ = 1
        Spring(mass: 1.0, stiffness: 200.0, damping: 8.0, initialVelocity: 0.0),    // bouncy, ζ ≈ 0.28
        Spring(mass: 2.0, stiffness: 500.0, damping: 120.0, initialVelocity: 0.0),  // ζ ≈ 1.9, rendered as ζ = 1
        Spring(mass: 1.0, stiffness: 300.0, damping: 26.0, initialVelocity: 4.0),   // moving towards the target
        Spring(mass: 1.0, stiffness: 300.0, damping: 26.0, initialVelocity: -3.0),  // moving away from it
    ]

    // MARK: - Leg 1: closed form vs Core Animation's spring solver

    func testClosedFormMatchesCoreAnimationSpringSolver() throws {
        let selector = NSSelectorFromString("_" + "solveForInput:")
        guard let method = class_getInstanceMethod(CASpringAnimation.self, selector) else {
            throw XCTSkip("CASpringAnimation _solveForInput: is unavailable.")
        }
        var argumentType = [CChar](repeating: 0, count: 16)
        method_getArgumentType(method, 2, &argumentType, argumentType.count)
        let imp = method_getImplementation(method)

        for spring in springs {
            // Built by the emitter's own factory, so its duration is the settle the closed form maps
            // unit phase onto — `_solveForInput:` takes a fraction of the animation's duration.
            let animation = makeCoreListCustomSpringAnimation("position.y", mass: spring.mass,
                                                              stiffness: spring.stiffness,
                                                              damping: spring.damping,
                                                              initialVelocity: spring.initialVelocity)
            func solve(_ t: Double) -> Double {
                if argumentType[0] == CChar(UInt8(ascii: "f")) {
                    let f = unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector, Float) -> Float).self)
                    return Double(f(animation, selector, Float(t)))
                }
                let d = unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector, Double) -> Double).self)
                return d(animation, selector, t)
            }

            // Float-precision tolerance: `_solveForInput:` takes a float argument on some builds, so
            // the phase is quantized before the spring sees it.
            for i in 0...400 {
                let phase = Double(i) / 400.0
                let closedForm = coreListCustomSpringProgress(mass: spring.mass, stiffness: spring.stiffness,
                                                              damping: spring.damping,
                                                              initialVelocity: spring.initialVelocity,
                                                              phase: CGFloat(phase))
                XCTAssertEqual(closedForm, CGFloat(solve(phase)), accuracy: 2e-5,
                               "\(spring) diverged from CA's spring solver at phase \(phase)")
            }
        }
    }

    // MARK: - Leg 2: the model evaluates the closed form

    func testCurveSolveRoutesToTheClosedForm() {
        for spring in springs {
            for i in 0...200 {
                let phase = CGFloat(i) / 200.0
                XCTAssertEqual(spring.curve.solve(at: phase),
                               coreListCustomSpringProgress(mass: spring.mass, stiffness: spring.stiffness,
                                                            damping: spring.damping,
                                                            initialVelocity: spring.initialVelocity,
                                                            phase: phase),
                               accuracy: 1e-12)
            }
        }
    }

    func testModelTrackFollowsTheSpring() {
        let spring = springs[0]
        let track = ListAnimationTrack(generation: 1, from: 100.0, to: 400.0,
                                       startTime: 10.0, duration: 0.5, curve: spring.curve)
        for i in 0...50 {
            let phase = Double(i) / 50.0
            let expected = 100.0 + 300.0 * spring.curve.solve(at: CGFloat(phase))
            XCTAssertEqual(track.value(at: 10.0 + phase * 0.5), expected, accuracy: 1e-9)
        }
    }

    // MARK: - Leg 3: the emitted animation is Display's

    /// The spring's own settle at `speed == 1`. It cannot be read back off an emitted object:
    /// `settlingDuration` is reported in the parent's time, i.e. already divided by `speed`.
    private func settle(_ spring: Spring) -> Double {
        makeCoreListCustomSpringAnimation("position.y", mass: spring.mass, stiffness: spring.stiffness,
                                          damping: spring.damping,
                                          initialVelocity: spring.initialVelocity).duration
    }

    func testEmitsDisplaysSpringObject() throws {
        let spring = springs[0]
        let animation = makeCoreListAnimation(from: 0.0, to: 100.0, keyPath: "position.y",
                                              curve: spring.curve, springKind: .adjustedBezier,
                                              logicalDuration: 0.5, durationFactor: 1.0, additive: true)
        let emitted = try XCTUnwrap(animation as? CASpringAnimation,
                                    "customSpring must emit a real spring, not a bezier approximation")

        XCTAssertEqual(emitted.mass, 1.0, accuracy: 1e-9)
        XCTAssertEqual(emitted.stiffness, 300.0, accuracy: 1e-9)
        XCTAssertEqual(emitted.damping, 26.0, accuracy: 1e-9)
        XCTAssertEqual(emitted.initialVelocity, 0.0, accuracy: 1e-9)
        // The spring runs to its own settle; the pass duration reaches it only as playback speed.
        let settling = settle(spring)
        XCTAssertEqual(settling, 0.5897, accuracy: 1e-4, "the vertical send spring's settle")
        XCTAssertEqual(emitted.duration, settling, accuracy: 1e-9)
        XCTAssertEqual(emitted.speed, Float(settling / 0.5), accuracy: 1e-5)
        var controlPoints = [Float](repeating: -1, count: 4)
        emitted.timingFunction?.getControlPoint(at: 1, values: &controlPoints)
        emitted.timingFunction?.getControlPoint(at: 2, values: &controlPoints[2])
        XCTAssertEqual(controlPoints, [0.0, 0.0, 1.0, 1.0], "linear timing function")
        XCTAssertTrue(emitted.isAdditive)
    }

    func testSlowAnimationsReachesTheSpringAsSpeed() throws {
        let spring = springs[0]
        let animation = makeCoreListAnimation(from: 0.0, to: 100.0, keyPath: "position.y",
                                              curve: spring.curve, springKind: .adjustedBezier,
                                              logicalDuration: 0.5, durationFactor: 10.0, additive: false)
        let emitted = try XCTUnwrap(animation as? CASpringAnimation)
        let settling = settle(spring)
        XCTAssertEqual(emitted.duration, settling, accuracy: 1e-9)
        XCTAssertEqual(emitted.speed, Float(0.1 * settling / 0.5), accuracy: 1e-5)
    }

    /// The closed form has no overdamped branch because CA renders none: with `allowsOverdamping` at
    /// its default `false` it clamps the damping ratio to 1. Display never sets the flag, so neither
    /// does CoreList — if the default ever flips, both sides change together and this names why the
    /// parity test broke.
    func testOverdampingIsLeftAtCoreAnimationsDefault() {
        XCTAssertFalse(CASpringAnimation().allowsOverdamping)
        let animation = makeCoreListCustomSpringAnimation("position.y", mass: 2.0, stiffness: 500.0,
                                                          damping: 120.0, initialVelocity: 0.0)
        XCTAssertFalse(animation.allowsOverdamping)
    }

    /// Display parses a custom spring's parameters as `Float`; CoreList quantizes the same way, so a
    /// value with no exact float32 representation still builds the identical spring.
    func testParametersAreQuantizedLikeDisplay() {
        let animation = makeCoreListCustomSpringAnimation("position.y", mass: 1.0, stiffness: 555.027,
                                                          damping: 47.118, initialVelocity: 0.0)
        XCTAssertEqual(animation.stiffness, CGFloat(Float(555.027)))
        XCTAssertEqual(animation.damping, CGFloat(Float(47.118)))
    }

    // MARK: - Shape

    /// The send transition's vertical spring: a soft overshoot of a few percent, landing at rest.
    func testSendSpringOvershootsSoftlyAndSettles() {
        let curve = springs[0].curve
        XCTAssertEqual(curve.solve(at: 0.0), 0.0, accuracy: 1e-12)
        var peak: CGFloat = 0.0
        for i in 0...1_000 {
            peak = max(peak, curve.solve(at: CGFloat(i) / 1_000.0))
        }
        XCTAssertGreaterThan(peak, 1.01)
        XCTAssertLessThan(peak, 1.06)
        XCTAssertEqual(curve.solve(at: 1.0), 1.0, accuracy: 1e-3)
    }

    /// A critically damped spring never travels past its target.
    func testCriticallyDampedSpringDoesNotOvershoot() {
        let curve = springs[1].curve
        var previous: CGFloat = 0.0
        for i in 0...1_000 {
            let value = curve.solve(at: CGFloat(i) / 1_000.0)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-12)
            XCTAssertLessThanOrEqual(value, 1.0 + 1e-9)
            previous = value
        }
    }
}

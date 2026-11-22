import XCTest
import QuartzCore
@testable import CoreListDemo

final class CoreListTransitionCurveTests: XCTestCase {
    // MARK: - Curve solve

    func testEaseInOutMatchesDisplayBezier() {
        // bezierPoint(0.42, 0, 0.58, 1, x). Values computed from the same Newton solver
        // Display uses; see the design doc's verification table.
        XCTAssertEqual(CoreListTransition.Animation.Curve.easeInOut.solve(at: 0.25),
                       0.12916193104731982, accuracy: 1e-12)
        XCTAssertEqual(CoreListTransition.Animation.Curve.easeInOut.solve(at: 0.75),
                       0.87083806895268023, accuracy: 1e-12)
    }

    func testEaseInOutIsSymmetricAboutMidpoint() {
        // Exact, unlike the Float-payload `.custom` equivalents below: `.easeInOut` has no case
        // payload, so its control points are Double literals.
        XCTAssertEqual(CoreListTransition.Animation.Curve.easeInOut.solve(at: 0.5), 0.5,
                       accuracy: 1e-15)
    }

    func testEveryCurveHasExactEndpoints() {
        let curves: [CoreListTransition.Animation.Curve] = [
            .easeInOut, .easeIn, .spring, .linear,
            .custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        ]
        for curve in curves {
            XCTAssertEqual(curve.solve(at: 0), 0, accuracy: 1e-15, "\(curve) at 0")
            XCTAssertEqual(curve.solve(at: 1), 1, accuracy: 1e-15, "\(curve) at 1")
        }
    }

    func testEveryCurveIsMonotonicAndClamps() {
        let curves: [CoreListTransition.Animation.Curve] = [
            .easeInOut, .easeIn, .spring, .linear,
            .custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        ]
        for curve in curves {
            var previous = curve.solve(at: 0)
            for step in 1...200 {
                let value = curve.solve(at: CGFloat(step) / 200.0)
                XCTAssertGreaterThanOrEqual(value, previous - 1e-12, "\(curve) at \(step)")
                previous = value
            }
            // Out-of-range input is clamped, not extrapolated.
            XCTAssertEqual(curve.solve(at: -0.5), 0, accuracy: 1e-15)
            XCTAssertEqual(curve.solve(at: 1.5), 1, accuracy: 1e-15)
        }
    }

    /// `.spring` must sample the app's ADJUSTED spring curve, not the pre-iOS-9 bezier fallback in
    /// `ListViewAnimation.swift`. Both `ComponentTransition.Curve.spring` and
    /// `ContainedViewLayoutTransitionCurve.spring` emit via `kCAMediaTimingFunctionSpring`, which
    /// `CAAnimationUtils.swift:119` resolves to `controlPoints(0.380, 0.700, 0.125, 1.000)` for any
    /// duration it does not special-case with a real CASpringAnimation (0.5, and 0.3832 on iOS 26).
    /// The two curves differ by up to 0.228 in progress — 23% of the travel — so this is not cosmetic.
    func testSpringMatchesTheAppsAdjustedSpringCurve() {
        let spring = CoreListTransition.Animation.Curve.spring
        let adjusted = CoreListTransition.Animation.Curve.custom(0.380, 0.700, 0.125, 1.000)
        let staleFallback = CoreListTransition.Animation.Curve.custom(0.23, 1.0, 0.32, 1.0)

        var worstAgainstAdjusted: CGFloat = 0
        var worstAgainstStale: CGFloat = 0
        for step in 0...1000 {
            let x = CGFloat(step) / 1000.0
            worstAgainstAdjusted = max(worstAgainstAdjusted, abs(spring.solve(at: x) - adjusted.solve(at: x)))
            worstAgainstStale = max(worstAgainstStale, abs(spring.solve(at: x) - staleFallback.solve(at: x)))
        }
        // Equal to the adjusted curve within Float-payload precision (`.custom` rounds its control
        // points to float32; `.spring` uses Double literals).
        XCTAssertLessThan(worstAgainstAdjusted, 1e-6,
                          "spring drifted from controlPoints(0.380, 0.700, 0.125, 1.000)")
        // And decisively NOT the old fallback, so a silent revert cannot pass.
        XCTAssertGreaterThan(worstAgainstStale, 0.2,
                             "spring looks like the pre-iOS-9 fallback again")
    }

    func testSpringIsMonotonicDespiteDecreasingControlX() {
        // Control-x decreases (0.380 -> 0.125), which can break a 4-iteration Newton inversion.
        // x'(t) stays >= 0.45 over [0, 1], so it converges and y(x) stays monotonic.
        let spring = CoreListTransition.Animation.Curve.spring
        var previous = spring.solve(at: 0)
        for step in 1...1000 {
            let value = spring.solve(at: CGFloat(step) / 1000.0)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-12, "spring regressed at step \(step)")
            previous = value
        }
        XCTAssertEqual(spring.solve(at: 0), 0, accuracy: 1e-15)
        XCTAssertEqual(spring.solve(at: 1), 1, accuracy: 1e-15)
    }

    func testLinearIsIdentity() {
        for step in 0...10 {
            let x = CGFloat(step) / 10.0
            XCTAssertEqual(CoreListTransition.Animation.Curve.linear.solve(at: x), x,
                           accuracy: 1e-15)
        }
    }

    // The two curves the old ListAnimationCurve carried are cubic beziers: control-x at 1/3 and 2/3
    // makes x(t) = t identically, so .custom(1/3, 0, 2/3, 1) IS x²(3−2x) and .custom(1/3, 1, 2/3, 1)
    // IS 1−(1−x)³ — the two curves this module used before adopting ComponentTransition's
    // vocabulary. Pinned so the historical claim stays checkable.
    //
    // The identity is exact in real arithmetic but NOT in the enum: `custom` carries Float payloads
    // (matching ComponentTransition), so 1/3 and 2/3 round to float32 and x(t) drifts from t. The
    // realized deviation is at most 1.7e-8 in progress — 4e-7pt on a 25pt extent — which is why
    // these assert at 1e-6 rather than 1e-12. With exact Double control points the deviation is
    // 2.2e-16, so the Float payload is the entire error.
    private static let customBezierFloatTolerance: CGFloat = 1e-6

    func testSmoothstepIsACustomBezierWithinFloatPayloadPrecision() {
        let curve = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        for step in 0...100 {
            let x = CGFloat(step) / 100.0
            let smoothstep = x * x * (3 - 2 * x)
            let expected = smoothstep
            XCTAssertEqual(curve.solve(at: x), expected,
                           accuracy: Self.customBezierFloatTolerance, "at \(x)")
        }
    }

    func testCubicEaseOutIsACustomBezierWithinFloatPayloadPrecision() {
        let curve = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 1.0, 2.0 / 3.0, 1.0)
        for step in 0...100 {
            let x = CGFloat(step) / 100.0
            let inverse = 1 - x
            let easeOut = 1 - inverse * inverse * inverse
            let expected = easeOut
            XCTAssertEqual(curve.solve(at: x), expected,
                           accuracy: Self.customBezierFloatTolerance, "at \(x)")
        }
    }

    /// Pins the deviation itself, so a future change that widens it fails loudly.
    func testCustomBezierFloatDeviationStaysBelowOnePartInTenMillion() {
        let smooth = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        let easeOut = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 1.0, 2.0 / 3.0, 1.0)
        var worst: CGFloat = 0
        for step in 0...1000 {
            let x = CGFloat(step) / 1000.0
            let ss = x * x * (3 - 2 * x)
            let inverse = 1 - x
            let eo = 1 - inverse * inverse * inverse
            worst = max(worst, abs(smooth.solve(at: x) - ss))
            worst = max(worst, abs(easeOut.solve(at: x) - eo))
        }
        XCTAssertLessThan(worst, 1e-7, "Float-payload deviation grew; measured \(worst)")
    }

    // MARK: - isImmediate

    func testZeroDurationIsImmediate() {
        XCTAssertTrue(CoreListTransition.immediate.isImmediate)
        XCTAssertTrue(CoreListTransition.easeInOut(duration: 0).isImmediate)
        XCTAssertTrue(CoreListTransition(animation: .curve(duration: -1, curve: .linear))
                        .isImmediate)
        XCTAssertFalse(CoreListTransition.easeInOut(duration: 0.3).isImmediate)
    }

    func testDurationAndCurveAccessors() {
        XCTAssertEqual(CoreListTransition.immediate.duration, 0)
        XCTAssertNil(CoreListTransition.immediate.curve)
        let transition = CoreListTransition.easeInOut(duration: 0.4)
        XCTAssertEqual(transition.duration, 0.4, accuracy: 1e-12)
        XCTAssertEqual(transition.curve, .easeInOut)
    }

    func testScaledMultipliesDurationAndKeepsCurve() {
        let scaled = CoreListTransition.easeInOut(duration: 0.5).scaled(by: 10)
        XCTAssertEqual(scaled.duration, 5, accuracy: 1e-12)
        XCTAssertEqual(scaled.curve, .easeInOut)
        // A negative factor cannot produce a negative duration.
        XCTAssertEqual(CoreListTransition.easeInOut(duration: 0.5).scaled(by: -2).duration, 0)
        // Scaling .none stays .none.
        XCTAssertTrue(CoreListTransition.immediate.scaled(by: 10).isImmediate)
    }

    func testEqualityComparesAnimationAndIgnoresUserData() {
        let a = CoreListTransition.easeInOut(duration: 0.3)
        let b = CoreListTransition.easeInOut(duration: 0.3).withUserData("tag")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, CoreListTransition.easeInOut(duration: 0.4))
        XCTAssertEqual(b.userData(String.self), "tag")
    }

    // MARK: - Executor

    func testImmediateSetterWritesValueAndLeavesNoAnimation() {
        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 10)
        CoreListTransition.immediate.setPositionY(layer: layer, 40)
        XCTAssertEqual(layer.position.y, 40, accuracy: 1e-12)
        XCTAssertNil(layer.animation(forKey: "position"))
    }

    func testAnimatedSetterWritesFinalValueAndInstallsAnimation() {
        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 10)
        CoreListTransition.easeInOut(duration: 0.3).setPositionY(layer: layer, 40)
        XCTAssertEqual(layer.position.y, 40, accuracy: 1e-12)
        XCTAssertNotNil(layer.animation(forKey: "position.y"))
    }

    func testSetterEarlyOutsOnEqualTarget() {
        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 40)
        CoreListTransition.easeInOut(duration: 0.3).setPositionY(layer: layer, 40)
        XCTAssertNil(layer.animation(forKey: "position.y"),
                     "an equal target must not install an animation")
    }

    func testAnimateAppliesTheDurationFactorAsSpeed() throws {
        UIView.debugAnimationDurationFactorOverride = 4
        defer { UIView.debugAnimationDurationFactorOverride = nil }
        let layer = CALayer()
        layer.animate(from: 0, to: 1, keyPath: "opacity",
                      duration: 0.25, delay: 0, curve: .linear,
                      removeOnCompletion: true, additive: false)
        let animation = try XCTUnwrap(layer.animation(forKey: "opacity"))
        // CAAnimationUtils' mechanism: logical duration, factor as speed.
        XCTAssertEqual(animation.duration, 0.25, accuracy: 1e-9)
        XCTAssertEqual(animation.speed, 0.25, accuracy: 1e-6)
        XCTAssertEqual(animation.duration / Double(animation.speed), 1.0, accuracy: 1e-6)
    }

    func testSetTransformWritesAndAnimates() throws {
        let layer = CALayer()
        let target = CATransform3DMakeRotation(0.5, 0, 0, 1)
        CoreListTransition.immediate.setTransform(layer: layer, transform: target)
        XCTAssertTrue(CATransform3DEqualToTransform(layer.transform, target))
        XCTAssertNil(layer.animation(forKey: "transform"))
    }

    // MARK: - Exact solver

    /// Reference cubic-bezier evaluation by bisection — slow but unconditionally correct, so it
    /// pins `solve` without reusing `solve`'s own Newton code as its own oracle.
    private func referenceBezier(_ x1: CGFloat, _ y1: CGFloat,
                                 _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat) -> CGFloat {
        func curveAt(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
            let a = 1.0 - 3.0 * a2 + 3.0 * a1
            let b = 3.0 * a2 - 6.0 * a1
            let c = 3.0 * a1
            return ((a * t + b) * t + c) * t
        }
        var lo: CGFloat = 0, hi: CGFloat = 1
        for _ in 0..<100 {
            let mid = (lo + hi) * 0.5
            if curveAt(mid, x1, x2) < x { lo = mid } else { hi = mid }
        }
        return curveAt((lo + hi) * 0.5, y1, y2)
    }

    func testSolveIsExactWithNoTailClamp() {
        // `.custom` stores Float control points, so the reference must be given the SAME
        // float32-rounded values — otherwise this measures the payload width (about 2e-8) rather
        // than the solver. The payload-free cases keep their exact Double literals.
        func f(_ v: Float) -> CGFloat { CGFloat(v) }
        let curves: [(CoreListTransition.Animation.Curve, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (.easeInOut, 0.42, 0.0, 0.58, 1.0),
            (.easeIn, 0.42, 0.0, 1.0, 1.0),
            (.spring, 0.380, 0.700, 0.125, 1.000),
            (.custom(0.33, 0.52, 0.25, 0.99), f(0.33), f(0.52), f(0.25), f(0.99))
        ]
        // One assertion per curve, not per sample: a per-sample assertion emits a thousand
        // failure records for a single bug, which buries the signal and bloats the result bundle.
        for (curve, x1, y1, x2, y2) in curves {
            var worst: CGFloat = 0
            var worstX: CGFloat = 0
            for step in 0...1000 {
                let x = CGFloat(step) / 1000.0
                let deviation = abs(curve.solve(at: x) - referenceBezier(x1, y1, x2, y2, x))
                if deviation > worst { worst = deviation; worstX = x }
            }
            XCTAssertLessThan(worst, 1e-9,
                              "\(curve) deviates from the exact bezier by \(worst) at x=\(worstX)")
        }
    }

    /// The clamp used to snap everything from x ≈ 0.9606 onward to exactly 1.0. Its removal is the
    /// whole point: CA keeps interpolating there, so the model must too.
    func testTailIsInterpolatedNotSnapped() {
        let curve = CoreListTransition.Animation.Curve.easeInOut
        XCTAssertLessThan(curve.solve(at: 0.97), 1.0)
        XCTAssertLessThan(curve.solve(at: 0.99), 1.0)
        XCTAssertGreaterThan(curve.solve(at: 0.99), curve.solve(at: 0.97))
        XCTAssertEqual(curve.solve(at: 1.0), 1.0, accuracy: 1e-12)
    }

    /// Control points whose x-derivative vanishes defeat Newton; bisection must still land it.
    func testDegenerateControlPointsStillSolve() {
        let curve = CoreListTransition.Animation.Curve.custom(0.0, 0.0, 0.0, 1.0)
        XCTAssertEqual(curve.solve(at: 0.0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(curve.solve(at: 1.0), 1.0, accuracy: 1e-9)
        var previous = curve.solve(at: 0)
        var regressedAt: CGFloat?
        var sawNaN = false
        for step in 1...200 {
            let x = CGFloat(step) / 200.0
            let value = curve.solve(at: x)
            if value.isNaN { sawNaN = true }
            if value < previous - 1e-9, regressedAt == nil { regressedAt = x }
            previous = value
        }
        XCTAssertFalse(sawNaN, "degenerate control points produced NaN")
        XCTAssertNil(regressedAt, "solve regressed at x=\(regressedAt.map(String.init) ?? "-")")
    }


    // MARK: - Spring kind

    func testTransitionResolvesSpringKindAtConstruction() {
        XCTAssertEqual(CoreListTransition.spring(duration: 0.5).springKind, .system05)
        XCTAssertEqual(CoreListTransition.spring(duration: 0.4).springKind, .adjustedBezier)
        XCTAssertEqual(CoreListTransition.easeInOut(duration: 0.5).springKind, .adjustedBezier,
                       "a non-spring curve never selects a system spring")
        XCTAssertEqual(CoreListTransition.immediate.springKind, .adjustedBezier)
    }

    /// The load-bearing one. The controller scales before the model sees the transition, so if
    /// `scaled(by:)` recomputed the kind, a x10 drag coefficient would turn the 0.5 system spring
    /// into a bezier and nobody would notice outside Slow Animations.
    func testScalingPreservesSpringKind() {
        let scaled = CoreListTransition.spring(duration: 0.5).scaled(by: 10)
        XCTAssertEqual(scaled.duration, 5.0, accuracy: 1e-12)
        XCTAssertEqual(scaled.springKind, .system05,
                       "scaling must not re-resolve the kind from the scaled duration")
    }


    // MARK: - Shared factory

    func testFactoryEmitsBasicAnimationWithTimingFunctionForBezierCurves() throws {
        let animation = makeCoreListAnimation(from: 0, to: 100, keyPath: "position.y",
                                              curve: .easeInOut, springKind: .adjustedBezier,
                                              logicalDuration: 0.3, durationFactor: 1, additive: true)
        XCTAssertFalse(animation is CASpringAnimation)
        XCTAssertEqual(animation.keyPath, "position.y")
        XCTAssertTrue(animation.isAdditive)
        XCTAssertEqual(animation.duration, 0.3, accuracy: 1e-12)
        XCTAssertEqual(animation.speed, 1.0, "CoreList pre-scales duration instead of using speed")
        XCTAssertNotNil(animation.timingFunction)
    }

    func testFactoryEmitsRealSpringForTheSystemBranch() throws {
        let animation = makeCoreListAnimation(from: 0, to: 100, keyPath: "position.y",
                                              curve: .spring, springKind: .system05,
                                              logicalDuration: 0.5, durationFactor: 1, additive: false)
        let spring = try XCTUnwrap(animation as? CASpringAnimation)
        // Faithful to `makeSpringAnimationImpl` (UIKitUtils.m:53), which DELEGATES to the 26-spring
        // on iOS 26 rather than using the older constants. Asserting 3/1000/500 unconditionally
        // would be asserting against Display, not with it.
        if #available(iOS 26.0, *) {
            XCTAssertEqual(spring.mass, 1.0, accuracy: 1e-9)
            XCTAssertEqual(spring.stiffness, 555.027, accuracy: 1e-9)
            XCTAssertEqual(spring.damping, 47.118, accuracy: 1e-9)
        } else {
            XCTAssertEqual(spring.mass, 3.0, accuracy: 1e-9)
            XCTAssertEqual(spring.stiffness, 1000.0, accuracy: 1e-9)
            XCTAssertEqual(spring.damping, 500.0, accuracy: 1e-9)
        }
    }

    func testFactoryEmitsAdjustedBezierForANonSpecialSpringDuration() throws {
        let animation = makeCoreListAnimation(from: 0, to: 100, keyPath: "position.y",
                                              curve: .spring, springKind: .adjustedBezier,
                                              logicalDuration: 0.4, durationFactor: 1, additive: false)
        XCTAssertFalse(animation is CASpringAnimation)
        XCTAssertNotNil(animation.timingFunction)
    }

    func testFactoryNeverEmitsKeyframes() {
        let curves: [CoreListTransition.Animation.Curve] = [
            .easeInOut, .easeIn, .linear, .custom(0.1, 0.2, 0.3, 0.4), .spring
        ]
        for curve in curves {
            for kind in [CoreListSpringKind.adjustedBezier, .system05] {
                let animation = makeCoreListAnimation(from: 0, to: 1, keyPath: "opacity",
                                                      curve: curve, springKind: kind,
                                                      logicalDuration: 0.3, durationFactor: 1, additive: false)
                XCTAssertFalse(animation is CAKeyframeAnimation, "\(curve)/\(kind)")
            }
        }
    }

}

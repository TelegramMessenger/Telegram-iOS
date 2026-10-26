import XCTest
import UIKit
import ObjectiveC
@testable import CoreListDemo

/// Pins `CoreListTransition.Animation.Curve.uiKitScroll` to the real curve
/// `UIScrollView.setContentOffset(_:animated: true)` runs.
///
/// The provenance, established by disassembling UIKitCore:
///
/// - `-[UIScrollView setContentOffset:animated:]` forwards to
///   `_setContentOffset:animated:animationCurve:` with animation curve **0**.
/// - `-[UIScrollView _animateScrollToContentOffset:animationCurve:…]` installs a
///   `UIScrollViewScrollAnimation`, taking the no-custom-animation branch: duration comes from
///   `_contentOffsetAnimationDuration` and the curve is forwarded to `setAnimationCurve:`.
/// - `-[UIScrollViewScrollAnimation progressForFraction:]` defers to super whenever
///   `_customAnimation` is nil, which is the case for every plain animated scroll.
/// - `-[UIAnimation progressForFraction:]` switches on `animationCurve & 0xf`; case 0 is
///   `sin(t · π/2)²`.
///
/// Two independent legs are checked, so neither has to be taken on faith:
///
/// 1. UIKit's own curve function really is `sin²(t·π/2)` — the `π/2` was inferred from the
///    disassembly (the constant itself is an unnamed literal), so it is *measured* here by calling
///    UIKit's implementation directly.
/// 2. Our shipped bezier approximates that closed form to within the documented bound.
///
/// Leg 1 uses private API and is skipped rather than failed when UIKit moves — this is a test
/// target, nothing here ships.
final class UIScrollViewCurveParityTests: XCTestCase {
    /// `-[UIAnimation progressForFraction:]`, case 0.
    private func uiKitClosedFormProgress(_ t: CGFloat) -> CGFloat {
        let s = sin(t * .pi / 2.0)
        return s * s
    }

    /// The peak deviation of the shipped bezier from `sin²(t·π/2)`, measured over 200,001 uniform
    /// samples with the control points widened back from `Float` exactly as `solve(at:)` widens
    /// them. Tracking the measured value rather than a round number means a change to the control
    /// points fails here loudly instead of quietly degrading.
    private let expectedPeakDeviation: CGFloat = 1.9651e-4

    // MARK: - Leg 2: the shipped curve vs UIKit's closed form

    func testSolveApproximatesUIKitSinSquaredCurveWithinDocumentedBound() {
        let curve = CoreListTransition.Animation.Curve.uiKitScroll

        var peak: CGFloat = 0.0
        var peakAt: CGFloat = 0.0
        let samples = 20_001
        for i in 0..<samples {
            let x = CGFloat(i) / CGFloat(samples - 1)
            let deviation = abs(curve.solve(at: x) - uiKitClosedFormProgress(x))
            if deviation > peak {
                peak = deviation
                peakAt = x
            }
        }

        // A 5% band around the measured optimum: tight enough that any real change to the control
        // points trips it, loose enough to survive sampling-grid differences.
        XCTAssertLessThanOrEqual(peak, expectedPeakDeviation * 1.05,
                                 "uiKitScroll drifted from sin²(t·π/2); peak \(peak) at x=\(peakAt)")
        XCTAssertGreaterThanOrEqual(peak, expectedPeakDeviation * 0.95,
                                    "uiKitScroll fits BETTER than recorded (\(peak)) — if the control "
                                    + "points were improved deliberately, update expectedPeakDeviation "
                                    + "and the doc comment on Curve.uiKitScroll.")
    }

    /// The whole point of choosing a bezier over sampled keyframes was to keep one function on both
    /// sides of the seam. If `mediaTimingFunction` and `solve(at:)` ever disagree, the analytic model
    /// and the render server are describing different animations — the defect class CoreList removed
    /// the 0.997 bezier clamp to avoid.
    func testEmittedTimingFunctionIsTheSameCurveSolveEvaluates() {
        guard case let .custom(c1x, c1y, c2x, c2y) = CoreListTransition.Animation.Curve.uiKitScroll else {
            return XCTFail("uiKitScroll must stay a `.custom` bezier so it bridges losslessly to "
                           + "ComponentTransition and needs no new switch cases")
        }

        let timing = CoreListTransition.Animation.Curve.uiKitScroll.mediaTimingFunction
        var first = [Float](repeating: 0, count: 2)
        var second = [Float](repeating: 0, count: 2)
        timing.getControlPoint(at: 1, values: &first)
        timing.getControlPoint(at: 2, values: &second)

        XCTAssertEqual(first[0], c1x, accuracy: 1e-7)
        XCTAssertEqual(first[1], c1y, accuracy: 1e-7)
        XCTAssertEqual(second[0], c2x, accuracy: 1e-7)
        XCTAssertEqual(second[1], c2y, accuracy: 1e-7)
    }

    func testCurveIsMonotonicWithExactEndpoints() {
        let curve = CoreListTransition.Animation.Curve.uiKitScroll

        XCTAssertEqual(curve.solve(at: 0.0), 0.0, accuracy: 1e-12)
        XCTAssertEqual(curve.solve(at: 1.0), 1.0, accuracy: 1e-12)

        // The true curve has f'(0) = f'(1) = 0 and never reverses; the fit preserves both, which is
        // why the symmetric family was chosen over the marginally-tighter free optimum.
        var previous: CGFloat = 0.0
        for i in 0...10_000 {
            let value = curve.solve(at: CGFloat(i) / 10_000.0)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-12,
                                        "uiKitScroll reversed at x=\(CGFloat(i) / 10_000.0)")
            previous = value
        }
    }

    // MARK: - Leg 1: UIKit's own implementation, called directly

    func testUIKitsOwnCurveFunctionIsSinSquared() throws {
        let progressSelector = NSSelectorFromString("progressForFraction:")
        let initSelector = NSSelectorFromString("initWithTarget:")

        guard let animationClass = NSClassFromString("UIScrollViewScrollAnimation"),
              animationClass.instancesRespond(to: progressSelector),
              animationClass.instancesRespond(to: initSelector),
              let method = class_getInstanceMethod(animationClass, progressSelector)
        else {
            throw XCTSkip("UIScrollViewScrollAnimation/progressForFraction: is unavailable in this "
                          + "UIKit; the shipped curve is still pinned by the closed-form tests above.")
        }

        // `takeUnretainedValue` on the alloc deliberately leaks one object: taking it retained
        // would over-release at scope exit and crash the whole suite. A single leaked animation in
        // a test process is the safe trade.
        let scrollView = UIScrollView()
        guard let allocated = (animationClass as AnyObject).perform(NSSelectorFromString("alloc"))?
                .takeUnretainedValue(),
              let animation = allocated.perform(initSelector, with: scrollView)?.takeUnretainedValue()
        else {
            throw XCTSkip("Could not construct a UIScrollViewScrollAnimation.")
        }

        // A freshly allocated instance is zeroed, so `_animationCurve` is already 0 — the value
        // `setContentOffset:animated:` passes. Set it explicitly anyway so the test does not depend
        // on that.
        let setCurveSelector = NSSelectorFromString("setAnimationCurve:")
        if animationClass.instancesRespond(to: setCurveSelector),
           let setCurve = class_getInstanceMethod(animationClass, setCurveSelector) {
            typealias SetCurveFunction = @convention(c) (AnyObject, Selector, Int) -> Void
            let function = unsafeBitCast(method_getImplementation(setCurve), to: SetCurveFunction.self)
            function(animation, setCurveSelector, 0)
        }

        typealias ProgressFunction = @convention(c) (AnyObject, Selector, Float) -> Float
        let progress = unsafeBitCast(method_getImplementation(method), to: ProgressFunction.self)

        // `progressForFraction:` computes sin in double and squares in float, so compare at float
        // precision. Any other constant than π/2 in that `fmul` diverges from this by orders of
        // magnitude, which is exactly what this test exists to detect.
        for i in 0...1_000 {
            let fraction = Float(i) / 1_000.0
            let actual = progress(animation, progressSelector, fraction)
            let expected = Float(uiKitClosedFormProgress(CGFloat(fraction)))
            XCTAssertEqual(actual, expected, accuracy: 2e-6,
                           "UIKit's curve 0 is not sin²(t·π/2) at fraction \(fraction)")
        }
    }

    func testUIKitScrollAnimationDurationIsThreeTenths() throws {
        let selector = NSSelectorFromString("_contentOffsetAnimationDuration")
        let scrollView = UIScrollView()
        guard scrollView.responds(to: selector) else {
            throw XCTSkip("-[UIScrollView _contentOffsetAnimationDuration] is unavailable in this UIKit.")
        }

        typealias DurationFunction = @convention(c) (AnyObject, Selector) -> Double
        let duration = unsafeBitCast(scrollView.method(for: selector), to: DurationFunction.self)

        // `-[UIScrollView initWithFrame:]` stores the literal 0x3FD3333333333333 here, and the
        // duration is distance-independent. `CoreListTransition.uiKitScroll(duration:)` defaults
        // to it, as does the chat backend's `.Default` scroll.
        XCTAssertEqual(duration(scrollView, selector), 0.3, accuracy: 1e-12)
        XCTAssertEqual(CoreListTransition.uiKitScroll().duration, 0.3, accuracy: 1e-12)
    }
}

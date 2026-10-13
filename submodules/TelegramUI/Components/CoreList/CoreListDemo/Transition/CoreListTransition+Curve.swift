import CoreGraphics

// Cubic-bezier solver copied from Display/Source/Spring.swift so CoreList stays dependency-free.
// Do not "improve" the algorithm: ComponentFlow's curves are defined by exactly these four Newton
// iterations and the 0.997 clamp, and CoreList's parity with them depends on matching it.

private func bezierA(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat { 1.0 - 3.0 * a2 + 3.0 * a1 }
private func bezierB(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat { 3.0 * a2 - 6.0 * a1 }
private func bezierC(_ a1: CGFloat) -> CGFloat { 3.0 * a1 }

private func calcBezier(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
    ((bezierA(a1, a2) * t + bezierB(a1, a2)) * t + bezierC(a1)) * t
}

private func calcSlope(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
    3.0 * bezierA(a1, a2) * t * t + 2.0 * bezierB(a1, a2) * t + bezierC(a1)
}

/// Inverts x(t) for the given control-x values.
///
/// Newton first — it converges in two or three steps for every well-conditioned curve — then
/// bisection for control points where `x'(t)` vanishes and Newton cannot make progress. Display's
/// version runs a fixed 4 iterations with no fallback; the extra robustness matters because
/// `.custom` control points come from callers.
private func getTForX(_ x: CGFloat, _ x1: CGFloat, _ x2: CGFloat) -> CGFloat {
    var t = x
    for _ in 0..<8 {
        let error = calcBezier(t, x1, x2) - x
        if abs(error) < 1e-12 { return t }
        let slope = calcSlope(t, x1, x2)
        if slope == 0.0 { break }
        let next = t - error / slope
        if next < 0.0 || next > 1.0 || next.isNaN { break }
        t = next
    }

    var lo: CGFloat = 0.0
    var hi: CGFloat = 1.0
    for _ in 0..<60 {
        let mid = (lo + hi) * 0.5
        if calcBezier(mid, x1, x2) < x { lo = mid } else { hi = mid }
    }
    return (lo + hi) * 0.5
}

/// Cubic-bezier progress. Unlike Display's `bezierPoint` there is **no 0.997 clamp**: Core
/// Animation keeps interpolating through the tail, and this value has to agree with what CA
/// renders. Measured, the clamp was the entire 2.9e-3 error — the iteration count was already
/// exact to 4.4e-16.
func coreListBezierPoint(_ x1: CGFloat, _ y1: CGFloat,
                         _ x2: CGFloat, _ y2: CGFloat,
                         _ x: CGFloat) -> CGFloat {
    calcBezier(getTForX(x, x1, x2), y1, y2)
}

/// The app's adjusted spring curve.
///
/// Both `ComponentTransition.Curve.spring` and `ContainedViewLayoutTransitionCurve.spring` emit
/// through `kCAMediaTimingFunctionSpring`, and `CAAnimationUtils` (`CAAnimationUtils.swift:119`)
/// resolves that to one of three things:
///
/// 1. iOS 26 and `duration ≈ 0.3832` → a real `CASpringAnimation` (`make26SpringAnimationImpl`);
/// 2. `duration == 0.5` → a real `CASpringAnimation` (`makeSpringAnimation`);
/// 3. **any other duration → `CAMediaTimingFunction(controlPoints: 0.380, 0.700, 0.125, 1.000)`.**
///
/// Case 3 is what the app actually renders for an arbitrary duration, so it is what CoreList
/// samples. Cases 1 and 2 are real springs behind private `UIKitRuntimeUtils` API that CoreList
/// cannot reproduce; at exactly those two durations CoreList's spring is an approximation of them.
/// No CoreList or chat-backend site currently uses either (the chat backend springs at 0.4).
///
/// Note this constant is NOT what ComponentFlow's own `solve(at:)` returns — that routes to
/// `listViewAnimationCurveSystem`, which samples the 0.5s `CASpringAnimation`, so ComponentFlow's
/// analytic spring and its emitted spring agree only at duration 0.5. CoreList is analytic-first:
/// what it samples is exactly what it emits, so it follows the emitted curve.
private let coreListAdjustedSpring: (CGFloat, CGFloat, CGFloat, CGFloat) = (0.380, 0.700, 0.125, 1.000)

public extension CoreListTransition.Animation.Curve {
    /// Progress at unit phase `offset`. Mirrors `ComponentTransition.Animation.Curve.solve(at:)`,
    /// except for `.spring` — see `coreListAdjustedSpring` above.
    ///
    /// `.bounce` is not a unit curve at all: ComponentFlow's own `solve` asserts on it and routes to
    /// private spring API instead. CoreList does the same and degrades to `.spring`.
    func solve(at offset: CGFloat) -> CGFloat {
        let x = min(max(offset, 0.0), 1.0)
        switch self {
        case .easeInOut:
            return coreListBezierPoint(0.42, 0.0, 0.58, 1.0, x)
        case .easeIn:
            return coreListBezierPoint(0.42, 0.0, 1.0, 1.0, x)
        case .spring:
            let (x1, y1, x2, y2) = coreListAdjustedSpring
            return coreListBezierPoint(x1, y1, x2, y2, x)
        case .linear:
            // Identity must stay identity — no 0.997 clamp here, matching
            // `listViewAnimationCurveLinear`.
            return x
        case let .custom(c1x, c1y, c2x, c2y):
            return coreListBezierPoint(CGFloat(c1x), CGFloat(c1y), CGFloat(c2x), CGFloat(c2y), x)
        case .uiKitSmoothDeceleration:
            // Not a bezier at all — the closed form of the critically damped spring CA is rendering,
            // so the model and the render server evaluate the same function. See
            // `coreListSmoothDecelerationProgress`.
            return coreListSmoothDecelerationProgress(phase: x)
        case .bounce:
            assertionFailure("`.bounce` is not a unit curve; CoreList samples `.spring` instead")
            let (x1, y1, x2, y2) = coreListAdjustedSpring
            return coreListBezierPoint(x1, y1, x2, y2, x)
        }
    }
}

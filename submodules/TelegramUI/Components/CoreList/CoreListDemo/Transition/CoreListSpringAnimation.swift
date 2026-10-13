import UIKit
import QuartzCore

// Spring factories copied verbatim from UIKitRuntimeUtils' `makeSpringAnimationImpl` /
// `make26SpringAnimationImpl` (UIKitUtils.m:53, :68). Only `valueAt:` and the
// `highFrameRateReason` key were private there; the CASpringAnimation parameters themselves are
// public API, so CoreList builds the same animations without taking the dependency.

func makeCoreListSpringAnimation(_ keyPath: String, duration: Double) -> CABasicAnimation {
    if #available(iOS 26.0, *) {
        return makeCoreList26SpringAnimation(keyPath, duration)
    }
    let springAnimation = CASpringAnimation(keyPath: keyPath)
    springAnimation.mass = 3.0
    springAnimation.stiffness = 1000.0
    springAnimation.damping = 500.0
    springAnimation.duration = 0.5
    springAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    return springAnimation
}

func makeCoreList26SpringAnimation(_ keyPath: String, _ duration: Double) -> CABasicAnimation {
    let springAnimation = CASpringAnimation(keyPath: keyPath)
    springAnimation.mass = 1.0
    springAnimation.stiffness = 555.027
    springAnimation.damping = 47.118
    springAnimation.duration = duration
    springAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    if #available(iOS 17.0, *) {
        springAnimation.allowsOverdamping = false
    }
    if #available(iOS 15.0, *) {
        springAnimation.preferredFrameRateRange = CAFrameRateRange(minimum: 80.0,
                                                                   maximum: 120.0,
                                                                   preferred: 120.0)
    }
    return springAnimation
}

// MARK: - UIKit's smooth-deceleration scroll spring

/// The spring `UIScrollView` uses for **scroll-to-top** (status-bar tap) and
/// `_setContentOffsetWithDecelerationAnimation:` — UIKit's `__smoothDecelerationAnimation()`
/// singleton, NOT the curve `setContentOffset(_:animated:)` runs.
///
/// UIKit builds it as `[UISpringTimingParameters _convertDampingRatio: 1.0 response: 0.6 …]`, then
/// sets `duration = [animation durationForEpsilon: 2⁻¹²⁶]`. Every field below was read off the live
/// animation object rather than guessed — `response` is an unnamed literal in the binary, so it is
/// not recoverable statically. `SmoothDecelerationParityTests` re-reads UIKit's object and fails if
/// any of it drifts.
///
/// It also attaches `CAMediaTimingFunction(controlPoints: 0, 0.2, 1, 1)`, which is **dead**:
/// `-[UIScrollViewScrollAnimation progressForFraction:]` computes the timing function first and then
/// unconditionally overwrites it from the `CASpringAnimation` branch. It is reproduced here only so
/// the emitted object matches UIKit's field for field.
public let coreListSmoothDecelerationResponse: Double = 0.6
/// UIKit's own settle time for this spring, `[animation durationForEpsilon: 2⁻¹²⁶]`.
///
/// This is a MEASURED UIKit value, not a tuning knob — `makeCoreListSmoothDecelerationAnimation`
/// stamps it onto the emitted animation and `SmoothDecelerationParityTests` asserts it equals what
/// UIKit's live object reports. To change how fast CoreList plays the curve, change
/// `coreListSmoothDecelerationDefaultDuration`; changing this one would break that parity check and
/// silently redefine the curve's shape (it is the argument scale of the closed form below).
public let coreListSmoothDecelerationNaturalDuration: Double = 1.6

/// The duration CoreList actually plays the curve at, and the default for
/// `CoreListTransition.uiKitSmoothDeceleration(duration:)`.
///
/// Distinct from the natural duration on purpose. `makeCoreListAnimation` maps a pass duration onto
/// a system spring through `speed` (= natural / logical), so this replays the *identical* unit curve
/// ~1.39× faster rather than becoming a different spring — half the travel by ~0.115s, ~96% by
/// ~0.35s, with the same critically damped shape and no overshoot. Equivalent to a spring of
/// response `0.6 × 1.15/1.6 = 0.43125`, expressed as playback speed so the emitted object stays
/// UIKit's.
public let coreListSmoothDecelerationDefaultDuration: Double = 1.15
/// Undamped angular frequency, `2π / response`.
public let coreListSmoothDecelerationOmega: Double =
    2.0 * Double.pi / coreListSmoothDecelerationResponse

func makeCoreListSmoothDecelerationAnimation(_ keyPath: String) -> CASpringAnimation {
    let springAnimation = CASpringAnimation(keyPath: keyPath)
    springAnimation.mass = 1.0
    // dampingRatio 1.0 => stiffness = ω²m, damping = 2ζ√(km) = 2ω. Written as the derivation rather
    // than as literals so "critically damped" stays legible; matches UIKit to ~1e-14.
    springAnimation.stiffness = coreListSmoothDecelerationOmega * coreListSmoothDecelerationOmega
    springAnimation.damping = 2.0 * coreListSmoothDecelerationOmega
    springAnimation.duration = coreListSmoothDecelerationNaturalDuration
    springAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.0, 0.2, 1.0, 1.0)
    if #available(iOS 17.0, *) {
        springAnimation.allowsOverdamping = false
    }
    return springAnimation
}

/// `ω · naturalDuration` — the argument scale of the closed form below.
///
/// Deliberately the NATURAL duration, not the pass duration: a caller asking for a different
/// duration gets the same unit curve replayed at a different `speed` (that is how
/// `makeCoreListAnimation` maps every system spring onto a pass), so the shape must not move.
private let smoothDecelerationPhaseScale =
    coreListSmoothDecelerationOmega * coreListSmoothDecelerationNaturalDuration

/// Closed-form progress of the smooth-deceleration spring at unit `phase`.
///
/// For a critically damped unit step released from rest, `x(t) = 1 − (1 + ωt)·e^(−ωt)`. Verified
/// against UIKit's own `_solveForInput:` to six decimals across the range, which is why CoreList
/// evaluates this directly instead of reaching for private API the way the opaque system springs
/// must — there is nothing here that needs reverse-engineering at runtime.
///
/// Note it lands at 0.9999991 rather than 1.0 at `phase == 1`; that is what the spring genuinely
/// renders, and normalising it would put this function at odds with the emitted animation.
func coreListSmoothDecelerationProgress(phase: CGFloat) -> CGFloat {
    let x = min(max(Double(phase), 0.0), 1.0) * smoothDecelerationPhaseScale
    return CGFloat(1.0 - (1.0 + x) * exp(-x))
}

/// Which of `CAAnimationUtils.swift:119`'s three `kCAMediaTimingFunctionSpring` branches a duration
/// selects.
///
/// **Always resolved from the LOGICAL duration.** `0.5` and `0.3832` are logical values —
/// `CAAnimationUtils` sees them unscaled because it handles Slow Animations with `speed`, whereas
/// CoreList pre-scales. Resolving from a scaled duration would see `5.0` under a ×10 drag
/// coefficient, miss `.system05`, and silently emit a bezier: a divergence visible only under Slow
/// Animations.
enum CoreListSpringKind: Equatable {
    case system26
    case system05
    case adjustedBezier
}

func coreListSpringKind(logicalDuration: Double) -> CoreListSpringKind {
    if #available(iOS 26.0, *), abs(logicalDuration - 0.3832) <= 0.0001 {
        return .system26
    }
    if logicalDuration == 0.5 {
        return .system05
    }
    return .adjustedBezier
}

/// Analytic evaluation of a real `CASpringAnimation`, reproducing what
/// `-[CASpringAnimation(AnimationUtils) valueAt:]` does in `UIKitUtils.m:24`.
///
/// `valueAt:` is Display's OWN category, not an Apple selector — `CASpringAnimation` does not
/// respond to it unless `UIKitRuntimeUtils` is linked, which CoreList deliberately does not do. What
/// it wraps is the genuinely private `_solveForInput:`, and the wrapper exists because that method's
/// argument is `float` on some builds and `double` on others, so the IMP has to be called with the
/// matching calling convention. This reimplements the same lookup.
///
/// The selector name is assembled at runtime rather than written as a literal, matching Display.
private enum CoreListSpringSolver {
    typealias FloatImp = @convention(c) (AnyObject, Selector, Float) -> Float
    typealias DoubleImp = @convention(c) (AnyObject, Selector, Double) -> Double

    static let selector = NSSelectorFromString("_" + "solveForInput:")

    /// Resolved once: which calling convention `_solveForInput:` uses, or neither if it is gone.
    static let resolved: (float: FloatImp?, double: DoubleImp?) = {
        guard let method = class_getInstanceMethod(CASpringAnimation.self, selector) else {
            return (nil, nil)
        }
        // Argument 2 is the first real parameter: 0 is self, 1 is _cmd. `NSMethodSignature` is not
        // usable from Swift, so read the encoding straight off the method.
        var argumentType = [CChar](repeating: 0, count: 16)
        method_getArgumentType(method, 2, &argumentType, argumentType.count)
        let imp = method_getImplementation(method)
        switch argumentType[0] {
        case CChar(UInt8(ascii: "f")):
            return (unsafeBitCast(imp, to: FloatImp.self), nil)
        case CChar(UInt8(ascii: "d")):
            return (nil, unsafeBitCast(imp, to: DoubleImp.self))
        default:
            return (nil, nil)
        }
    }()

    static func solve(_ animation: CASpringAnimation, _ t: CGFloat) -> CGFloat? {
        if let floatImp = resolved.float {
            return CGFloat(floatImp(animation, selector, Float(t)))
        }
        if let doubleImp = resolved.double {
            return CGFloat(doubleImp(animation, selector, Double(t)))
        }
        return nil
    }
}

private let system05Spring = makeCoreListSpringAnimation("", duration: 0.5) as? CASpringAnimation
private let system26Spring = makeCoreList26SpringAnimation("", 0.3832) as? CASpringAnimation

/// Analytic value of a system spring at unit `phase`, or nil for `.adjustedBezier` (solved by
/// `Curve.solve`) and on any OS where `_solveForInput:` has gone away — callers fall back to the
/// adjusted bezier so the model and the emitter degrade together rather than disagreeing.
///
/// Display's own fallback returns `t`, i.e. linear. Returning nil is better: it lets the caller use
/// the adjusted bezier, which is at least the right family of curve.
func coreListSpringValue(kind: CoreListSpringKind, phase: CGFloat) -> CGFloat? {
    let animation: CASpringAnimation?
    switch kind {
    case .system05: animation = system05Spring
    case .system26: animation = system26Spring
    case .adjustedBezier: return nil
    }
    guard let animation else { return nil }
    return CoreListSpringSolver.solve(animation, min(max(phase, 0.0), 1.0))
}

import UIKit
import QuartzCore

/// The single place CoreList turns a curve into a CAAnimation — a copy of
/// `CAAnimationUtils.makeAnimation`'s branch tree (`CAAnimationUtils.swift:69`), minus the branches
/// CoreList has no caller for (the `kCAMediaTimingFunctionCustomSpringPrefix` parse and the
/// `mediaTimingFunction` override).
///
/// Both emitters call this: `CALayer.animate` installs the result directly, and
/// `CoreAnimationCompiler` layers the model-path properties on top (`beginTime`, `fillMode`,
/// `isRemovedOnCompletion`, generation metadata). One branch tree, so the two cannot drift — which
/// they already did once for `.spring`.
///
/// Slow Animations is handled exactly as `CAAnimationUtils` handles it: `duration` stays LOGICAL and
/// `speed` becomes `1/k`. CoreList used to pre-scale the duration instead — visually equivalent, but
/// it meant the emitted object did not match what the rest of the app emits, and the drag coefficient
/// only appeared as a longer duration rather than as playback speed.
///
/// `ListAnimationModel` still reasons on the SCALED clock (its deadlines and reaping do), which is
/// why the track carries the factor separately and the compiler divides it back out here.
func makeCoreListAnimation(from: CGFloat,
                           to: CGFloat,
                           keyPath: String,
                           curve: CoreListTransition.Animation.Curve,
                           springKind: CoreListSpringKind,
                           logicalDuration: Double,
                           durationFactor: Double,
                           additive: Bool) -> CABasicAnimation {
    makeCoreListAnimation(fromValue: from as NSNumber, toValue: to as NSNumber, keyPath: keyPath,
                          curve: curve, springKind: springKind,
                          logicalDuration: logicalDuration, durationFactor: durationFactor,
                          additive: additive)
}

/// Value-typed form, matching `CAAnimationUtils.makeAnimation(from: Any?, to: Any, …)`. Needed for
/// non-scalar keyPaths such as `transform`, where CA does the interpolation from the endpoints.
func makeCoreListAnimation(fromValue: Any?,
                           toValue: Any,
                           keyPath: String,
                           curve: CoreListTransition.Animation.Curve,
                           springKind: CoreListSpringKind,
                           logicalDuration: Double,
                           durationFactor: Double,
                           additive: Bool) -> CABasicAnimation {
    // Verbatim from CAAnimationUtils: a non-unit, non-zero factor becomes playback speed.
    var speed: Float = 1.0
    if durationFactor != 0 && durationFactor != 1 {
        speed = Float(1.0 / durationFactor)
    }

    let animation: CABasicAnimation
    var isSystemSpring = false

    if case .uiKitSmoothDeceleration = curve {
        // A real CASpringAnimation, exactly as UIKit installs for scroll-to-top. It goes down the
        // `isSystemSpring` path below so its natural 1.6s settle is mapped onto the pass duration as
        // `speed`, the same way the two system springs are.
        animation = makeCoreListSmoothDecelerationAnimation(keyPath)
        isSystemSpring = true
    } else if case .spring = curve {
        switch springKind {
        case .system26:
            animation = makeCoreList26SpringAnimation(keyPath, logicalDuration)
            isSystemSpring = true
        case .system05:
            animation = makeCoreListSpringAnimation(keyPath, duration: logicalDuration)
            isSystemSpring = true
        case .adjustedBezier:
            animation = CABasicAnimation(keyPath: keyPath)
            animation.timingFunction = curve.mediaTimingFunction
        }
    } else {
        animation = CABasicAnimation(keyPath: keyPath)
        animation.timingFunction = curve.mediaTimingFunction
    }

    if isSystemSpring {
        // Verbatim CAAnimationUtils: the spring factories set their own duration from the spring's
        // settling behaviour, and `speed` maps it onto the pass duration while also carrying the
        // drag coefficient. `animation.duration` is deliberately left alone.
        if logicalDuration > 0 {
            animation.speed = speed * Float(animation.duration / logicalDuration)
        }
    } else {
        animation.duration = logicalDuration
        animation.speed = speed
    }

    animation.fromValue = fromValue
    animation.toValue = toValue
    animation.isAdditive = additive
    animation.isRemovedOnCompletion = true
    animation.fillMode = .forwards
    return animation
}

extension CoreListTransition.Animation.Curve {
    /// The `CAMediaTimingFunction` CA should evaluate for this curve. Every case here is a cubic
    /// bezier, and it is the SAME bezier `solve(at:)` computes — which is what lets the model stay
    /// authoritative while CA does the interpolating.
    var mediaTimingFunction: CAMediaTimingFunction {
        switch self {
        case .easeInOut:
            return CAMediaTimingFunction(controlPoints: 0.42, 0.0, 0.58, 1.0)
        case .easeIn:
            return CAMediaTimingFunction(controlPoints: 0.42, 0.0, 1.0, 1.0)
        case .linear:
            return CAMediaTimingFunction(name: .linear)
        case let .custom(a, b, c, d):
            return CAMediaTimingFunction(controlPoints: a, b, c, d)
        case .spring, .bounce:
            // Reached for `.spring`'s adjustedBezier branch, and for `.bounce`, which degrades to
            // the same adjusted curve.
            return CAMediaTimingFunction(controlPoints: 0.380, 0.700, 0.125, 1.000)
        case .uiKitSmoothDeceleration:
            // Unreachable from `makeCoreListAnimation` (that case emits a real CASpringAnimation
            // before consulting this). Returns the timing function UIKit itself hangs on the
            // animation, which UIKit also never evaluates — `progressForFraction:` computes it and
            // then overwrites it from the CASpringAnimation branch.
            return CAMediaTimingFunction(controlPoints: 0.0, 0.2, 1.0, 1.0)
        }
    }
}

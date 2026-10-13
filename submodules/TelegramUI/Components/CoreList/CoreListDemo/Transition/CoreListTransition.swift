import UIKit
import QuartzCore

/// A ComponentTransition-shaped animation descriptor, vendored into CoreList.
///
/// CoreList cannot depend on ComponentFlow — its Bazel target has no `deps` and the demo builds
/// standalone in Xcode — so this is a self-contained copy of the value model in
/// `submodules/ComponentFlow/Source/Base/Transition.swift`. The `Animation`/`Curve` case shape is
/// identical, so `CoreListTransitionBridge.swift` in TelegramUI maps between the two case-for-case.
///
/// Deliberate divergences, all recorded in
/// `docs/superpowers/specs/2026-07-27-corelist-transition-design.md`:
///
/// - **A zero duration is immediate.** ComponentFlow treats only `.none` as immediate;
///   `.curve(duration: 0, …)` still animates there. CoreList's model settles a zero-duration
///   property immediately and half its test suite says "no animation" as `duration: 0`, so every
///   branch here tests `isImmediate` and none writes `if case .none`.
/// - **`.spring` samples the app's adjusted spring bezier** `(0.380, 0.700, 0.125, 1.000)` — what
///   `CAAnimationUtils` emits for `kCAMediaTimingFunctionSpring` at any duration other than the two
///   it special-cases with real `CASpringAnimation`s (0.5, and 0.3832 on iOS 26). See
///   `CoreListTransition+Curve.swift`. **`.bounce` is not a unit curve** — ComponentFlow's own
///   `solve` asserts on it too, and CoreList degrades it to `.spring`.
/// - **Additions over ComponentTransition:** `Animation`/`Curve` are `Equatable` (because
///   `ListAnimationTrack` is), the struct has a hand-written `==` over `animation` alone
///   (`_userData: [Any]` blocks synthesis), and `duration`/`curve`/`scaled(by:)` carry over from the
///   deleted `ListAnimationSpec`.
/// - **Not vendored:** shape-layer, gradient, blur, mesh, parabolic, and keyframe-transform helpers.
///   No CoreList consumer, and several need private API.
public struct CoreListTransition: Equatable {
    public enum Animation: Equatable {
        public enum Curve: Equatable {
            case easeInOut
            case easeIn
            case spring
            case linear
            case custom(Float, Float, Float, Float)
            case bounce(stiffness: CGFloat, damping: CGFloat)

            /// UIKit's **scroll-to-top** curve — a critically damped spring, not a bezier.
            ///
            /// This is the one `UIScrollView` uses for a status-bar tap and for
            /// `_setContentOffsetWithDecelerationAnimation:`, and it is a genuinely different family
            /// from `.uiKitScroll`: distance-insensitive 0.3s `sin²` there, a critically damped
            /// settle here. Constants and the closed form live in `CoreListSpringAnimation.swift`;
            /// note the spring's NATURAL settle is UIKit's 1.6s while CoreList plays it at 1.15s, the
            /// same unit curve at a different speed.
            ///
            /// Unlike `.uiKitScroll` this could NOT be spelled as a `.custom` bezier — a spring with
            /// a long asymptotic tail is not a cubic — so it costs a real case, and therefore a
            /// branch in every exhaustive switch over `Curve` (all compile-enforced, including the
            /// `ComponentTransition` bridge in `CoreListChatHistoryBackend.swift`).
            case uiKitSmoothDeceleration

            public static var slide: Curve { .custom(0.33, 0.52, 0.25, 0.99) }

            /// `UIScrollView.setContentOffset(_:animated: true)`'s curve.
            ///
            /// UIKit does not use a bezier here at all. `setContentOffset:animated:` forwards to
            /// `_setContentOffset:animated:animationCurve:` with curve **0**, and
            /// `_animateScrollToContentOffset:…` installs a `UIScrollViewScrollAnimation` whose
            /// `progressForFraction:` defers to `-[UIAnimation progressForFraction:]` whenever no
            /// `_customAnimation` is set — which is the case for every plain animated scroll. That
            /// function switches on `animationCurve & 0xf`, and case 0 computes
            ///
            ///     progress = sin(t · π/2)²     ≡  (1 − cos(π·t)) / 2
            ///
            /// (disassembly: `sin`, then `fmul s0, s0, s0`). Cases 1 and 2 are the half-angle
            /// forms `sin(t·π/2)` and `1 − cos(t·π/2)`; anything ≥ 3 returns the input unchanged.
            ///
            /// The companion duration is `_contentOffsetAnimationDuration`, which
            /// `-[UIScrollView initWithFrame:]` stores as the literal `0x3FD3333333333333` —
            /// **0.3s**, fixed and independent of distance. `CoreListTransition.uiKitScroll(…)`
            /// defaults to it.
            ///
            /// Since `sin²` is not expressible as a `CAMediaTimingFunction`, these control points
            /// are the minimax cubic-bezier fit to it, which keeps CoreList on the
            /// `CABasicAnimation` path and keeps `solve(at:)` and the render server evaluating the
            /// *same* function (the analytic-first invariant — see `mediaTimingFunction`). The fit
            /// is point-symmetric about (0.5, 0.5) exactly as the true curve is, and its peak error
            /// is **1.97e-4** of the travel — 0.1pt over 500pt, well inside the `1/screenScale`
            /// pixel grid that `-[UIScrollViewScrollAnimation setProgress:]` snaps UIKit's own
            /// output to. `UIScrollViewCurveParityTests` pins both the fit and the provenance.
            public static var uiKitScroll: Curve { .custom(0.3643, 0.0, 0.6357, 1.0) }
        }

        case none
        case curve(duration: Double, curve: Curve)
    }

    public var animation: Animation
    /// Which `kCAMediaTimingFunctionSpring` branch this transition's `.spring` selects, resolved
    /// once from the duration this transition was CONSTRUCTED with — which is the logical one.
    /// `scaled(by:)` carries it through untouched; re-resolving from a scaled duration would miss
    /// the system-spring branches under Slow Animations.
    /// Internal, not public: only the compiler and the model consume it, and CoreList's public
    /// surface stays at ComponentTransition's shape.
    private(set) var springKind: CoreListSpringKind
    /// The Slow-Animations factor `scaled(by:)` has applied to this transition, so the emitter can
    /// divide it back out and express it as `speed` the way `CAAnimationUtils` does. 1 means the
    /// duration is still logical.
    private(set) var appliedDurationFactor: Double = 1
    private var _userData: [Any] = []

    public init(animation: Animation) {
        self.animation = animation
        switch animation {
        case .none:
            self.springKind = .adjustedBezier
        case let .curve(duration, curve):
            if case .spring = curve {
                self.springKind = coreListSpringKind(logicalDuration: duration)
            } else {
                self.springKind = .adjustedBezier
            }
        }
    }

    public static var immediate: CoreListTransition { CoreListTransition(animation: .none) }

    public static func easeInOut(duration: Double) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .easeInOut))
    }

    public static func spring(duration: Double) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .spring))
    }

    /// `UIScrollView.setContentOffset(_:animated: true)`, curve and duration together.
    ///
    /// The default is UIKit's own `_contentOffsetAnimationDuration` — 0.3s, fixed regardless of
    /// distance. See `Curve.uiKitScroll` for the derivation.
    public static func uiKitScroll(duration: Double = 0.3) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .uiKitScroll))
    }

    /// UIKit's **scroll-to-top** animation, curve and duration together.
    ///
    /// The default is `coreListSmoothDecelerationDefaultDuration` — **1.15s**, not UIKit's own 1.6s
    /// settle. Passing any duration replays the identical unit curve at a different speed (that is
    /// how `makeCoreListAnimation` maps every system spring onto a pass), so the shape, the critical
    /// damping and the absence of overshoot are unchanged; only the clock moves. At 1.15s: half the
    /// travel by ~0.115s, ~96% by ~0.35s, then the spring's asymptotic tail — which is what makes
    /// this read as "smooth" rather than as a long animation.
    public static func uiKitSmoothDeceleration(
        duration: Double = coreListSmoothDecelerationDefaultDuration
    ) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .uiKitSmoothDeceleration))
    }

    /// True when this transition must settle its target with no animation. Unlike ComponentFlow,
    /// a non-positive duration counts: CoreList's model settles such a property immediately.
    public var isImmediate: Bool {
        switch self.animation {
        case .none:
            return true
        case let .curve(duration, _):
            return duration <= 0
        }
    }

    public var duration: TimeInterval {
        switch self.animation {
        case .none:
            return 0
        case let .curve(duration, _):
            return max(0, duration)
        }
    }

    public var curve: Animation.Curve? {
        switch self.animation {
        case .none:
            return nil
        case let .curve(_, curve):
            return curve
        }
    }

    /// Multiplies the duration, keeping the curve. Used by `ListAnimationController` to apply the
    /// Slow Animations factor exactly once on the model path.
    public func scaled(by factor: Double) -> CoreListTransition {
        switch self.animation {
        case .none:
            return self
        case let .curve(duration, curve):
            var result = self
            result.animation = .curve(duration: max(0, duration * factor), curve: curve)
            // Composes, so scaling twice is still recoverable. springKind is deliberately NOT
            // re-resolved — see its own doc comment.
            result.appliedDurationFactor = self.appliedDurationFactor * factor
            return result
        }
    }

    public func withAnimation(_ animation: Animation) -> CoreListTransition {
        // Re-resolves springKind: the incoming animation carries a logical duration, unlike
        // `scaled(by:)`, which must preserve the already-resolved kind.
        var result = CoreListTransition(animation: animation)
        result._userData = self._userData
        return result
    }

    public func withAnimationIfAnimated(_ animation: Animation) -> CoreListTransition {
        if self.isImmediate { return self }
        return self.withAnimation(animation)
    }

    public func userData<T>(_ type: T.Type) -> T? {
        for item in self._userData.reversed() {
            if let item = item as? T { return item }
        }
        return nil
    }

    public func withUserData(_ userData: Any) -> CoreListTransition {
        var result = self
        result._userData.append(userData)
        return result
    }

    /// `_userData` is `[Any]` and cannot participate; equality is the animation alone.
    public static func == (lhs: CoreListTransition, rhs: CoreListTransition) -> Bool {
        lhs.animation == rhs.animation
    }
}

public extension CoreListTransition {
    // MARK: - Setters
    //
    // Each early-outs on an equal target, exactly as ComponentTransition's do, and each writes the
    // final value before installing an animation.
    //
    // No CATransaction anywhere: every layer CoreList writes is UIView-backed, and a UIView's layer
    // returns a null action by default outside an animation block, so there is no implicit animation
    // to suppress. CoreList creates no standalone CALayer.

    func setPositionY(layer: CALayer, _ value: CGFloat) {
        if layer.position.y == value { return }
        if self.isImmediate {
            layer.position.y = value
            layer.removeAnimation(forKey: "position")
            return
        }
        let previous = layer.presentation()?.position.y ?? layer.position.y
        layer.position.y = value
        self.animateScalar(layer: layer, keyPath: "position.y", from: previous, to: value)
    }

    func setPositionX(layer: CALayer, _ value: CGFloat) {
        if layer.position.x == value { return }
        if self.isImmediate {
            layer.position.x = value
            layer.removeAnimation(forKey: "position")
            return
        }
        let previous = layer.presentation()?.position.x ?? layer.position.x
        layer.position.x = value
        self.animateScalar(layer: layer, keyPath: "position.x", from: previous, to: value)
    }

    func setPosition(layer: CALayer, _ position: CGPoint) {
        self.setPositionX(layer: layer, position.x)
        self.setPositionY(layer: layer, position.y)
    }

    func setBoundsHeight(layer: CALayer, _ value: CGFloat) {
        if layer.bounds.size.height == value { return }
        if self.isImmediate {
            layer.bounds.size.height = value
            layer.removeAnimation(forKey: "bounds.size.height")
            return
        }
        let previous = layer.presentation()?.bounds.size.height ?? layer.bounds.size.height
        layer.bounds.size.height = value
        self.animateScalar(layer: layer, keyPath: "bounds.size.height", from: previous, to: value)
    }

    func setBoundsWidth(layer: CALayer, _ value: CGFloat) {
        if layer.bounds.size.width == value { return }
        if self.isImmediate {
            layer.bounds.size.width = value
            layer.removeAnimation(forKey: "bounds.size.width")
            return
        }
        let previous = layer.presentation()?.bounds.size.width ?? layer.bounds.size.width
        layer.bounds.size.width = value
        self.animateScalar(layer: layer, keyPath: "bounds.size.width", from: previous, to: value)
    }

    func setBoundsOriginY(layer: CALayer, _ value: CGFloat) {
        if layer.bounds.origin.y == value { return }
        if self.isImmediate {
            layer.bounds.origin.y = value
            layer.removeAnimation(forKey: "bounds.origin.y")
            return
        }
        let previous = layer.presentation()?.bounds.origin.y ?? layer.bounds.origin.y
        layer.bounds.origin.y = value
        self.animateScalar(layer: layer, keyPath: "bounds.origin.y", from: previous, to: value)
    }

    func setOpacity(layer: CALayer, _ value: CGFloat) {
        if layer.opacity == Float(value) { return }
        if self.isImmediate {
            layer.opacity = Float(value)
            layer.removeAnimation(forKey: "opacity")
            return
        }
        let previous = CGFloat(layer.presentation()?.opacity ?? layer.opacity)
        layer.opacity = Float(value)
        self.animateScalar(layer: layer, keyPath: "opacity", from: previous, to: value)
    }

    func setAlpha(view: UIView, _ value: CGFloat) {
        self.setOpacity(layer: view.layer, value)
    }

    func setFrame(view: UIView, frame: CGRect) {
        self.setFrame(layer: view.layer, frame: frame)
    }

    func setFrame(layer: CALayer, frame: CGRect) {
        if layer.frame == frame { return }
        if self.isImmediate {
            layer.frame = frame
            return
        }
        let anchor = layer.anchorPoint
        self.setBoundsWidth(layer: layer, frame.width)
        self.setBoundsHeight(layer: layer, frame.height)
        self.setPosition(layer: layer,
                         CGPoint(x: frame.minX + frame.width * anchor.x,
                                 y: frame.minY + frame.height * anchor.y))
    }

    func setScale(layer: CALayer, _ scale: CGFloat) {
        let transform = layer.transform
        let current = sqrt((transform.m11 * transform.m11)
                           + (transform.m12 * transform.m12)
                           + (transform.m13 * transform.m13))
        if current == scale { return }
        if self.isImmediate {
            layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            layer.removeAnimation(forKey: "transform.scale")
            return
        }
        layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
        self.animateScalar(layer: layer, keyPath: "transform.scale", from: current, to: scale)
    }

    func setScale(view: UIView, _ scale: CGFloat) {
        self.setScale(layer: view.layer, scale)
    }

    func setTransform(layer: CALayer, transform: CATransform3D) {
        if CATransform3DEqualToTransform(layer.transform, transform) { return }
        if self.isImmediate {
            layer.transform = transform
            layer.removeAnimation(forKey: "transform")
            return
        }
        // CA interpolates transforms from the endpoints, exactly as ComponentTransition's
        // setTransform does through CAAnimationUtils. An earlier version sampled an ELEMENT-WISE
        // matrix interpolation into keyframes, which is neither what CA does nor what the rest of
        // the app emits — it happened to look right only for the affine transforms in use.
        guard case let .curve(duration, curve) = self.animation, duration > 0 else { return }
        let previous = layer.presentation()?.transform ?? layer.transform
        layer.transform = transform
        let animation = makeCoreListAnimation(
            fromValue: NSValue(caTransform3D: previous),
            toValue: NSValue(caTransform3D: transform),
            keyPath: "transform",
            curve: curve,
            springKind: coreListSpringKind(logicalDuration: duration),
            logicalDuration: duration,
            durationFactor: UIView.animationDurationFactor,
            additive: false
        )
        layer.add(animation, forKey: "transform")
    }

    func setTransform(view: UIView, transform: CATransform3D) {
        self.setTransform(layer: view.layer, transform: transform)
    }

    /// Scalar animation primitive. All setters funnel here so duration scaling and the sampled-curve
    /// rendering live in one place.
    func animateScalar(layer: CALayer,
                       keyPath: String,
                       from: CGFloat,
                       to: CGFloat,
                       additive: Bool = false,
                       completion: ((Bool) -> Void)? = nil) {
        guard case let .curve(duration, curve) = self.animation, duration > 0 else {
            completion?(true)
            return
        }
        layer.animate(from: from, to: to, keyPath: keyPath, duration: duration, delay: 0,
                      curve: curve, removeOnCompletion: true, additive: additive,
                      completion: completion)
    }

    /// UIView-block animation, for item views laying out with UIKit rather than layer writes.
    /// `.custom` and `.bounce` degrade to ease-in-out options: faithful handling needs
    /// `CALayerSpringParametersOverride`, which is private API CoreList cannot reach.
    func animateView(allowUserInteraction: Bool = true,
                     delay: Double = 0.0,
                     _ body: @escaping () -> Void,
                     completion: ((Bool) -> Void)? = nil) {
        guard case let .curve(duration, curve) = self.animation, duration > 0 else {
            body()
            completion?(true)
            return
        }
        var options: UIView.AnimationOptions
        switch curve {
        case .linear:
            options = [.curveLinear]
        case .easeIn:
            options = [.curveEaseIn]
        case .spring:
            options = UIView.AnimationOptions(rawValue: 7 << 16)
        case .easeInOut, .custom, .bounce, .uiKitSmoothDeceleration:
            // `.uiKitSmoothDeceleration` degrades here for the same reason `.custom` does: a
            // UIView block animation cannot take a spring's parameters without
            // `CALayerSpringParametersOverride`, which is private API CoreList cannot reach. Layer
            // animations (the path scrolling actually uses) get the real spring.
            options = [.curveEaseInOut]
        }
        if allowUserInteraction {
            options.insert(.allowUserInteraction)
        }
        UIView.animate(withDuration: duration * UIView.animationDurationFactor,
                       delay: delay * UIView.animationDurationFactor,
                       options: options,
                       animations: body,
                       completion: completion)
    }
}

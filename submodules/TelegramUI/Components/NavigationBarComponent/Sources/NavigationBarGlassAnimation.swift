import Foundation
import UIKit
import Display
import GlassBackgroundComponent

// The glass animation model shared by a navigation transition's capsules (`NavigationBarPlatterTransitionView`) and
// the bar's own in-place capsule changes: SwiftUI's toolbar GlassContainer settings on iOS 27, reverse-engineered
// (docs/superpowers/specs/2026-10-13-native-navigation-glass-platters-ios27-re.md) and calibrated against the native
// reference app (Tests/NativeNavigationReference).

/// SwiftUI's toolbar glass settings (SwiftUICore 27 `GlassContainer.defaultOverride(context:)` 0x1c6ff2468).
enum NavigationBarGlassSettings {
    static let transition = NavigationTransitionSpring(duration: 0.416, bounce: 0.25)
    /// A `.materialize` update resolves the transition spring with no bounce.
    static let materialize = NavigationTransitionSpring(duration: 0.416, bounce: 0.0)
    static let blurRadius: CGFloat = 10.0
    /// Items swapped in a kept capsule are matched (`AppearanceSettings.match`, glass RE §2.3): they shrink to, and grow
    /// from, this scale (no 16 pt cap below 1). Measured on iOS 27 in a push (Edit -> Select Messages).
    static let matchScale: CGFloat = 0.2
    /// `ScalePulse` (SwiftUICore 27 `ScalePulseModifier.animate()` 0x1c7804958): the new set rises at once, the
    /// old set's height falls after 0.113 s and its width after 0.142 s.
    static let pulseUp = NavigationTransitionSpring(duration: 0.292, bounce: 0.5)
    static let pulseDownHeight = NavigationTransitionSpring(duration: 0.416, bounce: 0.416)
    static let pulseDownHeightDelay: CGFloat = 0.113
    static let pulseDownWidth = NavigationTransitionSpring(duration: 0.416, bounce: 0.5)
    static let pulseDownWidthDelay: CGFloat = 0.142
    static let pulseMaxScale: CGFloat = 1.2
    /// UIKit's press on interactive glass (`_UIFlexInteraction`) springs back on this when released: damping 0.375,
    /// response 0.4 (read at run time from `+[UIView _animateUsingSpringBehavior:tracking:...]`: stiffness 246.74,
    /// damping 11.78), so a released press undershoots by 0.28 at ~0.22 s. Measured identical on native toolbar glass.
    static let pressRelease = NavigationTransitionSpring(dampingRatio: 0.375, response: 0.4)
    /// The press glow (`_UIFlexInteraction`'s BigGlow and LittleGlow) fades after release on a critically damped spring
    /// with a 0.5 s response: fit to the native BigGlow's opacity, per 60 Hz frame, within ±0.005 (with about one frame of
    /// latency, not modelled). Measured 2026-10-14 on the iOS 27 simulator; the same with and without a transition.
    static let pressGlowRelease = NavigationTransitionSpring(dampingRatio: 1.0, response: 0.5)
    /// Measured, not read: the native tint cross-fade fits a critically damped spring with a 0.3 s response
    /// (0.29 at 50 ms, 0.54 at 82 ms, 0.84 at 150 ms, done by ~215 ms).
    static let tintCrossFade = NavigationTransitionSpring(dampingRatio: 1.0, response: 0.3)
    /// A platter with no partner at its index that has one to go to on the other bar collapses into it (or grows out of
    /// it) after `minDelay + min(maxDelay, delayFactor · |Δ| / diagonal)` (SwiftUICore 27 `Resolver.adjustMatchedEntry`,
    /// glass RE §1): the toolbar `TransitionSettings`, Δ the resolved offset (`resolvedMatchedOffset`), the diagonal of
    /// the bar's platter container (402 x 54 on an iPhone 18 Pro: `NavigationBarContentView`'s height read in the
    /// reference app).
    static let matchedMinDelay: Double = 0.083
    static let matchedMaxDelay: Double = 0.166
    static let matchedDelayFactor: Double = 0.33
    static let platterContainerHeight: CGFloat = 54.0
    /// The translation kick (`TranslationKickModifier`, glass RE §3.1): Δ / kickFactor, Δ the platter's own centre minus
    /// its partner's (so away from the platter it collapses into, and onward for one growing out of it), out on
    /// `kickOffset` after `kickOffsetDelay`, back to 0 on `kickReturn` after `kickReturnDelay`, both issued as the shape
    /// starts moving.
    static let kickFactor: CGFloat = 6.0
    static let kickOffset = NavigationTransitionSpring(duration: 0.25, bounce: 0.0)
    static let kickOffsetDelay: Double = 0.05
    static let kickReturn = NavigationTransitionSpring(duration: 0.5, bounce: 0.166)
    static let kickReturnDelay: Double = 0.15
    /// How close the bar's glass shapes come before they merge: its platters are the elements of one `CASDFLayer` with
    /// `smoothness` 12 (read in the reference app at rest and mid-transition on iOS 27; UIKit's platter
    /// `BackgroundProperties.glassSmoothness`). `UIGlassContainerEffect.spacing` reaches the SDF layer unchanged.
    static let platterSmoothness: CGFloat = 12.0

    /// The unit point a matched pair pulses about (`GeometryResult.transitionAnchor(containerSize:)`, SwiftUICore 27
    /// 0x1c6ea8474, stored into both pulses' settings at 0x1c6ea26d0 and 0x1c6ea33c8): per axis 0 when the partner's
    /// centre is before the container's, 1 when after, 0.5 when on it. Right platters pulse about their trailing edge.
    static func transitionAnchor(partner: CGRect, container: CGRect) -> CGPoint {
        func axis(_ value: CGFloat, _ middle: CGFloat) -> CGFloat {
            if abs(value - middle) < 0.001 {
                return 0.5
            }
            return value < middle ? 0.0 : 1.0
        }
        return CGPoint(x: axis(partner.midX, container.midX), y: axis(partner.midY, container.midY))
    }

    /// The offset the delay is computed from (`Resolver.resolvedMinOffset(result:isRemoval:)`, SwiftUICore 27
    /// 0x1c6ea85b0, called from `adjustMatchedEntry` at 0x1c6ea2c28 and read by the delay block at 0x1c6ea2e64): nil for
    /// shapes that overlap (no raw offset), else, for an entry inside a changed run of the platters' index diff (a removed
    /// or inserted platter always is), zero on removal and nil on insertion. So a platter collapsing into another waits
    /// exactly `matchedMinDelay` and one growing out of another waits for nothing. The kick takes the raw offset
    /// (read at 0x1c6ea29d4, before this), so it is unaffected.
    static func resolvedMatchedOffset(_ offset: CGSize?, isRemoval: Bool) -> CGSize? {
        guard offset != nil, isRemoval else {
            return nil
        }
        return CGSize()
    }

    static func matchedDelay(offset: CGSize, containerWidth: CGFloat) -> Double {
        let diagonal = Double(hypot(containerWidth, NavigationBarGlassSettings.platterContainerHeight))
        guard diagonal > 0.0 else {
            return NavigationBarGlassSettings.matchedMinDelay
        }
        let distance = Double(hypot(offset.width, offset.height))
        return NavigationBarGlassSettings.matchedMinDelay + min(NavigationBarGlassSettings.matchedMaxDelay, distance / diagonal * NavigationBarGlassSettings.matchedDelayFactor)
    }
}

/// How the glass moves, with or without Reduce Motion. Under Reduce Motion SwiftUI's glass appears and disappears by
/// opacity alone (no scale, no blur: `AppearanceSettings.reduceMotion`, glass RE §2.1), skips the scale pulse (§3.2)
/// and resolves the transition spring without its bounce, at the same response (§2.2).
struct NavigationBarGlassMotion {
    let reduce: Bool

    var transition: NavigationTransitionSpring {
        return self.reduce ? NavigationBarGlassSettings.materialize : NavigationBarGlassSettings.transition
    }

    var blurRadius: CGFloat {
        return self.reduce ? 0.0 : NavigationBarGlassSettings.blurRadius
    }

    func materializeScale(size: CGSize) -> CGSize {
        return self.reduce ? CGSize(width: 1.0, height: 1.0) : navigationBarGlassMaterializeScale(size: size)
    }

    /// The scale items swapped in a kept capsule shrink to and grow from.
    var matchScale: CGSize {
        return self.reduce ? CGSize(width: 1.0, height: 1.0) : CGSize(width: NavigationBarGlassSettings.matchScale, height: NavigationBarGlassSettings.matchScale)
    }

    /// The scale pulse of a capsule whose items change; none under Reduce Motion.
    func pulse(size: CGSize) -> NavigationBarGlassPulse? {
        return self.reduce ? nil : NavigationBarGlassPulse(size: size)
    }

    /// The scale pulse as curves, starting at `startTime` on a group's clock; none under Reduce Motion.
    func pulseCurve(size: CGSize, startTime: Double, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> NavigationBarGlassPulseCurve? {
        return self.reduce ? nil : NavigationBarGlassPulseCurve(size: size, startTime: startTime, anchor: anchor)
    }
}

/// SwiftUI's translation kick as the progress of one curve (1: the full kick): out on `kickOffset` from
/// `startTime + kickOffsetDelay`, then back on `kickReturn` from `startTime + kickReturnDelay`, taking over wherever the
/// first had got to.
struct NavigationBarKickCurve {
    let offset: CGSize
    let out: NavigationSpringCurve
    let back: NavigationSpringCurve

    init(offset: CGSize, startTime: Double) {
        let out = NavigationSpringCurve(startTime: startTime + NavigationBarGlassSettings.kickOffsetDelay, from: 0.0, target: 1.0, spring: NavigationBarGlassSettings.kickOffset, rest: .glass(0.001))
        self.init(offset: offset, out: out, back: out.retargeted(at: startTime + NavigationBarGlassSettings.kickReturnDelay, to: 0.0, spring: NavigationBarGlassSettings.kickReturn))
    }

    private init(offset: CGSize, out: NavigationSpringCurve, back: NavigationSpringCurve) {
        self.offset = offset
        self.out = out
        self.back = back
    }

    func progress(at time: Double) -> CGFloat {
        return time < self.back.startTime ? self.out.value(at: time) : self.back.value(at: time)
    }

    func translation(at time: Double) -> CGSize {
        let progress = self.progress(at: time)
        return CGSize(width: self.offset.width * progress, height: self.offset.height * progress)
    }

    var restTime: Double {
        return self.back.restTime
    }

    func rebased(by time: Double) -> NavigationBarKickCurve {
        return NavigationBarKickCurve(offset: self.offset, out: self.out.rebased(by: time), back: self.back.rebased(by: time))
    }
}

struct NavigationBarGlassSpring {
    var value: CGFloat
    var velocity: CGFloat = 0.0
    var target: CGFloat
    var spring: NavigationTransitionSpring = NavigationBarGlassSettings.transition
    let restThreshold: CGFloat

    init(_ value: CGFloat, restThreshold: CGFloat) {
        self.value = value
        self.target = value
        self.restThreshold = restThreshold
    }

    var isAtRest: Bool {
        return abs(self.value - self.target) < self.restThreshold && abs(self.velocity) < self.restThreshold * 10.0
    }

    mutating func set(_ value: CGFloat) {
        self.value = value
        self.target = value
        self.velocity = 0.0
    }

    mutating func animate(to target: CGFloat, spring: NavigationTransitionSpring) {
        self.target = target
        self.spring = spring
    }

    mutating func step(_ dt: CGFloat) {
        if self.isAtRest {
            self.value = self.target
            self.velocity = 0.0
            return
        }
        let state = self.spring.advance(value: self.value, velocity: self.velocity, target: self.target, time: dt)
        self.value = state.value
        self.velocity = state.velocity
    }
}

/// SwiftUI's scale pulse (`ScalePulseEffect.effectValue` 0x1c7806c10): scale = f(a) * f(b) per axis with
/// f(p) = 1/m + (m - 1/m) p; at rest one set is at 1 and the other at 0, at the peak both are at 1 and the scale
/// is m^2. Measured on iOS 27 (untouched Edit -> Done and Edit -> checkmark): both peak at 1.2 in height (44 pt ->
/// ~53 pt) whatever the final shape, so the cap applies to the peak: m^2 = min((L + 16) / L, 1.2) per axis.
struct NavigationBarGlassPulse {
    var rising = NavigationBarGlassSpring(0.0, restThreshold: 0.001)
    var fallingWidth = NavigationBarGlassSpring(1.0, restThreshold: 0.001)
    var fallingHeight = NavigationBarGlassSpring(1.0, restThreshold: 0.001)
    let m: CGSize
    var elapsed: CGFloat = 0.0
    var startedWidth = false
    var startedHeight = false

    init(size: CGSize) {
        func m(_ length: CGFloat) -> CGFloat {
            return length > 0.0 ? min((length + 16.0) / length, NavigationBarGlassSettings.pulseMaxScale).squareRoot() : 1.0
        }
        self.m = CGSize(width: m(size.width), height: m(size.height))
        self.rising.animate(to: 1.0, spring: NavigationBarGlassSettings.pulseUp)
    }

    var scale: CGSize {
        func f(_ p: CGFloat, _ m: CGFloat) -> CGFloat {
            return 1.0 / m + (m - 1.0 / m) * p
        }
        return CGSize(width: f(self.rising.value, self.m.width) * f(self.fallingWidth.value, self.m.width), height: f(self.rising.value, self.m.height) * f(self.fallingHeight.value, self.m.height))
    }

    var isDone: Bool {
        return self.startedWidth && self.startedHeight && self.rising.isAtRest && self.fallingWidth.isAtRest && self.fallingHeight.isAtRest
    }

    mutating func step(_ dt: CGFloat) {
        self.elapsed += dt
        if !self.startedHeight && self.elapsed >= NavigationBarGlassSettings.pulseDownHeightDelay {
            self.startedHeight = true
            self.fallingHeight.animate(to: 0.0, spring: NavigationBarGlassSettings.pulseDownHeight)
        }
        if !self.startedWidth && self.elapsed >= NavigationBarGlassSettings.pulseDownWidthDelay {
            self.startedWidth = true
            self.fallingWidth.animate(to: 0.0, spring: NavigationBarGlassSettings.pulseDownWidth)
        }
        self.rising.step(dt)
        self.fallingHeight.step(dt)
        self.fallingWidth.step(dt)
    }
}

/// `NavigationBarGlassPulse` as curves on a group's clock: the new set rises at `startTime`, the old set's height falls
/// `pulseDownHeightDelay` later and its width `pulseDownWidthDelay` later.
struct NavigationBarGlassPulseCurve: Equatable {
    let m: CGSize
    let rising: NavigationSpringCurve
    let fallingHeight: NavigationSpringCurve
    let fallingWidth: NavigationSpringCurve
    /// The unit point of the shape that stays put (`ScalePulse.anchor`): the centre for a shape whose items change, the
    /// matched pair's `transitionAnchor` for a matched insertion or removal.
    let anchor: CGPoint

    init(size: CGSize, startTime: Double, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        self.anchor = anchor
        func m(_ length: CGFloat) -> CGFloat {
            return length > 0.0 ? min((length + 16.0) / length, NavigationBarGlassSettings.pulseMaxScale).squareRoot() : 1.0
        }
        self.m = CGSize(width: m(size.width), height: m(size.height))
        self.rising = NavigationSpringCurve(startTime: startTime, from: 0.0, target: 1.0, spring: NavigationBarGlassSettings.pulseUp, rest: .glass(0.001))
        self.fallingHeight = NavigationSpringCurve(startTime: startTime + Double(NavigationBarGlassSettings.pulseDownHeightDelay), from: 1.0, target: 0.0, spring: NavigationBarGlassSettings.pulseDownHeight, rest: .glass(0.001))
        self.fallingWidth = NavigationSpringCurve(startTime: startTime + Double(NavigationBarGlassSettings.pulseDownWidthDelay), from: 1.0, target: 0.0, spring: NavigationBarGlassSettings.pulseDownWidth, rest: .glass(0.001))
    }

    private init(m: CGSize, rising: NavigationSpringCurve, fallingHeight: NavigationSpringCurve, fallingWidth: NavigationSpringCurve, anchor: CGPoint) {
        self.m = m
        self.anchor = anchor
        self.rising = rising
        self.fallingHeight = fallingHeight
        self.fallingWidth = fallingWidth
    }

    var restTime: Double {
        return max(self.rising.restTime, self.fallingHeight.restTime, self.fallingWidth.restTime)
    }

    func scale(at time: Double) -> CGSize {
        func f(_ p: CGFloat, _ m: CGFloat) -> CGFloat {
            return 1.0 / m + (m - 1.0 / m) * p
        }
        let rising = self.rising.value(at: time)
        return CGSize(width: f(rising, self.m.width) * f(self.fallingWidth.value(at: time), self.m.width), height: f(rising, self.m.height) * f(self.fallingHeight.value(at: time), self.m.height))
    }

    func rebased(by time: Double) -> NavigationBarGlassPulseCurve {
        return NavigationBarGlassPulseCurve(m: self.m, rising: self.rising.rebased(by: time), fallingHeight: self.fallingHeight.rebased(by: time), fallingWidth: self.fallingWidth.rebased(by: time), anchor: self.anchor)
    }
}

/// The scale a capsule materializes from: 1.2, or less so it grows by at most 16 pt per axis
/// (SwiftUICore 27 `GlassAppearanceScaleEffect` 0x1c79340bc).
func navigationBarGlassMaterializeScale(size: CGSize) -> CGSize {
    func axis(_ length: CGFloat) -> CGFloat {
        guard length > 0.0 else {
            return 1.0
        }
        return min(1.2, (length + 16.0) / length)
    }
    return CGSize(width: axis(size.width), height: axis(size.height))
}

/// The scale UIKit is drawing a capsule's press at (1 at rest): the on-screen height of the glass effect view the
/// capsule's content sits in, over the height the glass is laid out at (the effect view's superview; the capsule's own
/// height at rest, the merge's shape while the glass is lent, so the merge's own scaling is not read as a press).
/// UIKit's `_UIFlexInteraction` grows that glass around the content, by its bounds on a short tap (measured in the app,
/// 2026-10-14: every transform between the content and the capsule read 1 while the glass was 61 pt) or by a transform,
/// so the content's own size says nothing about it. Read from the presentation layers when both are there.
func navigationBarCapsulePressScale(_ container: GlassContextExtractableContainer) -> CGFloat {
    var current: UIView? = container.contentView.superview
    while let view = current, view !== container, !(view is UIVisualEffectView) {
        current = view.superview
    }
    guard let glass = current as? UIVisualEffectView else {
        return 1.0
    }
    let layout: UIView = glass.superview ?? container
    guard layout.bounds.height > 0.0 else {
        return 1.0
    }
    let glassLayer: CALayer
    let layoutLayer: CALayer
    if let glassPresentation = glass.layer.presentation(), let layoutPresentation = layout.layer.presentation() {
        glassLayer = glassPresentation
        layoutLayer = layoutPresentation
    } else {
        glassLayer = glass.layer
        layoutLayer = layout.layer
    }
    let scale = glassLayer.convert(glassLayer.bounds, to: layoutLayer).height / layout.bounds.height
    return scale.isFinite && scale > 0.0 ? scale : 1.0
}

/// UIKit's press glow on a capsule (1: full, 0: none): the opacity of the BigGlow layer `_UIFlexInteraction` puts in
/// the capsule's glass while pressed, read from the presentation layers. Nil when there is none.
func navigationBarCapsulePressGlow(_ container: GlassContextExtractableContainer) -> CGFloat? {
    func find(_ layer: CALayer) -> CALayer? {
        if let name = layer.name, name.hasSuffix(".BigGlow") {
            return layer
        }
        for sublayer in layer.sublayers ?? [] {
            if let result = find(sublayer) {
                return result
            }
        }
        return nil
    }
    guard let glow = find(container.layer) else {
        return nil
    }
    var opacity = CGFloat((glow.presentation() ?? glow).opacity)
    var current = glow.superlayer
    while let layer = current, layer !== container.layer {
        opacity *= CGFloat((layer.presentation() ?? layer).opacity)
        current = layer.superlayer
    }
    return max(0.0, min(1.0, opacity))
}

/// UIKit's press glow on a capsule it is pressing to `press`. A glow is always there with a press: when the glow layer
/// cannot be found (a UIKit change), a press alone stands for a full one. A press passes 1.03 within ~20 ms, so 1.01
/// tells it from a reading that is merely not exactly 1.
func navigationBarCapsulePressGlow(_ container: GlassContextExtractableContainer?, press: CGFloat) -> CGFloat {
    if let container, let glow = navigationBarCapsulePressGlow(container) {
        return glow
    }
    return press > 1.01 ? 1.0 : 0.0
}

/// UIKit's press on a capsule: how far it has grown the capsule's glass, and its glow.
struct NavigationBarCapsulePress {
    var scale: CGFloat
    var glow: CGFloat

    var isPressed: Bool {
        return abs(self.scale - 1.0) > 0.0005 || self.glow > 0.001
    }
}

func navigationBarCapsulePress(_ container: GlassContextExtractableContainer) -> NavigationBarCapsulePress {
    let scale = navigationBarCapsulePressScale(container)
    return NavigationBarCapsulePress(scale: scale, glow: navigationBarCapsulePressGlow(container, press: scale))
}

/// UIKit's press glow, drawn over a transition's capsule as `_UIFlexInteraction` draws it over a pressed one (measured
/// 2026-10-14, glass RE notes §6): inside a container clipped to the capsule, a white BigGlow over the whole capsule and
/// a 66 pt white LittleGlow (a shadow of radius half its size) at the touch, both under a `vibrantColorMatrix` filter
/// that transforms what lies beneath rather than painting over it. The LittleGlow spreads as it fades, to ~264 pt at
/// none. We do not know where the finger was, so it is centred.
final class NavigationBarPressGlowView: UIView {
    /// `_UIFlexInteraction.BigGlow`'s matrix, the same in light and dark: a ~16% saturation boost plus 0.05 per channel.
    /// Whether Core Animation's `vibrantColorMatrix` filter can be made (it is private).
    static let isAvailable: Bool = navigationBarVibrantColorMatrixFilter(NavigationBarPressGlowView.bigGlowMatrix) != nil

    static let bigGlowMatrix: [Float32] = [1.1575, -0.1431, -0.0144, 0.0, 0.05, -0.0425, 1.0570, -0.0145, 0.0, 0.05, -0.0426, -0.1430, 1.1856, 0.0, 0.05, 0.0, 0.0, 0.0, 1.0, 0.0]
    /// `_UIFlexInteraction.LittleGlow`'s matrices: brightness x1.667 in light, x4 in dark, with a saturation boost.
    static let littleGlowMatrixLight: [Float32] = [2.3229, -0.5962, -0.0600, 0.0, 0.0, -0.1772, 1.9040, -0.0602, 0.0, 0.0, -0.1773, -0.5958, 2.4399, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0]
    static let littleGlowMatrixDark: [Float32] = [5.5748, -1.4308, -0.1440, 0.0, 0.0, -0.4252, 4.5696, -0.1444, 0.0, 0.0, -0.4256, -1.4300, 5.8556, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0]

    private let bigGlow = UIView()
    private let littleGlow = UIView()
    private var isDark: Bool?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.bigGlow.backgroundColor = .white
        self.bigGlow.layer.filters = [navigationBarVibrantColorMatrixFilter(NavigationBarPressGlowView.bigGlowMatrix)].compactMap { $0 }
        self.addSubview(self.bigGlow)
        self.littleGlow.layer.shadowColor = UIColor.white.cgColor
        self.littleGlow.layer.shadowOpacity = 1.0
        self.littleGlow.layer.shadowOffset = CGSize()
        self.addSubview(self.littleGlow)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lays the glow out in `size` (the capsule's own, untransformed) at `glow` (1: full).
    func update(size: CGSize, glow: CGFloat, isDark: Bool) {
        if self.isDark != isDark {
            self.isDark = isDark
            self.littleGlow.layer.filters = [navigationBarVibrantColorMatrixFilter(isDark ? NavigationBarPressGlowView.littleGlowMatrixDark : NavigationBarPressGlowView.littleGlowMatrixLight)].compactMap { $0 }
        }
        let glow = max(0.0, min(1.0, glow))
        self.layer.cornerRadius = size.height * 0.5
        self.bigGlow.frame = CGRect(origin: CGPoint(), size: size)
        self.bigGlow.alpha = glow
        // A 66 pt square scaled to its size: its shadow (radius half the square) scales with it, so a transform gives
        // the same glow as a resized square, and keyframes can play it.
        self.littleGlow.transform = .identity
        self.littleGlow.bounds = CGRect(x: 0.0, y: 0.0, width: 66.0, height: 66.0)
        self.littleGlow.layer.shadowRadius = 33.0
        self.littleGlow.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0.0, y: 0.0, width: 66.0, height: 66.0)).cgPath
        self.littleGlow.center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let scale = NavigationBarPressGlowView.littleGlowScale(glow: glow)
        self.littleGlow.transform = CGAffineTransform(scaleX: scale, y: scale)
        self.littleGlow.alpha = glow
    }

    /// The LittleGlow's size over its 66 pt square: it spreads to ~264 pt as it fades.
    static func littleGlowScale(glow: CGFloat) -> CGFloat {
        return (66.0 + 198.0 * (1.0 - max(0.0, min(1.0, glow)))) / 66.0
    }

    /// Plays the glow along `glows` at `sizes` (the capsule's own, per sample) on the render server: the BigGlow's
    /// opacity, and the LittleGlow growing as it fades, as a scale of its 66 pt square (its shadow scales with it).
    func animate(sizes: [CGSize], glows: [CGFloat], timing: NavigationKeyframeTiming, isDark: Bool) {
        guard let lastSize = sizes.last, let lastGlow = glows.last else {
            return
        }
        self.update(size: lastSize, glow: lastGlow, isDark: isDark)
        let prefix = "navigationGlass."
        let bounds = sizes.map { NSValue(cgRect: CGRect(origin: CGPoint(), size: $0)) }
        let centers = sizes.map { NSValue(cgPoint: CGPoint(x: $0.width * 0.5, y: $0.height * 0.5)) }
        let opacities = glows.map { NSNumber(value: Float(max(0.0, min(1.0, $0)))) }
        addNavigationKeyframes(to: self.layer, key: prefix + "bounds", keyPath: "bounds", values: bounds, timing: timing)
        addNavigationKeyframes(to: self.layer, key: prefix + "position", keyPath: "position", values: centers, timing: timing)
        addNavigationKeyframes(to: self.layer, key: prefix + "cornerRadius", keyPath: "cornerRadius", values: sizes.map { NSNumber(value: Float($0.height * 0.5)) }, timing: timing)
        addNavigationKeyframes(to: self.bigGlow.layer, key: prefix + "bounds", keyPath: "bounds", values: bounds, timing: timing)
        addNavigationKeyframes(to: self.bigGlow.layer, key: prefix + "position", keyPath: "position", values: centers, timing: timing)
        addNavigationKeyframes(to: self.bigGlow.layer, key: prefix + "opacity", keyPath: "opacity", values: opacities, timing: timing)
        addNavigationKeyframes(to: self.littleGlow.layer, key: prefix + "position", keyPath: "position", values: centers, timing: timing)
        addNavigationKeyframes(to: self.littleGlow.layer, key: prefix + "transform", keyPath: "transform", values: glows.map { glow -> NSValue in
            let scale = NavigationBarPressGlowView.littleGlowScale(glow: glow)
            return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1.0))
        }, timing: timing)
        addNavigationKeyframes(to: self.littleGlow.layer, key: prefix + "opacity", keyPath: "opacity", values: opacities, timing: timing)
    }
}

/// Core Animation's `vibrantColorMatrix` filter with `matrix` (4x5, row-major), as UIKit's press glow uses it.
private func navigationBarVibrantColorMatrixFilter(_ matrix: [Float32]) -> NSObject? {
    guard let filterClass = NSClassFromString("CAFilter") as AnyObject as? NSObjectProtocol else {
        return nil
    }
    guard let filter = filterClass.perform(NSSelectorFromString("filterWithName:"), with: "vibrantColorMatrix")?.takeUnretainedValue() as? NSObject else {
        return nil
    }
    var values = matrix
    filter.setValue(NSValue(bytes: &values, objCType: "{CAColorMatrix=ffffffffffffffffffff}"), forKey: "inputColorMatrix")
    return filter
}

/// The partner SwiftUI's resolver gives a matched insertion or removal (`sourceElement(target:otherElements:config:context:)`,
/// SwiftUICore 27 0x1c6ea55d8, the best `Entry.geometryResult(to:context:)`: the distance between the glass shapes): the
/// candidate nearest `frame`, by the gap between the two shapes, then by their centres. Nil without candidates.
func navigationBarNearestPartner(of frame: CGRect, among candidates: [CGRect]) -> Int? {
    func gap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = max(0.0, max(a.minX - b.maxX, b.minX - a.maxX))
        let dy = max(0.0, max(a.minY - b.maxY, b.minY - a.maxY))
        return (dx * dx + dy * dy).squareRoot()
    }
    func centres(_ a: CGRect, _ b: CGRect) -> CGFloat {
        return hypot(a.midX - b.midX, a.midY - b.midY)
    }
    return candidates.indices.min(by: { lhs, rhs in
        return (gap(frame, candidates[lhs]), centres(frame, candidates[lhs])) < (gap(frame, candidates[rhs]), centres(frame, candidates[rhs]))
    })
}

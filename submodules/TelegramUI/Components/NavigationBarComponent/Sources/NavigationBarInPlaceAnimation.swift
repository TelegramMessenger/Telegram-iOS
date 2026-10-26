import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

/// A glass container of the bar's row: the left capsule, or a right pill by index from the edge (0: the outermost).
enum NavigationBarCapsuleSlot: Hashable {
    case left
    case right(Int)
}

/// A bar capsule animating an in-place change of its items (Edit <-> Done, the back button giving way to edit mode) as
/// iOS 27's toolbar glass does (docs/superpowers/specs/2026-10-13-native-navigation-glass-platters-ios27-re.md): the
/// shape springs to its new frame and pulses, the old items dematerialize where they were while the new ones
/// materialize where they will be, and a tint change cross-fades. It runs on the bar's real capsule, so a press UIKit
/// is drawing on the glass carries on through the change and the new items take taps at once.
final class NavigationBarInPlaceCapsule {
    final class Items {
        let view: UIView
        /// Where the items are at rest, in the bar's coordinates: they stay there while the shape moves around them.
        var frame: CGRect
        /// 0: present; 1: dematerialized (transparent, blurred, scaled up by `maxScale`).
        var appearance: NavigationBarGlassSpring
        var maxScale: CGSize
        let blurRadius: CGFloat

        init(view: UIView, frame: CGRect, appearance: CGFloat, motion: NavigationBarGlassMotion) {
            self.view = view
            self.frame = frame
            self.appearance = NavigationBarGlassSpring(appearance, restThreshold: 0.001)
            self.maxScale = motion.materializeScale(size: frame.size)
            self.blurRadius = motion.blurRadius
        }
    }

    let slot: NavigationBarCapsuleSlot
    let container: GlassContextExtractableContainer
    var x: NavigationBarGlassSpring
    var y: NavigationBarGlassSpring
    var width: NavigationBarGlassSpring
    var height: NavigationBarGlassSpring
    private(set) var targetFrame: CGRect
    var pulse: NavigationBarGlassPulse?
    /// 0: present; 1: dematerialized, scaled up by `maxScale`. The glass itself appears and disappears through
    /// `isVisible` (UIKit's own materialization): alpha does not hide native glass.
    var dematerialization = NavigationBarGlassSpring(0.0, restThreshold: 0.001)
    var maxScale = CGSize(width: 1.0, height: 1.0)
    /// The bar's live items (its `leftButtonsContainer` or a right pill's `itemsContainer`); nil while the capsule leaves.
    var items: Items?
    var leaving: [Items] = []
    var isRemoved = false
    var tintColor: GlassBackgroundView.TintColor
    var isDark: Bool

    /// A matched removal or insertion (spec, animation): the shape follows curves on the in-place clock, collapsing
    /// into, or growing out of, its partner.
    final class Matched {
        var x: NavigationSpringCurve
        var y: NavigationSpringCurve
        var width: NavigationSpringCurve
        var height: NavigationSpringCurve
        var dematerialization: NavigationSpringCurve
        var kick: NavigationBarKickCurve?
        let isRemoval: Bool
        /// Where it is heading: its partner's frame for a removal, its own for an insertion.
        var target: CGRect
        /// The pill its items are laid out in, which it carries as it moves: the one it leaves, or the one it becomes.
        var itemsPill: CGRect
        /// The partner's glass container.
        weak var partner: GlassContextExtractableContainer?

        init(source: CGRect, target: CGRect, start: Double, spring: NavigationTransitionSpring, dematerializationFrom: CGFloat, isRemoval: Bool, kick: NavigationBarKickCurve?, partner: GlassContextExtractableContainer) {
            func curve(_ from: CGFloat, _ to: CGFloat, _ rest: NavigationSpringRest) -> NavigationSpringCurve {
                return NavigationSpringCurve(startTime: start, from: from, target: to, spring: spring, rest: rest)
            }
            self.x = curve(source.minX, target.minX, .glass(0.01))
            self.y = curve(source.minY, target.minY, .glass(0.01))
            self.width = curve(source.width, target.width, .glass(0.01))
            self.height = curve(source.height, target.height, .glass(0.01))
            self.dematerialization = curve(dematerializationFrom, isRemoval ? 1.0 : 0.0, .glass(0.001))
            self.kick = kick
            self.isRemoval = isRemoval
            self.target = target
            self.itemsPill = isRemoval ? source : target
            self.partner = partner
        }

        func frame(at time: Double) -> CGRect {
            let kick = self.kick?.translation(at: time) ?? CGSize()
            return CGRect(x: self.x.value(at: time) + kick.width, y: self.y.value(at: time) + kick.height, width: max(0.0, self.width.value(at: time)), height: max(0.0, self.height.value(at: time)))
        }

        /// Heads for `frame` from where it is now: an insertion's new place, or a removal's partner moved by a relayout
        /// (a removal keeps the items in the pill it leaves).
        func retarget(to frame: CGRect, at time: Double, spring: NavigationTransitionSpring) {
            self.x = self.x.retargeted(at: time, to: frame.minX, spring: spring)
            self.y = self.y.retargeted(at: time, to: frame.minY, spring: spring)
            self.width = self.width.retargeted(at: time, to: frame.width, spring: spring)
            self.height = self.height.retargeted(at: time, to: frame.height, spring: spring)
            self.target = frame
            if !self.isRemoval {
                self.itemsPill = frame
            }
        }

        func isAtRest(at time: Double) -> Bool {
            let rest = max(self.x.restTime, self.y.restTime, self.width.restTime, self.height.restTime, self.dematerialization.restTime, self.kick?.restTime ?? 0.0)
            return time >= rest
        }
    }

    var matched: Matched?
    /// SwiftUI's pulse of a matched pair, about the pair's anchor (on the in-place clock); while it runs it replaces
    /// `pulse`.
    var anchoredPulse: NavigationBarGlassPulseCurve?
    /// A press UIKit was drawing when this capsule's glass was lent, continued (nil: none).
    var press: NavigationSpringCurve?
    /// The glass view lent to the bar's merging container, while this capsule merges.
    var lentGlass: UIView?
    /// Whether its items move with the shape, centred in it (a partner that only moves, its items unchanged), rather than
    /// staying where they rest while the shape morphs around them (an item change).
    var itemsTravelWithShape = false
    /// Its tint's change from `from` toward `tintColor` (0 to 1 on the in-place clock), when the bar cross-fades it frame
    /// by frame (`glassTint(at:)`); nil when UIKit animates it. The bar does where glass merges: UIKit's animated change of
    /// an effect draws a dark band where two merging shapes meet, and goes on doing so when an effect is set over it
    /// (both probed on iOS 27); an effect set every frame does not. It runs on the shapes' transition spring, as native's
    /// does (`startInPlaceTintFade`).
    var tintFade: (from: GlassBackgroundView.TintColor, fraction: NavigationSpringCurve)?

    /// The tint the glass shows at `time` while the bar draws its cross-fade.
    func glassTint(at time: Double) -> GlassBackgroundView.TintColor {
        guard let tintFade = self.tintFade, time < tintFade.fraction.restTime else {
            return self.tintColor
        }
        return GlassBackgroundView.TintColor.blended(from: tintFade.from, to: self.tintColor, fraction: tintFade.fraction.value(at: time), isDark: self.isDark)
    }

    init(slot: NavigationBarCapsuleSlot, container: GlassContextExtractableContainer, frame: CGRect, tintColor: GlassBackgroundView.TintColor, isDark: Bool) {
        self.slot = slot
        self.container = container
        self.x = NavigationBarGlassSpring(frame.minX, restThreshold: 0.01)
        self.y = NavigationBarGlassSpring(frame.minY, restThreshold: 0.01)
        self.width = NavigationBarGlassSpring(frame.width, restThreshold: 0.01)
        self.height = NavigationBarGlassSpring(frame.height, restThreshold: 0.01)
        self.targetFrame = frame
        self.tintColor = tintColor
        self.isDark = isDark
    }

    /// The frame its springs have reached.
    var springFrame: CGRect {
        return CGRect(x: self.x.value, y: self.y.value, width: max(0.0, self.width.value), height: max(0.0, self.height.value))
    }

    /// Where the shape is at in-place time `time`: on its matched curves while it merges, else on its springs.
    func frame(at time: Double) -> CGRect {
        return self.matched?.frame(at: time) ?? self.springFrame
    }

    func animateFrame(to frame: CGRect, spring: NavigationTransitionSpring) {
        self.targetFrame = frame
        self.x.animate(to: frame.minX, spring: spring)
        self.y.animate(to: frame.minY, spring: spring)
        self.width.animate(to: frame.width, spring: spring)
        self.height.animate(to: frame.height, spring: spring)
    }

    func setFrame(_ frame: CGRect) {
        self.targetFrame = frame
        self.x.set(frame.minX)
        self.y.set(frame.minY)
        self.width.set(frame.width)
        self.height.set(frame.height)
    }

    func step(_ dt: CGFloat) {
        self.x.step(dt)
        self.y.step(dt)
        self.width.step(dt)
        self.height.step(dt)
        self.dematerialization.step(dt)
        if self.pulse != nil {
            self.pulse?.step(dt)
            if self.pulse?.isDone == true {
                self.pulse = nil
            }
        }
        self.items?.appearance.step(dt)
        for items in self.leaving {
            items.appearance.step(dt)
        }
        for items in self.leaving where items.appearance.isAtRest {
            items.view.removeFromSuperview()
        }
        self.leaving.removeAll(where: { $0.appearance.isAtRest })
    }

    func isAtRest(at time: Double) -> Bool {
        if !(self.x.isAtRest && self.y.isAtRest && self.width.isAtRest && self.height.isAtRest && self.dematerialization.isAtRest && self.pulse == nil && (self.items?.appearance.isAtRest ?? true) && self.leaving.isEmpty) {
            return false
        }
        if let matched = self.matched, !matched.isAtRest(at: time) {
            return false
        }
        if let anchoredPulse = self.anchoredPulse, time < anchoredPulse.restTime {
            return false
        }
        if let press = self.press, time < press.restTime {
            return false
        }
        if let tintFade = self.tintFade, time < tintFade.fraction.restTime {
            return false
        }
        return true
    }
}

extension NavigationBarGlassSettings {
    /// An in-place tint change UIKit animates (a pill that merges with none). Measured against iOS 27 (a pressed Edit ->
    /// checkmark, both filmed): the native capsule is fully tinted ~0.13 s after the change starts; UIKit starts drawing
    /// our change ~30 ms late, and a 0.3 s response (the navigation transition's frame-driven cross-fade) took ~0.25 s.
    /// Pills that merge fade by hand on the transition spring instead (`startInPlaceTintFade`).
    static let inPlaceTint = NavigationTransitionSpring(dampingRatio: 1.0, response: 0.1)

    /// UIKit animates a glass's tint and its appearing and disappearing itself, on the curve of the animation block it
    /// is changed in. This Bezier follows a critically damped spring to within 3% when the block lasts 1.469 times the
    /// spring's response (where the spring is 99.9% of the way there).
    static func uikitTransition(for spring: NavigationTransitionSpring) -> ComponentTransition {
        return ComponentTransition(animation: .curve(duration: Double(spring.response) * 1.469, curve: .custom(0.3, 0.6, 0.1, 1.0)))
    }
}

/// Whether a capsule's items changed in a way that animates in place: other items, or the same items showing something
/// else. An enabled state is not an item change (the capsule keeps its items and retints), and a custom content keeps
/// its own state (the chat list's proxy status).
func navigationBarCapsuleItemsDiffer(_ lhs: [NavigationBarComponent.Button], _ rhs: [NavigationBarComponent.Button]) -> Bool {
    if lhs.count != rhs.count {
        return true
    }
    for (l, r) in zip(lhs, rhs) {
        if l.id != r.id {
            return true
        }
        switch (l.content, r.content) {
        case (.custom, .custom):
            break
        default:
            if l.content != r.content {
                return true
            }
        }
    }
    return false
}

/// Places `view` at `frame` (in its superview's coordinates), scaled by `scale` about the frame's center, whatever the
/// view's anchor point.
private func setInPlaceFrame(_ view: UIView, frame: CGRect, scale: CGSize) {
    let anchor = view.layer.anchorPoint
    view.bounds = CGRect(origin: CGPoint(), size: frame.size)
    view.layer.position = CGPoint(x: frame.minX + anchor.x * frame.width, y: frame.minY + anchor.y * frame.height)
    let center = CGPoint(x: (0.5 - anchor.x) * frame.width, y: (0.5 - anchor.y) * frame.height)
    view.transform = CGAffineTransform(a: scale.width, b: 0.0, c: 0.0, d: scale.height, tx: (1.0 - scale.width) * center.x, ty: (1.0 - scale.height) * center.y)
}

extension NavigationBarComponent.View {
    var inPlaceMotion: NavigationBarGlassMotion {
        return NavigationBarGlassMotion(reduce: self.inPlaceReduceMotion())
    }

    /// The glass container of `slot`, if the bar has one now.
    func inPlaceContainer(_ slot: NavigationBarCapsuleSlot) -> GlassContextExtractableContainer? {
        switch slot {
        case .left:
            return self.leftButtonsBackgroundContainer
        case let .right(index):
            return self.rightPillBackgroundContainer(at: index)
        }
    }

    /// The bar's items view `slot`'s glass holds.
    func inPlaceItemsView(_ slot: NavigationBarCapsuleSlot) -> UIView {
        switch slot {
        case .left:
            return self.leftButtonsContainer
        case let .right(index):
            return self.rightPill(at: index).itemsContainer
        }
    }

    func inPlaceCapsule(for container: GlassContextExtractableContainer) -> NavigationBarInPlaceCapsule? {
        return self.inPlaceCapsules.first(where: { $0.container === container })
    }

    /// Where a capsule is now: its in-place spring frame, or the frame Core Animation is drawing it at.
    private func currentFrame(of container: GlassContextExtractableContainer) -> CGRect {
        if let capsule = self.inPlaceCapsule(for: container) {
            return capsule.frame(at: self.inPlaceTime)
        }
        let layer = container.layer.presentation() ?? container.layer
        return CGRect(x: layer.position.x - layer.bounds.width * 0.5, y: layer.position.y - layer.bounds.height * 0.5, width: layer.bounds.width, height: layer.bounds.height)
    }

    /// What a side shows now, its own views handed over by the content view (never a snapshot, which freezes what
    /// animates), at its resting frame: what leaves when the side's items change in place. Call before the content view
    /// takes the new items.
    func inPlaceLeavingItems(slot: NavigationBarCapsuleSlot) -> NavigationBarInPlaceCapsule.Items? {
        guard let container = self.inPlaceContainer(slot), let contentView = self.primaryContentView else {
            return nil
        }
        let source: UIView
        switch slot {
        case .left:
            source = contentView.leftButtonsContainer
        case let .right(index):
            source = contentView.rightPillContainer(at: index)
        }
        let view = contentView.extractItems(of: source)
        let capsule = self.inPlaceCapsule(for: container)
        let capsuleFrame = capsule?.targetFrame ?? container.frame
        // Items still materializing leave from where they got to.
        let appearance = capsule?.items?.appearance.value ?? 0.0
        return NavigationBarInPlaceCapsule.Items(view: view, frame: CGRect(origin: CGPoint(x: capsuleFrame.minX + source.frame.minX, y: capsuleFrame.minY + source.frame.minY), size: source.bounds.size), appearance: appearance, motion: self.inPlaceMotion)
    }

    /// A glass UIKit is pressing comes up white when its effect changes (a tapped Edit -> Done on a one-pill bar left
    /// Done white with a blue edge, seen on iOS 27), so before `capsule` is retinted to `tintColor` a pressed glass gets
    /// a new effect view and the press's scale goes on as the bar's own spring. A layout where pills merge has renewed
    /// its pressed pills already (`inPlaceTintByHand`).
    private func renewPressedGlassBeforeRetint(_ capsule: NavigationBarInPlaceCapsule, to tintColor: GlassBackgroundView.TintColor) {
        guard !self.inPlaceTintByHand, self.glassMergesShapes(), let current = capsule.container.glassTintColor, current != tintColor else {
            return
        }
        let id = ObjectIdentifier(capsule.container)
        let press = self.inPlacePressAtChange[id] ?? self.inPlacePressReader(capsule.container)
        guard press.isPressed else {
            return
        }
        capsule.container.renewGlass()
        if abs(press.scale - 1.0) > 0.0005 {
            let running = capsule.press?.value(at: self.inPlaceTime) ?? 1.0
            capsule.press = NavigationSpringCurve(startTime: self.inPlaceTime, from: running * press.scale, target: 1.0, spring: NavigationBarGlassSettings.pressRelease, rest: .glass(0.0005))
        }
        self.inPlacePressAtChange[id] = NavigationBarCapsulePress(scale: 1.0, glow: 0.0)
    }

    /// Starts the bar's own cross-fade of `capsule`'s tint to `tintColor`, from what its glass shows now (`tintFade`), on
    /// the transition spring the shapes move on: native's merging pills fade so (measured 2026-10-16 at fixed points of
    /// four reference-app films, Edit <-> Done with and without a tap: white <-> accent in ~0.25 s; the transition spring
    /// fits all four within 0.012, the best free fit, response 0.404 and damping 0.75, within 0.010). Its overshoot past
    /// the new tint reads as the new tint (`TintColor.blended`).
    private func startInPlaceTintFade(_ capsule: NavigationBarInPlaceCapsule, to tintColor: GlassBackgroundView.TintColor) {
        let from = capsule.container.glassTintColor ?? tintColor
        capsule.tintFade = nil
        if from != tintColor {
            capsule.tintFade = (from, NavigationSpringCurve(startTime: self.inPlaceTime, from: 0.0, target: 1.0, spring: self.inPlaceMotion.transition, rest: .glass(0.001)))
        }
    }

    /// A capsule whose items changed (or that the change creates) animates to `frame`: an existing one morphs and
    /// pulses with its old items dematerializing, a new one materializes; the new items materialize either way.
    func startInPlaceChange(container: GlassContextExtractableContainer, slot: NavigationBarCapsuleSlot, isNew: Bool, frame: CGRect, tintColor: GlassBackgroundView.TintColor, isDark: Bool, leaving: NavigationBarInPlaceCapsule.Items?) {
        let itemsView = self.inPlaceItemsView(slot)
        let motion = self.inPlaceMotion
        let capsule: NavigationBarInPlaceCapsule
        if let current = self.inPlaceCapsule(for: container) {
            capsule = current
            if capsule.matched != nil {
                // A pill still growing out of its partner whose items change: its springs take over where it is.
                let now = capsule.frame(at: self.inPlaceTime)
                capsule.matched = nil
                capsule.setFrame(now)
            }
        } else {
            capsule = NavigationBarInPlaceCapsule(slot: slot, container: container, frame: isNew ? frame : self.currentFrame(of: container), tintColor: tintColor, isDark: isDark)
            self.inPlaceCapsules.append(capsule)
            // The springs own the frame from here on.
            container.layer.removeAllAnimations()
        }
        capsule.isDark = isDark
        capsule.itemsTravelWithShape = false
        if isNew {
            self.inPlaceCapsuleAppeared = true
            capsule.setFrame(frame)
            capsule.maxScale = motion.materializeScale(size: frame.size)
            capsule.dematerialization.set(1.0)
            capsule.dematerialization.animate(to: 0.0, spring: NavigationBarGlassSettings.materialize)
        } else {
            capsule.animateFrame(to: frame, spring: motion.transition)
            // The pulse multiplies with any press still on the capsule (UIKit's, or the bar's continuation of it when a
            // retint renewed the glass), as on iOS 27. Native's change starts
            // ~0.08 s after its items change, so after a tap its pulse peaks in the press release's undershoot (Edit ->
            // Done: 49 pt); ours starts at once and peaks over the press (62 pt). Kept so by decision (2026-10-14).
            capsule.pulse = motion.pulse(size: frame.size)
        }

        if let leaving {
            if itemsView.superview === container.contentView {
                container.contentView.insertSubview(leaving.view, belowSubview: itemsView)
            } else {
                container.contentView.addSubview(leaving.view)
            }
            leaving.appearance.animate(to: 1.0, spring: NavigationBarGlassSettings.materialize)
            capsule.leaving.append(leaving)
        }
        itemsView.layer.removeAllAnimations()
        let items = NavigationBarInPlaceCapsule.Items(view: itemsView, frame: frame, appearance: 1.0, motion: motion)
        items.appearance.animate(to: 0.0, spring: NavigationBarGlassSettings.materialize)
        capsule.items = items

        // The glass's tint (a cross-fade) and, for a new capsule, its appearing are UIKit's to animate, except the tint in
        // a layout where pills merge (`tintFade`).
        let tintByHand = (self.inPlaceTintByHand || capsule.lentGlass != nil) && !isNew
        if !isNew {
            self.renewPressedGlassBeforeRetint(capsule, to: tintColor)
        }
        if tintByHand {
            self.startInPlaceTintFade(capsule, to: tintColor)
        } else {
            capsule.tintFade = nil
        }
        capsule.tintColor = tintColor
        let glassTransition = tintByHand ? .immediate : NavigationBarGlassSettings.uikitTransition(for: isNew ? NavigationBarGlassSettings.materialize : NavigationBarGlassSettings.inPlaceTint)
        let currentFrame = capsule.frame(at: self.inPlaceTime)
        container.update(size: currentFrame.size, cornerRadius: currentFrame.height * 0.5, isDark: isDark, tintColor: capsule.glassTint(at: self.inPlaceTime), isInteractive: true, isVisible: true, transition: glassTransition)

        self.applyInPlace(capsule)
        self.startInPlaceLinkIfNeeded()
    }

    /// A capsule the change removes dematerializes where it is, with its items, then leaves.
    func startInPlaceRemoval(container: GlassContextExtractableContainer, slot: NavigationBarCapsuleSlot, tintColor: GlassBackgroundView.TintColor, isDark: Bool, leaving: NavigationBarInPlaceCapsule.Items?) {
        let capsule: NavigationBarInPlaceCapsule
        if let current = self.inPlaceCapsule(for: container) {
            capsule = current
            if capsule.matched != nil {
                let now = capsule.frame(at: self.inPlaceTime)
                capsule.matched = nil
                capsule.setFrame(now)
            }
        } else {
            capsule = NavigationBarInPlaceCapsule(slot: slot, container: container, frame: self.currentFrame(of: container), tintColor: tintColor, isDark: isDark)
            self.inPlaceCapsules.append(capsule)
            container.layer.removeAllAnimations()
        }
        capsule.isRemoved = true
        container.isUserInteractionEnabled = false
        if let items = capsule.items {
            // The live items go on to the side's next capsule, if any; what they showed leaves as `leaving`.
            capsule.items = nil
            Self.resetInPlaceItems(items.view, size: items.frame.size)
        }
        if let leaving {
            let itemsView = self.inPlaceItemsView(slot)
            if itemsView.superview === container.contentView {
                container.contentView.insertSubview(leaving.view, belowSubview: itemsView)
            } else {
                container.contentView.addSubview(leaving.view)
            }
            leaving.appearance.animate(to: 1.0, spring: NavigationBarGlassSettings.materialize)
            capsule.leaving.append(leaving)
        }
        capsule.maxScale = self.inPlaceMotion.materializeScale(size: capsule.targetFrame.size)
        capsule.dematerialization.animate(to: 1.0, spring: NavigationBarGlassSettings.materialize)
        let currentFrame = capsule.frame(at: self.inPlaceTime)
        container.update(size: currentFrame.size, cornerRadius: currentFrame.height * 0.5, isDark: capsule.isDark, tintColor: capsule.tintColor, isInteractive: true, isVisible: false, transition: NavigationBarGlassSettings.uikitTransition(for: NavigationBarGlassSettings.materialize))

        self.applyInPlace(capsule)
        self.startInPlaceLinkIfNeeded()
    }

    /// A layout while a capsule animates in place: it heads for `frame` instead of being placed there.
    func retargetInPlace(_ capsule: NavigationBarInPlaceCapsule, frame: CGRect, tintColor: GlassBackgroundView.TintColor, isDark: Bool, transition: ComponentTransition) {
        if frame != capsule.targetFrame {
            if let matched = capsule.matched, !matched.isRemoval {
                // Growing out of its partner: it heads for its new place from where it is.
                matched.retarget(to: frame, at: self.inPlaceTime, spring: self.inPlaceMotion.transition)
                capsule.setFrame(frame)
            } else if transition.animation.isImmediate {
                capsule.setFrame(frame)
            } else {
                capsule.animateFrame(to: frame, spring: self.inPlaceMotion.transition)
            }
            capsule.items?.frame = frame
        }
        if tintColor != capsule.tintColor || isDark != capsule.isDark {
            self.renewPressedGlassBeforeRetint(capsule, to: tintColor)
            let tintByHand = !transition.animation.isImmediate && (self.inPlaceTintByHand || capsule.lentGlass != nil)
            if tintByHand {
                self.startInPlaceTintFade(capsule, to: tintColor)
            } else {
                capsule.tintFade = nil
            }
            capsule.tintColor = tintColor
            capsule.isDark = isDark
            let currentFrame = capsule.frame(at: self.inPlaceTime)
            capsule.container.update(size: currentFrame.size, cornerRadius: currentFrame.height * 0.5, isDark: isDark, tintColor: capsule.glassTint(at: self.inPlaceTime), isInteractive: true, isVisible: !capsule.isRemoved, transition: (transition.animation.isImmediate || tintByHand) ? .immediate : NavigationBarGlassSettings.uikitTransition(for: NavigationBarGlassSettings.inPlaceTint))
        }
        self.applyInPlace(capsule)
    }

    /// A pill that goes collapses into `partner`'s pill, or one that comes grows out of it (SwiftUI's matched removal and
    /// insertion, `Resolver.adjustMatchedEntry`, spec): after the resolved delay (`minDelay` for a removal, none for an
    /// insertion) the shape springs between its frame and the partner's on the transition spring with the kick, its
    /// items leaving into, or appearing from, the `.match` appearance; both pills pulse about the pair's anchor; the
    /// moving pill takes the partner's tint on the way (measured: the Administrators film); with native glass both glass
    /// views are lent to one container at smoothness 12 so the shapes merge. `source` is where an insertion starts when
    /// it is not the partner's frame (a pill that was leaving and comes back). `partnerMove` is where the partner is and
    /// where this layout puts it: a partner with no change of its own springs between them, its items with it.
    func startInPlaceMatched(container: GlassContextExtractableContainer, slot: NavigationBarCapsuleSlot, isRemoval: Bool, frame: CGRect, source insertionSource: CGRect? = nil, partner: GlassContextExtractableContainer, partnerFrame: CGRect, partnerMove: (from: CGRect, to: CGRect), partnerTintColor: GlassBackgroundView.TintColor, tintColor: GlassBackgroundView.TintColor, isDark: Bool, leaving: NavigationBarInPlaceCapsule.Items?) {
        let motion = self.inPlaceMotion
        let time = self.inPlaceTime
        if !isRemoval {
            self.inPlaceCapsuleAppeared = true
        }
        let capsule: NavigationBarInPlaceCapsule
        if let current = self.inPlaceCapsule(for: container) {
            capsule = current
        } else {
            capsule = NavigationBarInPlaceCapsule(slot: slot, container: container, frame: isRemoval ? self.currentFrame(of: container) : (insertionSource ?? partnerFrame), tintColor: tintColor, isDark: isDark)
            self.inPlaceCapsules.append(capsule)
            container.layer.removeAllAnimations()
        }
        let source = isRemoval ? capsule.frame(at: time) : (insertionSource ?? partnerFrame)
        let target = isRemoval ? partnerFrame : frame
        let own = isRemoval ? source : target
        let delta = CGSize(width: own.midX - partnerFrame.midX, height: own.midY - partnerFrame.midY)
        let disjoint = !source.intersects(target)
        let resolved = NavigationBarGlassSettings.resolvedMatchedOffset(disjoint ? delta : nil, isRemoval: isRemoval)
        let start = time + (resolved.map { NavigationBarGlassSettings.matchedDelay(offset: $0, containerWidth: self.bounds.width) } ?? 0.0)
        let kick = disjoint ? NavigationBarKickCurve(offset: CGSize(width: delta.width / NavigationBarGlassSettings.kickFactor, height: delta.height / NavigationBarGlassSettings.kickFactor), startTime: start) : nil
        let fromDematerialization: CGFloat = capsule.matched?.dematerialization.value(at: time) ?? (isRemoval ? capsule.dematerialization.value : 1.0)
        capsule.matched = NavigationBarInPlaceCapsule.Matched(source: source, target: target, start: start, spring: motion.transition, dematerializationFrom: fromDematerialization, isRemoval: isRemoval, kick: kick, partner: partner)
        capsule.setFrame(target)
        capsule.dematerialization.set(0.0)
        capsule.pulse = nil
        capsule.maxScale = motion.matchScale
        capsule.isRemoved = isRemoval
        capsule.isDark = isDark
        container.isUserInteractionEnabled = !isRemoval

        // Items: the leaving ones go into the partner (`.match`), the new ones appear from it.
        if isRemoval {
            if let items = capsule.items {
                capsule.items = nil
                Self.resetInPlaceItems(items.view, size: items.frame.size)
            }
            if let leaving {
                container.contentView.addSubview(leaving.view)
                leaving.maxScale = motion.matchScale
                leaving.appearance.animate(to: 1.0, spring: motion.transition)
                capsule.leaving.append(leaving)
            }
        } else {
            let itemsView = self.inPlaceItemsView(slot)
            itemsView.layer.removeAllAnimations()
            let items = NavigationBarInPlaceCapsule.Items(view: itemsView, frame: frame, appearance: capsule.items?.appearance.value ?? 1.0, motion: motion)
            items.maxScale = motion.matchScale
            items.appearance.animate(to: 0.0, spring: motion.transition)
            capsule.items = items
        }

        // Both pulse about the pair's anchor: the partner now, the moving pill when it starts moving.
        let anchor = NavigationBarGlassSettings.transitionAnchor(partner: partnerFrame, container: self.bounds)
        let partnerCapsule = self.inPlaceCapsuleCreatingIfNeeded(for: partner, from: partnerMove.from, to: partnerMove.to, tintColor: partnerTintColor, isDark: isDark)
        partnerCapsule.pulse = nil
        partnerCapsule.anchoredPulse = motion.pulseCurve(size: partnerFrame.size, startTime: time, anchor: anchor)
        capsule.anchoredPulse = motion.pulseCurve(size: own.size, startTime: start, anchor: anchor)

        // The moving pill's tint: into the partner's as it goes, from the partner's to its own as it comes.
        let merges = self.glassMergesShapes()
        if merges {
            self.lendInPlaceGlass(partnerCapsule)
            self.lendInPlaceGlass(capsule)
        }
        // Merging, the bar cross-fades the tint (`tintFade`); otherwise UIKit fades the glass out.
        let current = capsule.frame(at: time)
        if isRemoval {
            if merges {
                self.startInPlaceTintFade(capsule, to: partnerTintColor)
            } else {
                capsule.tintFade = nil
            }
            capsule.tintColor = partnerTintColor
            container.update(size: current.size, cornerRadius: current.height * 0.5, isDark: isDark, tintColor: capsule.glassTint(at: time), isInteractive: true, isVisible: merges, transition: merges ? .immediate : NavigationBarGlassSettings.uikitTransition(for: NavigationBarGlassSettings.materialize))
        } else {
            if insertionSource == nil {
                // A new pill starts as part of its partner: in the partner's tint, its glass already there when merging.
                container.update(size: current.size, cornerRadius: current.height * 0.5, isDark: isDark, tintColor: partnerTintColor, isInteractive: true, isVisible: merges, transition: .immediate)
            }
            if merges {
                self.startInPlaceTintFade(capsule, to: tintColor)
            } else {
                capsule.tintFade = nil
            }
            capsule.tintColor = tintColor
            container.update(size: current.size, cornerRadius: current.height * 0.5, isDark: isDark, tintColor: capsule.glassTint(at: time), isInteractive: true, isVisible: true, transition: merges ? .immediate : NavigationBarGlassSettings.uikitTransition(for: NavigationBarGlassSettings.materialize))
        }
        self.applyInPlace(capsule)
        self.applyInPlace(partnerCapsule)
        self.startInPlaceLinkIfNeeded()
    }

    /// `container`'s in-place capsule when it has none: made at `frame`, where it is, heading for `target` (its frame in
    /// this layout) on the transition spring with its items.
    func inPlaceCapsuleCreatingIfNeeded(for container: GlassContextExtractableContainer, from frame: CGRect, to target: CGRect, tintColor: GlassBackgroundView.TintColor, isDark: Bool) -> NavigationBarInPlaceCapsule {
        if let current = self.inPlaceCapsule(for: container) {
            return current
        }
        let slot: NavigationBarCapsuleSlot = self.rightPills.firstIndex(where: { $0.background === container }).map { .right($0) } ?? .left
        let capsule = NavigationBarInPlaceCapsule(slot: slot, container: container, frame: frame, tintColor: tintColor, isDark: isDark)
        capsule.items = NavigationBarInPlaceCapsule.Items(view: self.inPlaceItemsView(slot), frame: target, appearance: 0.0, motion: self.inPlaceMotion)
        if target != frame {
            capsule.animateFrame(to: target, spring: self.inPlaceMotion.transition)
            capsule.itemsTravelWithShape = true
        }
        self.inPlaceCapsules.append(capsule)
        container.layer.removeAllAnimations()
        return capsule
    }

    /// Lends `capsule`'s glass to the merging container, carrying on a press UIKit is drawing on it as a spring (on top of
    /// one the bar is already releasing, when the glass was lent before: a tap before the last change settled).
    private func lendInPlaceGlass(_ capsule: NavigationBarInPlaceCapsule) {
        let press = self.inPlacePressAtChange[ObjectIdentifier(capsule.container)] ?? self.inPlacePressReader(capsule.container)
        if abs(press.scale - 1.0) > 0.0005 {
            let current = capsule.press?.value(at: self.inPlaceTime) ?? 1.0
            capsule.press = NavigationSpringCurve(startTime: self.inPlaceTime, from: current * press.scale, target: 1.0, spring: NavigationBarGlassSettings.pressRelease, rest: .glass(0.0005))
            // Carried on once: a partner of two pills is lent twice in one layout.
            self.inPlacePressAtChange[ObjectIdentifier(capsule.container)] = NavigationBarCapsulePress(scale: 1.0, glow: 0.0)
        }
        guard capsule.lentGlass == nil else {
            return
        }
        let mergeContainer: GlassBackgroundContainerView
        if let current = self.inPlaceMergeContainer {
            mergeContainer = current
        } else {
            mergeContainer = GlassBackgroundContainerView(spacing: NavigationBarGlassSettings.platterSmoothness)
            mergeContainer.isUserInteractionEnabled = false
            self.inPlaceMergeContainer = mergeContainer
            self.insertSubview(mergeContainer, aboveSubview: self.underButtonsView)
        }
        mergeContainer.frame = self.bounds
        mergeContainer.update(size: self.bounds.size, isDark: capsule.isDark, transition: .immediate)
        let glass = capsule.container.lendGlass()
        mergeContainer.contentView.addSubview(glass)
        capsule.lentGlass = glass
    }

    /// After a layout: a pill going into a partner heads for the partner's frame as laid out now (a relayout mid-merge
    /// moves the partner), and the merging container spans the bar in its appearance.
    func followInPlacePartners(barSize: CGSize, isDark: Bool) {
        for capsule in self.inPlaceCapsules {
            guard let matched = capsule.matched, matched.isRemoval, let partner = matched.partner, let partnerCapsule = self.inPlaceCapsule(for: partner), partnerCapsule.targetFrame != matched.target else {
                continue
            }
            matched.retarget(to: partnerCapsule.targetFrame, at: self.inPlaceTime, spring: self.inPlaceMotion.transition)
            capsule.setFrame(partnerCapsule.targetFrame)
        }
        if let mergeContainer = self.inPlaceMergeContainer {
            mergeContainer.frame = CGRect(origin: CGPoint(), size: barSize)
            mergeContainer.update(size: barSize, isDark: isDark, transition: .immediate)
        }
    }

    /// Gives `capsule`'s glass back; the merging container goes when nothing is lent to it.
    private func reclaimInPlaceGlass(_ capsule: NavigationBarInPlaceCapsule) {
        if capsule.lentGlass != nil {
            capsule.lentGlass = nil
            capsule.container.reclaimGlass()
        }
        if let mergeContainer = self.inPlaceMergeContainer, !self.inPlaceCapsules.contains(where: { $0.lentGlass != nil }) {
            mergeContainer.removeFromSuperview()
            self.inPlaceMergeContainer = nil
        }
    }

    /// Ends at once the in-place animation of `container` and of every pill going into, or coming out of, it (a layout
    /// without animation takes the pill away): their glass comes back. A partner `container` was merging with keeps its
    /// own animation, its glass drawn alone in the merging container until it rests.
    func finishInPlace(of container: GlassContextExtractableContainer) {
        let ending = self.inPlaceCapsules.filter { $0.container === container || $0.matched?.partner === container }
        guard !ending.isEmpty else {
            return
        }
        self.inPlaceCapsules.removeAll(where: { capsule in ending.contains(where: { $0 === capsule }) })
        for capsule in ending {
            self.finishInPlace(capsule)
        }
        if self.inPlaceCapsules.isEmpty {
            self.stopInPlaceLink()
        }
    }

    /// Puts every capsule animating in place where it ends up (a navigation transition is taking the bar over).
    func finishInPlaceAnimations() {
        let capsules = self.inPlaceCapsules
        self.inPlaceCapsules.removeAll()
        for capsule in capsules {
            self.finishInPlace(capsule)
        }
        self.stopInPlaceLink()
    }

    private func finishInPlace(_ capsule: NavigationBarInPlaceCapsule) {
        self.reclaimInPlaceGlass(capsule)
        for items in capsule.leaving {
            items.view.removeFromSuperview()
        }
        capsule.leaving.removeAll()
        if capsule.isRemoved {
            capsule.container.removeFromSuperview()
            return
        }
        let frame = capsule.targetFrame
        capsule.container.transform = .identity
        capsule.container.frame = frame
        capsule.container.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: capsule.isDark, tintColor: capsule.tintColor, isInteractive: true, isVisible: true, transition: .immediate)
        if let items = capsule.items {
            Self.resetInPlaceItems(items.view, size: frame.size)
        }
    }

    private static func resetInPlaceItems(_ view: UIView, size: CGSize) {
        view.transform = .identity
        view.frame = CGRect(origin: CGPoint(), size: size)
        view.alpha = 1.0
        ComponentTransition.immediate.setBlur(layer: view.layer, radius: 0.0)
    }

    private func applyInPlace(_ capsule: NavigationBarInPlaceCapsule) {
        if capsule.lentGlass != nil && !capsule.container.isGlassLent {
            // The container took its glass back itself (a context menu extracting it): the loan is over.
            self.reclaimInPlaceGlass(capsule)
        }
        let time = self.inPlaceTime
        let frame = capsule.frame(at: time)
        let anchor = capsule.anchoredPulse?.anchor ?? CGPoint(x: 0.5, y: 0.5)
        let pulse = capsule.anchoredPulse.map { $0.scale(at: time) } ?? capsule.pulse?.scale ?? CGSize(width: 1.0, height: 1.0)
        let d = capsule.matched?.dematerialization.value(at: time) ?? capsule.dematerialization.value
        let press = capsule.press?.value(at: time) ?? 1.0
        let base = CGSize(width: (1.0 + d * (capsule.maxScale.width - 1.0)) * press, height: (1.0 + d * (capsule.maxScale.height - 1.0)) * press)
        let scale = CGSize(width: base.width * pulse.width, height: base.height * pulse.height)
        // The pulse holds its anchor still (`ScalePulse.anchor`): the shape's centre moves by the anchor's offset times
        // the pulse's growth (none for the centred pulse of an item change).
        let centre = CGPoint(x: frame.midX + (anchor.x - 0.5) * frame.width * base.width * (1.0 - pulse.width), y: frame.midY + (anchor.y - 0.5) * frame.height * base.height * (1.0 - pulse.height))
        let container = capsule.container
        container.bounds = CGRect(origin: CGPoint(), size: frame.size)
        // The shape the glass draws, and how the items inside it are scaled: by the glass's own size while it merges, by
        // the pill's transform otherwise.
        let shapeSize: CGSize
        let itemsScale: CGSize
        if let glass = capsule.lentGlass {
            // One shape with its partner: the glass is laid out at its scaled frame, untransformed, as push/pop lays out
            // merged platters. The pill's own view stays at rest, so its items take taps.
            container.center = CGPoint(x: frame.midX, y: frame.midY)
            container.transform = .identity
            shapeSize = CGSize(width: frame.width * scale.width, height: frame.height * scale.height)
            glass.transform = .identity
            glass.frame = CGRect(x: centre.x - shapeSize.width * 0.5, y: centre.y - shapeSize.height * 0.5, width: shapeSize.width, height: shapeSize.height)
            itemsScale = scale
        } else {
            container.center = centre
            container.transform = CGAffineTransform(scaleX: scale.width, y: scale.height)
            shapeSize = frame.size
            itemsScale = CGSize(width: 1.0, height: 1.0)
        }
        // A merging pill that goes keeps its glass (it shrinks into its partner's); one in its own container fades.
        let isVisible = !capsule.isRemoved || (capsule.matched != nil && capsule.lentGlass != nil)
        container.update(size: shapeSize, cornerRadius: min(shapeSize.width, shapeSize.height) * 0.5, isDark: capsule.isDark, tintColor: capsule.glassTint(at: time), isInteractive: true, isVisible: isVisible, transition: .immediate)
        var allItems = capsule.leaving
        if let items = capsule.items {
            allItems.append(items)
        }
        // The pill the items are placed in: a pill going into, or coming out of, its partner carries its items (they were
        // laid out in the pill it leaves, or the pill it becomes), and a partner that only moves carries them centred;
        // otherwise they stay where they rest while the shape morphs around them.
        let itemsPill: CGRect = capsule.matched?.itemsPill ?? (capsule.itemsTravelWithShape ? capsule.targetFrame : frame)
        for items in allItems {
            let a = max(0.0, min(1.0, items.appearance.value))
            // Where the items sit in the shape: their place in the pill, scaled with the shape about its centre.
            let offset = CGPoint(x: items.frame.midX - itemsPill.midX, y: items.frame.midY - itemsPill.midY)
            let centreInShape = CGPoint(x: shapeSize.width * 0.5 + offset.x * itemsScale.width, y: shapeSize.height * 0.5 + offset.y * itemsScale.height)
            let localFrame = CGRect(x: centreInShape.x - items.frame.width * 0.5, y: centreInShape.y - items.frame.height * 0.5, width: items.frame.width, height: items.frame.height)
            let appearanceScale = CGSize(width: 1.0 + items.appearance.value * (items.maxScale.width - 1.0), height: 1.0 + items.appearance.value * (items.maxScale.height - 1.0))
            setInPlaceFrame(items.view, frame: localFrame, scale: CGSize(width: appearanceScale.width * itemsScale.width, height: appearanceScale.height * itemsScale.height))
            items.view.alpha = 1.0 - a
            ComponentTransition.immediate.setBlur(layer: items.view.layer, radius: items.blurRadius * a)
        }
    }

    private func startInPlaceLinkIfNeeded() {
        guard self.inPlaceLink == nil else {
            return
        }
        // The first frame advances nothing: the change starts on screen where it starts.
        self.inPlaceLastTime = nil
        self.inPlaceLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
            self?.inPlaceDisplayLinkFrame(at: CACurrentMediaTime())
        })
    }

    /// A display link frame at `time`.
    func inPlaceDisplayLinkFrame(at time: Double) {
        let dt = self.inPlaceLastTime.map { CGFloat(time - $0) } ?? 0.0
        self.inPlaceLastTime = time
        let factor = self.inPlaceDurationFactor()
        self.tickInPlace(dt: factor > 0.0 ? dt / CGFloat(factor) : dt)
    }

    private func stopInPlaceLink() {
        self.inPlaceLink?.invalidate()
        self.inPlaceLink = nil
        self.inPlaceLastTime = nil
        let actions = self.inPlaceEndActions
        self.inPlaceEndActions = []
        for action in actions {
            action()
        }
        if self.inPlaceCapsuleAppeared {
            self.inPlaceCapsuleAppeared = false
            self.glassNeedsReadaptation?()
        }
    }

    /// Runs `action` once no capsule animates in place: at once when none does, else when the last one settles. For
    /// work that would cut a capsule's change short (the bar's glass adapting again to its backdrop).
    public func afterInPlaceAnimations(_ action: @escaping () -> Void) {
        if self.inPlaceCapsules.isEmpty {
            action()
        } else {
            self.inPlaceEndActions.append(action)
        }
    }

    /// One frame, `dt` seconds of animation time.
    func tickInPlace(dt: CGFloat) {
        self.inPlaceTime += Double(dt)
        let time = self.inPlaceTime
        for capsule in self.inPlaceCapsules {
            capsule.step(dt)
        }
        var settled: [NavigationBarInPlaceCapsule] = []
        for capsule in self.inPlaceCapsules {
            // A partner keeps merging (its glass lent) while a matched pill still moves into or out of it.
            let isHeldAsPartner = self.inPlaceCapsules.contains(where: { other in
                return other !== capsule && other.matched?.partner === capsule.container && !other.isAtRest(at: time)
            })
            if capsule.isAtRest(at: time) && !isHeldAsPartner {
                settled.append(capsule)
            } else {
                self.applyInPlace(capsule)
            }
        }
        self.inPlaceCapsules.removeAll(where: { capsule in settled.contains(where: { $0 === capsule }) })
        for capsule in settled {
            self.finishInPlace(capsule)
        }
        if self.inPlaceCapsules.isEmpty {
            self.stopInPlaceLink()
        }
    }

    struct InPlaceState {
        var frame: CGRect
        var pulse: CGSize
        /// The new items' opacity; nil for a capsule that is leaving.
        var itemsAlpha: CGFloat?
        var isMatched = false
        var isGlassLent = false
        var pulseAnchor = CGPoint(x: 0.5, y: 0.5)
        var press: CGFloat = 1.0
        var tintColor: GlassBackgroundView.TintColor? = nil
        /// While lent: the glass's frame (the merging container spans the bar) and whether it carries a transform.
        var glassFrame: CGRect? = nil
        var isGlassTransformed = false
        /// While lent: where the first leaving items' centre is from the glass's centre.
        var leavingItemsOffsetInGlass: CGPoint? = nil
    }

    func inPlaceStateForTesting(slot: NavigationBarCapsuleSlot) -> InPlaceState? {
        guard let capsule = self.inPlaceCapsules.first(where: { $0.slot == slot }) else {
            return nil
        }
        let time = self.inPlaceTime
        return InPlaceState(frame: capsule.frame(at: time), pulse: capsule.anchoredPulse.map { $0.scale(at: time) } ?? capsule.pulse?.scale ?? CGSize(width: 1.0, height: 1.0), itemsAlpha: capsule.items.map { 1.0 - max(0.0, min(1.0, $0.appearance.value)) }, isMatched: capsule.matched != nil, isGlassLent: capsule.lentGlass != nil, pulseAnchor: capsule.anchoredPulse?.anchor ?? CGPoint(x: 0.5, y: 0.5), press: capsule.press?.value(at: time) ?? 1.0, tintColor: capsule.tintColor, glassFrame: capsule.lentGlass?.frame, isGlassTransformed: capsule.lentGlass.map { !$0.transform.isIdentity } ?? false, leavingItemsOffsetInGlass: capsule.lentGlass.flatMap { glass in
            capsule.leaving.first.flatMap { items in items.view.superview.map { $0.convert(items.view.center, to: glass) } }.map { CGPoint(x: $0.x - glass.bounds.midX, y: $0.y - glass.bounds.midY) }
        })
    }

    /// The views of the items leaving `slot`'s capsule.
    func inPlaceLeavingViewsForTesting(slot: NavigationBarCapsuleSlot) -> [UIView] {
        return self.inPlaceCapsules.first(where: { $0.slot == slot })?.leaving.map { $0.view } ?? []
    }

    func inPlaceStateForTesting(isLeft: Bool) -> InPlaceState? {
        return self.inPlaceStateForTesting(slot: isLeft ? .left : .right(0))
    }

    func inPlaceTickForTesting(dt: CGFloat) {
        self.tickInPlace(dt: dt)
    }
}

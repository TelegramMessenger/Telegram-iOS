import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

/// A glass container of the bar's row: the left capsule, the right one, and the accent circle outermost on the right.
enum NavigationBarCapsuleSlot {
    case left
    case right
    case rightCircle
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
    /// The bar's live items (its `leftButtonsContainer` or `rightButtonsContainer`); nil while the capsule leaves.
    var items: Items?
    var leaving: [Items] = []
    var isRemoved = false
    var tintColor: GlassBackgroundView.TintColor
    var isDark: Bool

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

    var frame: CGRect {
        return CGRect(x: self.x.value, y: self.y.value, width: max(0.0, self.width.value), height: max(0.0, self.height.value))
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

    var isAtRest: Bool {
        return self.x.isAtRest && self.y.isAtRest && self.width.isAtRest && self.height.isAtRest && self.dematerialization.isAtRest && self.pulse == nil && (self.items?.appearance.isAtRest ?? true) && self.leaving.isEmpty
    }
}

extension NavigationBarGlassSettings {
    /// An in-place tint change, as UIKit is handed it. Measured against iOS 27 (a pressed Edit -> checkmark, both
    /// filmed): the native capsule is fully tinted ~0.13 s after the change starts; UIKit starts drawing our change ~30
    /// ms late, and a 0.3 s response (the navigation transition's frame-driven cross-fade) took ~0.25 s.
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
        case .right:
            return self.rightButtonsBackgroundContainer
        case .rightCircle:
            return self.rightCircleBackgroundContainer
        }
    }

    /// The bar's items view `slot`'s glass holds.
    func inPlaceItemsView(_ slot: NavigationBarCapsuleSlot) -> UIView {
        switch slot {
        case .left:
            return self.leftButtonsContainer
        case .right:
            return self.rightButtonsContainer
        case .rightCircle:
            return self.rightCircleContainer
        }
    }

    func inPlaceCapsule(for container: GlassContextExtractableContainer) -> NavigationBarInPlaceCapsule? {
        return self.inPlaceCapsules.first(where: { $0.container === container })
    }

    /// Where a capsule is now: its in-place spring frame, or the frame Core Animation is drawing it at.
    private func currentFrame(of container: GlassContextExtractableContainer) -> CGRect {
        if let capsule = self.inPlaceCapsule(for: container) {
            return capsule.frame
        }
        let layer = container.layer.presentation() ?? container.layer
        return CGRect(x: layer.position.x - layer.bounds.width * 0.5, y: layer.position.y - layer.bounds.height * 0.5, width: layer.bounds.width, height: layer.bounds.height)
    }

    /// What a side shows now, as a snapshot at its resting frame: what leaves when the side's items change in place.
    /// Call before the content view takes the new items.
    func inPlaceLeavingItems(slot: NavigationBarCapsuleSlot) -> NavigationBarInPlaceCapsule.Items? {
        guard let container = self.inPlaceContainer(slot), let contentView = self.primaryContentView else {
            return nil
        }
        let source: UIView
        switch slot {
        case .left:
            source = contentView.leftButtonsContainer
        case .right:
            source = contentView.rightButtonsContainer
        case .rightCircle:
            source = contentView.rightCircleContainer
        }
        let view = source.snapshotView(afterScreenUpdates: false) ?? UIView()
        view.isUserInteractionEnabled = false
        let capsule = self.inPlaceCapsule(for: container)
        let capsuleFrame = capsule?.targetFrame ?? container.frame
        // Items still materializing leave from where they got to.
        let appearance = capsule?.items?.appearance.value ?? 0.0
        return NavigationBarInPlaceCapsule.Items(view: view, frame: CGRect(origin: CGPoint(x: capsuleFrame.minX + source.frame.minX, y: capsuleFrame.minY + source.frame.minY), size: source.bounds.size), appearance: appearance, motion: self.inPlaceMotion)
    }

    /// A capsule whose items changed (or that the change creates) animates to `frame`: an existing one morphs and
    /// pulses with its old items dematerializing, a new one materializes; the new items materialize either way.
    func startInPlaceChange(container: GlassContextExtractableContainer, slot: NavigationBarCapsuleSlot, isNew: Bool, frame: CGRect, tintColor: GlassBackgroundView.TintColor, isDark: Bool, leaving: NavigationBarInPlaceCapsule.Items?) {
        let itemsView = self.inPlaceItemsView(slot)
        let motion = self.inPlaceMotion
        let capsule: NavigationBarInPlaceCapsule
        if let current = self.inPlaceCapsule(for: container) {
            capsule = current
        } else {
            capsule = NavigationBarInPlaceCapsule(slot: slot, container: container, frame: isNew ? frame : self.currentFrame(of: container), tintColor: tintColor, isDark: isDark)
            self.inPlaceCapsules.append(capsule)
            // The springs own the frame from here on.
            container.layer.removeAllAnimations()
        }
        capsule.isDark = isDark
        if isNew {
            capsule.setFrame(frame)
            capsule.maxScale = motion.materializeScale(size: frame.size)
            capsule.dematerialization.set(1.0)
            capsule.dematerialization.animate(to: 0.0, spring: NavigationBarGlassSettings.materialize)
        } else {
            capsule.animateFrame(to: frame, spring: motion.transition)
            // The pulse multiplies with any press UIKit is still drawing on the glass, as on iOS 27. Native's change starts
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

        // The glass's tint (a cross-fade) and, for a new capsule, its appearing are UIKit's to animate.
        capsule.tintColor = tintColor
        let glassTransition = NavigationBarGlassSettings.uikitTransition(for: isNew ? NavigationBarGlassSettings.materialize : NavigationBarGlassSettings.inPlaceTint)
        container.update(size: capsule.frame.size, cornerRadius: capsule.frame.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, isVisible: true, transition: glassTransition)

        self.applyInPlace(capsule)
        self.startInPlaceLinkIfNeeded()
    }

    /// A capsule the change removes dematerializes where it is, with its items, then leaves.
    func startInPlaceRemoval(container: GlassContextExtractableContainer, slot: NavigationBarCapsuleSlot, tintColor: GlassBackgroundView.TintColor, isDark: Bool, leaving: NavigationBarInPlaceCapsule.Items?) {
        let capsule: NavigationBarInPlaceCapsule
        if let current = self.inPlaceCapsule(for: container) {
            capsule = current
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
        container.update(size: capsule.frame.size, cornerRadius: capsule.frame.height * 0.5, isDark: capsule.isDark, tintColor: capsule.tintColor, isInteractive: true, isVisible: false, transition: NavigationBarGlassSettings.uikitTransition(for: NavigationBarGlassSettings.materialize))

        self.applyInPlace(capsule)
        self.startInPlaceLinkIfNeeded()
    }

    /// A layout while a capsule animates in place: it heads for `frame` instead of being placed there.
    func retargetInPlace(_ capsule: NavigationBarInPlaceCapsule, frame: CGRect, tintColor: GlassBackgroundView.TintColor, isDark: Bool, transition: ComponentTransition) {
        if frame != capsule.targetFrame {
            if transition.animation.isImmediate {
                capsule.setFrame(frame)
            } else {
                capsule.animateFrame(to: frame, spring: self.inPlaceMotion.transition)
            }
            capsule.items?.frame = frame
        }
        if tintColor != capsule.tintColor || isDark != capsule.isDark {
            capsule.tintColor = tintColor
            capsule.isDark = isDark
            capsule.container.update(size: capsule.frame.size, cornerRadius: capsule.frame.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, isVisible: !capsule.isRemoved, transition: transition.animation.isImmediate ? .immediate : NavigationBarGlassSettings.uikitTransition(for: NavigationBarGlassSettings.inPlaceTint))
        }
        self.applyInPlace(capsule)
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
        let frame = capsule.frame
        let pulse = capsule.pulse?.scale ?? CGSize(width: 1.0, height: 1.0)
        let d = capsule.dematerialization.value
        let scale = CGSize(width: (1.0 + d * (capsule.maxScale.width - 1.0)) * pulse.width, height: (1.0 + d * (capsule.maxScale.height - 1.0)) * pulse.height)
        let container = capsule.container
        container.bounds = CGRect(origin: CGPoint(), size: frame.size)
        container.center = CGPoint(x: frame.midX, y: frame.midY)
        container.transform = CGAffineTransform(scaleX: scale.width, y: scale.height)
        container.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: capsule.isDark, tintColor: capsule.tintColor, isInteractive: true, isVisible: !capsule.isRemoved, transition: .immediate)
        var allItems = capsule.leaving
        if let items = capsule.items {
            allItems.append(items)
        }
        for items in allItems {
            let a = max(0.0, min(1.0, items.appearance.value))
            let localFrame = CGRect(x: items.frame.minX - frame.minX, y: items.frame.minY - frame.minY, width: items.frame.width, height: items.frame.height)
            setInPlaceFrame(items.view, frame: localFrame, scale: CGSize(width: 1.0 + items.appearance.value * (items.maxScale.width - 1.0), height: 1.0 + items.appearance.value * (items.maxScale.height - 1.0)))
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
    }

    /// One frame, `dt` seconds of animation time.
    func tickInPlace(dt: CGFloat) {
        for capsule in self.inPlaceCapsules {
            capsule.step(dt)
        }
        var settled: [NavigationBarInPlaceCapsule] = []
        for capsule in self.inPlaceCapsules {
            if capsule.isAtRest {
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
    }

    func inPlaceStateForTesting(slot: NavigationBarCapsuleSlot) -> InPlaceState? {
        guard let capsule = self.inPlaceCapsules.first(where: { $0.slot == slot }) else {
            return nil
        }
        return InPlaceState(frame: capsule.frame, pulse: capsule.pulse?.scale ?? CGSize(width: 1.0, height: 1.0), itemsAlpha: capsule.items.map { 1.0 - max(0.0, min(1.0, $0.appearance.value)) })
    }

    func inPlaceStateForTesting(isLeft: Bool) -> InPlaceState? {
        return self.inPlaceStateForTesting(slot: isLeft ? .left : .right)
    }

    func inPlaceTickForTesting(dt: CGFloat) {
        self.tickInPlace(dt: dt)
    }
}

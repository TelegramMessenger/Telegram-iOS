import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import EdgeEffect
import NavigationBarComponent

/// The renderer of a navigation transition between two bars built on `NavigationBarComponent`; nil for any other pair,
/// which then slides with its screens.
public func makeNavigationBarTransitionRenderer(bottom: NavigationBarTransitionSource, top: NavigationBarTransitionSource) -> NavigationBarTransitionRenderer? {
    guard let bottom = bottom as? NavigationBarComponentTransitionSource, let top = top as? NavigationBarComponentTransitionSource, bottom.componentTransitionState != nil, top.componentTransitionState != nil else {
        return nil
    }
    return NavigationBarTransitionRendererImpl(bottom: bottom, top: top)
}

/// The edge effect's gradient length for a whole transition. It is a mask image, so it cannot be interpolated: the
/// transition keeps the length of the backdrop that shows more, the taller one on a tie.
func navigationBarTransitionBackdropEdgeLength(bottom: NavigationBarComponentTransitionState, top: NavigationBarComponentTransitionState) -> CGFloat {
    let bottomShown = bottom.backdropColor == nil ? 0.0 : bottom.backdropAlpha
    let topShown = top.backdropColor == nil ? 0.0 : top.backdropAlpha
    if abs(bottomShown - topShown) > 0.001 {
        return bottomShown > topShown ? bottom.backdropEdgeLength : top.backdropEdgeLength
    }
    return bottom.backdropHeight >= top.backdropHeight ? bottom.backdropEdgeLength : top.backdropEdgeLength
}

/// Below it a backdrop counts as transparent (UIKit's threshold, `navigationBarTransitionBackdropAlpha`).
private let navigationBarTransitionTransparentBackdropAlpha: CGFloat = 0.3

/// The backdrops the transition draws from, and whether each bar keeps its own instead (`keepsLoneBackdrop`: a
/// backdrop only that bar shows, the other's being transparent). A bar that keeps its own contributes the other bar's
/// backdrop at no alpha, so the transition draws only the other's, at its own height and colour.
func navigationBarTransitionBackdropStates(bottom: NavigationBarComponentTransitionState, top: NavigationBarComponentTransitionState) -> (bottom: NavigationBarComponentTransitionState, top: NavigationBarComponentTransitionState, bottomKeepsOwn: Bool, topKeepsOwn: Bool) {
    func shown(_ state: NavigationBarComponentTransitionState) -> CGFloat {
        return state.backdropColor == nil ? 0.0 : state.backdropAlpha
    }
    func keepsOwn(_ state: NavigationBarComponentTransitionState, other: NavigationBarComponentTransitionState) -> Bool {
        return state.keepsLoneBackdrop && shown(state) >= navigationBarTransitionTransparentBackdropAlpha && shown(other) < navigationBarTransitionTransparentBackdropAlpha
    }
    func leavingTheBackdrop(_ state: NavigationBarComponentTransitionState, to other: NavigationBarComponentTransitionState) -> NavigationBarComponentTransitionState {
        var state = state
        state.backdropHeight = other.backdropHeight
        state.backdropColor = other.backdropColor
        state.backdropAlpha = 0.0
        state.backdropExtension = other.backdropExtension
        state.backdropTintAlpha = other.backdropTintAlpha
        state.backdropEdgeLength = other.backdropEdgeLength
        return state
    }
    let bottomKeepsOwn = keepsOwn(bottom, other: top)
    let topKeepsOwn = keepsOwn(top, other: bottom)
    return (bottomKeepsOwn ? leavingTheBackdrop(bottom, to: top) : bottom, topKeepsOwn ? leavingTheBackdrop(top, to: bottom) : top, bottomKeepsOwn, topKeepsOwn)
}

/// The shared backdrop's alpha at `fraction` (0: the bottom bar, 1: the top one). Two backdrops on the same side of 0.3
/// cross-fade along the whole transition. When one is transparent (below 0.3) and the other is not, UIKit fades it in
/// a keyframe instead (`_UIBarsTwoPartCrossfadeTransitionProgress`, bar RE §6): going transparent during the first 0.3
/// of the progress, going opaque during the last 0.3. Either way that is the 0.3 of the fraction next to the opaque
/// bar, so a push, a pop and a scrubbed pop agree.
func navigationBarTransitionBackdropAlpha(bottom: CGFloat, top: CGFloat, fraction: CGFloat) -> CGFloat {
    let threshold = navigationBarTransitionTransparentBackdropAlpha
    let keyframeLength: CGFloat = 0.3
    let progress: CGFloat
    if (bottom < threshold) == (top < threshold) {
        progress = fraction
    } else if top < threshold {
        progress = fraction / keyframeLength
    } else {
        progress = (fraction - (1.0 - keyframeLength)) / keyframeLength
    }
    let clamped = max(0.0, min(1.0, progress))
    return bottom * (1.0 - clamped) + top * clamped
}

/// The shared edge effect's frame at `fraction`, laid out at `layoutHeight` (the taller bar's, when baked) so that its
/// bottom edge is where a `fraction`-interpolated height would put it.
func navigationBarTransitionBackdropFrame(fraction: CGFloat, bottomTop: CGFloat, topTop: CGFloat, bottomHeight: CGFloat, topHeight: CGFloat, bottomExtension: CGFloat, topExtension: CGFloat, width: CGFloat, layoutHeight: CGFloat) -> CGRect {
    func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        return a * (1.0 - fraction) + b * fraction
    }
    let backdropExtension = lerp(max(0.0, min(20.0, bottomExtension)), max(0.0, min(20.0, topExtension)))
    let bottomEdge = lerp(bottomTop, topTop) + backdropExtension + lerp(bottomHeight, topHeight) + 24.0
    let height = 20.0 + layoutHeight + 24.0
    return CGRect(x: 0.0, y: bottomEdge - height, width: width, height: height)
}

/// Draws what both bars share once: one edge effect whose height, colour and alpha move between the two bars', and the
/// glass capsules, as iOS 27 animates them (`NavigationBarPlatterTransitionView`), iPhone Duo's side column included:
/// its back circle, buttons capsule and trailing circle are capsules like the row's, laid out vertically.
final class NavigationBarTransitionRendererImpl: NavigationBarTransitionRenderer {
    private weak var bottom: NavigationBarComponentTransitionSource?
    private weak var top: NavigationBarComponentTransitionSource?
    let backdropView: UIView
    let rowView: UIView
    private let edgeEffectView = EdgeEffectView()
    /// The bars' screen nodes the capsules host until the glass is gone (`NavigationBarNodeLoan`).
    private var lentNodes: [ObjectIdentifier: ASDisplayNode] = [:]
    private var platterView: NavigationBarPlatterTransitionView?
    private var appliedPlatterSides: (bottom: NavigationBarPlatterTransitionView.Side, top: NavigationBarPlatterTransitionView.Side)?
    private(set) var currentBackdropHeight: CGFloat = 0.0
    private(set) var currentBackdropAlpha: CGFloat = 1.0
    private(set) var currentFraction: CGFloat = 0.0
    /// What an expansion took from the lower bar (its pill and avatar), which the capsules leave out.
    private var bottomExclusions = NavigationBarTransitionExclusions.none

    func updateExclusions(bottom: NavigationBarTransitionExclusions) {
        self.bottomExclusions = bottom
    }

    // Tests.
    var edgeEffectViewForTesting: EdgeEffectView { return self.edgeEffectView }
    var platterViewForTesting: NavigationBarPlatterTransitionView? { return self.platterView }

    init(bottom: NavigationBarComponentTransitionSource, top: NavigationBarComponentTransitionSource) {
        self.bottom = bottom
        self.top = top
        self.backdropView = SparseContainerView()
        self.backdropView.isUserInteractionEnabled = false
        self.rowView = SparseContainerView()
        self.rowView.isUserInteractionEnabled = false
        self.backdropView.addSubview(self.edgeEffectView)
    }

    deinit {
        // A renderer dropped without being ended (its transition went away) still gives the nodes back.
        let nodes = Array(self.lentNodes.values)
        if Thread.isMainThread {
            for node in nodes {
                NavigationBarNodeLoan.end(node)
            }
        } else {
            DispatchQueue.main.async {
                for node in nodes {
                    NavigationBarNodeLoan.end(node)
                }
            }
        }
    }

    /// Lends the capsules the screen nodes of both contents; a node no longer in either goes back.
    private func lendNodes(bottom: NavigationBarComponent.Content, top: NavigationBarComponent.Content) {
        var nodes: [ObjectIdentifier: ASDisplayNode] = [:]
        for node in navigationBarContentNodes(bottom) + navigationBarContentNodes(top) {
            nodes[ObjectIdentifier(node)] = node
        }
        for (key, node) in self.lentNodes where nodes[key] == nil {
            NavigationBarNodeLoan.end(node)
        }
        for node in nodes.values {
            NavigationBarNodeLoan.lend(node)
        }
        self.lentNodes = nodes
    }

    func end() {
        let nodes = self.lentNodes
        self.lentNodes = [:]
        for node in nodes.values {
            NavigationBarNodeLoan.end(node)
        }
    }

    /// Both bars' states, with the backdrops the transition draws; tells each bar whether it keeps its own.
    private func transitionStates() -> (bottom: NavigationBarComponentTransitionState, top: NavigationBarComponentTransitionState)? {
        guard let bottom = self.bottom, let top = self.top, let bottomState = bottom.componentTransitionState, let topState = top.componentTransitionState else {
            return nil
        }
        let states = navigationBarTransitionBackdropStates(bottom: bottomState, top: topState)
        bottom.updateKeepsOwnBackdrop(states.bottomKeepsOwn)
        top.updateKeepsOwnBackdrop(states.topKeepsOwn)
        return (states.bottom, states.top)
    }

    func update(size: CGSize, fraction: CGFloat, bottomFrame: CGRect, topFrame: CGRect, transition: ContainedViewLayoutTransition) {
        guard let (bottomState, topState) = self.transitionStates() else {
            return
        }
        self.currentFraction = fraction
        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
            return a * (1.0 - fraction) + b * fraction
        }
        let componentTransition = ComponentTransition(transition)

        // Backdrop: one edge effect between the two bars'.
        let backdropHeight = lerp(bottomState.backdropHeight, topState.backdropHeight)
        self.currentBackdropHeight = backdropHeight
        let bottomBackdropAlpha = bottomState.backdropColor == nil ? 0.0 : bottomState.backdropAlpha
        let topBackdropAlpha = topState.backdropColor == nil ? 0.0 : topState.backdropAlpha
        let bottomColor = bottomState.backdropColor ?? topState.backdropColor ?? .white
        let topColor = topState.backdropColor ?? bottomState.backdropColor ?? .white
        let color = bottomColor.mixedWith(topColor, alpha: fraction)
        // A bar moves its edge effect down by its extension, at most 20pt.
        let edgeEffectFrame = navigationBarTransitionBackdropFrame(fraction: fraction, bottomTop: bottomFrame.minY, topTop: topFrame.minY, bottomHeight: bottomState.backdropHeight, topHeight: topState.backdropHeight, bottomExtension: bottomState.backdropExtension, topExtension: topState.backdropExtension, width: size.width, layoutHeight: backdropHeight)
        let edgeEffectHeight = edgeEffectFrame.height - 20.0
        transition.updateFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
        let edgeLength = navigationBarTransitionBackdropEdgeLength(bottom: bottomState, top: topState)
        self.edgeEffectView.colorLayer.removeAnimation(forKey: navigationBarTransitionKeyframeKeyPrefix + "tintOpacity")
        self.edgeEffectView.update(content: color, blur: true, alpha: lerp(bottomState.backdropTintAlpha, topState.backdropTintAlpha), rect: CGRect(origin: CGPoint(), size: edgeEffectFrame.size), edge: .top, edgeSize: min(edgeLength, edgeEffectHeight), transition: componentTransition)
        let backdropAlpha = navigationBarTransitionBackdropAlpha(bottom: bottomBackdropAlpha, top: topBackdropAlpha, fraction: fraction)
        self.currentBackdropAlpha = backdropAlpha
        transition.updateAlpha(layer: self.edgeEffectView.layer, alpha: backdropAlpha)

        // The capsules, on their own springs.
        let platterView: NavigationBarPlatterTransitionView
        if let current = self.platterView {
            platterView = current
        } else {
            platterView = NavigationBarPlatterTransitionView(frame: CGRect())
            platterView.onSettled = { [weak self] in
                self?.glassSettled?()
            }
            self.platterView = platterView
            self.rowView.addSubview(platterView)
        }
        platterView.frame = CGRect(origin: CGPoint(), size: size)
        // A bar whose row is hidden (an active search) contributes no capsules: they are not on screen, so the other
        // bar's materialize or dematerialize in place. The capsules are never faded as a whole: this view is their
        // glass's ancestor, and pushing a chat from a search with it starting transparent, the chat's glass was not drawn
        // through the push and the linger after it.
        var bottomContent = navigationBarTransitionCapsuleContent(bottomState)
        if !self.bottomExclusions.nodes.isEmpty {
            let excluded = Set(self.bottomExclusions.nodes.map { ObjectIdentifier($0) })
            bottomContent = NavigationBarComponent.Content(title: bottomContent.title, back: bottomContent.back, leftButton: bottomContent.leftButton, rightButtons: bottomContent.rightButtons.filter { button in
                if case let .node(node) = button.content {
                    return !excluded.contains(ObjectIdentifier(node))
                }
                return true
            }, backPressed: bottomContent.backPressed, badge: bottomContent.badge, backContextAction: bottomContent.backContextAction)
        }
        let topContent = navigationBarTransitionCapsuleContent(topState)
        self.lendNodes(bottom: bottomContent, top: topContent)
        let bottomSide = NavigationBarPlatterTransitionView.Side(content: bottomContent, theme: bottomState.theme, strings: bottomState.strings, leftInset: bottomState.leftInset, rightInset: bottomState.rightInset, trailingButtonsInset: bottomState.trailingButtonsInset, rowFrame: bottomState.rowFrame.offsetBy(dx: bottomFrame.minX, dy: bottomFrame.minY), leadingPressScale: bottomState.leadingPressScale, leadingPressGlow: bottomState.leadingPressGlow, trailingPressScales: bottomState.trailingPressScales, trailingPressGlows: bottomState.trailingPressGlows, columnFrame: navigationBarTransitionRowIsHidden(bottomState) ? nil : bottomState.sideColumnFrame?.offsetBy(dx: bottomFrame.minX, dy: bottomFrame.minY), hidesColumnButtons: bottomState.hidesSideColumnButtons, titlePill: self.bottomExclusions.titlePill ? nil : navigationBarTransitionTitlePill(bottomState, offset: bottomFrame.origin))
        let topSide = NavigationBarPlatterTransitionView.Side(content: topContent, theme: topState.theme, strings: topState.strings, leftInset: topState.leftInset, rightInset: topState.rightInset, trailingButtonsInset: topState.trailingButtonsInset, rowFrame: topState.rowFrame.offsetBy(dx: topFrame.minX, dy: topFrame.minY), leadingPressScale: topState.leadingPressScale, leadingPressGlow: topState.leadingPressGlow, trailingPressScales: topState.trailingPressScales, trailingPressGlows: topState.trailingPressGlows, columnFrame: navigationBarTransitionRowIsHidden(topState) ? nil : topState.sideColumnFrame?.offsetBy(dx: topFrame.minX, dy: topFrame.minY), hidesColumnButtons: topState.hidesSideColumnButtons, titlePill: navigationBarTransitionTitlePill(topState, offset: topFrame.origin))
        if let applied = self.appliedPlatterSides, platterSidesEqual(applied.bottom, bottomSide), platterSidesEqual(applied.top, topSide) {
        } else {
            self.appliedPlatterSides = (bottomSide, topSide)
            platterView.setSides(bottom: bottomSide, top: topSide)
        }
    }

    func animate(size: CGSize, timeline: NavigationTransitionTimeline, bottomFrame: CGRect, topFrame: CGRect) {
        guard let (bottomState, topState) = self.transitionStates(), let finalFraction = timeline.fractions.last else {
            return
        }
        let timing = timeline.timing
        // The model and the glass are laid out at the final fraction, as an immediate update would.
        self.update(size: size, fraction: finalFraction, bottomFrame: bottomFrame, topFrame: topFrame, transition: .immediate)
        let layoutHeight = max(bottomState.backdropHeight, topState.backdropHeight)
        let frames = timeline.fractions.map { navigationBarTransitionBackdropFrame(fraction: $0, bottomTop: bottomFrame.minY, topTop: topFrame.minY, bottomHeight: bottomState.backdropHeight, topHeight: topState.backdropHeight, bottomExtension: bottomState.backdropExtension, topExtension: topState.backdropExtension, width: size.width, layoutHeight: layoutHeight) }
        guard let finalFrame = frames.last else {
            return
        }
        let bottomColor = bottomState.backdropColor ?? topState.backdropColor ?? .white
        let topColor = topState.backdropColor ?? bottomState.backdropColor ?? .white
        let colors = timeline.fractions.map { bottomColor.mixedWith(topColor, alpha: $0) }
        let tints = timeline.fractions.map { bottomState.backdropTintAlpha * (1.0 - $0) + topState.backdropTintAlpha * $0 }
        let edgeLength = navigationBarTransitionBackdropEdgeLength(bottom: bottomState, top: topState)
        let bottomBackdropAlpha = bottomState.backdropColor == nil ? 0.0 : bottomState.backdropAlpha
        let topBackdropAlpha = topState.backdropColor == nil ? 0.0 : topState.backdropAlpha
        let alphas = timeline.fractions.map { navigationBarTransitionBackdropAlpha(bottom: bottomBackdropAlpha, top: topBackdropAlpha, fraction: $0) }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.edgeEffectView.frame = finalFrame
        self.edgeEffectView.update(content: colors.last, blur: true, alpha: tints.last ?? 0.75, rect: CGRect(origin: CGPoint(), size: finalFrame.size), edge: .top, edgeSize: min(edgeLength, finalFrame.height - 20.0), transition: .immediate)
        CATransaction.commit()

        let prefix = navigationBarTransitionKeyframeKeyPrefix
        addNavigationKeyframes(to: self.edgeEffectView.layer, key: prefix + "position", keyPath: "position", values: frames.map { NSValue(cgPoint: CGPoint(x: $0.midX, y: $0.midY)) }, timing: timing)
        addNavigationKeyframes(to: self.edgeEffectView.layer, key: prefix + "opacity", keyPath: "opacity", values: alphas.map { NSNumber(value: Float($0)) }, timing: timing)
        addNavigationKeyframes(to: self.edgeEffectView.colorLayer, key: prefix + "backgroundColor", keyPath: "backgroundColor", values: colors.map { $0.cgColor }, timing: timing)
        addNavigationKeyframes(to: self.edgeEffectView.colorLayer, key: prefix + "tintOpacity", keyPath: "opacity", values: tints.map { NSNumber(value: Float($0)) }, timing: timing)
    }

    func beginTransition(isInteractive: Bool, toTop: Bool) {
        self.platterView?.beginTransition(isInteractive: isInteractive, toTop: toTop)
    }

    func endInteraction(towardTop: Bool) {
        self.platterView?.endInteraction(towardTop: towardTop)
    }

    func beginInteraction() {
        self.platterView?.beginInteraction()
    }

    var isGlassAnimating: Bool {
        return self.platterView?.isAnimating ?? false
    }

    var glassSettled: (() -> Void)?
}

private func platterSidesEqual(_ lhs: NavigationBarPlatterTransitionView.Side, _ rhs: NavigationBarPlatterTransitionView.Side) -> Bool {
    return lhs.content == rhs.content && lhs.theme === rhs.theme && lhs.strings === rhs.strings && lhs.leftInset == rhs.leftInset && lhs.rightInset == rhs.rightInset && lhs.trailingButtonsInset == rhs.trailingButtonsInset && lhs.rowFrame == rhs.rowFrame && lhs.leadingPressScale == rhs.leadingPressScale && lhs.leadingPressGlow == rhs.leadingPressGlow && lhs.trailingPressScales == rhs.trailingPressScales && lhs.trailingPressGlows == rhs.trailingPressGlows && lhs.columnFrame == rhs.columnFrame && lhs.hidesColumnButtons == rhs.hidesColumnButtons && lhs.titlePill?.frame == rhs.titlePill?.frame && lhs.titlePill?.signature == rhs.titlePill?.signature
}

/// A bar's title pill for the capsules, at its place in the transition: none when its row is hidden.
func navigationBarTransitionTitlePill(_ state: NavigationBarComponentTransitionState, offset: CGPoint) -> NavigationBarTransitionTitlePill? {
    guard !navigationBarTransitionRowIsHidden(state), var pill = state.titlePill else {
        return nil
    }
    pill.frame = pill.frame.offsetBy(dx: offset.x, dy: offset.y)
    return pill
}

/// Whether a bar's row is hidden (an active search replaces it), so its capsules are not on screen. A row fading
/// counts as hidden from half way.
func navigationBarTransitionRowIsHidden(_ state: NavigationBarComponentTransitionState) -> Bool {
    return state.rowAlpha < 0.5
}

/// The content a bar's capsules show in a transition: none when its row is hidden.
func navigationBarTransitionCapsuleContent(_ state: NavigationBarComponentTransitionState) -> NavigationBarComponent.Content {
    if navigationBarTransitionRowIsHidden(state) {
        return NavigationBarComponent.Content(title: .text(""), back: nil, leftButton: nil, rightButtons: [], backPressed: state.content.backPressed)
    }
    return navigationBarCapsuleContent(state.content)
}

/// The capsules' copy of a content: no title (each bar's own title rides its screen, as in UIKit). Screen nodes stay
/// as they are: the renderer lends them to the capsules (`NavigationBarNodeLoan`).
func navigationBarCapsuleContent(_ content: NavigationBarComponent.Content) -> NavigationBarComponent.Content {
    return NavigationBarComponent.Content(title: .text(""), back: content.back, leftButton: content.leftButton, rightButtons: content.rightButtons, backPressed: content.backPressed, badge: content.badge, backContextAction: content.backContextAction)
}

/// The screen nodes among a content's buttons.
func navigationBarContentNodes(_ content: NavigationBarComponent.Content) -> [ASDisplayNode] {
    var nodes: [ASDisplayNode] = []
    for button in [content.leftButton].compactMap({ $0 }) + content.rightButtons {
        if case let .node(node) = button.content {
            nodes.append(node)
        }
    }
    return nodes
}

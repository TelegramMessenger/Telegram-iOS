import Foundation
import UIKit
import AsyncDisplayKit

/// A bar taking part in a navigation push or pop, by the context-menu extraction flow: the bar keeps its containing
/// view in its screen; the coordinator lifts only the content view above the two sliding screens and returns it
/// through `putBack()`.
public protocol NavigationBarTransitionSource: AnyObject {
    /// The content to lift, or nil when the bar takes no part (hidden, opted out, already lifted).
    func takeView() -> NavigationBarTransitionTakeViewInfo?
    /// Re-attaches the content to the containing view and ends any role.
    func putBack()
    /// Puts the lifted bar into a role (nil: none) for `fraction` — 0 shows the bottom screen's bar, 1 the top
    /// screen's.
    func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition)
    /// While lifted: the source's own layout moved its content, in the containing view's coordinates.
    var transitionContentFrameUpdated: ((CGRect) -> Void)? { get set }
    /// After a transition whose glass is still animating above this bar (UIKit's capsules run on their own clock and
    /// outlive the screens' transition): `held` keeps the bar's own glass hidden meanwhile, and the bar calls
    /// `interrupted` when it is touched or its content or layout changes, so that the transition's glass hands over at
    /// once. Returns whether the bar holds its glass; one that cannot is handed back at once.
    func holdGlass(_ held: Bool, interrupted: (() -> Void)?) -> Bool
    /// The bar's back button frame in `view`'s coordinates, nil without one: a push's back-button hole.
    func backButtonFrame(in view: UIView) -> CGRect?
}

public extension NavigationBarTransitionSource {
    func holdGlass(_ held: Bool, interrupted: (() -> Void)?) -> Bool {
        return false
    }

    func backButtonFrame(in view: UIView) -> CGRect? {
        return nil
    }
}

public enum NavigationBarTransitionRole: Equatable {
    /// The lower screen's bar: covered by a push, revealed by a pop.
    case bottom
    /// The upper screen's bar.
    case top
}

public final class NavigationBarTransitionTakeViewInfo {
    /// Stays in the screen; the content's frame is reported in its coordinates.
    public let containingView: UIView
    /// Re-parented by the coordinator until `putBack()`.
    public let contentView: UIView

    public init(containingView: UIView, contentView: UIView) {
        self.containingView = containingView
        self.contentView = contentView
    }
}

/// What another transition takes from a bar for itself, so its morph does not draw it twice: its title pill, and the
/// screen nodes of these buttons.
public struct NavigationBarTransitionExclusions {
    public var titlePill: Bool
    public var nodes: [ASDisplayNode]

    public static let none = NavigationBarTransitionExclusions(titlePill: false, nodes: [])

    public init(titlePill: Bool, nodes: [ASDisplayNode]) {
        self.titlePill = titlePill
        self.nodes = nodes
    }
}

/// The key prefix of the keyframe animations a bar transition installs (the bar layer's and its renderer's).
public let navigationBarTransitionKeyframeKeyPrefix = "navigationBarTransition."

/// Draws what a bar transition shows once for both bars: the backdrop and the morphing row.
public protocol NavigationBarTransitionRenderer: AnyObject {
    /// Below both bars' contents.
    var backdropView: UIView { get }
    /// Above both.
    var rowView: UIView { get }
    /// `bottomFrame`/`topFrame`: the two contents' frames in the transition layer.
    func update(size: CGSize, fraction: CGFloat, bottomFrame: CGRect, topFrame: CGRect, transition: ContainedViewLayoutTransition)
    /// The transition runs on the render server along `timeline`: bake what is drawn per fraction (the backdrop, the
    /// row's alpha) as keyframes on the timeline's clock. `bottomFrame`/`topFrame` as in `update`.
    func animate(size: CGSize, timeline: NavigationTransitionTimeline, bottomFrame: CGRect, topFrame: CGRect)
    /// The transition starts, after the first `update`: a swipe (`isInteractive`) or not, ending on the top bar
    /// (`toTop`, a push) or on the bottom one. Glass that runs on its own springs starts here, as UIKit's does.
    func beginTransition(isInteractive: Bool, toTop: Bool)
    /// A swipe was let go: it ends on the top bar (`towardTop`, a cancelled pop) or on the bottom one.
    func endInteraction(towardTop: Bool)
    /// A swipe back took over the transition while it ran toward the top bar (a push, or a pop springing back). A
    /// dragging finger does not move the glass; it carries on as it was until the release.
    func beginInteraction()
    /// Whether the glass is still animating on its own springs when the screens' transition ends. It then stays above
    /// the bar the transition ended on until it settles, and `glassSettled` is called then.
    var isGlassAnimating: Bool { get }
    var glassSettled: (() -> Void)? { get set }
    /// The transition's glass is gone: at the transition's end, or at the end of its linger. Whatever the renderer
    /// borrowed from the bars goes back to them.
    func end()
    /// What another transition took from the lower bar (an expansion: the chat's pill and avatar): the morph leaves it
    /// out.
    func updateExclusions(bottom: NavigationBarTransitionExclusions)
}

public extension NavigationBarTransitionRenderer {
    func beginTransition(isInteractive: Bool, toTop: Bool) {
    }

    func endInteraction(towardTop: Bool) {
    }

    func beginInteraction() {
    }

    func end() {
    }

    func updateExclusions(bottom: NavigationBarTransitionExclusions) {
    }

    var isGlassAnimating: Bool {
        return false
    }

    var glassSettled: (() -> Void)? {
        get {
            return nil
        }
        set {
        }
    }
}

/// Draws the shared parts of a bar transition; the app sets it (Display cannot build a bar). Nil, or a nil result:
/// the bars slide with their screens.
public var defaultNavigationBarTransitionRenderer: ((_ bottom: NavigationBarTransitionSource, _ top: NavigationBarTransitionSource) -> NavigationBarTransitionRenderer?)?

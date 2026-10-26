import Foundation
import UIKit
import AsyncDisplayKit

/// How a push or a pop moves its two screens.
public enum NavigationTransitionStyle {
    /// UIKit's slide.
    case slide
    /// The upper screen grows out of a glass shape on the lower one (a chat's title pill into its profile), drawn by
    /// this renderer.
    case expand(NavigationExpansionRenderer)
}

public enum NavigationExpansionOperation: Equatable {
    case push
    case pop
    case interactivePop
}

/// The lower screen's side of an expansion (the chat): opaque to Display, read by the renderer.
public protocol NavigationExpansionSource: AnyObject {
}

/// The upper screen's side (the profile).
public protocol NavigationExpansionDestination: AnyObject {
}

/// The upper screen as a card under a swipe back (`CardPose`, the prototype's SwipeBack.swift): it shrinks around the
/// touch point, which stays under the finger. `weight` is how much of it holds: 1 under the finger; after a release that
/// closes, `t(2 − t)` of the closing clock, so the card ends in the origin instead of growing back.
public struct NavigationExpansionCardPose: Equatable {
    public var dx: CGFloat
    public var dy: CGFloat
    public var anchor: CGPoint
    public var weight: CGFloat
    public var isVertical: Bool

    public static let none = NavigationExpansionCardPose(dx: 0.0, dy: 0.0, anchor: CGPoint(), weight: 0.0)
    /// The smallest scale under the finger.
    public static let minScale: CGFloat = 0.45

    public init(dx: CGFloat, dy: CGFloat, anchor: CGPoint, weight: CGFloat, isVertical: Bool = false) {
        self.dx = dx
        self.dy = dy
        self.anchor = anchor
        self.weight = weight
        self.isVertical = isVertical
    }

    private var travel: CGFloat {
        return max(self.isVertical ? self.dy : self.dx, 0.0)
    }

    public var isActive: Bool {
        return (self.dx != 0.0 || self.dy != 0.0) && self.weight > 0.0
    }

    /// 1 − 0.7 of the travel over the width, not below `minScale` (measured from iMessage: 0.85 at 76 pt, 0.6 at
    /// 227 pt).
    public func scale(width: CGFloat) -> CGFloat {
        let s = max(1.0 - 0.7 * self.travel / max(1.0, width), NavigationExpansionCardPose.minScale)
        return 1.0 - (1.0 - s) * self.weight
    }

    /// How far the upper screen has gone into the card (0…1): the lower screen takes the status bar and the back
    /// button's look by it.
    public func fade(width: CGFloat) -> CGFloat {
        return min(self.travel / (max(1.0, width) * 0.35), 1.0) * self.weight
    }

    public func transform(width: CGFloat) -> CGAffineTransform {
        guard self.isActive else {
            return .identity
        }
        let s = self.scale(width: width)
        return CGAffineTransform(translationX: self.anchor.x + self.dx * self.weight, y: self.anchor.y + self.dy * self.weight).scaledBy(x: s, y: s).translatedBy(x: -self.anchor.x, y: -self.anchor.y)
    }

    public func released(_ weight: CGFloat) -> NavigationExpansionCardPose {
        var pose = self
        pose.weight = weight
        return pose
    }

    /// A released pose's weight while the closing clock runs from 1 to 0.
    public static func releasedWeight(time: CGFloat) -> CGFloat {
        let t = min(max(time, 0.0), 1.0)
        return t * (2.0 - t)
    }
}

/// An expansion running on the render server, sampled once.
public struct NavigationExpansionTimeline {
    public let timing: NavigationKeyframeTiming
    /// The clock at each of `timing.sampleTimes`: 0 the lower screen, 1 the upper, past both on the overshoot.
    public let times: [CGFloat]
    /// Which windows the clock runs (the opening's, kept by a reversed push).
    public let isOpening: Bool
    /// The card pose at each sample.
    public let poses: [NavigationExpansionCardPose]
    public let animationTime: () -> Double
    public let reinstallTiming: () -> NavigationKeyframeTiming?
    public let schedule: (_ animationTime: Double, _ action: @escaping () -> Void) -> Void

    public init(timing: NavigationKeyframeTiming, times: [CGFloat], isOpening: Bool, poses: [NavigationExpansionCardPose], animationTime: @escaping () -> Double, reinstallTiming: @escaping () -> NavigationKeyframeTiming?, schedule: @escaping (Double, @escaping () -> Void) -> Void) {
        self.timing = timing
        self.times = times
        self.isOpening = isOpening
        self.poses = poses
        self.animationTime = animationTime
        self.reinstallTiming = reinstallTiming
        self.schedule = schedule
    }
}

/// Draws an expansion: the app sets it (Display cannot build glass).
public protocol NavigationExpansionRenderer: AnyObject {
    var openSpring: NavigationTransitionSpring { get }
    var closeSpring: NavigationTransitionSpring { get }
    /// Above both screens, below the bars' transition layer (the labels, the photo).
    var view: UIView { get }
    /// Below the upper screen, above the lower one (the drops' glass, the card's shadow): the upper screen's background
    /// paints over it, as the prototype's paint covers the drop.
    var underView: UIView { get }
    /// What it takes from the lower bar, which the bar morph then does not draw.
    var barExclusions: NavigationBarTransitionExclusions { get }
    /// The clock value at which the upper bar's own items start materializing on opening.
    var barGlassStart: CGFloat { get }
    /// The upper bar's back button, in `view`'s coordinates: during an expanding push it alone takes a touch.
    var backButtonFrame: CGRect? { get }
    /// Starts: lends both screens' views and masks the upper one, at `time` in `isOpening`'s windows.
    func begin(topView: UIView, bottomView: UIView, size: CGSize, time: CGFloat, isOpening: Bool)
    /// One frame, set directly (a finger moving the card).
    func update(time: CGFloat, isOpening: Bool, pose: NavigationExpansionCardPose)
    /// The transition runs on the render server along `timeline`.
    func animate(timeline: NavigationExpansionTimeline)
    /// The bars' fraction at this clock value (0 the lower bar, 1 the upper).
    func barFraction(time: CGFloat, isOpening: Bool) -> CGFloat
    /// Ends: every lent view goes back. `atTop`: it ended on the upper screen.
    func end(atTop: Bool)
}

/// Builds the renderer for a source and a destination; nil, or a nil result, gives the slide. The app sets it.
public var defaultNavigationExpansionRenderer: ((_ source: NavigationExpansionSource, _ destination: NavigationExpansionDestination, _ operation: NavigationExpansionOperation) -> NavigationExpansionRenderer?)?

/// The style of a push or pop between `top` and `bottom`: an expansion when both screens take part and the app draws
/// it, in a compact, full-screen, non-split stack with Reduce Motion off; otherwise the slide. Read once, when the
/// transition starts.
public func navigationTransitionStyle(top: ViewController, bottom: ViewController, operation: NavigationExpansionOperation, isFlat: Bool, layout: ContainerViewLayout, reduceMotion: Bool) -> NavigationTransitionStyle {
    guard !reduceMotion, !isFlat, !layout.presentedInFormSheet, case .compact = layout.metrics.widthClass else {
        return .slide
    }
    guard let destination = top.navigationExpansionDestination(below: bottom, operation: operation), let source = bottom.navigationExpansionSource(above: top, operation: operation), let makeRenderer = defaultNavigationExpansionRenderer, let renderer = makeRenderer(source, destination, operation) else {
        return .slide
    }
    return .expand(renderer)
}

/// Whether a released swipe closes the expansion: past 0.3 of the width, or flung — projected past half of it (UIKit's
/// normal deceleration, 0.998 per millisecond) at over 300 pt/s.
public func navigationExpansionCommits(dx: CGFloat, velocity: CGFloat, width: CGFloat) -> Bool {
    let projected = dx + velocity * 0.998 / (1.0 - 0.998) / 1000.0
    return dx > width * 0.3 || (projected > width * 0.5 && velocity > 300.0)
}

public extension NavigationSpringRest {
    /// An expansion's clock: the prototype's `Motion` rule (within 0.0005, slower than twenty times that).
    static let expansion = NavigationSpringRest(value: 0.0005, velocity: 0.01)
}

extension NavigationTransitionStyle {
    /// The expansion's open and close springs' durations (nil: the slide).
    var expansionOpenResponse: CGFloat? {
        if case let .expand(renderer) = self {
            return renderer.openSpring.response
        }
        return nil
    }

    var expansionCloseResponse: CGFloat? {
        if case let .expand(renderer) = self {
            return renderer.closeSpring.response
        }
        return nil
    }
}

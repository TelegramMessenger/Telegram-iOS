import UIKit

/// The seam between `CoreVirtualListView` (virtualization/layout/animation) and the scroll
/// engine that provides the scroll position + physics (drag, momentum, rubber-band, bounce).
/// Physics-semantic on purpose: an offset, programmatic writes, edges, and a per-frame
/// user-scroll callback — NOT `UIScrollView`'s `bounds`/`contentSize` vocabulary. The first
/// implementation (`UIKitScrollEngine`) wraps `UIScrollView`; a later one drives `ScrollPhysics`.

/// A baked scroll trajectory the RENDER SERVER is playing, published by engines that move content
/// with a keyframe animation rather than per-frame main-thread writes.
///
/// A consumer that positions anything against the scroll offset must compose against this rather than
/// sampling `offset` per frame: during a flight `offset` is advanced by a main-thread sampling tick
/// while the content is moved by Core Animation, so the two run on different clocks. Composing against
/// the trajectory's OWN vertices — rather than resampling it — is what keeps a composed animation in
/// exact phase with the content's.
struct ScrollFlight {
    let trajectory: Trajectory
    /// Layer-local time at which the trajectory's `t = 0` plays.
    let beginTime: CFTimeInterval
    /// Coordinate shift accrued since the trajectory was baked.
    ///
    /// The trajectory's own offsets are in the base it was baked in. Window rebalancing re-bases the
    /// container mid-flight (`applyShift`), so a consumer positioning anything against the trajectory
    /// must add this — `trajectory.finalOffset + coordinateShift` is where the flight actually comes
    /// to rest, which is what `KeyframeFlight.settledOffset` reports. Engines republish whenever it
    /// changes.
    var coordinateShift: CGFloat = 0

    /// The flight's resting place in CURRENT list coordinates.
    var settledOffset: CGFloat { trajectory.finalOffset + coordinateShift }

    /// A trajectory sample's offset in CURRENT list coordinates.
    func offset(atSampleIndex index: Int) -> CGFloat {
        trajectory.samples[index].offset + coordinateShift
    }
}

/// The seam between `CoreVirtualListView` and its scroll engine (see the file header).
protocol ScrollEngine: AnyObject {
    /// Current scroll position in the engine's offset coordinate.
    var offset: CGFloat { get }

    /// Fires when a baked flight starts, is re-baked or spliced, or ends (`nil`). Engines that move
    /// content on the main thread never fire it: their per-frame consumers are already in lockstep,
    /// so `nil` forever is the honest answer rather than a missing feature.
    var onFlightChanged: ((ScrollFlight?) -> Void)? { get set }

    /// Fires ONLY on user-driven scroll (drag/momentum/bounce). The programmatic writes below
    /// never re-enter this — the adapter absorbs the old `CoreVirtualListView.isUpdating` guard.
    var onScroll: ((_ offset: CGFloat) -> Void)? { get set }

    /// Fires when the user STARTS an interactive drag (the pan gesture reaches `.began`). Not fired for
    /// programmatic writes or momentum/bounce. The UIKit analogue is
    /// `UIScrollViewDelegate.scrollViewWillBeginDragging`.
    var onWillBeginDragging: (() -> Void)? { get set }

    /// Fires when the user's interactive drag ENDS (the pan gesture reaches `.ended`/`.cancelled`),
    /// whether or not momentum follows — so `onWillBeginDragging`/`onDidEndDragging` bracket exactly the
    /// finger-down interval, and NOT the momentum phase after it. Not fired for programmatic writes, nor
    /// when deceleration or a bounce finishes. The UIKit analogue is
    /// `UIScrollViewDelegate.scrollViewDidEndDragging(_:willDecelerate:)`.
    var onDidEndDragging: (() -> Void)? { get set }

    /// Consulted once per interactive release, BEFORE the engine decides whether momentum follows,
    /// with the recognizer's release velocity. Returning `true` releases as if the finger had come to
    /// rest: no fling, while an overscrolled release still springs back to the edge.
    ///
    /// It exists because a release can be claimed by something outside the list. The chat's history is
    /// dragged by the same finger that interactively dismisses the keyboard, and that dismissal is
    /// decided in touch DELIVERY — before the pan's `.ended` reaches an engine in action dispatch — so
    /// by the time this is consulted the host already knows the momentum was spent elsewhere.
    ///
    /// Deliberately a pull, not a latch the host arms: there is exactly one release to answer for and
    /// no flag to leak into the next gesture. `ListViewImpl.shouldStopScrolling`
    /// (`Display/Source/ListView.swift:266`) is the same hook on the other backend, consulted in
    /// `scrollViewWillEndDragging`.
    var shouldStopScrollingOnRelease: ((_ velocity: CGFloat) -> Bool)? { get set }

    /// Programmatic absolute write (the old `setBoundsOriginY` + the fast-flick delta clamp).
    func setOffset(_ y: CGFloat)

    /// Stop any deceleration/momentum, leaving the content exactly where it is PRESENTED. Idempotent, and
    /// never fires `onScroll`.
    ///
    /// This exists so a caller never has to write `setOffset(offset)` to halt. Under a `.keyframe` flight
    /// that idiom is a trap: `offset` is per-frame stable, the call internally catches the flight at its
    /// true instantaneous position, and then the stale argument overwrites it — so the halt lands on the
    /// last sampling tick's position instead of the current one. See
    /// docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md.
    func haltMotionInPlace()

    /// Re-anchor an in-progress drag so the content stays where it is across an edge change the
    /// caller just declared through `setEdges`. A drag maps finger travel to content through the
    /// rubber band, so moving an edge re-scales that mapping and the content jumps on the next drag
    /// frame unless the anchor moves with it. No-op outside a drag, and no-op for an engine whose
    /// drag it does not own.
    func reanchorDragToCurrentPosition()

    /// Re-anchor the reported `offset` on what the render server is currently presenting, without disturbing
    /// any animation. Call once at the top of a mutation pass so the pass reads a CURRENT position: `offset`
    /// is per-frame stable by contract, which makes it stale by however long the main thread has been busy
    /// since the last sampling tick. Continuity does not require currency (a single consistent value cancels
    /// algebraically), but membership, the anchor witness and the overscroll gate all do. No-op for an engine
    /// whose offset is already the presented value.
    func syncToPresentedPosition()

    /// Programmatic relative shift — the rebalance reposition (the old `bounds.origin.y += shift`).
    func applyShift(_ dy: CGFloat)

    /// Declares the scrollable extent as edges; either may be open (`nil` = unbounded / no
    /// bounce on that side). Replaces `contentSize`. Offsets are in the engine's coordinate.
    func setEdges(min: CGFloat?, max: CGFloat?)

    /// Where the list parents `container` and exit snapshots. Snapshots must NOT ride container
    /// repositioning, so they sit here (above the container), as today.
    var contentHost: UIView { get }

    /// The container origin (in the engine's offset coordinate) at which to park a loaded window of
    /// `windowHeight`, given which edges are loaded. The engine parks the strip so any OPEN side has
    /// room to scroll into: the `UIScrollView` adapter parks far from its [0, contentSize] clamp; the
    /// clampless physics core parks in a natural small coordinate. Top-loaded ⇒ 0 in every engine.
    func containerOrigin(windowHeight: CGFloat, topLoaded: Bool, bottomLoaded: Bool) -> CGFloat
}

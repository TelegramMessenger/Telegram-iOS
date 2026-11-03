import UIKit

/// The injected-time rebake orchestrator for a keyframe deceleration over a `PhysicsScrollCore`.
/// Shared by `PhysicsScrollEngine` (real layer-local time + CA playback) and `TestScrollEngine`
/// (`SyntheticClock`, no CA), so both run the SAME logic. Holds the live `Trajectory`, its `startTime`
/// (caller's time base), a `generation` (stale-completion guard), and the persistent `coordinateShift`.
/// No UIKit drawing, no `CADisplayLink`, no CA — the engines own those.
/// See docs/plans/2026-05-26-keyframe-list-deceleration-design.md §3.
final class KeyframeFlight {
    private let core: PhysicsScrollCore
    private(set) var trajectory: Trajectory
    private(set) var startTime: TimeInterval
    /// Bumped once per REBAKE within THIS flight (so a rebaked CA animation's stale completion is
    /// guarded). Cross-flight staleness (launch/catch) is the ENGINE's responsibility — a fresh flight
    /// instance resets this to 0, so an engine must NOT use it as a whole-lifecycle guard on its own.
    private(set) var generation: Int = 0

    /// Accumulated coordinate translation: (list coordinate) − (trajectory coordinate) since the
    /// trajectory was last baked. PERSISTS across ticks. A pure coordinate shift (container re-base)
    /// is a rigid translation of the decel path — it changes no SHAPE — so it does NOT rebake/re-emit:
    /// `noteShift` just accumulates here, and the engine slides the layer model by the same `dy` so the
    /// already-playing additive animation rides along. (Re-emitting the animation on every shift — which
    /// happens every frame at scroll speed — was the residual scroll jank.) Only an edge/shape change
    /// rebakes; the splice then folds this into the new trajectory's coordinate and resets it to 0.
    /// Internal so an engine can publish it: a consumer composing against `trajectory` needs the
    /// base its offsets are in. See `ScrollFlight.coordinateShift`.
    private(set) var coordinateShift: CGFloat = 0
    /// A real edge change invalidates the baked future until a rebake consumes it. This is deliberately
    /// not tick-local: `applyChanges` can call `setEdges` between sampling ticks, and the next
    /// `beginTick` must preserve that notification while it reseeds the live state.
    private var edgeRebakePending = false
    var hasPendingEdgeRebake: Bool { edgeRebakePending }

    /// The declared edges the live `trajectory` was baked against, in the trajectory's own coordinate.
    /// Together with the trajectory these ARE the parameters of the animation the engine has in flight: the
    /// path is a deterministic function of the seeded `(offset, velocity)` — which by construction stays ON
    /// this path, `beginTick` reseeds from it — plus the declared edges. So the ONLY thing a mid-flight
    /// change can alter is how the edges sit relative to the path. Refreshed at every bake.
    private var bakedEdges: (min: CGFloat?, max: CGFloat?) = (nil, nil)
    /// Layer-local time of the last `beginTick`, i.e. how far the played path has been consumed. A rebake
    /// only ever replaces the FUTURE, so this is where the "can an edge still reach this path" test starts.
    /// `nil` until the first tick (then the whole path is future) and never ahead of the caller's real
    /// clock, so it can only ever over-report the remaining band — a rebake too many, never one missed.
    private var lastTickTime: TimeInterval?

    /// Clearance required before an edge counts as untouched by a path: the physics' own settle tolerance
    /// (`Deceleration.settleTolerance`, 0.5px — private there). A path that merely reaches an edge already
    /// engaged the spring and settles within that band of it, so the band keeps a bounce from reading as a
    /// free coast.
    private static let edgeClearance: CGFloat = 0.5

    init(core: PhysicsScrollCore, startTime: TimeInterval) {
        self.core = core
        self.startTime = startTime
        // bakeTrajectory → Trajectory.build requires a `.decelerating` axis (post-endDrag). The caller
        // (engine) must construct a flight only after endDrag returned .decelerate.
        assert(core.isDecelerating, "KeyframeFlight must be built from a core in .decelerating state")
        self.trajectory = core.bakeTrajectory()
        self.bakedEdges = core.edges
    }

    var duration: TimeInterval { trajectory.duration }
    func isComplete(now: TimeInterval) -> Bool { now - startTime >= trajectory.duration }

    /// Live scroll offset (LIST coordinate) at `now` — the trajectory sample re-based by every shift
    /// accumulated since the last bake.
    func liveOffset(now: TimeInterval) -> CGFloat { trajectory.offset(at: now - startTime) + coordinateShift }
    /// Velocity is shift-invariant — a rigid re-base moves position only (ScrollAxis.shift leaves
    /// velocity untouched), so this does NOT add `coordinateShift` (unlike `liveOffset`).
    func liveVelocity(now: TimeInterval) -> CGFloat { trajectory.velocity(at: now - startTime) }
    /// Where the flight comes to rest, in the CURRENT (list) coordinate.
    var settledOffset: CGFloat { trajectory.finalOffset + coordinateShift }

    /// Start of a sampling tick: re-anchor the core's decel state at the live LIST-coordinate sample (so
    /// a subsequent `applyShift`/`setEdges` composes on it). Does NOT reset `coordinateShift` or a
    /// pending edge invalidation — both persist until an edge-change rebake folds them in.
    func beginTick(now: TimeInterval) {
        lastTickTime = now
        core.reseedDeceleration(offset: liveOffset(now: now), velocity: liveVelocity(now: now))
    }

    /// The list re-based the coordinate this tick (container repositioned). A pure rigid translation —
    /// the decel SHAPE is unchanged — so this does NOT request a rebake. The engine slides the layer
    /// model by the same `dy`; the in-flight additive animation keeps playing, just translated.
    func noteShift(_ dy: CGFloat) { coordinateShift += dy }

    /// The list changed a bounce edge this tick (or re-based the coordinate while a finite edge stayed
    /// put). Requests a rebake/re-emit only when that can actually change the SHAPE of this flight: an edge
    /// the path has yet to reach takes no part in the motion that is left, so re-baking against it would
    /// hand the render server the animation it is already playing. `setEdges` reports EVERY declared change, and
    /// during virtualization most of them move a content edge far from a coasting flick — re-emitting for
    /// those is the same CA churn `noteShift` exists to avoid. The engine calls this with `core` already
    /// holding the new edges.
    func noteEdgesChanged() {
        if canChangeRemainingMotion(newEdges: core.edges) {
            edgeRebakePending = true
        }
    }

    /// Whether the declared edges can still alter what is LEFT of the baked path. Two ways in: the band the
    /// path has yet to cover reaches the edges it was baked against (a bounce that is still to come, and any
    /// edge move reshapes it), or it reaches the newly declared ones. The baked band is in the trajectory
    /// coordinate, so the freshly declared edges — which the list states in the CURRENT coordinate — are
    /// compared against the band re-based by `coordinateShift`. Only ever RAISES the pending flag; a real
    /// invalidation stays durable until a rebake consumes it.
    private func canChangeRemainingMotion(newEdges: (min: CGFloat?, max: CGFloat?)) -> Bool {
        let remaining = trajectory.offsetExtent(from: (lastTickTime ?? startTime) - startTime)
        if Self.edgesReach(bakedEdges, extent: remaining) { return true }
        return Self.edgesReach(newEdges, extent: (remaining.min + coordinateShift,
                                                 remaining.max + coordinateShift))
    }

    /// Whether either declared edge takes part in a path occupying `extent`. `nil` is an open side —
    /// `PhysicsScrollCore` gives it a far sentinel, i.e. unreachable by construction.
    private static func edgesReach(_ edges: (min: CGFloat?, max: CGFloat?),
                                   extent: (min: CGFloat, max: CGFloat)) -> Bool {
        if let lo = edges.min, extent.min <= lo + edgeClearance { return true }
        if let hi = edges.max, extent.max >= hi - edgeClearance { return true }
        return false
    }

    /// How to stop this flight at `stopTime` (caller's time base) WITHOUT the content ever stepping
    /// backward: the live path truncated there, plus the LIST-coordinate offset it comes to rest at.
    ///
    /// A catch cannot take effect at the instant it is decided. The layer write and the animation removal
    /// travel in one transaction, and the pipeline presents that transaction at the next frame it can
    /// produce — after the rest of the main-thread turn and the commit-to-display delay. Until it lands
    /// the render server keeps playing the flight, so freezing the list at `liveOffset(now:)` hands it a
    /// value the screen has already passed, and it snaps back by `velocity × (that gap)`. Measured on the
    /// shipping physics: 40pt one frame late, 79pt two frames late, off a 3000 pt/s release. The gap is
    /// main-thread cost plus pipeline latency, which is precisely what grows on a slower device.
    ///
    /// Replayed on this flight's own `startTime`, the truncated path is EXACTLY the one in flight up to
    /// `stopTime` (`Trajectory.truncated`), so whichever frame the swap lands on presents the same value
    /// it would have anyway — and after `stopTime` it holds at the rest offset. The engine therefore
    /// swaps animations rather than removing one, the same continuous-swap idiom `rebakeIfNeeded` +
    /// `reemitFlightAnimation` already use for a mid-flight rebake. Overshooting `stopTime` costs a few
    /// milliseconds of the flight's own remaining motion; undershooting it is the backward step, so the
    /// caller is expected to bias late.
    ///
    /// `nil` when there is no path left to play (the stop is at or before this flight's launch, or the
    /// flight is already over) — the caller falls back to removing the animation, which is exact there
    /// because a settled flight presents its rest offset already.
    func braked(stoppingAt stopTime: TimeInterval) -> (offset: CGFloat, trajectory: Trajectory)? {
        let cut = trajectory.truncated(at: stopTime - startTime)
        guard cut.duration > 1e-6, cut.samples.count >= 2 else { return nil }
        // `cut.finalOffset + coordinateShift == liveOffset(now: stopTime)` by construction: same
        // trajectory coordinate, and truncation only drops samples after `stopTime`.
        return (cut.finalOffset + coordinateShift, cut)
    }

    /// After `onScroll`/rebalance: if an edge changed, rebake+splice (a pure shift does not get here —
    /// it rode the model translation). Returns true if rebaked (the engine then re-emits the CA animation
    /// from `trajectory` at `startTime`). The core already reflects the live LIST-coordinate state
    /// (beginTick) plus the shift/edges the list applied this tick.
    @discardableResult
    func rebakeIfNeeded(now: TimeInterval) -> Bool {
        guard edgeRebakePending else { return false }
        // The per-tick protocol requires beginTick(now:) to have reseeded the core this tick (which
        // sets phase = .decelerating), so bakeTrajectory's precondition holds. Tripwire if miswired.
        assert(core.isDecelerating, "rebakeIfNeeded requires beginTick to have reseeded the core this tick")
        let future = core.bakeTrajectory()                    // from the re-based / re-edged live state
        let spliced = Trajectory.spliced(current: trajectory, prevBeginTime: startTime, now: now,
                                         future: future, shift: coordinateShift)
        trajectory = spliced.trajectory
        startTime = spliced.beginTime
        coordinateShift = 0                                   // folded into the new trajectory's coordinate
        bakedEdges = core.edges                               // what the new path was shaped by (see noteEdgesChanged)
        edgeRebakePending = false
        generation &+= 1
        return true
    }
}

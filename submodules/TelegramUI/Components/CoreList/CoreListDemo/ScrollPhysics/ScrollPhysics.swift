import CoreGraphics
import Foundation // log

/// One axis of UIScrollView's scroll state machine. See analysis doc §1–§6.
/// `velocity` is points/millisecond. Pixel-rounded offsets are returned by `step`;
/// the internal `offset` stays full-precision across frames (matching the integrator).
struct ScrollAxis {
    enum Phase { case idle, dragging, decelerating }

    // Config
    private(set) var min: CGFloat
    private(set) var max: CGFloat
    let range: CGFloat
    let rate: CGFloat
    let lnRate: CGFloat
    let scale: CGFloat
    /// `_fastScrollMultiplier`, the free-deceleration distance multiplier. Mutable because the
    /// integrator itself clears it on reaching the spring or settling (`0x17a87bc` / `0x17a8844`),
    /// and `Trajectory.build` needs to observe WHEN that happened to re-time it onto a baked path.
    var vScale: CGFloat
    let c: CGFloat

    // State
    private(set) var offset: CGFloat
    private(set) var velocity: CGFloat = 0
    private var dragStartOffset: CGFloat = 0
    /// The un-banded finger position the last `drag()` proposed. Kept so the drag can be re-anchored
    /// against moved edges without knowing the recognizer's cumulative translation.
    private var lastProposedOffset: CGFloat = 0
    private(set) var phase: Phase = .idle

    init(offset: CGFloat, min: CGFloat, max: CGFloat, range: CGFloat,
         rate: CGFloat, scale: CGFloat, vScale: CGFloat = 1, c: CGFloat = RubberBand.touchCoefficient) {
        self.offset = offset
        self.min = min; self.max = max; self.range = range
        self.rate = rate; self.lnRate = log(rate)
        self.scale = scale; self.vScale = vScale; self.c = c
    }

    mutating func beginDrag() {
        dragStartOffset = offset
        lastProposedOffset = offset
        velocity = 0
        phase = .dragging
    }

    /// `translation` is the pan recognizer's cumulative value in points. Gesture VELOCITY is not
    /// this type's business — `ReleaseDecision` owns it, because the release decision it feeds is
    /// two-dimensional (the threshold is `vx² + vy²`, the low-pass guard tests both axes jointly)
    /// and cannot be answered per axis.
    mutating func drag(translation: CGFloat) {
        let proposed = dragStartOffset - translation                       // §3
        lastProposedOffset = proposed
        offset = RubberBand.offset(proposed, min: min, max: max, range: range, c: c) // §1
    }

    /// Re-anchor an in-progress drag so the CURRENT offset survives an edge change: the anchor moves
    /// by exactly the difference between the un-banded pre-images of this offset under the new edges
    /// and the old ones, so the next `drag()` reproduces where the content is now and carries on from
    /// there. No-op outside a drag.
    ///
    /// `setBounds` deliberately disturbs nothing, which is right when the caller wants the band
    /// re-evaluated. It is wrong when an edge moves under a finger that is holding content still:
    /// the mapping from finger to content silently re-scales and the content jumps one frame later.
    /// The chat moves the newest edge mid-drag to hold its overscroll action open, and needs this.
    mutating func reanchorDragToCurrentOffset() {
        guard phase == .dragging else { return }
        let preImage = RubberBand.inverse(offset, min: min, max: max, range: range, c: c)
        dragStartOffset += preImage - lastProposedOffset
        lastProposedOffset = preImage
    }

    /// Enter deceleration at a release velocity `ReleaseDecision` already decided (pts/ms).
    /// The caller is responsible for the release DECISION; this only installs its result.
    mutating func applyRelease(velocity: CGFloat) {
        self.velocity = velocity
        phase = .decelerating
    }

    /// Advance one deceleration frame; returns the pixel-rounded offset to write, whether settled,
    /// and whether this frame ENDED the deceleration (entered the spring or settled), which is the
    /// integrator's own fast-scroll reset. Call only after `applyRelease(velocity:)`.
    mutating func step(dtMs: CGFloat) -> (written: CGFloat, settled: Bool, endedDeceleration: Bool) {
        // "Ended a deceleration" means one that was actually RUNNING. An axis already at rest cannot
        // end anything, and saying it does is not pedantry: CoreList pins x to a dead axis
        // (offset 0, min == max == 0, velocity 0), which is in-bounds and below the velocity floor, so
        // it reports `settled` on every step. Combined with `||` in `ScrollPhysics.step` that made the
        // pair ALWAYS report a deceleration ending — which cleared the fast-scroll streak on the first
        // step of every flight and is why the repeated-flick multiplier could never reach the three
        // consecutive flicks it needs to grow.
        // Running == decelerating AND not already at rest — the exact complement of `settled()`:
        // above the integrator's velocity floor, or displaced past an edge and still springing back.
        let outOfBounds = offset < min || offset > Swift.max(max, min)
        let wasRunning = phase == .decelerating
            && (abs(velocity) >= Deceleration.velocityFloor || outOfBounds)
        // Deceleration is a single-frame value type; reconstruct it each frame from the live
        // full-precision offset/velocity. Do NOT hoist it into stored state — that would discard
        // the inter-frame precision the integrator depends on.
        var d = Deceleration(offset: offset, velocity: velocity, min: min, max: max,
                             rate: rate, vScale: vScale)
        let (settled, endedDeceleration) = d.step(dtMs: dtMs)
        offset = d.offset                                                   // keep full precision
        velocity = d.velocity
        if settled { phase = .idle }
        let reallyEnded = wasRunning && endedDeceleration
        if reallyEnded { vScale = 1 }                                       // 0x17a87bc / 0x17a8844
        return (OffsetMath.pixelRound(offset, scale: scale), settled, reallyEnded) // §6 write rounds
    }

    /// Move the bounce points without disturbing any dynamic state (offset/velocity/phase/
    /// dragStartOffset). The analogue of a UIScrollView `contentSize` change — lets a
    /// scroll engine declare a freshly-loaded edge mid-interaction. Changes no physics formula.
    /// `range` (the viewport dimension, not the content span) is intentionally left unchanged.
    mutating func setBounds(min: CGFloat, max: CGFloat) {
        self.min = min
        self.max = max
    }

    /// Rigidly re-base the axis: the offset AND the in-progress drag anchor move together, so a
    /// rebalance reposition mid-drag/mid-decel composes (the next `drag()` recomputes from the
    /// shifted anchor, and a decel continues from the shifted offset with velocity untouched). The
    /// analogue of a UIScrollView `bounds.origin.y` shift.
    mutating func shift(by dy: CGFloat) {
        offset += dy
        dragStartOffset += dy
        lastProposedOffset += dy
    }

    /// Re-anchor a deceleration at an explicit offset/velocity under the current edges. The analogue
    /// of catching an in-flight decel and relaunching from the live sample — the keyframe rebake's
    /// substrate. `velocity` is the integrator's unit (pts/ms). Sets phase to `.decelerating`; the
    /// next `step` continues from here. Changes no physics formula. Sets only the `step`/`build`
    /// substate (offset/velocity/phase) — it does NOT update `dragStartOffset`, so a caller must go
    /// straight into `step`/`build` and never follow a reseed with `drag()`/`applyRelease()`.
    mutating func reseedDeceleration(offset: CGFloat, velocity: CGFloat) {
        self.offset = offset
        self.velocity = velocity
        self.phase = .decelerating
    }

    func projectedTarget() -> CGFloat {
        Projection.target(offset: offset, velocity: velocity, lnRate: lnRate, vScale: vScale)
    }
}

/// Two-axis UIScrollView physics. Each axis is independent.
struct ScrollPhysics {
    var x: ScrollAxis
    var y: ScrollAxis

    mutating func beginDrag() { x.beginDrag(); y.beginDrag() }

    /// Install a release velocity `ReleaseDecision` already decided, on both axes.
    mutating func applyRelease(velocity: CGPoint) {
        x.applyRelease(velocity: velocity.x)
        y.applyRelease(velocity: velocity.y)
    }

    mutating func drag(translation: CGPoint) {
        x.drag(translation: translation.x)
        y.drag(translation: translation.y)
    }

    mutating func reanchorDragToCurrentOffset() {
        x.reanchorDragToCurrentOffset()
        y.reanchorDragToCurrentOffset()
    }

    /// Returns the offset to write, whether BOTH axes have settled, and whether EITHER ended its
    /// deceleration this frame (the integrator's fast-scroll reset — one axis reaching an edge is
    /// enough, matching `_getBouncingDecelerationOffset` being called per axis against one ivar).
    mutating func step(dtMs: CGFloat) -> (written: CGPoint, settled: Bool, endedDeceleration: Bool) {
        let rx = x.step(dtMs: dtMs)
        let ry = y.step(dtMs: dtMs)
        return (CGPoint(x: rx.written, y: ry.written),
                rx.settled && ry.settled,
                rx.endedDeceleration || ry.endedDeceleration)
    }
}

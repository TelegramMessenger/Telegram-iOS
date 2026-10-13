import UIKit
@testable import CoreListDemo

/// Deterministic `ScrollEngine` driving the REAL `ScrollPhysics` core through a `SyntheticClock` —
/// no pan recognizer, no `CADisplayLink`. Higher fidelity than `TestableScrollView` (which hand-rolls
/// spring/decel): new tests validate the list against the actual reverse-engineered physics. Wraps
/// the same `PhysicsScrollCore` the production `PhysicsScrollEngine` does, so the shipping glue is
/// under test.
final class TestScrollEngine: ScrollEngine {
    let host = UIView()
    let clock: SyntheticClock
    private let core: PhysicsScrollCore

    init(clock: SyntheticClock, viewport: CGSize) {
        self.clock = clock
        host.frame = CGRect(origin: .zero, size: viewport)
        core = PhysicsScrollCore(contentHost: host)
    }

    // MARK: - Deceleration mode

    enum DecelerationMode { case stepped, keyframe }
    var decelerationMode: DecelerationMode = .stepped

    private var flight: KeyframeFlight?
    private(set) var keyframeRebakeCount = 0
    var keyframeFlightDuration: TimeInterval? { flight?.duration }
    /// Where the live flight will come to rest, in list coordinates (nil when not flying). A rebake that
    /// changes the motion moves this; one skipped as unreachable must leave it exactly as it was.
    var keyframeSettledOffset: CGFloat? { flight?.settledOffset }
    private(set) var declaredEdges: (min: CGFloat?, max: CGFloat?) = (0, 0)

    // MARK: - ScrollEngine

    /// Mirrors PhysicsScrollEngine: published only in `.keyframe` mode, at the same lifecycle points.
    var onFlightChanged: ((ScrollFlight?) -> Void)?

    var onScroll: ((CGFloat) -> Void)? {
        get { core.onScroll }
        set { core.onScroll = newValue }
    }
    var onWillBeginDragging: (() -> Void)?
    var onDidEndDragging: (() -> Void)?
    var shouldStopScrollingOnRelease: ((CGFloat) -> Bool)?
    /// Mirrors `PhysicsScrollEngine.offset`: the physics position, advanced once per frame, never a sample of
    /// the flight. See that property and the clock-free-mutation-pass spec.
    var offset: CGFloat { core.offset }
    /// TEST INSTRUMENT ONLY — the PRESENTED viewport, i.e. what the render server shows. The model is parked at
    /// the trajectory's `finalOffset` and the additive keyframe adds `offset(tᵢ) − finalOffset`
    /// (Trajectory+Keyframe.swift), so the presented bounds origin is exactly `flight.liveOffset(now:)`. This
    /// is the measuring stick for lurch tests: it must NOT go through `offset`, or a test that asserts the
    /// content did not move would pass by the measuring stick freezing with the value it measures.
    var liveViewportOffset: CGFloat { flight.map { $0.liveOffset(now: clock.now) } ?? core.offset }
    var contentHost: UIView { host }

    func setOffset(_ y: CGFloat) {
        // Mirror PhysicsScrollEngine.setOffset (file PhysicsScrollEngine.swift): catch any live
        // keyframe flight to its live offset (production: catchFlight + removeAnimation; test: same
        // shape), then idle the core's phase UNCONDITIONALLY (production: cancelDeceleration runs
        // regardless of flight; matches both keyframe-catch and stepped-decel halt paths). The 4c
        // halt idiom (§4(b)) is `engine.setOffset(engine.offset)` — a no-op offset write that
        // catches + idles as a side effect; Tasks 4-6 §4(b) halt sites rely on this to fully halt
        // motion in both modes.
        if let f = flight {
            core.setOffset(f.liveOffset(now: clock.now))   // snap physics to live BEFORE clobbering
            flight = nil
        }
        core.cancelDeceleration()                          // phase → .idle (production parity, both modes)
        core.setOffset(y)
    }
    /// Forwards to the real core, like `PhysicsScrollEngine` — this harness exists to put the
    /// shipping glue under test, and a stub here would make any list-level assertion about holding
    /// content across a mid-drag edge change pass vacuously.
    func reanchorDragToCurrentPosition() {
        core.reanchorDragToCurrentPosition()
    }

    func haltMotionInPlace() {
        // Mirrors PhysicsScrollEngine.haltMotionInPlace: catch the flight at its live position (production
        // additionally removes the CA animation), then idle the core.
        if let f = flight {
            core.setOffset(f.liveOffset(now: clock.now))
            flight = nil
        }
        core.cancelDeceleration()
    }
    func syncToPresentedPosition() {
        flight?.beginTick(now: clock.now)
    }
    func applyShift(_ dy: CGFloat) {
        if flight != nil {
            let changesShape = core.hasFiniteEdge
            host.bounds.origin.y += dy          // mirror PhysicsScrollEngine — the model rides the re-base
            core.applyShiftPhysicsOnly(dy)
            flight?.noteShift(dy)
            // Republish: a consumer composing against the trajectory must learn the new base, or it
            // keeps positioning against where the flight WOULD have landed before the re-base.
            if let f = flight {
                onFlightChanged?(ScrollFlight(trajectory: f.trajectory,
                                              beginTime: f.startTime,
                                              coordinateShift: f.coordinateShift))
            }
            if changesShape {
                flight?.noteEdgesChanged()
            }
        } else {
            core.applyShift(dy)
        }
    }
    func setEdges(min: CGFloat?, max: CGFloat?) {
        declaredEdges = (min, max)
        if core.setEdges(min: min, max: max) { flight?.noteEdgesChanged() }   // rebake only on a REAL edge change
    }
    func containerOrigin(windowHeight: CGFloat, topLoaded: Bool, bottomLoaded: Bool) -> CGFloat {
        core.containerOrigin(windowHeight: windowHeight, topLoaded: topLoaded, bottomLoaded: bottomLoaded)
    }

    // MARK: - Deterministic gesture simulation (real physics)

    var isDecelerating: Bool { flight != nil || core.isDecelerating }

    /// Recognizer velocity (pts/s) of the last `drag` this gesture, so `endDrag()` can keep its
    /// zero-argument shape while `PhysicsScrollCore` takes the fresh read UIKit makes at release.
    private var lastRecognizerVelocity: CGFloat = 0

    func beginDrag() {
        // Parity with PhysicsScrollEngine: the finger landing (`onTouchDown` → `_beginTrackingWithEvent:`)
        // is a distinct moment from the pan beginning, and it is where the fast-scroll streak is
        // carried or expired. It happens BEFORE the flight catch, as it does in production.
        core.beginTouchTracking(at: clock.now)
        onWillBeginDragging?()                                  // parity with PhysicsScrollEngine.handlePan(.began)
        if let f = flight {                                    // catch a moving flight at its live offset
            // Deliberately NOT braked. Production catches interactively with `braking: true`
            // (PhysicsScrollEngine.catchFlight), stopping a few frames ahead so the swap is continuous on
            // screen — but that lead exists only to cover a real commit-to-display pipeline, and this
            // harness has neither a render server nor a display link. `SyntheticClock` presents the model
            // instantly, so the correct lead here is zero, which is exactly this hard stop. The brake's
            // own contract is pinned at the value level in `FlightCatchContinuityTests`.
            core.setOffset(f.liveOffset(now: clock.now))
            flight = nil
            onFlightChanged?(nil)
        }
        core.beginDrag()
    }

    /// `translation`/`velocity` are recognizer-space (points, points/sec) — finger up is negative,
    /// matching `UIPanGestureRecognizer.translation/velocity(in:)`.
    func drag(translation: CGFloat, velocity: CGFloat) {
        lastRecognizerVelocity = velocity
        core.drag(translation: translation, velocity: velocity)
    }

    @discardableResult func endDrag() -> Bool {
        // Mirror PhysicsScrollEngine.applyPanUpdate(.ended): a host that claims the release is honoured
        // by releasing at zero, not by skipping `endDrag` — so an overscrolled release still bounces.
        let suppressed = shouldStopScrollingOnRelease?(lastRecognizerVelocity) ?? false
        let decelerate = core.endDrag(recognizerVelocity: suppressed ? 0.0 : lastRecognizerVelocity, at: clock.now)
        lastRecognizerVelocity = 0
        defer { onDidEndDragging?() }                            // parity with PhysicsScrollEngine.handlePan(.ended)
        if decelerate && decelerationMode == .keyframe {
            let f = KeyframeFlight(core: core, startTime: clock.now)
            flight = f
            // Mirror PhysicsScrollEngine.launchFlight: the layer model is parked at the trajectory's settled
            // endpoint because the emitted keyframe animation is ADDITIVE around it. The harness emits no CA,
            // but it must reproduce the model value or a host reading geometry through `UIView.convert`
            // cannot be tested against it — the destination-space defect is invisible otherwise.
            host.bounds.origin.y = f.trajectory.finalOffset
            onFlightChanged?(ScrollFlight(trajectory: f.trajectory, beginTime: f.startTime))
        }
        return decelerate
    }

    /// Begin a flick that sends the content offset moving at `offsetVelocity` pts/s (+down/increasing),
    /// anchored at the current offset, leaving the engine decelerating. Drive it with `tick(dt:)`.
    /// TWO zero-translation drag frames are deliberate and load-bearing: under the parity model the
    /// first is the `.began` sample and the second the first `.changed`, so `previous == latest` and
    /// the guarded low-pass yields `0.75·v + 0.25·v == v` — the same release velocity this helper
    /// produced before the parity work, which is why every suite built on it keeps its expectations.
    /// Reducing it to one frame would change that: with `previous` still zero the guard skips the
    /// blend and the release carries the raw sample. The recognizer velocity is the opposite sign of
    /// the offset velocity (the finger moves opposite the content).
    func simulateFlick(offsetVelocity v: CGFloat) {
        // Fired directly rather than by going through `beginDrag()`, which would also catch a live flight
        // and change the physics of a flick chained onto a decelerating one. This keeps the
        // will-begin/did-end pair balanced (`endDrag()` fires did-end) without altering any offset.
        onWillBeginDragging?()
        core.beginTouchTracking(at: clock.now)
        core.beginDrag()
        drag(translation: 0, velocity: -v)
        drag(translation: 0, velocity: -v)
        _ = endDrag()
    }

    /// Advance the deceleration by `dt` seconds (no-op if not decelerating). Caller advances the
    /// clock separately (mirrors `VirtualListDriver.tick`).
    func tick(dt: TimeInterval) {
        if let f = flight {
            if f.isComplete(now: clock.now), !f.hasPendingEdgeRebake {
                core.setOffset(f.settledOffset)            // settle at the LIST-coord rest (finalOffset + accrued shift)
                core.cancelDeceleration()                  // phase → .idle so isDecelerating is false
                core.noteDecelerationEnded()               // parity with PhysicsScrollEngine.finalizeFlight
                flight = nil
                onFlightChanged?(nil)
                onScroll?(core.offset)
                return
            }
            f.beginTick(now: clock.now)
            // Parity with PhysicsScrollEngine.sampleTick: a baked path has no per-frame hook, so the
            // flight's reset instant is where the integrator would have cleared the streak.
            if let reset = f.trajectory.multiplierResetTime, clock.now - f.startTime >= reset {
                core.noteDecelerationEnded()
            }
            onScroll?(f.liveOffset(now: clock.now))         // → list rebalances → applyShift/setEdges → noteShift/noteEdges
            if f.rebakeIfNeeded(now: clock.now) {
                keyframeRebakeCount += 1
                host.bounds.origin.y = f.trajectory.finalOffset   // mirror reemitFlightAnimation's re-park
                if f.isComplete(now: clock.now) {
                    core.setOffset(f.settledOffset)
                    core.cancelDeceleration()
                    core.noteDecelerationEnded()
                    flight = nil
                    onFlightChanged?(nil)
                    onScroll?(core.offset)
                } else {
                    onFlightChanged?(ScrollFlight(trajectory: f.trajectory, beginTime: f.startTime))
                }
            }
            return
        }
        guard core.isDecelerating else { return }
        _ = core.step(dtMs: CGFloat(dt * 1000))
    }
}

import UIKit

/// `ScrollEngine` driving `CoreVirtualListView` via the owned `ScrollPhysics` core (`.stepped`
/// deceleration). Drives `contentHost.bounds.origin.y` exactly like a `UIScrollView`, so the list's
/// layout math is unchanged — only the driver differs. Touch only; trackpad and `.keyframe`
/// deceleration during virtualization are future increments.
final class PhysicsScrollEngine: NSObject, ScrollEngine {
    private let host = UIView()
    private let core: PhysicsScrollCore
    private let pan = PhysicsPanGestureRecognizer(target: nil, action: nil)
    private var displayLink: CADisplayLink?
    /// Whether the pan recognized a drag this gesture (so a bare-tap touch-up can spring back without
    /// double-handling a real release, which `.ended`/`.cancelled` already handle).
    private var sawDrag = false

    /// Set when the pan was FORCED to `.began` rather than reaching it through hysteresis — by
    /// `shouldBeginImmediately` (a finger landing on moving content) or by `shouldReceive(event:)`
    /// (the trackpad finger-rest catch). Both are CATCHES, where translation and velocity are ~0 and
    /// the gesture is not a flick start, so neither feeds the `.began` drag sample.
    ///
    /// The trackpad half additionally needs a translation baseline: `pan.setTranslation(.zero, in:)`
    /// is silently ignored for indirect-scroll, so the recognizer's translation at our forced
    /// `.began` carries the STALE value from the prior gesture and never decrements — spurious
    /// `.changed` events would feed that value into `core.drag` and overscroll the list far past the
    /// catch position. We track our own baseline and subtract it in `.changed` so the drag math sees
    /// the delta SINCE the catch. That half stays trackpad-only through an explicit `isIndirect`
    /// conjunction rather than hiding in this flag's name. Cleared on `.ended`/`.cancelled`.
    private var beganWasForced = false
    private var trackpadTranslationBaseline: CGFloat = 0

    /// Whether the finger landed on MOVING content. Written by `noteTouchDown` and read by
    /// `shouldBeginImmediately` one statement later, both inside the recognizer's `touchesBegan`, so it
    /// cannot go stale between the two. It exists because those two steps now disagree about the
    /// present: the catch runs first, so a live `flight != nil || core.isDecelerating` re-read in
    /// `shouldBeginImmediately` would find the motion already stopped and never force the `.began` that
    /// absorbs the tap.
    private var caughtMovingContentAtTouchDown = false

    /// How a flick/bounce plays out after release. `.stepped` (default) integrates the physics on the
    /// main thread once per frame (the original behaviour); `.keyframe` precomputes the whole path and
    /// plays it as a render-server `CAKeyframeAnimation` on the host's `bounds.origin.y`, driving the
    /// shared `KeyframeFlight` so the list can re-base its coordinate mid-flight (rebake-and-splice).
    enum DecelerationMode { case stepped, keyframe }
    var decelerationMode: DecelerationMode = .stepped

    // Keyframe-flight state (nil/zero unless a `.keyframe` deceleration is in flight). `flightGeneration`
    // is the ENGINE-owned cross-flight staleness guard (launch/re-emit/catch); `KeyframeFlight.generation`
    // counts rebakes WITHIN a flight only.
    private var flight: KeyframeFlight?
    private var flightGeneration = 0
    /// What the ENGINE last wrote to `host.bounds.origin.y`. During a flight that value is the additive
    /// animation's BASE (parked at the trajectory's `finalOffset`), not a position — so if it ever
    /// differs from this, something outside the engine rebased the animation mid-flight. Diagnostic
    /// only; read by `FlightTrace`.
    private var expectedBoundsBase: CGFloat = 0
    /// Container rebases move the sampled position without moving content; subtract them so the
    /// opening samples describe real travel.
    private var cumulativeFlightShift: CGFloat = 0
    private var flightLaunchOffset: CGFloat = 0
    private var flightRebakes = 0
    /// Wall time of the release, and how many opening samples have been logged. A start-phase
    /// difference converges by the end of the path, so TOTAL travel and whole-flight profile are both
    /// blind to it — only the first frames show it.
    private var launchWallTime: CFTimeInterval = 0
    private var openingSamples = 0

    /// Log where the content is, relative to the release position, in the opening frames.
    /// `-[UIScrollView _endPanNormal:]` sets `lastUpdateTime = now - 1/maxFPS` and steps to `now`, so
    /// its FIRST deceleration step integrates exactly one display frame. `.stepped` inherits that from
    /// its display link's first callback; whether `.keyframe`'s baked path, begun at `localNow()`,
    /// hands off the same way is exactly what this measures.
    private func noteOpening(_ label: String, position: CGFloat) {
        guard FlightTrace.isEnabled, openingSamples < 6 else { return }
        openingSamples += 1
        FlightTrace.shared.log(String(format: "OPENING %@ #%d t=%.2fms moved=%.1f",
                                      label, openingSamples,
                                      (CACurrentMediaTime() - launchWallTime) * 1000,
                                      position - flightLaunchOffset))
    }
    private static let flightKey = "listDecelerationFlight"

    /// Layer-LOCAL time (CLAUDE.md gotcha). Equals `CACurrentMediaTime()` only at default layer speed;
    /// reading it via `convertTime` keeps the flight sampler on CA's rendered position under slow-mo.
    private func localNow() -> CFTimeInterval { host.layer.convertTime(CACurrentMediaTime(), from: nil) }

    override init() {
        core = PhysicsScrollCore(contentHost: host)
        super.init()
        pan.addTarget(self, action: #selector(handlePan(_:)))
        pan.onTouchDown = { [weak self] timestamp in self?.noteTouchDown(at: timestamp) }
        pan.onTouchUp = { [weak self] in self?.handleTouchUp() }
        // Grab the scroll the instant a finger lands on MOVING content (UIScrollView's no-deadzone feel).
        // The STOP already happened in `noteTouchDown`; what the forced `.began` adds is absorption —
        // because the engine grants no simultaneity, UIKit's plain exclusion FAILS the content
        // recognizer as the pan begins, so the stopping tap does not also fall through to the row. At
        // rest the closure is false → normal hysteresis, and the content recognizer wins on its own.
        //
        // It answers from the flag `noteTouchDown` captured, NOT from live motion state: by the time
        // UIKit consults this, one statement later, the catch has already nulled the motion.
        pan.shouldBeginImmediately = { [weak self] in
            guard let self else { return false }
            if self.caughtMovingContentAtTouchDown {
                self.beganWasForced = true             // a catch, not a flick start — see beganWasForced
            }
            return self.caughtMovingContentAtTouchDown
        }
        // `UIScrollView` sets this false on its own pan (measured, iOS 26.2); a freshly constructed
        // recognizer defaults to TRUE, which withholds every `UITouchPhaseEnded` from the views under
        // the list until this pan resolves. Row recognizers are unaffected — they receive touches
        // regardless of where hit-testing settles — but a `UIControl` inside a row reads its touch-up
        // from the view, and chat's inline bot keyboards put real `UIButton`s in the list
        // (`ChatMessageActionButtonsNode`); `ListViewImpl` delays none of them. Absorption does not
        // need it either: that works by failing the content RECOGNIZER through exclusion, and
        // `cancelsTouchesInView` still cancels the view's touch when this pan recognizes mid-drag.
        pan.delaysTouchesEnded = false
        pan.delegate = self
        host.addGestureRecognizer(pan)
    }

    // MARK: - ScrollEngine

    var onScroll: ((CGFloat) -> Void)? {
        get { core.onScroll }
        set { core.onScroll = newValue }
    }

    /// Published only in `.keyframe` mode, where the render server plays the trajectory.
    var onFlightChanged: ((ScrollFlight?) -> Void)?
    var onWillBeginDragging: (() -> Void)?
    var onDidEndDragging: (() -> Void)?
    var shouldStopScrollingOnRelease: ((CGFloat) -> Bool)?
    /// The physics scroll position, advanced once per frame by whichever driver is running — NEVER a sample of
    /// the flight. Consumers may read this as many times as they like within a frame and get one coherent
    /// value; a consumer that reads it twice around its own work (the list does, three times per mutation
    /// pass) must not observe the scroll position moving underneath it. Sampling the flight here instead made
    /// every mid-flight `applyChanges` re-place the content where it was when the pass started — a backward
    /// lurch of `velocity × pass duration`, up to 185pt measured. See
    /// docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md.
    ///
    /// The instantaneous position is deliberately NOT exposed: `catchFlight` samples
    /// `flight.liveOffset(now: localNow())` directly, which is the one operation that genuinely needs it.
    var offset: CGFloat { core.offset }
    var contentHost: UIView { host }

    /// Whether any driver is running. Exposed for the seam tests; production reads motion state
    /// through `onFlightChanged` / the drag pair.
    var isDecelerating: Bool { flight != nil || core.isDecelerating }
    /// Where the current release projects to. Exists for the seam tests and for nothing in
    /// production, which plays the baked trajectory rather than the analytic landing.
    var projectedRestOffset: CGFloat { core.projectedTarget() }
    /// `_fastScrollMultiplier` as the replica currently has it. Diagnostic.
    var decelerationVelocityScale: CGFloat { core.decelerationVelocityScale }
    var decelerationStreakCount: Int { core.decelerationStreakCount }
    var decelerationStreakReset: String { core.decelerationStreakReset }

    /// The finger landing — `-[UIScrollView _beginTrackingWithEvent:]`. A different moment from the pan
    /// beginning: it is where the repeated-flick streak is carried or expired, and where moving content
    /// is CAUGHT. Production reaches it through our own `pan.onTouchDown`; the A/B comparison view
    /// drives the engine from `UIScrollView.panGestureRecognizer`, whose touches never route through
    /// that pan, and calls this directly. Without that hookup the streak neither expires on a pause nor
    /// compounds (`_fastScrollStartMultiplier` stays 1), so the harness would understate our own
    /// multiplier and read as a physics difference that does not exist in the app.
    ///
    /// **The catch belongs here, in touch DELIVERY, and not in `handlePan(.began)`.** UIScrollView stops
    /// its deceleration in `_beginTrackingWithEvent:` for the same reason: a recognizer's `.began` is
    /// subject to gesture ARBITRATION, and this one cannot control who else is arbitrating. Any ancestor
    /// that declares `shouldBeRequiredToFailBy` for pans HOLDS our forced `.began` until that recognizer
    /// fails, and `NavigationContainer` declares exactly that for every `UIPanGestureRecognizer`
    /// (`Display/Source/Navigation/NavigationContainer.swift:202`, and `NavigationModalContainer:147`)
    /// — our pan IS one. Its `InteractiveTransitionGestureRecognizer` does not fail until the finger has
    /// travelled ~2pt off-axis, and for a dead-still finger not until it LIFTS, so with the catch on the
    /// `.began` path a tap on a flinging chat kept flying for the whole finger-down interval and stopped
    /// at the touch-UP. `onTouchDown`/`onTouchUp` are touch delivery, which arbitration cannot hold.
    ///
    /// Order within this method is load-bearing: `beginTouchTracking` decides the streak from the motion
    /// state, so it must run BEFORE the catch nulls that motion.
    func noteTouchDown(at timestamp: TimeInterval) {
        sawDrag = false
        // Cleared at finger-down, which runs BEFORE `shouldBeginImmediately` is consulted. Clearing it
        // only on `.ended`/`.cancelled` would leak a stale `true` into the next gesture whenever a
        // forced begin was then denied by `gestureRecognizerShouldBegin` (a tracking UIControl), and
        // that gesture's natural `.began` would skip its drag sample.
        beganWasForced = false
        // UIKit passes `event.timestamp`, which shares CACurrentMediaTime's timebase.
        core.beginTouchTracking(at: timestamp)
        caughtMovingContentAtTouchDown = flight != nil || core.isDecelerating
        if caughtMovingContentAtTouchDown { catchMotionForFingerRest() }
    }

    func setOffset(_ y: CGFloat) {
        // The list's one-viewport delta-clamp routes here; during a flight, catch first (plain catch —
        // the clamp is unreachable at realistic flick speeds, so a relaunch is unnecessary). After
        // halting the drivers (catchFlight removes the CA animation; stopDisplayLink invalidates the
        // sampling/stepping link), also idle the core's phase via `cancelDeceleration` so the post-
        // setOffset state is fully halted (not just driverless-with-stale-phase). Matches the
        // analogous `finalizeFlight` and TestScrollEngine.setOffset; required by the
        // 4c §4(b) halt idiom `engine.setOffset(engine.offset)`, where Tasks 4-6 (and the §4(b)
        // halt sites in CoreVirtualListView) rely on this call to halt motion fully.
        if flight != nil { catchFlight() }
        stopDisplayLink()
        core.cancelDeceleration()
        core.setOffset(y)
    }
    func reanchorDragToCurrentPosition() {
        core.reanchorDragToCurrentPosition()
    }

    func haltMotionInPlace() {
        // Same teardown as `setOffset` minus the offset write: `catchFlight` already snaps the physics and
        // the layer model to the live position and removes the animation, so the content does not move.
        if flight != nil { catchFlight() }
        stopDisplayLink()
        core.cancelDeceleration()
    }
    func syncToPresentedPosition() {
        // Exactly what a sampling tick does first: reseed the physics at the flight's live sample. The CA
        // animation is untouched, so the flight keeps playing — only the value the list reads becomes current.
        flight?.beginTick(now: localNow())
    }
    func applyShift(_ dy: CGFloat) {
        if flight != nil {
            // With two open edges this is a rigid coordinate translation and needs no re-emit. A finite
            // edge stays fixed while the offset moves, however, so its relative geometry changes and the
            // translated old bounce is no longer authoritative — unless the translated path still cannot
            // reach that edge, which `noteEdgesChanged` filters out.
            let changesShape = core.hasFiniteEdge
            cumulativeFlightShift += dy
            FlightTrace.shared.log("shift dy=\(dy) changesShape=\(changesShape)")
            host.bounds.origin.y += dy
            expectedBoundsBase += dy
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
                noteFlightEdgesChanged()
            }
        } else {
            cumulativeFlightShift += dy
            FlightTrace.shared.log("shift dy=\(dy) changesShape=n/a")
            core.applyShift(dy)
        }
    }
    func setEdges(min: CGFloat?, max: CGFloat?) {
        if core.setEdges(min: min, max: max) {
            noteFlightEdgesChanged()
        }
    }
    func containerOrigin(windowHeight: CGFloat, topLoaded: Bool, bottomLoaded: Bool) -> CGFloat {
        core.containerOrigin(windowHeight: windowHeight, topLoaded: topLoaded, bottomLoaded: bottomLoaded)
    }

    // MARK: - Driver

    /// Route a declared-edge change (or a coordinate re-base against a fixed edge) into the live flight.
    /// `noteEdgesChanged` ignores a change that cannot reach its baked path — that flight keeps playing the
    /// animation it already has, so the generation bump is gated on an invalidation ACTUALLY being pending:
    /// bumping it unconditionally would kill the completion block of an animation we then never replace.
    private func noteFlightEdgesChanged() {
        guard let flight else { return }
        flight.noteEdgesChanged()
        if flight.hasPendingEdgeRebake { flightGeneration &+= 1 }
    }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        applyPanUpdate(state: gr.state,
                       translation: gr.translation(in: host),
                       velocity: gr.velocity(in: host),
                       forced: beganWasForced,
                       isIndirect: pan.isIndirectScroll)
    }

    /// The gesture→physics seam, split out of `handlePan` so it can be driven from a synthetic event
    /// list — no recognizer, no window, no display link. This is the layer the short-flick defect
    /// lived in, and it had no coverage precisely because it was welded to `UIPanGestureRecognizer`.
    ///
    /// `translation` is points, `velocity` points/SECOND (both recognizer-space, finger-signed).
    /// `forced` marks a pan that was force-begun on moving content rather than reaching `.began`
    /// through hysteresis. `isIndirect` is passed IN rather than read off the recognizer: a
    /// `PhysicsPanGestureRecognizer` that has received no touches reports `isIndirectScroll == true`,
    /// so reading it here would hand a synthetic gesture the trackpad rubber-band coefficient.
    func applyPanUpdate(state: UIGestureRecognizer.State, translation: CGPoint,
                        velocity: CGPoint, forced: Bool, isIndirect: Bool) {
        switch state {
        case .began:
            sawDrag = true
            onWillBeginDragging?()
            // Trackpad-style indirect scroll delivers no touch-down, so `onTouchDown` never catches an
            // in-flight keyframe flight — catch it here. Idempotent for touch (onTouchDown nulled it).
            // Braking: this is a finger landing on moving content, the one catch a user watches happen.
            if flight != nil { catchFlight(braking: true) }
            stopDisplayLink()
            refreshScale()                 // round the upcoming decel to DEVICE PIXELS, not whole points
            // Trackpad (indirect) overscroll uses a looser rubber-band than touch (0.715 vs 0.55).
            core.updateRubberBandCoefficient(isIndirect ? RubberBand.trackpadCoefficient
                                                        : RubberBand.touchCoefficient)
            core.beginDrag()
            if forced {
                // A forced `.began` is a CATCH, not a flick start — see `beganWasForced`. Only the
                // trackpad half needs the stale-translation baseline.
                if isIndirect { trackpadTranslationBaseline = translation.y }
            } else {
                // `handlePan:` case 1 runs `_updatePanGesture` IMMEDIATELY after zeroing the velocity
                // ivars, so `.began` contributes a full velocity sample AND applies its translation.
                // Dropping it ran the whole gesture one sample behind UIKit and released a short
                // flick at a quarter of its velocity — the reported "modest scroll".
                core.drag(translation: translation.y, velocity: velocity.y)
            }
        case .changed:
            // A `.changed` with no preceding `.began` cannot come from UIKit, but a synthetic caller
            // can produce one; treat it as the gesture start rather than dragging from stale state.
            if !core.isDragging {
                core.beginDrag()
            }
            let tr = (forced && isIndirect) ? translation.y - trackpadTranslationBaseline
                                            : translation.y
            // Skip no-movement `.changed` events on the forced trackpad path: UIKit fires `.changed`
            // with the stale-but-unchanging translation after our forced `.began` (delta=0, vel=0),
            // and `core.drag(0, 0)` would re-apply the rubber band on top of the already-rubber-banded
            // live offset, compressing further.
            if forced, isIndirect, tr == 0, velocity.y == 0 { break }
            core.drag(translation: tr, velocity: velocity.y)
        case .ended, .cancelled:
            // A host may have already spent this release on something else (the chat's interactive
            // keyboard dismissal, decided in touch delivery — which precedes this action dispatch).
            // Release at zero rather than skipping `endDrag`: `ReleaseDecision` zeroes the sample,
            // falls below its decelerate threshold and expires the repeated-flick streak, which is
            // exactly the state a genuinely slow release leaves behind — and `.stop` still springs
            // back when the content was released overscrolled, so the one motion that MUST happen
            // still does. Skipping the call instead would strand an overscrolled list off its edge.
            let releaseVelocity = (shouldStopScrollingOnRelease?(velocity.y) ?? false) ? 0.0 : velocity.y
            if core.endDrag(recognizerVelocity: releaseVelocity, at: CACurrentMediaTime()) {
                startDeceleration()
            }
            beganWasForced = false
            trackpadTranslationBaseline = 0
            // Paired with the `.began` notification above: the pan can only reach `.ended`/`.cancelled`
            // after `.began`, so the two callbacks always bracket the finger-down interval. Fired AFTER
            // deceleration is launched so an observer reading motion state sees the post-release truth.
            onDidEndDragging?()
        default:
            break
        }
    }

    /// Route a release that should decelerate/spring to the active mode's driver.
    private func startDeceleration() {
        switch decelerationMode {
        case .stepped:  startSteppingLink()
        case .keyframe: launchFlight()
        }
    }

    /// A bare tap (no drag) lifted: if it left the content overscrolled, resume the spring-back via the
    /// active mode's driver (so a tap during a `.keyframe` bounce springs back as a keyframe flight too).
    private func handleTouchUp() {
        guard !sawDrag else { return }
        resumeBounceIfOverscrolled()
    }

    /// Resume the edge bounce if the content was left overscrolled by a catch-and-hold (touch tap or
    /// trackpad finger-rest). Shared by `handleTouchUp` (touch) and the `.ended`/`.cancelled` UIScrollEvent
    /// branch in `shouldReceive(event:)` (trackpad). No-op when at rest within the edges.
    private func resumeBounceIfOverscrolled() {
        refreshScale()
        if core.resumeBounceIfOverscrolled() { startDeceleration() }
    }

    /// Match the deceleration's pixel-rounding to the device's real display scale, like
    /// `PhysicsScrollView.makePhysics`. Read at gesture start (the host is in a window then, so the
    /// trait collection is valid). Window-guarded: a detached host — e.g. in unit tests — keeps the
    /// deterministic default scale 1, so the physics-core test fixtures stay byte-identical.
    private func refreshScale() {
        guard host.window != nil else { return }
        core.updateScale(Swift.max(host.traitCollection.displayScale, 1))
    }

    // MARK: - Stepped driver (default)

    @objc private func step(_ link: CADisplayLink) {
        let dtMs = CGFloat((link.targetTimestamp - link.timestamp) * 1000)
        let done = core.step(dtMs: dtMs)
        noteOpening("stepped(written)", position: core.offset - cumulativeFlightShift)
        if done {
            FlightTrace.shared.log("SETTLED offset=\(core.offset) "
                + "totalTravel=\(core.offset - flightLaunchOffset)")
            FlightTrace.shared.flush()
            stopDisplayLink()
        }
    }

    private func startSteppingLink() {
        FlightTrace.shared.begin("STEPPED flight")
        flightLaunchOffset = core.offset
        launchWallTime = CACurrentMediaTime()
        openingSamples = 0
        cumulativeFlightShift = 0
        FlightTrace.shared.log("launch v=\(core.decelerationVelocity) offset=\(core.offset) projectedTarget=\(core.projectedTarget()) "
            + "projectedTravel=\(core.projectedTarget() - core.offset) "
            + "edges=\(String(describing: core.edges)) vScale=\(core.decelerationVelocityScale)")
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    // MARK: - Keyframe driver (increment 4a)

    /// Bake the released decel state into a `KeyframeFlight`, park the host model at the settled offset,
    /// and hand the visual path to the render server. The sampling link reports the live offset (and
    /// drives the list's mid-flight rebalance → rebake); the CA completion finalises.
    private func launchFlight() {
        // The release hand-off runs as a SETTLE PROBE, and its displacement is rewound before the bake.
        // It compensates a MODEL-WRITE driver, which a baked flight is not: the render server plays the
        // path from an explicit `beginTime` at each frame's own PRESENTATION time, so the first frame
        // the launch transaction lands on is already one commit-to-display delay in — and that delay IS
        // the hand-off. Keeping it double-counts the frame and the release steps FORWARD by
        // `releaseHandOffFrames × frameTravel` (12pt at 120Hz, 23pt at 60Hz off a 3000 pt/s flick, twice
        // that under the repeated-flick multiplier). Keyframe-only — `.stepped` writes the model once
        // per frame just as the drag does. CLAUDE.md has the full account; `FlightLaunchContinuityTests`
        // locks it, and `FlightCatchContinuityTests` is the same seam sign-flipped at the catch.
        //
        // The probe still has to RUN, because it is a real integration frame and can END the
        // deceleration it was handed — and a release CAN reach here with nothing left to spend.
        // `endDrag` reports `.decelerate` for two of them: a blend that cancels (the decelerate
        // threshold reads the RAW latest sample and the 0.75/0.25 low-pass runs after it, so a finger
        // reversing on its last sample releases above the threshold at ~0 pts/ms), and an overscrolled
        // release already inside `Deceleration.settleTolerance` — the everyday drag-to-the-edge-and-
        // pause. `.stepped` absorbs both in its first link callback; here the settle happens BEFORE the
        // bake, so building the flight would violate the `.decelerating` precondition `KeyframeFlight`
        // asserts (`FlightLaunchPreconditionTests`). The rewind runs only AFTER that verdict is read,
        // so it cannot reach those cases — and it is exact, since `offset`/`decelerationVelocity` are
        // the axis' full-precision state (pixel rounding is on the WRITE) and `reseedDeceleration` is a
        // pure (offset, velocity, phase) restore. It rewinds the CORE, not just the bake, because
        // `engine.offset` feeds the list's own geometry and must describe the screen, not lead it.
        let releaseState = (offset: core.offset, velocity: core.decelerationVelocity)
        if Self.appliesReleaseHandOff {
            core.applyDecelerationHandOff(frameMs: Self.displayFrameMs * Self.releaseHandOffFrames)
        }
        guard core.isDecelerating else { settleWithoutFlight(at: core.offset); return }
        core.reseedDeceleration(offset: releaseState.offset, velocity: releaseState.velocity)
        let now = localNow()
        let f = KeyframeFlight(core: core, startTime: now)
        guard f.trajectory.samples.count >= 2, f.trajectory.duration > 0 else {
            // Degenerate (unreachable in practice — Trajectory.build always appends ≥1 post-t0 sample).
            settleWithoutFlight(at: f.trajectory.finalOffset)
            return
        }
        flight = f
        host.bounds.origin.y = f.trajectory.finalOffset            // model at settled (sync)
        expectedBoundsBase = f.trajectory.finalOffset
        flightLaunchOffset = core.offset
        flightRebakes = 0
        launchWallTime = CACurrentMediaTime()
        openingSamples = 0
        cumulativeFlightShift = 0
        FlightTrace.shared.begin("KEYFRAME flight")
        FlightTrace.shared.log("launch v=\(core.decelerationVelocity) offset=\(core.offset) finalOffset=\(f.trajectory.finalOffset) "
            + "travel=\(f.trajectory.finalOffset - core.offset) duration=\(f.trajectory.duration) "
            + "samples=\(f.trajectory.samples.count) edges=\(String(describing: core.edges)) "
            + "vScale=\(core.decelerationVelocityScale) "
            + "pinnedRate=\(Self.pinsMaximumRefreshRate) linkPinned=\(Self.pinsSamplingLinkRate)")
        flightGeneration &+= 1
        let g = flightGeneration
        // disablingImplicitActions: false — this site never disabled them, and doing so now would
        // change what the flight install does.
        let flightAnim = f.trajectory.boundsOriginKeyframeAnimation(beginTime: now)
        flightAnim.preferHighRefreshRate()
        if #available(iOS 15.0, *), let r = maxRefreshRange() { flightAnim.preferredFrameRateRange = r }   // pin the floor: hold the rate
        flightAnim.setCoreListCompletion { [weak self] _ in
            guard let self, self.flightGeneration == g else { return }   // ignore stale completions
            self.finalizeFlight()
        }
        host.layer.add(flightAnim, forKey: Self.flightKey)
        onFlightChanged?(ScrollFlight(trajectory: f.trajectory, beginTime: now))
        startSamplingLink()
    }

    /// Come to rest at `offset` with no flight at all: a release that had nothing left to play. Writes
    /// the position through the core (the hand-off deliberately does not touch the host bounds, so the
    /// "physics offset == host bounds origin while nothing is in flight" identity needs this), idles the
    /// core so `isDecelerating` cannot read stale, and reports the rest position once — the same settle
    /// `.stepped` reaches through its first link callback returning `settled`.
    private func settleWithoutFlight(at offset: CGFloat) {
        core.setOffset(offset)
        core.cancelDeceleration()
        onFlightChanged?(nil)
        onScroll?(offset)
    }

    /// Per-tick protocol (order is load-bearing — `KeyframeFlight` asserts the core is `.decelerating`):
    /// FIRST the `isComplete` finalize check; else `beginTick` (reseed core to the live sample), THEN
    /// `onScroll(liveOffset)` (the list rebalances → applyShift/setEdges → noteShift/noteEdgesChanged),
    /// THEN `rebakeIfNeeded`; on a rebake, re-emit the CA animation from the spliced trajectory.
    @objc private func sampleTick(_ link: CADisplayLink) {
        guard let f = flight else { stopDisplayLink(); return }
        let now = localNow()
        if f.isComplete(now: now), !f.hasPendingEdgeRebake {
            finalizeFlight()
            return
        }
        if FlightTrace.isEnabled {
            // Where the RENDER SERVER actually has the content, against where the baked path says it
            // should be at this instant. Distance measurements cannot see a profile error: the
            // animation is installed with `beginTime` already in the past by the commit delay, so CA
            // starts it at phase δ rather than 0 — the opening, fastest milliseconds are never
            // rendered while the endpoint, and therefore the travel, stays exactly right.
            if let presented = host.layer.presentation()?.bounds.origin.y {
                noteOpening("keyframe(rendered)", position: presented - cumulativeFlightShift)
                let planned = f.liveOffset(now: now)
                let lag = planned - presented
                if abs(lag) > 2.0 {
                    FlightTrace.shared.log(String(format: "PROFILE t=%.1fms planned=%.1f presented=%.1f lag=%.1f",
                                                  (now - f.startTime) * 1000, planned, presented, lag))
                }
            }
            let base = host.bounds.origin.y
            if abs(base - expectedBoundsBase) > 0.5 {
                FlightTrace.shared.log("BASE-DRIFT expected=\(expectedBoundsBase) actual=\(base) "
                    + "delta=\(base - expectedBoundsBase)  <-- something rebased the animation")
                expectedBoundsBase = base
            }
        }
        f.beginTick(now: now)
        // A baked path has no per-frame hook, so the flight's own reset instant is where the
        // integrator would have cleared the fast-scroll streak (`0x17a87bc` / `0x17a8844`). Without
        // this the `.keyframe` driver — which is what the chat ships — never clears it at all, since
        // `PhysicsScrollCore.step` only runs under `.stepped`.
        if let reset = f.trajectory.multiplierResetTime, now - f.startTime >= reset {
            core.noteDecelerationEnded()
        }
        onScroll?(f.liveOffset(now: now))                          // list rebalances → applyShift (model-bump) / setEdges
        if f.rebakeIfNeeded(now: now) {
            if f.isComplete(now: now) {
                finalizeFlight()
            } else {
                reemitFlightAnimation()
            }
        }
    }

    /// Re-emit the CA animation after a mid-flight rebake/splice — now ONLY an edge/shape change (a pure
    /// coordinate shift rides the model translation in `applyShift` instead). Snap the model to the new
    /// settled offset and play the spliced trajectory from its startTime.
    private func reemitFlightAnimation() {
        guard let f = flight else { return }   // re-entrant catch (setOffset during onScroll) nulled flight → no-op, no stray anim
        host.layer.removeAnimation(forKey: Self.flightKey)
        host.bounds.origin.y = f.trajectory.finalOffset
        expectedBoundsBase = f.trajectory.finalOffset
        flightRebakes += 1
        FlightTrace.shared.log("REBAKE #\(flightRebakes) finalOffset=\(f.trajectory.finalOffset) "
            + "duration=\(f.trajectory.duration) samples=\(f.trajectory.samples.count)")
        flightGeneration &+= 1
        let g = flightGeneration
        let flightAnim = f.trajectory.boundsOriginKeyframeAnimation(beginTime: f.startTime)
        flightAnim.preferHighRefreshRate()
        if #available(iOS 15.0, *), let r = maxRefreshRange() { flightAnim.preferredFrameRateRange = r }   // pin the floor: hold the rate
        flightAnim.setCoreListCompletion { [weak self] _ in
            guard let self, self.flightGeneration == g else { return }
            self.finalizeFlight()
        }
        host.layer.add(flightAnim, forKey: Self.flightKey)
        onFlightChanged?(ScrollFlight(trajectory: f.trajectory, beginTime: f.startTime))
    }

    /// Catch an in-flight `.keyframe` deceleration: snap the model (physics + host bounds) to the offset
    /// the flight stops at BEFORE touching the animation (so the swap/removal reveals that position, no
    /// flash), and invalidate `flight`/`flightGeneration` first so the CA completion's stale-
    /// generation guard fires for both async AND synchronous completion paths. Pre-fix the bump+nil
    /// happened AFTER `removeAnimation`: async completion was guarded fine (the original tap-stop path),
    /// but trackpad Option A (catch from `shouldReceive(event:)`) hit a synchronous completion window
    /// where `finalizeFlight` ran during `removeAnimation` — `core.setOffset(f.settledOffset)` then
    /// jumped the list to the post-animation rest position at the moment of catch. With the bump first,
    /// the completion's `flightGeneration == g` guard catches the stale fire; `flight = nil` is the
    /// secondary belt-and-suspenders (finalizeFlight's own `guard let f = flight` also short-circuits).
    ///
    /// `braking` picks WHICH instant the flight stops at, and it is the difference between a clean stop
    /// and a visible backward jerk. A catch takes effect only when its transaction is presented — after
    /// the rest of this main-thread turn and the commit-to-display delay — and the render server plays the
    /// flight until then, so `liveOffset(now:)` is a value the screen has already passed by the time it
    /// lands (40pt one frame late, 79pt two frames late, off a 3000 pt/s release; see
    /// `FlightCatchContinuityTests`). A braking catch instead stops the flight at `brakeStopTime()` and
    /// swaps in the same path truncated there (`KeyframeFlight.braked`), which presents identically until
    /// that instant — so the content coasts the last couple of frames along the path it was already on and
    /// stops, instead of snapping back. INTERACTIVE catches brake; the programmatic ones
    /// (`setOffset`, `haltMotionInPlace`, `tearDown`) do not, because each of them immediately imposes its
    /// own position or tears the engine down, and a residual brake would ride on top of that write.
    private func catchFlight(braking: Bool = false) {
        guard let f = flight else { return }
        let brake = braking ? f.braked(stoppingAt: brakeStopTime()) : nil
        let live = brake?.offset ?? f.liveOffset(now: localNow())
        FlightTrace.shared.log("CATCH braking=\(braking) at=\(live) "
            + "(flight would have settled at \(f.settledOffset))")
        core.setOffset(live)                          // also writes host.bounds.origin.y = live (via core.writeOffset)
        host.bounds.origin.y = live                   // redundant but explicit: model == live BEFORE the swap (no flash)
        flight = nil
        flightGeneration &+= 1
        if let brake {
            // Same key ⇒ this REPLACES the flight animation rather than leaving the layer bare, and it
            // rides the flight's own `startTime` (a past explicit origin, exactly as `reemitFlightAnimation`
            // does) so its already-played history lines up frame for frame with what is on screen. No
            // completion: there is no flight left to finalize, and the generation bump above has already
            // disarmed the animation this one displaces.
            let brakeAnim = brake.trajectory.boundsOriginKeyframeAnimation(beginTime: f.startTime)
            brakeAnim.preferHighRefreshRate()
            if #available(iOS 15.0, *), let r = maxRefreshRange() { brakeAnim.preferredFrameRateRange = r }
            host.layer.add(brakeAnim, forKey: Self.flightKey)
        } else {
            host.layer.removeAnimation(forKey: Self.flightKey)
        }
        onFlightChanged?(nil)
    }

    /// Layer-local instant a braking catch should come to rest: the first frame this turn's commit can
    /// realistically be PRESENTED at, plus one frame of headroom. `targetTimestamp` is the vsync the
    /// transaction we are about to commit is aiming at, so it is the estimate; the extra frame is because
    /// the two errors are not symmetric — landing early just means the flight coasts a few more
    /// milliseconds along the path the eye is already tracking, while landing late is the backward step
    /// this whole mechanism exists to remove. `max` with `localNow()` covers a turn that has already
    /// overrun its frame (the link's timestamps only refresh in its callback, so they can be in the past).
    /// Both link timestamps are converted through the layer, so the headroom stays a real frame under a
    /// non-unit layer speed.
    private func brakeStopTime() -> CFTimeInterval {
        let now = localNow()
        // `timestamp == 0` means the sampling link has not fired yet (a catch in the same turn as the
        // launch), so its window is meaningless — fall back to the display's nominal frame.
        guard let link = displayLink, link.timestamp > 0 else {
            let frame = 1.0 / Double(Swift.max(UIScreen.main.maximumFramesPerSecond, 60))
            return now + 2 * frame
        }
        let lastFrame = host.layer.convertTime(link.timestamp, from: nil)
        let nextFrame = host.layer.convertTime(link.targetTimestamp, from: nil)
        let frame = Swift.max(nextFrame - lastFrame, 1.0 / 120.0)
        return Swift.max(now, nextFrame) + frame
    }

    /// Catch an in-flight deceleration when a finger LANDS on (or rests on) the list, without moving it.
    /// Two callers, one meaning: `noteTouchDown` (touch — see the arbitration note there) and the
    /// trackpad finger-rest in `shouldReceive(event:)`, which gets no touch-down at all and so would
    /// otherwise stop only on the first MOVEMENT. Handles both modes: a keyframe flight catches to its
    /// live offset; a stepped decel stops its link and idles the core, holding the content where it
    /// caught (no `onScroll` — nothing moved). Both callers reach it only while the gesture is still
    /// `.possible`, so it never fires mid-drag.
    private func catchMotionForFingerRest() {
        if flight != nil {
            catchFlight(braking: true)      // interactive, same as the touch catch — see `catchFlight`
        } else if core.isDecelerating {
            stopDisplayLink()
            core.cancelDeceleration()
        }
    }

    /// Authoritative end-of-flight (CA completion OR the sampler reaching `duration`). The model is
    /// already at the settled offset; tear down and report the settled position.
    private func finalizeFlight() {
        guard let f = flight else { return }          // idempotent
        stopDisplayLink()
        core.setOffset(f.settledOffset)            // settle at the LIST-coord rest (finalOffset + accrued shift)
        core.cancelDeceleration()                  // idle the core (phase → .idle) — matches TestScrollEngine
        core.noteDecelerationEnded()               // a finished flight has settled, which clears the streak
        FlightTrace.shared.log("FINALIZE settledOffset=\(f.settledOffset) coreOffset=\(core.offset) "
            + "totalTravel=\(core.offset - flightLaunchOffset) rebakes=\(flightRebakes)")
        FlightTrace.shared.flush()
        flight = nil
        onFlightChanged?(nil)                      // BEFORE onScroll: a consumer re-entering must see no flight
        onScroll?(core.offset)
    }

    private func startSamplingLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(sampleTick(_:)))
        if #available(iOS 15.0, *), Self.pinsSamplingLinkRate, let r = maxRefreshRange() {
            link.preferredFrameRateRange = r        // hold the ProMotion rate (residual-hitch fix)
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Whether a keyframe flight PINS the display to its maximum rate (`min == max == preferred`)
    /// rather than requesting an adaptive range.
    ///
    /// Pinning is the shipped behaviour and was itself a fix: the residual scroll hitch was the
    /// DISPLAY rate dropping — sampling display-link callbacks skipped while the main thread sat idle
    /// at ~0.5ms, with no re-emit — because `preferHighRefreshRate()` asks for `(min: 30, max, max)`
    /// and that low floor let the system throttle to ~80Hz and intermittently halve it.
    ///
    /// It is togglable because it is also a **keyframe-only, ProMotion-only** asymmetry, and therefore
    /// a candidate for a "constrained velocity" reported on device and unreproducible in the 60Hz
    /// Simulator, where `maxRefreshRange()` is inert: `.stepped` sets no range on its display link at
    /// all, so the two drivers ask the system for different things on a 120Hz panel. A rigid range is
    /// also the one the system is least able to satisfy under thermal pressure or Low Power Mode
    /// (which caps ProMotion at 60Hz), and an unsatisfiable request is served by falling back rather
    /// than by negotiating. Defaults to the shipped behaviour; only the demo flips it.
    static var pinsMaximumRefreshRate = true

    /// Whether the SAMPLING display link is also pinned to the maximum rate.
    ///
    /// It does not move the content — the render server plays the baked animation — it only drives
    /// `onScroll` → rebalance → row loading. Pinning it therefore buys no smoothness and costs DOUBLE
    /// the main-thread row work per second: measured on a 120Hz device, the keyframe sampler runs at
    /// ~116Hz while `.stepped`'s link runs at ~61Hz, because only the keyframe path applies
    /// `maxRefreshRange()`. A saturated main thread means rows arrive late behind a container whose
    /// motion is provably correct (measured within 1% of the analytic path from the first frame),
    /// which is a candidate for a flick that measures right and feels constrained.
    ///
    /// Separate from `pinsMaximumRefreshRate` because the two were conflated: unpinning BOTH gave up
    /// the animation's rate guarantee — the hitch the pinning was introduced to fix — while only
    /// incidentally reducing sampler load, so the combination read as worse.
    static var pinsSamplingLinkRate = true

    /// Whether `launchFlight` runs UIScrollView's release hand-off at all (see
    /// `PhysicsScrollCore.applyDecelerationHandOff`).
    ///
    /// On the baked path the step is a SETTLE PROBE and nothing else — its displacement is rewound
    /// before the bake, because a render-server-played path gets that frame from the commit-to-display
    /// delay for free (`launchFlight`). Turning it off therefore does not change the opening; it
    /// removes the probe, so a release with nothing left to spend bakes a degenerate ~1-vertex flight
    /// instead of settling through `settleWithoutFlight`.
    static var appliesReleaseHandOff = true
    /// How much of a display frame the settle probe integrates.
    ///
    /// It no longer sizes any displacement — see `appliesReleaseHandOff` — so this only decides how
    /// marginal a release has to be for the probe to settle it. UIScrollView's own step is a full
    /// frame; half of one is kept because it is what shipped and every `FlightLaunchPreconditionTests`
    /// fixture is stated at that size.
    static var releaseHandOffFrames: CGFloat = 0.5

    /// A FIXED max-refresh range for ProMotion, or nil on ≤60Hz (incl. Simulator) or when pinning is
    /// disabled — in which case the animation keeps `preferHighRefreshRate()`'s adaptive range and the
    /// display link keeps CoreAnimation's default.
    @available(iOS 15.0, *)
    private func maxRefreshRange() -> CAFrameRateRange? {
        guard Self.pinsMaximumRefreshRate else { return nil }
        let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
        guard maxFps > 61 else { return nil }   // no-op on ≤60Hz (incl. Simulator)
        return CAFrameRateRange(minimum: maxFps, maximum: maxFps, preferred: maxFps)
    }

    /// One display frame in ms, for the release hand-off. Falls back to 60Hz.
    private static var displayFrameMs: CGFloat {
        1000.0 / CGFloat(Swift.max(UIScreen.main.maximumFramesPerSecond, 60))
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Stop the display link so an engine that is being discarded (e.g. the demo swapping engines)
    /// doesn't keep stepping/sampling a detached host until its in-flight deceleration settles. A live
    /// `.keyframe` flight is caught first so its CA animation is removed (the link retains its target,
    /// so without this the engine lingers — and keeps firing — until the decel ends on its own).
    func tearDown() {
        if flight != nil { catchFlight() }
        stopDisplayLink()
    }

    deinit { displayLink?.invalidate() }
}

extension PhysicsScrollEngine: UIGestureRecognizerDelegate {
    /// **Never grant simultaneity to a content recognizer.** UIKit resolves simultaneity as *either
    /// delegate says yes*, so a grant here overrides a refusal written in a file this one never
    /// mentions — a nested scroll view's UIKit default, or `ContextGesture`'s explicit
    /// `other is UIPanGestureRecognizer -> false` (`Display/Source/ContextGesture.swift:66`). Our pan
    /// IS a pan, so anything refusing pans is refusing us, and neither refusal can be seen from here.
    /// That is what makes a grant unfindable from the content side, and it shipped twice: first as an
    /// in-bubble carousel and the chat history both scrolling on one diagonal drag, then as a bubble's
    /// long-press running its press animation and never activating.
    ///
    /// Denying leaves plain UIKit exclusion, which is the whole of `ListViewImpl`'s mechanism
    /// (`ListViewScroller` denies everything but `ListViewTapGestureRecognizer`,
    /// `Display/Source/ListViewScroller.swift:15`). Exclusion is also what absorbs the stopping tap:
    /// a pan force-begun on moving content FAILS the content recognizer at touch-down. There is
    /// deliberately no `shouldBeRequiredToFailBy` counterpart — a failure dependency HOLDS a
    /// recognizer instead of failing it, and a pan that force-began never fails until lift, so the
    /// held recognizer sits in `.possible` while its own timer-driven animation runs to completion.
    ///
    /// `false` is UIKit's default, so this method is redundant in the strict sense. It stays as the
    /// marker in the exact spot both bugs were introduced, and because the policy tests need
    /// something to call.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return false
    }

    /// Ported from `ListViewScroller.gestureRecognizerShouldBegin`
    /// (`Display/Source/ListViewScroller.swift:22`), the delegate that governs `ListViewImpl`'s scroll
    /// pan. Two deferrals:
    ///
    /// - a two-touch pan on the same view wins while two fingers are down. Currently inert — nothing
    ///   else attaches to `host` — but it is the rule, and it costs nothing to keep true;
    /// - a `UIControl` already tracking keeps the touch. This one is live: chat's inline bot keyboards
    ///   put real `UIButton`s inside the list (`ChatMessageActionButtonsNode`).
    ///
    /// Note this also gates the forced-immediate `.began`: writing `state = .began` runs the same
    /// transition machinery as a natural begin, so a tracking control can deny a grab on moving
    /// content. `ListViewImpl` behaves identically — `UIScrollView`'s decelerating-grab passes
    /// through this same override.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan, let view = pan.view else { return true }
        if let recognizers = view.gestureRecognizers {
            for other in recognizers where other !== pan {
                if let otherPan = other as? UIPanGestureRecognizer, otherPan.minimumNumberOfTouches == 2 {
                    return pan.numberOfTouches < 2
                }
            }
        }
        if let hit = view.hitTest(pan.location(in: view), with: nil) as? UIControl {
            return !hit.isTracking
        }
        return true
    }

    /// Trackpad two-finger scroll delivers no `UITouch`, so `touchesBegan`/`onTouchDown`/
    /// `shouldBeginImmediately` never fire for it and there is no `onTouchUp` either. UIKit consults
    /// this delegate (the `UIEvent` overload) only once per gesture, at finger-down, while the
    /// recognizer is still `.possible` — the trackpad equivalent of `touchesBegan`. We catch any
    /// in-flight motion AND force `state = .began` (the public-API analogue of touch's
    /// `shouldBeginImmediately` path): the existing `handlePan(.began)` then runs (sawDrag, second
    /// catch as a no-op, `core.beginDrag` at the caught offset), and on natural finger-lift UIKit
    /// transitions the recognizer through `.ended` → `handlePan(.ended)` → `core.endDrag()`. Per
    /// `ScrollAxis.endDrag`, an overscrolled offset returns `.decelerate` regardless of a prior
    /// `beginDrag`, so a trackpad rest-then-lift over a bounce resumes the bounce — exactly as touch
    /// does. Gated on motion (mirrors `shouldBeginImmediately`'s condition) so a finger-rest on idle
    /// content lets the recognizer transition naturally on the user's first movement. The catch runs
    /// even if UIKit silently no-ops the state write (safety net). Always returns `true`. Touch is
    /// unaffected — UIKit consults this overload only for scroll events.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        guard gestureRecognizer.state == .possible, flight != nil || core.isDecelerating else { return true }
        catchMotionForFingerRest()
        // Mark the forced-began path so handlePan(.began) captures the recognizer's stale translation as
        // a baseline (the indirect-scroll recognizer ignores setTranslation, so we subtract our own
        // baseline in .changed to make drag math see the delta since the catch, not the cumulative
        // translation that leaked from the prior gesture). See `beganWasForced` for the full why.
        beganWasForced = true
        gestureRecognizer.state = .began
        return true
    }
}

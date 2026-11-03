import UIKit

/// A minimal custom scroll view driven entirely by the reverse-engineered `ScrollPhysics` core —
/// no `UIScrollView`. A real `UIPanGestureRecognizer` feeds drag translation/velocity to the physics
/// (the same inputs UIScrollView consumes); a `CADisplayLink` steps the deceleration once per frame.
/// Drag, rubber-band, flick deceleration, and edge bounce all fall out of the physics. Vertical-only.
final class PhysicsScrollView: UIView {
    /// Host your content here; lay it out in your own coordinates (origin at the content top).
    let contentView = UIView()

    /// Total scrollable content height. Set after laying out `contentView`'s subviews.
    var contentHeight: CGFloat = 0 { didSet { clampWhenIdle(); setNeedsLayout() } }

    /// Live state for a HUD: current offset (pts), velocity (pts/ms), and phase.
    var onScroll: ((_ offsetY: CGFloat, _ velocityY: CGFloat, _ phase: ScrollAxis.Phase) -> Void)?

    /// How a flick/bounce plays out after release. `.stepped` integrates the physics on the main
    /// thread once per frame (the original behaviour); `.keyframe` precomputes the whole path and
    /// plays it as a render-server `CAKeyframeAnimation`. See the design doc.
    enum DecelerationMode { case stepped, keyframe }
    var decelerationMode: DecelerationMode = .keyframe

    private let pan = PhysicsPanGestureRecognizer(target: nil, action: nil)
    private var physics: ScrollPhysics?
    private var displayLink: CADisplayLink?
    private var offsetY: CGFloat = 0          // currently applied content offset

    // Keyframe-flight state (nil/zero unless a `.keyframe` deceleration is in flight).
    private var trajectory: Trajectory?
    private var flightStartLocalTime: CFTimeInterval = 0
    private var flightGeneration = 0
    private static let flightAnimationKey = "decelerationFlight"

    /// Layer-LOCAL time (CLAUDE.md gotcha). Equals `CACurrentMediaTime()` only at default layer speed;
    /// reading it via `convertTime` keeps the flight sampler on CA's rendered position under slow-mo.
    static func localTime(of layer: CALayer) -> CFTimeInterval {
        layer.convertTime(CACurrentMediaTime(), from: nil)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        addSubview(contentView)
        pan.addTarget(self, action: #selector(handlePan(_:)))
        pan.onTouchDown = { [weak self] timestamp in                // stop moving content on touch-down
            guard let self else { return }
            // `-[UIScrollView _beginTrackingWithEvent:]` — where the repeated-flick streak is
            // carried or expired. A distinct moment from the pan beginning.
            self.release.beginTouchTracking(at: timestamp)
            self.catchContent()
        }
        pan.onTouchUp = { [weak self] in self?.handleTouchUp() }
        pan.delegate = self   // trackpad finger-down catch via shouldReceive(event:) — see the extension
        addGestureRecognizer(pan)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var maxOffsetY: CGFloat { Swift.max(0, contentHeight - bounds.height) }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = CGRect(x: 0, y: -offsetY, width: bounds.width, height: contentHeight)
    }

    /// Build a fresh 2-axis physics anchored at the current offset. X is a no-scroll axis (min==max).
    private func makePhysics() -> ScrollPhysics {
        let scale = Swift.max(traitCollection.displayScale, 1)
        // Trackpad (indirect) overscroll uses a looser rubber-band than touch (0.715 vs 0.55).
        let c = pan.isIndirectScroll ? RubberBand.trackpadCoefficient : RubberBand.touchCoefficient
        return ScrollPhysics(
            x: ScrollAxis(offset: 0, min: 0, max: 0, range: bounds.width, rate: 0.998, scale: scale, c: c),
            y: ScrollAxis(offset: offsetY, min: 0, max: maxOffsetY, range: bounds.height, rate: 0.998, scale: scale, c: c))
    }

    /// `UIScrollView`'s release path — the same model `PhysicsScrollCore` uses, so this standalone
    /// demo and the list-backing engine feel identical.
    private var release = ReleaseDecision()

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            // Trackpad scrolls deliver no touch-down, so onTouchDown never catches an in-flight
            // keyframe flight — catch it here. Idempotent for touch (onTouchDown already nulled it).
            if trajectory != nil { catchFlight() }
            stopDisplayLink()
            var p = makePhysics()
            p.beginDrag()
            physics = p
            release.beginGesture()
            // `handlePan:` case 1 runs `_updatePanGesture` immediately, so `.began` is a full
            // velocity sample and applies its translation. Dropping it releases a short flick at a
            // quarter of its velocity.
            noteDrag(gr)
        case .changed:
            noteDrag(gr)
        case .ended, .cancelled:
            guard physics != nil else { return }
            let outcome = release.release(recognizerVelocity: gr.velocity(in: self),
                                          at: CACurrentMediaTime())
            let overscrolled = offsetY < 0 || offsetY > maxOffsetY
            switch outcome {
            case let .decelerate(velocity, vScale):
                physics!.x.vScale = vScale
                physics!.y.vScale = vScale
                physics!.applyRelease(velocity: velocity)
                startDeceleration()
            case .stop where overscrolled:
                physics!.applyRelease(velocity: .zero)      // spring back from the edge
                startDeceleration()
            case .stop:
                physics = nil
            }
        default:
            break
        }
    }

    /// One pan callback — `.began` or `.changed` — fed to both the release model and the physics.
    private func noteDrag(_ gr: UIPanGestureRecognizer) {
        release.note(recognizerVelocity: gr.velocity(in: self),
                     translation: gr.translation(in: self))
        physics?.drag(translation: gr.translation(in: self))
        applyOffset()
    }

    /// Touch-down catches moving content immediately (UIScrollView behaviour).
    private func catchContent() {
        if trajectory != nil { catchFlight() }         // keyframe flight: snap model to live + remove anim
        stopDisplayLink()                              // stops the stepping OR the sampling link
        physics = nil                                  // hold the content where the finger landed
        onScroll?(offsetY, 0, .idle)
    }

    /// Catch an in-flight `.keyframe` deceleration: read the live offset from the trajectory, snap the
    /// model to it BEFORE removing the animation (so removal reveals the live position, no flash).
    private func catchFlight() {
        guard let traj = trajectory else { return }
        let localT = Self.localTime(of: contentView.layer) - flightStartLocalTime
        let live = traj.offset(at: localT)
        offsetY = live
        contentView.frame.origin.y = -live             // model == live (sync) before removal
        contentView.layer.removeAnimation(forKey: Self.flightAnimationKey)
        flightGeneration &+= 1                          // a late CA completion now no-ops
        trajectory = nil
    }

    /// Lifting without a drag taking over (e.g. a tap during a bounce) resumes the spring-back if we
    /// caught it overscrolled. `physics != nil` means a drag already drove a release — leave it alone.
    private func handleTouchUp() {
        if physics == nil { startBounceBackIfNeeded() }
    }

    /// Resume the edge bounce after a catch-and-release with no drag (e.g. a tap during a bounce).
    private func startBounceBackIfNeeded() {
        guard offsetY < 0 || offsetY > maxOffsetY else { return }
        var p = makePhysics()
        p.beginDrag()
        p.applyRelease(velocity: .zero)                // overscrolled ⇒ springs back, at zero velocity
        physics = p
        startDeceleration()
    }

    @objc private func step(_ link: CADisplayLink) {
        guard physics != nil else { stopDisplayLink(); return }
        let dtMs = CGFloat((link.targetTimestamp - link.timestamp) * 1000)   // exactly one display frame
        let result = physics!.step(dtMs: dtMs)
        if result.endedDeceleration { release.resetStreakAfterDeceleration() }
        let settled = result.settled
        applyOffset()
        if settled {
            stopDisplayLink()
            physics = nil
        }
    }

    /// Build the path offline, snap the model to the settled offset, and hand the visual path to the
    /// render server. The sampling link reports the live offset; the CA completion finalises.
    private func launchFlight() {
        guard let p = physics else { return }
        let traj = Trajectory.build(from: p.y)
        physics = nil                                  // the trajectory is now the source of truth

        // Defensive: Trajectory.build always appends >= 1 post-t0 sample, so this can't trip for a
        // built trajectory — but guards a hand-constructed/zero-duration path before any CA work.
        guard traj.samples.count >= 2, traj.duration > 0 else {
            offsetY = traj.finalOffset                 // degenerate: snap + settle, no animation
            setNeedsLayout()
            onScroll?(offsetY, 0, .idle)
            return
        }

        trajectory = traj
        offsetY = traj.finalOffset
        contentView.frame.origin.y = -offsetY          // model AT FINAL, synchronously (size invariant)

        let now = Self.localTime(of: contentView.layer)
        flightStartLocalTime = now
        flightGeneration &+= 1
        let generation = flightGeneration

        // disablingImplicitActions: false — this site never disabled them.
        let flightAnim = traj.positionKeyframeAnimation(beginTime: now)
        flightAnim.preferHighRefreshRate()
        flightAnim.setCoreListCompletion { [weak self] _ in
            guard let self, self.flightGeneration == generation else { return } // ignore stale completions
            self.finalizeFlight()
        }
        contentView.layer.add(flightAnim, forKey: Self.flightAnimationKey)

        startSamplingLink()
    }

    /// Report the live offset/velocity by sampling the trajectory at the current layer-local time.
    /// Time-indexed, so a dropped frame self-corrects on the next tick. (Later: a CoreVirtualListView
    /// consumer virtualises off this value.)
    @objc private func sampleTick(_ link: CADisplayLink) {
        guard let traj = trajectory else { stopDisplayLink(); return }
        let localT = Self.localTime(of: contentView.layer) - flightStartLocalTime
        if localT >= traj.duration { finalizeFlight(); return }   // dual finalize: don't rely solely on the CA completion
        onScroll?(traj.offset(at: localT), traj.velocity(at: localT), .decelerating)
    }

    /// Authoritative end-of-flight (fired by the CA completion). The model is already at the settled
    /// offset; just tear down and report idle.
    private func finalizeFlight() {
        guard trajectory != nil else { return }   // idempotent: sampler OR CA completion may fire first
        stopDisplayLink()
        trajectory = nil
        physics = nil
        onScroll?(offsetY, 0, .idle)
    }

    private func applyOffset() {
        guard let p = physics else { return }
        offsetY = p.y.offset
        setNeedsLayout()
        onScroll?(offsetY, p.y.velocity, p.y.phase)
    }

    /// Keep the content in range when the geometry changes while not interacting. "Idle" means no
    /// stepped physics AND no keyframe flight — a `.keyframe` flight nulls `physics` (the trajectory
    /// owns the motion), so `physics == nil` alone no longer implies idle.
    private func clampWhenIdle() {
        guard physics == nil, trajectory == nil else { return }
        offsetY = Swift.min(Swift.max(offsetY, 0), maxOffsetY)
    }

    private func startDeceleration() {
        switch decelerationMode {
        case .stepped:  startSteppingLink()
        case .keyframe: launchFlight()
        }
    }

    private func startSamplingLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(sampleTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func startSteppingLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit { displayLink?.invalidate() }
}

extension PhysicsScrollView: UIGestureRecognizerDelegate {
    /// Trackpad two-finger scroll delivers no `UITouch`, so `onTouchDown` (which catches a decelerating
    /// flight on finger-down for touch) never fires for it. This public delegate callback IS offered the
    /// indirect-scroll event the instant two fingers land — while the recognizer is still `.possible`,
    /// before it recognizes a drag — so catching here stops the flight on trackpad finger-rest exactly
    /// as `onTouchDown` does for touch. (The `.possible` gate confines the catch to finger-down: it must
    /// not fire mid-drag, which would null the physics.) Always returns `true` (never blocks the event).
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        if gestureRecognizer.state == .possible { catchContent() }
        return true
    }
}

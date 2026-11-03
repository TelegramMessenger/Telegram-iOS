import UIKit

/// Side-by-side A/B of a REAL `UIScrollView` against the physics replica, driven by ONE gesture.
///
/// Matching two flicks by hand is impossible to do well enough to judge an initial-speed difference,
/// and every trace comparison so far has been of two gestures that merely resembled each other. This
/// removes the variable entirely: our engine is driven from `scrollView.panGestureRecognizer` itself,
/// so it receives the exact translation and velocity stream UIKit is using for that same touch — no
/// second recognizer, no arbitration, no simultaneity grant (the module's standing rule against
/// granting simultaneity is untouched, because there is only ever one recognizer).
///
/// LEFT column (blue) rides the real `contentOffset`; RIGHT column (orange) rides our engine. Both
/// draw the same numbered bands, so any difference in position — and especially in the opening frames
/// of a flick, which is the reported symptom — is directly visible as the two columns separating.
final class ScrollComparisonViewController: UIViewController, UIGestureRecognizerDelegate,
                                            UIScrollViewDelegate {

    private let scrollView = UIScrollView()
    private let realColumn = BandView()
    private let ourColumn = BandView()
    /// Not in the responder chain: touches must reach the scroll view, and this exists only to be
    /// scrolled by us. `contentHost` is the engine's own view; we host it here.
    private let ourContainer = UIView()

    private let engine = PhysicsScrollEngine()
    private let readout = UILabel()
    private let modeControl = UISegmentedControl(items: ["keyframe", "stepped"])
    /// Release hand-off, in display frames.
    ///
    /// It was built to find how much of a frame UIScrollView applies at release, by comparing openings.
    /// That question is answered, and the answer for the `.keyframe` path is NONE: the hand-off is a
    /// model-write driver's compensation, and a render-server-played trajectory gets the same frame
    /// from the commit-to-display delay (`PhysicsScrollEngine.launchFlight`). This control therefore no
    /// longer moves the opening — it only decides how marginal a release has to be for the probe to
    /// settle it instead of launching a flight. Note also what hid the defect here: this harness reads
    /// `UIScrollView.contentOffset`, a MODEL value, against our own model, and the delay cancels in
    /// that comparison — so the hand-off really is needed for the two models to agree.
    private let handOffControl = UISegmentedControl(items: ["0", "¼", "½", "1 frame"])
    private let handOffValues: [CGFloat] = [0, 0.25, 0.5, 1.0]
    /// WHICH recognizer drives the replica. Driving from `scrollView.panGestureRecognizer` removes all
    /// gesture variance and isolates the PHYSICS — but it also bypasses our own recognizer entirely,
    /// so it cannot see a difference that originates there. UIScrollView's pan is
    /// `UIScrollViewPanGestureRecognizer`, a private subclass that overrides `velocityInView:`; ours is
    /// a plain `UIPanGestureRecognizer`. If the two report different velocities for the same touch,
    /// that is invisible in the isolated mode and is exactly what this switch exposes.
    private let sourceControl = UISegmentedControl(items: ["drive: UIKit pan", "drive: our pan"])
    private lazy var ourPan = PhysicsPanGestureRecognizer(target: self, action: #selector(handleOurPan(_:)))
    private var drivesFromOurPan: Bool { sourceControl.selectedSegmentIndex == 1 }
    /// Both recognizers' reported velocity at the last release, for the same touch.
    private var lastUIKitVelocity: CGFloat = 0
    private var lastOurVelocity: CGFloat = 0
    /// UIKit's `_fastScrollMultiplier`, measured from OUTSIDE. `scrollViewWillEndDragging` hands us the
    /// release velocity and the target UIKit projects from it; the analytic projection for that
    /// velocity is `(|v| − 0.01)/|ln rate|`, and `_getBouncingDecelerationOffset` scales the
    /// free-deceleration term by the multiplier. So target ÷ analytic IS the multiplier, without
    /// needing the ivar. On a burst of fast flicks it should climb above 1 while ours stays at 1.
    private var uikitMultiplier: CGFloat = 1
    private var uikitBurstCount = 0
    /// Peaks over the current BURST. The live figures above are unreadable for the thing they exist to
    /// measure: a multiplier is only raised while a flight is running, and a running flight is exactly
    /// when the UI never settles, so any snapshot taken after the burst reads the post-settle reset.
    /// These hold until a flick arrives with the streak already back at zero — i.e. a new burst.
    private var peakUIKitMultiplier: CGFloat = 1
    private var peakOurMultiplier: CGFloat = 1
    private var peakStreak = 0

    private let contentHeight: CGFloat = 40_000
    /// SIGNED extremes: `ours - real`. Positive means the replica is AHEAD of the real scroll view,
    /// negative means behind — which is the whole question, and an unsigned maximum cannot answer it.
    private var peakAhead: CGFloat = 0
    private var peakBehind: CGFloat = 0
    /// Peaks split at the release. The two phases are different mechanisms — drag TRACKING versus
    /// deceleration — and a combined figure cannot tell them apart, which made a half-frame hand-off
    /// look barely different from none at all.
    private var dragAhead: CGFloat = 0
    private var dragBehind: CGFloat = 0
    private var isDecelerating = false
    private var displayLink: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentSize = CGSize(width: view.bounds.width, height: contentHeight)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        realColumn.tint = .systemBlue
        scrollView.addSubview(realColumn)
        view.addSubview(scrollView)

        ourContainer.isUserInteractionEnabled = false      // every touch belongs to the scroll view
        ourContainer.clipsToBounds = true
        ourColumn.tint = .systemOrange
        engine.contentHost.addSubview(ourColumn)
        ourContainer.addSubview(engine.contentHost)
        view.addSubview(ourContainer)

        // THE point of the harness: one gesture, both physics.
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handleSharedPan(_:)))
        // Our own recognizer, on the same view, seeing the same touches. Simultaneity is granted HERE
        // ONLY — a debug harness whose entire purpose is to run both recognizers against one gesture.
        // The engine's own delegate still refuses it everywhere else.
        ourPan.delegate = self
        // The engine's own touch-down hookup lives on the engine's own recognizer, which never sees
        // these touches. Route it from here, in BOTH drive modes: the touch-down moment is what
        // expires a stale streak and carries the multiplier forward, so without it the replica cannot
        // compound across a burst no matter what drives the drag.
        ourPan.onTouchDown = { [weak self] t in self?.engine.noteTouchDown(at: t) }
        scrollView.addGestureRecognizer(ourPan)

        sourceControl.selectedSegmentIndex = 0
        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        handOffControl.selectedSegmentIndex =
            handOffValues.firstIndex(of: PhysicsScrollEngine.releaseHandOffFrames) ?? 2
        handOffControl.addTarget(self, action: #selector(handOffChanged), for: .valueChanged)
        readout.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        readout.numberOfLines = 0
        readout.textAlignment = .center
        let bar = UIStackView(arrangedSubviews: [sourceControl, modeControl, handOffControl, readout])
        bar.axis = .vertical
        bar.spacing = 4
        bar.isLayoutMarginsRelativeArrangement = true
        bar.layoutMargins = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    deinit { displayLink?.invalidate() }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let half = view.bounds.width / 2
        scrollView.contentSize = CGSize(width: view.bounds.width, height: contentHeight)
        realColumn.frame = CGRect(x: 0, y: 0, width: half, height: contentHeight)
        ourContainer.frame = CGRect(x: half, y: 0, width: half, height: view.bounds.height)
        engine.contentHost.frame = ourContainer.bounds
        ourColumn.frame = CGRect(x: 0, y: 0, width: half, height: contentHeight)
        // Same scrollable range as the real one, so edge behaviour matches too.
        engine.setEdges(min: 0, max: Swift.max(0, contentHeight - view.bounds.height))
    }

    @objc private func handOffChanged() {
        let frames = handOffValues[handOffControl.selectedSegmentIndex]
        PhysicsScrollEngine.releaseHandOffFrames = frames
        PhysicsScrollEngine.appliesReleaseHandOff = frames > 0
    }

    @objc private func modeChanged() {
        engine.decelerationMode = modeControl.selectedSegmentIndex == 0 ? .keyframe : .stepped
    }

    func scrollViewWillEndDragging(_ sv: UIScrollView, withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let v = abs(velocity.y)
        let analytic = (v - 0.01) / abs(log(sv.decelerationRate.rawValue))
        let projected = abs(targetContentOffset.pointee.y - sv.contentOffset.y)
        uikitMultiplier = analytic > 1 ? projected / analytic : 1
        uikitBurstCount = uikitMultiplier > 1.02 ? uikitBurstCount + 1 : 0
        peakUIKitMultiplier = Swift.max(peakUIKitMultiplier, uikitMultiplier)
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true     // harness only — see `ourPan`
    }

    /// Our own recognizer on the same touch. Records its velocity for comparison always, and drives
    /// the replica when selected.
    @objc private func handleOurPan(_ gr: UIPanGestureRecognizer) {
        if gr.state == .ended || gr.state == .cancelled { lastOurVelocity = gr.velocity(in: view).y }
        guard drivesFromOurPan else { return }
        feed(gr)
    }

    /// The real scroll view's OWN pan, forwarded into the replica unchanged.
    @objc private func handleSharedPan(_ gr: UIPanGestureRecognizer) {
        if gr.state == .ended || gr.state == .cancelled { lastUIKitVelocity = gr.velocity(in: view).y }
        guard !drivesFromOurPan else {
            if gr.state == .began { resetPeaks() }       // still own the peak bookkeeping
            return
        }
        feed(gr)
    }

    private func resetPeaks() {
        peakAhead = 0; peakBehind = 0; dragAhead = 0; dragBehind = 0
        isDecelerating = false
        engine.setOffset(scrollView.contentOffset.y)
    }

    private func feed(_ gr: UIPanGestureRecognizer) {
        if gr.state == .began {
            resetPeaks()
            // A flick arriving on a cleared streak starts a new burst, so the held peaks are stale.
            if engine.decelerationStreakCount == 0 {
                peakUIKitMultiplier = 1; peakOurMultiplier = 1; peakStreak = 0
            }
        }
        engine.applyPanUpdate(state: gr.state,
                              translation: gr.translation(in: view),
                              velocity: gr.velocity(in: view),
                              forced: false,
                              isIndirect: false)
        if gr.state == .ended || gr.state == .cancelled {
            dragAhead = peakAhead; dragBehind = peakBehind      // freeze the drag-phase figures
            peakAhead = 0; peakBehind = 0                       // and restart for the deceleration
            isDecelerating = true
        }
    }

    @objc private func tick() {
        let real = scrollView.contentOffset.y
        let ours = engine.offset
        let delta = ours - real
        peakAhead = Swift.max(peakAhead, delta)
        peakBehind = Swift.min(peakBehind, delta)
        peakOurMultiplier = Swift.max(peakOurMultiplier, engine.decelerationVelocityScale)
        peakStreak = Swift.max(peakStreak, engine.decelerationStreakCount)
        readout.text = String(
            format: "BLUE left = UIScrollView      ORANGE right = ours\n"
                  + "real %.0f   ours %.0f   Δ %+.0f\nDRAG  ahead %+.0f  behind %+.0f\n%@  ahead %+.0f  behind %+.0f\n"
                  + "release v — UIKit pan %.0f   our pan %.0f   (pts/s)\n"
                  + "MULTIPLIER  UIKit %.2fx   ours %.2fx\nstreak %d   last reset: %@\n"
                  + "BURST PEAK  UIKit %.2fx   ours %.2fx   streak %d",
            real, ours, delta, dragAhead, dragBehind,
            isDecelerating ? "DECEL" : "     ", peakAhead, peakBehind,
            lastUIKitVelocity, lastOurVelocity, uikitMultiplier, engine.decelerationVelocityScale,
            engine.decelerationStreakCount, engine.decelerationStreakReset,
            peakUIKitMultiplier, peakOurMultiplier, peakStreak)
    }
}

/// Numbered horizontal bands, so a difference in position between two columns is legible at a glance.
private final class BandView: UIView {
    var tint: UIColor = .systemBlue { didSet { setNeedsDisplay() } }
    private let band: CGFloat = 100

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let first = Int(floor(rect.minY / band)), last = Int(ceil(rect.maxY / band))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.label,
        ]
        for i in first...last {
            let y = CGFloat(i) * band
            ctx.setFillColor((i % 2 == 0 ? tint.withAlphaComponent(0.30) : tint.withAlphaComponent(0.12)).cgColor)
            ctx.fill(CGRect(x: 0, y: y, width: bounds.width, height: band))
            ("\(i * Int(band))" as NSString).draw(at: CGPoint(x: 8, y: y + 6), withAttributes: attrs)
        }
    }
}

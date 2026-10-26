import UIKit
import QuartzCore

/// Measures **D**, the commit-to-display depth: how long after a main-thread turn's work the frame
/// carrying that turn's commit is actually scanned out, expressed in display frames.
///
/// D is the one number `PhysicsScrollEngine.launchFlight` cannot derive, and the residual it leaves is
/// `(D − 1) × frameTravel`. A baked flight is anchored at `localNow()` and evaluated by the render
/// server at each frame's PRESENTATION time, so the first frame it lands on shows `traj(D)`; the drag
/// it continues advanced by exactly one frame per frame, because a model write is presented D later
/// and D is a constant DELAY, not a rate. So the release is continuous at D = 1 frame and steps
/// forward above that.
///
/// **The instrument is a differential, because nothing in this process can read the screen.**
/// `presentation()` is evaluated on the main thread at `CACurrentMediaTime()`, `render(in:)` and
/// `drawHierarchy` walk the model tree, and `MTLDrawable.presentedTime` / `addPresentedHandler` — the
/// one API that reported real scan-out — are gone from the iOS 27 SDK. What a captured framebuffer
/// CAN show is two things at once. So two identical bars travel the same ramp at the same velocity:
///
/// - **`modelBar`** is moved by a per-frame model write from a display link, the way the drag moves
///   the list. At scan-out time `T` it therefore shows `p(T − D)` — stale by the pipeline.
/// - **`animatedBar`** is moved by a `CABasicAnimation` on an explicit `beginTime`, the way a baked
///   flight moves it. At scan-out time `T` the render server shows `p(T)` exactly — not stale at all.
///
/// Their separation in ONE captured frame is `velocity × D`, with no clock shared between the capture
/// and the app: D falls out of a distance. That separation IS the defect, in its purest form.
///
/// **Diagnostic only — excluded from the Bazel `CoreList` library (see `BUILD`).**
final class PipelineDepthProbe {

    /// Points per second both bars travel. Chosen so one frame of travel is large against the capture's
    /// pixel grid (15pt = 45px at 60Hz/3×, 7.5pt at 120Hz) while a full cycle stays far longer than any
    /// plausible D, so the two bars can never be confused across a wrap.
    static let velocity: CGFloat = 900
    /// Length of the ramp before it restarts.
    static let travel: CGFloat = 600
    static var period: CFTimeInterval { CFTimeInterval(travel / velocity) }

    static let shared = PipelineDepthProbe()

    private(set) var isRunning = false
    private let modelBar = UIView()
    private let animatedBar = UIView()
    private var link: CADisplayLink?
    /// Layer-local origin of the ramp. Both bars are driven from this one value, which is what makes
    /// the separation a pure function of D.
    private var originLocal: CFTimeInterval = 0
    private var host: UIView?
    /// Positive control. `-probeLead <ms>` shifts the ANIMATED bar's `beginTime` earlier by a known
    /// amount, so the measured separation must grow by exactly `velocity × lead`. An instrument that
    /// reads zero is only worth believing if a known offset moves it — without this the whole
    /// apparatus could be measuring nothing and reporting agreement.
    var leadSeconds: CFTimeInterval = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-probeLead"), i + 1 < args.count,
              let ms = Double(args[i + 1]) else { return 0 }
        return ms / 1000.0
    }()

    private init() {}

    /// Bar geometry, in the host's coordinates. `rampTop` is `p(0)`.
    static let barHeight: CGFloat = 8
    static let rampTop: CGFloat = 0

    func attach(to host: UIView) {
        self.host = host
        for (bar, colour) in [(modelBar, UIColor.systemRed), (animatedBar, UIColor.systemBlue)] {
            bar.backgroundColor = colour
            bar.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            host.addSubview(bar)
        }
    }

    func layoutBars(in bounds: CGRect) {
        let w = bounds.width / 2 - 12
        modelBar.frame = CGRect(x: 0, y: Self.rampTop, width: w, height: Self.barHeight)
        animatedBar.frame = CGRect(x: bounds.width / 2 + 12, y: Self.rampTop, width: w, height: Self.barHeight)
    }

    func start() {
        guard !isRunning, let host else { return }
        layoutBars(in: host.bounds)
        // One origin, read through the layer so Slow Animations cannot desync the two halves.
        originLocal = animatedBar.layer.convertTime(CACurrentMediaTime(), from: nil)

        // The time-anchored half: exactly what a baked flight does — an explicit `beginTime`, evaluated
        // by the render server at each frame's own presentation time.
        let anim = CABasicAnimation(keyPath: "position.y")
        anim.fromValue = Self.rampTop + Self.barHeight / 2
        anim.toValue = Self.rampTop + Self.barHeight / 2 + Self.travel
        anim.duration = Self.period
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.repeatCount = .infinity
        anim.beginTime = originLocal - leadSeconds        // 0 unless the positive control is armed
        anim.isRemovedOnCompletion = false
        anim.fillMode = .backwards
        if #available(iOS 15.0, *) {
            let fps = Float(host.window?.screen.maximumFramesPerSecond ?? 60)
            anim.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
        }
        animatedBar.layer.add(anim, forKey: "probe")

        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        if #available(iOS 15.0, *) {
            let fps = Float(host.window?.screen.maximumFramesPerSecond ?? 60)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
        }
        link.add(to: .main, forMode: .common)
        self.link = link
        isRunning = true
    }

    func stop() {
        link?.invalidate()
        link = nil
        animatedBar.layer.removeAnimation(forKey: "probe")
        isRunning = false
    }

    /// The model-write half: the same ramp, written once per frame from the main thread — the way
    /// `PhysicsScrollCore.writeOffset` moves the list under the finger. Implicit actions are disabled
    /// so this is a pure model write with no animation of its own.
    @objc private func step(_ link: CADisplayLink) {
        let local = animatedBar.layer.convertTime(CACurrentMediaTime(), from: nil)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        modelBar.layer.position.y = position(atLocal: local)
        CATransaction.commit()
    }

    private func position(atLocal t: CFTimeInterval) -> CGFloat {
        let elapsed = (t - originLocal).truncatingRemainder(dividingBy: Self.period)
        let phase = CGFloat(elapsed < 0 ? elapsed + Self.period : elapsed) / CGFloat(Self.period)
        return Self.rampTop + Self.barHeight / 2 + phase * Self.travel
    }

    /// What a captured separation means, for the on-screen readout.
    static func interpret(separationPoints gap: CGFloat, refreshHz: Double) -> String {
        let frame = 1.0 / refreshHz
        let depthSeconds = Double(gap / velocity)
        let depthFrames = depthSeconds / frame
        let residualFrames = depthFrames - 1.0
        return String(format: "gap %.1fpt → D = %.2f frames (%.1fms) → residual %.2f frames"
                      + " = %.0fpt at 3000 pt/s", gap, depthFrames, depthSeconds * 1000,
                      residualFrames, residualFrames * 3000.0 * frame)
    }
}

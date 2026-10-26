import UIKit

/// Hand-driven recorder: a tall plain UIScrollView whose real gesture is captured (via the
/// swizzler) into a GestureRecording and saved as JSON. Debug-only. Reachable as the demo's
/// "Recorder" tab (`SceneDelegate`), which is excluded from the Bazel library, so this screen exists
/// only in the standalone demo app.
final class ScrollRecorderViewController: UIViewController {
    let scrollView = UIScrollView()
    private let sink = CaptureSink()
    private var displayLink: CADisplayLink?     // settle detector only — frames come from the swizzle
    private var recordingName: String?
    private var geometry: GestureRecording.Geometry?
    private var releaseTime: TimeInterval?
    private var released = false
    /// Retained so `Dump` can re-emit the take that was just saved.
    private var lastRecording: GestureRecording?
    /// On-screen, selectable transport for a DEVICE recording. A device has no `simctl` container
    /// call and — as this screen exists to work around — no reliable console either, so the payload
    /// has to be readable off the phone itself.
    private let dumpView = UITextView()

    private let gestureNames = ["slow-drag-release", "medium-flick", "flick-into-bottom",
                                "overscroll-release", "creep", "reverse-mid-decel",
                                "short-flick", "repeat-flick"]
    private let nameControl = UISegmentedControl(items: ["slow drag", "flick", "into edge",
                                                         "overscroll", "creep", "reverse",
                                                         "short", "repeat"])
    private let inputKindControl = UISegmentedControl(items: ["Touch", "Trackpad"])
    private let statusLabel = UILabel()

    /// Fixture file/`name` for a scenario, prefixed when recorded via trackpad so touch and
    /// trackpad ground truth never collide in the Fixtures dir.
    static func fixtureName(scenario: String, trackpad: Bool) -> String {
        trackpad ? "trackpad-\(scenario)" : scenario
    }

    static let defaultContentHeight: CGFloat = 6000
    /// `repeat-flick` compounds `_fastScrollMultiplier` across a burst, and REACHING AN EDGE resets
    /// the streak (`0x17a87bc`). A saturated streak projects tens of thousands of points, so the
    /// content has to be tall enough that the burst never lands on the bottom edge — otherwise the
    /// fixture silently records a reset instead of the acceleration it exists to capture.
    static let burstContentHeight: CGFloat = 120_000

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never   // clean zero-inset geometry for fixtures
        scrollView.contentSize = CGSize(width: view.bounds.width, height: Self.defaultContentHeight)
        let content = UILabel()
        content.numberOfLines = 0
        content.text = "Scroll recorder — pick a gesture, tap Record, then flick / drag."
        content.frame = CGRect(x: 16, y: 120, width: view.bounds.width - 32, height: 6000 - 140)
        scrollView.addSubview(content)
        // No delegate: ground truth is captured via the swizzle, not delegate callbacks.
        view.addSubview(scrollView)
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))

        installControlBar()
    }

    /// A floating Record/Stop bar pinned to the top — a sibling of the scroll view, so it does
    /// not intercept scroll drags. Debug-only.
    private func installControlBar() {
        nameControl.selectedSegmentIndex = 0
        inputKindControl.selectedSegmentIndex = 0

        let recordButton = UIButton(type: .system)
        recordButton.setTitle("● Record", for: .normal)
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)

        let dumpButton = UIButton(type: .system)
        dumpButton.setTitle("⇩ Dump", for: .normal)
        dumpButton.addTarget(self, action: #selector(dumpTapped), for: .touchUpInside)

        let stopButton = UIButton(type: .system)
        stopButton.setTitle("■ Stop", for: .normal)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)

        statusLabel.text = "Idle"
        statusLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        statusLabel.numberOfLines = 0            // the shape summary is read off the DEVICE screen,
        statusLabel.adjustsFontSizeToFitWidth = true   // so no console or cable is needed to triage a take
        statusLabel.minimumScaleFactor = 0.5

        let buttons = UIStackView(arrangedSubviews: [recordButton, stopButton, dumpButton])
        buttons.axis = .horizontal
        buttons.spacing = 16
        buttons.alignment = .firstBaseline

        let bar = UIStackView(arrangedSubviews: [inputKindControl, nameControl, buttons, statusLabel])
        bar.axis = .vertical
        bar.spacing = 8
        bar.isLayoutMarginsRelativeArrangement = true
        bar.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        bar.translatesAutoresizingMaskIntoConstraints = false

        let background = UIView()
        background.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        background.translatesAutoresizingMaskIntoConstraints = false

        dumpView.isHidden = true
        dumpView.isEditable = false
        dumpView.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        dumpView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.97)
        dumpView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(background)
        view.addSubview(bar)
        view.addSubview(dumpView)
        NSLayoutConstraint.activate([
            dumpView.topAnchor.constraint(equalTo: bar.bottomAnchor),
            dumpView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dumpView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dumpView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            background.topAnchor.constraint(equalTo: view.topAnchor),
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            background.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        ])
    }

    // MARK: Controls

    @objc private func recordTapped() {
        let scenario = gestureNames[nameControl.selectedSegmentIndex]
        let name = Self.fixtureName(scenario: scenario, trackpad: inputKindControl.selectedSegmentIndex == 1)
        // Deterministic start position (idle, BEFORE capture starts so it isn't recorded): so a single
        // gesture exercises the intended scenario regardless of where the previous one left off.
        scrollView.contentSize = CGSize(
            width: scrollView.bounds.width,
            height: scenario == "repeat-flick" ? Self.burstContentHeight : Self.defaultContentHeight)
        let maxY = Swift.max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let startY: CGFloat
        switch scenario {
        case "flick-into-bottom":  startY = Swift.max(0, maxY - 1000)  // room: one firm flick → edge + bounce
        case "overscroll-release": startY = maxY                       // at the bottom edge → drag up to overscroll
        case "reverse-mid-decel": startY = Swift.max(0, maxY / 2)  // room to scroll then reverse mid-momentum
        case "creep":             startY = 0                       // top → very slow creep
        default:                   startY = 0                          // top → drag / flick downward
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: startY), animated: false)
        beginRecording(named: name)
        statusLabel.text = "● Recording: \(name)"
    }

    @objc private func stopTapped() { finishAndSave() }

    /// Print the last recording in a console-transportable form (see `compactJSON`). Debug-only escape
    /// hatch for a DEVICE, where the Documents container is not a `simctl` call away.
    @objc private func dumpTapped() {
        guard let rec = lastRecording else { statusLabel.text = "Nothing to dump"; return }
        if !dumpView.isHidden { dumpView.isHidden = true; return }   // tap again to dismiss
        let payload = Self.landingDigest(rec)
        dumpView.text = payload
        dumpView.isHidden = false
        UIPasteboard.general.string = payload    // Universal Clipboard, if the Mac is on the same ID
        print("[ScrollRecorder] ===== \(rec.name) =====\n\(payload)")
    }

    /// Everything needed to re-derive the release and compare our landing against the real one, in
    /// about a dozen short lines: the geometry, the whole touch stream, and the ground-truth extent
    /// plus the deceleration cadence. Deliberately NOT the full recording — the frame-by-frame
    /// trajectory is ~30kB, and the question "does our replica land where UIScrollView landed" only
    /// needs the endpoints. Fetch the full JSON afterwards if the landing disagrees.
    static func landingDigest(_ rec: GestureRecording) -> String {
        let g = rec.geometry
        var out = [String]()
        out.append(String(format: "NAME %@", rec.name))
        out.append(String(format: "GEO ch=%.0f bh=%.0f it=%.0f ib=%.0f sc=%.0f dr=%.4f",
                          g.contentHeight, g.boundsHeight, g.insetTop, g.insetBottom,
                          g.scale, g.decelerationRate))
        for s in rec.touches {
            out.append(String(format: "TCH t=%.4f p=%@ s=%d tr=%.2f v=%.1f",
                              s.t, s.phase.rawValue, s.state, s.translation.y, s.velocity.y))
        }
        if let r = rec.releaseTime { out.append(String(format: "REL t=%.4f", r)) }
        let gt = rec.frames.map { $0.groundTruthOffset.y }
        out.append(String(format: "GT n=%d first=%.2f last=%.2f max=%.2f",
                          gt.count, gt.first ?? 0, gt.last ?? 0, gt.max() ?? 0))
        var dts = [Double]()
        var prev: GestureRecording.Frame?
        for f in rec.frames {
            if let p = prev, p.phase == .decelerating, f.phase == .decelerating { dts.append(f.t - p.t) }
            prev = f
        }
        dts.sort()
        out.append(String(format: "DT decelMs=%.3f n=%d",
                          dts.isEmpty ? 0 : dts[dts.count / 2] * 1000, dts.count))
        let dragFrames = rec.frames.filter { $0.phase == .dragging }
        out.append("DRAGTR " + dragFrames.map { String(format: "%.2f", $0.translation.y) }
                                          .prefix(12).joined(separator: ","))
        out.append(Self.shapeSummary(rec))
        return out.joined(separator: "\n")
    }

    /// The shape facts that decide whether a take is USABLE, short enough to read off the phone.
    ///
    /// `chg` is the one that matters for a short flick: UIKit's release low-pass is guarded, so an
    /// engine that drops the `.began` sample only diverges at `chg <= 1`. At `chg >= 2` the old and
    /// new models agree exactly and the take proves nothing.
    static func shapeSummary(_ rec: GestureRecording) -> String {
        let driving = rec.touches.filter(\.hasRecognized)
        let changed = driving.dropFirst().filter { $0.phase == .moved }
        let ends = rec.touches.filter { $0.phase == .ended || $0.phase == .cancelled }
        let begins = rec.touches.filter { $0.phase == .began }
        var gaps: [String] = []
        for (i, e) in ends.enumerated() where i + 1 < begins.count {
            gaps.append(String(format: "%.2f", begins[i + 1].t - e.t))
        }
        let peak = driving.map { Swift.max(abs($0.velocity.x), abs($0.velocity.y)) }.max() ?? 0
        var out = String(format: "frames=%d touch=%d drv=%d chg=%d gestures=%d peak=%.0f",
                         rec.frames.count, rec.touches.count, driving.count, changed.count,
                         ends.count, peak)
        if !gaps.isEmpty { out += " gaps=[" + gaps.joined(separator: ",") + "]" }
        return out
    }

    /// Same schema as a saved fixture — it decodes verbatim — but transportable through a terminal:
    /// no pretty-printing, no `rubberBandSamples` (only the four original fixtures assert those), and
    /// values rounded to 0.001, far below the ~1px bounds these fixtures are held to. Roughly a third
    /// the size of the saved file.
    func compactJSON(_ rec: GestureRecording) -> String {
        func r(_ v: CGFloat) -> CGFloat { (v * 1000).rounded() / 1000 }
        func r(_ p: CGPoint) -> CGPoint { CGPoint(x: r(p.x), y: r(p.y)) }
        func r(_ t: TimeInterval) -> TimeInterval { (t * 1000).rounded() / 1000 }
        let trimmed = GestureRecording(
            name: rec.name,
            geometry: rec.geometry,
            frames: rec.frames.map {
                .init(t: r($0.t), phase: $0.phase, translation: r($0.translation),
                      recognizerVelocity: r($0.recognizerVelocity),
                      groundTruthOffset: r($0.groundTruthOffset))
            },
            rubberBandSamples: [],
            touches: rec.touches.map {
                .init(t: r($0.t), centroid: r($0.centroid), phase: $0.phase,
                      translation: r($0.translation), velocity: r($0.velocity), state: $0.state)
            },
            releaseTime: rec.releaseTime.map(r))
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return (try? enc.encode(trimmed)).flatMap { String(data: $0, encoding: .utf8) } ?? "<encode failed>"
    }

    /// End the current recording (if any), save it, and reflect the result in the status label.
    private func finishAndSave() {
        guard recordingName != nil else { return }
        let rec = endRecording()
        lastRecording = rec
        let url = save(rec)
        let summary = Self.shapeSummary(rec)
        print("[ScrollRecorder] \(rec.name): \(summary)")
        statusLabel.text = (url == nil ? "Save failed\n" : "✓ \(rec.name)\n") + summary
    }

    // MARK: Recording lifecycle (also driven directly by tests)

    func beginRecording(named name: String) {
        sink.attach(to: scrollView)   // self-contained: installs swizzle hooks + sets the time baseline
        released = false
        releaseTime = nil
        recordingName = name
        geometry = GestureRecording.Geometry(
            contentWidth: scrollView.contentSize.width, contentHeight: scrollView.contentSize.height,
            boundsWidth: scrollView.bounds.width, boundsHeight: scrollView.bounds.height,
            insetTop: scrollView.adjustedContentInset.top, insetLeft: scrollView.adjustedContentInset.left,
            insetBottom: scrollView.adjustedContentInset.bottom, insetRight: scrollView.adjustedContentInset.right,
            scale: scrollView.traitCollection.displayScale == 0 ? 2 : scrollView.traitCollection.displayScale,
            decelerationRate: scrollView.decelerationRate.rawValue)
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func endRecording() -> GestureRecording {
        displayLink?.invalidate(); displayLink = nil
        let zero = GestureRecording.Geometry(contentWidth: 0, contentHeight: 0, boundsWidth: 0, boundsHeight: 0,
                                             insetTop: 0, insetLeft: 0, insetBottom: 0, insetRight: 0,
                                             scale: 2, decelerationRate: 0.998)
        let rec = GestureRecording(name: recordingName ?? "empty", geometry: geometry ?? zero,
                                   frames: sink.frames, rubberBandSamples: sink.rubberBandSamples,
                                   touches: sink.touches, releaseTime: releaseTime)
        sink.detach()
        recordingName = nil; geometry = nil; releaseTime = nil
        return rec
    }

    /// Write a recording to the app Documents dir and print the path (for `simctl` retrieval).
    @discardableResult
    func save(_ rec: GestureRecording) -> URL? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = dir.appendingPathComponent("\(rec.name).json")
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        do { try enc.encode(rec).write(to: url); print("[ScrollRecorder] saved:", url.path); return url }
        catch { print("[ScrollRecorder] save failed:", error); return nil }
    }

    // MARK: Live capture

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        guard recordingName != nil, !released else { return }
        if gr.state == .ended || gr.state == .cancelled {
            released = true
            releaseTime = sink.elapsed()   // touch-up time → the deceleration clock baseline (analysis §2)
        }
    }

    /// Settle detector only: frames are event-sourced from the `setContentOffset:` swizzle, not here.
    @objc private func tick() {
        guard recordingName != nil else { return }
        if released && !scrollView.isDecelerating && !scrollView.isDragging {
            finishAndSave()
        }
    }
}

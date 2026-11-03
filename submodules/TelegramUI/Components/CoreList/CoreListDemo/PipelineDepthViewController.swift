import UIKit

/// Front end for `PipelineDepthProbe` — see that file for what D is, why it matters to
/// `PhysicsScrollEngine.launchFlight`, and why the instrument has to be a differential.
///
/// Read it by RECORDING THE SCREEN, not by looking at this process: the separation between the red
/// (model-write) and blue (time-anchored) bars in one captured frame is `velocity × D`.
/// `Tools/measure-pipeline-depth.py` drives the whole thing.
///
/// **It must be `simctl io recordVideo`, never `simctl io screenshot`.** The screenshot path
/// re-renders on demand rather than sampling a composited frame: measured, the gap wandered between
/// 0 and 37px with no stable value, while the red bar's own positions stayed cleanly quantized to one
/// frame of travel — so the noise was entirely in the capture. `recordVideo` taps per frame and gives
/// a gap with a 1px standard deviation.
///
/// **Diagnostic only — excluded from the Bazel `CoreList` library (see `BUILD`).**
final class PipelineDepthViewController: UIViewController {

    private let track = UIView()
    private let startButton = UIButton(type: .system)
    private let explanation = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        // A flat, saturated background: the capture is analysed by colour, so nothing else on this
        // screen may be red or blue.
        view.backgroundColor = .white

        explanation.numberOfLines = 0
        explanation.font = .systemFont(ofSize: 12)
        explanation.textColor = .darkGray
        explanation.text = """
            RED is moved by a per-frame model write (how the drag moves the list); BLUE by a \
            CABasicAnimation on an explicit beginTime (how a baked flight moves it). Both ride the \
            same ramp at 900 pt/s from one shared origin.

            At scan-out, red shows p(T − D) and blue shows p(T). Their separation in a CAPTURED frame \
            is therefore velocity × D — and D is what decides whether launchFlight's residual is real. \
            RECORD the screen and measure the gap; this process cannot read its own screen, and a \
            screenshot re-renders on demand rather than sampling a composited frame.
            """

        startButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        startButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)

        track.backgroundColor = .white
        track.clipsToBounds = true

        for v in [explanation, startButton, track] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        NSLayoutConstraint.activate([
            explanation.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            explanation.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            explanation.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            startButton.topAnchor.constraint(equalTo: explanation.bottomAnchor, constant: 10),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            track.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 10),
            track.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            track.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            track.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        PipelineDepthProbe.shared.attach(to: track)
        refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !PipelineDepthProbe.shared.isRunning { PipelineDepthProbe.shared.layoutBars(in: track.bounds) }
    }

    @objc private func toggle() {
        let probe = PipelineDepthProbe.shared
        if probe.isRunning { probe.stop() } else { probe.start() }
        refresh()
    }

    private func refresh() {
        startButton.setTitle(PipelineDepthProbe.shared.isRunning ? "Stop" : "Start", for: .normal)
    }
}

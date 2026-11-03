import UIKit
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

/// **TASK PH4b — the same three arms, ONE ARM PER PROCESS.**
///
/// ## Why this file exists
///
/// PH4 measured the underline defect on three arms and got a result it correctly refused to bill:
///
/// | arm | cleared the marker |
/// | --- | --- |
/// | stock `UITextView` | 6/6 |
/// | Telegram + InputDec | 0/6 (392 px, zero variance) |
/// | Telegram + **legacy — what ships today** | **3/6, bimodally (0 or 375, never between)** |
///
/// That legacy number decides who owns the user's complaint. If the shipping backend really does
/// fail to withdraw the marker half the time, then part of "corrected words are not underlined" is
/// PRE-EXISTING and the port is being over-charged. If it is an artefact, the port owns all of it.
///
/// PH4 could not tell, and said so: its three arms run **in sequence in one process**, only one view
/// can hold the responder role, so legacy is always measured fourth (after the warm-up, stock and
/// InputDec have each been focused and resigned). Order effects on the process-wide system checker
/// were not excluded.
///
/// ## What is different here, and it is exactly one thing
///
/// Each test method below measures **one arm and nothing else**, and the sweep runs each in its own
/// `xcodebuild test -only-testing:` invocation, so each arm gets a **freshly launched host-app
/// process**. Everything else — the driver, the settle rule, the pixel instrument, the band, the
/// warm-up, the fixture, the simulator — is `HostedUnderlineArmProbeCase`, moved verbatim out of
/// PH4's suite for precisely this reason. **Process isolation is the only variable that moved.**
///
/// The isolation is not merely promised by how the sweep is invoked; it is **checked inside the
/// process**. `HostedUnderlineArmProbeCase.armsMeasuredInThisProcess` counts arms actually driven,
/// and each method asserts it is 1 when its own arm finishes. Run two of these methods in one
/// `xcodebuild` invocation and the second one fails and says why, rather than quietly reproducing
/// the very confound this file exists to remove.
///
/// ## Why a null result here is a measurement and not an absence
///
/// This programme has three times produced a confident answer from a measurement that read nothing:
/// a parity harness whose arms all declined and compared equal; a runtime gate that passed because
/// it iterated zero contracts; a spelling oracle that read zero pixels because the probe
/// short-circuited before the pixel question. So "legacy clears every time" must be distinguishable
/// from "this harness can no longer see a marker at all". Three guards, all in-process:
///
/// 1. **A calibration control that is KNOWN to differ, in every single run.** Before the arm is
///    touched, a stock view carrying a *deliberate* red `NSUnderlineStyle` is rendered and counted.
///    It must read non-zero. Its number is printed on every row, so a row of zeros is always
///    accompanied by a proof that the same instrument, in the same process, seconds earlier, saw a
///    known red underline. A zero is only worth reporting after that.
/// 2. **The arm's own before/after pair.** `misspelledRed` is read from the same band, on the same
///    view, moments before `correctedRed`. `markerPresent` (misspelledRed > 3) is asserted, so a
///    "cleared" verdict can never come from an arm that never marked anything. A run that fails
///    that assertion is VOID, not a pass.
/// 3. **Two arms with known, opposite behaviour are measured under the identical isolation.**
///    stock is known to clear 6/6; InputDec is known never to clear (392 px, zero variance). If the
///    isolated harness reproduces both of those, then it can demonstrably resolve *clear* from
///    *not clear*, and whatever it reports for legacy is a reading rather than a blind spot. This
///    is the two-sided control, and it is the reason stock and InputDec are re-run here at all
///    rather than quoted from PH4.
///
/// ## Sample size — why 20 for legacy and 10 for the controls
///
/// The hypotheses to separate are H0 "legacy clears essentially always, and 3/6 was an order
/// artefact" (p ≈ 1) against H1 "legacy has a real intermittent defect at roughly the observed rate"
/// (p ≈ 0.5). Under H1, the chance that **n** isolated runs all clear is 2⁻ⁿ: 1/64 at the n=6 PH4
/// ran, which is why 6 was too few, and about **1 in a million at n=20**. So 20 clean clears refute
/// H1 decisively, and any count near 10 confirms it just as decisively.
///
/// 20 is chosen for what it can and cannot say, both stated rather than implied: all-20-clear puts
/// a 95% upper bound of about **14%** on any residual intrinsic failure rate (rule of three, 3/20).
/// That excludes the ~50% under test by a wide margin; it does **not** exclude a rare failure, and
/// this file does not claim to.
///
/// The controls get 10 each. They are not being estimated — they already have zero variance across
/// PH4's 6 runs — they are being *re-confirmed under isolation*, and 10 identical readings is ample
/// for that while keeping the sweep to 40 process launches.
///
/// ## These tests assert VALIDITY, not the outcome
///
/// Deliberately. They are the instrument for a sweep whose verdict is computed from the printed
/// `PH4B-ROW` lines, so a run that measured cleanly must exit 0 whichever way the marker went;
/// otherwise a sweep of 40 invocations could not distinguish "the arm did not clear" from "the
/// invocation broke". What they *do* assert is that the run is worth counting: the instrument saw
/// its calibration underline, the arm painted a marker, no second arm ran in this process, and the
/// underline never reached the document model. A row that prints is a row that passed all four.
///
/// `Scripts/ph4b-isolation-sweep.sh` runs the sweep and aggregates. The standing verdict lives in
/// `task-PH4b-report.md`.
@available(iOS 17.0, *)
@MainActor
final class IDHostedIsolatedUnderlineArmTests: HostedUnderlineArmProbeCase {

    // MARK: - The control that is known to differ

    /// Renders a **deliberate** red underline through public `NSAttributedString` attributes and
    /// counts it with the same instrument the arm will be counted with, in the same process.
    ///
    /// This is the guard that makes a zero interpretable. It is not a smoke test that runs once in
    /// some other suite — it runs inside *every* measurement process, immediately before the arm,
    /// and its reading is printed on the same row. Copied from
    /// `IDHostedMarkerPixelExperimentTests.test_0_calibration…`, which is where it was first shown
    /// to catch a blank render.
    private func calibrateInstrument() -> (red: Int, ink: Int, upstream: Int) {
        let view = UITextView(frame: CGRect(x: 0, y: 0, width: 340, height: 90))
        view.font = .systemFont(ofSize: 20)
        view.textColor = .black
        view.backgroundColor = .white
        view.attributedText = NSAttributedString(string: "mispelled word", attributes: [
            .font: UIFont.systemFont(ofSize: 20.0),
            .foregroundColor: UIColor.black,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.red,
        ])
        install(view, at: CGPoint(x: 10, y: 620), size: CGSize(width: 340, height: 90))

        let band = HostedPixelInstrument.markerBand(view, characterRange: NSRange(location: 0, length: 9),
                                                    in: view)
        let counts = band.map { HostedPixelInstrument.pixels(in: view, band: $0) }
            ?? HostedPixelInstrument.PixelCounts()
        let upstream = band.map { HostedPixelInstrument.upstreamRedPixels(in: view, band: $0) } ?? 0

        // Removed here rather than in teardown: the arm must be measured in a hierarchy that does
        // not also contain a red underline, and teardown blocks do not run until the test ends.
        view.removeFromSuperview()

        XCTAssertGreaterThan(counts.ink, 3,
                             "[INSTRUMENT BROKEN — BLANK RENDER] no non-white pixels under a word "
                             + "that is definitely drawn. Every zero this process goes on to report "
                             + "is an instrument failure, not a finding.")
        XCTAssertGreaterThan(counts.red, 3,
                             "[INSTRUMENT BROKEN — RED PREDICATE] ink=\(counts.ink) red=\(counts.red)")
        XCTAssertGreaterThan(upstream, 3,
                             "[UPSTREAM INSTRUMENT BROKEN] the ported IDCountRedPixels/IDRenderView "
                             + "pair read \(upstream) red px where the Swift counter read "
                             + "\(counts.red). The two disagree about a KNOWN underline.")
        return (counts.red, counts.ink, upstream)
    }

    // MARK: - One arm, alone in its process

    private func runIsolatedArm(
        _ name: String,
        build: () throws -> (input: UITextInput, renderView: UIView, responder: UIResponder,
                             model: () -> Bool)
    ) throws {
        XCTAssertEqual(
            Self.armsMeasuredInThisProcess, 0,
            "ANOTHER ARM HAS ALREADY BEEN MEASURED IN THIS PROCESS. That is the exact confound "
            + "PH4b exists to remove — run one `-only-testing:` invocation per arm "
            + "(Scripts/ph4b-isolation-sweep.sh does), never the whole class at once.")

        let calibration = calibrateInstrument()
        warmUpTheSystemChecker()

        let arm = try build()
        // Every arm is installed at the SAME origin. In PH4 the three arms sat at y=80/260/440 for
        // the good reason that they coexisted; here each is alone, so position becomes a needless
        // difference between arms and is removed.
        install(arm.renderView, at: CGPoint(x: 10, y: 80), size: CGSize(width: 340, height: 160))

        let reading = measure(input: arm.input, renderView: arm.renderView,
                              responder: arm.responder, model: arm.model)

        XCTAssertEqual(
            Self.armsMeasuredInThisProcess, 1,
            "\(Self.armsMeasuredInThisProcess) arms were driven in this process; the row below "
            + "would carry an order effect and must not be counted.")

        // Machine-readable, one line, no spaces inside values. The sweep script parses this and
        // nothing else, so the human-readable print below can change freely.
        let row = [
            "arm=\(name)",
            "pid=\(ProcessInfo.processInfo.processIdentifier)",
            "arms=\(Self.armsMeasuredInThisProcess)",
            "calibRed=\(calibration.red)",
            "calibInk=\(calibration.ink)",
            "calibUpstream=\(calibration.upstream)",
            "misspelledRed=\(reading.misspelledRed)",
            "misspelledInk=\(reading.misspelledInk)",
            "misspelledConverged=\(reading.misspelledConverged ? 1 : 0)",
            "correctedRed=\(reading.correctedRed)",
            "correctedInk=\(reading.correctedInk)",
            "correctedConverged=\(reading.correctedConverged ? 1 : 0)",
            "correctedSeconds=\(String(format: "%.2f", reading.correctedSettleSeconds))",
            "forcedRed=\(reading.correctedRedAfterForcedRedraw)",
            "originalBandRed=\(reading.correctedRedAtOriginalBand)",
            "present=\(reading.markerPresent ? 1 : 0)",
            "cleared=\(reading.markerCleared ? 1 : 0)",
            "model=\(reading.underlineInModel ? 1 : 0)",
            "text=\(reading.textAfterCorrection.replacingOccurrences(of: " ", with: "_"))",
            "msamples=\(reading.misspelledSamples.map(String.init).joined(separator: ","))",
            "csamples=\(reading.correctedSamples.map(String.init).joined(separator: ","))",
        ].joined(separator: " ")
        print("PH4B-ROW \(row)")

        // --- validity, not outcome ---
        XCTAssertTrue(
            reading.markerPresent,
            "[VOID RUN — NOT A FINDING] the \(name) arm painted no misspelling marker at all "
            + "(\(reading)), so whatever it reads after the correction says nothing about "
            + "clearing. The calibration control in this same process read "
            + "\(calibration.red) red px, so the instrument was working; the marker itself never "
            + "arrived. Do not count this row.")
        XCTAssertFalse(
            reading.underlineInModel,
            "the \(name) arm wrote the misspelling underline INTO THE DOCUMENT MODEL. Every "
            + "message sent from this editor would carry it. This is upstream's claim 2 and it is "
            + "a correctness invariant, not a parity comparison.")
    }

    // MARK: - The three arms

    /// **Positive control.** Known to clear 6/6 in PH4's in-sequence run. If isolation broke the
    /// harness's ability to see a marker being withdrawn, this is where it shows.
    func test_isolatedArm_stock() throws {
        try runIsolatedArm("stock") {
            let stock = self.makeStockOracleView()
            return (stock, stock, stock, {
                stock.textStorage.length > 1
                    && stock.textStorage.attribute(.underlineStyle, at: 1, effectiveRange: nil) != nil
            })
        }
    }

    /// **Negative control.** Known never to clear in PH4's in-sequence run — 392 px, zero variance
    /// across 6. If isolation somehow made every arm read zero, this is where it shows.
    func test_isolatedArm_inputDec() throws {
        try runIsolatedArm("inputDec") {
            let arm = try self.makeHostArm(.inputDecIfSupported)
            return (arm.canvas, arm.editor, arm.canvas, { self.modelCarriesUnderline(arm.editor) })
        }
    }

    /// **THE QUESTION.** The shipping backend. PH4 read 3/6, bimodally, always measured last.
    func test_isolatedArm_legacy() throws {
        try runIsolatedArm("legacy") {
            let arm = try self.makeHostArm(.legacy)
            return (arm.canvas, arm.editor, arm.canvas, { self.modelCarriesUnderline(arm.editor) })
        }
    }
}

import UIKit
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

/// **The one driver both underline suites use.**
///
/// Every line of this file was moved verbatim out of `IDHostedSpellingUnderlineParityTests`, which
/// now subclasses it. The extraction exists for one reason and it is a measurement reason, not a
/// tidiness one: task PH4b re-measures the same three arms **one arm per process**, and if that
/// re-measurement drove the arms through a second, separately-written driver, then any difference
/// between the two results could be the driver rather than the isolation. Sharing the driver makes
/// process isolation the ONLY variable that changed.
///
/// So: do not "improve" anything here without re-running both suites. A change here silently
/// re-bases PH4's recorded numbers.
@available(iOS 17.0, *)
@MainActor
class HostedUnderlineArmProbeCase: XCTestCase {

    let misspelled = "mispelled"
    let corrected = "misspelled"

    /// Incremented by `measure(...)`, once per arm actually driven. **This is the runtime proof of
    /// the PH4b isolation claim**: the isolated suite asserts it is exactly 1 when its arm finishes,
    /// so "one arm per process" is checked by the process rather than promised by the test runner's
    /// documentation. The warm-up view does not count — it is never `measure`d.
    nonisolated(unsafe) static var armsMeasuredInThisProcess = 0

    struct Reading: CustomStringConvertible {
        var misspelledRed = 0
        var misspelledInk = 0
        var correctedRed = 0
        var correctedInk = 0
        /// The same band, re-sampled after the whole view tree has been forced to lay out and
        /// redraw. **This is the single most useful number here for whoever fixes the defect**: if
        /// the marker disappears once a redraw is forced, the bug is a missing INVALIDATION (the
        /// engine cleared the annotation and never told the surface), which is a small, local fix.
        /// If it survives a forced redraw, the annotation itself is still present and the bug is in
        /// the checking lifecycle, which is a much deeper one.
        var correctedRedAfterForcedRedraw = 0
        var underlineInModel = false
        var textAfterCorrection = ""
        var band = "<none>"

        // --- PH4b additions: the trajectory, not just the endpoint. ---
        //
        // PH4 read one settled number per step, so a legacy run that cleared and a legacy run that
        // did not were indistinguishable apart from the endpoint — there was nothing to
        // characterise the bimodality WITH. These record how the reading got where it got.

        /// Every sample `settled(...)` took while waiting for the misspelled reading.
        var misspelledSamples: [Int] = []
        /// Every sample `settled(...)` took while waiting for the corrected reading.
        var correctedSamples: [Int] = []
        /// False when `settled(...)` ran out its whole budget without two consecutive equal
        /// samples — i.e. the reading was still moving when it was billed. A non-clearing run that
        /// never converged is a different animal from one that converged on a non-zero value.
        var misspelledConverged = false
        var correctedConverged = false
        /// Seconds spent inside the corrected-step settle.
        var correctedSettleSeconds: Double = 0
        /// The ORIGINAL (misspelled-length) band, re-read after the correction. If the marker moved
        /// rather than cleared, this separates "still marked where it was" from "re-marked".
        var correctedRedAtOriginalBand = 0

        /// Upstream's claim 3: correcting the word must drop the marker to less than half.
        var markerCleared: Bool { correctedRed * 2 < misspelledRed }
        var markerPresent: Bool { misspelledRed > 3 }

        var description: String {
            "misspelledRed=\(misspelledRed) correctedRed=\(correctedRed) "
            + "correctedRedAfterForcedRedraw=\(correctedRedAfterForcedRedraw) "
            + "ink=\(misspelledInk)/\(correctedInk) present=\(markerPresent) "
            + "cleared=\(markerCleared) underlineInModel=\(underlineInModel) "
            + "text=\(textAfterCorrection.debugDescription) band=\(band)"
        }
    }

    // MARK: - Hosting

    var appRootView: UIView {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first,
              let root = window.rootViewController?.view else {
            XCTFail("HOSTED TEST IS NOT HOSTED: no application window, so the marker will not be "
                    + "painted and every reading below is a false zero.")
            return UIView()
        }
        return root
    }

    func install(_ view: UIView, at origin: CGPoint, size: CGSize) {
        view.frame = CGRect(origin: origin, size: size)
        appRootView.addSubview(view)
        appRootView.layoutIfNeeded()
        view.layoutIfNeeded()
        addTeardownBlock { MainActor.assumeIsolated { view.removeFromSuperview() } }
    }

    func spin(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    struct SettleResult {
        var value: Int
        var samples: [Int]
        /// True when two consecutive equal samples were seen before the budget ran out.
        var converged: Bool
        var seconds: Double
    }

    /// Samples `probe` until the reading is **settled** — two consecutive equal samples, at least
    /// `interval` apart — or `seconds` elapse. Returns the settled value.
    ///
    /// **This replaced a first-satisfaction poll, and the replacement is the difference between a
    /// trustworthy tier and a coin flip.** With "return as soon as the condition holds", the arms
    /// were read at whatever moment each happened to satisfy it, and the LEGACY CONTROL cleared its
    /// marker in only 2 of 3 runs — so the test's own PORT-DEFECT / PRE-EXISTING billing flipped
    /// between runs while the InputDec arm's reading never moved (392, 392, 392). A comparison whose
    /// control is unstable cannot bill anything to anybody. Upstream's own probe settles the same
    /// way (`stableSamples >= 2` in `IDObserveStockSpellingReadiness`).
    ///
    /// PH4b added the returned trajectory. The settle RULE is byte-for-byte the one PH4 ran.
    func settled(upTo seconds: TimeInterval, interval: TimeInterval = 0.4,
                 probe: () -> Int) -> SettleResult {
        let began = Date()
        let deadline = began.addingTimeInterval(seconds)
        var previous: Int? = nil
        var current = probe()
        var samples: [Int] = [current]
        while Date() < deadline {
            spin(interval)
            let next = probe()
            samples.append(next)
            if next == current, previous == current {
                return SettleResult(value: current, samples: samples, converged: true,
                                    seconds: Date().timeIntervalSince(began))
            }
            previous = current
            current = next
        }
        return SettleResult(value: current, samples: samples, converged: false,
                            seconds: Date().timeIntervalSince(began))
    }

    /// The system checker loads asynchronously and does not answer for the FIRST view driven in a
    /// fresh process. Upstream encodes the same fact rather than fixing it. Without this, the first
    /// arm measured reads zero for an instrument reason and the whole comparison is inverted.
    func warmUpTheSystemChecker() {
        let warmUp = UITextView(frame: .zero)
        warmUp.spellCheckingType = .yes
        install(warmUp, at: CGPoint(x: 10, y: 500), size: CGSize(width: 300, height: 80))
        XCTAssertTrue(warmUp.becomeFirstResponder())
        warmUp.insertText("mispelled wrng ")
        spin(2.5)
        warmUp.resignFirstResponder()
        warmUp.removeFromSuperview()
    }

    // MARK: - One arm, measured

    /// Drives `input` through misspelling → correction, sampling `renderView` at each step.
    func measure(input: UITextInput, renderView: UIView,
                 responder: UIResponder, model: (() -> Bool)? = nil) -> Reading {
        Self.armsMeasuredInThisProcess += 1
        var reading = Reading()
        let wordRange = NSRange(location: 0, length: (misspelled as NSString).length)

        XCTAssertTrue(responder.becomeFirstResponder(), "the arm refused first responder")
        spin(0.3)
        input.selectedTextRange = input.textRange(from: input.endOfDocument, to: input.endOfDocument)
        input.insertText("\(misspelled) ")
        // The checker is selection-driven: a word is checked when the caret LEAVES it. The trailing
        // space already moves past it; the spin gives the async checker time to answer.
        spin(0.5)

        let misspelledSettle = settled(upTo: 10.0) {
            guard let band = HostedPixelInstrument.markerBand(input, characterRange: wordRange,
                                                              in: renderView) else { return 0 }
            let counts = HostedPixelInstrument.pixels(in: renderView, band: band)
            reading.misspelledInk = counts.ink
            reading.band = "\(band)"
            return counts.red
        }
        reading.misspelledRed = misspelledSettle.value
        reading.misspelledSamples = misspelledSettle.samples
        reading.misspelledConverged = misspelledSettle.converged
        reading.underlineInModel = model?() ?? false

        // The original band, captured BEFORE the replacement moves the layout, so the
        // `correctedRedAtOriginalBand` re-read below asks about the same strip of the view.
        let originalBand = HostedPixelInstrument.markerBand(input, characterRange: wordRange,
                                                           in: renderView)

        if let start = input.position(from: input.beginningOfDocument, offset: 0),
           let end = input.position(from: start, offset: wordRange.length),
           let range = input.textRange(from: start, to: end) {
            input.replace(range, withText: corrected)
        }
        spin(0.5)
        let correctedRange = NSRange(location: 0, length: (corrected as NSString).length)
        let correctedSettle = settled(upTo: 10.0) {
            guard let band = HostedPixelInstrument.markerBand(input, characterRange: correctedRange,
                                                              in: renderView) else { return 0 }
            let counts = HostedPixelInstrument.pixels(in: renderView, band: band)
            reading.correctedInk = counts.ink
            return counts.red
        }
        reading.correctedRed = correctedSettle.value
        reading.correctedSamples = correctedSettle.samples
        reading.correctedConverged = correctedSettle.converged
        reading.correctedSettleSeconds = correctedSettle.seconds
        if let originalBand {
            reading.correctedRedAtOriginalBand =
                HostedPixelInstrument.pixels(in: renderView, band: originalBand).red
        }
        // Force a full layout + redraw of the whole arm, then re-sample the identical band.
        forceRedraw(renderView)
        spin(0.6)
        if let band = HostedPixelInstrument.markerBand(input, characterRange: correctedRange,
                                                       in: renderView) {
            reading.correctedRedAfterForcedRedraw =
                HostedPixelInstrument.pixels(in: renderView, band: band).red
        }

        reading.textAfterCorrection = input.text(in: input.textRange(from: input.beginningOfDocument,
                                                                    to: input.endOfDocument)!) ?? ""
        responder.resignFirstResponder()
        return reading
    }

    func forceRedraw(_ view: UIView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        view.setNeedsDisplay()
        for subview in view.subviews { forceRedraw(subview) }
    }

    /// The stock `UITextView` oracle arm, configured exactly as PH4 configured it.
    func makeStockOracleView() -> UITextView {
        let stock = UITextView(frame: .zero)
        stock.font = .systemFont(ofSize: 20)
        stock.textColor = .black
        stock.backgroundColor = .white
        stock.spellCheckingType = .yes
        stock.autocorrectionType = .no      // corrections would rewrite the fixture out from under us
        return stock
    }

    func makeHostArm(_ backend: RichTextEditorInputBackendPreference)
        throws -> (editor: RichTextEditorView, canvas: DocumentCanvasView) {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 340, height: 160),
                                        inputBackend: backend)
        editor.backgroundColor = .white
        editor.isSpellCheckingEnabled = true
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: []))])
        switch backend {
        case .legacy:
            XCTAssertFalse(editor.canvasForTesting is IDDocumentCanvasView,
                           "the Legacy CONTROL arm was handed an InputDec canvas — it would then "
                           + "agree with the InputDec arm for the wrong reason")
        default:
            _ = try XCTUnwrap(editor.canvasForTesting as? IDDocumentCanvasView,
                              "the InputDec arm fell back to legacy; this would certify the WRONG "
                              + "backend while reporting green")
        }
        return (editor, editor.canvasForTesting)
    }

    func modelCarriesUnderline(_ editor: RichTextEditorView) -> Bool {
        editor.document.blocks.contains { block in
            guard case let .paragraph(paragraph) = block else { return false }
            return paragraph.runs.contains { $0.attributes.underline }
        }
    }
}

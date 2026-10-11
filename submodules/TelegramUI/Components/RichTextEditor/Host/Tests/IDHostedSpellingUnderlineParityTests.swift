import UIKit
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

/// **The user's fifth and still-open defect, measured — for the first time in this programme.**
///
/// "Corrected words are not underlined" has had no automated oracle at all: task P1 measured stock
/// `UITextView` painting zero misspelling-marker pixels in a SwiftPM xctest process, so the ported
/// `IDBlockSpellingIntegrationParityTests` declines with `[ORACLE UNAVAILABLE — NOT CERTIFIED]`
/// rather than passing, and the user has been the only instrument. Task PH4's experiment
/// (`IDHostedMarkerPixelExperimentTests`) showed that a HOSTED process paints the marker normally.
/// This is the first thing built on that.
///
/// It is upstream's `testMisspellingUsesNativeTemporaryPixelsAndCorrectionDropsBelowHalf`, run three
/// ways, in the environment where the oracle is alive:
///
/// * **stock** `UITextView` — the oracle. What UIKit itself does.
/// * **InputDec** — the ported engine through the phase-2/3 adapter. The thing under test.
/// * **legacy** — the shipping backend. **The control.** A divergence Legacy also shows is
///   PRE-EXISTING, not something the port introduced; charging it to the port would overstate the
///   port's cost, and the earlier differential corpus found 194 of 514 differences were exactly
///   that.
///
/// The oracle guard is evaluated before any comparison, because three arms all reading zero would
/// compare EQUAL and report a meaningless pass.
///
/// # ⚠️ THIS SUITE IS EXPECTED TO FAIL. DO NOT "FIX" THE TEST.
///
/// It is the reproduction of an OPEN DEFECT, not a broken test. It went red the first time it was
/// ever run, which is the whole reason it exists: the defect had no automated oracle before task
/// PH4, and the user was the only instrument. Making it green without changing the engine would
/// return the programme to exactly the state five rounds of hands-on testing already proved
/// dangerous. It goes green when the marker is withdrawn on correction.
///
/// ## What was measured — 6 runs, iPhone 17 Pro K1, iOS 26.5, 2026-08-27
///
/// | arm | marker appears | marker clears on correction | corrected red px |
/// | --- | --- | --- | --- |
/// | stock `UITextView` | yes, 6/6 | **yes, 6/6** | 0 every run |
/// | Telegram + **InputDec** | yes, 6/6 | **never, 0/6** | **392 every run, zero variance** |
/// | Telegram + legacy (control) | yes, 6/6 | **sometimes, 3/6** | 0 or 375, never in between |
///
/// Three things follow, and the second is the one that was not expected:
///
/// 1. **The InputDec arm never withdraws the marker.** Deterministic; the reading does not move.
/// 2. **The SHIPPING legacy backend does not either, about half the time** — and bimodally (0 or
///    375, never an intermediate value), so this is a bistable behaviour rather than sampling
///    noise. Adopting upstream's own two-equal-samples settle discipline did not change it. **So
///    the user's "corrected words are not underlined" complaint is not purely a port defect**; part
///    of it is present in what ships today. That reframing is worth more than the port billing.
/// 3. **A forced full layout + redraw does not clear it** on either arm
///    (`correctedRedAfterForcedRedraw` equals `correctedRed` exactly). So this is NOT a missing
///    invalidation — the temporary annotation is still there. The bug is in the checking lifecycle,
///    where the marker should be withdrawn when the word stops being misspelled.
///
/// ## What this suite does NOT establish
///
/// The three arms are measured **in sequence in one process**, and only one view can hold the
/// responder role at a time, so the legacy arm is always measured last, after two others have been
/// focused and resigned. Order effects on the shared system checker are plausible and are NOT ruled
/// out here. Anyone billing the legacy result must first re-measure it in isolation, one arm per
/// process — which is precisely what upstream's per-row `simctl erase` matrix (§7.6/§7.7) exists to
/// do. The InputDec result does not depend on this: it is measured second, and it is invariant.
///
/// **PH4b HAS NOW DONE THAT RE-MEASUREMENT.** `IDHostedIsolatedUnderlineArmTests` drives ONE arm
/// per process through this file's own driver; `task-PH4b-report.md` carries the numbers. Read the
/// legacy figure in the table above as this suite's IN-SEQUENCE reading, never as the isolated
/// truth, and take the isolated suite's numbers when the two disagree.
@available(iOS 17.0, *)
@MainActor
final class IDHostedSpellingUnderlineParityTests: HostedUnderlineArmProbeCase {

    // Everything this suite used to carry itself — `Reading`, `spin`, `settled`,
    // `warmUpTheSystemChecker`, `measure`, `forceRedraw`, `makeHostArm`, `modelCarriesUnderline`
    // and the stock-oracle constructor — now lives in `HostedUnderlineArmProbeCase`, moved verbatim.
    //
    // It was moved so that PH4b's ONE-ARM-PER-PROCESS re-measurement
    // (`IDHostedIsolatedUnderlineArmTests`) drives the arms through the identical code. If that
    // suite had its own driver, a difference between its numbers and the ones recorded above could
    // be the driver rather than the isolation, and the whole re-measurement would settle nothing.

    // MARK: - The measurement

    func test_aMisspellingIsMarkedAndCorrectingItRemovesTheMark_threeArms() throws {
        XCTAssertTrue(IDTextEditorBackend.isSupported(),
                      "the InputDec backend is unsupported on this runtime")
        warmUpTheSystemChecker()

        // --- stock: the oracle ---
        let stock = makeStockOracleView()   // the same constructor the isolated suite uses
        install(stock, at: CGPoint(x: 10, y: 80), size: CGSize(width: 340, height: 160))
        let stockReading = measure(input: stock, renderView: stock, responder: stock) {
            stock.textStorage.length > 1
                && stock.textStorage.attribute(.underlineStyle, at: 1, effectiveRange: nil) != nil
        }

        // --- THE ORACLE GUARD, before any comparison ---
        //
        // A skip, not a failure: a skip records "NOT CERTIFIED", which is the truthful state when
        // the oracle is silent. In the SwiftPM process this branch is always taken; here it must
        // not be, and if it ever is, the pixel experiment's own assertions will say why.
        try XCTSkipUnless(
            stockReading.markerPresent,
            "[ORACLE UNAVAILABLE — NOT CERTIFIED] stock UITextView painted no misspelling marker "
            + "even in the HOSTED process (\(stockReading)). Read "
            + "IDHostedMarkerPixelExperimentTests' failures first — it measures this signal "
            + "directly and names the step that stopped.")

        // --- InputDec: the thing under test ---
        let inputDecArm = try makeHostArm(.inputDecIfSupported)
        install(inputDecArm.editor, at: CGPoint(x: 10, y: 260), size: CGSize(width: 340, height: 160))
        let inputDecReading = measure(input: inputDecArm.canvas, renderView: inputDecArm.editor,
                                      responder: inputDecArm.canvas) {
            self.modelCarriesUnderline(inputDecArm.editor)
        }

        // --- legacy: the control ---
        let legacyArm = try makeHostArm(.legacy)
        install(legacyArm.editor, at: CGPoint(x: 10, y: 440), size: CGSize(width: 340, height: 160))
        let legacyReading = measure(input: legacyArm.canvas, renderView: legacyArm.editor,
                                    responder: legacyArm.canvas) {
            self.modelCarriesUnderline(legacyArm.editor)
        }

        print("PH4-EVIDENCE ============ UNDERLINE PARITY, THREE ARMS ============")
        print("PH4-EVIDENCE   stock:    \(stockReading)")
        print("PH4-EVIDENCE   inputDec: \(inputDecReading)")
        print("PH4-EVIDENCE   legacy:   \(legacyReading)")
        print("PH4-EVIDENCE ==============================================================")

        // Upstream's claim 2, kept on every arm: the marker must be a TEMPORARY RENDERING
        // ATTRIBUTE, never model state. A backend that "fixed" underlining by writing `.underline`
        // into the document would pass the pixel half of this test and corrupt every message the
        // user sent. This one is asserted unconditionally — it is a correctness invariant, not a
        // parity comparison.
        XCTAssertFalse(inputDecReading.underlineInModel,
                       "the InputDec arm wrote the misspelling underline INTO THE DOCUMENT MODEL. "
                       + "Every message sent from this editor would carry it.")
        XCTAssertFalse(legacyReading.underlineInModel,
                       "the Legacy arm wrote the misspelling underline INTO THE DOCUMENT MODEL.")

        // Claim 1: a misspelled word gets marked. All three arms do this, every run.
        XCTAssertTrue(inputDecReading.markerPresent,
                      "the InputDec arm painted NO misspelling marker at all — a different and worse "
                      + "defect than the one this suite tracks. \(inputDecReading)")
        XCTAssertTrue(legacyReading.markerPresent,
                      "the Legacy control painted no marker, so it cannot serve as a control. "
                      + "\(legacyReading)")

        // Claim 3: correcting the word removes the mark.
        //
        // ASSERTED ONLY FOR THE INPUTDEC ARM, deliberately. The legacy control is BIMODAL here —
        // 3 of 6 runs cleared, 3 did not, with no intermediate value — so a comparison that bills
        // this claim PORT-DEFECT or PRE-EXISTING from the control's reading flips its own diagnosis
        // between runs. A flapping label is worse than no label: readers learn to ignore it. The
        // InputDec reading, by contrast, has zero variance across 6 runs, so this failure is stable
        // and actionable. The legacy number is reported below as context, never asserted on.
        XCTAssertTrue(
            inputDecReading.markerCleared,
            "[OPEN DEFECT — this failure is expected; do not 'fix' the test]\n"
            + "Correcting a misspelled word does NOT remove its underline on the InputDec arm.\n"
            + "  stock (oracle): \(stockReading)\n"
            + "  inputDec:       \(inputDecReading)\n"
            + "  legacy (ctrl):  \(legacyReading)\n"
            + "A forced layout+redraw does not clear it either "
            + "(\(inputDecReading.correctedRedAfterForcedRedraw) px), so the temporary annotation "
            + "is still present: the bug is in the checking lifecycle, not in invalidation.\n"
            + "NOTE: the legacy CONTROL clears this only ~half the time, so part of this defect may "
            + "be PRE-EXISTING in the shipping backend. Re-measure one arm per process before "
            + "billing it.")
    }
}

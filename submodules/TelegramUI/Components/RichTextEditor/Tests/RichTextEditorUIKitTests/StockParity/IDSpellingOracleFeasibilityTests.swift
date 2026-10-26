#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorStockParitySupport

/// **Task P2 step 3 — does `IDSpellingReadinessProbe` give us a real spelling oracle in an xctest
/// process?**
///
/// Task P1 concluded it did not: "stock `UITextView` paints zero misspelling-marker pixels in a
/// SwiftPM xctest process". Upstream appears to disagree — its
/// `IDSpellingReadinessProbeTests.testStockTextViewSpellingEnvironmentIsReady` asserts
/// `observation.status == IDSpellingReadinessStatusReady`, which by the classifier
/// (`IDClassifySpellingReadinessForPrimaryLanguages`) requires en-US on BOTH the controller and the
/// input, continuous checking on, a temporary annotation observed, AND a non-zero marker pixel
/// count.
///
/// This suite settles it by measurement rather than by reasoning from either claim. It runs
/// upstream's own probe, unmodified, in THIS process, and reports every intermediate the classifier
/// consults — so a negative result names the step that failed rather than the whole environment.
///
/// It deliberately measures **two** stock configurations, because P1 and upstream did not use the
/// same one and the difference is exactly the sort of thing that decides this question:
///
/// * `plainUITextView` — what upstream's probe tests use.
/// * `suppressedInputView` — P1's `IDStockParity.OracleTextView`, which returns a 1×0 dummy
///   `inputView` so `becomeFirstResponder` does not raise a keyboard. If the system text checker is
///   driven by the keyboard pipeline, that subclass would silently disable the very thing being
///   measured, and P1's negative would be an artefact of its own fixture.
@available(iOS 17.0, *)
@MainActor
final class IDSpellingOracleFeasibilityTests: XCTestCase {

    private var window: UIWindow?

    private func install(_ editor: UITextView) {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 400, height: 400)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        }
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.addSubview(editor)
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        editor.layoutIfNeeded()
        self.window = window
        addTeardownBlock {
            MainActor.assumeIsolated {
                editor.removeFromSuperview()
                window.isHidden = true
                window.rootViewController = nil
            }
        }
    }

    /// P1's oracle subclass, reproduced here so this suite has no dependency on the parity harness.
    private final class SuppressedKeyboardTextView: UITextView {
        private var suppressed: UIView?
        override var inputView: UIView? {
            get {
                if suppressed == nil { suppressed = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0)) }
                return suppressed
            }
            set { suppressed = newValue }
        }
    }

    private func describe(_ dictionary: [String: Any]) -> String {
        let data = try? JSONSerialization.data(withJSONObject: dictionary,
                                               options: [.sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "<unserialisable>"
    }

    // MARK: - The environment facts, measured one at a time

    /// Step 0. Without an installed en_US checker nothing downstream can work, and every later
    /// result would be attributable to the wrong cause. Upstream's own guard, run first.
    func test_0_theRuntimeHasAnEnglishCheckerThatFlagsTheRegressionWord() {
        XCTAssertTrue(IDAssertEnglishCheckerAvailable(self),
                      "no installed en checker: every spelling measurement below is uninterpretable")
    }

    /// Step 1 — **the environment characterisation**, and the reason upstream's single `status`
    /// enum must not be read as a verdict here.
    ///
    /// Measured 2026-08-26 in this SwiftPM xctest process, iPhone 17 Pro K1:
    ///
    /// | fact | value |
    /// | --- | --- |
    /// | `UITextInputMode.currentInputMode.primaryLanguage` | `"en-US"` |
    /// | `editor.textInputMode` on a first-responder stock `UITextView` | **nil** |
    ///
    /// The classifier's FIRST gate is that *both* be `"en-US"`, so it returns `inputModeMismatch`
    /// and never evaluates the annotation or pixel questions. Reading only the status would
    /// therefore report "the spelling environment is not ready" while the checker is in fact
    /// running — which is why steps 2 and 3 decompose it.
    ///
    /// Both facts are asserted so that an OS or host change is caught rather than silently
    /// changing what the other tests mean.
    func test_1_theProcessHasAnEnUSControllerModeButNoPerViewInputMode() {
        let editor = UITextView(frame: CGRect(x: 10, y: 10, width: 300, height: 120))
        install(editor)
        XCTAssertTrue(editor.becomeFirstResponder(), "the stock editor could not become first responder")
        XCTAssertEqual(IDCurrentInputModePrimaryLanguage(), "en-US",
                       "the controller-level input mode changed; step 2/3's readings may no longer "
                       + "mean what the report says. hasCurrentInputMode=\(IDHasCurrentInputMode()) "
                       + "privateClasses=\(IDPrivateTextInputClassAvailability())")
        XCTAssertNil(editor.textInputMode,
                     "a per-view textInputMode has become available in this process — "
                     + "IDObserveStockSpellingReadiness may now reach `ready`, and the spelling "
                     + "suite's skip should be revisited")
    }

    /// Step 2 — **THE ORACLE**, and its calibration.
    ///
    /// `IDSpellingReadinessProbe`'s non-pixel signal is
    /// `IDRenderingAttributesDifferFromPersistentAttributes`: it walks the stock editor's TextKit 2
    /// *rendering* attributes and reports the ranges whose attributes differ from the persistent
    /// ones at the same offset. That is precisely "the system applied a temporary annotation here",
    /// which is what a misspelling marker IS.
    ///
    /// **A signal that is always true is not an oracle.** So this test runs the identical procedure
    /// twice — once over text containing a misspelling, once over text that is entirely correctly
    /// spelled — and requires the two to differ. Without this half, "annotation observed" could be
    /// reporting some unrelated rendering attribute and every spelling assertion built on it would
    /// be vacuous. This programme has shipped that mistake before.
    func test_2_theTemporaryAnnotationOracleIsRealAndDiscriminates() {
        // EXPLICIT WARM-UP. The FIRST text view driven in a fresh process receives no annotation at
        // all — the system text checker loads asynchronously and the first word is typed before it
        // is ready. `IDBlockSpellingIntegrationParityTests` documents this at length and warms up
        // for it; this test relied on `test_0`/`test_1` having run first, which made the headline
        // evidence for the whole oracle claim ORDER-DEPENDENT: run alone with `-only-testing:` this
        // method, the misspelled arm reads empty.
        //
        // The failure direction was always the safe one (a cold process makes this FAIL, never
        // falsely pass, and the misspelled sample is taken before the correctly-spelled one so a
        // non-empty misspelled reading itself proves the machinery is warm). It is still wrong for
        // the load-bearing test to depend on its siblings.
        let warmUp = UITextView(frame: CGRect(x: 10, y: 290, width: 300, height: 100))
        install(warmUp)
        _ = IDObserveStockAnnotationRangesForText(warmUp, "mispelled ", 2.0)

        let misspelled = UITextView(frame: CGRect(x: 10, y: 10, width: 300, height: 120))
        install(misspelled)
        let misspelledRanges = IDObserveStockAnnotationRangesForText(misspelled, "mispelled wrng ", 2.0)

        let correct = UITextView(frame: CGRect(x: 10, y: 150, width: 300, height: 120))
        install(correct)
        let correctRanges = IDObserveStockAnnotationRangesForText(correct, "correctly spelled ", 2.0)

        XCTAssertFalse(misspelledRanges.isEmpty,
                       "the temporary-annotation oracle produced NOTHING for \"mispelled wrng \" — "
                       + "there is no spelling oracle in this process at all")
        XCTAssertTrue(correctRanges.isEmpty,
                      "the temporary-annotation oracle fired for correctly-spelled text "
                      + "(\(correctRanges)) — it is NOT discriminating, and any assertion built on "
                      + "it is vacuous. misspelled=\(misspelledRanges)")
    }

    /// Step 3 — the pixel half, which is where Task P1's negative conclusion is CORRECT.
    ///
    /// The probe's `markerPixelCount` is zero in this process even though the same observation
    /// reports `temporaryAnnotationObserved == true`. The annotation lands; the marker is not
    /// painted into a layer this process can render. So P1's finding survives, narrowed: the
    /// *pixel* oracle is unavailable, the *annotation* oracle is not.
    ///
    /// Asserted rather than merely recorded, deliberately: if a future OS paints the marker,
    /// this test fails and points at the spelling suite's skip, which should then be removed.
    func test_3_theMarkerPixelOracleIsUnavailableWhileTheAnnotationOracleIsNot() {
        let editor = UITextView(frame: CGRect(x: 10, y: 10, width: 300, height: 120))
        XCTAssertNotNil(editor.textLayoutManager, "the probe requires TextKit 2")
        install(editor)
        let observation = IDObserveStockSpellingReadiness(editor, 5.0)
        XCTAssertTrue(observation.temporaryAnnotationObserved,
                      "the annotation oracle went away: \(describe(observation.dictionaryRepresentation))")
        XCTAssertEqual(observation.markerPixelCount, 0,
                       "MISSPELLING MARKER PIXELS ARE NOW VISIBLE in an xctest process "
                       + "(\(observation.markerPixelCount)). Task P1's skip in "
                       + "IDBlockSpellingIntegrationParityTests should be removed and the pixel "
                       + "assertions restored. evidence=\(describe(observation.dictionaryRepresentation))")
    }

    /// Step 4. The lifecycle trace: which step of the private checking pipeline is the first one
    /// that does not happen. `firstMissingTransition` is upstream's own vocabulary
    /// (`hooksUnavailable` → `selectionDepartureUnavailable` → `selectionCheckUnavailable` →
    /// `wordCheckUnavailable` → `checkerUnavailable` → `keyboardLanguagesUnavailable` →
    /// `annotationUnavailable` → `complete`).
    ///
    /// It reaches `complete` here. That is the strongest single statement this suite makes: the
    /// private `UITextCheckingController` pipeline runs END TO END in a SwiftPM xctest process —
    /// selection departure, selection check, per-word check, a live `textChecker`, non-empty
    /// keyboard languages, and a landed annotation.
    func test_4_theStockCheckingPipelineReachesTheEnd() {
        let editor = UITextView(frame: CGRect(x: 10, y: 10, width: 300, height: 120))
        install(editor)
        let trace = IDObserveStockSpellingLifecycle(editor, .staged, 3.0)
        let dictionary = trace.dictionaryRepresentation
        XCTAssertEqual(dictionary["firstMissingTransition"] as? String, "complete",
                       "stock checking lifecycle stopped early: \(describe(dictionary))")
        XCTAssertEqual(dictionary["hooksRestored"] as? Bool, true,
                       "the lifecycle swizzles were not restored — every later test in this process "
                       + "is running against patched UIKit classes")
    }

    /// Step 5 — the control for P1's fixture choice.
    ///
    /// P1 measured spelling through `IDStockParity.OracleTextView`, which returns a 1×0 dummy
    /// `inputView` so `becomeFirstResponder` raises no keyboard. If the checker were driven by the
    /// keyboard pipeline, that subclass would have silently disabled the thing being measured and
    /// P1's negative would be an artefact of its own fixture rather than a fact about the process.
    ///
    /// It is not: the suppressed-inputView arm produces the SAME readings as a plain `UITextView`.
    /// Recorded because ruling this out is what makes the rest of the suite's conclusions safe.
    func test_5_suppressingTheInputViewDoesNotChangeAnyReading() {
        let plain = UITextView(frame: CGRect(x: 10, y: 10, width: 300, height: 120))
        install(plain)
        let plainObservation = IDObserveStockSpellingReadiness(plain, 5.0)

        let suppressed = SuppressedKeyboardTextView(frame: CGRect(x: 10, y: 150, width: 300, height: 120))
        install(suppressed)
        let suppressedObservation = IDObserveStockSpellingReadiness(suppressed, 5.0)

        XCTAssertEqual(suppressedObservation.temporaryAnnotationObserved,
                       plainObservation.temporaryAnnotationObserved,
                       "the suppressed inputView changed the ANNOTATION reading — P1's fixture, not "
                       + "the environment, would then be the cause. plain="
                       + "\(describe(plainObservation.dictionaryRepresentation)) suppressed="
                       + "\(describe(suppressedObservation.dictionaryRepresentation))")
        XCTAssertEqual(suppressedObservation.markerPixelCount, plainObservation.markerPixelCount,
                       "the suppressed inputView changed the PIXEL reading")
        XCTAssertEqual(IDSpellingReadinessStatusString(suppressedObservation.status),
                       IDSpellingReadinessStatusString(plainObservation.status),
                       "the suppressed inputView changed the probe's status")
    }
}
#endif

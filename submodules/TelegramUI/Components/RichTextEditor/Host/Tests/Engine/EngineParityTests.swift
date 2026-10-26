import XCTest
import UIKit
import RichTextInputDecHost
@testable import RichTextEngineEditor

/// Each test builds exactly ONE arm (Global Constraint 3) and records its observable
/// behaviour; the two arms are compared by asserting the SAME expectations hold for both,
/// which keeps one process to one arm while still being a comparison.
final class EngineParityTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    }
    /// `tearDownArm()` FIRST: it resigns the arm's first-responder role and takes it out of the
    /// window while both still exist. Releasing the window alone does not do either — a focused
    /// engine would simply survive into the next test, breaking Global Constraint 3's one-arm-per-
    /// process rule from the other end.
    override func tearDown() {
        EngineParityHarness.tearDownArm()
        window.isHidden = true; window = nil
        super.tearDown()
    }

    /// Positions the caret at the END of the seeded text before typing — see
    /// `EngineParityHarness.makeArm`'s doc comment: neither arm defaults there on its own, and the
    /// two arms don't even agree on where their OWN default sits (`.hosted` ends at the end because
    /// `RichTextEngineEditorView.document`'s setter explicitly moves it there; `.raw` starts at 0).
    /// Typing at the end is what BOTH the raw-engine smoke test
    /// (`InputDecUpstreamHostSmokeTests.test_theHostBecomesFirstResponderAndAcceptsTypedText`) and
    /// every real host do, so this is normalizing to the realistic case, not hiding a difference —
    /// the difference in each arm's untouched default caret is a fact about their construction paths
    /// (bare engine vs. `document`-seeded editor), not about the adapter under test.
    ///
    /// Resets the trace with `EngineParityHarness.resetTrace()` right before typing (NOT at
    /// `makeArm` time — `makeArm` itself already starts a fresh recording, but focusing/positioning
    /// the caret above can itself emit a `selectionDidChange`, and that would land in the same
    /// trace as the keystroke unless cleared first) so `trace` below reflects exactly the one
    /// `insertText` call, nothing from setup.
    private func typeAndDescribe(_ arm: EngineParityArm) -> (text: String, caret: CGRect, trace: [String]) {
        let view = EngineParityHarness.makeArm(arm, in: window)
        XCTAssertTrue(view.becomeFirstResponder(), "\(arm) failed to become first responder")
        view.selectedTextRange = view.textRange(from: view.endOfDocument, to: view.endOfDocument)
        EngineParityHarness.resetTrace()
        view.insertText("!")
        let whole = view.textRange(from: view.beginningOfDocument, to: view.endOfDocument)!
        let caret = view.caretRect(for: view.endOfDocument)
        return (view.text(in: whole) ?? "", caret, EngineParityHarness.trace())
    }

    func test_rawArmTypes() {
        let raw = typeAndDescribe(.raw)
        XCTAssertEqual(raw.text, EngineParityHarness.seed + "!")
        XCTAssertFalse(raw.caret.isNull)
        XCTAssertTrue(raw.trace.contains("textDidChange"), "raw arm produced no textDidChange")
    }

    func test_hostedArmTypesIdentically() {
        let hosted = typeAndDescribe(.hosted)
        XCTAssertEqual(hosted.text, EngineParityHarness.seed + "!")
        XCTAssertFalse(hosted.caret.isNull)
        XCTAssertTrue(hosted.trace.contains("textDidChange"), "hosted arm produced no textDidChange")
    }

    /// THE POSITIVE CONTROL (Global Constraint 6, task brief step 3). Without it, "no differences
    /// found" and "the instrument is dead" produce identical output — a vacuous pass this
    /// programme has produced at least five separate ways. This plants a difference and REQUIRES it
    /// to be visible. If this test ever passes trivially, the harness is not measuring anything.
    ///
    /// FIX ROUND 1/2 HISTORY, recorded because it is load-bearing: an earlier version of this test
    /// dropped the trace-based half of this assertion, believing (wrongly, on the strength of a
    /// broken diagnostic — see `EngineParityHarness.trace()`'s doc comment) that the engine's
    /// autocorrection trace never fires for either arm. It does fire, once the harness's own
    /// Install/Reset ordering bug was fixed. Both signals are asserted here now: the exact-text
    /// equality (proven independently useful — it catches a broken adapter that the trace alone
    /// would not, e.g. a correct `textDidChange` notification paired with a corrupted read) AND the
    /// trace containing `"textDidChange"` (proven independently useful — it catches an adapter that
    /// silently drops the private input delegate notification while somehow still landing the
    /// right characters, e.g. via a completely different, un-vetted code path).
    func test_theHarnessCanSeeADifference() {
        let view = EngineParityHarness.makeArm(.hosted, in: window)
        XCTAssertTrue(view.becomeFirstResponder())
        view.selectedTextRange = view.textRange(from: view.endOfDocument, to: view.endOfDocument)
        EngineParityHarness.resetTrace()
        view.insertText("X")
        let whole = view.textRange(from: view.beginningOfDocument, to: view.endOfDocument)!
        let actual = view.text(in: whole)
        let planted = EngineParityHarness.seed + "DIFFERENT"
        XCTAssertNotEqual(actual, planted,
                          "the instrument reported a match against text that was never typed")
        XCTAssertEqual(actual, EngineParityHarness.seed + "X",
                       "the instrument did not observe the actual edit it drove — read back "
                       + "\(actual.debugDescription), the harness cannot be trusted to see a "
                       + "real difference either")
        XCTAssertFalse(EngineParityHarness.trace().isEmpty,
                       "the trace is EMPTY — the instrument is dead, not the arms identical")
        XCTAssertTrue(EngineParityHarness.trace().contains("textDidChange"),
                      "the trace recorded events but none of them was textDidChange: "
                      + "\(EngineParityHarness.trace())")
    }

    /// THE TEARDOWN CHECK, and the counterpart to the retention check below. One arm per process
    /// (Global Constraint 3) is a property of the whole process, not of `makeArm` alone: an arm that
    /// keeps the first-responder role and stays in a window is still live while the NEXT test builds
    /// its own, which is exactly the two-arms-at-once condition that makes the process-global trace
    /// readings junk. `tearDownArm()` is what gives an arm back, and this is the only thing that
    /// checks it does anything at all — a `tearDownArm()` body emptied to `{}` compiles, every other
    /// test in this file still passes, and the constraint is silently void.
    func test_tearDownArmActuallyGivesTheArmBack() {
        let view = EngineParityHarness.makeArm(.hosted, in: window)
        XCTAssertTrue(view.becomeFirstResponder())
        // Anti-vacuity: both facts must be TRUE before the teardown, or asserting them false
        // afterwards proves nothing.
        XCTAssertTrue(view.isFirstResponder)
        XCTAssertNotNil(view.superview)

        EngineParityHarness.tearDownArm()

        XCTAssertFalse(view.isFirstResponder,
                       "the arm still holds the first-responder role after teardown — it stays live "
                       + "into the next test, which is two arms at once")
        XCTAssertNil(view.superview, "the arm is still in the window after teardown")
    }

    /// THE RETENTION CHECK. `EngineParityHarness.makeArm(.hosted)` returns `editor.engine`, not
    /// `editor` — the `RichTextEngineEditorView` that owns the observation wiring (its
    /// `EngineObserver` is assigned to `engine.observationSink`, a WEAK property). If the harness
    /// let `editor` go out of scope without retaining it, `editor` — and the `EngineObserver` it
    /// owns — would deallocate the instant `makeArm` returns, and `observationSink` would silently
    /// read nil from then on: the `.hosted` arm would degrade into a second `.raw` arm with no
    /// adapter attached, and every parity test above would report "no differences" FOREVER no
    /// matter what the adapter does. This is the one check standing between this instrument and
    /// that specific silent-failure mode — see `EngineParityHarness.retainedHostedEditor`.
    func test_hostedArmRetainsItsOwningEditor() {
        let view = EngineParityHarness.makeArm(.hosted, in: window)
        guard let engine = view as? TGIDObservingBlockTextView else {
            XCTFail("`.hosted` arm did not return the observing engine subclass")
            return
        }
        XCTAssertNotNil(engine.observationSink,
                        "observationSink is nil — the owning RichTextEngineEditorView was deallocated")
    }
}

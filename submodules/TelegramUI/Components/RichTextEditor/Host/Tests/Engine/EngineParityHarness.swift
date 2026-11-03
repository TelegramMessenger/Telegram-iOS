import UIKit
import RichTextEditorCore
import RichTextInputDecHost
import RichTextInputDecUpstream
@testable import RichTextEngineEditor

enum EngineParityArm { case raw, hosted }

/// Tier B: the raw engine against the same engine inside RichTextEngineEditorView. Any
/// difference is BY CONSTRUCTION something we introduced — there is no attribution question.
///
/// ONE ARM PER PROCESS (Global Constraint 3): the engine's trace is a process-global static
/// (IDPrivateUIKit.m:24), so two arms alive AT THE SAME TIME in one test process interleave and
/// the readings are junk. Each test builds exactly one arm.
enum EngineParityHarness {
    static let seed = "alpha beta"

    /// Retains the `.hosted` arm's owning `RichTextEngineEditorView` for the lifetime of the arm.
    ///
    /// `makeArm(.hosted)` returns `editor.engine` — a `UIView & UITextInput` — NOT `editor`
    /// itself, because the harness's return type has to be the same shape for both arms and only
    /// the raw engine IS a `UIView & UITextInput` on its own. But the observation wiring lives on
    /// `editor`, not on the engine: `RichTextEngineEditorView.init` builds an `EngineObserver` and
    /// assigns it to `engine.observationSink`, which is declared WEAK
    /// (`TGIDEngineObservation.h`). If `editor` were only a local inside `makeArm`, nothing would
    /// retain it once the function returned — it would deallocate, taking the `EngineObserver`
    /// with it, and `observationSink` would silently go nil. The `.hosted` arm would then be
    /// measuring the SAME raw engine as `.raw`, with no adapter attached, and this whole harness
    /// would report "no differences" forever regardless of what the adapter actually does — the
    /// exact vacuous-instrument failure this task exists to prevent.
    ///
    /// See `EngineParityTests.test_hostedArmRetainsItsOwningEditor`, which is the only check that
    /// stands between this instrument and that failure mode.
    private static var retainedHostedEditor: RichTextEngineEditorView?

    /// The single live arm, so `tearDownArm()` can dismantle it without the caller having to hand
    /// it back. Retained deliberately: a `weak` reference here would be nil for the `.raw` arm the
    /// moment the test's own window is released, which is exactly the case that needs tearing down.
    private static var activeArmView: (UIView & UITextInput)?

    /// ONE ARM PER PROCESS is not a property of `makeArm` alone — it is a property of the whole
    /// process, and as written this enum never gave one back. `retainedHostedEditor` was assigned
    /// and never cleared, no arm ever resigned the first-responder role, and no arm ever left the
    /// window it was added to. So a focused engine (with its private input controller, its
    /// selection presentation and its interaction assistant all live) outlived the test that built
    /// it and was still the first responder while the NEXT test built its own arm — two arms alive
    /// at once, which is the exact condition the constraint exists to prevent and which makes the
    /// process-global trace readings junk.
    ///
    /// Every test that builds an arm must call this from its own `tearDown`. Idempotent, and a
    /// no-op when no arm was built.
    static func tearDownArm() {
        if let view = activeArmView {
            _ = view.resignFirstResponder()
            view.removeFromSuperview()
        }
        activeArmView = nil
        retainedHostedEditor = nil
    }

    /// Builds ONE arm — never both in a process (Global Constraint 3).
    ///
    /// Neither arm's post-construction caret sits at the end of the seeded text: a freshly built
    /// `IDBlockTextView` (and therefore `.raw`, which never runs `RichTextEngineEditorView`'s
    /// `document` setter) defaults its selection to the very START of the document — confirmed
    /// empirically, not assumed — so a caller that types immediately after `becomeFirstResponder()`
    /// without first moving the caret would insert at position 0, not append. `makeArm` seeds
    /// identical content for both arms but deliberately leaves the caret wherever each arm's own
    /// construction naturally puts it; callers that want to type at the end (every test in
    /// `EngineParityTests` does) must position the caret themselves, exactly the way a real host
    /// would. Silently normalizing it here would hide a real difference in the two arms' default
    /// caret behavior — which is exactly the kind of thing this harness exists to surface, not paper
    /// over.
    static func makeArm(_ arm: EngineParityArm, in window: UIWindow) -> UIView & UITextInput {
        // ORDER IS LOAD-BEARING (fix round 1). `IDResetAutocorrectionTraceForUITesting()` does not
        // clear the trace to empty — it sets the process-global static to NIL (a teardown, not a
        // clear; `IDPrivateUIKit.m:46-49`). `IDRecordAutocorrectionTraceForUITesting` appends to
        // that static directly with no nil-check, and Objective-C silently no-ops a message send to
        // nil, so every record made while the static is nil vanishes with no error — and
        // `IDCopyAutocorrectionTraceForUITesting`'s `?: @[]` fallback makes a torn-down trace read
        // exactly like a legitimately-empty one. Reset MUST run first (tearing down any leftover
        // state) and Install MUST run last, so the array is live at the moment `makeArm` returns.
        // The original ordering here (Install then Reset) built the array and immediately
        // discarded it — every trace reading taken against that ordering was measuring a nil
        // static, not the engine. See `trace()`/`startRecording()` below for the matching fix on
        // the per-drive reset path, and this task's report for the full before/after evidence.
        startRecording()
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17.0)]
        let view: UIView & UITextInput
        switch arm {
        case .raw:
            let engine = IDBlockTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240),
                                         attributedBlocks: [NSAttributedString(string: seed,
                                                                               attributes: attributes)])
            engine.isEditable = true
            engine.isSelectable = true
            view = engine
        case .hosted:
            let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
            editor.document = Document(blocks: [.paragraph(ParagraphBlock(
                id: BlockID("p0"), runs: [TextRun(text: seed)]))])
            // Retain `editor` for as long as the arm is alive — see the property's doc comment.
            // Without this line the `.hosted` arm silently degrades into a second `.raw` arm.
            retainedHostedEditor = editor
            view = editor.engine
        }
        window.addSubview(view)
        window.makeKeyAndVisible()
        activeArmView = view
        return view
    }

    /// Wired to the engine's real process-global autocorrection trace
    /// (`IDInstallAutocorrectionTraceForUITesting` / `IDCopyAutocorrectionTraceForUITesting` /
    /// `IDResetAutocorrectionTraceForUITesting`, `IDPrivateUIKit.h`). **Live, not dead** — an
    /// earlier version of this comment claimed the opposite (fix round 1's finding, corrected in
    /// fix round 2). Both claims were made in good faith from real measurements; the first one was
    /// wrong because of TWO compounding bugs, neither of which was a property of the engine:
    ///
    /// 1. `IDResetAutocorrectionTraceForUITesting()` does not clear the trace to empty — it sets the
    ///    process-global static to NIL (a teardown, not a clear). The original `makeArm` called
    ///    Install THEN Reset (nil-ing the array it had just created), and `resetTrace()` called
    ///    Reset again immediately before every drive — so the array was nil at the moment of every
    ///    single measurement. `IDRecordAutocorrectionTraceForUITesting` appends to that static with
    ///    no nil-check (a no-op message-send-to-nil in Objective-C, not a crash), and
    ///    `IDCopyAutocorrectionTraceForUITesting`'s `?: @[]` fallback makes a torn-down trace read
    ///    exactly like a legitimately-empty one — so every reading looked like "no events" with no
    ///    error anywhere. Fixed by `startRecording()` below: Reset first, Install last, so the array
    ///    is always live at the moment `makeArm` (or a per-drive `resetTrace()`) returns.
    /// 2. Independently, the verification NSLog probes used to investigate fix round 1's finding
    ///    printed `IDCopyAutocorrectionTraceForUITesting()`'s default multi-line array description
    ///    (`"(\n    event,\n    event\n)"`) and were then filtered with a grep that only matched the
    ///    line containing the log tag — which is ONLY the opening `"("`, identical for an empty and
    ///    a populated array. Every one of fix round 1's "measured: still empty" readings was reading
    ///    that same truncated first line, not the array's actual contents.
    ///
    /// With both fixed, the trace fires for BOTH arms on a single `insertText`:
    /// `["selectionDidChange", "textDidChange"]` — measured directly, not assumed (see
    /// `EngineParityTests` for the assertions and this task's report for the full before/after
    /// transcript). `EngineParityTests` now gates on `trace().contains("textDidChange")` AS WELL AS
    /// the exact-text-equality assertions the earlier (wrong) diagnosis introduced — the two measure
    /// different facts (the private input delegate actually fired, vs. the document actually
    /// contains what was typed) and neither is redundant with the other.
    static func trace() -> [String] { IDCopyAutocorrectionTraceForUITesting() }

    /// Reset THEN Install, in that order, so the trace is never left nil while a drive happens —
    /// the exact bug fix round 1 found in this file. `resetTrace()` is kept as the name every
    /// caller already uses (interface contract + `EngineParityTests`); it now means "start a fresh
    /// recording", not "tear down and leave torn down".
    static func resetTrace() { startRecording() }

    /// The single place that is allowed to call the raw Reset/Install pair, so the ordering can
    /// only be gotten right or wrong in ONE place rather than at every call site.
    private static func startRecording() {
        IDResetAutocorrectionTraceForUITesting()
        IDInstallAutocorrectionTraceForUITesting()
    }
}

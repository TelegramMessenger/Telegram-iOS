#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit

/// Task C9 — Family 6 (marked text and prediction). Four `RichTextInputTextBackend` witnesses:
/// `markedTextRange`, `markedTextStyle`, `setMarkedText(_:selectedRange:)`, `unmarkText()`.
///
/// **This is the opposite shape from `deleteBackward()`'s (Family 5, `+KeyInput.swift`) two-call
/// forward.** `setMarkedText`/`unmarkText` route into `kernelInput` exactly like every other
/// `kernelInput`-backed witness in `IDTextEditorBackend.swift` — guarded, one call, absent-on-
/// failure — but the STATE this backend must keep in step (`state.markedRange`/`.isComposing`) is
/// NOT uniformly reachable through that one call the way `deleteBackward()`'s is:
///
///   * `setMarkedText(_:selectedRange:)` composes PROVISIONAL TEXT — the private controller drives
///     that through OUR storage façade (`TGRichTextInputDecTextStorageFacade
///     .replaceCharactersInRange:withString:`). **CORRECTION (Task D2):** the paragraph below used to
///     claim the `keyboardInput:shouldInsertText:isMarkedText:YES` canvas thunk latches `.markedText`
///     before that call — R10 already measured (see `latchDeleteBackwardIntent()`'s own doc comment,
///     `IDTextEditorBackend.swift`) that this thunk NEVER fires, and the differential trace's
///     `cjk-compose-commit` scenario confirmed it independently (`documentPrepare(replaceText)`
///     instead of `documentPrepare(setMarkedText)`). `setMarkedText(_:selectedRange:)` below now
///     latches `.markedText` directly, mirroring `insertText(_:)`/`latchDeleteBackwardIntent()`, so
///     the existing Family-4 two-phase transaction
///     (`IDTextEditorBackendClientBridge.prepareAndCommitReplacement` →
///     `IDTextEditorBackendIntent.mutation(for: .markedText, …)` → `documentClient.prepareMutation`/
///     `commitPreparedMutation` → `backend.adoptAndEmitDidChange(_:RichTextInputMutationResult)`)
///     ALREADY adopts `result.markedRange` into `state` and publishes — for free, with no new code
///     in this file. Verified by reading the chain, not assumed: `IDTextEditorBackendIntent.swift`'s
///     `.markedText` case already existed (Task C7), and `adoptAndEmitDidChange(_:)`
///     (`IDTextEditorBackend.swift`) already writes `markedRange: result.markedRange,
///     isComposing: result.markedRange != nil` for every mutation result, not only insert/delete
///     ones.
///   * `unmarkText()` COMMITS an already-provisional composition — no character is inserted or
///     removed (`IDUIKitInputControllerCapability.unmarkText` is a bare one-line forward to the real
///     private controller's own `-unmarkText`, mirroring the standard `UITextInput` contract every
///     text view honors: the marked text is already sitting in storage, committing only clears the
///     "this is marked" bookkeeping). So NO `replaceCharactersInRange:withString:` call reaches our
///     façade, NO `prepareAndCommitReplacement` round-trip happens, and `adoptAndEmitDidChange`
///     never runs — `state.markedRange` would go STALE forever without an explicit retirement.
///     `commitMarkedTextStateIfComposing()` (`IDTextEditorBackend.swift`, this task) is that
///     retirement — a narrow, purpose-built `internal` crossing point, not a blanket widening of
///     `state`/`publishState` (see that method's own doc comment).
///
/// `markedTextRange` and `markedTextStyle` need no such adoption step: the former is a plain
/// `kernelInput`-guarded read (mirrors every other `UITextPosition`/`UITextRange`-returning witness
/// already in `IDTextEditorBackend.swift`); the latter is `get { nil } set { }` — NOT routed into
/// `kernelInput` at all, and NOT the `{ get set }`-backed-by-a-stored-property stub rule this file's
/// own class header states as the default for that shape. This is a DELIBERATE, disclosed exception,
/// pinned by `test_markedTextStyleGetterReturnsNil_andTheSetterIsANoOp`: it mirrors
/// `LegacyRichTextInputBackend+MarkedText.swift`'s own identical member verbatim ("we draw our own
/// underline decoration ... there is no system styling to vend and nothing to remember when UIKit
/// sets one" — `DocumentCanvasView+MarkedText.swift:28`'s pinned legacy behavior, which this backend
/// inherits unchanged rather than reinventing). Routing it onto `kernelInput.markedTextStyle` would
/// be a genuine behavior CHANGE (the getter would start echoing back whatever was last set), not a
/// completion of a placeholder.
@available(iOS 17.0, *)
extension IDTextEditorBackend {

    // MARK: - `RichTextInputTextBackend` (`UITextInput` routing) — marked text / prediction

    var markedTextRange: UITextRange? {
        var error: NSError?
        let value = TGRichTextInputDecPerformReturningObject({
            self.kernelInput?.markedTextRange
        }, &error) as? UITextRange
        if let error { reportKernelFailure(error, witness: #function) }
        return value
    }

    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get { nil }
        set { }
    }

    func setMarkedText(_ text: String?, selectedRange: NSRange) {
        // TASK D2 — a second, independent fix found via the differential trace, same root cause
        // class as `deleteBackward()`'s own pre-warm (`+KeyInput.swift`): the private controller
        // behind `kernelInput` keeps its OWN internally-cached selection, distinct from — and never
        // kept in step with — this backend's canonical `state.selection`. The PROPER
        // `selectedTextRange` setter (`IDTextEditorBackend.swift`) only ever writes `state` via
        // `setSelection(_:reason:)`; nothing pushes that write down into the kernel. So
        // `kernelInput?.setMarkedText(...)` below, unwarmed, composed against wherever the kernel's
        // OWN stale cached selection last was — offset 0 (attach-time default) rather than the caret
        // this witness's own caller just set. Measured directly: the differential trace's
        // `cjk-compose-commit` scenario (caret placed at the end of "Alpha" via the real
        // `selectedTextRange` setter, then `setMarkedText`) composed the marked text at the START of
        // the document instead — `documentPrepare` mutation range `{0, 0}`-relative, not the caret's
        // offset 5. Pre-warming with the exact same `mintKernelSelectedTextRange()` call
        // `deleteBackward()` already uses fixes it.
        var selectionSyncError: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInput?.selectedTextRange = self.mintKernelSelectedTextRange()
        }, &selectionSyncError)
        if let selectionSyncError {
            reportKernelFailure(selectionSyncError, witness: #function)
            return
        }
        // TASK D2 — Swift-side intent latch, mirroring `insertText(_:)`/`latchDeleteBackwardIntent()`.
        // This file's own header above assumed `keyboardInput:shouldInsertText:isMarkedText:YES`
        // latches `.markedText` before the façade's `replaceCharactersInRange:withString:` runs; R10
        // already measured that thunk never fires (see `latchMarkedTextIntent()`'s own doc comment),
        // and the differential trace's `cjk-compose-commit` scenario confirmed it independently
        // (`documentPrepare(replaceText)`, not `documentPrepare(setMarkedText)`, before this fix).
        // TASK D4d — the latch carries the caller's `selectedRange` down with the intent. Without
        // it `IDTextEditorBackendIntent.mutation(for: .markedText, …)` fabricated an
        // end-of-marked-text caret, which the differential corpus measured as a uniform `+2`
        // selection offset at the `offered` checkpoint of every inline-prediction scenario (and
        // which also made every system prediction render as a CJK composition, since
        // `legacySetMarkedText` derives `isPrediction` from this same value). See that method's own
        // doc comment.
        latchMarkedTextIntent(selectedRange: selectedRange)
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInput?.setMarkedText(text, selectedRange: selectedRange)
        }, &error)
        if let error {
            reportKernelFailure(error, witness: #function)
        }
        // No further adoption here — see this file's own header: a real composing edit reaches
        // `adoptAndEmitDidChange(_:)` through the storage façade's two-phase transaction, which
        // already adopts `state.markedRange`/`.isComposing` and publishes.
    }

    func unmarkText() {
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInput?.unmarkText()
        }, &error)
        if let error {
            reportKernelFailure(error, witness: #function)
        }
        // TASK D4f — `unmarkText` commits without mutating a character (see this file's own header),
        // so no façade round-trip will ever retire the composition on its own. This site used to do
        // that with `commitMarkedTextStateIfComposing()` alone, which retires `state` and nothing
        // else — and `state` is not all a commit owes. `DocumentCanvasView.commitMarkedText()`
        // (`+MarkedText.swift`) is where the composition's SINGLE undo step is registered (from the
        // snapshot taken at composition start), and it is reachable only through
        // `legacyApplyMutation`'s `.unmarkText` case, i.e. only through the document client.
        // Without that hop every composition on this backend was un-undoable — measured on the
        // differential corpus's four `*-return-commit-then-undo` scenarios, where the undo popped an
        // empty group, left the composed text in `blocks`, and reported `canRedo == 0` against
        // stock's 1.
        //
        // ORDER IS LOAD-BEARING: the document commit must run FIRST, because
        // `commitMarkedTextStateIfComposing()` clears the very `state.markedRange` that
        // `DocumentCanvasView.commitMarkedText()`'s own `guard markedRange != nil` reads back
        // through `inputBackend.markedRange`. Reversed, the commit finds no composition open and
        // skips the undo registration again — the same silent no-op, one call earlier.
        commitComposedTextInDocument()
        // Still called, now as the FALLBACK for every path the document commit could not take (a
        // detached backend, a rejected preparation) — see its own doc comment. A no-op after a
        // successful commit, which retires `markedRange` itself.
        commitMarkedTextStateIfComposing()
    }
}
#endif

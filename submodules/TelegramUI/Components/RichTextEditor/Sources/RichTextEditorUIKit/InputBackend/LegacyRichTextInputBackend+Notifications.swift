#if canImport(UIKit)
import UIKit

/// TASK 26 — Family 3, the notification half. **This file is the ONLY place in the package that sends
/// a `UITextInputDelegate` notification.** Source-boundary rule R16
/// (`InputBackendSourceBoundaryTests.test_onlyTheBackendSendsInputDelegateNotifications`) enforces
/// that mechanically: no other file under `Sources/` may contain `textWillChange(`, `textDidChange(`,
/// `selectionWillChange(` or `selectionDidChange(` as a send.
///
/// Before this task the 44 canvas-side sites each spelled their own
/// `textInputDelegate?.selectionWillChange(self)` pair inline, and the backend had its own private
/// four (`+Mutation.swift`, moved here unchanged). Two senders of the same notifications is exactly
/// the shape that makes "the backend owns input state" unverifiable, which is why the routing half
/// (`selectedTextRange`/`inputDelegate`) and the emission half had to land together.
///
/// **The receiver argument.** Each emitter passes `host?.hostInputView as? UITextInput`, where every
/// canvas site used to pass `self`. Those are the same object: `DocumentCanvasView.hostInputView` is
/// `self` (`DocumentCanvasView.swift`, the `RichTextInputHost` conformance) and `DocumentCanvasView`
/// conforms to `UITextInput` (`+UITextInput.swift`), so the cast succeeds and yields the very canvas
/// that used to pass itself. The one behavioral difference is the `host?` optional-chain: with no
/// attached host the argument is `nil` rather than the canvas. `UITextInputDelegate` declares the
/// parameter as `UITextInput?`, and the only window in which `host` is nil while a canvas is alive is
/// the documented "attached but host gone" / post-detach window (see `+TextReads.swift`'s Task-24 fix
/// note for the five states that reach it), in which the canvas is being torn down anyway.
///
/// **The three deliberate asymmetries** this file preserves verbatim, each as its own member so a
/// future conformer cannot collapse them into one parameterised bracket:
///   1. `notifyingContentAndSelectionChange` fires all four notifications UNCONDITIONALLY — even for a
///      no-op body and even for an edit the body refuses (deviation D10). Pinned by
///      `DelegateTraceCharacterizationTests.test_editingWithANoOpBody_stillEmitsAllFourNotifications`
///      and `…test_refusedEdit_stillEmitsAllFourNotifications`.
///   2. `notifyingSelectionChange` is SUPPRESSED while `suppressesSelectionNotifications` is set (the
///      per-frame samples of an interactive selection-handle drag), while
///      `notifyingSelectionChangeIgnoringCoalescing` is NOT (`moveFloatingCaret` uses it). Pinned by
///      `…test_coalescedSelectionFrames_emitNothing` vs
///      `…test_moveFloatingCaret_emitsABracketEvenWhileCoalescing`.
///   3. `notifyingContentChange` is a TEXT-ONLY bracket even though the caret moves — the marked-commit
///      and `dismissPrediction` shape. Pinned by `…test_insertTextWhileMarked_emitsATextOnlyBracket`.
///
/// **`body` always runs.** Suppression suppresses the NOTIFICATIONS, never the body — every one of
/// these brackets wraps a real canvas state change that must happen regardless.
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {

    // MARK: - The four `UITextInputDelegate` emitters
    //
    // MOVED VERBATIM from `+Mutation.swift` (where Task 22b introduced them for the mutation path
    // alone, with the note "Task 26 later formalizes these under the same names for the whole
    // package"). Same names, same bodies; only the doc comment and the file changed. They are
    // deliberately NOT on the `RichTextInputBackend` protocol: no canvas site calls one directly, so
    // they stay this conformer's own internal detail.

    /// The ONLY four call sites of `inputDelegate` anywhere in the package.
    func notifyTextWillChange() {
        inputDelegate?.textWillChange(host?.hostInputView as? UITextInput)
    }

    func notifySelectionWillChange() {
        inputDelegate?.selectionWillChange(host?.hostInputView as? UITextInput)
    }

    func notifySelectionDidChange() {
        inputDelegate?.selectionDidChange(host?.hostInputView as? UITextInput)
    }

    func notifyTextDidChange() {
        inputDelegate?.textDidChange(host?.hostInputView as? UITextInput)
    }

    // MARK: - The five brackets (the `RichTextInputBackend` requirements)

    /// Was `DocumentCanvasView+Editing.swift`'s `editing(coalescing:_:)` bracket (`:27-32`), the same
    /// shape in `registerUndo`'s self-re-registering closure (`:72-78`) and in `reload` (`DCV:954-958`).
    func notifyingContentAndSelectionChange(_ body: () -> Void) {
        notifyTextWillChange()
        notifySelectionWillChange()
        body()
        notifySelectionDidChange()
        notifyTextDidChange()
    }

    /// Was the three canvas selection funnels' `if !coalescingSelectionNotifications { … }` pairs
    /// (`setCaret`/`setSelectionHead`/`setSelectionAnchor`). The flag consulted is
    /// `suppressesSelectionNotifications` — the SAME flag `setSelection`'s publish-deferral reads, and
    /// the same one `DocumentCanvasView.beginCoalescedSelectionDrag()`/`endCoalescedSelectionDrag()`
    /// write, so there is exactly one writer of it. (They reached it through a
    /// `coalescingSelectionNotifications` forwarder from Task 26 until TASK 43 deleted it; the canvas
    /// now names this member directly, and `InputBackendSourceBoundaryTests`
    /// `.test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` caps the mentions at four.)
    func notifyingSelectionChange(_ body: () -> Void) {
        let suppressed = suppressesSelectionNotifications
        if !suppressed { notifySelectionWillChange() }
        body()
        if !suppressed { notifySelectionDidChange() }
    }

    /// The unconditional selection bracket: `beginFloatingCursor`'s collapse, `moveFloatingCaret`,
    /// `setMarkedText`'s selection half, `selectTableRows`/`selectTableColumns`/`selectTableCells`,
    /// `selectImage`, `applySelection`, and the composer's `composerSelectedRange` setter all emit
    /// their bracket today regardless of the coalescing flag. `moveFloatingCaret` is the one whose
    /// unsuppressed-ness is a DOCUMENTED asymmetry rather than merely an unconsidered default; that
    /// distinction is a call-site intent and is recorded at the call site
    /// (`DocumentCanvasView+FloatingCursor.swift`), not as a second member here — see
    /// `RichTextInputBackend.swift`'s Task-26 fix-round-1 note.
    func notifyingSelectionChangeIgnoringCoalescing(_ body: () -> Void) {
        notifySelectionWillChange()
        body()
        notifySelectionDidChange()
    }

    /// Was the marked-commit branch of `insertText` (`+UITextInput.swift`), `setMarkedText`'s
    /// provisional-text half and `dismissPrediction` (`+MarkedText.swift`).
    func notifyingContentChange(_ body: () -> Void) {
        notifyTextWillChange()
        body()
        notifyTextDidChange()
    }

    /// Was `endCoalescedSelectionDrag`'s bare pair (`DCV:1846-1847`). Deliberately has no `body`
    /// parameter: the settled selection is already in place, and
    /// `DelegateTraceCharacterizationTests.test_endCoalescedSelectionDrag_emitsExactlyOneBracketWithNoStateChangeBetween`
    /// pins that the WILL and DID events observe identical state — a `body` here would be a place for a
    /// future edit to violate that.
    func notifyCoalescedSelectionResync() {
        notifySelectionWillChange()
        notifySelectionDidChange()
    }
}
#endif

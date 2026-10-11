#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit

/// Task C8 — Family 5 (backward deletion). One witness, `deleteBackward()`.
///
/// **This is the opposite shape from `LegacyRichTextInputBackend+Deletion.swift`'s 24-call-site
/// fan-out.** Legacy owns every branch of backward-delete semantics itself (paragraph merges,
/// table-cell-start behavior, media-gap handling, grapheme-cluster width, …) because it IS the
/// document engine. This backend owns none of that: the private kernel resolves the delete range
/// itself — `_rangesForBackwardsDelete`/`unionRange`, surfaced here only as
/// `preflightBackwardDeleteRanges()`/`backwardDeleteRange()` — using our own
/// `TGRichTextInputDecLayoutController.id_rangeOfCharacterClusterAtIndex:type:` (Family 1, Task
/// C4; manifest row 31) for the grapheme-cluster width, then drives the storage façade's
/// two-phase transaction (Family 4, Task C7). So this witness is a plain call forward — no
/// notification bracket of its own (hard invariant 10: only `emitWillChange`/
/// `adoptAndEmitDidChange` in `IDTextEditorBackend.swift` may send `UITextInputDelegate`
/// notifications, and none of the calls below reaches them directly; the façade transaction the
/// private controller triggers as a SIDE EFFECT of `deleteBackward()` is what does).
///
/// **CORRECTION (Task R10, cluster 9): the `.deleteBackward` intent is NOT latched by the
/// ABI-witnessed `keyboardInputShouldDelete:` preflight** the way this comment used to claim (and
/// the way Task C7 built the mechanism to work for a genuine software-keyboard-driven delete).
/// Measured directly: that thunk never fires when this witness drives the delete itself, on
/// either call path (through a canvas or directly on the backend) — see `deleteBackward()`'s own
/// doc comment and `latchDeleteBackwardIntent()` (`IDTextEditorBackend.swift`) for the evidence
/// and the fix (a direct Swift-side latch, mirroring `insertText(_:)`'s own).
///
/// **Every kernel call below is separately guarded**, per `IDBackendCallGuardTests`' blanket rule
/// ("every reachable entry point", not a per-call risk judgment — the same rule `detach()` already
/// applies to its own two kernel-witness calls). None is combined into one `TGRichTextInputDecPerform`
/// block: if the preflight itself raises or rejects, the actual delete must not be attempted —
/// `_rangesForBackwardsDelete` failing to answer a `unionRange`-capable object is a genuine
/// contract violation, not a "try anyway" situation.
///
/// **Task R10 (cluster 8) added a THIRD guarded call, ahead of the original two: a pre-warm write
/// to `kernelInput?.selectedTextRange`.** See `deleteBackward()`'s own doc comment below for why —
/// in short, the private controller behind `kernelInput` keeps its OWN cached selection, which
/// `setSelection(_:reason:)` never updates, so this witness must hand it a current one before
/// asking it to resolve a delete range against "the caret."
@available(iOS 17.0, *)
extension IDTextEditorBackend {

    // MARK: - `RichTextKeyInputBackend` (`UIKeyInput` routing) — `deleteBackward()`

    func deleteBackward() {
        // Task R10 (cluster 8) — PRE-WARM the kernel's own cached `selectedTextRange` before
        // consulting it about anything. `activeController` (the real private controller behind
        // `kernelInput`) holds its OWN internally-cached selection object, distinct from — and not
        // automatically kept in step with — this backend's canonical `state.selection`:
        // `setSelection(_:reason:)` (Family 3, Task C6/R9) only ever writes `state`; nothing pushes
        // that write back down into the kernel. Under a live keyboard session the two stay in step
        // because the KERNEL is normally the one driving selection changes in the first place
        // (the selection-changed thunks relay ITS state up into `setSelection`, never the other
        // direction — TASK F3 struck `TGThunk_deleteBackwardAndNotify` from that list: it no longer
        // exists, because `_deleteBackwardAndNotify:` turned out to be UIKit ASKING for a delete,
        // not reporting one, and the canvas now inherits UIResponder's implementation, which routes
        // it straight into THIS witness) — but a selection set any other way (every
        // fake-client contract test in this suite, and any future programmatic caller) leaves the
        // kernel's copy stale, so `preflightBackwardDeleteRanges()`/`deleteBackward()` below resolve
        // the delete range against wherever the kernel last thought the caret was, not where this
        // backend's own `state` says it is. Measured directly: without this write,
        // `IDBackendFamily5Tests.test_deleteBackwardUsesTheControllerProposedRange` (caret moved to
        // offset 3 via `setSelection`, kernel's own cached selection left at its attach-time 0) saw
        // ZERO mutations reach the document client — the kernel decided there was nothing before
        // its own (stale, offset-0) caret to delete. Reuses `mintKernelSelectedTextRange()`
        // (`IDTextEditorBackend.swift`) — the EXACT revision-stamped identity the `selectedTextRange`
        // getter already vends to UIKit — rather than inventing a second minting path.
        var selectionSyncError: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInput?.selectedTextRange = self.mintKernelSelectedTextRange()
        }, &selectionSyncError)
        if let selectionSyncError {
            reportKernelFailure(selectionSyncError, witness: #function)
            return
        }
        var preflightError: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInput?.preflightBackwardDeleteRanges()
        }, &preflightError)
        if let preflightError {
            reportKernelFailure(preflightError, witness: #function)
            return
        }
        // Task R10 (cluster 9) — latch `.deleteBackward` OURSELVES, immediately before the call
        // whose internal machinery actually drives the façade's `replaceCharactersInRange:
        // withString:`. See `latchDeleteBackwardIntent()`'s own doc comment (`IDTextEditorBackend.swift`)
        // for the measured evidence that the ABI-witnessed `keyboardInputShouldDelete:` canvas
        // thunk — this file's own header used to say latched it — never actually fires on this
        // call shape. Not itself a kernel call (no `TGRichTextInputDecPerform` needed), so it sits
        // outside `IDBackendCallGuardTests`' scan.
        latchDeleteBackwardIntent()
        var deleteError: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInput?.deleteBackward()
        }, &deleteError)
        if let deleteError {
            reportKernelFailure(deleteError, witness: #function)
        }
    }
}
#endif

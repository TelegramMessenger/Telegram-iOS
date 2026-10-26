#if canImport(UIKit)
import UIKit

/// The facade-callback side of the seam. `backendDidPublishState` maps onto the two coarse channels
/// the canvas already has: `.content`/`.markedText` → notifyContentSizeChanged() (relayed
/// SYNCHRONOUSLY to the facade's onChange, RichTextEditorView.swift:258) and
/// `.selection`/`.interaction` → onSelectionChange (relayed ASYNC-COALESCED, :725-733). That
/// asymmetry is deliberate and is pinned by the Phase-0 facade traces.
@MainActor
@available(iOS 13.0, *)
final class TelegramLifecycleInputClient: RichTextInputLifecycleClient {
    /// `unowned`, deliberately, not `weak` — see `TelegramDocumentInputClient`'s doc comment for the
    /// full rationale (the canvas strictly outlives its clients). Tests that discard the canvas via `_`
    /// must bind it and use `withExtendedLifetime` instead (proven sharp in Task 12 review).
    private unowned let canvas: DocumentCanvasView

    init(canvas: DocumentCanvasView) { self.canvas = canvas }

    /// Read-through, never cached: the spec requires the policy to be read at operation time.
    var editPolicy: RichTextInputEditPolicy { canvas.editPolicy }

    func backendDidAttach() {}
    func backendWillDetach() {}

    func backendWillBeginEditing() -> Bool { true }   // no veto hook exists today
    func backendDidBeginEditing() { canvas.onBecameFirstResponder?() }
    func backendShouldEndEditing() -> Bool { true }
    func backendDidEndEditing() { canvas.onResignedFirstResponder?() }

    func backendDidPublishState(_ state: RichTextInputStateSnapshot,
                                reason: RichTextInputStateChangeReason) {
        switch reason {
        case .content, .markedText, .externalSynchronization:
            canvas.notifyContentSizeChanged()
        case .selection, .interaction:
            guard !canvas.suppressHostChangeNotification else { return }
            canvas.onSelectionChange?()
        case .policy:
            break
        }
    }

    /// Silent by design **for Legacy** —
    /// `test_backendDidRejectMutationIsSilentUnderLegacy` pins that and this body must stay empty for
    /// it. Be precise about WHY, though: Legacy is not rejection-free. It really does call this method,
    /// at `LegacyRichTextInputBackend+Mutation.swift:277` (`.notEditable`) and `:281`
    /// (`.revisionMismatch`), from `prepareAndRun`. What makes the Legacy path silent is that
    /// `prepareAndRun` has **no production entry point** — that file's own header records it: the real
    /// edit paths are plain forwards, and the rejection machinery is reachable only through the
    /// test-only `ReferenceMutationBackend`. But the wording that used to stand here ("no rejection concept exists today") is no longer
    /// true of the other implementor: the InputDec backend DOES reject, at
    /// `TelegramDocumentInputClient.swift:120`, when a mutation's `expectedRevision` fails to match.
    ///
    /// Tasks D4c and D4d both lost time to that. A real rejection arrives here and is dropped without
    /// a log, an assertion, or a counter, so the symptom presented as a mutation that silently did
    /// nothing — which is indistinguishable from the five empty-stub witnesses this programme has
    /// already found, and sent both investigations chasing the wrong layer first.
    ///
    /// Leave the Legacy path silent; if you need to see ID-backend rejections, instrument HERE — it is
    /// the one place every rejection passes through.
    func backendDidRejectMutation(_ mutation: RichTextInputMutation,
                                  reason: RichTextInputMutationRejection) {}

    func backendRequiresLayout(for range: NSRange?, reason: RichTextInputLayoutRequestReason) {
        canvas.notifyContentSizeChanged()
    }
}
#endif

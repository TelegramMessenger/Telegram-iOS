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

    /// No rejection concept exists today, so a legacy rejection is silent by design.
    func backendDidRejectMutation(_ mutation: RichTextInputMutation,
                                  reason: RichTextInputMutationRejection) {}

    func backendRequiresLayout(for range: NSRange?, reason: RichTextInputLayoutRequestReason) {
        canvas.notifyContentSizeChanged()
    }
}
#endif

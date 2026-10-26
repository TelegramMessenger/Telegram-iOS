#if canImport(UIKit)
import UIKit

/// Public facade callbacks and relayout requests are the sole authority of this client.
///
/// `DocumentCanvasView` remains responsible for invoking `super.becomeFirstResponder()` and
/// `super.resignFirstResponder()`; the backend owns ordering around those calls and emits hooks exactly
/// once after successful transitions. Repeated responder calls are idempotent. Failed responder
/// transitions emit no did-begin/did-end callback.
///
/// `backendDidPublishState` is the only input-state publication into Telegram rendering and facade
/// callbacks. Lifecycle callbacks cannot synchronously reenter a mutating backend method. Content size
/// is derived by Telegram after publication; the backend does not own layout size. Edit policy is read
/// at operation time and may change without replacing the backend.
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputLifecycleClient: AnyObject {
    var editPolicy: RichTextInputEditPolicy { get }

    func backendDidAttach()
    func backendWillDetach()

    func backendWillBeginEditing() -> Bool
    func backendDidBeginEditing()
    func backendShouldEndEditing() -> Bool
    func backendDidEndEditing()

    func backendDidPublishState(
        _ state: RichTextInputStateSnapshot,
        reason: RichTextInputStateChangeReason
    )

    func backendDidRejectMutation(
        _ mutation: RichTextInputMutation,
        reason: RichTextInputMutationRejection
    )

    func backendRequiresLayout(
        for range: NSRange?,
        reason: RichTextInputLayoutRequestReason
    )
}
#endif

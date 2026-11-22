#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

/// The recording twin of the pre-existing `InputDelegateSpy` (T/MarkedTextTests.swift:7), which holds
/// four independent counters and no order. This writes into the shared `RichTextInputEventLog` instead,
/// so a contract test can assert this delegate's four notifications interleaved correctly against the
/// six clients' events. `InputDelegateSpy` is untouched — it has live users in `MarkedTextTests.swift`.
///
/// `conversationContext(_:didChange:)` must be implemented (matching `InputDelegateSpy`) — the
/// `UITextInputDelegate` conformance is incomplete on current SDKs without it.
@MainActor
@available(iOS 16.0, *)
final class RecordingInputDelegate: NSObject, UITextInputDelegate {
    let log: RichTextInputEventLog
    init(log: RichTextInputEventLog) { self.log = log }

    func selectionWillChange(_ textInput: UITextInput?) {
        log.record(.delegateSelectionWillChange)
    }
    func selectionDidChange(_ textInput: UITextInput?) {
        log.record(.delegateSelectionDidChange)
    }
    func textWillChange(_ textInput: UITextInput?) {
        log.record(.delegateTextWillChange)
    }
    func textDidChange(_ textInput: UITextInput?) {
        log.record(.delegateTextDidChange)
    }
    @available(iOS 18.4, *)
    func conversationContext(_ context: UIConversationContext?, didChange textInput: UITextInput?) {}
}
#endif

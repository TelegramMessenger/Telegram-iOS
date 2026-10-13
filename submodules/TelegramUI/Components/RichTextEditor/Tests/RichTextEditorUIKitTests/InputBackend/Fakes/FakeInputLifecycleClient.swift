#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

@MainActor
@available(iOS 16.0, *)
final class FakeInputLifecycleClient: RichTextInputLifecycleClient {
    let log: RichTextInputEventLog
    init(log: RichTextInputEventLog) { self.log = log }

    /// Mutable so 22i's policy tests can change it mid-test; `editPolicyReadCount` proves it is read
    /// AT OPERATION TIME by the backend under test rather than cached once at attach.
    var editPolicyStorage: RichTextInputEditPolicy = .legacyUnrestricted
    private(set) var editPolicyReadCount = 0
    var editPolicy: RichTextInputEditPolicy {
        editPolicyReadCount += 1
        return editPolicyStorage
    }

    var willBeginEditingAllowed = true
    var shouldEndEditingAllowed = true

    /// Reentrancy injection hooks: fire synchronously from inside the corresponding callback so a test
    /// can exercise a client that calls back into the backend mid-callback.
    var onDidAttach: (() -> Void)? = nil
    var onDidPublishState: ((RichTextInputStateSnapshot, RichTextInputStateChangeReason) -> Void)? = nil

    private(set) var didAttachCallCount = 0
    private(set) var willDetachCallCount = 0
    private(set) var lastPublishedState: RichTextInputStateSnapshot? = nil
    private(set) var lastPublishReason: RichTextInputStateChangeReason? = nil
    private(set) var lastRejectedMutation: RichTextInputMutation? = nil
    private(set) var lastRejectionReason: RichTextInputMutationRejection? = nil
    private(set) var lastLayoutRequestRange: NSRange? = nil
    private(set) var lastLayoutRequestReason: RichTextInputLayoutRequestReason? = nil

    func backendDidAttach() {
        didAttachCallCount += 1
        log.record(.lifecycleDidAttach)
        onDidAttach?()
    }
    func backendWillDetach() {
        willDetachCallCount += 1
        log.record(.lifecycleWillDetach)
    }
    func backendWillBeginEditing() -> Bool {
        log.record(.lifecycleWillBeginEditing(allowed: willBeginEditingAllowed))
        return willBeginEditingAllowed
    }
    func backendDidBeginEditing() {
        log.record(.lifecycleDidBeginEditing)
    }
    func backendShouldEndEditing() -> Bool {
        log.record(.lifecycleShouldEndEditing(allowed: shouldEndEditingAllowed))
        return shouldEndEditingAllowed
    }
    func backendDidEndEditing() {
        log.record(.lifecycleDidEndEditing)
    }
    func backendDidPublishState(_ state: RichTextInputStateSnapshot, reason: RichTextInputStateChangeReason) {
        lastPublishedState = state
        lastPublishReason = reason
        log.record(.lifecyclePublish(revision: state.documentRevision, reason: "\(reason)"))
        onDidPublishState?(state, reason)
    }
    func backendDidRejectMutation(_ mutation: RichTextInputMutation, reason: RichTextInputMutationRejection) {
        lastRejectedMutation = mutation
        lastRejectionReason = reason
        log.record(.lifecycleReject(mutation: "\(mutation)", reason: "\(reason)"))
    }
    func backendRequiresLayout(for range: NSRange?, reason: RichTextInputLayoutRequestReason) {
        lastLayoutRequestRange = range
        lastLayoutRequestReason = reason
        log.record(.lifecycleRequiresLayout(range: range, reason: "\(reason)"))
    }
}
#endif

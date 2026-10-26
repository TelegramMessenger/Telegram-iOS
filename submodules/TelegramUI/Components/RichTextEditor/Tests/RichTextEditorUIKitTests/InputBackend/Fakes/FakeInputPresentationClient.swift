#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

@MainActor
@available(iOS 16.0, *)
final class FakeInputPresentationClient: RichTextInputPresentationClient {
    let log: RichTextInputEventLog
    init(log: RichTextInputEventLog) { self.log = log }

    /// Owned so `test_interactionContainerViewIdentity_isStableForTheBackendLifetime` (22-series) can
    /// assert identity across repeated `interactionContainerView` reads.
    let containerView = UIView()
    var interactionContainerView: UIView { containerView }

    var visibleBounds: CGRect = CGRect(x: 0, y: 0, width: 300, height: 600)

    private(set) var applyCallCount = 0
    private(set) var lastAppliedSnapshot: RichTextInputPresentationSnapshot? = nil
    private(set) var lastInvalidation: RichTextInputPresentationInvalidation? = nil
    private(set) var tearDownCallCount = 0

    /// TASK 22g ADDITION: reentrancy injection hook, mirroring `FakeInputLifecycleClient.onDidPublishState`
    /// — fires synchronously from inside `apply(_:)`, AFTER the log record, so a test can exercise a
    /// presentation client that calls back into the backend mid-publish (`publishState` calls
    /// `presentationClient.apply(...)` BEFORE `lifecycleClient.backendDidPublishState(...)`, so this
    /// fires earlier in the bracket than that hook does). `nil` (default) preserves every earlier
    /// test's behavior exactly.
    var onApply: (() -> Void)? = nil

    func apply(_ snapshot: RichTextInputPresentationSnapshot) {
        applyCallCount += 1
        lastAppliedSnapshot = snapshot
        log.record(.presentationApply(revision: snapshot.state.documentRevision,
                                      caretIsNil: snapshot.caret == nil,
                                      segmentCount: snapshot.visibleSelectionSegments.count))
        onApply?()
    }
    func invalidate(_ invalidation: RichTextInputPresentationInvalidation) {
        lastInvalidation = invalidation
        log.record(.presentationInvalidate(raw: invalidation.rawValue))
    }
    func requestReveal(_ target: RichTextInputRevealTarget, animated: Bool) {
        log.record(.presentationReveal(target: "\(target)", animated: animated))
    }
    func dismissEditMenu(reason: RichTextInputEditMenuDismissReason) {
        log.record(.presentationDismissEditMenu(reason: "\(reason)"))
    }
    func tearDownPresentation() {
        tearDownCallCount += 1
        log.record(.presentationTearDown)
    }
}
#endif

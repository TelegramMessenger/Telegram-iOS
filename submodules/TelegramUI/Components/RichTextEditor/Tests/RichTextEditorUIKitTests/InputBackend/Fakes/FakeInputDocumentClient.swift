#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

@MainActor
@available(iOS 16.0, *)
final class FakeInputDocumentClient: RichTextInputDocumentClient {
    let log: RichTextInputEventLog
    init(log: RichTextInputEventLog) { self.log = log }

    // MARK: state the tests drive
    var revision: UInt64 = 1
    var utf16Length: Int = 100
    var plainTextToReturn: String? = "Alpha"
    var attributedTextToReturn: NSAttributedString? = NSAttributedString(string: "Alpha")
    /// Read PER CALL by `typingAttributes(at:)`. Deviation D25's test mutates this dictionary
    /// between two reads and asserts the second read sees the change — which is only possible if
    /// the backend caches nothing.
    var typingAttributesByOffset: [Int: [NSAttributedString.Key: Any]] = [:]
    private(set) var typingAttributesReadCount = 0
    /// nil ⇒ `rebase` returns nil (the "cannot be rebased" case).
    var rebaseResult: RichTextInputPosition? = nil
    private(set) var rebaseCallCount = 0
    private(set) var receivedExpectedRevisions: [UInt64] = []
    /// TASK 22c FIX ROUND 1 ADDITION. When non-nil, EVERY call to `rebase(_:fromRevision:)` sets
    /// `revision` to this value AFTER recording the call — simulating "the document moves again
    /// literally inside the rebase call", so a test can prove the backend commits to the ONE
    /// `document.revision` snapshot it read BEFORE rebasing rather than a live re-read afterward
    /// (which would chase a moving target — the shape a `while document.revision != documentRevision`
    /// loop would exploit). `nil` (default) preserves every prior test's behavior exactly.
    var revisionAfterRebase: UInt64? = nil
    /// TASK 22c FIX ROUND 1 ADDITION. When non-empty, each call to `rebase(_:fromRevision:)` pops and
    /// returns its FIRST element (falling back to `rebaseResult` once exhausted) — lets a test give
    /// SUCCESSIVE calls (e.g. a non-collapsed selection's anchor then head) DIFFERENT outcomes, which
    /// the single shared `rebaseResult` cannot express. Empty (default) preserves every prior test's
    /// behavior.
    var rebaseResultsQueue: [RichTextInputPosition?] = []
    /// TASK 22f FIX ROUND 1 (review Major 3 / Focal Point 2b) ADDITION. Invoked (if set), from INSIDE
    /// `rebase(_:fromRevision:)`, right after the log record — a reentrant callout so a test can
    /// sample backend state (e.g. `backend.state.documentRevision`) MID-reconciliation, before
    /// `synchronizeAfterExternalChange` adopts `change.newRevision`/`change.selection`. Same
    /// "callout from inside the call" shape as `revisionAfterRebase`/`rebaseResultsQueue` above.
    /// `nil` (default) preserves every earlier test's behavior exactly.
    var onRebase: (() -> Void)? = nil
    /// Set to a rejection to make the NEXT prepare terminal.
    var nextPreparationRejection: RichTextInputMutationRejection? = nil
    /// TASK 22b ADDITION. Set to make the NEXT prepare a terminal NO-CHANGE outcome (the spec's
    /// other terminal disposition alongside `.rejected` — see `BackendMutationContractTests
    /// .test_terminalNoChange_leavesTheRevisionUnchanged`). One-shot, mirroring
    /// `nextPreparationRejection`'s consume-once shape. Defaults preserve every pre-22b test's
    /// behavior (a `.ready` preparation unless a rejection is armed).
    var nextPreparationNoChange: Bool = false
    /// TASK 22b ADDITION. Independent overrides for the NEXT `.ready` preparation's two flags —
    /// needed so `BackendMutationContractTests.test_preparationFlags_gateTheWillNotificationsIndependently`
    /// and `.test_resultDisagreeingWithPreparationFlags_reportsAContractViolation` can construct a
    /// preparation whose flags do NOT match what `commitDisposition` will report, which the
    /// pre-22b hardcoded `true`/`true` couldn't express. Defaults preserve the exact pre-22b
    /// behavior for every earlier test in this fixture.
    var nextPreparationContentWillChange: Bool = true
    var nextPreparationSelectionWillChange: Bool = true
    /// TASK 22b ADDITION. Every mutation handed to `prepareMutation`, in call order — lets a test
    /// inspect exactly what the backend constructed (e.g. that `deleteBackward()`'s `proposedRange`
    /// was forwarded verbatim, or that `insertText(_:)`'s attributed string carries the resolved
    /// typing attributes) without parsing the log's stringly-typed `"\(mutation)"` description.
    private(set) var receivedMutations: [RichTextInputMutation] = []
    /// What `commitPreparedMutation` reports back.
    var commitDisposition: RichTextInputMutationResult.Disposition = .applied
    var commitSelection = RichTextCanonicalSelection.caret(at: .downstream(0))
    var commitMarkedRange: NSRange? = nil
    var commitBumpsRevision = true

    // MARK: token discipline, self-enforced
    private(set) var issuedTokens: [UUID] = []
    private(set) var consumedTokens: [UUID] = []
    private(set) var sawDoubleCommit = false
    private(set) var sawUnconsumedPreparation = false
    /// Called from every suite's tearDown. "Consumed exactly once before returning to the run loop"
    /// therefore becomes a DEFAULT assertion instead of a per-test one.
    func finish() { sawUnconsumedPreparation = issuedTokens.count != consumedTokens.count }

    // MARK: RichTextInputDocumentClient
    func plainText(in range: NSRange) -> String? {
        log.record(.documentRead(kind: "plainText", range: range)); return plainTextToReturn
    }
    func attributedText(in range: NSRange) -> NSAttributedString? {
        log.record(.documentRead(kind: "attributedText", range: range)); return attributedTextToReturn
    }
    func typingAttributes(at position: RichTextInputPosition) -> [NSAttributedString.Key: Any] {
        typingAttributesReadCount += 1
        return typingAttributesByOffset[position.utf16Offset] ?? [:]
    }
    func clamp(_ position: RichTextInputPosition) -> RichTextInputPosition {
        RichTextInputPosition(utf16Offset: min(max(position.utf16Offset, 0), utf16Length),
                              affinity: position.affinity)
    }
    func isValidInsertionPosition(_ position: RichTextInputPosition) -> Bool {
        position.utf16Offset >= 0 && position.utf16Offset <= utf16Length
    }
    func rebase(_ position: RichTextInputPosition, fromRevision: UInt64) -> RichTextInputPosition? {
        rebaseCallCount += 1
        log.record(.documentRebase(offset: position.utf16Offset, fromRevision: fromRevision))
        onRebase?()
        if let revisionAfterRebase { revision = revisionAfterRebase }
        if !rebaseResultsQueue.isEmpty { return rebaseResultsQueue.removeFirst() }
        return rebaseResult
    }
    func prepareMutation(_ mutation: RichTextInputMutation,
                         expectedRevision: UInt64) -> RichTextInputMutationPreparation {
        receivedExpectedRevisions.append(expectedRevision)
        receivedMutations.append(mutation)
        log.record(.documentPrepare(mutation: "\(mutation)", expectedRevision: expectedRevision))
        if let rejection = nextPreparationRejection {
            nextPreparationRejection = nil
            return .terminal(result(disposition: .rejected(rejection), changed: false))
        }
        if nextPreparationNoChange {
            nextPreparationNoChange = false
            return .terminal(result(disposition: .noChange, changed: false))
        }
        let token = UUID()
        issuedTokens.append(token)
        return .ready(RichTextInputPreparedMutation(token: token, expectedRevision: expectedRevision,
                                                    contentWillChange: nextPreparationContentWillChange,
                                                    selectionWillChange: nextPreparationSelectionWillChange))
    }
    func commitPreparedMutation(_ prepared: RichTextInputPreparedMutation) -> RichTextInputMutationResult {
        log.record(.documentCommit(token: prepared.token))
        if consumedTokens.contains(prepared.token) { sawDoubleCommit = true }
        consumedTokens.append(prepared.token)
        if commitBumpsRevision, commitDisposition == .applied { revision += 1 }
        return result(disposition: commitDisposition, changed: commitDisposition == .applied)
    }

    private func result(disposition: RichTextInputMutationResult.Disposition,
                        changed: Bool) -> RichTextInputMutationResult {
        RichTextInputMutationResult(
            disposition: disposition, revision: revision, selection: commitSelection,
            markedRange: commitMarkedRange, affectedRange: nil, contentChanged: changed,
            selectionChanged: changed, legacyConservativePreparation: true)
    }
}
#endif

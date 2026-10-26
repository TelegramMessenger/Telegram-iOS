#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Task 22b, the first of eight contract suites (22b-22i). Pins the mutation-execution contract —
/// prepare, the two will-notifications, commit exactly once, adopt the result, the two
/// did-notifications, publish — using the backend under test's two `RichTextKeyInputBackend`
/// witnesses (`insertText(_:)` / `deleteBackward()`), which this task gave a real body (see the
/// production `+Mutation.swift` file added alongside this one). TASK 27b moved `insertText(_:)`'s body
/// out of that file and onto the test-only `ReferenceMutationBackend` — see `makeBackend()` below;
/// `deleteBackward()`'s is still there, awaiting Task 28.
///
/// `class`, not `final class` — Task 22a's `BackendContractCases` is subclassed again by stage 2,
/// which overrides ONLY `makeBackend()`. The only place this file names a concrete backend type
/// is that override, below.
@MainActor
@available(iOS 16.0, *)
class BackendMutationContractTests: BackendContractCases {
    /// **TASK 27b — `ReferenceMutationBackend`, not `LegacyRichTextInputBackend`.** This suite drives
    /// `backend.insertText(…)`, and stage 1's legacy conformer no longer owns that mutation: its
    /// witness is now a plain `legacyCanvas` forward (deviation **D35**, ruled by the user
    /// 2026-08-19), so against it those tests would assert a contract this conformer does not meet.
    /// `ReferenceMutationBackend` (`T/Support/`) is the stage-1 conformer that does: a real
    /// `LegacyRichTextInputBackend` for every OTHER member — every non-mutation test in this file
    /// still exercises exactly the production code it did before, one forward away — carrying the
    /// Task-22b transaction body on `insertText(_:)` and running it through the SAME production
    /// `prepareAndRun`/`runMutation` machinery. **No test body in this file changed.** Stage 2
    /// re-overrides this one method with `IDTextEditorBackend()`, for which the mutation contract is a
    /// first-party obligation.
    ///
    /// This suite is the mutation contract itself: 8 of its 9 tests drive `insertText`, the 9th drives
    /// `deleteBackward` (still the legacy conformer's own body, forwarded, until Task 28 moves it the
    /// same way).
    override func makeBackend() -> (any RichTextInputBackend)? {
        ReferenceMutationBackend()
    }

    /// Every test in this file needs delegate notifications to be OBSERVABLE, so wire the shared
    /// `RecordingInputDelegate` directly onto the backend (bypassing canvas plumbing, which does not
    /// route `inputDelegate` to the backend until Task 26 — this suite tests the backend in
    /// isolation, which is exactly what `backend: any RichTextInputBackend` is for).
    private var delegate: RecordingInputDelegate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        delegate = RecordingInputDelegate(log: log)
        backend.inputDelegate = delegate
    }

    override func tearDownWithError() throws {
        delegate = nil
        try super.tearDownWithError()
    }

    // MARK: - 1. The worked example: the whole ordering, end to end

    /// The spec's mutation order, end to end. This exact array is the contract: prepare, the two
    /// will-notifications, commit, the two did-notifications, presentation, publication.
    ///
    /// RED IF: `runMutation` reorders any of the eight steps, calls `commitPreparedMutation` more
    /// than once, skips a notification, or skips the trailing publish.
    func test_insertText_readyPreparation_commitsExactlyOnce_andPublishesApplied() {
        backend.insertText("x")
        XCTAssertEqual(log.kinds,
                       ["documentPrepare", "delegateTextWillChange", "delegateSelectionWillChange",
                        "documentCommit", "delegateSelectionDidChange", "delegateTextDidChange",
                        "presentationApply", "lifecyclePublish"])
        // Adapted from the brief's literal `host.document.issuedTokens` (not compilable against the
        // base class's `host: any RichTextInputHost`, which has no `.document` shorthand) to the
        // fixture's own downcast accessor — same assertion, same intent: the one issued token was
        // consumed exactly once before returning to the run loop.
        XCTAssertEqual(fakeHost!.fakeDocumentClient.issuedTokens, fakeHost!.fakeDocumentClient.consumedTokens)
    }

    // MARK: - 2. Terminal rejection

    /// RED IF: a rejection ever reached a delegate notification, a commit, or a publication — or if
    /// the dedicated rejection signal (`backendDidRejectMutation`, distinct from both the delegate
    /// notifications and `backendDidPublishState`'s publication) stopped firing.
    func test_terminalRejection_emitsNoDelegateNotifications_andNoPublication() {
        fakeHost!.fakeDocumentClient.nextPreparationRejection = .invalidRange

        backend.insertText("x")

        XCTAssertEqual(log.kinds, ["documentPrepare", "lifecycleReject"])
    }

    // MARK: - 3. Terminal no-change

    /// The OTHER terminal disposition alongside rejection. Unlike a rejection, a no-change has no
    /// `RichTextInputMutationRejection` to report, so it is silent — no `lifecycleReject` either.
    ///
    /// RED IF: the revision moved despite nothing committing, or a notification/publication leaked
    /// through for a preparation that never reached `.ready`.
    func test_terminalNoChange_leavesTheRevisionUnchanged() {
        let before = backend.state.documentRevision
        fakeHost!.fakeDocumentClient.nextPreparationNoChange = true

        backend.insertText("x")

        XCTAssertEqual(backend.state.documentRevision, before)
        XCTAssertEqual(log.kinds, ["documentPrepare"])
    }

    // MARK: - 4. Preparation flags are unconditional (deviation D10)

    /// Deviation D10 + Task 26's own `notifyingContentAndSelectionChange(_:)` signature (which takes
    /// no flags parameter at all): the legacy backend's will-notifications are UNCONDITIONAL — they
    /// do not gate on `contentWillChange`/`selectionWillChange`. Pinned by driving each flag false
    /// INDEPENDENTLY of the other and observing BOTH notifications still fire either way.
    ///
    /// RED IF: a future change made either notification conditional on its matching flag (a
    /// plausible-looking "fix" that would in fact contradict D10 and change legacy's keyboard
    /// behavior, per the deviation's own justification).
    func test_preparationFlags_gateTheWillNotificationsIndependently() {
        fakeHost!.fakeDocumentClient.nextPreparationContentWillChange = false
        fakeHost!.fakeDocumentClient.nextPreparationSelectionWillChange = true

        backend.insertText("x")

        XCTAssertEqual(log.count("delegateTextWillChange"), 1,
                       "contentWillChange=false must not suppress textWillChange")
        XCTAssertEqual(log.count("delegateSelectionWillChange"), 1)

        log.reset()
        fakeHost!.fakeDocumentClient.nextPreparationContentWillChange = true
        fakeHost!.fakeDocumentClient.nextPreparationSelectionWillChange = false

        backend.insertText("y")

        XCTAssertEqual(log.count("delegateTextWillChange"), 1)
        XCTAssertEqual(log.count("delegateSelectionWillChange"), 1,
                       "selectionWillChange=false must not suppress selectionWillChange")
    }

    // MARK: - 5. A disagreeing result is a contract violation

    /// `RichTextInputDocumentClient.commitPreparedMutation`'s own doc comment: a commit "must agree
    /// with the preparation's contentWillChange/selectionWillChange flags." Construct a preparation
    /// that says content will NOT change, then let the (default-`.applied`) commit report that it
    /// DID — a genuine disagreement the executor must catch and report, not silently accept.
    ///
    /// RED IF: `runMutation` stopped comparing `result.contentChanged`/`.selectionChanged` against
    /// their matching preparation flags.
    func test_resultDisagreeingWithPreparationFlags_reportsAContractViolation() {
        fakeHost!.fakeDocumentClient.nextPreparationContentWillChange = false
        // selectionWillChange stays true (default) and commitDisposition stays .applied (default), so
        // the fake's commit reports BOTH contentChanged and selectionChanged true: content disagrees
        // with its own preparation, selection agrees — exactly one violation expected.

        backend.insertText("x")

        let violations = log.events.compactMap { event -> String? in
            if case .contractViolation(let message) = event { return message }
            return nil
        }
        XCTAssertEqual(violations.count, 1)
        XCTAssertTrue(violations.first?.contains("contentWillChange") ?? false,
                     "expected the violation to name the disagreeing flag; got \(violations)")
    }

    // MARK: - 6. A rejection touches no annotation or undo state

    /// Distinct from test 2 above: this test's own contribution is the TOKEN-level assertion, which
    /// the log alone cannot express — a token is only ever issued (and only ever consumed) on the
    /// `.ready` path, so a rejected preparation issuing zero tokens is direct proof
    /// `commitPreparedMutation` (and, in a real client, undo registration) never ran.
    ///
    /// RED IF: a rejection ever caused a token to be issued/consumed, or an annotation event to be
    /// recorded into the shared log.
    func test_rejection_touchesNoAnnotationOrUndoState() {
        fakeHost!.fakeDocumentClient.nextPreparationRejection = .prohibitedStructuralEdit

        backend.insertText("x")

        XCTAssertFalse(log.kinds.contains("annotationAdd"))
        XCTAssertFalse(log.kinds.contains("annotationRemove"))
        XCTAssertTrue(fakeHost!.fakeDocumentClient.issuedTokens.isEmpty,
                     "a rejected preparation must never issue a mutation token — issuing one would " +
                     "imply commitPreparedMutation (and therefore undo registration) could run")
        XCTAssertTrue(fakeHost!.fakeDocumentClient.consumedTokens.isEmpty)
    }

    // MARK: - 7. deleteBackward's proposed range

    /// `deleteBackward()` carries no explicit range parameter, so the document client's
    /// `.deleteBackward` mutation case's `proposedRange` must be synthesized from the backend's own
    /// current selection and forwarded VERBATIM (the same numeric range as `selection.normalizedRange`,
    /// not dropped to `nil` and not independently derived).
    ///
    /// RED IF: `deleteBackward()` ever passed `proposedRange: nil`, or a range that disagreed with
    /// the selection it was built from.
    func test_deleteBackwardWithProposedRange_forwardsTheProposedRangeVerbatim() {
        backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(2), head: .downstream(5)),
                             reason: .programmatic)
        log.reset()   // clear setSelection's own publish noise — irrelevant to this test

        backend.deleteBackward()

        guard case .deleteBackward(let selection, let proposedRange) =
            fakeHost!.fakeDocumentClient.receivedMutations.last else {
            XCTFail("expected the last received mutation to be .deleteBackward")
            return
        }
        XCTAssertEqual(selection, RichTextCanonicalSelection(anchor: .downstream(2), head: .downstream(5)))
        XCTAssertEqual(proposedRange, NSRange(location: 2, length: 3))
    }

    // MARK: - 8. The document client never sends delegate notifications

    /// Structural guarantee, not just a behavioral one: `RichTextInputDocumentClient` conformers hold
    /// no reference to a `UITextInputDelegate` at all (the fake is constructed from `log` alone), so
    /// they CANNOT themselves be the source of a delegate notification — only the backend, which
    /// alone holds `inputDelegate`, can be. Combined with a dynamic check that the expected four
    /// notifications did in fact fire (so the type check isn't pinning an accidentally-silent path).
    ///
    /// RED IF: `RichTextInputDocumentClient` (or a future conformer) ever gained a `UITextInputDelegate`
    /// conformance, or a mutation stopped emitting all four delegate notifications.
    func test_documentClientNeverSendsInputDelegateNotifications() {
        XCTAssertFalse(fakeHost!.fakeDocumentClient is UITextInputDelegate,
                       "RichTextInputDocumentClient.swift: \"The document client never calls " +
                       "UITextInputDelegate — the backend owns delegate ordering around this call.\"")

        backend.insertText("x")

        XCTAssertEqual(log.count("delegateTextWillChange"), 1)
        XCTAssertEqual(log.count("delegateSelectionWillChange"), 1)
        XCTAssertEqual(log.count("delegateSelectionDidChange"), 1)
        XCTAssertEqual(log.count("delegateTextDidChange"), 1)
    }

    // MARK: - 9. Deviation D25: no typing-attribute cache

    /// The spec's authority table gives the active backend a transient typing-attribute cache; the
    /// legacy backend has none (deviation D25) — `typingAttributes(at:)` is resolved fresh on every
    /// `insertText(_:)` call. Set an attribute for the offset the backend will query, insert, mutate
    /// the dictionary out from under it, insert again at the (new) query offset, and confirm the
    /// second read reflects the change with `typingAttributesReadCount == 2`.
    ///
    /// RED IF: the backend ever memoized a typing-attributes lookup (the second insert would carry
    /// the FIRST font, or `typingAttributesReadCount` would stay at 1).
    func test_typingAttributesAreResolvedPerCall_theLegacyBackendCachesNothing() {
        backend.setSelection(.caret(at: .downstream(3)), reason: .programmatic)
        let fontA = UIFont.systemFont(ofSize: 12)
        fakeHost!.fakeDocumentClient.typingAttributesByOffset[3] = [.font: fontA]

        backend.insertText("x")

        XCTAssertEqual(fakeHost!.fakeDocumentClient.typingAttributesReadCount, 1)
        guard case .insertText(let firstText, _, _) = fakeHost!.fakeDocumentClient.receivedMutations.last else {
            XCTFail("expected an .insertText mutation"); return
        }
        XCTAssertEqual(firstText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, fontA)

        // Read the SAME offset the backend will actually query next (its own current head, per the
        // fake's fixed `commitSelection` default), then mutate the dictionary there.
        let nextOffset = backend.canonicalSelectionHeadOffset
        let fontB = UIFont.systemFont(ofSize: 20)
        fakeHost!.fakeDocumentClient.typingAttributesByOffset[nextOffset] = [.font: fontB]

        backend.insertText("y")

        XCTAssertEqual(fakeHost!.fakeDocumentClient.typingAttributesReadCount, 2)
        guard case .insertText(let secondText, _, _) = fakeHost!.fakeDocumentClient.receivedMutations.last else {
            XCTFail("expected a second .insertText mutation"); return
        }
        XCTAssertEqual(secondText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, fontB,
                      "the second read must reflect the just-mutated dictionary — proving nothing is cached")
    }
}
#endif

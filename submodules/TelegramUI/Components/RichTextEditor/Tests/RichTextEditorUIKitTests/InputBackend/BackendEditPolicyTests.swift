#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Task 22i, the LAST of the eight contract suites (22b-22i). Pins the per-operation
/// `RichTextInputEditPolicy` gate — purely through the `any RichTextInputBackend`/`any
/// RichTextInputHost` surface, never a concrete type — and, being last, is also where the whole
/// eight-suite matrix gets its final mechanical check (see `task-22i-report.md`).
///
/// The gate is PER-OPERATION, not global: a policy that blocks editing must not block reads,
/// geometry, or selection queries. This suite pins exactly four of the six `RichTextInputEditPolicy`
/// fields against exactly the one operation each is documented to gate:
/// - `isEditable` → the mutation family (`insertText`/`deleteBackward`, routed through the shared
///   `prepareAndRun` chokepoint in `+Mutation.swift` — gating there covers both without a duplicated
///   check) and, separately, `editPolicyDidChange()`'s own edit-menu dismissal.
/// - `isSelectable` → `setSelection(_:reason:)` (which `selectedTextRange`'s setter and the
///   floating-cursor path both route through — one gate point covers them). **TASK 35 CORRECTION:
///   this line used to name `setCanonicalAnchor`/`setCanonicalHead` as routing through the gate too,
///   and they no longer do** — Task 35 turned them into the raw, ungated writes backing the canvas
///   `anchor`/`head` forwarders, because a pre-seam `anchor = …` consulted no policy and 117 canvas
///   sites must not start doing so in one commit. Nothing this suite asserts changes: it drives
///   `setSelection` directly. Tasks 36a-39 move those sites INTO this gate one cluster at a time and
///   Task 40b deletes the ungated pair, after which the parenthesis is true again as written.
///   **TASK 36a CORRECTION — 36a-36c do NOT move them into this gate.** They funnel
///   `DocumentCanvasView+Editing.swift`'s 34 write sites into ONE application point
///   (`applyCaretOutcome`) that keeps using the raw pair, because routing it through `setSelection`
///   doubles the host selection report `editing`'s own tail emits (measured; that method's doc
///   comment is the one place the numbers live). So those 34 sites reach this gate at Task
///   40b, in one line, rather than one cluster at a time — and until then `isSelectable` still does
///   not gate them. Nothing this suite asserts changes; it still drives `setSelection` directly.
/// - `allowsPaste` → `canPerformCommand(.paste, sender:)`.
/// - `allowsDictation` → `insertDictationResult(_:)` (D15's permanently-unwitnessed member — see that
///   test's own comment for what "reject" can mean when the member never touches the document client
///   either way).
///
/// `allowsRichText` and `allowsWritingTools` are DELIBERATELY NOT covered here — `allowsWritingTools`
/// maps to `isEditableForWritingTools` (Deviation D3) and the rest of the responder-lifecycle family,
/// which Task 31 routes; this task does not reach into that scope.
///
/// **TASK 31 FIX ROUND 1 — that sentence read as a forward reference to coverage Task 31 would supply,
/// and Task 31 deliberately did NOT supply it.** It routed `isEditableForWritingTools` as a bare
/// `true` (`+Responder.swift`), the literal the pre-seam witness answered, and explicitly did NOT gate
/// it on `allowsWritingTools`: the witness consulted nothing, so wiring the policy would have been NEW
/// behaviour inside a zero-behaviour-change phase. **`allowsWritingTools` therefore still has no
/// producer and no consumer anywhere, and no task owns connecting it** — the field exists in
/// `RichTextInputEditPolicy` and nothing reads it. Whoever makes the edit policy live (D27's charter,
/// not a Phase-4 family task) owns both the wiring and this test's missing case. `clearCompositionState()` /
/// `setMarkedText(_:selectedRange:)` / `synchronizeAfterExternalChange` are likewise NOT gated by
/// this task (not asked for by the brief's six tests, and the last of those three is host-driven, not
/// a user edit attempt a policy would plausibly block).
///
/// `class`, not `final class` — `BackendContractCases` (Task 22a) is subclassed again by stage 2,
/// which overrides ONLY `makeBackend()`. The only place this file names a concrete backend type is
/// that override, below (R10).
@MainActor
@available(iOS 16.0, *)
class BackendEditPolicyTests: BackendContractCases {
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
    /// 2 of this suite's 6 tests drive `insertText` as the operation the policy gate must reject (the
    /// gate itself lives in `prepareAndRun`, which is exactly what the reference conformer calls); the
    /// other four drive selection/paste/dictation/edit-menu, all forwarded unchanged.
    override func makeBackend() -> (any RichTextInputBackend)? {
        ReferenceMutationBackend()
    }

    /// Test 2 needs delegate notifications to be OBSERVABLE (both the permissive control and the
    /// not-editable absence), so wire the shared `RecordingInputDelegate` directly onto the backend —
    /// same shape `BackendMutationContractTests` uses, for the same reason (canvas plumbing does not
    /// route `inputDelegate` to the backend until Task 26; this suite tests the backend in isolation).
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

    // MARK: - 1. The policy is read AT OPERATION TIME, never cached at attach

    /// The policy is consulted AT OPERATION TIME. A backend that snapshotted it during attach would
    /// still accept this insert, which is exactly the staleness the spec forbids.
    ///
    /// FIX ROUND 1 (task-22i-review.md Minor 5): added a leading control of this test's OWN, rather
    /// than leaning on test 2's — under the default permissive policy, the SAME kind of call commits,
    /// establishing that `editPolicyReadCount` moving is not itself the whole property: the second
    /// assertion (`documentCommit` absent) is what actually shows the fresh read TAKES EFFECT, not
    /// merely that `editPolicy` was read via the mechanism `editPolicyReadCount` instruments.
    ///
    /// RED-CHECK: temporarily made `prepareAndRun` snapshot the policy once, at the top of
    /// `attach(to:)` (`+Attachment.swift`), instead of reading `host.lifecycleClient.editPolicy` fresh
    /// inside `prepareAndRun` (`+Mutation.swift`) — confirmed `XCTAssertGreaterThan(...editPolicyReadCount,
    /// readsAfterAttach)` failed (the count stayed frozen at its attach-time value; `insertText`
    /// silently used the STALE, cached `isEditable == true` and committed anyway, so
    /// `log.contains("documentCommit")` also went true), then reverted.
    func test_editPolicyIsReadAtOperationTime_notCachedAtAttach() {
        // Control (Minor 5, fix round 1): under the default permissive policy, the same kind of call
        // actually commits — this test's own anchor, not test 2's.
        log.reset()
        backend.insertText("control")
        XCTAssertTrue(log.kinds.contains("documentCommit"),
                     "control: insertText must commit under the default permissive policy")

        let readsAfterAttach = fakeHost!.fakeLifecycleClient.editPolicyReadCount
        fakeHost!.fakeLifecycleClient.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: false, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: true)
        log.reset()
        backend.insertText("x")
        XCTAssertGreaterThan(fakeHost!.fakeLifecycleClient.editPolicyReadCount, readsAfterAttach)
        XCTAssertFalse(log.contains("documentCommit"))
    }

    // MARK: - 2. `isEditable` gates the mutation family

    /// VACUITY-TRAP CONTRAST (both directions): the control below proves the SAME `insertText` call
    /// commits and notifies under the default permissive policy — without it, the absence assertions
    /// after the policy flips would hold vacuously against a fixture that never committed/notified
    /// anything at all, for an unrelated reason.
    ///
    /// RED-CHECK: temporarily deleted the new `guard host.lifecycleClient.editPolicy.isEditable else
    /// { … }` guard from `prepareAndRun` (`+Mutation.swift`). Confirmed, at the OBSERVATION POINT
    /// immediately after the second `insertText("b")` call: `log.kinds.contains("documentCommit")`
    /// flipped true, all four `delegate*` assertions flipped true, `backend.state.documentRevision`
    /// no longer equalled `revisionBefore`, and the `.lifecycleReject(reason: "notEditable")` search
    /// found nothing (no rejection was ever reported) — then reverted.
    func test_notEditable_rejectsInsertText_withNotEditable_andNoDelegateNotifications() {
        // Control (permissive): the same operation actually commits and notifies.
        log.reset()
        backend.insertText("a")
        XCTAssertTrue(log.kinds.contains("documentCommit"),
                     "control: insertText must commit under the default permissive policy")
        XCTAssertTrue(log.kinds.contains("delegateTextWillChange"))
        XCTAssertTrue(log.kinds.contains("delegateTextDidChange"))

        fakeHost!.fakeLifecycleClient.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: false, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: true)
        let revisionBefore = backend.state.documentRevision
        log.reset()

        backend.insertText("b")

        XCTAssertFalse(log.kinds.contains("documentCommit"),
                      "a not-editable policy must block the document commit entirely")
        XCTAssertFalse(log.kinds.contains("documentPrepare"),
                      "…and must never reach the document client's prepare step either")
        XCTAssertFalse(log.kinds.contains("delegateTextWillChange"))
        XCTAssertFalse(log.kinds.contains("delegateSelectionWillChange"))
        XCTAssertFalse(log.kinds.contains("delegateSelectionDidChange"))
        XCTAssertFalse(log.kinds.contains("delegateTextDidChange"))
        XCTAssertEqual(backend.state.documentRevision, revisionBefore,
                       "a rejected insert must not move the revision")
        XCTAssertTrue(log.events.contains {
            if case .lifecycleReject(_, let reason) = $0 { return reason == "notEditable" }
            return false
        }, "the rejection must be reported with reason .notEditable; got \(log.kinds)")
    }

    // MARK: - 3. `isEditable` also drives `editPolicyDidChange()`'s own effect

    /// `editPolicyDidChange()` is wired from `DocumentCanvasView.editPolicy`'s `didSet` in production
    /// (Task 20) and is one of only three members production actually calls on the backend today
    /// (with `attach`/`detach`). This pins its ONE effect this task gives it: a transition TO
    /// not-editable dismisses any open edit menu — and, separately, that doing so never detaches the
    /// backend (a plausible but wrong "policy went hostile, tear it all down" overreach).
    ///
    /// VACUITY-TRAP CONTRAST: the control proves a policy change that STAYS editable does NOT dismiss
    /// anything — without it, "dismiss on any `editPolicyDidChange()` call, unconditionally" would
    /// also pass this test.
    ///
    /// RED-CHECK: temporarily changed the `guard !host.lifecycleClient.editPolicy.isEditable else {
    /// return }` in `editPolicyDidChange()` (`+Responder.swift` since Task 31; this citation read
    /// `+PendingRouting.swift` until Task 34 renamed that file and repaired the pointer) to
    /// unconditionally call `dismissEditMenu`. Confirmed the CONTROL assertion (`XCTAssertFalse(...contains("presentationDismissEditMenu"))`)
    /// failed at its OBSERVATION POINT (right after the still-editable policy change), then reverted.
    func test_editPolicyDidChangeToNotEditable_dismissesTheEditMenu_andKeepsTheBackendAttached() {
        // Control: a policy change that stays editable must not dismiss anything.
        log.reset()
        fakeHost!.fakeLifecycleClient.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: true, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: false)
        backend.editPolicyDidChange()
        XCTAssertFalse(log.kinds.contains("presentationDismissEditMenu"),
                      "control: a policy change that stays editable must not dismiss the edit menu")

        log.reset()
        fakeHost!.fakeLifecycleClient.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: false, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: true)

        backend.editPolicyDidChange()

        XCTAssertTrue(log.events.contains {
            if case .presentationDismissEditMenu(let reason) = $0 { return reason == "policyChanged" }
            return false
        }, "a transition to not-editable must dismiss the edit menu with reason .policyChanged; got \(log.kinds)")
        XCTAssertTrue(backend.isAttached, "an edit-policy change must never detach the backend")
    }

    // MARK: - 4. `isSelectable` gates `setSelection(_:reason:)`

    /// VACUITY-TRAP CONTRAST: the control proves the SAME `setSelection` call, under the default
    /// permissive policy, DOES apply and publish — anchoring the post-flip absences against a
    /// fixture that published nothing at all, for an unrelated reason.
    ///
    /// RED-CHECK: temporarily deleted the new `guard lifecycle?.editPolicy.isSelectable ?? true else
    /// { return }` guard from `setSelection` (`LegacyRichTextInputBackend.swift`). Confirmed, at the
    /// OBSERVATION POINT immediately after the second `setSelection` call:
    /// `backend.canonicalSelection` no longer equalled `selectionBefore` (it adopted the new offset
    /// 5), and both `presentationApply`/`lifecyclePublish` appeared in the log — then reverted.
    func test_notSelectable_rejectsSetSelection_andPublishesNothing() {
        // Control (permissive): the same operation actually applies and publishes.
        log.reset()
        backend.setSelection(.caret(at: .downstream(2)), reason: .programmatic)
        XCTAssertEqual(backend.canonicalSelection, .caret(at: .downstream(2)),
                       "control: setSelection must apply under the default permissive policy")
        XCTAssertTrue(log.kinds.contains("presentationApply"))
        XCTAssertTrue(log.kinds.contains("lifecyclePublish"))

        fakeHost!.fakeLifecycleClient.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: true, isSelectable: false, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: true)
        let selectionBefore = backend.canonicalSelection
        log.reset()

        backend.setSelection(.caret(at: .downstream(5)), reason: .programmatic)

        XCTAssertEqual(backend.canonicalSelection, selectionBefore,
                       "a not-selectable policy must block the selection write entirely")
        XCTAssertFalse(log.kinds.contains("presentationApply"),
                      "a blocked selection write must not publish to the presentation client")
        XCTAssertFalse(log.kinds.contains("lifecyclePublish"),
                      "a blocked selection write must not publish to the lifecycle client")
    }

    // MARK: - 5. `allowsPaste` gates `canPerformCommand(.paste, sender:)`

    /// RED-CHECK, RE-RUN after fix round 1's Minor-1 fix (`canPerformCommand`'s `.paste` branch now
    /// also consults `command?.canPerform(.paste, sender:)`, not `allowsPaste` alone — see the
    /// production doc comment): temporarily changed the whole `.paste` branch to unconditionally
    /// `return true`. Confirmed `XCTAssertFalse(backend.canPerformCommand(.paste, sender: nil))`
    /// still failed (observed `true` under `allowsPaste == false`) at the same OBSERVATION POINT
    /// immediately after the second call, then reverted.
    func test_allowsPasteFalse_makesCanPerformPasteFalse() {
        // Control (permissive): paste is allowed under the default policy.
        XCTAssertTrue(backend.canPerformCommand(.paste, sender: nil),
                     "control: paste must be permitted under the default permissive policy")

        fakeHost!.fakeLifecycleClient.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: true, isSelectable: true, allowsRichText: true,
            allowsPaste: false, allowsDictation: true, allowsWritingTools: true)

        XCTAssertFalse(backend.canPerformCommand(.paste, sender: nil),
                      "allowsPaste == false must make canPerformCommand(.paste, sender:) false")
    }

    // MARK: - 6. `allowsDictation` gates `insertDictationResult(_:)`

    /// `insertDictationResult(_:)` is Deviation D15's permanently-unwitnessed member: this body
    /// NEVER reaches the document client or `legacyCanvas`, allowed or not (unlike every other test
    /// in this suite, there is no real content effect this test could show being prevented — the
    /// operation has no effect either way). What IS observable, and what this test pins, is whether a
    /// REJECTION gets reported at all: under the default permissive policy the call is a silent
    /// no-op (matches D15 exactly, unchanged); under `allowsDictation == false` it reports a rejection
    /// through the same `backendDidRejectMutation` channel a real mutation rejection uses — the
    /// contrast this test needs, since "a policy blocks X" requires showing the permissive side does
    /// NOT report the same thing X's absence might otherwise be mistaken for.
    ///
    /// RED-CHECK, RE-RUN (task-22i-review.md Major 4 — the FIRST round's narration was impossible
    /// as written: it claimed the CONTROL's absence-assertion failed while also claiming the control
    /// held, which cannot both be true from deleting a producer): temporarily deleted the whole
    /// `guard host.lifecycleClient.editPolicy.allowsDictation else { … }` block's BODY from
    /// `insertDictationResult(_:)` (`+Unwitnessed.swift`), leaving the member an unconditional
    /// no-op again (its exact pre-Task-22i shape). Rebuilt and ran ONLY this test. The CONTROL
    /// (permissive branch) held exactly as before — it observes an ABSENCE, and an absence stays true
    /// whether or not a producer exists elsewhere in the method. The RESTRICTIVE assertion actually
    /// went red, at the OBSERVATION POINT immediately after the second call:
    /// `XCTAssertTrue(log.events.contains { … reason == "unsupportedOperation" … })` failed with `got
    /// []` — no rejection of any kind was reported. Reverted; rebuilt; reran — green again.
    func test_allowsDictationFalse_rejectsInsertDictationResult() {
        // Control (permissive): dictation stays the pre-existing silent no-op — no rejection at all.
        log.reset()
        backend.insertDictationResult([])
        XCTAssertFalse(log.kinds.contains("lifecycleReject"),
                      "control: dictation must not be rejected while the policy allows it")
        XCTAssertFalse(log.kinds.contains("documentPrepare"),
                      "D15: this member must never reach the document client, allowed or not")

        fakeHost!.fakeLifecycleClient.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: true, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: false, allowsWritingTools: true)
        log.reset()

        backend.insertDictationResult([])

        XCTAssertTrue(log.events.contains {
            if case .lifecycleReject(_, let reason) = $0 { return reason == "unsupportedOperation" }
            return false
        }, "allowsDictation == false must report a rejection with reason .unsupportedOperation " +
           "(task-22i-review.md Major 3 — the disclosed placeholder reason must be pinned, or a " +
           "future swap to any other case would leave this suite green); got \(log.kinds)")
        XCTAssertFalse(log.kinds.contains("documentPrepare"),
                      "D15: still never reaches the document client, even when rejected")
    }
}
#endif

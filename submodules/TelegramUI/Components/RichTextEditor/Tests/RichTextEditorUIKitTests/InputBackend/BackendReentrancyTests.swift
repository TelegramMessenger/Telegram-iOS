#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// A `UITextInputDelegate` whose four notification methods invoke test-supplied probes. Used ONLY by
/// this suite's "read during a notification phase" and "external change requested between prepare and
/// commit" tests, which need to sample backend state (or call back into the backend) from exactly
/// inside `notifyTextWillChange`/`notifySelectionWillChange`/`notifySelectionDidChange`/
/// `notifyTextDidChange` (`LegacyRichTextInputBackend+Mutation.swift`). A test-file-local type, not a
/// Task 22a fixture: adding reentrancy-probe hooks to the shared `RecordingInputDelegate` would give
/// every OTHER contract suite (22b-22f, 22h-22i) unwanted reentrancy-specific complexity it does not
/// need. Not restricted by R10/R11 — those rules cover only `RichTextInputBackend`/`RichTextInputHost`
/// conformers and the two factory-provided fixture hosts (`FakeInputHost`/`IncompatibleFakeHost`); a
/// plain `UITextInputDelegate` spy, like the pre-existing `RecordingInputDelegate`, is out of their
/// scope by design (R11's own doc comment says so explicitly).
@MainActor
@available(iOS 16.0, *)
private final class ProbingInputDelegate: NSObject, UITextInputDelegate {
    var onSelectionWillChange: (() -> Void)?
    var onTextWillChange: (() -> Void)?
    var onSelectionDidChange: (() -> Void)?
    var onTextDidChange: (() -> Void)?

    func selectionWillChange(_ textInput: UITextInput?) { onSelectionWillChange?() }
    func textWillChange(_ textInput: UITextInput?) { onTextWillChange?() }
    func selectionDidChange(_ textInput: UITextInput?) { onSelectionDidChange?() }
    func textDidChange(_ textInput: UITextInput?) { onTextDidChange?() }
    @available(iOS 18.4, *)
    func conversationContext(_ context: UIConversationContext?, didChange textInput: UITextInput?) {}
}

/// Task 22g, the sixth of eight contract suites (22b-22i). Pins the transaction-phase machine's
/// reentrancy rules (spec: "New mutation begins only from `.idle`"; "Mutating reentry from client or
/// facade callbacks is rejected"; "Detach requested during mutation runs at the transaction boundary")
/// and the three-way split this task's implementation makes between them:
///   - a REENTRANT MUTATION (another `insertText`/`deleteBackward` fired from inside an in-flight
///     transaction's own callback) is REJECTED — `LegacyRichTextInputBackend+Mutation.swift`'s
///     `prepareAndRun` chokepoint, this task's one new guard on that path;
///   - a REENTRANT EXTERNAL CHANGE (`synchronizeAfterExternalChange` fired the same way) is DEFERRED,
///     not rejected — stashed in `deferredExternalChange` and drained by `endTransaction()` once the
///     transaction genuinely returns to `.idle`;
///   - a REENTRANT DETACH is LATCHED — this was already Task 20's behavior (`detachRequested`,
///     `+Attachment.swift`); this task adds no new code for it, only the pinning test (the worked
///     example below) plus the "nothing latches when nothing was requested" contrast the class's own
///     brief flags as a required vacuity guard.
///
/// SCOPE, disclosed up front: the reentrant-mutation REJECTION only guards `prepareAndRun` (i.e.
/// `insertText`/`deleteBackward`, and — per that chokepoint's own established role — every future
/// entry point Tasks 27/29 route through it). `setSelection`, `clearCompositionState`, and
/// `setMarkedText` each have their own single-bracket `transactionPhase = .publishingState` …
/// `endTransaction()` shape and are NOT given a matching REJECTION guard here — that member-level
/// fix is Task 26/29/41's, per the normative note on `endTransaction()`
/// (`LegacyRichTextInputBackend+Attachment.swift`), which is the ONE place this is recorded (do not
/// restate it here or at any of the three members). What FIX ROUND 1 of this task DOES own, because
/// the guard being defeated was the guard 22g shipped: making the SHARED bracket-exit
/// (`endTransaction()`) nesting-aware, so a nested (unrejected) call to one of those three cannot end
/// an OUTER transaction early — see the nested-reentrancy tests below.
///
/// `class`, not `final class` — Task 22a's `BackendContractCases` is subclassed again by stage 2,
/// which overrides ONLY `makeBackend()`. The only place this file names a concrete backend type is
/// that override, below.
@MainActor
@available(iOS 16.0, *)
class BackendReentrancyTests: BackendContractCases {
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
    /// 12 of this suite's 15 tests drive `insertText` to open the transaction they then re-enter; the
    /// other three (nested `setSelection`, the `preserveIfRebasable` rebase callout, the re-stashed
    /// external change) run against the forwarded legacy members unchanged. Splitting them out was
    /// considered and rejected: a delegating conformer leaves them byte-identical, so a split would
    /// buy nothing and cost a ninth inherited suite.
    override func makeBackend() -> (any RichTextInputBackend)? {
        ReferenceMutationBackend()
    }

    // MARK: - 1. The worked example: a detach requested mid-mutation latches to the boundary

    /// `detach()` during a mutation LATCHES and drains at `endTransaction()`. A detach that ran
    /// immediately would interleave teardown into the middle of the log.
    ///
    /// Includes the REQUIRED negative contrast the task brief's own vacuity-trap note calls out for
    /// this exact assertion shape ("'the latch drains' is vacuous if the drain is unconditional, so
    /// pin a case where nothing drains"): the preamble below runs an ORDINARY mutation with no detach
    /// requested and asserts NEITHER teardown event appears, before the worked example's positive
    /// case.
    ///
    /// FIX ROUND 1 (review CRITICAL) — REWORKED HOOK SITE, was `onDidPublishState`. What went wrong in
    /// the original check: `FakeInputLifecycleClient.backendDidPublishState` (`Fakes/FakeInputLifecycleClient.swift`)
    /// records `.lifecyclePublish` and ONLY THEN invokes `onDidPublishState` — and nothing in the
    /// outer bracket logs anything AFTER that call returns (`publishState` ends there; `endTransaction()`
    /// itself logs nothing). So under the ORIGINAL named mutation (`detach()` running
    /// `performDetachSteps()` unconditionally instead of latching), the reentrant teardown fired
    /// strictly AFTER `documentCommit`/`presentationApply`/`lifecyclePublish` were already in the log —
    /// producing a log BYTE-IDENTICAL to the correctly-latched world
    /// (`documentPrepare, documentCommit, presentationApply, lifecyclePublish, presentationTearDown,
    /// lifecycleWillDetach` either way). All four assertions held in both worlds; the report's
    /// "confirmed red" was not reproducible — the check was hooked at a point with no outer log events
    /// still to come, so a plausible verification pass silently observed nothing.
    ///
    /// Fixed by hooking `onApply` instead — `FakeInputPresentationClient.apply(_:)` fires it BEFORE
    /// `lifecyclePublish` is ever logged (`publishState` calls `presentationClient.apply(...)` first).
    /// Now the two worlds genuinely diverge: correctly-latched gives `presentationApply, lifecyclePublish,
    /// presentationTearDown, lifecycleWillDetach`; an immediate (wrong) detach gives `presentationApply,
    /// presentationTearDown, lifecycleWillDetach, lifecyclePublish` — `publishState`'s local `host`
    /// constant (bound before the callout) keeps the OUTER `backendDidPublishState` call reachable even
    /// after the immediate detach nils `self.host`, so the outer publish is delivered, just LATE.
    ///
    /// RED IF: `detach()`'s `guard transactionPhase == .idle else { detachRequested = true; return }`
    /// (`+Attachment.swift`) were deleted (i.e. `detach()` ran `performDetachSteps()` immediately,
    /// unconditionally). Confirmed red against exactly that mutation with THIS hook site — both
    /// `log.kinds.last` (became `"lifecyclePublish"` instead of `"lifecycleWillDetach"`) and
    /// `lastMutationEvent < presentationTearDown` (flipped, since the late-delivered outer
    /// `lifecyclePublish` now sits AFTER `presentationTearDown`) went red — then reverted.
    func test_detachDuringMutation_runsAtTheTransactionBoundary() {
        // Contrast half — nothing drains for an ordinary mutation with no detach requested.
        backend.insertText("a")
        XCTAssertFalse(log.contains("presentationTearDown"), "nothing should drain when nothing was requested")
        XCTAssertFalse(log.contains("lifecycleWillDetach"), "nothing should drain when nothing was requested")
        log.reset()

        let backendUnderTest = backend
        fakeHost!.fakePresentationClient.onApply = { [weak backendUnderTest] in
            backendUnderTest?.detach()
        }
        backend.insertText("x")
        let lastMutationEvent = [log.index(of: "documentCommit"),
                                 log.index(of: "presentationApply"),
                                 log.index(of: "lifecyclePublish")].compactMap { $0 }.max()!
        XCTAssertLessThan(lastMutationEvent, log.index(of: "presentationTearDown")!)
        XCTAssertEqual(log.kinds.last, "lifecycleWillDetach")
        XCTAssertFalse(backend.isAttached)
        XCTAssertFalse(log.contains("contractViolation"), "a well-ordered reentrant detach is not caller misuse")
    }

    // MARK: - 2. A reentrant mutation from the lifecycle client's publish callback is rejected

    /// The realistic reentrancy path the spec calls out: a facade/client callback fired from
    /// `publishState` (here, `backendDidPublishState`) calls back into `insertText` while the OUTER
    /// `insertText` is still mid-transaction (`transactionPhase == .publishingState`). The reentrant
    /// call must never reach the document client at all — proven by the prepare/commit COUNTS staying
    /// at exactly one, not two.
    ///
    /// Pins the REQUIRED contrast (task brief: "a 'reentrant call is rejected' assertion is vacuous
    /// unless a non-reentrant call on the same path is shown to succeed"): a SECOND, ordinary
    /// (non-reentrant) `insertText` immediately afterward succeeds normally — proving the outer
    /// transaction genuinely completed (returned to `.idle`) rather than the backend being left wedged
    /// or silently rejecting everything from then on.
    ///
    /// RED IF: `prepareAndRun`'s `guard transactionPhase == .idle else { report; return }`
    /// (`+Mutation.swift`) were deleted — the reentrant `insertText("y")` would run its own full
    /// prepare/notify/commit/publish bracket, so `log.count("documentPrepare")` would read 2 instead
    /// of 1 (and, absent the `reentered` guard in this test's own hook, would recurse without bound,
    /// since each nested publish re-fires `onDidPublishState`). Confirmed red against exactly that
    /// mutation, then reverted.
    func test_mutatingReentryFromDidPublishState_isRejected_andTheOuterTransactionCompletes() {
        var reentered = false
        let backendUnderTest = backend
        fakeHost!.fakeLifecycleClient.onDidPublishState = { [weak backendUnderTest] _, _ in
            guard !reentered else { return }
            reentered = true
            backendUnderTest?.insertText("y")
        }

        backend.insertText("x")

        XCTAssertEqual(log.count("documentPrepare"), 1,
                       "the reentrant insertText must never reach prepareMutation")
        XCTAssertEqual(log.count("documentCommit"), 1)
        XCTAssertTrue(log.contains("contractViolation"), "the reentrant attempt must be reported")

        // Contrast: the outer transaction genuinely completed — a fresh, non-reentrant mutation
        // succeeds normally afterward.
        log.reset()
        backend.insertText("z")
        XCTAssertEqual(log.count("documentPrepare"), 1)
        XCTAssertEqual(log.count("documentCommit"), 1)
        XCTAssertFalse(log.contains("contractViolation"))
    }

    // MARK: - 3. A reentrant mutation from the presentation client's apply callback is rejected

    /// The SAME guard, exercised from a DIFFERENT callback site — `presentationClient.apply(...)` runs
    /// BEFORE `lifecycleClient.backendDidPublishState(...)` inside `publishState`
    /// (`LegacyRichTextInputBackend.swift`), so this fires earlier in the bracket than test 2's hook.
    /// Proves the guard keys on the SHARED `transactionPhase`, not on which specific client happened
    /// to call back.
    ///
    /// Same contrast requirement as test 2: a non-reentrant mutation succeeds afterward.
    ///
    /// RED IF: the SAME `prepareAndRun` guard were deleted — `log.count("documentPrepare")` would read
    /// 2 instead of 1 for the exact same reason as test 2. Confirmed red against exactly that
    /// mutation, then reverted.
    func test_mutatingReentryFromPresentationApply_isRejected() {
        var reentered = false
        let backendUnderTest = backend
        fakeHost!.fakePresentationClient.onApply = { [weak backendUnderTest] in
            guard !reentered else { return }
            reentered = true
            backendUnderTest?.insertText("y")
        }

        backend.insertText("x")

        XCTAssertEqual(log.count("documentPrepare"), 1,
                       "the reentrant insertText must never reach prepareMutation")
        XCTAssertEqual(log.count("documentCommit"), 1)
        XCTAssertTrue(log.contains("contractViolation"), "the reentrant attempt must be reported")

        log.reset()
        backend.insertText("z")
        XCTAssertEqual(log.count("documentPrepare"), 1)
        XCTAssertEqual(log.count("documentCommit"), 1)
        XCTAssertFalse(log.contains("contractViolation"))
    }

    // MARK: - 4. A read during `.notifyingWillChange` observes the BEFORE state

    /// Spec: "Read queries during notification phases observe the documented before or after state for
    /// that phase." `notifySelectionWillChange`/`notifyTextWillChange` fire BEFORE
    /// `document.commitPreparedMutation` runs (`runMutation`, `+Mutation.swift`), so a read from inside
    /// either must still see the PRE-mutation revision/selection.
    ///
    /// Pins the REQUIRED contrast (a same-value read is not evidence of anything): the mutation's own
    /// commit DOES move both the revision and the selection forward, proving the will-change read
    /// wasn't merely coincidentally equal to a value that never changes.
    ///
    /// RED IF `documentRevision`/`canonicalSelectionStorage` were adopted BEFORE
    /// `transactionPhase = .notifyingWillChange`'s notifications instead of after (i.e. `runMutation`
    /// applied `result.revision`/`result.selection` immediately after `prepareMutation` returned
    /// `.ready`, ahead of the will-change notifications) — the observed values below would equal the
    /// AFTER state instead of the before state. Confirmed red against exactly that reordering, then
    /// reverted.
    func test_readDuringNotifyingWillChange_observesTheBeforeState() {
        let delegate = ProbingInputDelegate()
        backend.inputDelegate = delegate
        let beforeRevision = backend.state.documentRevision
        let beforeSelection = backend.canonicalSelection
        fakeHost!.fakeDocumentClient.commitSelection = RichTextCanonicalSelection.caret(at: .downstream(5))

        let backendUnderTest = backend
        var observedRevision: UInt64?
        var observedSelection: RichTextCanonicalSelection?
        delegate.onSelectionWillChange = {
            observedRevision = backendUnderTest.state.documentRevision
            observedSelection = backendUnderTest.canonicalSelection
        }

        backend.insertText("x")

        XCTAssertEqual(observedRevision, beforeRevision,
                       "the will-change notification must observe the state BEFORE the commit lands")
        XCTAssertEqual(observedSelection, beforeSelection)
        // Contrast: the commit genuinely moved both forward afterward.
        XCTAssertNotEqual(backend.state.documentRevision, beforeRevision)
        XCTAssertNotEqual(backend.canonicalSelection, beforeSelection)
    }

    // MARK: - 5. A read during `.notifyingDidChange` observes the AFTER state

    /// The contrasting half of test 4's same rule: `notifySelectionDidChange`/`notifyTextDidChange`
    /// fire AFTER `documentRevision`/`canonicalSelectionStorage`/`markedRangeStorage` adopt the
    /// commit's result (`runMutation`), so a read from inside either must see the POST-mutation state.
    ///
    /// FIX ROUND 1 (review Minor 7): now checks REVISION as well as selection, symmetric with test 4
    /// (which checked both) — the original only checked selection.
    ///
    /// FIX ROUND 2 (review Minor 7, follow-up): the revision assertion originally compared against
    /// `beforeRevision + 1` — encoding "exactly one increment per logical mutation", precisely the
    /// assumption **D31** disclaims (revision is "strictly increasing per content mutation", never
    /// "exactly one"). It was true only because `FakeInputDocumentClient.commitPreparedMutation` does
    /// `revision += 1`, which is the FAKE's own arithmetic, not a contract this suite should encode.
    /// Fixed to compare against `fakeHost!.fakeDocumentClient.revision` — the document client's own
    /// live revision after the commit — which is true regardless of how many times a real client's
    /// commit increments it.
    ///
    /// RED IF `documentRevision`/`canonicalSelectionStorage` were adopted AFTER
    /// `transactionPhase = .notifyingDidChange`'s notifications instead of before (i.e. `runMutation`
    /// deferred applying `result.revision`/`result.selection` until after the did-change notifications)
    /// — the observed selection AND revision below would equal the BEFORE state instead of the after
    /// state. Confirmed red against exactly that reordering, then reverted.
    func test_readDuringNotifyingDidChange_observesTheAfterState() {
        let delegate = ProbingInputDelegate()
        backend.inputDelegate = delegate
        let beforeRevision = backend.state.documentRevision
        let beforeSelection = backend.canonicalSelection
        let expectedAfterSelection = RichTextCanonicalSelection.caret(at: .downstream(7))
        fakeHost!.fakeDocumentClient.commitSelection = expectedAfterSelection

        let backendUnderTest = backend
        var observedRevision: UInt64?
        var observedSelection: RichTextCanonicalSelection?
        delegate.onSelectionDidChange = {
            observedRevision = backendUnderTest.state.documentRevision
            observedSelection = backendUnderTest.canonicalSelection
        }

        backend.insertText("y")

        XCTAssertEqual(observedRevision, fakeHost!.fakeDocumentClient.revision,
                       "the did-change notification must observe the REVISION after the commit " +
                       "lands too — compared against the document client's own live revision, not " +
                       "`beforeRevision + 1` (which would encode the single-increment-per-mutation " +
                       "assumption D31 explicitly disclaims)")
        XCTAssertEqual(observedSelection, expectedAfterSelection,
                       "the did-change notification must observe the state AFTER the commit lands")
        XCTAssertNotEqual(observedSelection, beforeSelection,
                          "contrast: proves the read is genuinely post-commit, not coincidentally " +
                          "equal to the pre-mutation value")
        XCTAssertNotEqual(observedRevision, beforeRevision)
    }

    // MARK: - 6. An external change requested between prepare and commit is deferred to idle

    /// Spec: "No callback between preparation and commit may publish an external document change.
    /// Such a request is deferred until the transaction returns to `.idle`." `notifySelectionWillChange`
    /// fires exactly in that window — after `document.prepareMutation` returned `.ready` (preparation),
    /// before `document.commitPreparedMutation` runs (commit). A `synchronizeAfterExternalChange` call
    /// from inside it must not apply immediately (checked via a mid-callback read), but must be applied
    /// once `insertText`'s own transaction reaches `endTransaction()` and returns to `.idle`.
    ///
    /// The change's `oldRevision` is set to the revision `insertText`'s OWN commit will land on (not
    /// the revision at the moment the external change arrives) so that the DRAIN-time continuity check
    /// cleanly succeeds, giving this test a clean "applied once idle" positive outcome.
    ///
    /// FIX ROUND 1 (review Major 1) — ADDED DISCRIMINATING ASSERTION. The report's original claim that
    /// `observedRevisionAtRequestTime == baseRevision` proves deferral was WRONG: with this test's
    /// `oldRevision` choice (`baseRevision + 1`), an IMMEDIATELY-processed (non-deferred) call would
    /// ALSO leave `documentRevision` at `baseRevision` — not because it was deferred, but because the
    /// continuity check (`change.oldRevision == documentRevision`, i.e. `baseRevision + 1 == baseRevision`)
    /// REJECTS it outright at request time. That assertion is inert for mutation 1 specifically; the
    /// test as a whole was still non-vacuous only because its LATER assertions (the final revision/
    /// selection pair, and the final `contractViolation` check) happen to catch the same mutation for a
    /// DIFFERENT reason (an immediately-rejected call reports a violation right away, which the
    /// overall-log check at the end would have caught regardless of the request-time read). Fixed by
    /// ALSO checking the contract-violation COUNT at the exact request-time moment: an immediately-
    /// processed call fails continuity SYNCHRONOUSLY (right there, inside the hook), so its violation
    /// count would already be 1 at that point; a correctly-deferred call reports nothing yet (0),
    /// since nothing has been evaluated at all — this is the assertion that actually discriminates
    /// deferral from immediate-rejection, at the exact place the report claimed one did.
    ///
    /// See the SIBLING test below (`test_deferredExternalChangeThatBecomesStaleByDrainTime_isRejectedWithAContinuityViolation`)
    /// for the review's OTHER suggested fix — a request-time-VALID change (`oldRevision == baseRevision`)
    /// where immediate processing would SUCCEED (discriminating via the revision read directly) and
    /// correct deferral makes it genuinely stale by drain time (discriminating via a reported
    /// violation instead of a silent drop).
    ///
    /// RED IF: `synchronizeAfterExternalChange`'s `guard transactionPhase == .idle else {
    /// deferredExternalChange = change; return }` (`LegacyRichTextInputBackend.swift`) were deleted —
    /// the call from inside `onSelectionWillChange` would run immediately, hit the continuity guard
    /// synchronously, and report a violation THERE — so `observedViolationCountAtRequestTime` would
    /// read 1 instead of 0. RED IF `endTransaction()`'s drain (`+Attachment.swift`) were deleted
    /// instead — the deferred change would never apply at all, so the final assertions below would see
    /// `insertText`'s own revision/selection, not the external change's. Confirmed red against each
    /// mutation independently, then reverted.
    func test_externalChangeRequestedBetweenPrepareAndCommit_isDeferredToIdle() {
        let delegate = ProbingInputDelegate()
        backend.inputDelegate = delegate
        let baseRevision = fakeHost!.fakeDocumentClient.revision
        let change = RichTextInputExternalChange(
            oldRevision: baseRevision + 1, newRevision: baseRevision + 6, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: .downstream(42)), markedTextPolicy: .discard)

        var observedRevisionAtRequestTime: UInt64?
        var observedViolationCountAtRequestTime: Int?
        var reentered = false
        let backendUnderTest = backend
        delegate.onSelectionWillChange = { [weak backendUnderTest] in
            guard !reentered else { return }
            reentered = true
            backendUnderTest?.synchronizeAfterExternalChange(change)
            observedRevisionAtRequestTime = backendUnderTest?.state.documentRevision
            observedViolationCountAtRequestTime = self.log.count("contractViolation")
        }

        backend.insertText("x")

        XCTAssertEqual(observedRevisionAtRequestTime, baseRevision,
                       "an external change requested between prepare and commit must not apply " +
                       "immediately — the in-flight mutation has not committed yet")
        XCTAssertEqual(observedViolationCountAtRequestTime, 0,
                       "the GENUINELY discriminating check: an immediately-processed (non-deferred) " +
                       "call would fail this change's continuity check SYNCHRONOUSLY and report a " +
                       "violation right here — its absence is what proves deferral, not the revision " +
                       "read above (which is inert for this specific change, see this test's own doc " +
                       "comment)")
        XCTAssertEqual(backend.state.documentRevision, baseRevision + 6,
                       "the deferred external change is applied once the transaction returns to .idle")
        XCTAssertEqual(backend.canonicalSelection, change.selection)
        XCTAssertFalse(log.contains("contractViolation"), "a correctly-deferred change must not be treated as caller misuse")
    }

    // MARK: - 6b. FIX ROUND 1 (review Major 1's second, request-time-valid variant)

    /// The review's own suggested companion to test 6: a change whose `oldRevision` is valid AT
    /// REQUEST TIME (`== baseRevision`) rather than at drain time. This flips which half of the test
    /// discriminates: an IMMEDIATELY-processed call would now SUCCEED (continuity holds against the
    /// pre-commit revision) and apply right there, so the mid-callback revision read directly shows
    /// the wrong-world outcome; correctly DEFERRED, the change is not evaluated until `insertText`'s
    /// own commit has already moved `documentRevision` to `baseRevision + 1` — one past what this
    /// change's `oldRevision` describes — so it is LEGITIMATELY stale by the time it is finally
    /// drained, and is rejected with a reported continuity violation rather than silently applied or
    /// silently dropped.
    ///
    /// RED IF: the SAME defer guard were deleted — the mid-callback read would show
    /// `baseRevision + 6` (applied immediately) instead of `baseRevision` (not yet applied). Confirmed
    /// red against exactly that mutation, then reverted.
    func test_deferredExternalChangeThatBecomesStaleByDrainTime_isRejectedWithAContinuityViolation() {
        let delegate = ProbingInputDelegate()
        backend.inputDelegate = delegate
        let baseRevision = fakeHost!.fakeDocumentClient.revision
        let change = RichTextInputExternalChange(
            oldRevision: baseRevision, newRevision: baseRevision + 6, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: .downstream(42)), markedTextPolicy: .discard)

        var observedRevisionAtRequestTime: UInt64?
        var reentered = false
        let backendUnderTest = backend
        delegate.onSelectionWillChange = { [weak backendUnderTest] in
            guard !reentered else { return }
            reentered = true
            backendUnderTest?.synchronizeAfterExternalChange(change)
            observedRevisionAtRequestTime = backendUnderTest?.state.documentRevision
        }

        backend.insertText("x")

        XCTAssertEqual(observedRevisionAtRequestTime, baseRevision,
                       "an immediately-processed call would have applied by now (this change's " +
                       "oldRevision is valid AT REQUEST TIME) — its absence directly proves deferral")
        XCTAssertEqual(backend.state.documentRevision, baseRevision + 1,
                       "insertText's OWN commit is the only thing that moved the revision — the " +
                       "external change is now stale relative to it and must not have applied")
        XCTAssertNotEqual(backend.canonicalSelection, change.selection,
                          "the stale change's selection must not have been adopted either")
        XCTAssertTrue(log.contains("contractViolation"),
                     "a change that becomes stale between being deferred and being drained is " +
                     "REJECTED at drain time, not silently dropped")
    }

    // MARK: - 7. FIX ROUND 1 (review Focal Point 3 / Minor 6): pin 22f's own unpinned claim

    /// When `LegacyRichTextInputBackend.swift`'s `.publishingState` label resolution note was written,
    /// it argued the label but left 22f's own testable claim unpinned — "a reentrant `detach()` from
    /// inside `rebase` still latches correctly." `FakeInputDocumentClient.onRebase` (Task 22f) exists
    /// precisely so this call site can be probed reentrantly.
    ///
    /// RED IF: `detach()`'s idle-guard were deleted (same production mutation as test 1, exercised from
    /// a DIFFERENT call site — inside `synchronizeAfterExternalChange`'s nested `rebase` callout rather
    /// than `runMutation`'s publish) — teardown would run immediately, mid-`.preserveIfRebasable`
    /// reconciliation, before this transaction's own `.externalSynchronization` publish, so
    /// `log.index(of: "lifecyclePublish")` would no longer be less than `presentationTearDown`'s index.
    /// Confirmed red against exactly that mutation, then reverted.
    func test_detachFromInsideAPreserveIfRebasableRebaseCallout_stillLatchesToTheBoundary() {
        backend.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        let backendUnderTest = backend
        var reentered = false
        fakeHost!.fakeDocumentClient.onRebase = { [weak backendUnderTest] in
            guard !reentered else { return }
            reentered = true
            backendUnderTest?.detach()
        }
        let old = fakeHost!.fakeDocumentClient.revision
        fakeHost!.fakeDocumentClient.revision = old + 1
        log.reset()

        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: backend.canonicalSelection, markedTextPolicy: .preserveIfRebasable))

        guard let publishIndex = log.index(of: "lifecyclePublish"),
              let tearDownIndex = log.index(of: "presentationTearDown") else {
            XCTFail("expected both a publish and a teardown event; got \(log.kinds) — an IMMEDIATE " +
                   "(non-latching) detach here drops the publish silently instead (self.host is nil'd " +
                   "before synchronizeAfterExternalChange reaches publishState's own `guard let host`)")
            return
        }
        XCTAssertLessThan(publishIndex, tearDownIndex,
                          "a detach requested from inside the rebase callout must not tear down " +
                          "before this transaction's own publish is delivered")
        XCTAssertEqual(log.kinds.last, "lifecycleWillDetach")
        XCTAssertFalse(backend.isAttached)
    }

    // MARK: - 8. FIX ROUND 1 (review Minor 3): a deferred change drains BEFORE a latched detach

    /// `endTransaction()` drains a deferred external change BEFORE checking `detachRequested` —
    /// reasoned in that method's own doc comment as "the friendlier choice" (applying a change the
    /// caller was told would eventually land, rather than silently dropping it because a detach raced
    /// it), but left unpinned before this fix round.
    func test_deferredExternalChangeDrainsBeforeALatchedDetach_soItIsAppliedNotDropped() {
        let backendUnderTest = backend
        let old = fakeHost!.fakeDocumentClient.revision
        let change = RichTextInputExternalChange(
            oldRevision: old + 1, newRevision: old + 9, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: .downstream(11)), markedTextPolicy: .discard)
        var fired = false
        fakeHost!.fakePresentationClient.onApply = { [weak backendUnderTest] in
            guard !fired else { return }
            fired = true
            backendUnderTest?.detach()
            backendUnderTest?.synchronizeAfterExternalChange(change)
        }

        backend.insertText("x")

        XCTAssertFalse(backend.isAttached)
        let externalPublishIndex = log.events.firstIndex { event in
            if case .lifecyclePublish(_, let reason) = event { return reason == "externalSynchronization" }
            return false
        }
        guard let externalPublishIndex, let tearDownIndex = log.index(of: "presentationTearDown") else {
            XCTFail("expected both the deferred change's own publish and a teardown event; got " +
                   "\(log.kinds) — the deferred change must actually be applied and published, not " +
                   "silently dropped by a detach that raced it")
            return
        }
        XCTAssertLessThan(externalPublishIndex, tearDownIndex,
                          "the deferred external change is drained BEFORE the latched detach tears down")
        XCTAssertEqual(backend.state.documentRevision, old + 9)
    }

    // MARK: - 9/10/11. FIX ROUND 1 (review Major 2): nesting-awareness of the shared bracket exit
    //
    // Three tests the review lists as writable today with the fakes this task already has. Each
    // exercises a NESTED single-bracket member (`setSelection`, unguarded by design — see this file's
    // own SCOPE paragraph) fired from `onApply`, i.e. from INSIDE an outer `insertText`'s own
    // `publishState` call, and checks that the nested call's `endTransaction()` does not corrupt the
    // OUTER transaction.

    /// Consequence 1 (review): a nested `setSelection` fired from the SAME callback that already
    /// latched a detach must not let ITS OWN `endTransaction()` drain that latch early — only the
    /// OUTERMOST bracket's `endTransaction()` may do that.
    ///
    /// RED IF: `endTransaction()`'s `activeTransactionDepth` nesting guard (`+Attachment.swift`) were
    /// removed (i.e. every `endTransaction()` call unconditionally does the real work) — the nested
    /// `setSelection`'s own `endTransaction()` would drain the latch immediately, mid-bracket, so the
    /// OUTER's own (still-pending) `lifecyclePublish` would be delivered AFTER `presentationTearDown`/
    /// `lifecycleWillDetach` instead of before, and `log.kinds.last` would read `"lifecyclePublish"`
    /// instead of `"lifecycleWillDetach"`. Confirmed red against exactly that mutation, then reverted.
    func test_nestedSetSelectionAfterALatchedDetach_doesNotEndTheOuterTransactionEarly() {
        var fired = false
        let backendUnderTest = backend
        fakeHost!.fakePresentationClient.onApply = { [weak backendUnderTest] in
            guard !fired else { return }
            fired = true
            backendUnderTest?.detach()
            backendUnderTest?.setSelection(.caret(at: .downstream(3)), reason: .programmatic)
        }

        backend.insertText("x")

        let lastPublishIndex = log.kinds.lastIndex(of: "lifecyclePublish")!
        XCTAssertLessThan(lastPublishIndex, log.index(of: "presentationTearDown")!,
                          "the OUTER transaction's own publish must be delivered before teardown, not " +
                          "after — a nested endTransaction() draining the latch early delivers it late")
        XCTAssertEqual(log.kinds.last, "lifecycleWillDetach")
    }

    /// FIX ROUND 2 (review Minor 3): of the six `activeTransactionDepth` bump sites, only
    /// `setSelection` was exercised as a NESTED caller before this round (the three tests above/below).
    /// This re-runs the SAME shape as the test above through a DIFFERENT bracket
    /// (`clearCompositionState`) — proving the nesting-awareness fix is a property of
    /// `endTransaction()`/`withTransaction(_:)` (shared machinery), not something that happens to work
    /// for `setSelection` alone.
    ///
    /// DISCLOSED, not silently left: the remaining two bump sites — `setMarkedText` and the
    /// `suppressesSelectionNotifications` didSet flush — are STILL unexercised as nested callers.
    /// **TASK 29 CORRECTION**: this said `setMarkedText`'s real forward was Task 29's and would be the
    /// point a realistic nested-caller shape first exists for it. That forward landed and it is a
    /// PLAIN `legacyCanvas` forward that opens no bracket at all, so the member is no longer a bump
    /// site on this class — the bracket (and its `guard transactionPhase == .idle`) moved to
    /// `ReferenceMutationBackend`, which is what this suite now drives. A realistic nested-caller shape
    /// for it therefore first exists at Task 41, when composition state moves.
    /// The didSet flush has no real caller AT ALL until Task
    /// 26 wires an actual canvas gesture through `suppressesSelectionNotifications`
    /// (`LegacyRichTextInputBackend.swift`'s own doc comment on that property already says so) — there
    /// is no realistic nested-caller shape to test before that lands.
    ///
    /// RED IF: the SAME `endTransaction()` nesting mutation as the test above. Confirmed red against
    /// exactly that mutation, then reverted.
    func test_nestedClearCompositionStateAfterALatchedDetach_doesNotEndTheOuterTransactionEarly() {
        var fired = false
        let backendUnderTest = backend
        fakeHost!.fakePresentationClient.onApply = { [weak backendUnderTest] in
            guard !fired else { return }
            fired = true
            backendUnderTest?.detach()
            backendUnderTest?.clearCompositionState()
        }

        backend.insertText("x")

        let lastPublishIndex = log.kinds.lastIndex(of: "lifecyclePublish")!
        XCTAssertLessThan(lastPublishIndex, log.index(of: "presentationTearDown")!,
                          "the OUTER transaction's own publish must be delivered before teardown, not " +
                          "after — a nested endTransaction() draining the latch early delivers it late")
        XCTAssertEqual(log.kinds.last, "lifecycleWillDetach")
    }

    /// Consequence 2 (review): a nested `setSelection`'s `endTransaction()` must not return
    /// `transactionPhase` to `.idle` for the REST of the outer bracket — otherwise a LATER callback
    /// (here, the outer's own `backendDidPublishState`, gated on `reason == .content` so it does not
    /// fire on the nested selection's OWN publish) would see `.idle` and wrongly ACCEPT a reentrant
    /// `insertText`, defeating `prepareAndRun`'s guard entirely.
    ///
    /// RED IF: the SAME nesting guard were removed — the nested `setSelection`'s `endTransaction()`
    /// would reset `transactionPhase` to `.idle` immediately; by the time the outer's own
    /// `backendDidPublishState(.content)` fires and this hook's reentrant `insertText("y")` runs,
    /// `prepareAndRun`'s guard would see `.idle` and ACCEPT it, running a full second prepare/commit —
    /// `log.count("documentPrepare")` would read 2 instead of 1. Confirmed red against exactly that
    /// mutation, then reverted.
    func test_nestedSetSelection_doesNotDefeatTheMutatingReentryGuardForTheOuterBracket() {
        var firedApply = false
        var firedReentrantInsert = false
        let backendUnderTest = backend
        fakeHost!.fakePresentationClient.onApply = { [weak backendUnderTest] in
            guard !firedApply else { return }
            firedApply = true
            backendUnderTest?.setSelection(.caret(at: .downstream(3)), reason: .programmatic)
        }
        fakeHost!.fakeLifecycleClient.onDidPublishState = { [weak backendUnderTest] _, reason in
            guard case .content = reason, !firedReentrantInsert else { return }
            firedReentrantInsert = true
            backendUnderTest?.insertText("y")
        }

        backend.insertText("x")

        XCTAssertEqual(log.count("documentPrepare"), 1,
                       "a nested setSelection must not return transactionPhase to .idle for the REST " +
                       "of the outer bracket — otherwise the outer bracket's OWN publish callback " +
                       "would see .idle and wrongly accept a reentrant insertText")
        // FIX ROUND 2 (review Minor 5(b)): the count staying at 1 is consistent with the reentrant
        // insertText being REJECTED, but also with it merely never having been ATTEMPTED — this proves
        // it was attempted and rejected (transactionPhase was still non-idle when
        // prepareAndRun's guard ran), not that the outer bracket's callback silently never fired.
        XCTAssertTrue(log.contains("contractViolation"),
                     "the reentrant insertText must be REJECTED (and reported), not merely absent")
    }

    // MARK: - 11b. TASK 26: member-level reentrancy for setSelection/clearCompositionState/setMarkedText

    /// TASK 26 ADDITION (the gap `endTransaction()`'s own doc comment, `+Attachment.swift`, assigns to
    /// this task: "member-level reentrancy REJECTION for `setSelection`/`clearCompositionState`/
    /// `setMarkedText` themselves"). The shape is the one the review recommended verbatim: "a per-member
    /// entry guard that performs the storage write and skips the bracket … letting the outer bracket's
    /// publish carry the state". So a nested call is now observable ONLY through the outer publish —
    /// it contributes no `presentationApply`/`lifecyclePublish` of its own.
    ///
    /// Deliberately NOT a hard rejection that also drops the write: the sibling test
    /// `test_nestedSetSelection_publishesTheFreshStateNotAStaleSnapshot` pins that the NESTED value
    /// wins, and a client adjusting the selection from a publish callback is a legitimate pattern, not
    /// caller misuse (which is also why this guard is silent rather than reporting a
    /// `RichTextInputContractViolation`, unlike the reentrant-MUTATION guard in `prepareAndRun`).
    ///
    /// RED IF: the `guard transactionPhase == .idle else { return }` line were removed from
    /// `setSelection` — the nested call would open its own bracket and publish, so the run would record
    /// TWO `lifecyclePublish` events instead of one. Confirmed red against exactly that removal
    /// ("2" is not equal to "1"), then reverted.
    func test_nestedSetSelection_writesItsStorageButOpensNoBracketOfItsOwn() {
        let s2 = RichTextCanonicalSelection.caret(at: .downstream(9))
        var fired = false
        let backendUnderTest = backend
        fakeHost!.fakeLifecycleClient.onDidPublishState = { [weak backendUnderTest] _, _ in
            guard !fired else { return }
            fired = true
            backendUnderTest?.setSelection(s2, reason: .programmatic)
        }

        backend.setSelection(.caret(at: .downstream(2)), reason: .programmatic)

        XCTAssertTrue(fired, "control: the nested call must actually have been made")
        XCTAssertEqual(log.count("lifecyclePublish"), 1,
                       "the nested setSelection must skip its own bracket — only the OUTER transaction " +
                       "publishes")
        XCTAssertEqual(log.count("presentationApply"), 1)
        XCTAssertEqual(backend.canonicalSelection, s2,
                       "…but its STORAGE WRITE still happened: the nested value is what the backend " +
                       "ends up holding, exactly as the recommended shape requires")
    }

    /// Consequence 3 (review): `publishState` captures its snapshot BEFORE the presentation-client
    /// callout that can trigger a nested `setSelection`. Fixed by having `publishState` re-read `state`
    /// fresh immediately before the lifecycle-client delivery (not the presentation-client delivery,
    /// which already ran before any nested call could exist) — see that method's own doc comment. This
    /// is a fix to shared machinery, not a member-level reentrancy guard: it does not reject anything.
    ///
    /// TASK 26 CORRECTION — the ORIGINAL mechanism sentence here is now FALSE and has been removed. It
    /// said "a nested `setSelection(S2)` publishes S2 fully and the OUTER's own (pre-nested, now-stale)
    /// publish still lands afterward", and, below, "the OUTER transaction's own publish is delivered
    /// AFTER the nested one (both go through `backendDidPublishState`)". Task 26's member-level
    /// reentrancy guard (`guard transactionPhase == .idle`, added to `setSelection`,
    /// `clearCompositionState` and `setMarkedText`) means **the nested call publishes NOTHING AT ALL** —
    /// it performs its storage write and skips its own bracket. There is now exactly ONE delivery in
    /// this run, the outer one. The assertion below is unchanged and still discriminating, but for a
    /// different reason: the freshening is what lets that single delivery carry S2, because the nested
    /// call mutated `canonicalSelectionStorage` INSIDE `publishState`'s own window — between
    /// `let snapshot = state` and the lifecycle delivery. Recorded here because this suite is inherited
    /// by stage 2, and a stage-2 reader following the old sentence would look for a second publish that
    /// no longer exists.
    ///
    /// This is also the test that settles the freshening's expiry (see `endTransaction()`'s doc comment,
    /// `+Attachment.swift`, now owned by Task 35): the freshening cannot be removed while a nested call
    /// still writes storage without publishing.
    ///
    /// RED IF: `publishState`'s final call were reverted to delivering the captured `snapshot` instead
    /// of a fresh `state` read — the one `lifecyclePublish` would describe the selection as it stood
    /// BEFORE the nested `setSelection(S2)` ran, not S2 itself. Confirmed red against exactly that
    /// reversion (Task 26 re-confirmed it WITH the member-level guards in place), then reverted.
    func test_nestedSetSelection_publishesTheFreshStateNotAStaleSnapshot() {
        let s2 = RichTextCanonicalSelection.caret(at: .downstream(9))
        var fired = false
        let backendUnderTest = backend
        fakeHost!.fakePresentationClient.onApply = { [weak backendUnderTest] in
            guard !fired else { return }
            fired = true
            backendUnderTest?.setSelection(s2, reason: .programmatic)
        }

        backend.insertText("x")

        // TASK 26 CORRECTION (see the doc comment): since the member-level reentrancy guard landed, the
        // nested `setSelection(s2)` publishes NOTHING — it writes `canonicalSelectionStorage` and skips
        // its bracket. The OUTER transaction's publish is therefore the ONLY delivery, and it carries
        // s2 solely because `publishState` re-reads `state` fresh for the lifecycle client after the
        // presentation callout that ran the nested write. Without the freshening it would carry the
        // pre-nested selection and the nested value would reach no client at all.
        XCTAssertEqual(fakeHost!.fakeLifecycleClient.lastPublishedState?.selection, s2,
                       "the OUTER transaction's own (and only) publish must carry the FRESH state (S2), " +
                       "not the snapshot captured before the nested call ran")
        XCTAssertEqual(log.count("lifecyclePublish"), 1,
                       "control for the corrected mechanism: exactly ONE publish reaches the lifecycle " +
                       "client in this run — if the nested call ever publishes again, the sentence " +
                       "above stops describing what happens")
    }

    // MARK: - 12. FIX ROUND 1: a client that re-stashes on every publish cannot recurse without bound

    /// `endTransaction()`'s drain used to call the PUBLIC `synchronizeAfterExternalChange` and let ITS
    /// OWN `endTransaction()` drain again — recursively, without bound, if a client reacts to every
    /// publish by requesting a new external sync. Fixed by draining AT MOST ONE deferred change per
    /// OUTER `endTransaction()` call (`+Attachment.swift`'s own doc comment). Not asserting on an
    /// actual unbounded chain (that would risk a genuine stack overflow in the test process); this
    /// pins the OBSERVABLE consequence instead — a change re-stashed during the ONE drain this
    /// transaction performs is left pending for a LATER transaction, not chained here.
    ///
    /// Precise shape: the outer change (old → old+6) applies directly. Its OWN publish stashes a
    /// SECOND change (unconditionally, reading the CURRENT revision fresh each time so it is always
    /// continuity-valid at the moment it is stashed) — that second change IS the ONE this call's
    /// `endTransaction()` drains (it was already pending by the time that method runs), so it ALSO
    /// applies within this same top-level call. ITS OWN publish stashes a THIRD change — and THIS one
    /// must NOT be chained (the nested call that would drain it has `activeTransactionDepth > 0`, so
    /// its own `endTransaction()` is a no-op) — it is left pending for whatever LATER, independent
    /// transaction runs next.
    ///
    /// RED IF: `endTransaction()`'s depth-gated "at most one drain" (`+Attachment.swift`) were reverted
    /// to the old unconditional recursive drain — the THIRD change would ALSO apply within this same
    /// call (the hook would fire a third time here too), so `stashFireCount` would read 3 instead of 2
    /// and `documentRevision` would already be `old + 206` before the later `setSelection` call ever
    /// runs. Confirmed red against exactly that reversion, then reverted.
    func test_aChangeReStashedDuringTheOneDrainThisTransactionPerforms_isLeftPendingNotChainedHere() {
        let backendUnderTest = backend
        let old = fakeHost!.fakeDocumentClient.revision
        var stashFireCount = 0
        fakeHost!.fakeLifecycleClient.onDidPublishState = { [weak backendUnderTest] _, reason in
            guard case .externalSynchronization = reason, let backendUnderTest else { return }
            stashFireCount += 1
            let current = backendUnderTest.state.documentRevision
            backendUnderTest.synchronizeAfterExternalChange(RichTextInputExternalChange(
                oldRevision: current, newRevision: current + 100, reason: .remoteUpdate,
                changedRangeBefore: nil, changedRangeAfter: nil,
                selection: .caret(at: .downstream(999)), markedTextPolicy: .discard))
        }

        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 6, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: .downstream(3)), markedTextPolicy: .discard))

        XCTAssertEqual(stashFireCount, 2,
                       "the drain must process exactly the ONE change that was ALREADY pending when " +
                       "this outer endTransaction() ran — a third firing within this same call would " +
                       "mean it chained recursively instead of stopping at one")
        XCTAssertEqual(backend.state.documentRevision, old + 106,
                       "the change that was pending BEFORE this call's drain ran (old+6 -> old+106) " +
                       "did apply — 'at most one per call' still does its one job")
        XCTAssertEqual(backend.canonicalSelection, .caret(at: .downstream(999)))

        // The THIRD change (stashed during the SECOND change's own drained publish) was left pending,
        // not chained — proven by a LATER, independent transaction picking it up.
        backend.setSelection(.caret(at: .downstream(1)), reason: .programmatic)
        XCTAssertEqual(backend.state.documentRevision, old + 206)
    }
}
#endif

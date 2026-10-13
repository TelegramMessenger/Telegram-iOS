#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Task 22f, the fifth of eight contract suites (22b-22i). Pins the three `RichTextMarkedTextPolicy`
/// branches of `synchronizeAfterExternalChange` (`.discard`, `.commitBeforeChange`,
/// `.preserveIfRebasable`) against `markedRangeStorage` — a real, if storage-only, stored
/// representation `markedTextRange`/`setMarkedText(_:selectedRange:)` got ahead of schedule (see
/// `LegacyRichTextInputBackend.swift`'s "Marked text (TASK 22f...)" section) so this suite has
/// something real to reconcile.
///
/// FIX ROUND 1 (review): four tests added to the original six —
/// `test_setMarkedText_publishesWithMarkedTextReason` (Major 1: `setMarkedText` published nothing,
/// undisclosed), `test_predictionShapedSetMarkedText_isTreatedIdenticallyToACompositionAtThisStorageOnlyStage`
/// (Focal Point 1 item 3: the suite had zero `{0,0}`-prediction-shaped fixtures — the exact input
/// Task 18's ghost-prediction bug lived in), `test_preserveIfRebasable_rebasesBeforeAdoptingRevisionAndSelection`
/// (Major 3: the reorder was real but the report over-claimed it unpinnable — `onRebase` refutes
/// that), and `test_preserveIfRebasable_skipsRebase_whenTheRevisionHasNotMoved` (Minor 4: the missing
/// "nothing stale ⇒ no rebase call" fast path). Ten tests total this round.
///
/// TASK 29 — the backend under test changed, and **no test body did.** Task 29 routed
/// `markedTextRange`/`setMarkedText(_:selectedRange:)` on `LegacyRichTextInputBackend` into plain
/// `legacyCanvas` forwards, so on that type they now read/write the CANVAS's `markedRange` rather than
/// `markedRangeStorage` — which is the store this suite's subject,
/// `reconcileMarkedTextForExternalChange`, reads. The two storage-only bodies moved to
/// `ReferenceMutationBackend` (`T/Support/`) and `makeBackend()` now returns that, exactly the
/// re-homing Task 27b performed for `insertText`'s transaction and Task 28 for `deleteBackward()`'s.
/// Everything this suite asserts is still an assertion about `LegacyRichTextInputBackend`'s own
/// machinery: the conformer forwards `synchronizeAfterExternalChange`, `detach`, `clearCompositionState`
/// and the publication path straight to a real instance, and the moved bodies write that instance's
/// `markedRangeStorage`.
///
/// `class`, not `final class` — Task 22a's `BackendContractCases` is subclassed again by stage 2,
/// which overrides ONLY `makeBackend()`. The only place this file names a concrete backend type is
/// that override, below.
@MainActor
@available(iOS 16.0, *)
class BackendMarkedTextPolicyTests: BackendContractCases {
    override func makeBackend() -> (any RichTextInputBackend)? {
        ReferenceMutationBackend()
    }

    // MARK: - 1. The worked example: `.discard` drops the composition without touching the document

    /// `.discard` drops the composition WITHOUT asking the document client to change anything — the
    /// whole point of the policy is that the host already applied the change.
    ///
    /// RED IF: `.discard`'s case in `reconcileMarkedTextForExternalChange` were reverted to a bare
    /// `break` (the pre-task behavior) — `markedTextRange` would then stay non-nil. Confirmed red
    /// against exactly that mutation, then reverted.
    func test_discard_dropsMarkedRange_withoutMutatingTheDocument() {
        backend.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNotNil(backend.markedTextRange, "composition established before the external change")
        log.reset()
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: fakeHost!.fakeDocumentClient.revision,
            newRevision: fakeHost!.fakeDocumentClient.revision + 1,
            reason: .undo, changedRangeBefore: nil, changedRangeAfter: nil,
            selection: backend.canonicalSelection, markedTextPolicy: .discard))
        XCTAssertNil(backend.markedTextRange)
        XCTAssertFalse(log.contains("documentPrepare"))
        XCTAssertFalse(log.contains("documentCommit"))
    }

    // MARK: - 2. `.commitBeforeChange` resolves the composition before the new revision lands

    /// `.commitBeforeChange` asks the backend to stop treating the composition as provisional before
    /// the new revision lands.
    ///
    /// FIX ROUND 1 (review Major 2) — CORRECTED ORACLE: the real chokepoint `.commitBeforeChange`
    /// maps to is `legacyCanvas.finalizeMarkedText()` (`Canvas/DocumentCanvasView+MarkedText.swift:136-147`;
    /// plan `:7290,7359,7372`) — **not** `commitMarkedText()` as an earlier draft of this comment said.
    /// `finalizeMarkedText()` is two-halved: a genuine COMPOSITION is COMMITTED (`commitMarkedText()`:
    /// one undo step, no text mutation, no revision bump, no delegate notification — "Does NOT mutate
    /// text (provisional chars stay committed)"); a genuine PREDICTION is DISMISSED, never committed
    /// (`dismissPrediction()`: removes the ghost via `applyReplaceOutcome(…, text: "")`, DOES bump the
    /// revision, DOES fire `textWillChange`/`textDidChange`, registers NO undo). See
    /// `reconcileMarkedTextForExternalChange`'s own doc comment (production code) for the full oracle
    /// and the three observables (undo depth, the ghost-removal revision bump, the delegate bracket).
    /// (TASK 29 CORRECTION, fix round 1: this said the suite could reach them "once Task 29's real
    /// forward lands". It landed and they are still out of reach — under D35 the routed member writes
    /// `canvas.markedRange`, not the `markedRangeStorage` this suite reconciles. **Task 41** owns them.)
    ///
    /// SELF-DISCLOSED (per the task brief's own vacuity-trap note): at this stage-1 storage level,
    /// `LegacyRichTextInputBackend`'s OWN `setMarkedText(_:selectedRange:)` never actually inserts
    /// anything into the document either (see its doc comment) — so this branch's OBSERVABLE effect
    /// on `markedRangeStorage` COINCIDES with `.discard`'s: both simply clear it, and neither touches
    /// the document client (CONFIRMED on review: the two case bodies are the literal same statement,
    /// so swapping them is a textual no-op — nothing anywhere goes red on that swap). The genuine
    /// distinction described above needs a `setMarkedText` that gives the store this suite reconciles a
    /// genuine provisional document delta to commit or dismiss. (TASK 29 CORRECTION, fix round 1: this
    /// named Task 29's `legacyCanvas` forward as that thing. It is not — the forward landed, and it
    /// writes `canvas.markedRange` while this suite drives `ReferenceMutationBackend`'s storage-only
    /// body against `markedRangeStorage`. **Task 41**, which merges the two stores, is the owner.) This is
    /// NOT re-litigated as a false contrast here — see
    /// `test_preserveIfRebasable_keepsMarkedRange_whenRebaseSucceeds` below for the branch that IS
    /// genuinely different today.
    ///
    /// What this test DOES pin, and is not vacuous relative to `.discard`'s own test: `documentRevision`
    /// still lands on exactly `change.newRevision` — the marked-text reconciliation does not
    /// accidentally short-circuit (or depend on) revision adoption.
    ///
    /// FIX ROUND 1 (review Minor 2) — this test's NAME claims a "before" its OWN body cannot observe
    /// (it reads terminal state only). Not fabricating an observation here: `.commitBeforeChange`'s
    /// branch is a bare field write with no callout of its own to sample mid-flight, unlike
    /// `.preserveIfRebasable`'s `document.rebase` call. The ORDERING claim the name makes is genuinely
    /// pinned, mechanism-wide, by `test_preserveIfRebasable_rebasesBeforeAdoptingRevisionAndSelection`
    /// below — that test proves `reconcileMarkedTextForExternalChange` (the exact same call, shared by
    /// all three policies, at the exact same call site) runs before `documentRevision`/
    /// `canonicalSelectionStorage` adopt `change.newRevision`/`change.selection`. This test's own
    /// assertions remain terminal-state only; the name is honest at the mechanism level, not because
    /// this test's own body newly observes an ordering.
    ///
    /// RED IF: `.commitBeforeChange`'s case in `reconcileMarkedTextForExternalChange` were reverted to
    /// a bare `break` (the pre-task behavior, shared with `.preserveIfRebasable` before this task) —
    /// `markedTextRange` would then stay non-nil. Confirmed red against exactly that mutation, then
    /// reverted.
    func test_commitBeforeChange_commitsTheComposition_beforeAdoptingTheNewRevision() {
        backend.setMarkedText("k", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(backend.markedTextRange, "composition established before the external change")
        log.reset()
        let old = fakeHost!.fakeDocumentClient.revision
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: backend.canonicalSelection, markedTextPolicy: .commitBeforeChange))
        XCTAssertNil(backend.markedTextRange, "the composition is resolved, not left dangling")
        XCTAssertEqual(backend.state.documentRevision, old + 1)
        XCTAssertFalse(log.contains("documentPrepare"), "bookkeeping-only at this stage — see this test's own doc comment for the real Task-29 oracle (finalizeMarkedText())")
        XCTAssertFalse(log.contains("documentCommit"))
    }

    // MARK: - 3. `.preserveIfRebasable` keeps the (rebased) range when both endpoints rebase

    /// `.preserveIfRebasable` is the one policy that genuinely differs from the other two today — the
    /// real contrast this suite pins, per the task brief's "pin the contrast, not just the case" rule:
    /// both endpoints of the marked range are rebased via `document.rebase(_:fromRevision:)`, and a
    /// successful rebase KEEPS the composition (with the rebased offsets), unlike `.discard`/
    /// `.commitBeforeChange`, which always drop it.
    ///
    /// RED IF: `.preserveIfRebasable` were implemented as a bare `markedRangeStorage = nil` (i.e. the
    /// same as `.discard`) — `markedTextRange` would then be nil instead of reflecting the rebased
    /// range, and `rebaseCallCount` would be 0 instead of 2. Confirmed red against exactly that
    /// mutation, then reverted.
    func test_preserveIfRebasable_keepsMarkedRange_whenRebaseSucceeds() {
        backend.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        guard let before = backend.markedTextRange as? DocumentTextRange else {
            XCTFail("composition established before the external change"); return
        }
        // Simulate a genuine rebase: the two endpoints land at DIFFERENT offsets than they started at
        // (not an identity pass-through), so the resulting range is provably derived from the rebase
        // calls rather than incidentally equal to the pre-change range.
        fakeHost!.fakeDocumentClient.rebaseResultsQueue = [
            RichTextInputPosition(utf16Offset: before.from.offset + 10),
            RichTextInputPosition(utf16Offset: before.to.offset + 10),
        ]
        log.reset()
        let old = fakeHost!.fakeDocumentClient.revision
        // FIX ROUND 2 (review Minor 1): the fast path above now keys on `document.revision`, the
        // CLIENT's live revision — matching the "the host already applied the change" invariant
        // documented on `.discard`'s own case, this must actually move for the rebase below to run.
        fakeHost!.fakeDocumentClient.revision = old + 1
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: backend.canonicalSelection, markedTextPolicy: .preserveIfRebasable))
        guard let after = backend.markedTextRange as? DocumentTextRange else {
            XCTFail("expected the rebased marked range to survive"); return
        }
        XCTAssertEqual(after.from.offset, before.from.offset + 10)
        XCTAssertEqual(after.to.offset, before.to.offset + 10)
        XCTAssertEqual(fakeHost!.fakeDocumentClient.rebaseCallCount, 2,
                       "a non-collapsed marked range rebases both endpoints — never more than the two")
    }

    // MARK: - 4. `.preserveIfRebasable` discards the range when rebase returns nil

    /// The contrasting outcome of the SAME policy on the SAME shape of input: a rebase that fails
    /// drops the composition, exactly like `.discard`/`.commitBeforeChange` — proving "keep" above
    /// isn't unconditional.
    ///
    /// RED IF: `.preserveIfRebasable` unconditionally kept the marked range regardless of what
    /// `document.rebase` returned (e.g. reusing the STALE offsets when rebase fails, instead of
    /// dropping) — `markedTextRange` would then be non-nil. Confirmed red against exactly that
    /// mutation, then reverted.
    func test_preserveIfRebasable_discardsMarkedRange_whenRebaseReturnsNil() {
        backend.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNotNil(backend.markedTextRange, "composition established before the external change")
        // `fakeHost!.fakeDocumentClient.rebaseResult` defaults to nil — "cannot be rebased".
        log.reset()
        let old = fakeHost!.fakeDocumentClient.revision
        // FIX ROUND 2 (review Minor 1): see test 3's own note — the fast path now keys on the
        // CLIENT's live revision, so it must actually move for the rebase (and its failure) below to
        // be reached at all.
        fakeHost!.fakeDocumentClient.revision = old + 1
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: backend.canonicalSelection, markedTextPolicy: .preserveIfRebasable))
        XCTAssertNil(backend.markedTextRange, "an unrebasable marked range must be dropped, not left stale")
        // FIX ROUND 1 (review Minor 6): corrected message — D32's rule is AT MOST ONE rebase attempt
        // PER DISTINCT OFFSET, not "one call total" (test 3 asserts exactly TWO calls, one per
        // endpoint, and that is not a violation). What this assertion pins is narrower: the FIRST
        // (failing) endpoint's rebase must short-circuit the SECOND endpoint's rebase call, not retry
        // the same offset.
        XCTAssertEqual(fakeHost!.fakeDocumentClient.rebaseCallCount, 1,
                       "the first (failing) endpoint rebase must short-circuit the second endpoint's " +
                       "call, per D32's at-most-one-attempt-per-offset rule")
    }

    // MARK: - 5. A composition left active at detach does not survive into a fresh attach

    /// `markedRangeStorage` is new REAL state this task added (`setMarkedText`'s ahead-of-schedule
    /// body) — the hard-won rule "if you add state, say what tears it down and pin that too":
    /// `finalizeMarkedTextForDetach()` (`performDetachSteps()`'s step 3) now clears it, mirroring how
    /// `suppressesSelectionNotifications`/`floatingCursorActive` are reset at detach. Follows
    /// `BackendSelectionContractTests.test_selectedTextRangeSetter_isIgnoredWhileFloatingCursorIsActive`'s
    /// own detach/reattach pattern: a fresh host via the fixture's `makeHost(log:)` factory (R11),
    /// never a directly-constructed fixture type.
    ///
    /// RED IF: `finalizeMarkedTextForDetach()` were reverted to its pre-task empty body —
    /// `markedTextRange` would then read the STALE pre-detach range immediately after the fresh
    /// `attach()` (since `installInitialState` never touches `markedRangeStorage`). Confirmed red
    /// against exactly that mutation, then reverted.
    func test_markedTextIsNotMigratedAcrossDetachAndReattach() throws {
        backend.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNotNil(backend.markedTextRange, "composition established before detaching")

        backend.detach()

        let freshHost = makeHost(log: log)
        try backend.attach(to: freshHost)
        withExtendedLifetime(freshHost) {
            XCTAssertNil(backend.markedTextRange,
                        "a fresh attach must not inherit a composition left over from the previous session")
        }
    }

    // MARK: - 6. An undo external change is reconciled via the declared policy, not a keyboard mutation

    /// The riskiest implementation mistake this switch invites: routing a marked-text policy through
    /// the SAME chokepoint (`prepareAndRun`/`runMutation`, `+Mutation.swift`) a real keyboard mutation
    /// uses — which would fire `UITextInputDelegate` notifications and the document client, turning a
    /// host-driven external change into a COUNTERFEIT keyboard mutation. `.commitBeforeChange` is the
    /// policy whose NAME most invites "just call `unmarkText()`/an insert via `prepareAndRun`", so it
    /// is the one exercised here, under `reason: .undo` (the most realistic real-world trigger for
    /// this method).
    ///
    /// RED IF: `.commitBeforeChange`'s reconciliation were implemented by routing an `.unmarkText` (or
    /// any other) mutation through `prepareAndRun`/`runMutation` instead of a bare
    /// `markedRangeStorage = nil` — `log` would then show `documentPrepare`/`documentCommit` and the
    /// delegate would show `delegateTextWillChange`/`delegateTextDidChange`
    /// (`delegateSelectionWillChange`/`delegateSelectionDidChange`), none of which a host-driven undo
    /// should ever produce. Confirmed red by temporarily routing this branch through
    /// `prepareAndRun(document:host:) { .unmarkText }`, then reverted.
    ///
    /// FIX ROUND 1 (review Major 2) — QUALIFIED: the blanket "no delegate notifications" this test
    /// asserts holds ONLY for the COMPOSITION-shaped input it exercises (`setMarkedText("k",
    /// selectedRange: NSRange(location: 1, length: 0))` — caret at the END, not a prediction). At
    /// **TASK 41**, once `.commitBeforeChange` maps to the real `finalizeMarkedText()`, a
    /// PREDICTION-shaped input (`selectedRange == {0,0}`) DOES need to fire
    /// `textWillChange`/`textDidChange` (`dismissPrediction()`'s own bracket) — this test must NOT be
    /// relaxed to accommodate that; **Task 41** needs a prediction-shaped SIBLING asserting the bracket
    /// DOES fire. (TASK 29 CORRECTION: this obligation was booked to Task 29. Under the D35 ruling Task
    /// 29 routed the witnesses as plain `legacyCanvas` forwards and did NOT wire `.commitBeforeChange`
    /// to `finalizeMarkedText()` — that reconciliation still runs on the parallel `markedRangeStorage`,
    /// so nothing about this test's oracle changed and the sibling is still owed, by Task 41.) See `test_predictionShapedSetMarkedText_isTreatedIdenticallyToACompositionAtThisStorageOnlyStage`
    /// below for the fixture gap this suite had before this fix round.
    func test_undoExternalChange_usesTheDeclaredPolicy_notACounterfeitKeyboardMutation() {
        let delegate = RecordingInputDelegate(log: log)
        backend.inputDelegate = delegate

        backend.setMarkedText("k", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(backend.markedTextRange, "composition established before the undo")
        log.reset()
        let old = fakeHost!.fakeDocumentClient.revision
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .undo,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: backend.canonicalSelection, markedTextPolicy: .commitBeforeChange))

        XCTAssertNil(backend.markedTextRange)
        XCTAssertFalse(log.contains("documentPrepare"))
        XCTAssertFalse(log.contains("documentCommit"))
        XCTAssertFalse(log.contains("delegateTextWillChange"))
        XCTAssertFalse(log.contains("delegateTextDidChange"))
        XCTAssertFalse(log.contains("delegateSelectionWillChange"))
        XCTAssertFalse(log.contains("delegateSelectionDidChange"))
    }

    // MARK: - 7. FIX ROUND 1 (review Major 1): `setMarkedText` publishes with reason `.markedText`

    /// `setMarkedText` mutates `markedRangeStorage`, which is BOTH `state.markedRange` AND (via it)
    /// `state.isComposing` — two of the four published snapshot fields, per `clearCompositionState()`'s
    /// own doc comment (a GENERAL rule, not a `clearCompositionState`-only quirk). It shipped
    /// publishing nothing — the same shape as the already-found Task 20 `clearCompositionState()`
    /// defect (caught in review, not by argument). Fixed to publish with reason `.markedText`,
    /// mirroring `clearCompositionState()`'s own established choice.
    ///
    /// TASK 29 — the member this drives now lives on `ReferenceMutationBackend`, moved verbatim with
    /// its publish. The published-snapshot rule it pins is unchanged and still a rule about
    /// `LegacyRichTextInputBackend` (the publish runs through `inner.publishState`); what changed is
    /// which conformer's `setMarkedText` is the entry point. The REAL routed member publishes nothing
    /// of its own — the canvas body it forwards to fires `notifyContentSizeChanged()` and
    /// `onSelectionChange?()` itself, which is the resolution of the "must look at BOTH channels" note
    /// Task 22f left for Task 29 (see `LegacyRichTextInputBackend+MarkedText.swift`).
    ///
    /// RED IF: `setMarkedText`'s `publishState(reason: .markedText)` call were removed — `log.kinds`
    /// would then be empty instead of `["presentationApply", "lifecyclePublish"]`. Confirmed red
    /// against exactly that mutation, then reverted.
    func test_setMarkedText_publishesWithMarkedTextReason() {
        backend.setMarkedText("k", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual(log.kinds, ["presentationApply", "lifecyclePublish"])
        let reasons = log.events.compactMap { event -> String? in
            if case .lifecyclePublish(_, let reason) = event { return reason }
            return nil
        }
        XCTAssertEqual(reasons, ["markedText"])
    }

    // MARK: - 8. FIX ROUND 1 (review Focal Point 1 item 3): the missing prediction-shaped fixture

    /// Every one of the original six tests used a COMPOSITION-shaped `selectedRange` (location 1 or
    /// 2, caret at the END of the marked text) — the suite had ZERO `{0,0}`-prediction-shaped cases,
    /// i.e. it was silent on precisely the input Task 18's ghost-prediction bug lived in. Added per
    /// the review's explicit instruction: report what IS found, do NOT silently "fix" the branch to
    /// invent a distinction this stage-1 body does not have.
    ///
    /// FINDING: stage-1 `setMarkedText` ignores `selectedRange` entirely (see its own doc comment) —
    /// it derives `markedRangeStorage` from the composing TEXT's length only, never from
    /// `selectedRange`. So a prediction-shaped call (`selectedRange == {0,0}`) and a
    /// composition-shaped call produce an IDENTICAL `markedRangeStorage`, and
    /// `reconcileMarkedTextForExternalChange` — which also never reads `selectedRange`, only
    /// `markedRangeStorage` — reconciles them identically too. This is NECESSARILY a documented
    /// placeholder, not a real pass/fail on the actual prediction-vs-composition distinction: there is
    /// no `markedTextIsPrediction`-equivalent tracked anywhere in this stage-1 backend (by design,
    /// per `markedRangeStorage`'s own declaration comment — Task 41 moves all four composition
    /// properties together). The real divergence (a prediction must be DISMISSED via
    /// `dismissPrediction()`, never committed) is entirely **TASK 41's** to add, once composition state
    /// actually moves onto the backend. (TASK 29 CORRECTION: booked to Task 29 until its fix round 1.
    /// Task 29's `legacyCanvas` forward DID land, and it changed nothing here — under D35 the routed
    /// member writes `canvas.markedRange`, not the `markedRangeStorage` this suite reconciles, so the
    /// storage-only body this test drives is unchanged and simply lives on `ReferenceMutationBackend`
    /// now.)
    ///
    /// THIS TEST IS NOT COVERAGE of that real divergence — two other tests bear on it and this one must
    /// not be misread as a substitute for either. `test_finalizeMarkedTextDismissesAPredictionButCommitsAComposition`
    /// (landed with Task 29, `MarkedTextRouterTests`) pins the commit-vs-dismiss behavior — but note
    /// what Task 29's review established about it: it drives `DocumentCanvasView.finalizeMarkedText()`,
    /// so it is a CHARACTERIZATION of pre-existing canvas behaviour, not a guard on any backend member;
    /// it will need a backend-driven sibling when Task 41 moves the state.
    /// `test_exactlyOneWritableSelectionAuthority` (Task 41, `plan:7577`) is the R7 absolute-zero
    /// guard that keeps a backend-side `markedTextIsPrediction` from ever being added as a second
    /// writable composition authority. This test's own job is narrower: recording what this stage-1
    /// body does TODAY (nothing distinguishes the two shapes) so a future reader has a dated
    /// characterization to diff against once Task 41 lands.
    ///
    /// FIX ROUND 2 (review Minor 4) — CORRECTED: "no mutation exists to revert against" was itself an
    /// over-claim (the second time this shape has come up in this file — rule 5's "I could not find
    /// one" is the honest form, and here one exists). Two REALISTIC mutations DO redden this test:
    ///   1. Deriving `newLength` from `selectedRange.length` instead of the composing TEXT's length
    ///      (a plausible reading of "the marked range should reflect what's selected") — for THIS
    ///      test's prediction-shaped call (`selectedRange == {0,0}`), `selectedRange.length` is 0, so
    ///      `markedRangeStorage` would become `nil` instead of a length-3 range, and the
    ///      `guard let predictionRange = …` below would fail. Confirmed red against exactly this
    ///      mutation, then reverted.
    ///   2. A reading in which a `{0,0}` `selectedRange` is special-cased to record NO marked range at
    ///      all (conflating "this LOOKS like a prediction signal" with "there is no composition") —
    ///      confirmed red the same way (the same guard fails), then reverted.
    /// Both mutations single out the SAME `selectedRange == {0,0}` input this test exists to exercise,
    /// which is exactly why this test is non-vacuous: it pins that the CURRENT body does NEITHER of
    /// those two plausible (and wrong, for this stage) things. What remains true, and is the actual
    /// FINDING this test records: neither mutation above is currently PRESENT in the source — the
    /// stage-1 body simply ignores `selectedRange` — so there is nothing to revert in the shipped code
    /// itself; the two mutations above were applied only transiently, to prove this test would catch
    /// either one, not left in place.
    func test_predictionShapedSetMarkedText_isTreatedIdenticallyToACompositionAtThisStorageOnlyStage() {
        // Prediction shape: selectedRange == {0,0} (caret at the START, trailing ghost text) —
        // contrast every other test's composition shape (selectedRange location == the marked text's
        // own length, caret at the END).
        backend.setMarkedText("ing", selectedRange: NSRange(location: 0, length: 0))
        guard let predictionRange = backend.markedTextRange as? DocumentTextRange else {
            XCTFail("composition established before the external change"); return
        }
        XCTAssertEqual(predictionRange.to.offset - predictionRange.from.offset, 3,
                       "the stage-1 body computes the marked range from the TEXT length only — a " +
                       "prediction's {0,0} caret has no effect on the recorded range")
        log.reset()
        let old = fakeHost!.fakeDocumentClient.revision
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: backend.canonicalSelection, markedTextPolicy: .commitBeforeChange))
        XCTAssertNil(backend.markedTextRange,
                     "FINDING: identical outcome to the composition-shaped test above — this stage " +
                     "does not distinguish a prediction from a composition (no markedTextIsPrediction " +
                     "tracking exists), so .commitBeforeChange clears it the same way either input " +
                     "shape. This is the exact gap TASK 41 must close: a real prediction must be " +
                     "DISMISSED via finalizeMarkedText() -> dismissPrediction(), never committed.")
    }

    // MARK: - 9. FIX ROUND 1 (review Major 3 / Focal Point 2b): pin the reorder

    /// The review's verdict on Focal Point 2: keep the reorder (it is the more honest order, and
    /// reverting would be worse — it would rebase `fromRevision: change.oldRevision` after the local
    /// revision had already advanced), and PIN it — the original report's "no test would catch a
    /// re-reorder" was an over-claim: `FakeInputDocumentClient.onRebase` (this fix round's addition,
    /// same precedent as `revisionAfterRebase`/`rebaseResultsQueue`) is a reentrant callout from
    /// INSIDE `document.rebase(_:fromRevision:)` — a sampling point mid-`synchronizeAfterExternalChange`,
    /// before `documentRevision`/`canonicalSelectionStorage` adopt `change.newRevision`/
    /// `change.selection`. Covers BOTH halves the review's Focal Point 2 flagged: the revision AND the
    /// canonical-selection adoption ordering (the original report only disclosed the revision half).
    ///
    /// RED IF: `reconcileMarkedTextForExternalChange(change)` were moved back to AFTER
    /// `documentRevision = change.newRevision; canonicalSelectionStorage = change.selection` (the
    /// pre-fix-round-1 position it started at, before this task's own initial reorder) — both captured
    /// values below would read the NEW revision/selection instead of the OLD ones. Confirmed red
    /// against exactly that reversion, then reverted back.
    func test_preserveIfRebasable_rebasesBeforeAdoptingRevisionAndSelection() {
        backend.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNotNil(backend.markedTextRange, "composition established before the external change")
        let staleSelection = backend.canonicalSelection
        fakeHost!.fakeDocumentClient.rebaseResult = RichTextInputPosition(utf16Offset: 0)

        var revisionDuringRebase: UInt64?
        var selectionDuringRebase: RichTextCanonicalSelection?
        let backendUnderTest = backend
        fakeHost!.fakeDocumentClient.onRebase = {
            revisionDuringRebase = backendUnderTest.state.documentRevision
            selectionDuringRebase = backendUnderTest.canonicalSelection
        }

        let old = fakeHost!.fakeDocumentClient.revision
        // FIX ROUND 2 (review Minor 1): see test 3's own note.
        fakeHost!.fakeDocumentClient.revision = old + 1
        let newSelection = RichTextCanonicalSelection.caret(at: .downstream(9))
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: newSelection, markedTextPolicy: .preserveIfRebasable))

        XCTAssertEqual(revisionDuringRebase, old,
                       "the rebase must run BEFORE documentRevision adopts change.newRevision")
        XCTAssertEqual(selectionDuringRebase, staleSelection,
                       "the rebase must ALSO run BEFORE canonicalSelectionStorage adopts change.selection")
        XCTAssertEqual(backend.state.documentRevision, old + 1, "revision still lands correctly afterward")
        XCTAssertEqual(backend.canonicalSelection, newSelection, "selection still lands correctly afterward")
    }

    // MARK: - 10. FIX ROUND 1 (review Minor 4): the missing "nothing stale" fast path

    /// `.preserveIfRebasable` claimed to mirror `ensureCanonicalSelectionIsCurrent`
    /// (`+Mutation.swift:131-158`), which opens with `guard targetRevision != documentRevision else {
    /// return true }` — a fast path this branch lacked. Added this fix round: when
    /// `change.oldRevision == change.newRevision` (the shape of a `.layoutOnly` reflow — the plan's
    /// most frequent external change), the marked range's endpoints are still expressed in the SAME,
    /// unmoved revision, so no rebase call is needed at all.
    ///
    /// RED IF: the fast path were removed — `rebaseCallCount` would read 2 instead of 0. Confirmed red
    /// against exactly that mutation, then reverted.
    func test_preserveIfRebasable_skipsRebase_whenTheRevisionHasNotMoved() {
        backend.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        guard let before = backend.markedTextRange as? DocumentTextRange else {
            XCTFail("composition established before the external change"); return
        }
        log.reset()
        let old = fakeHost!.fakeDocumentClient.revision
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old, reason: .layoutOnly,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: backend.canonicalSelection, markedTextPolicy: .preserveIfRebasable))
        guard let after = backend.markedTextRange as? DocumentTextRange else {
            XCTFail("expected the marked range to survive an unmoved revision"); return
        }
        XCTAssertEqual(after.from.offset, before.from.offset)
        XCTAssertEqual(after.to.offset, before.to.offset)
        XCTAssertEqual(fakeHost!.fakeDocumentClient.rebaseCallCount, 0,
                       "nothing is stale when the revision hasn't moved — no rebase call is needed")
    }

    // MARK: - 11. FIX ROUND 2 (review Minor 2): a zero-length rebased range collapses to nil

    /// `.preserveIfRebasable` could write a ZERO-LENGTH marked range (`isComposing == true` while
    /// composing nothing) when both endpoints rebase to the IDENTICAL offset —
    /// `test_preserveIfRebasable_rebasesBeforeAdoptingRevisionAndSelection`'s own `rebaseResult`
    /// (identity offset 0 for both endpoints, to keep that test's OWN focus on ordering rather than on
    /// this shape) produces exactly this. Collapsed to `nil` here, mirroring `setMarkedText`'s own
    /// empty-collapses-to-nil convention.
    ///
    /// RED IF: the `hi > lo ? NSRange(location: lo, length: hi - lo) : nil` collapse were reverted to
    /// an unconditional `NSRange(location: lo, length: hi - lo)` — `markedTextRange` would then be
    /// non-nil (a zero-length range) instead of nil. Confirmed red against exactly that mutation, then
    /// reverted.
    func test_preserveIfRebasable_collapsesAZeroLengthRebasedRangeToNil() {
        backend.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNotNil(backend.markedTextRange, "composition established before the external change")
        // Both endpoints rebase to the SAME offset — the zero-length shape this test targets.
        fakeHost!.fakeDocumentClient.rebaseResult = RichTextInputPosition(utf16Offset: 5)
        log.reset()
        let old = fakeHost!.fakeDocumentClient.revision
        fakeHost!.fakeDocumentClient.revision = old + 1
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: backend.canonicalSelection, markedTextPolicy: .preserveIfRebasable))
        XCTAssertNil(backend.markedTextRange,
                     "a zero-length rebased range must collapse to nil — isComposing must never be " +
                     "true while composing nothing")
    }
}
#endif

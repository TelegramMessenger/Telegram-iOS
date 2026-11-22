#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Task 22c, the second of eight contract suites (22b-22i). Pins the backend's REVISION-SAFETY
/// contract: a stale position/selection is rebased or rejected — never silently reinterpreted
/// against a newer document (deviation D32); a decreasing/mismatched external-change revision is a
/// contract violation and is not adopted (Task 20's continuity guard, already implemented — this
/// suite adds coverage Task 20's own `BackendAttachmentTests` does not); and a `.layoutOnly` external
/// change never moves the document revision even though it still publishes.
///
/// `class`, not `final class` — Task 22a's `BackendContractCases` is subclassed again by stage 2,
/// which overrides ONLY `makeBackend()`. The only place this file names a concrete backend type is
/// that override, below.
@MainActor
@available(iOS 16.0, *)
class BackendRevisionContractTests: BackendContractCases {
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
    /// 4 of this suite's 6 tests drive `insertText` as the mutation whose rebase/adoption they pin; the
    /// other two drive `synchronizeAfterExternalChange`, forwarded unchanged.
    override func makeBackend() -> (any RichTextInputBackend)? {
        ReferenceMutationBackend()
    }

    // MARK: - 1. The worked example: one rebase, one prepare at the new revision

    /// One rebase, then ONE prepare at the new revision. A backend that prepared at the stale
    /// revision first and retried would record `[1, 5]` here (the stale `1` ahead of the corrected
    /// `5`) — that is the failure this pins.
    ///
    /// FIX ROUND 1 correction: an earlier version of this comment said "would record `[4, 5]`" — wrong
    /// against this fixture (the backend is at revision `1`, not `4`, because the
    /// `synchronizeAfterExternalChange` call BELOW is deliberately refused — only the corrected `1`
    /// vs. `5` framing above is accurate).
    ///
    /// That `synchronizeAfterExternalChange` call is DELIBERATELY refused: its `oldRevision: 4`
    /// does not match the freshly-attached backend's adopted revision (1, seeded from the fixture's
    /// default `FakeInputDocumentClient.revision`), so Task 20's continuity guard reports a contract
    /// violation and adopts nothing (`log.reset()` discards that noise — this test is not about it).
    /// The backend is therefore left exactly as stale as it started, while the document client's own
    /// revision has genuinely moved to 5 out from under it — precisely the scenario the REBASE
    /// mechanism below must recover from on the very next operation.
    ///
    /// RED IF: `insertText` ever attempted a `prepareMutation` BEFORE rebasing (would add a `1` ahead
    /// of the `5` in `receivedExpectedRevisions`), or rebased more than once for this collapsed
    /// selection (would push `rebaseCallCount` above 1).
    func test_stalePosition_isRebasedOnce_thenPreparesAtTheNewRevision() {
        let stale = backend.canonicalSelection
        fakeHost!.fakeDocumentClient.revision = 5
        fakeHost!.fakeDocumentClient.rebaseResult = RichTextInputPosition(utf16Offset: 3)
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: 4, newRevision: 5, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: stale, markedTextPolicy: .discard))
        log.reset()
        backend.insertText("x")
        XCTAssertEqual(fakeHost!.fakeDocumentClient.rebaseCallCount, 1)
        XCTAssertEqual(fakeHost!.fakeDocumentClient.receivedExpectedRevisions, [5])
    }

    // MARK: - 2. A rebase returning nil is a rejection, not a crash or a silent reinterpretation

    /// D32: "a stale object is explicitly rebased or rejected." When `document.rebase` reports the
    /// position CANNOT be rebased (`nil`), the mutation must never reach `prepareMutation` at all —
    /// there is no valid position to construct it from — and must be reported through the SAME
    /// `backendDidRejectMutation` channel `BackendMutationContractTests` already pins for a
    /// `.terminal(.rejected(...))` disposition, reusing the existing `.revisionMismatch` case of
    /// `RichTextInputMutationRejection` rather than inventing a second reporting path.
    ///
    /// RED IF: `insertText` called `prepareMutation` despite a nil rebase (a genuine "silently
    /// reinterpreted" bug), or the rejection were reported some other way (or not at all), or the
    /// backend's revision/selection moved despite the refusal.
    func test_rebaseReturningNil_rejectsWithRevisionMismatch_withoutPreparing() {
        let revisionBefore = backend.state.documentRevision
        let selectionBefore = backend.canonicalSelection
        fakeHost!.fakeDocumentClient.revision = 5
        fakeHost!.fakeDocumentClient.rebaseResult = nil   // "cannot be rebased" (the fixture's own default; explicit here)

        backend.insertText("x")

        XCTAssertEqual(fakeHost!.fakeDocumentClient.rebaseCallCount, 1)
        XCTAssertTrue(fakeHost!.fakeDocumentClient.receivedMutations.isEmpty,
                     "an un-rebasable stale position must never reach prepareMutation")
        XCTAssertEqual(log.kinds, ["documentRebase", "lifecycleReject"])
        XCTAssertEqual(fakeHost!.fakeLifecycleClient.lastRejectionReason, .revisionMismatch)
        XCTAssertEqual(backend.state.documentRevision, revisionBefore,
                       "a refused rebase must not adopt the newer revision")
        XCTAssertEqual(backend.canonicalSelection, selectionBefore,
                       "a refused rebase must not touch the (stale, now-unusable) selection either")
    }

    // MARK: - 3. At most one rebase per operation — settles, and re-arms, but never loops

    /// FIX ROUND 1: the review found this test's ORIGINAL body pinned "settles, then re-arms" but NOT
    /// "cannot loop" — against this fixture's immobile fake, a `while document.revision !=
    /// documentRevision { rebase…; documentRevision = document.revision }` re-implementation would
    /// ALSO read `rebaseCallCount == 1` (nothing in the fake makes `document.revision` move on its
    /// own, so the loop's own re-check sees the condition already satisfied after one iteration and
    /// exits — coincidentally identical to the correct snapshot-then-adopt shape). Part (1) below
    /// closes that gap using the new `revisionAfterRebase` knob: it makes the fake's `revision` move
    /// FURTHER, DURING the rebase call itself, simulating the document racing ahead again before the
    /// backend has finished reacting to the FIRST staleness. The correct implementation reads
    /// `document.revision` into `targetRevision` ONCE, before calling `rebase` at all, and uses THAT
    /// snapshot as `expectedRevision` — so `receivedExpectedRevisions` records the pre-bump `5`. An
    /// implementation that re-read `document.revision` AFTER the rebase call (catching the knob's
    /// bump to `20`) would instead record `20` — and, per the spec's own "may not loop" language, a
    /// literal `while` loop built around that live re-read would then notice its own STALE copy of
    /// `documentRevision` still disagrees and attempt a SECOND rebase (this fixture cannot force that
    /// second call to terminate observably without hanging, which is why the `expectedRevision`
    /// assertion — not a call-count assertion — is what this part actually pins; see the fix-round
    /// report for the full derivation).
    ///
    /// Parts (2) and (3) are the original "settles, then re-arms" coverage, unchanged: (2) runs
    /// immediately after (1) with backend and document already in lockstep (a normal commit advances
    /// both together) — a correct implementation attempts ZERO further rebases here; a buggy "always
    /// rebase when in doubt" implementation would over-count. (3) the document moves again — a
    /// genuinely NEW staleness — and gets exactly ONE more rebase, proving the mechanism re-arms per
    /// operation rather than either forgetting to recheck (would stay at the (2) count) or looping.
    ///
    /// RED IF: `receivedExpectedRevisions` ever recorded `20` instead of `5` for part (1) (a live
    /// re-read after rebasing), a rebase fired on the settled (2) call, or the mechanism failed to
    /// re-fire at all for (3).
    func test_rebaseIsAttemptedAtMostOncePerOperation_andCannotLoop() {
        fakeHost!.fakeDocumentClient.revision = 5
        fakeHost!.fakeDocumentClient.rebaseResult = RichTextInputPosition(utf16Offset: 3)
        fakeHost!.fakeDocumentClient.revisionAfterRebase = 20
        backend.insertText("x")
        XCTAssertEqual(fakeHost!.fakeDocumentClient.rebaseCallCount, 1)
        XCTAssertEqual(fakeHost!.fakeDocumentClient.receivedExpectedRevisions, [5],
                       "must prepare at the ONE snapshot taken before rebasing (5) — reading " +
                       "document.revision again AFTER the rebase call would catch the knob's bump " +
                       "to 20 instead, which is exactly the live-re-read shape a looping " +
                       "implementation would keep chasing")
        fakeHost!.fakeDocumentClient.revisionAfterRebase = nil   // stop moving the target

        backend.insertText("y")
        XCTAssertEqual(fakeHost!.fakeDocumentClient.rebaseCallCount, 1,
                       "no staleness remains after (1) settled — a second rebase here would mean " +
                       "the mechanism keeps re-firing instead of settling")

        fakeHost!.fakeDocumentClient.revision = 40
        fakeHost!.fakeDocumentClient.rebaseResult = RichTextInputPosition(utf16Offset: 9)
        backend.insertText("z")
        XCTAssertEqual(fakeHost!.fakeDocumentClient.rebaseCallCount, 2,
                       "one new staleness must rebase exactly once more — not zero (forgetting to " +
                       "recheck), not more than once (looping)")
    }

    // MARK: - 4. A decreasing/mismatched external-change revision is refused, touching nothing else

    /// `BackendAttachmentTests` (Task 20) already pins TWO decreasing-revision shapes against a bare
    /// `DocumentCanvasView` with no shared event log: `oldRevision: 5, newRevision: 2` (a genuine
    /// same-baseline regression) and `oldRevision: 3, newRevision: 6` against a backend at 5 (a
    /// MISMATCH that does not itself regress). This test is deliberately a THIRD, un-covered
    /// combination — `oldRevision` mismatched AND `newRevision` itself decreasing ("doubly wrong") —
    /// and its own contribution is the flat, ordered EVENT LOG assertion `BackendAttachmentTests`
    /// structurally cannot make (it never wires the Task 22a shared log): the refusal must produce
    /// exactly one `contractViolation` and touch NOTHING else — no document read/rebase/prepare, no
    /// presentation apply, no lifecycle publish.
    ///
    /// RED IF: the change were adopted (`documentRevision` would move to 1, or `selection` would
    /// become `staleSelection`), no violation were reported, or the refusal leaked into any other
    /// client (a non-empty `log.kinds` beyond the one violation).
    func test_decreasingRevisionFromExternalChange_isAContractViolation_andIsNotAdopted() {
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: 1, newRevision: 5, reason: .documentReplacement,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: .downstream(0)), markedTextPolicy: .discard))
        XCTAssertEqual(backend.state.documentRevision, 5)
        log.reset()

        let staleSelection = RichTextCanonicalSelection.caret(at: .downstream(9))
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: 2, newRevision: 1, reason: .documentReplacement,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: staleSelection, markedTextPolicy: .discard))

        XCTAssertEqual(backend.state.documentRevision, 5,
                       "a decreasing/mismatched revision must not be adopted")
        XCTAssertNotEqual(backend.state.selection, staleSelection)
        XCTAssertEqual(log.kinds, ["contractViolation"],
                       "the refusal must touch nothing else — no presentation apply, no publish, " +
                       "no document access")
    }

    // MARK: - 5. `.layoutOnly` keeps the document revision, but still publishes exactly once

    /// Mirrors `BackendAttachmentTests.test_synchronizeWithLayoutOnlyKeepsTheDocumentRevision`'s
    /// revision-unchanged assertion (that coverage is not duplicated as a goal here — it is reused as
    /// a premise), and adds what that bare-canvas test cannot check: the SELECTION still adopts (only
    /// the revision counter is exempt) and the operation publishes exactly once end to end
    /// (`presentationApply` + `lifecyclePublish`, matching the single `publishState` call), with no
    /// contract violation reported.
    ///
    /// RED IF: `documentRevision` moved despite `.layoutOnly`, the new selection were NOT adopted, the
    /// operation published zero or more than once, or a spurious violation appeared.
    func test_layoutOnlyExternalChange_keepsTheDocumentRevision_andPublishesOnce() {
        let revisionBefore = backend.state.documentRevision
        let newSelection = RichTextCanonicalSelection.caret(at: .downstream(7))

        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: revisionBefore, newRevision: revisionBefore + 5, reason: .layoutOnly,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: newSelection, markedTextPolicy: .discard))

        XCTAssertEqual(backend.state.documentRevision, revisionBefore,
                       "a layout-only change must not move the document revision, even though " +
                       "newRevision advanced")
        XCTAssertEqual(backend.state.selection, newSelection,
                       "layout-only still adopts the new SELECTION — only the revision counter is untouched")
        XCTAssertEqual(log.count("lifecyclePublish"), 1)
        XCTAssertEqual(log.count("presentationApply"), 1)
        XCTAssertFalse(log.kinds.contains("contractViolation"))
    }

    // MARK: - 6. The non-collapsed selection rebases BOTH endpoints, and refuses if either fails

    /// FIX ROUND 1 — Critical 2: retargeted from the original (vacuous) test 6. Every OTHER test in
    /// this suite runs against the attach-seeded selection (`installInitialState` →
    /// `.caret(at: clamp(.downstream(0)))`), which is COLLAPSED (anchor == head), so
    /// `ensureCanonicalSelectionIsCurrent`'s non-collapsed branch (`else if let rebasedOther =
    /// document.rebase(currentHead, …)`) was entirely unpinned: replacing the whole branch with
    /// `rebasedHead = rebasedAnchor` — silently collapsing a REAL selection onto its rebased anchor,
    /// a data-loss-shaped bug — left every other test green.
    ///
    /// Part 1 drives a genuinely non-collapsed selection (anchor 2, head 5) through a stale mutation
    /// and proves BOTH endpoints are independently rebased, at THEIR OWN offsets (2 then 5 — not the
    /// same offset called twice, which `rebasedHead = rebasedAnchor` would also produce as "2 calls"
    /// if it happened to call rebase(anchor) twice, so the OFFSETS themselves are asserted, not just
    /// the count). Part 2 proves refusal when the SECOND (head) endpoint's rebase fails even though
    /// the first (anchor) succeeded, using the new `rebaseResultsQueue` knob to give the two calls
    /// different outcomes (a single shared `rebaseResult` cannot express this).
    ///
    /// RED IF: part 1's `rebaseOffsets` were `[2, 2]` or `[5, 5]` (the branch collapsed onto one
    /// endpoint) or `rebaseCallCount` were 1; or part 2's mutation reached `prepareMutation` despite
    /// the second endpoint's nil rebase.
    func test_nonCollapsedSelection_rebasesBothEndpoints_andRefusesIfEitherFails() {
        backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(2), head: .downstream(5)),
                             reason: .programmatic)
        log.reset()   // clear setSelection's own publish noise — irrelevant to this test

        // Part 1: both endpoints rebase, at their own distinct offsets.
        fakeHost!.fakeDocumentClient.revision = 9
        fakeHost!.fakeDocumentClient.rebaseResult = RichTextInputPosition(utf16Offset: 20)
        backend.insertText("x")
        XCTAssertEqual(fakeHost!.fakeDocumentClient.rebaseCallCount, 2)
        let rebaseOffsets = log.events.compactMap { event -> Int? in
            if case .documentRebase(let offset, _) = event { return offset }
            return nil
        }
        XCTAssertEqual(rebaseOffsets, [2, 5],
                       "each endpoint must be rebased at ITS OWN offset — not the same offset twice")

        // Part 2: a fresh non-collapsed selection goes stale again, but the SECOND rebase call
        // (head) fails — the whole mutation must be refused, not silently accepted with a
        // half-rebased selection.
        backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(1), head: .downstream(4)),
                             reason: .programmatic)
        log.reset()
        fakeHost!.fakeDocumentClient.revision = 15
        fakeHost!.fakeDocumentClient.rebaseResultsQueue = [RichTextInputPosition(utf16Offset: 30), nil]
        let receivedMutationsBefore = fakeHost!.fakeDocumentClient.receivedMutations.count

        backend.insertText("y")

        XCTAssertEqual(fakeHost!.fakeDocumentClient.receivedMutations.count, receivedMutationsBefore,
                       "a failed SECOND-endpoint rebase must never reach prepareMutation")
        XCTAssertEqual(fakeHost!.fakeLifecycleClient.lastRejectionReason, .revisionMismatch)
    }

    // Originally a 7th test here pinned that, against the REAL `TelegramDocumentInputClient`, a stale
    // rebase always rejects (D32 construction) by constructing a real `DocumentCanvasView` + its
    // default backend. FIX ROUND 2: relocated to
    // `TelegramDocumentInputClientMutationTests.test_rebase_isIdentityAtTheCurrentRevision_andNilOtherwise`
    // (`final`, legacy-client-specific) — a `BackendContractCases` subclass must never construct a
    // concrete backend or canvas outside `makeBackend()` (see the plan's Task 22c entry and the new R10
    // source-boundary rule, `InputBackendSourceBoundaryTests.test_noConcreteBackendNamedOutsideMakeBackend_R10`,
    // for why: this suite is inherited verbatim by stage 2, which would have silently kept exercising
    // the LEGACY backend/canvas no matter what `makeBackend()` returned). This suite is 6 tests.
}
#endif

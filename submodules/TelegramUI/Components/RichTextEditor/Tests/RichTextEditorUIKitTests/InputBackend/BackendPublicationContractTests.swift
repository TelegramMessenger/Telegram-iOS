#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Task 22d, the third of eight contract suites (22b-22i). Pins the backend's PUBLICATION contract:
/// `publishState(reason:)` is the single path by which state reaches the host — every operation
/// publishes through it exactly the number of times the operation's own shape implies (one for a
/// committed mutation, one for a whole-selection write, one per coalesced drag — never zero when
/// something changed, never more than the operation's own count), always presentation-then-lifecycle,
/// always after any did-change delegate notifications.
///
/// Adjacent suites own the rest of the mutation shape: ordering/notification mechanics are 22b's,
/// revision/rebase semantics are 22c's, marked-text policy is 22e's, reentrancy is 22f's, edit policy
/// is 22i's — this suite only counts and orders publications.
///
/// `class`, not `final class` — Task 22a's `BackendContractCases` is subclassed again by stage 2,
/// which overrides ONLY `makeBackend()`. The only place this file names a concrete backend type is
/// that override, below.
@MainActor
@available(iOS 16.0, *)
class BackendPublicationContractTests: BackendContractCases {
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
    /// 3 of this suite's 8 tests drive `insertText` as the operation whose publications they count; the
    /// other five drive selection/coalescing/detach, all forwarded unchanged.
    override func makeBackend() -> (any RichTextInputBackend)? {
        ReferenceMutationBackend()
    }

    /// Needed for `test_publicationFollowsDidChangeNotifications`, which orders publication against
    /// the delegate's did-change notifications — bypassing canvas plumbing exactly like
    /// `BackendMutationContractTests` does (this suite tests the backend in isolation).
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

    // MARK: - 1. The worked example: presentationApply always precedes lifecyclePublish

    /// The spec's step 9 does NOT fix the order of presentationApply vs lifecyclePublish, so this
    /// FREEZES whatever Phase 0 recorded. If it ever fails, the seam changed an observable order —
    /// do not "fix" the expectation without re-running the Phase-0 golden traces.
    func test_presentationApplyAndLifecyclePublish_keepTheirPinnedOrder() {
        backend.insertText("x")
        let apply = log.index(of: "presentationApply")
        let publish = log.index(of: "lifecyclePublish")
        XCTAssertNotNil(apply); XCTAssertNotNil(publish)
        XCTAssertLessThan(apply!, publish!, "presentation is applied before the state is published")
    }

    // MARK: - 2. One committed mutation publishes exactly one snapshot — contrasted against zero

    /// Vacuity guard: a "publishes exactly once" assertion is meaningless if the fake publishes
    /// unconditionally regardless of path, so this drives a REJECTED preparation first (which must
    /// publish zero times — `BackendMutationContractTests` already pins this in isolation; this test's
    /// own contribution is using it as the CONTRAST for the count below) before the real, committed
    /// mutation that must publish exactly once. Also pins the reason string is `"content"` for a real
    /// mutation — the contrasting reason case (`"selection"`) is pinned by test 4 below, so a swap
    /// between the two reasons is caught by ONE of the two tests either way.
    ///
    /// RED IF: the rejected preparation published anything (would break the very contrast this test
    /// relies on), the real mutation published zero or more than once, or `publishState` were ever
    /// called with a hardcoded reason unrelated to the actual operation.
    func test_oneMutation_publishesExactlyOneSnapshot() {
        fakeHost!.fakeDocumentClient.nextPreparationRejection = .invalidRange
        backend.insertText("x")
        XCTAssertEqual(log.count("presentationApply"), 0,
                       "a terminal rejection must not publish — establishes the contrast for below")
        XCTAssertEqual(log.count("lifecyclePublish"), 0)
        log.reset()

        // `nextPreparationRejection` is one-shot (consumed above), so this is a genuine .ready commit.
        backend.insertText("y")
        XCTAssertEqual(log.count("presentationApply"), 1)
        XCTAssertEqual(log.count("lifecyclePublish"), 1)
        let reasons = log.events.compactMap { event -> String? in
            if case .lifecyclePublish(_, let reason) = event { return reason }
            return nil
        }
        XCTAssertEqual(reasons, ["content"])
    }

    // MARK: - 3. Publication follows BOTH did-change delegate notifications

    /// Distinct from test 1 (which only orders the two publication calls against each other): this
    /// pins that the delegate's did-change notifications — which the host's keyboard/autocorrect
    /// machinery reacts to — are fully done before ANY publication reaches presentation/lifecycle.
    ///
    /// RED IF: `runMutation` ever published before `notifySelectionDidChange`/`notifyTextDidChange`
    /// (e.g. a reordering that moved the publish step earlier "for efficiency").
    func test_publicationFollowsDidChangeNotifications() {
        backend.insertText("x")
        let selectionDidChange = log.index(of: "delegateSelectionDidChange")
        let textDidChange = log.index(of: "delegateTextDidChange")
        let publish = log.index(of: "lifecyclePublish")
        XCTAssertNotNil(selectionDidChange); XCTAssertNotNil(textDidChange); XCTAssertNotNil(publish)
        XCTAssertLessThan(selectionDidChange!, publish!)
        XCTAssertLessThan(textDidChange!, publish!)
    }

    // MARK: - 4. A selection-only change publishes with reason .selection and touches no text delegate calls

    /// `setSelection` is not modeled as a document mutation (spec: "Programmatic selection ... is not
    /// modeled as a document mutation"), so it must never call the two TEXT delegate notifications —
    /// only `RichTextKeyInputBackend` mutations (routed through `runMutation`) do that. Also pins the
    /// reason string `"selection"` — the contrasting `"content"` case is test 2 above, so a swapped
    /// reason is caught by one of the two tests regardless of which way it's swapped.
    ///
    /// RED IF: `setSelection` ever called `notifyTextWillChange`/`notifyTextDidChange` (would make this
    /// indistinguishable from a real mutation), or published with any reason other than `.selection`.
    func test_selectionOnlyChange_publishesReasonSelection_andEmitsNoTextNotifications() {
        backend.setSelection(.caret(at: .downstream(3)), reason: .programmatic)

        XCTAssertEqual(log.count("delegateTextWillChange"), 0)
        XCTAssertEqual(log.count("delegateTextDidChange"), 0)
        XCTAssertEqual(log.count("presentationApply"), 1)
        XCTAssertEqual(log.count("lifecyclePublish"), 1)
        let reasons = log.events.compactMap { event -> String? in
            if case .lifecyclePublish(_, let reason) = event { return reason }
            return nil
        }
        XCTAssertEqual(reasons, ["selection"])
    }

    // MARK: - 5. An equal selection still publishes — not a change-detecting cache

    /// `setSelection`'s own doc comment: "Deliberately unconditional: an equal selection still
    /// publishes exactly once ... this is a report of 'selection was set', not a change-detecting
    /// cache." Driven TWICE, against two DIFFERENT already-current values, so a plausible
    /// `guard selection != canonicalSelectionStorage else { return }` early-out can't slip through by
    /// only guarding the very first call in the test.
    ///
    /// RED IF: `setSelection` ever gained an equality short-circuit against the stored selection —
    /// the call below would then publish ZERO times instead of one.
    ///
    /// FIX ROUND 1 (Minor 5): trimmed to its NOVEL contribution.
    /// `BackendAttachmentTests.test_setSelectionWithAnEqualSelectionPublishesOnce` already pins the
    /// attach-seeded-value case (the source doc comment on `setSelection` cites that test by name) —
    /// this test no longer duplicates it. Its own contribution is a SECOND, different
    /// already-current value, so a guard that only defeats the very first assertion a test happens
    /// to make can't slip through.
    func test_repeatedSetSelectionWithAnEqualSelection_publishesOnce() {
        // A value already equal to itself (not the attach-seeded one — see
        // `BackendAttachmentTests` above): set it once (becomes current), then set the SAME value
        // again — genuinely "equal to what's now current".
        let second = RichTextCanonicalSelection.caret(at: .downstream(5))
        backend.setSelection(second, reason: .programmatic)
        log.reset()
        backend.setSelection(second, reason: .programmatic)
        XCTAssertEqual(log.count("presentationApply"), 1)
        XCTAssertEqual(log.count("lifecyclePublish"), 1)
    }

    // MARK: - 6. A coalesced selection drag publishes exactly one snapshot, at the end

    /// SELF-DISCLOSED POLICY (not dictated by the brief or the spec — see the doc comment on
    /// `suppressesSelectionNotifications` in `LegacyRichTextInputBackend.swift`, added by this task):
    /// while that flag is `true`, `setSelection` updates `canonicalSelectionStorage` but defers
    /// publication; flipping it back to `false` publishes exactly once, reflecting the LAST selection
    /// set during the suppressed run. This is the only lever this stage-1 backend exposes for a
    /// coalesced multi-sample drag — no begin/end-drag method exists on `RichTextInputBackend` yet
    /// (that is Task 26's job — FIX ROUND 2: corrected from "Task 31", the plan's `:6280` gives this
    /// flag to family 3, not the unrelated responder-lifecycle Task 31 — wire a real canvas gesture
    /// through this flag, mirroring the legacy canvas's own `coalescingSelectionNotifications` — which
    /// Task 26 duly turned into a forwarder onto this flag and TASK 43 deleted outright).
    /// Default `false` leaves every other test in
    /// every other suite byte-identical — verified by the full-suite run in this task's report.
    ///
    /// RED IF: `setSelection` ignored `suppressesSelectionNotifications` entirely (the three samples
    /// below would then publish three times, not zero, before the flag clears), the flag-clear failed
    /// to flush the deferred publish (zero publishes total instead of one), the settled selection
    /// after the flag clears reflected anything other than the LAST sample (e.g. the first, or an
    /// intermediate one — a plausible bug if the deferred publish captured stale state instead of
    /// reading it fresh at flush time), or (FIX ROUND 1, Major 2) the flush's reason were anything
    /// other than `"selection"` — the didSet's `publishState` call is the only publish site this
    /// suite doesn't otherwise pin a reason for, so a swap to e.g. `.content` (which would route to
    /// the WRONG host channel — `TelegramLifecycleInputClient` sends `.selection` to
    /// `onSelectionChange` and `.content` to `notifyContentSizeChanged()`) previously stayed green.
    func test_coalescedSelectionDrag_publishesExactlyOneSnapshotAtTheEnd() {
        backend.suppressesSelectionNotifications = true
        backend.setSelection(.caret(at: .downstream(1)), reason: .touch)
        backend.setSelection(.caret(at: .downstream(2)), reason: .touch)
        backend.setSelection(.caret(at: .downstream(3)), reason: .touch)
        XCTAssertEqual(log.count("presentationApply"), 0,
                       "samples during a coalesced drag must not publish")
        XCTAssertEqual(log.count("lifecyclePublish"), 0)

        backend.suppressesSelectionNotifications = false

        XCTAssertEqual(log.count("presentationApply"), 1)
        XCTAssertEqual(log.count("lifecyclePublish"), 1)
        XCTAssertEqual(backend.canonicalSelection, RichTextCanonicalSelection.caret(at: .downstream(3)),
                       "the settled selection must be the LAST sample, not the first or an intermediate one")
        let reasons = log.events.compactMap { event -> String? in
            if case .lifecyclePublish(_, let reason) = event { return reason }
            return nil
        }
        XCTAssertEqual(reasons, ["selection"])
    }

    // MARK: - 7. A pending coalesced latch does not survive detach — no flush, no leak (Major 1)

    /// `performDetachSteps()` (`+Attachment.swift`) now flips `suppressesSelectionNotifications`
    /// off as one of its teardown steps, AFTER `isAttached` has already gone `false` — D18 declares
    /// this teardown kills "the coalescing flag". Pins that a latch still outstanding at that point
    /// is dropped silently rather than publishing to a host that has just been declared closed to
    /// new operations.
    ///
    /// The `XCTAssertFalse` on the flag itself is what makes this test discriminating rather than
    /// vacuously green: a version that forgot to touch the flag AT ALL during detach would also read
    /// zero publishes here (nothing ever flips the flag, so the didSet never runs) — this asserts the
    /// flag DID get flushed (transitioned) AND that the flush produced no publish, which only the
    /// combination of "clear during detach" + "guard the flush on `isAttached`" satisfies together.
    ///
    /// RED IF: `LegacyRichTextInputBackend.swift`'s didSet lost its `isAttached` guard (the detach-time
    /// clear below would then publish to the host mid-detach instead of dropping silently), or
    /// `performDetachSteps` stopped clearing the flag at all (it would read back `true`, not `false`).
    func test_detachWithAPendingCoalescedLatch_publishesNothing() {
        backend.suppressesSelectionNotifications = true
        backend.setSelection(.caret(at: .downstream(2)), reason: .touch)
        XCTAssertEqual(log.count("lifecyclePublish"), 0, "still suppressed — no publish yet")

        backend.detach()

        XCTAssertFalse(backend.suppressesSelectionNotifications,
                       "detach must still drain the coalescing flag (D18) even though it must not publish")
        XCTAssertEqual(log.count("lifecyclePublish"), 0, "a detach must not flush a pending latch to the host")
        XCTAssertEqual(log.count("presentationApply"), 0)
    }

    // MARK: - 8. A latch set before detach() does not survive into the next attach (Major 1)

    /// Complements test 7 (which pins detach itself doesn't flush) by pinning that the NEXT session
    /// starts clean: a fresh `attach` inherits neither the suppression flag nor any pending latch
    /// from the torn-down one.
    ///
    /// RED IF: `performDetachSteps` failed to clear the flag (or something reordered around it) so
    /// `suppressesSelectionNotifications` or the pending latch survived across the attach boundary —
    /// the flag would read back `true` immediately after `attach` (caught directly below), and/or
    /// the fresh-host `setSelection` below would publish ZERO times instead of once: given
    /// `pending ⟹ flag` (the latch is only ever set while the flag is set, and both are cleared
    /// together), a survived flag leaves `setSelection` STILL suppressed, so it would only re-latch
    /// rather than publish — not "twice", as an earlier draft of this comment claimed; this is exactly
    /// what was observed when this test was red-checked against a `performDetachSteps` that skipped
    /// clearing the flag (fix round 2).
    ///
    /// FIX ROUND 2 (Major B): uses the fixture's `makeHost(log:)` factory rather than constructing
    /// `FakeInputHost` directly — a stage-2 subclass overriding `makeHost` must get ITS host here, not
    /// unconditionally the stage-1 fake (the same defect class R10 polices for backends, now R11 for
    /// hosts). `withExtendedLifetime` (fix round 2, Minor 3) keeps `freshHost` alive through the
    /// assertions below — `backend.host` holds it only WEAKLY, per the package's own convention
    /// (`TelegramLifecycleInputClient.swift`, `BackendAttachmentTests.swift`).
    func test_aPendingCoalescedLatchBeforeDetach_doesNotSurviveIntoTheNextAttach() throws {
        backend.suppressesSelectionNotifications = true
        backend.setSelection(.caret(at: .downstream(2)), reason: .touch)
        backend.detach()

        let freshHost = makeHost(log: log)
        try backend.attach(to: freshHost)
        withExtendedLifetime(freshHost) {
            log.reset()   // discard this attach's own lifecycleDidAttach noise

            XCTAssertFalse(backend.suppressesSelectionNotifications,
                           "a fresh attach must not inherit the previous session's coalescing flag")

            backend.setSelection(.caret(at: .downstream(4)), reason: .programmatic)
            XCTAssertEqual(log.count("lifecyclePublish"), 1,
                           "a survived latch/flag would leave setSelection still suppressed, so this " +
                           "would read 0 (a re-latch), not 1")
            XCTAssertEqual(log.count("presentationApply"), 1)
        }
    }
}
#endif

#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Proves the doubles themselves behave, since every one of Tasks 22b-22i's contract suites trusts
/// them. These are real assertions about the FAKES, not about contract behavior — that distinction is
/// this task's whole scope (no `Sources/` change, no contract assertions).
@MainActor
@available(iOS 16.0, *)
final class FakeClientSelfTests: XCTestCase {

    func test_finishFlagsAnUnconsumedPreparation() {
        let log = RichTextInputEventLog()
        let doc = FakeInputDocumentClient(log: log)

        guard case .ready = doc.prepareMutation(.unmarkText, expectedRevision: doc.revision) else {
            return XCTFail("expected a ready preparation")
        }
        XCTAssertFalse(doc.sawUnconsumedPreparation, "not flagged until finish() runs")
        doc.finish()
        XCTAssertTrue(doc.sawUnconsumedPreparation, "a prepared token was never committed")
    }

    func test_aSecondCommitOfTheSameTokenSetsSawDoubleCommit() {
        let log = RichTextInputEventLog()
        let doc = FakeInputDocumentClient(log: log)

        guard case .ready(let prepared) = doc.prepareMutation(.unmarkText, expectedRevision: doc.revision) else {
            return XCTFail("expected a ready preparation")
        }
        _ = doc.commitPreparedMutation(prepared)
        XCTAssertFalse(doc.sawDoubleCommit, "a single commit must not flag double-commit")
        _ = doc.commitPreparedMutation(prepared)
        XCTAssertTrue(doc.sawDoubleCommit, "committing the same token twice must be caught")
        // NOTE: `finish()`'s count-based check (`issuedTokens.count != consumedTokens.count`) also
        // trips here, since one issued token was committed twice — a separate, coincidental signal
        // from `sawDoubleCommit` above, not asserted by this test.
    }

    func test_typingAttributesReadCountIncrementsPerCall() {
        let log = RichTextInputEventLog()
        let doc = FakeInputDocumentClient(log: log)
        let position = RichTextInputPosition.downstream(0)

        XCTAssertEqual(doc.typingAttributesReadCount, 0)
        XCTAssertEqual(doc.typingAttributes(at: position).count, 0)
        XCTAssertEqual(doc.typingAttributesReadCount, 1)

        // Mutate BETWEEN two reads; the second read must see the change — proves nothing is cached.
        doc.typingAttributesByOffset[0] = [.foregroundColor: UIColor.red]
        let second = doc.typingAttributes(at: position)
        XCTAssertEqual(doc.typingAttributesReadCount, 2)
        XCTAssertEqual(second[.foregroundColor] as? UIColor, UIColor.red)
    }

    func test_theLogPreservesInsertionOrderAcrossTwoFakes() {
        let log = RichTextInputEventLog()
        let document = FakeInputDocumentClient(log: log)
        let lifecycle = FakeInputLifecycleClient(log: log)

        lifecycle.backendDidAttach()
        _ = document.plainText(in: NSRange(location: 0, length: 1))
        lifecycle.backendWillDetach()

        XCTAssertEqual(log.kinds, ["lifecycleDidAttach", "documentRead", "lifecycleWillDetach"],
                       "the three events, from two different fakes, must appear in call order")
    }

    func test_incompatibleFakeHostIsNotALegacyHost() {
        let log = RichTextInputEventLog()
        XCTAssertFalse(IncompatibleFakeHost(log: log) is any LegacyRichTextInputHost)
    }

    /// RELOCATED HERE from `BackendAttachDetachTests` (task-22h-review.md, Major 5): the original test
    /// lived in an INHERITED contract suite (`BackendContractCases`, which stage 2 subclasses overriding
    /// ONLY `makeBackend()`) but could only ever pin `FakeInputPresentationClient`'s own stored `let
    /// containerView` — nothing in `LegacyRichTextInputBackend` reads `interactionContainerView` yet
    /// (`installInteractions()` is still a Task-32 no-op stub), so stage 2 would have inherited a test
    /// that exercises the FAKE, never the backend under test. This file is the fixture's own
    /// self-consistency suite (a plain `XCTestCase`, not a `BackendContractCases` descendant — out of
    /// R10/R11's scope by the same ancestry walk those rules use), which is exactly where a test about
    /// the FAKE belongs.
    ///
    /// **TASK 32 DISCHARGED THE RECORDED FOLLOW-UP, and it had to correct its premise first.** The
    /// follow-up (`docs/superpowers/plans/2026-08-16-richtext-input-backend-seam.md`, Task 32) read:
    /// "once `installInteractions()` gets a real body that reads this property (to hand the container to
    /// real gesture recognizers), add a genuine BACKEND-level counterpart". **`installInteractions()`
    /// does not read it, and must not.** Its real body is a plain forward to
    /// `DocumentCanvasView.installSelectionInteractions()`, and
    /// `TelegramPresentationInputClient`'s own doc comment states the design in as many words:
    /// "`interactionContainerView` is the drawing plane only — it grants no interaction authority",
    /// the recognizers are installed directly on the canvas, and the container is
    /// `isUserInteractionEnabled = false`. Building an install path that handed the container to
    /// recognizers would have been a behaviour change and an architectural reversal.
    ///
    /// What the follow-up was PROTECTING is still reachable and was delivered instead:
    /// `InteractionRouterTests.test_interactionContainerViewIdentity_isStableAcrossTheBackendLifetime`
    /// attaches through the REAL `TelegramPresentationInputClient`, exercises operations across the
    /// backend's lifetime, and asserts the identity does not move — closing the zero-backend-coverage
    /// gap without inventing the install path. This test stays as the FIXTURE's own half.
    ///
    /// `FakeInputPresentationClient`'s own doc comment (Task 22a) already named this exact test as the
    /// reason `containerView` is a stored, not a freshly-constructed, `UIView`.
    ///
    /// RED-CHECK: temporarily changed `FakeInputPresentationClient.interactionContainerView` from
    /// `{ containerView }` to `{ UIView() }` (a fresh view per read). Confirmed
    /// `XCTAssertTrue(first === second)` failed at the OBSERVATION POINT (the second read), then
    /// reverted.
    func test_interactionContainerViewIdentity_isStableAcrossRepeatedReads() {
        let log = RichTextInputEventLog()
        let presentation = FakeInputPresentationClient(log: log)

        let first = presentation.interactionContainerView
        let second = presentation.interactionContainerView

        XCTAssertTrue(first === second,
                     "interactionContainerView must hand back the same view identity on every read")
    }

    // MARK: - Fixture-exercising probes (fix round: root cause of the failed review was that no
    // self-test ever ran `BackendContractCases.setUpWithError`/`tearDownWithError` for real — the only
    // subclass that ever executed was the skip probe, which skips before setUp does anything).
    //
    // These two construct a `BackendContractCasesFixtureTests` MANUALLY (never handed to the XCTest
    // runner) and call its lifecycle methods directly, so a deliberately-triggered teardown failure is
    // attributed to the CURRENTLY RUNNING test (this one) rather than corrupting `probe`'s own identity —
    // and `XCTExpectFailure` both consumes that failure (this test stays green) AND, in its default
    // strict mode, fails THIS test if the expected failure does NOT occur — i.e. these two tests would
    // themselves go RED if a future change dropped either teardown assertion. That is the verification
    // the review asked for: "verify the assertion fires rather than letting it fail your own test."

    /// RED if `tearDownWithError`'s `sawDoubleCommit` check is ever removed or short-circuited by the
    /// `sawUnconsumedPreparation` check running first and returning early (it must not: both must fire
    /// independently). Constructs the reviewer's exact counterexample — 2 tokens issued, 2 commit CALLS
    /// made (one token committed twice, the other never committed) — so the counts coincidentally
    /// balance and the count-based unconsumed check cannot see the problem on its own.
    func test_teardownFailsIndependently_onSawDoubleCommit_whenCountsCoincidentallyBalance() throws {
        let probe = BackendContractCasesFixtureTests()
        try probe.setUpWithError()
        let doc = try XCTUnwrap(probe.fakeHost?.fakeDocumentClient)

        guard case .ready(let tokenA) = doc.prepareMutation(.unmarkText, expectedRevision: doc.revision),
              case .ready = doc.prepareMutation(.unmarkText, expectedRevision: doc.revision) else {
            return XCTFail("expected two ready preparations")
        }
        _ = doc.commitPreparedMutation(tokenA)
        _ = doc.commitPreparedMutation(tokenA)   // double-commit; the OTHER token is never committed

        // Confirm the setup: counts balance (2 issued, 2 commit calls), so a count-only check would
        // see nothing wrong here — yet `sawDoubleCommit` is unambiguously true.
        XCTAssertEqual(doc.issuedTokens.count, doc.consumedTokens.count)
        XCTAssertTrue(doc.sawDoubleCommit)

        XCTExpectFailure("tearDownWithError must flag sawDoubleCommit independently of the balanced counts") { @MainActor in
            _ = try? probe.tearDownWithError()
        }
    }

    /// RED if `tearDownWithError`'s `sawUnconsumedPreparation` check is ever removed.
    func test_teardownFailsIndependently_onSawUnconsumedPreparation() throws {
        let probe = BackendContractCasesFixtureTests()
        try probe.setUpWithError()
        let doc = try XCTUnwrap(probe.fakeHost?.fakeDocumentClient)

        guard case .ready = doc.prepareMutation(.unmarkText, expectedRevision: doc.revision) else {
            return XCTFail("expected a ready preparation")
        }
        // Never committed.
        XCTAssertFalse(doc.sawDoubleCommit, "this case must be independent of the double-commit flag")

        XCTExpectFailure("tearDownWithError must flag an unconsumed preparation") { @MainActor in
            _ = try? probe.tearDownWithError()
        }
    }
}

/// The fixture-exercising subclass the review asked for: a REAL `BackendContractCases` subclass whose
/// `setUpWithError`/`tearDownWithError` actually run (either via the normal XCTest runner, for the two
/// test methods below, or manually via direct calls from `FakeClientSelfTests` above). Overrides ONLY
/// `makeBackend()`, exactly the shape Tasks 22b-22i and stage 2 use.
@MainActor
@available(iOS 16.0, *)
final class BackendContractCasesFixtureTests: BackendContractCases {
    override func makeBackend() -> (any RichTextInputBackend)? {
        LegacyRichTextInputBackend()
    }

    /// Catches a missing `log.reset()` after attach. `attach()` calls `backendDidAttach()`, which the
    /// fake logs (`.lifecycleDidAttach`) — without the reset every one of 22b-22i's test bodies would
    /// see that noise as the first entry in `log.kinds`, unless each author defensively reset it
    /// themselves (defeating the point of a shared base class).
    func test_logIsEmptyAtTheStartOfATestBody() {
        XCTAssertTrue(log.kinds.isEmpty,
                     "attach noise must be reset before the test body runs; got \(log.kinds)")
    }

    /// Catches an unwired `RichTextInputContractViolation.reporter`. Deliberately triggers the spec's
    /// documented "operation on a detached backend" failure class (exactly the reviewer's repro) and
    /// confirms it is OBSERVED via the log rather than trapping the process — an unwired reporter falls
    /// through to `assertionFailure`, which crashes the whole xctest runner in DEBUG (the same
    /// crash-reads-as-a-gap pattern as the `description` recursion this task already found once).
    /// Simply reaching the final assertion already proves no crash happened: a trapped
    /// `assertionFailure` would have killed the process before execution could return here.
    func test_aContractViolationIsObservedInTheLog_notCrashed() {
        backend.detach()
        log.reset()   // isolate: detach's own bookkeeping is not the violation under test
        backend.setSelection(.caret(at: .downstream(0)), reason: .programmatic)
        XCTAssertTrue(log.contains("contractViolation"),
                     "a detached-backend operation must be recorded via the reporter, not crash")
    }
}
#endif

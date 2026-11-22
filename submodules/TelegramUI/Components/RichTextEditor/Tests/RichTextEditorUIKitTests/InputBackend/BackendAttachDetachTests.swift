#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Task 22h, the seventh of eight contract suites (22b-22i). Pins ATOMIC `attach(to:)` and TERMINAL,
/// IDEMPOTENT `detach()` — purely through the `any RichTextInputBackend`/`any RichTextInputHost`
/// surface, never a concrete type. `BackendAttachmentTests` (Task 20, `final`, legacy-only, 24 tests)
/// already covers the nine-step teardown ORDER against `LegacyRichTextInputBackend.pendingRoutingCalls`
/// (a static array this suite cannot and must not reference — R10), the continuity-guard rejections,
/// the `detachRequested` latch, the transaction-depth backstops, and `finalizeMarkedTextForDetach`.
/// Every test below is deliberately re-homed on the SHARED `log` (the one observable surface a genuine
/// third-party conformer would also produce) rather than restated against that legacy-only bookkeeping
/// — see each test's own comment for exactly what it adds beyond `BackendAttachmentTests`.
///
/// **TASK 34 FIX ROUND 1 (review Minor 3) — `pendingRoutingCalls` is no longer "stub-call
/// bookkeeping", and this file said so in two places.** Task 34 deleted the `pendingRouting(_:)` funnel
/// that wrote it; the array survives as a **test-only recording buffer with a production-symbol name**,
/// appended to solely by `BackendAttachmentTests`' own fake-client hooks. The R10 prohibition on naming
/// it from THIS suite is unchanged and is the reason the wording matters at all — a reader here can
/// only meet the array through these sentences. Its declaration in `+Unwitnessed.swift` carries the
/// full disclosure, including the consequence: an assertion of the form "driving X records no stub
/// call" is now true by construction rather than by test.
///
/// `class`, not `final class` — Task 22a's `BackendContractCases` is subclassed again by stage 2, which
/// overrides ONLY `makeBackend()`. The only place this file names `LegacyRichTextInputBackend` is that
/// override, below (R10).
///
/// FIX ROUND 1 (task-22h-review.md, Minor 2): `test_attachFailure_leavesNoResidue` needs a
/// deliberately INCOMPATIBLE host (`IncompatibleFakeHost`, a Task 22a fixture) to drive `attach`'s
/// rejection path — the one case `FakeInputHost` cannot exercise by construction. That mechanism
/// (`nextHostIsIncompatible` + a `makeHost(log:)` override honoring it) now lives on
/// `BackendContractCases` ITSELF, not a per-file override here — moved there so any suite (this one,
/// 22i, or a later one) can opt in without duplicating the flag/override pair. This file therefore sets
/// the INHERITED `nextHostIsIncompatible` directly; there is nothing else to see here.
@MainActor
@available(iOS 16.0, *)
class BackendAttachDetachTests: BackendContractCases {
    override func makeBackend() -> (any RichTextInputBackend)? {
        LegacyRichTextInputBackend()
    }

    // MARK: - 1. attach atomicity: a rejected attach leaves nothing installed

    /// Atomicity: on a failed attach NOTHING may remain installed. Asserting only `fresh.isAttached ==
    /// false` would pass with a half-installed backend that had, say, already called the lifecycle
    /// client's `backendDidAttach()` before discovering the host is the wrong shape — this is the
    /// failure this test exists to catch, via the ONE shared, ordered log every one of the incompatible
    /// host's six fake clients writes into (constructed with the SAME `log` this class shares, via the
    /// sanctioned `makeHost(log:)` override on `BackendContractCases` — not a bespoke, unobserved log).
    ///
    /// FIX ROUND 1 (task-22h-review.md, Minor 3): `incompatibleHost` is a second, locally-made host that
    /// escapes `tearDownWithError`'s default token-hygiene gate (`sawDoubleCommit`/
    /// `sawUnconsumedPreparation`, checked only against `self.fakeHost`). Harmless HERE: the rejected
    /// attach never reaches this host's document client at all (that is exactly what `log.kinds.isEmpty`
    /// below proves), so there is no prepared token for the gate to have missed.
    ///
    /// WHAT THIS ADDS OVER `BackendAttachmentTests`: that suite's own
    /// `test_attachIsAtomic_aThrowingAttachLeavesNothingInstalled` pins the SAME property against
    /// `SpyBackend` (an independent, hand-written `RichTextInputBackend` conformer built to test the
    /// CANVAS's injection seam) — it does not exercise `LegacyRichTextInputBackend`'s own
    /// `.incompatibleHost` rejection branch at all. This test exercises exactly that branch, against the
    /// REAL backend, and — because every host client here writes into the shared log — proves NONE of
    /// the six clients (not just the two `BackendAttachmentTests.test_aFailingAttachIsReportedNotSwallowed`
    /// happens to check) were ever touched.
    ///
    /// FIX ROUND 1 (task-22h-review.md Major 2): asserts the specific `.incompatibleHost` error CASE,
    /// not merely that "some error" was thrown — this is the only test anywhere in the tree of
    /// `attach`'s `.incompatibleHost` branch (a tree-wide grep for `incompatibleHost` finds hits only in
    /// the enum declaration, `+Attachment.swift`, fixture doc comments, and this test), so asserting
    /// just `XCTAssertThrowsError` would keep this test green even if `attach(to:)` started throwing
    /// `.alreadyAttached` or `.missingCapability` for an incompatible host instead — a materially
    /// different, wrong error. Test 2 below already sets this precedent; matched here.
    ///
    /// FIX ROUND 1 (task-22h-review.md Major 3) — RECORDED, NOT FIXED WITH A PRODUCTION CHANGE:
    /// `attach(to:)`'s `do/catch` around `installInitialState(from:)` exists to roll back `self.host`/
    /// `isAttached` if that call throws — but `installInitialState` (`LegacyRichTextInputBackend.swift`)
    /// only calls `RichTextInputDocumentClient.revision`/`.clamp(_:)`, and BOTH are declared non-throwing
    /// on the protocol. So that `catch` branch is DEAD CODE today, with zero coverage: the ONLY failure
    /// this test (or any test) can drive is the EARLIER, pre-install narrowing-guard rejection below,
    /// which returns before `self.host` is ever assigned and before `installInteractions()` runs — i.e.
    /// before there is anything to roll back. `fresh.isAttached == false` and `log.kinds.isEmpty` are
    /// therefore proven by "the rejection happens before install", not by "a rollback undid an
    /// install" — a real but narrower claim than "atomicity is pinned" might suggest. Deliberately NOT
    /// fixed by adding a throwing path to `installInitialState` to make the rollback reachable — that
    /// would be inventing production behavior to serve a test. Recorded against Task 39b (the task that
    /// wires `.initialDocument`/host-originated document synchronization, and therefore the most likely
    /// place `installInitialState`'s failure mode might eventually become real) in the plan.
    ///
    /// RED-CHECK: temporarily changed the `guard let legacyHost = host as? any LegacyRichTextInputHost
    /// else { throw … }` in `LegacyRichTextInputBackend+Attachment.swift`'s `attach(to:)` to `else {
    /// return }` (swallowing the incompatibility instead of rejecting it) — confirmed
    /// `XCTAssertThrowsError` failed (no error thrown) at the OBSERVATION POINT immediately after the
    /// call, then reverted.
    func test_attachFailure_leavesNoResidue() throws {
        nextHostIsIncompatible = true
        let incompatibleHost = makeHost(log: log)
        let fresh = try XCTUnwrap(makeBackend(), "makeBackend() must hand back a fresh, unattached instance")

        var thrown: Error?
        XCTAssertThrowsError(try fresh.attach(to: incompatibleHost)) { thrown = $0 }
        guard case .incompatibleHost = thrown as? RichTextInputBackendAttachmentError else {
            return XCTFail("expected .incompatibleHost, got \(String(describing: thrown))")
        }
        XCTAssertFalse(fresh.isAttached)
        XCTAssertTrue(log.kinds.isEmpty,
                     "a rejected attach must not touch ANY of the incompatible host's clients — not " +
                     "the lifecycle client's backendDidAttach, not the presentation client's apply or " +
                     "tearDownPresentation, nothing at all; got \(log.kinds)")
    }

    // MARK: - 2. attach atomicity: attaching twice throws and preserves the first attachment

    /// Attaching an ALREADY-attached backend a second time must throw `.alreadyAttached`, leave the
    /// FIRST attachment's published state untouched, AND never touch the second host at all — not even
    /// a read of its document client's revision (proven by giving the second host a document revision
    /// that would be trivially distinguishable — 99 — if it were ever consulted).
    ///
    /// FIX ROUND 1 (task-22h-review.md, Minor 1): the discriminator that carries this test's red is the
    /// SECOND host's document revision (99) — so a silent `(secondHost as? FakeInputHost)?...` no-op on
    /// a failed cast would quietly remove that discriminator and let the test pass vacuously regardless
    /// of what `attach(to:)` actually does. `try XCTUnwrap(...)` makes a cast failure LOUD (fails the
    /// test with a clear reason) instead of silently defeating the assertion below it.
    ///
    /// FIX ROUND 1 (Minor 3, same as test 1): `secondHost` is a second, locally-made host outside the
    /// default token-hygiene gate. Harmless here — the rejected re-attach never reaches its document
    /// client (`log.kinds.isEmpty` below proves it), so nothing is ever prepared against it.
    ///
    /// WHAT THIS ADDS OVER `BackendAttachmentTests`: that suite's own
    /// `test_attachTwiceThrowsAlreadyAttached_andPreservesTheFirstAttachment` reads `backend.host`
    /// directly (a `LegacyRichTextInputBackend`-only, `internal` property) to prove host identity is
    /// unchanged. This test cannot and does not do that (R10) — instead it proves the SAME "nothing
    /// changed" property through the only surface a third-party conformer offers: the published
    /// `state`/`canonicalSelection`, and the second host's OWN event log staying empty. That is a
    /// STRONGER property than host-identity-unchanged: it additionally proves the second host's document
    /// client was never even READ, not merely that its result was discarded.
    ///
    /// RED-CHECK: temporarily deleted the `guard !isAttached else { throw
    /// RichTextInputBackendAttachmentError.alreadyAttached }` line from `attach(to:)`. With it gone, the
    /// second `attach(to:)` call proceeds to `installInitialState(from:)`, which reads the SECOND host's
    /// `documentClient.revision` (99) and reseeds `documentRevision` — confirmed
    /// `XCTAssertEqual(backend.state.documentRevision, revisionBefore)` failed (observed 99, not the
    /// first host's seeded revision of 1 — `FakeInputDocumentClient`'s default) at the OBSERVATION POINT
    /// after the (no-longer-throwing) call, then reverted.
    func test_attachTwice_throwsAlreadyAttached_andPreservesTheFirstAttachment() throws {
        XCTAssertTrue(backend.isAttached)
        let revisionBefore = backend.state.documentRevision
        let selectionBefore = backend.canonicalSelection

        let secondHost = makeHost(log: log)
        try XCTUnwrap(secondHost as? FakeInputHost, "expected the default FakeInputHost shape").fakeDocumentClient.revision = 99
        log.reset()   // discard any construction noise (there is none today; hygienic regardless)

        var thrown: Error?
        XCTAssertThrowsError(try backend.attach(to: secondHost)) { thrown = $0 }
        if case .alreadyAttached = thrown as? RichTextInputBackendAttachmentError {
            // expected
        } else {
            XCTFail("expected .alreadyAttached, got \(String(describing: thrown))")
        }

        XCTAssertTrue(backend.isAttached, "the first attachment must survive a rejected second attach")
        XCTAssertEqual(backend.state.documentRevision, revisionBefore,
                       "a rejected re-attach must not adopt the second host's document revision")
        XCTAssertEqual(backend.canonicalSelection, selectionBefore,
                       "a rejected re-attach must not touch the first host's published selection")
        XCTAssertTrue(log.kinds.isEmpty,
                     "a rejected re-attach must not touch the second host's clients at all; got \(log.kinds)")
        withExtendedLifetime(secondHost) {}
    }

    // MARK: - 3. detach is idempotent: a second call is a pure no-op

    /// A second `detach()` call, once already detached, must do nothing observable a second time.
    ///
    /// FIX ROUND 1 (task-22h-review.md, Focal point 1 — replaces the previous version of this comment,
    /// which framed the finding as "I could not find a mutation"; the review found one, and rejected
    /// strengthening this test with it). The deeper, correct framing is STRUCTURAL: at the contract
    /// level, `detach()`'s idempotence is OVER-DETERMINED. Any conformer that (i) releases its host
    /// during teardown (`performDetachSteps()`'s step 9) AND (ii) refuses every operation while detached
    /// (the per-member `isAttached` guard each mutating member is independently required to have) makes a
    /// REPEATED teardown unobservable through the client surface BY CONSTRUCTION — every observable route
    /// goes through the now-released host, and the detached backend's own state is frozen. Both (i) and
    /// (ii) are independently mandated by the contract, so this test is UNFALSIFIABLE against any
    /// conformer that satisfies the rest of the contract, and becomes falsifiable EXACTLY for a conformer
    /// that fails to release its host on detach — a live possibility for a future TextKit-2 stage-2
    /// backend, which may carry plenty of non-host teardown state. That is why this test is worth
    /// inheriting, and it is a materially better justification than "I could not find a mutation".
    ///
    /// TWO STRENGTHENINGS WERE CONSIDERED AND REJECTED (both found by the review, both real, both
    /// exploit an ACKNOWLEDGED missing guard rather than the idempotence mechanism itself):
    /// (a) `beginFloatingCursor(at:)` carries NO `isAttached` guard (`LegacyRichTextInputBackend.swift`'s
    /// own doc comment: "`begin`/`end` … carry no `isAttached` guard, so the combination is reachable in
    /// principle — Task 33 should add it"), so `detach()` → `beginFloatingCursor(at:)` (sets
    /// `floatingCursorActive = true` despite being detached) → a second `detach()` (clears the flag via
    /// `performDetachSteps()`) → `selectedTextRange = …` (now falls through the setter's
    /// `!floatingCursorActive` guard into `setSelection`, which DOES check `isAttached` and reports a
    /// violation it would have suppressed had the flag still been set) is a real, TODAY-reachable back
    /// door. (b) an analogous `markedRangeStorage`/`isComposing` variant via `setMarkedText`, if that
    /// member is likewise ever left unguarded. (TASK 29 CORRECTION: back door (b) no longer exists on
    /// this class at all — Task 29 routed `setMarkedText` as a plain `legacyCanvas` forward that writes
    /// no backend storage; the guarded storage body, `isAttached` check included, is
    /// `ReferenceMutationBackend`'s. Only (a) remains, still Task 33's.)
    /// REJECTED for both: the moment Task 33 adds
    /// the `isAttached` guard the contract already requires for that member, the back door closes, and
    /// the strengthened assertion would decay to VACUOUS — still green, still named "idempotent", now
    /// pinning nothing, with no signal that anything changed. Paying for one red check today at the cost
    /// of a SILENT vacuity later, once the acknowledged gap it depends on is closed, is a bad trade —
    /// exactly the "reads as coverage" failure mode this project has been burned by before. So this test
    /// stays a documented characterization, not strengthened onto either back door.
    ///
    /// DROPPING WAS ALSO CONSIDERED AND REJECTED: `BackendAttachmentTests` is `final class
    /// BackendAttachmentTests: XCTestCase` and legacy-only, so stage 2 inherits NOTHING from it — dropping
    /// this test would leave stage 2 with ZERO `detach()` idempotence coverage. Keep.
    ///
    /// FIX ROUND 1 (Minor 4), CORRECTED IN FIX ROUND 2 (task-22h-review.md's own correction: this was
    /// the reviewer's error, not a defect in the test): the detached-operation rejection assertion this
    /// test used to also carry duplicated test 5 (`test_operationAfterDetach_isRejected_andPublishesNothing`)
    /// with no distinct property, so it stayed removed. But the "first detach() produced something
    /// observable" assertion below is NOT the same property test 4
    /// (`test_detachOrder_matchesTheSpecifiedSequence`) pins, and removing it was wrong: test 4 asserts
    /// the EXACT content and order of the detach log (`["presentationTearDown", "lifecycleWillDetach"]`)
    /// — precisely the assertion a stage-2 port is expected to EDIT if its own client sequence differs.
    /// If this test relied on test 4 for its own "something happened" precondition, a stage-2 backend
    /// that edits test 4's exact-equality assertion to match its own sequence would leave THIS test
    /// tautologically comparing an empty log to an empty log, with NO signal that anything is wrong. A
    /// test in an inherited suite must carry its own control, not lean on a sibling's assertion that the
    /// port is expected to change. Restored below.
    ///
    /// WHAT THIS ADDS OVER `BackendAttachmentTests`: that suite's own `test_detachIsIdempotent` observes
    /// idempotency through `LegacyRichTextInputBackend.pendingRoutingCalls` (the static recording array
    /// this suite is forbidden from naming — R10; it was "stub-call bookkeeping" when this sentence was
    /// written and TASK 34 retired the funnel that made it so — see this file's header) and USED TO go
    /// red under the mutation
    /// below (confirmed at the time: `"5" is not equal to "3"` — the stub interaction calls fire a
    /// second time) — that legacy-only observable is why `BackendAttachmentTests` remained load-bearing
    /// and was not superseded by this suite.
    ///
    /// **TASK 32 RETIRED THAT OBSERVABLE, and the correction is recorded here because this is where the
    /// claim was written.** The two stubs it counted (`cancelActiveInteraction(reason:)`,
    /// `removeInteractions()`) are now real bodies that reach the canvas through `legacyCanvas` — i.e.
    /// through `host`, which step 9 has already released — so on a second pass they are optional-chained
    /// no-ops exactly like steps 7 and 8. **Every remaining step of `performDetachSteps()` is now
    /// host-gated, so the RED-CHECK below is over-determined for the sibling suite too**, not just for
    /// this one. `BackendAttachmentTests.test_detachIsIdempotent` carries the same note and gained a
    /// first-detach control (this test's own construction) in the same commit.
    ///
    /// **TASK 32 FIX ROUND 1 (review Major 2) RESTORED THE PIN — in the sibling suite only, and the
    /// asymmetry is a property of R10 rather than an oversight.** The observable that does not route
    /// through `host` is `performDetachSteps()`'s own hygiene resets (`floatingCursorActive`,
    /// `activeTransactionDepth`): poison them after the first detach and they survive a second one iff
    /// the guard holds. **This suite cannot use it.** R10 forbids a `BackendContractCases` descendant
    /// from naming a concrete backend outside `makeBackend()`, and `backend` here is typed `any
    /// RichTextInputBackend`, whose surface carries neither field — they are `LegacyRichTextInputBackend`
    /// internals by construction. So for the INHERITED suite the loss is permanent, and this test's own
    /// claim is the narrower one it can honestly make: the first detach did something observable through
    /// the shared `log`, and the second added nothing to it. The RED-CHECK paragraph below stands as the
    /// record of why that is over-determined here.
    ///
    /// RED-CHECK ATTEMPTED: deleted `detach()`'s `guard isAttached else { return }` guard entirely and
    /// ran the WHOLE suite against it (7 tests at the time; this suite is 6 as of fix round 1, test 7
    /// having been re-homed to `FakeClientSelfTests` — the count is incidental to this finding). Every
    /// test still passed: by the time a second call could run `performDetachSteps()` again, step 9 of
    /// the FIRST call has already set `host = nil`, so `host?.presentationClient.tearDownPresentation()`
    /// / `host?.lifecycleClient.backendWillDetach()` are optional-chained no-ops on the second pass
    /// either way — exactly the over-determination this comment describes. Reverted. (Confirmed
    /// separately, per above, that the SAME mutation DOES redden
    /// `BackendAttachmentTests.test_detachIsIdempotent`.)
    func test_detachTwice_isIdempotent() {
        backend.detach()
        XCTAssertFalse(log.kinds.isEmpty, "the first detach() must have done something observable")

        log.reset()
        backend.detach()   // second call — must be a pure no-op

        XCTAssertFalse(backend.isAttached)
        XCTAssertTrue(log.kinds.isEmpty, "a second detach() must not repeat any teardown step; got \(log.kinds)")
    }

    // MARK: - 4. detach terminality: the client-facing tail order is fixed

    /// The spec's nine detach steps end with two CLIENT-facing calls, in a fixed order: the
    /// presentation client is torn down (step 7) BEFORE the lifecycle client is told detach happened
    /// (step 8). This is the one slice of that order any third-party conformer's clients can observe —
    /// the other seven steps are internal bookkeeping no protocol member exposes.
    ///
    /// WHAT THIS ADDS OVER `BackendAttachmentTests`: that suite's own `test_detachRunsTheNineStepsInOrder`
    /// used to pin the FULL nine-step order, including the two interaction stubs
    /// (`cancelActiveInteraction(reason:)`, `removeInteractions()`) that existed only as
    /// `LegacyRichTextInputBackend`'s own pending-routing bookkeeping — that test was a
    /// characterization of the legacy implementation's internals. **TASK 32 replaced both stubs**, so
    /// that test now pins the same client-facing tail this one does, plus the two steps' EFFECTS on the
    /// host's canvas; the relative order of steps 2 and 4 became unobservable and is recorded as such
    /// there. This test is unaffected — it never named the interaction steps.
    /// This test pins the CLIENT-OBSERVABLE tail alone, which is what the spec actually obligates every
    /// conformer to — verifiable with no concrete-type access at all. (This is a strict SUBSET of the
    /// legacy test's coverage, not a stronger claim — its value is that it is inherited and the legacy
    /// superset is not.)
    ///
    /// RED-CHECK: temporarily swapped the two lines in `performDetachSteps()`
    /// (`+Attachment.swift`) — `host?.lifecycleClient.backendWillDetach()` before
    /// `host?.presentationClient.tearDownPresentation()`. Confirmed `XCTAssertEqual(log.kinds, …)` failed
    /// (observed `["lifecycleWillDetach", "presentationTearDown"]`) at the OBSERVATION POINT immediately
    /// after `detach()`, then reverted.
    func test_detachOrder_matchesTheSpecifiedSequence() {
        log.reset()
        backend.detach()
        XCTAssertEqual(log.kinds, ["presentationTearDown", "lifecycleWillDetach"],
                       "the presentation client must be torn down before the lifecycle client is told " +
                       "detach happened")
    }

    // MARK: - 5. detach terminality: an operation after detach is rejected and publishes nothing

    /// Once detached, EVERY operation must be refused — via the standard contract-violation channel —
    /// and must publish through NEITHER client.
    ///
    /// FIX ROUND 1 (task-22h-review.md, Major 1 + Major 4 — one edit closes both): added the PRE-DETACH
    /// CONTROL the terminality trap demands. Without it, the two post-detach absences
    /// (`presentationApply`/`lifecyclePublish` not present) would ALSO hold against a fixture that never
    /// published ANYTHING, ever — they'd be vacuously true for the wrong reason. The control performs
    /// the SAME `setSelection` call while still attached and asserts it DOES publish through both
    /// channels; only then does it detach and repeat, asserting absence. That presence-then-absence pair
    /// is jointly falsifiable against a silently-inert fixture in a way the bare absences were not.
    ///
    /// SECOND-GUARD CROSS-CHECK (Major 4, restated rather than removed): the two post-detach absences are
    /// OVER-DETERMINED by `publishState`'s OWN `guard let host else { return }` (
    /// `LegacyRichTextInputBackend.swift:808`) — `performDetachSteps()`'s step 9 has already released
    /// `host` by the time `setSelection` runs below, so these two assertions cannot fail for the reason
    /// their name suggests (`setSelection`'s OWN `isAttached` guard). They stay, because they are the
    /// ONLY inherited "publishes through neither channel" coverage (a stage-2 backend need not have a
    /// second nil-host guard at all) and, paired with the pre-detach control above, they ARE jointly
    /// falsifiable — a fixture that silently never published anything would fail the CONTROL half.
    ///
    /// WHAT THIS ADDS OVER `BackendAttachmentTests`: that suite's own
    /// `test_operationAfterDetachIsRejectedAndPublishesNothing` observes "publishes nothing" through
    /// `canvas.onSelectionChange` — a `DocumentCanvasView`-specific callback this suite cannot reach
    /// (R10), and (per the same over-determination this test now names explicitly) that check is ALSO
    /// over-determined by the very same `publishState` guard. So this is a claim of BREADTH (both
    /// publication channels checked, not one callback) over an equally inert assertion in both suites,
    /// not a claim of independent strength.
    ///
    /// RED-CHECK: temporarily removed the whole `guard isAttached else { RichTextInputContractViolation
    /// .report(…); return }` guard from `setSelection` in `LegacyRichTextInputBackend.swift`. Confirmed
    /// the contract-violation check and `XCTAssertEqual(backend.canonicalSelection, seeded)` failed (the
    /// new selection WAS adopted) at the OBSERVATION POINT immediately after the call — the
    /// `presentationApply`/`lifecyclePublish` absences did NOT go red even with the guard removed (see
    /// the second-guard cross-check above for why), then reverted.
    func test_operationAfterDetach_isRejected_andPublishesNothing() {
        // Pre-detach control (Major 1): the SAME operation, while still attached, must actually publish
        // through both channels — anchoring the post-detach absences below against a fixture that
        // published nothing at all.
        log.reset()
        backend.setSelection(.caret(at: .downstream(5)), reason: .programmatic)
        XCTAssertTrue(log.kinds.contains("presentationApply"),
                     "control: an attached setSelection must publish to the presentation client")
        XCTAssertTrue(log.kinds.contains("lifecyclePublish"),
                     "control: an attached setSelection must publish to the lifecycle client")

        let seeded = backend.canonicalSelection
        backend.detach()
        log.reset()

        backend.setSelection(.caret(at: .downstream(3)), reason: .programmatic)

        XCTAssertTrue(log.events.contains {
            if case .contractViolation(let message) = $0 { return message.contains("operation on a detached backend") }
            return false
        })
        XCTAssertEqual(backend.canonicalSelection, seeded, "a detached backend must not adopt the new selection")
        XCTAssertFalse(log.kinds.contains("presentationApply"), "a detached backend must not publish to the presentation client")
        XCTAssertFalse(log.kinds.contains("lifecyclePublish"), "a detached backend must not publish to the lifecycle client")
    }

    // MARK: - 6. Host retention: the backend must not keep the host alive

    /// The host is retained WEAKLY — proven purely through ARC, with no read of any
    /// `LegacyRichTextInputBackend`-only property (R10 forbids reading a concrete `.host`): if the
    /// backend held a STRONG reference, dropping every other reference to the host would not deallocate
    /// it, and `probe` (itself only `weak`) would still read non-nil.
    ///
    /// FIX ROUND 1 (task-22h-review.md, Minor 3): `localHost` is a third locally-made host outside the
    /// default token-hygiene gate — harmless here too, since this test never prepares a mutation against
    /// it at all (it exists purely to be attached, then released).
    ///
    /// WHAT THIS ADDS OVER `BackendAttachmentTests`: that suite's own
    /// `test_theBackendRetainsTheHostWeakly` constructs a real `DocumentCanvasView` directly and reads
    /// `backend.host` afterward — both forbidden here (R10). This test proves the identical invariant
    /// through a `weak var probe: (any RichTextInputHost)?` alone, which is a strictly protocol-level
    /// substitute: it needs no concrete accessor on the backend at all, so it would keep working
    /// unchanged even if `LegacyRichTextInputBackend` renamed or hid `.host` entirely.
    ///
    /// RED-CHECK: temporarily changed `weak var host: (any LegacyRichTextInputHost)?` to a plain (strong)
    /// `var host: (any LegacyRichTextInputHost)?` in `LegacyRichTextInputBackend.swift`. Confirmed
    /// `XCTAssertNil(probe)` failed (`probe` was still non-nil) at the OBSERVATION POINT after the
    /// `autoreleasepool` block, then reverted.
    func test_backendRetainsHostWeakly() throws {
        backend.detach()

        weak var probe: (any RichTextInputHost)?
        try autoreleasepool {
            var localHost: (any RichTextInputHost)? = makeHost(log: log)
            probe = localHost
            try backend.attach(to: localHost!)
            localHost = nil
        }

        XCTAssertNil(probe, "the host must be deallocatable while the backend remains attached to it")
    }
}
#endif

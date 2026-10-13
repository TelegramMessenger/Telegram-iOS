#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit

/// Abstract base class for the eight pure-contract suites (Tasks 22b-22i). Stage 2 re-runs the same
/// eight suites against `IDTextEditorBackend` by subclassing each one and overriding ONLY
/// `makeBackend()` (Decision 10) — nothing in the body below names a concrete backend, so a
/// subclass's `makeBackend()` override is the ONLY place a concrete conformer is ever constructed.
///
/// `class`, not `final class`: stage 2 (and each of 22b-22i) subclasses this.
@MainActor
@available(iOS 16.0, *)
class BackendContractCases: XCTestCase {

    /// The shared, ordered event log every fake (plus `RecordingInputDelegate`, when a subclass wires
    /// one) writes into. Fresh per test.
    private(set) var log: RichTextInputEventLog!

    /// The attached host. Typed `any RichTextInputHost` to mirror `backend` below.
    private(set) var host: (any RichTextInputHost)!

    /// The backend under test. Typed `any RichTextInputBackend` — NEVER the concrete type. A suite
    /// that finds itself needing a legacy-only member here has picked the wrong home for that test.
    var backend: any RichTextInputBackend { self._backend }
    private var _backend: (any RichTextInputBackend)!

    /// Convenience downcast to the default host shape, for suites that need the concrete fakes'
    /// test-only members (`fakeDocumentClient` etc.). `nil` when a subclass's `makeHost(log:)`
    /// override supplies a different host — such a suite is responsible for its own accessor.
    var fakeHost: FakeInputHost? { host as? FakeInputHost }

    /// Stage 2 overrides this to hand back e.g. `IDTextEditorBackend()`. The base implementation
    /// deliberately returns `nil`: see `setUpWithError()` below — a subclass that forgets to override
    /// this is SKIPPED, never silently run against a default concrete backend.
    func makeBackend() -> (any RichTextInputBackend)? { nil }

    /// Overridable so a backend needing a different host shape can supply one. Defaults to the
    /// standard all-fakes `FakeInputHost`.
    ///
    /// FIX ROUND 1 (task-22h-review.md Minor 2): honors `nextHostIsIncompatible` immediately below —
    /// moved here from a per-file override on `BackendAttachDetachTests` so any suite (22h, 22i, or a
    /// later one) can opt into a deliberately-incompatible host without duplicating the mechanism.
    /// Constructing `IncompatibleFakeHost(` HERE, inside a `func makeHost(` body, is the one place R11
    /// permits it; a parallel `makeIncompatibleHost(log:)` factory would NOT be masked by R11's literal
    /// `"func makeHost("` prefix match (`InputBackendSourceBoundaryTests.swift:457`) and would trip the
    /// rule instead of satisfying it — this shape was chosen specifically to avoid that.
    func makeHost(log: RichTextInputEventLog) -> any RichTextInputHost {
        if nextHostIsIncompatible {
            nextHostIsIncompatible = false
            return IncompatibleFakeHost(log: log)
        }
        return FakeInputHost(log: log)
    }

    /// Set by a test immediately before it calls `makeHost(log:)` again to get one deliberately-
    /// incompatible host (`IncompatibleFakeHost`, a plain `RichTextInputHost` conformer that fails
    /// `LegacyRichTextInputBackend.attach(to:)`'s narrowing cast). Consumed and reset the instant it is
    /// read, so it can never leak into a later `makeHost(log:)` call — including `setUpWithError()`'s
    /// own call below, for every test that never sets this flag.
    var nextHostIsIncompatible = false

    override func setUpWithError() throws {
        try super.setUpWithError()
        let freshLog = RichTextInputEventLog()
        self.log = freshLog
        guard let backend = makeBackend() else {
            throw XCTSkip(
                "\(type(of: self)) did not override makeBackend() — skipping (not silently " +
                "passing) this contract suite")
        }
        self._backend = backend
        let freshHost = makeHost(log: freshLog)
        self.host = freshHost
        // Route programmer-contract violations into the log instead of letting them trap the XCTest
        // runner — `RichTextInputContractViolation.swift`'s whole reason for the overridable `reporter`
        // ("the contract suite must OBSERVE violations"). Wired here so every one of 22b-22i's suites
        // gets this for free; cleared in `tearDownWithError` below.
        RichTextInputContractViolation.reporter = { [weak freshLog] message in
            freshLog?.record(.contractViolation(message))
        }
        // `try`, not `try!`: an attach failure is reported as THIS test's error, not a process trap.
        try backend.attach(to: freshHost)
        freshLog.reset()   // attach noise (`.lifecycleDidAttach`) is not part of any assertion
    }

    override func tearDownWithError() throws {
        // "A ready preparation is consumed exactly once before returning to the run loop" becomes a
        // DEFAULT assertion here rather than a per-test one — see `FakeInputDocumentClient.finish()`.
        // Both halves of the pair matter independently: an unconsumed preparation and a DOUBLE-consumed
        // one are different violations, and a count-based check on one cannot coincidentally catch the
        // other (see `FakeClientSelfTests.test_teardownFailsIndependently_onSawDoubleCommit_whenCountsCoincidentallyBalance`
        // and `…_onSawUnconsumedPreparation`).
        if let fakeHost = self.fakeHost {
            fakeHost.fakeDocumentClient.finish()
            XCTAssertFalse(
                fakeHost.fakeDocumentClient.sawDoubleCommit,
                "a document mutation token was committed twice")
            XCTAssertFalse(
                fakeHost.fakeDocumentClient.sawUnconsumedPreparation,
                "a document mutation was prepared but never committed before the test ended")
        }
        _backend?.detach()
        RichTextInputContractViolation.reporter = nil
        _backend = nil
        host = nil
        log = nil
        try super.tearDownWithError()
    }
}
#endif

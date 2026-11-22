#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Gated exactly like `IDBackendAttachAtomicityTests`/`IsSupportedTests`: `incomingCallbacks` stays
/// MANDATORY-rejected until the last of its 47 rows lands (Task C14), so `isSupported()` is
/// expected to answer FALSE on this runtime and every test below is expected to SKIP. See
/// `task-C2-report.md` for the measured answer.
@available(iOS 17.0, *)
@MainActor
final class IDFakeClientHarnessTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// TASK D2: `h.backend` widened to `any RichTextInputBackend` (Step 1) — this default-`kind`
    /// construction must still vend the CONCRETE ID backend, not merely something attached.
    func test_harnessAttachesTheIDBackendToFakeClients() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        XCTAssertTrue(h.backend is IDTextEditorBackend)
        XCTAssertTrue(h.backend.isAttached)
        XCTAssertEqual(h.lifecycle.didAttachCallCount, 1)
        XCTAssertTrue(h.host.hostInputView === h.canvas)
    }

    /// TASK D2: moved here from the `RichTextInputBackendHarness`-flavored `IDHarnessTests` version
    /// of this same-named test — this one drives `makeIDFakeClientHarness(kind:)` specifically (the
    /// fake-client-boundary harness Step 1 just generalized), not `makeBackendHarness(backend:)`.
    func test_storageFacadeIsVendedForInputDecAndNilForLegacy() {
        let id = makeIDFakeClientHarness(kind: .inputDec); defer { id.tearDown() }
        XCTAssertNotNil(id.storageFacadeIfAvailable)
        let legacy = makeIDFakeClientHarness(kind: .legacy); defer { legacy.tearDown() }
        XCTAssertNil(legacy.storageFacadeIfAvailable)
    }

    /// All seven fakes must share ONE log, or cross-client ordering is unassertable.
    func test_allFakesShareOneOrderedLog() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        XCTAssertTrue(h.document.log === h.log)
        XCTAssertTrue(h.geometry.log === h.log)
        XCTAssertTrue(h.command.log === h.log)
        XCTAssertTrue(h.presentation.log === h.log)
    }

    func test_theDocumentFakeSeedsTheRequestedText() {
        let h = makeIDFakeClientHarness(paragraphs: ["Alpha", "Beta"]); defer { h.tearDown() }
        XCTAssertEqual(h.document.text, "Alpha\nBeta")
        XCTAssertEqual(h.document.utf16Length, 10)
    }

    /// DEVIATION FROM THE BRIEF: the brief's illustrative snippet asserts `h.document.revision == 1`
    /// after `settableRevision += 1`. `FakeInputDocumentClient.revision` defaults to `1` (unchanged
    /// by this task), so `settableRevision += 1` reads 1 and writes back 2 — the brief's expected
    /// value is only reachable from a zero default, which is not this fixture's actual default and
    /// this task does not change it. Asserting `2` is the arithmetically correct statement of the
    /// same intent (the setter round-trips through `revision`).
    ///
    /// TASK R2 UPDATE: `clampCallCount` is now `1`, not `0`, right after `makeIDFakeClientHarness()`
    /// returns. `IDTextEditorBackend.attach(to:)` gained a real `installInitialState`-equivalent
    /// seed (`state.documentRevision = host.documentClient.revision; state.selection = .caret(at:
    /// host.documentClient.clamp(.downstream(0)))`), mirroring
    /// `LegacyRichTextInputBackend.installInitialState(from:)` exactly — see that call site's own
    /// comment for why this is a genuine, necessary fix (without it, `insertText(_:)`'s D32
    /// rebase-or-reject contract would see EVERY first mutation against this fixture as "stale",
    /// since `FakeInputDocumentClient.revision` defaults to `1` while the OLD attach left
    /// `state.documentRevision` hardcoded at `0`). This assertion encoded the PRE-Task-R2 behavior
    /// (attach touches nothing on the document client) as if it were a permanent contract; it never
    /// was one — nothing in this file's own doc comments claims `attach(to:)` must not read the
    /// document client, and Legacy's own `attach(to:)` has always called `clamp` too. Updated to `1`
    /// rather than left red, the same "a test-code bug in earlier scaffolding, not a runtime bug"
    /// class DIVERGENCES.md entry 14 already recorded for `CanvasFactoryTests`'s own stale assertion.
    func test_theNewCountersStartAtZeroAndAreMutable() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        XCTAssertEqual(h.document.clampCallCount, 1,
                       "attach(to:) seeds the initial selection via ONE clamp(.downstream(0)) call " +
                       "— see this test's own updated doc comment")
        XCTAssertEqual(h.document.rebaseCallCount, 0)
        XCTAssertTrue(h.geometry.receivedRequests.isEmpty)
        h.document.settableRevision += 1
        XCTAssertEqual(h.document.revision, 2)
    }

    func test_tearDownDetachesAndClearsTheAssociatedBridge() {
        let h = makeIDFakeClientHarness()
        let canvas = h.canvas
        h.tearDown()
        XCTAssertFalse(h.backend.isAttached)
        XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
    }
}
#endif

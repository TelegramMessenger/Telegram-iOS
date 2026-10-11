#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C9 — the ID-SPECIFIC assertions for Family 6 (marked text and prediction): that
/// `setMarkedText(_:selectedRange:)`/`unmarkText()` route through `kernelInput` and keep
/// `state.markedRange`/`.isComposing` in step (a composing edit for free, through the existing
/// Family-4 two-phase transaction; a commit explicitly, since it mutates no character — see
/// `IDTextEditorBackend+TextBackend.swift`'s own header), that marked text does not survive a
/// detach/reattach cycle, and that `synchronizeAfterExternalChange(_:)`'s three
/// `RichTextMarkedTextPolicy` branches behave as documented — mirroring
/// `BackendMarkedTextPolicyTests`' own worked examples (legacy-only, per this task's brief Step 6),
/// adapted to this backend's single-`state` store and its `IDFakeClientHarness` fixture.
///
/// Gated exactly like every other `.inputDec` suite in this stage: `isSupported()` evaluates the
/// WHOLE `incomingCallbacks` capability all-or-nothing (47 rows, spread across six tasks — see
/// `task-C4-supplement.md` §1), so it stays false — and every test below SKIPS — until Task C14
/// lands the last row. That is expected here, not a regression; see this task's own report
/// (`task-C9-report.md`) for the honest disclosure and for the NON-skip-gated coverage this task
/// added alongside this file (`IDTextEditorBackendMarkedTextPolicyTests`, over the pure
/// `IDTextEditorBackend.reconciledMarkedRange(...)` decision function — no kernel, no host, no
/// canvas — proven capable of failing, per this task's report).
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily6Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// A composing edit's `RichTextInputMutationResult.markedRange` reaches `state` through the
    /// EXISTING Family-4 two-phase transaction (`adoptAndEmitDidChange(_:)`) — no new adoption code
    /// in this task — but `isComposing` is spelled from THIS backend's own `markedRange` witness
    /// (`RichTextInputBackend.swift`'s documented rule), which was an always-nil stub until this
    /// task. Pins that the fix actually took: `isComposing` must read `true`, not just
    /// `state.markedRange` internally.
    func test_setMarkedTextPublishesIsComposing() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.document.commitMarkedRange = NSRange(location: 0, length: 2)
        let publishedBefore = h.lifecycle.publishedStates.count
        h.canvas.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertTrue(h.backend.isComposing, "adopting a non-nil markedRange must flip isComposing")
        XCTAssertEqual(h.backend.markedRange, NSRange(location: 0, length: 2))
        XCTAssertGreaterThan(h.lifecycle.publishedStates.count, publishedBefore,
                             "a composing edit must publish at least once")
    }

    /// `unmarkText()` commits without mutating a character (`IDTextEditorBackend+TextBackend.swift`'s
    /// own header), so nothing but this backend's explicit `commitMarkedTextStateIfComposing()`
    /// retires `state.markedRange` — without it this test is exactly the shape of stale-state bug
    /// the header warns about.
    func test_unmarkTextCommitsTheComposition() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.document.commitMarkedRange = NSRange(location: 0, length: 2)
        h.canvas.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertTrue(h.backend.isComposing, "composition established before commit")
        h.canvas.unmarkText()
        XCTAssertFalse(h.backend.isComposing, "unmarkText must commit — not leave the composition open")
        XCTAssertNil(h.backend.markedRange)
        // `RichTextInputStateChangeReason` is not `Equatable` (no other test in this stage compares
        // it directly either — see `RichTextInputEventLog.Event.lifecyclePublish`'s own STRING
        // payload for the established workaround), so pattern-match instead of `XCTAssertEqual`.
        guard case .markedText = h.lifecycle.lastPublishReason else {
            return XCTFail("expected the commit's own publish to carry the marked-text reason, " +
                           "got \(String(describing: h.lifecycle.lastPublishReason))")
        }
    }

    /// Mirrors `BackendMarkedTextPolicyTests.test_markedTextIsNotMigratedAcrossDetachAndReattach`:
    /// `state` is this backend's single canonical store (no second, canvas-side copy — see
    /// `setSelection(_:reason:)`'s own doc comment), and `detach()`/`attach(to:)` construct a FRESH
    /// `state` (`init()`'s memberwise default) — never carry the old one forward — so nothing needs
    /// its own "finalize marked text at detach" step the way Legacy's two-store split once did.
    func test_markedTextIsNotMigratedAcrossDetachAndReattach() throws {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.document.commitMarkedRange = NSRange(location: 0, length: 2)
        h.canvas.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertTrue(h.backend.isComposing, "composition established before detaching")

        h.backend.detach()
        let freshHost = FakeInputHost(hostInputView: h.canvas, log: h.log, text: "Alpha\nBeta")
        try h.backend.attach(to: freshHost)
        XCTAssertNil(h.backend.markedRange,
                     "a fresh attach must not inherit a composition left over from the previous session")
        XCTAssertFalse(h.backend.isComposing)
    }

    /// `.commitBeforeChange` is OBSERVABLY IDENTICAL to `.discard` at this backend, exactly the
    /// disclosure `LegacyRichTextInputBackend.reconcileMarkedTextForExternalChange`'s own doc comment
    /// makes for its matching branches (no production call site has ever asked for a genuine
    /// commit-then-drop distinct from a plain drop — see `IDTextEditorBackend
    /// .reconciledMarkedRange(...)`'s own doc comment). What this test pins, and is not vacuous
    /// relative to `.discard`'s own coverage in `IDTextEditorBackendMarkedTextPolicyTests`: the
    /// composition is resolved AND `documentRevision` still lands on exactly `change.newRevision` —
    /// the reconciliation does not accidentally short-circuit revision adoption — AND no new document
    /// mutation is issued (the hard invariant: never launder an external change through a keyboard
    /// mutation).
    func test_commitBeforeChangePolicy_commitsBeforeAdoptingTheNewRevision() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.document.commitMarkedRange = NSRange(location: 0, length: 2)
        h.canvas.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertTrue(h.backend.isComposing, "composition established before the external change")
        let mutationsBefore = h.document.receivedMutations.count
        let old = h.document.revision
        h.backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: h.backend.canonicalSelection, markedTextPolicy: .commitBeforeChange))
        XCTAssertNil(h.backend.markedRange, "the composition is resolved, not left dangling")
        XCTAssertFalse(h.backend.isComposing)
        XCTAssertEqual(h.backend.state.documentRevision, old + 1)
        XCTAssertEqual(h.document.receivedMutations.count, mutationsBefore,
                       "an external change must never be laundered through a keyboard mutation")
    }

    /// Mirrors `BackendMarkedTextPolicyTests.test_preserveIfRebasable_keepsMarkedRange_whenRebaseSucceeds`:
    /// both endpoints of the marked range are rebased via `documentClient.rebase(_:fromRevision:)`,
    /// and a successful rebase KEEPS the composition at the REBASED offsets — provably derived from
    /// the rebase calls, not incidentally equal to the pre-change range (both endpoints move by +10).
    func test_preserveIfRebasablePolicy_keepsTheMarkedRangeWhenRebaseSucceeds() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.document.commitMarkedRange = NSRange(location: 0, length: 2)
        h.canvas.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        guard let before = h.backend.markedRange else {
            return XCTFail("composition established before the external change")
        }
        h.document.rebaseResultsQueue = [
            RichTextInputPosition(utf16Offset: before.location + 10),
            RichTextInputPosition(utf16Offset: before.location + before.length + 10),
        ]
        let old = h.document.revision
        // The `.preserveIfRebasable` fast path (`change.reason.preservesTextOffsets`) must be
        // skipped for this to reach `rebase` at all — `.remoteUpdate` answers `false`.
        h.document.revision = old + 1
        h.backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: old, newRevision: old + 1, reason: .remoteUpdate,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: h.backend.canonicalSelection, markedTextPolicy: .preserveIfRebasable))
        guard let after = h.backend.markedRange else {
            return XCTFail("expected the rebased marked range to survive")
        }
        XCTAssertEqual(after.location, before.location + 10)
        XCTAssertEqual(after.location + after.length, before.location + before.length + 10)
        XCTAssertEqual(h.document.rebaseCallCount, 2,
                       "a non-collapsed marked range rebases both endpoints — never more than the two")
    }

    /// Pins `DocumentCanvasView+MarkedText.swift:28`'s documented legacy behavior — "we draw our own
    /// underline decoration; no system styling to vend" — as this backend's OWN answer too, not an
    /// omission to route into `kernelInput`. A bare, unattached backend suffices: neither half reads
    /// `state`/`kernelInput`/`host`.
    func test_markedTextStyleGetterReturnsNil_andTheSetterIsANoOp() {
        let backend = IDTextEditorBackend()
        XCTAssertNil(backend.markedTextStyle)
        backend.markedTextStyle = [.foregroundColor: UIColor.red]
        XCTAssertNil(backend.markedTextStyle, "the setter must remain a no-op")
    }
}
#endif

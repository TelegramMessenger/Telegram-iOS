#if canImport(UIKit)
import RichTextInputDecObjC
import RichTextEditorCore
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C6 — the ID-SPECIFIC assertions for Family 3 (selected range and input-delegate
/// ownership): endpoint identity (a reversed selection's anchor/head are never reordered),
/// publication-once, notification-before-publication ordering, and floating-cursor suppression of
/// the `selectedTextRange` setter. Mirrors `BackendSelectionContractTests` (the legacy backend's
/// own suite for the identical contract) — the backend-agnostic Family-3 assertions live in
/// `BackendSemanticContractCases` (Task C3's shared suite) and are not repeated here.
///
/// Gated exactly like `IDBackendFamily1Tests`/`IDBackendFamily2Tests` and every other `.inputDec`
/// suite in this stage: `isSupported()` evaluates the WHOLE `incomingCallbacks` capability
/// all-or-nothing across all 47 rows. This task lands row 30
/// (`invalidateDisplayForCharacterRange:`), dropping the mismatch count 9 -> 8 — but 8 rows still
/// belong to C12/C14, so `incomingCallbacks` stays rejected and `isSupported()` stays FALSE on
/// this runtime, and every test below is still expected to SKIP. That is expected here, not a
/// regression — see `task-C6-report.md` for the measured mismatch count and the real,
/// non-skipped evidence that DOES exist: the shared Family-3 cases added to
/// `BackendSemanticContractCases`, which run for real against `LegacyBackendSemanticTests`.
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily3Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// Mirrors `BackendSelectionContractTests
    /// .test_selectedTextRangeGetter_handsUIKitAnUnorderedRange_forAReversedSelection`, over the ID
    /// backend directly: anchor 10 / head 3 ⇒ the returned range's start is the ANCHOR (10), matching
    /// the legacy behavior pinned at `DocumentCanvasView+UITextInput.swift:143` /
    /// `LegacyRichTextInputBackend.selectedTextRange`'s own getter doc comment.
    func test_selectedTextRangeGetter_handsUIKitAnUnorderedRangeForAReversedSelection() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(10), head: .downstream(3)),
                               reason: .programmatic)
        guard let range = h.backend.selectedTextRange as? TGRichTextInputDecRange else {
            XCTFail("expected a TGRichTextInputDecRange"); return
        }
        XCTAssertEqual((range.start as? TGRichTextInputDecPosition)?.utf16Offset, 10,
                       "start must be the ANCHOR, not min()")
        XCTAssertEqual((range.end as? TGRichTextInputDecPosition)?.utf16Offset, 3,
                       "end must be the HEAD, not max()")
    }

    /// A reversed selection survives a round trip through the `selectedTextRange` SETTER (not just
    /// `setSelection` directly) unchanged — no reordering anywhere on the write path.
    func test_reversedSelectionSurvivesTheRoundTrip() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.selectedTextRange = TGRichTextInputDecRange(
            from: TGRichTextInputDecPosition(offset: 10, affinity: .forward, revision: 0),
            to: TGRichTextInputDecPosition(offset: 3, affinity: .forward, revision: 0))
        XCTAssertEqual(h.backend.canonicalSelectionAnchorOffset, 10)
        XCTAssertEqual(h.backend.canonicalSelectionHeadOffset, 3)
        XCTAssertTrue(h.backend.canonicalSelection.isReversed)
    }

    /// One `setSelection` call publishes EXACTLY one snapshot — a report of "selection was set",
    /// not a change-detecting cache (mirrors `BackendSelectionContractTests
    /// .test_selectionChangeReason_reachesPublicationUnchanged`'s "publish exactly once,
    /// unconditionally").
    func test_oneSelectionChangePublishesExactlyOneSnapshot() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.inputDelegate = RecordingInputDelegate(log: h.log)
        h.log.reset()
        h.backend.setSelection(.caret(at: .downstream(2)), reason: .programmatic)
        XCTAssertEqual(h.log.count("lifecyclePublish"), 1)
    }

    /// **TASK R11 CORRECTION (cluster 10).** This test used to pin `setSelection` emitting
    /// `delegateSelectionDidChange` strictly BEFORE `lifecyclePublish` — that was pinning the OLD,
    /// buggy behavior (`setSelection` firing its delegate bracket unconditionally for every `reason`,
    /// R1's cluster 10), not the real cross-backend contract. Proven directly against Legacy source,
    /// not assumed: `LegacyRichTextInputBackend.setSelection` (`LegacyRichTextInputBackend.swift`)
    /// sends ZERO `UITextInputDelegate` notifications from its own body — it writes
    /// `canonicalSelectionStorage`, checks `suppressesSelectionNotifications`, checks
    /// `transactionPhase == .idle`, then opens `withTransaction { publishState(reason: .selection) }`
    /// with no `notify*` call anywhere in between — confirmed live by the SHARED, unmodified
    /// `BackendSelectionContractTests.test_selectionChangeReason_reachesPublicationUnchanged`, which
    /// passes against `ReferenceMutationBackend` (real Legacy code) both before and after this
    /// correction. This backend's `setSelection` is now delegate-silent to match (Task R11, same
    /// commit) — this test now pins THAT: publication still happens (`presentationApply` then
    /// `lifecyclePublish`), with no `delegateSelectionWillChange`/`delegateSelectionDidChange` of
    /// `setSelection`'s OWN. (A REAL kernel-driven selection change still reaches the delegate via
    /// `relaySelectionDidChangeFromKernel()` — a different call path this fake-client harness, which
    /// never drives a live keyboard session, does not exercise.)
    func test_publicationFollowsDidChangeNotifications() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.inputDelegate = RecordingInputDelegate(log: h.log)
        h.log.reset()
        h.backend.setSelection(.caret(at: .downstream(2)), reason: .programmatic)
        XCTAssertFalse(h.log.contains("delegateSelectionWillChange"),
                       "setSelection must not open its own delegate bracket: \(h.log.kinds)")
        XCTAssertFalse(h.log.contains("delegateSelectionDidChange"),
                       "setSelection must not open its own delegate bracket: \(h.log.kinds)")
        XCTAssertEqual(h.log.kinds, ["presentationApply", "lifecyclePublish"],
                       "setSelection must still publish exactly once, unconditionally")
    }

    /// The load-bearing floating-cursor invariant (mirrors `BackendSelectionContractTests
    /// .test_selectedTextRangeSetter_isIgnoredWhileFloatingCursorIsActive`): a write reaching the
    /// `selectedTextRange` setter while the floating cursor owns the caret is dropped; the SAME
    /// write is honoured once the gesture ends.
    func test_selectedTextRangeSetterIsIgnoredDuringFloatingCursor() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.setSelection(.caret(at: .downstream(2)), reason: .programmatic)
        let settled = h.backend.canonicalSelection

        h.backend.setFloatingCursorActive(true)
        h.backend.selectedTextRange = TGRichTextInputDecRange(
            from: TGRichTextInputDecPosition(offset: 5, affinity: .forward, revision: 0),
            to: TGRichTextInputDecPosition(offset: 5, affinity: .forward, revision: 0))
        XCTAssertEqual(h.backend.canonicalSelection, settled,
                       "a write while the floating cursor owns the caret must be ignored")

        h.backend.setFloatingCursorActive(false)
        h.backend.selectedTextRange = TGRichTextInputDecRange(
            from: TGRichTextInputDecPosition(offset: 5, affinity: .forward, revision: 0),
            to: TGRichTextInputDecPosition(offset: 5, affinity: .forward, revision: 0))
        XCTAssertEqual(h.backend.canonicalSelectionHeadOffset, 5,
                       "the SAME write must be accepted once the floating cursor has ended")
    }
}
#endif

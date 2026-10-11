#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C13 — the ID-SPECIFIC assertions for Family 10 (floating cursor; autoscroll deliberately
/// deferred — see DIVERGENCES.md entry 13): that `beginFloatingCursor(at:)`/`updateFloatingCursor(at:)`/
/// `endFloatingCursor()` genuinely route into the kernel's `IDUIKitInteractionCapability`, that
/// `beginFloatingCursor(at:)` raises this backend's `floatingCursorActive` latch (and
/// `endFloatingCursor()` clears it), and that the latch does its one real job: a UIKit-driven
/// `selectedTextRange` RANGE write during the gesture is dropped, never becoming a selection —
/// mirroring `IDBackendFamily7Tests`'/`IDBackendFamily8Tests`'/`IDBackendFamily9Tests`' own "ID-specific
/// assertions over the fake harness" framing, one family over.
///
/// **The suppression invariant itself is not new here** — `IDBackendFamily3Tests
/// .test_selectedTextRangeSetterIsIgnoredDuringFloatingCursor` (Task C6) already pins it, driving the
/// latch through the RAW `setFloatingCursorActive(_:)` door directly (the setter's own guard existed
/// since Task C6, long before this task gave the gesture entry points a real body). What THIS task's
/// tests add is the other half: that `beginFloatingCursor(at:)`/`endFloatingCursor()` — the real OS
/// gesture entry points, previously empty no-ops — are what actually DRIVE that same latch, so the
/// wiring this task adds is what makes C6's invariant reachable from a genuine hold-spacebar gesture,
/// not only from white-box test code.
///
/// Gated exactly like every other `.inputDec` suite in this stage: `isSupported()` evaluates the
/// WHOLE `incomingCallbacks` capability all-or-nothing (47 rows, spread across seven tasks — see
/// `task-C4-supplement.md` §1), so it stays false — and every test below SKIPS — until Task C14
/// lands the last 7 rows. That is expected here, not a regression; see this task's own report
/// (`task-C13-report.md`) for the honest disclosure, and `IDTextEditorBackendFloatingCursorSuppressionTests`
/// (non-skip-gated) for the zero-skip coverage this task adds alongside this suite — the
/// suppression DECISION itself needs no live kernel (`DocumentCanvasView+UITextInput.swift`'s own
/// load-bearing note on this family), unlike the routing this suite exists to pin.
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily10Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    private func range(_ anchor: Int, _ head: Int) -> TGRichTextInputDecRange {
        TGRichTextInputDecRange(
            from: TGRichTextInputDecPosition(offset: anchor, affinity: .forward, revision: 0),
            to: TGRichTextInputDecPosition(offset: head, affinity: .forward, revision: 0))
    }

    /// `beginFloatingCursor(at:)` must (1) reach the kernel's interaction capability cleanly and
    /// (2) raise the latch `selectedTextRange`'s setter consults — proven by a subsequent UIKit-style
    /// range write during the (still-active) gesture landing as a no-op, exactly like
    /// `IDBackendFamily3Tests`'own invariant, now reached through the real entry point rather than
    /// the raw door.
    func test_beginFloatingCursorMarksTheStateComposing_andSuppressesSelectedTextRangeWrites() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.setSelection(.caret(at: .downstream(2)), reason: .programmatic)
        let settled = h.backend.canonicalSelection

        h.backend.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        XCTAssertTrue(h.backend.floatingCursorActive,
                     "beginFloatingCursor(at:) must raise the backend's floating-cursor latch")
        XCTAssertTrue(h.idBackend.witnessFailures.isEmpty,
                     "beginFloatingCursor(at:) must reach the kernel's interaction capability cleanly: \(h.idBackend.witnessFailures)")

        h.backend.selectedTextRange = range(5, 5)
        XCTAssertEqual(h.backend.canonicalSelection, settled,
                       "a selectedTextRange write during an active floating cursor must be dropped")

        h.backend.endFloatingCursor()
    }

    /// The point is forwarded with no clamping/conversion (the routing line passes `point` straight
    /// through to `kernelInteraction?.updateFloatingCursorAtPoint(_:animated:)` — see
    /// `+Interaction.swift`). This backend does not itself intercept or store the point for the ID
    /// path (unlike the canvas's own `legacyUpdateFloatingCursor`, deliberately out of this task's
    /// scope — see `+Interaction.swift`'s own header), so the observable proof available here is
    /// that an arbitrary point reaches the kernel cleanly with no witness failure — the same
    /// verification bar `IDBackendFamily9Tests.test_selectWordRoutesThroughTheInteractionCapability`
    /// uses for "routes through cleanly".
    func test_updateFloatingCursorForwardsThePointVerbatim() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        h.backend.updateFloatingCursor(at: CGPoint(x: 42.5, y: 137.25))
        XCTAssertTrue(h.idBackend.witnessFailures.isEmpty,
                     "updateFloatingCursor(at:) must reach the kernel's interaction capability cleanly: \(h.idBackend.witnessFailures)")
        XCTAssertTrue(h.backend.floatingCursorActive,
                     "an update mid-gesture must not itself clear the latch")
        h.backend.endFloatingCursor()
    }

    /// `endFloatingCursor()` clears the latch and leaves the caret exactly where the gesture began —
    /// collapsed, not the endpoint of a range push suppressed mid-gesture.
    func test_endFloatingCursorLeavesACollapsedCaret() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.setSelection(.caret(at: .downstream(2)), reason: .programmatic)

        h.backend.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        h.backend.selectedTextRange = range(5, 9)   // suppressed — must not apply
        h.backend.endFloatingCursor()

        XCTAssertFalse(h.backend.floatingCursorActive, "endFloatingCursor() must clear the latch")
        XCTAssertTrue(h.backend.canonicalSelection.isCollapsed,
                     "the caret must remain collapsed — the suppressed range push never applied")
        XCTAssertEqual(h.backend.canonicalSelectionHeadOffset, 2,
                       "the caret must remain exactly where the gesture began")
        XCTAssertTrue(h.idBackend.witnessFailures.isEmpty,
                     "both begin and end must complete cleanly: \(h.idBackend.witnessFailures)")
    }

    /// The full round trip, pinning the load-bearing behavior at `DocumentCanvasView+UITextInput
    /// .swift`'s selection-vs-move distinction (the file this family's own load-bearing note names):
    /// the IDENTICAL write is dropped while the gesture is active and honoured — becoming a genuine
    /// SELECTION, not merely accepted as a no-op caret move — the instant it ends.
    func test_uikitRangePushesDuringTheFloatingCursorDoNotBecomeASelection() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.setSelection(.caret(at: .downstream(2)), reason: .programmatic)
        let settled = h.backend.canonicalSelection
        let pushed = range(5, 9)

        h.backend.beginFloatingCursor(at: CGPoint(x: 0, y: 0))
        h.backend.selectedTextRange = pushed
        XCTAssertEqual(h.backend.canonicalSelection, settled,
                       "a selectedTextRange write during the gesture must be dropped, not become a selection")

        h.backend.endFloatingCursor()
        h.backend.selectedTextRange = pushed
        XCTAssertEqual(h.backend.canonicalSelectionAnchorOffset, 5)
        XCTAssertEqual(h.backend.canonicalSelectionHeadOffset, 9)
        XCTAssertFalse(h.backend.canonicalSelection.isCollapsed,
                       "the SAME write must be honoured once the gesture has ended, becoming a real selection")
    }
}
#endif

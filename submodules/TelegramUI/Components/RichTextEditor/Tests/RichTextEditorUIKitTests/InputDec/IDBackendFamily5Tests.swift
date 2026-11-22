#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C8 — the ID-SPECIFIC assertions for Family 5 (backward deletion): that
/// `IDTextEditorBackend.deleteBackward()` forwards the backend's own canonical selection and the
/// controller's own resolved delete range through to `RichTextInputMutation.deleteBackward`
/// verbatim, rather than a locally-guessed one — mirroring `IDBackendFamily4Tests`' own "pins the
/// TRANSACTION shape" framing, one family over.
///
/// Gated exactly like every other `.inputDec` suite in this stage: `isSupported()` evaluates the
/// WHOLE `incomingCallbacks` capability all-or-nothing (47 rows, spread across six tasks — see
/// `task-C4-supplement.md` §1), so it stays false — and every test below SKIPS — until Task C14
/// lands the last row. That is expected here, not a regression; see this task's own report
/// (`task-C8-report.md`) for the honest disclosure and for the NON-skip-gated coverage this task
/// added alongside this file (`IDTextEditorBackendDeleteBackwardRoutingTests`,
/// `IDTextEditorBackendIntentTests.test_deleteBackwardIntent_forwardsTheProposedRangeVerbatim`
/// from Task C7, `IDTextStorageFacadeTests`'s `.deleteBackward`-intent case also from Task C7).
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily5Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// The controller's own `preflightBackwardDeleteRanges()`/`backwardDeleteRange()` resolve the
    /// delete range (grapheme-cluster-aware, via `id_rangeOfCharacterClusterAtIndex:type:` —
    /// Family 1, Task C4) — never a range this backend computes itself. The proposed range must
    /// therefore END exactly at the caret, whatever its resolved WIDTH turns out to be (that width
    /// is `test_deleteBackwardOverAGraphemeCluster_deletesTheWholeCluster`'s own concern below).
    func test_deleteBackwardUsesTheControllerProposedRange() {
        let h = makeIDFakeClientHarness(paragraphs: ["Alpha", "Beta"]); defer { h.tearDown() }
        h.backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(3), head: .downstream(3)),
                               reason: .programmatic)
        h.canvas.deleteBackward()
        guard case .deleteBackward(let selection, let proposedRange) = h.document.receivedMutations.last,
              let proposed = proposedRange else {
            return XCTFail("got \(String(describing: h.document.receivedMutations.last))")
        }
        XCTAssertEqual(selection, RichTextCanonicalSelection(anchor: .downstream(3), head: .downstream(3)),
                       "the mutation must carry the backend's live canonical selection")
        XCTAssertEqual(proposed.location + proposed.length, 3,
                       "the controller's own proposed range must end exactly at the caret")
    }

    /// At document start there is nothing before the caret to delete: the document client answers
    /// a terminal no-change, which must produce no mirror mutation and no new published state —
    /// mirrors `IDBackendFamily4Tests.test_terminalRejection_emitsNoDelegateNotifications_andNoPublication`'s
    /// own shape, for the OTHER terminal disposition (`.noChange`, not `.rejected`).
    func test_deleteBackwardAtDocumentStart_isANoChange_andEmitsNoNotifications() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(0), head: .downstream(0)),
                               reason: .programmatic)
        h.document.nextPreparationNoChange = true
        let publishedBefore = h.lifecycle.publishedStates.count
        h.canvas.deleteBackward()
        XCTAssertEqual(h.lifecycle.publishedStates.count, publishedBefore,
                       "a terminal no-change must publish nothing")
        // Task R3: same correction as `IDBackendFamily4Tests`' two terminal-disposition tests —
        // `attach(to:)` now seeds the mirror with the fake host's real content ("Alpha\nBeta")
        // instead of leaving it empty, so "must not mutate the mirror" means "must still read
        // Alpha\nBeta", not "".
        XCTAssertEqual(h.storageFacade.string, "Alpha\nBeta", "a no-change delete must not mutate the mirror")
    }

    /// A family emoji (`👨‍👩‍👧‍👦`, a ZWJ sequence) is ONE grapheme cluster spanning several UTF-16
    /// units. The controller's own `id_rangeOfCharacterClusterAtIndex:type:` (Family 1, Task C4)
    /// must resolve the WHOLE cluster, so `proposedRange.length` must equal the emoji's own
    /// `utf16.count` — never 1 (which would leave an orphaned half of the sequence, exactly the
    /// surrogate/ZWJ-splitting bug the package `CLAUDE.md`'s grapheme-cluster invariants warn
    /// about for the legacy backend's own `deleteBackward`).
    func test_deleteBackwardOverAGraphemeCluster_deletesTheWholeCluster() {
        let familyEmoji = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"
        let h = makeIDFakeClientHarness(paragraphs: [familyEmoji, "Beta"]); defer { h.tearDown() }
        let caretOffset = familyEmoji.utf16.count
        h.backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(caretOffset),
                                                           head: .downstream(caretOffset)),
                               reason: .programmatic)
        h.canvas.deleteBackward()
        guard case .deleteBackward(_, let proposedRange) = h.document.receivedMutations.last,
              let proposed = proposedRange else {
            return XCTFail("got \(String(describing: h.document.receivedMutations.last))")
        }
        XCTAssertEqual(proposed.length, familyEmoji.utf16.count,
                       "a family emoji is one grapheme cluster and must be deleted as a whole, " +
                       "not one UTF-16 unit")
    }

    /// A non-empty selection is deleted AS the selection — the private controller's own backward-
    /// delete range resolution never runs when there is already something selected (mirrors the
    /// standard `UIKeyInput` contract every text view honors: Backspace over a selection removes
    /// the selection, not a computed cluster before it).
    func test_deleteBackwardWithANonEmptySelection_deletesTheSelection() {
        let h = makeIDFakeClientHarness(paragraphs: ["Alpha", "Beta"]); defer { h.tearDown() }
        h.backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(1), head: .downstream(4)),
                               reason: .programmatic)
        h.canvas.deleteBackward()
        guard case .deleteBackward(let selection, _) = h.document.receivedMutations.last else {
            return XCTFail("got \(String(describing: h.document.receivedMutations.last))")
        }
        XCTAssertEqual(selection, RichTextCanonicalSelection(anchor: .downstream(1), head: .downstream(4)),
                       "a non-empty selection must reach the mutation verbatim")
    }
}
#endif

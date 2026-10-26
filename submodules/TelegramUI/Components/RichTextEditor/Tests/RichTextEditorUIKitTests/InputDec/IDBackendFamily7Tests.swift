#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C10 — the ID-SPECIFIC assertions for Family 7 (responder commands and clipboard): that
/// `canPerformCommand(_:sender:)`/`performCommand(_:sender:)` route through
/// `RichTextInputCommandClient`, never the private controller's own `-cut:`/`-copy:`/`-paste:` —
/// mirroring `IDBackendFamily6Tests`' own "ID-specific assertions over the fake harness" framing,
/// one family over. See `IDTextEditorBackend+Responder.swift`'s own header for why this is a
/// deliberate divergence from upstream InputDec, recorded in `DIVERGENCES.md` entry 10.
///
/// Gated exactly like every other `.inputDec` suite in this stage: `isSupported()` evaluates the
/// WHOLE `incomingCallbacks` capability all-or-nothing (47 rows, spread across six tasks — see
/// `task-C4-supplement.md` §1), so it stays false — and every test below SKIPS — until Task C14
/// lands the last row. That is expected here, not a regression; see this task's own report
/// (`task-C10-C11-report.md`) for the honest disclosure and for the NON-skip-gated coverage this
/// task added alongside this file (`IDTextEditorBackendCommandRoutingTests`, over the pure
/// `IDTextEditorBackend.canPerformCommandDecision(...)`/`.performCommandViaClient(...)` decision
/// functions — no kernel, no host, no canvas — proven capable of failing, per this task's report).
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily7Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// The private controller is asked NOTHING here — the command client's own `canPerformResult ==
    /// false` short-circuits before `kernelInput?.shouldHandlePasteAction(_:sender:)` is ever reached.
    /// The STRUCTURAL guarantee (the kernel closure is never invoked once the command client already
    /// declined) is what `IDTextEditorBackendCommandRoutingTests
    /// .test_paste_whenCommandClientDeclines_neverConsultsTheKernelClosure` proves directly, with no
    /// kernel attached at all; this test pins the END-TO-END outcome once a real kernel IS attached.
    func test_canPerformPaste_consultsTheCommandClient_notThePrivateController() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.command.canPerformResult = false
        XCTAssertFalse(h.backend.canPerformCommand(.paste, sender: nil))
        XCTAssertTrue(h.command.canPerformQueries.contains(.paste),
                      "the command client must have been asked")
    }

    func test_pasteGoesThroughPrepareThenCommit() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.performCommand(.paste, sender: nil)
        XCTAssertEqual(h.command.prepared.count, 1)
        XCTAssertEqual(h.command.committed.count, 1)
        XCTAssertFalse(h.command.sawDoubleCommit)
    }

    /// Mirrors `BackendEditPolicyTests.test_allowsPasteFalse_makesCanPerformPasteFalse`'s own shape
    /// (Task 22i, the legacy backend's stage-1 suite) — the same `RichTextInputEditPolicy.allowsPaste`
    /// gate, now pinned for `IDTextEditorBackend`.
    func test_allowsPasteFalse_makesCanPerformPasteFalse() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        XCTAssertTrue(h.backend.canPerformCommand(.paste, sender: nil),
                     "control: paste must be permitted under the default permissive policy")
        h.lifecycle.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: true, isSelectable: true, allowsRichText: true,
            allowsPaste: false, allowsDictation: true, allowsWritingTools: true)
        XCTAssertFalse(h.backend.canPerformCommand(.paste, sender: nil),
                      "allowsPaste == false must make canPerformCommand(.paste, sender:) false")
    }

    /// `RichTextInputCommand.copy` carries no range — copy is entirely selection-BLIND at this
    /// routing layer, and that is the point of this test: a reversed selection (anchor AFTER head,
    /// the same shape `test_aReversedSelectionRoundTripsThroughSelectedTextRange` — Family 3 — pins
    /// for `selectedTextRange`) must survive a read-only `.copy` command completely UNTOUCHED — no
    /// silent reorder, no collapse — while the LOGICAL (ascending) range a real command client would
    /// copy TO the pasteboard remains correctly derivable from it via
    /// `RichTextCanonicalSelection.normalizedRange`, the seam's own established "the canvas hands
    /// UIKit an unordered range for a reversed drag" primitive (`IDTextEditorBackend.swift`'s
    /// `selectedTextRange` getter doc comment).
    func test_copyOfAReversedSelection_copiesTheLogicalRange() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let reversed = RichTextCanonicalSelection(anchor: .downstream(5), head: .downstream(2))
        h.backend.setSelection(reversed, reason: .programmatic)
        h.backend.performCommand(.copy, sender: nil)
        XCTAssertEqual(h.command.prepared, [.copy], "copy must go through the command client")
        XCTAssertEqual(h.backend.canonicalSelection, reversed,
                       "a read-only copy must not silently reorder or collapse the user's selection")
        XCTAssertEqual(h.backend.canonicalSelection.normalizedRange, NSRange(location: 2, length: 3),
                       "the LOGICAL (ascending) range must still be correctly derivable from the " +
                       "untouched, reversed selection")
    }
}
#endif

#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C13 — the NON-skip-gated coverage for Family 10's floating-cursor suppression decision and
/// for the `.floatingCursor` capability-request safety claim `IDTextEditorBackend.swift`'s
/// `requestedCapabilities` doc comment records.
///
/// **Neither test below needs a live kernel, a canvas, or a successful attach** — the supplement's
/// own framing for this task: "the floating-cursor suppression logic ... is pure Swift decision
/// logic needing no live kernel." This is what makes it possible to genuinely EXECUTE this coverage
/// on a runtime where `isSupported()` is false — unlike every `IDBackendFamily10Tests` assertion,
/// which stays skip-gated until Task C14 (and, run against the fake harness, would additionally
/// exercise a live `kernelInteraction` this task's own witnesses route through — irrelevant to the
/// DECISION under test here).
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendFloatingCursorSuppressionTests: XCTestCase {

    private func offsets(_ range: UITextRange?) -> (Int, Int)? {
        guard let r = range,
              let a = r.start as? TGRichTextInputDecPosition,
              let h = r.end as? TGRichTextInputDecPosition else { return nil }
        return (a.utf16Offset, h.utf16Offset)
    }

    /// `IDTextEditorBackend.selectedTextRange`'s setter opens with `guard !floatingCursorActive else
    /// { return }`, BEFORE it ever reaches `setSelection(_:reason:)`. `setFloatingCursorActive(_:)`
    /// is the unguarded raw door (no `isAttached` requirement, deliberately — see
    /// `IDTextEditorBackend.swift`), so it is safe to drive directly on a freshly constructed,
    /// never-attached backend — and because the guard returns BEFORE `setSelection`'s own
    /// `isAttached` check, this is observable WITHOUT ever reaching that check (which would
    /// otherwise route through `RichTextInputContractViolation.report(...)`, an `assertionFailure()`
    /// in DEBUG with no reporter installed — the "latent hard crash" the package CLAUDE.md and this
    /// task's own controller supplement warn about).
    ///
    /// **Proven capable of failing, not merely capable of passing**: commenting out the
    /// `guard !floatingCursorActive else { return }` line in `IDTextEditorBackend.selectedTextRange`'s
    /// setter and re-running this test — done, then reverted, for this task's report — makes the
    /// write fall through into `setSelection`, whose OWN `isAttached` guard reports a contract
    /// violation on this unattached backend; the reporter spy below observes that report and the
    /// assertion fails, with the real message quoted in the report.
    func test_selectedTextRangeWrite_isDroppedWhileFloatingCursorActive_beforeReachingSetSelection() {
        let backend = IDTextEditorBackend()
        let before = offsets(backend.selectedTextRange)

        var reportedMessages: [String] = []
        let previousReporter = RichTextInputContractViolation.reporter
        RichTextInputContractViolation.reporter = { reportedMessages.append($0) }
        defer { RichTextInputContractViolation.reporter = previousReporter }

        backend.setFloatingCursorActive(true)
        backend.selectedTextRange = TGRichTextInputDecRange(
            from: TGRichTextInputDecPosition(offset: 3, affinity: .forward, revision: 0),
            to: TGRichTextInputDecPosition(offset: 7, affinity: .forward, revision: 0))

        XCTAssertTrue(reportedMessages.isEmpty,
                     "the floating-cursor guard must return BEFORE the write ever reaches setSelection's own isAttached check — a contract-violation report here means the guard did not intercept: \(reportedMessages)")
        let after = offsets(backend.selectedTextRange)
        XCTAssertEqual(after.map { "\($0.0),\($0.1)" }, before.map { "\($0.0),\($0.1)" },
                       "a selectedTextRange write must be dropped while floatingCursorActive is true")

        backend.setFloatingCursorActive(false)
    }

    /// The `.floatingCursor` safety claim this task's `requestedCapabilities` doc comment makes:
    /// `IDUIKitFloatingCursorRuntimeContract()` (`IDUIKitInteractionCapability.m:132`, one of the
    /// kernel's seven surviving `@throw` sites) raises `NSInternalInconsistencyException` only when
    /// `manifest.capabilities["floatingCursor"]` is nil — and that call is reached on EVERY
    /// `IDUIKitInteractionCapability` construction (triggered by `.interaction` alone, requested
    /// since Task C12), independent of whether `.floatingCursor` is itself requested. This test
    /// establishes the precondition does NOT hold on this runtime — live-verified, not merely
    /// asserted from the manifest's own prose description — so that reachable throw path does not
    /// actually fire today. Needs only `TGRichTextInputDecContractManifest()`, no attach, no host,
    /// no view.
    func test_floatingCursorCapabilityIsPresentInTheManifest() {
        guard let manifest = TGRichTextInputDecContractManifest() else {
            XCTFail("the contract manifest must be loadable on this runtime — attach() itself depends on this and would already be failing for an unrelated reason if it were not")
            return
        }
        guard let contract = manifest.capabilities["floatingCursor"] else {
            XCTFail("manifest.capabilities[\"floatingCursor\"] is nil on this runtime — IDUIKitFloatingCursorRuntimeContract() would raise NSInternalInconsistencyException on every IDUIKitInteractionCapability construction (i.e. on every attach that requests .interaction, already true since Task C12)")
            return
        }
        XCTAssertEqual(contract.members.count, 3,
                       "the controller-decoded manifest records 3 members for the floatingCursor capability; a different count here means that decode is stale")
    }
}
#endif

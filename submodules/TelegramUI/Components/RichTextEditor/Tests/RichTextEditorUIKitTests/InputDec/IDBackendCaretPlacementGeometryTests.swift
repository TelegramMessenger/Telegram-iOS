#if canImport(UIKit)
import RichTextInputDecObjC
import RichTextEditorCore
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// TASK F1 — the crash a user hit on a real debug build the first time they tapped into the field
/// with Debug Settings ▸ Experiments ▸ "Text Field v2: InputDec backend" on
/// (`Telegram-2026-08-26-171558.ips`, `EXC_BREAKPOINT` on the main thread):
///
/// ```
///   DocumentCanvasView.performSingleTap(at:)
///     → DocumentCanvasView.setCaret(global:reportSelectionChange:)
///       → RichTextEditorView.scrollCaretIntoView(animated:)
///         → DocumentCanvasView.caretRect(atGlobal:)
///           → IDTextEditorBackend.caretRect(for:)
///             → reportKernelFailure(_:witness:) → RichTextInputContractViolation.report
///               → assertionFailure
/// ```
///
/// **These tests drive `caretRect(atGlobal:)`, deliberately — NOT `caretRect(for:)` with a
/// backend-minted position.** That is the whole reproduction: `DocumentCanvasView
/// +UITextInput.swift`'s `caretRect(atGlobal:)` mints a CANVAS-side identity object
/// (`LegacyTextIdentity.position(atGlobal:)`) whatever backend is installed, and the pre-F1 ID
/// witness forwarded it straight into the vendored kernel, whose layout controller casts every
/// incoming position to `TGRichTextInputDecPosition` unchecked and sends it `-utf16Offset` —
/// `unrecognized selector`, an `NSException`, caught by the exception guard, recorded as a kernel
/// witness failure, and (in DEBUG, with no reporter installed) trapped. Every pre-existing
/// `IDBackendFamily2Tests` case calls `caretRect(for:)` with a KERNEL-minted position instead, which
/// is why none of them ever saw this.
///
/// Assertions are on CAPTURED values (`witnessFailures` snapshotted before asserting, violations
/// collected by an installed reporter), never on live/derived state.
@available(iOS 17.0, *)
@MainActor
final class IDBackendCaretPlacementGeometryTests: XCTestCase {
    private var violations: [String] = []

    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
        violations = []
    }

    override func tearDown() {
        RichTextInputContractViolation.reporter = nil
        super.tearDown()
    }

    /// Replaces the harness factory's own NSLog-only reporter with a capturing one, so a
    /// contract violation is observable rather than merely non-fatal.
    private func captureViolations() {
        RichTextInputContractViolation.reporter = { [weak self] message in
            self?.violations.append(message)
        }
    }

    /// THE CRASH. Placing a caret must not report a kernel failure — under the pre-F1 witness this
    /// records one `caretRect(for:)` entry (and, without the harness's reporter, traps).
    func test_placingACaretThroughTheCanvasReportsNoKernelFailure() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        captureViolations()
        h.geometry.caretGeometryToReturn = RichTextInputCaretGeometry(
            position: .downstream(1), rect: CGRect(x: 7, y: 8, width: 2, height: 17),
            writingDirection: .leftToRight,
            lineID: RichTextInputLineID(blockID: BlockID(""), regionIndex: 0),
            documentRevision: h.document.revision, layoutGeneration: 1)

        _ = h.canvas.caretRect(atGlobal: 1)

        let recordedFailures = h.idBackend.witnessFailures
        let recordedViolations = violations
        XCTAssertEqual(recordedFailures, [],
                       "placing a caret must not fail a kernel witness — this is the reported crash")
        XCTAssertEqual(recordedViolations, [],
                       "…and must not report a contract violation, which is what traps in DEBUG")
    }

    /// The specified behaviour (`IDBackendFamily2Tests
    /// .test_caretRectForAKnownOffset_matchesTheGeometryClient`, over the canvas-minted position the
    /// production path actually uses): the geometry client is the caret-geometry authority, so the
    /// witness returns ITS rect verbatim.
    func test_caretRectAtAGlobalOffset_matchesTheGeometryClient() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        captureViolations()
        let rect = CGRect(x: 7, y: 8, width: 2, height: 17)
        h.geometry.caretGeometryToReturn = RichTextInputCaretGeometry(
            position: .downstream(1), rect: rect, writingDirection: .leftToRight,
            lineID: RichTextInputLineID(blockID: BlockID(""), regionIndex: 0),
            documentRevision: h.document.revision, layoutGeneration: 1)

        let observed = h.canvas.caretRect(atGlobal: 1)

        let queries = h.geometry.callCounts["caretGeometry"]
        XCTAssertEqual(observed, rect)
        XCTAssertEqual(queries, 1, "the geometry client must be the authority that was asked")
    }

    /// Deviation D9 survives the reroute: a genuinely foreign position (one neither this backend nor
    /// the canvas minted) still degrades to `.zero` at the UIKit edge — and, per defect 2, without
    /// trapping.
    func test_aForeignPositionStillDegradesToZero() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        captureViolations()
        final class OpaqueForeignTextPosition: UITextPosition {}
        h.geometry.caretGeometryToReturn = RichTextInputCaretGeometry(
            position: .downstream(1), rect: CGRect(x: 7, y: 8, width: 2, height: 17),
            writingDirection: .leftToRight,
            lineID: RichTextInputLineID(blockID: BlockID(""), regionIndex: 0),
            documentRevision: h.document.revision, layoutGeneration: 1)

        let observed = h.canvas.caretRect(for: OpaqueForeignTextPosition())

        let recordedFailures = h.idBackend.witnessFailures
        XCTAssertEqual(observed, .zero)
        XCTAssertEqual(recordedFailures, [], "a foreign position is a caller error, not a kernel failure")
    }

    /// THE CRASH, over the REAL Telegram clients rather than the fakes — the closest a unit test gets
    /// to what the user did. `makeBackendHarness(backend: .inputDec)` builds an `IDDocumentCanvasView`
    /// wired to the real `TelegramGeometryInputClient`/`TelegramDocumentInputClient` over a laid-out
    /// two-paragraph fixture, and `caretRect(atGlobal: canvas.head)` is verbatim the expression
    /// `RichTextEditorView.scrollCaretIntoView(animated:)` evaluates on the crashing frame.
    ///
    /// Asserting the rect is NON-EMPTY is the load-bearing half. `.zero` is D9's sanctioned "no
    /// geometry" answer and would satisfy any "did not crash" check while leaving the caret unable to
    /// scroll into view — a silent degradation of exactly the kind this backend has produced six times
    /// before. A real rect proves the geometry client answered, not merely that nothing raised.
    func test_caretRectAtTheLiveCaret_overTheRealClients_isRealGeometryAndDoesNotReport() {
        let h = makeBackendHarness(backend: .inputDec); defer { h.tearDown() }
        captureViolations()
        h.caret(1)

        let rect = h.canvas.caretRect(atGlobal: h.canvas.head)

        let recordedViolations = violations
        XCTAssertFalse(rect.isEmpty,
                       "the live caret must report real geometry through the real geometry client, " +
                       "not D9's .zero absent value: \(rect)")
        XCTAssertEqual(recordedViolations, [],
                       "no contract violation may be reported on the caret-scroll path")
    }

    /// DEFECT 2, at its own layer: a kernel witness failure is RECORDED and REPORTED, never trapped.
    ///
    /// Driven through `offset(from:to:)` — a FAMILY 1 witness, which still routes into the kernel
    /// after this task and therefore stays a durable driver — handed a foreign `UITextPosition`. That
    /// is a genuine kernel failure of exactly the shape the crash report shows: the layout controller
    /// casts the position to `TGRichTextInputDecPosition` unchecked, `-utf16Offset` is an unrecognized
    /// selector, the raised `NSException` is converted to an `NSError` by the exception guard, and
    /// `reportKernelFailure(_:witness:)` is reached.
    ///
    /// A post-`detach()` call is NOT usable here even though the kernel's `activeController` raises on
    /// one: `detach()` also nils `kernelInput`, so `self.kernelInput?.…` short-circuits and no kernel
    /// call is ever made (measured — the first draft of this test asserted on that path and recorded
    /// zero failures).
    func test_aKernelWitnessFailureIsRecordedAndReportedButNotFatal() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        captureViolations()
        final class OpaqueForeignTextPosition: UITextPosition {}

        _ = h.idBackend.offset(from: OpaqueForeignTextPosition(), to: OpaqueForeignTextPosition())

        let recordedFailures = h.idBackend.witnessFailures
        let recordedViolations = violations
        XCTAssertFalse(recordedFailures.isEmpty,
                       "witnessFailures must still record the failure — the tests read it")
        XCTAssertTrue(recordedFailures.contains { $0.contains("offset(from:to:)") },
                      "the recorded entry names the witness: \(recordedFailures)")
        XCTAssertFalse(recordedViolations.isEmpty,
                       "the diagnostic must stay loud — a kernel failure still reports through the " +
                       "reporter hook, it just must not trap")
    }
}
#endif

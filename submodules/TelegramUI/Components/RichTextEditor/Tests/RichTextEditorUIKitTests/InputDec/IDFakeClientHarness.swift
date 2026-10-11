#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit
// TASK D2: `ParagraphBlock`/`BlockID`/`TextRun` (used to seed the `.legacy` canvas below) are
// `RichTextEditorCore` types — `RichTextEditorUIKit` doesn't re-export its own Core import.
import RichTextEditorCore

/// The ID backend attached to the seam plan's seven fake clients, all sharing one ordered log.
///
/// Distinct from `makeBackendHarness(backend: .inputDec)`, which attaches the REAL Telegram
/// clients to a real canvas. Use this one when the assertion is about the client boundary
/// (call counts, argument values, interleaving); use that one when the assertion is about
/// canvas-visible behavior.
///
/// Task C7 retypes this to the brief's own `TGRichTextInputDecTextStorageFacade` — NON-optional,
/// deliberately, and force-unwrapping `backend.storageFacadeForTesting` (which stays `Optional` on
/// the backend, since it is nil whenever no bridge is attached) rather than keeping this property
/// `Optional` too. Two reasons: (1) the brief's own Step-1 test (`IDBackendIntentLatchTests`)
/// writes `h.storageFacade.currentIntent = .insertText` and `h.storageFacade.replaceCharacters(...)`
/// — positional, non-optional-chained access — which requires this exact non-optional shape to
/// compile as written; (2) every harness built by `makeIDFakeClientHarness` is fully attached by
/// construction (the factory calls `try! backend.attach(to: host)` before returning), so the force
/// unwrap can only fail if the harness itself is broken, matching the established convention
/// elsewhere in this suite (e.g. `RichTextInputBackendHarness.undoManager`'s own force-unwrap).
@MainActor
@available(iOS 17.0, *)
final class IDFakeClientHarness {
    /// TASK D2 WIDENING: was `IDTextEditorBackend` — narrowed at construction by
    /// `makeIDFakeClientHarness(kind:)`'s new `kind:` parameter, `.legacy` producing a
    /// `LegacyRichTextInputBackend` here instead. See that factory's own doc comment for why the
    /// stored type must be the shared protocol: `IDBackendDifferentialTraceTests` drives ONE
    /// `IDTraceScenario.body` closure against both backend kinds, so the closure's parameter type
    /// cannot name either concrete backend.
    let backend: any RichTextInputBackend
    /// TASK D2 WIDENING: was `IDDocumentCanvasView` — same reasoning as `backend` above. Every
    /// existing call site that reaches this property from a `.inputDec`-only suite (the default
    /// `kind`) already only touches members `DocumentCanvasView` declares, so this widening is
    /// source-compatible everywhere except the few `IDTextEditorBackend`-only members funneled
    /// through `idBackend` below.
    let canvas: DocumentCanvasView
    let host: FakeInputHost
    let log: RichTextInputEventLog

    var document: FakeInputDocumentClient { host.fakeDocumentClient }
    var geometry: FakeInputGeometryClient { host.fakeGeometryClient }
    var annotation: FakeInputAnnotationClient { host.fakeAnnotationClient }
    var presentation: FakeInputPresentationClient { host.fakePresentationClient }
    var lifecycle: FakeInputLifecycleClient { host.fakeLifecycleClient }
    var command: FakeInputCommandClient { host.fakeCommandClient }
    /// DEVIATION FROM THE D2 BRIEF'S STEP-1 TEXT — a real conflict, not a design choice. The brief
    /// asked to retype this `Optional` (`(backend as? IDTextEditorBackend)?.storageFacadeForTesting`)
    /// so the moved `test_storageFacadeIsVendedForInputDecAndNilForLegacy` could read it directly. But
    /// this property's ORIGINAL (pre-D2) doc comment recorded a DELIBERATE, load-bearing reason it must
    /// stay non-optional: dozens of pre-existing `.inputDec`-only call sites across
    /// `IDBackendIntentLatchTests`, `IDBackendFamily4Tests`, `IDBackendFamily5Tests` (measured — a full
    /// compile pass under the brief's literal Optional retyping surfaced ~20 errors across exactly
    /// those three files) write `h.storageFacade.currentIntent = ...` /
    /// `h.storageFacade.replaceCharacters(...)` — positional, non-optional-chained access that
    /// requires this exact non-optional shape to compile. Making it Optional is not a source-compatible
    /// widening the way `backend`/`canvas` above are; it is a breaking retype of an established,
    /// heavily-used surface. Kept non-optional (now via `as!` on the widened `backend`, same force-unwrap
    /// discipline as before — every caller of this property is `.inputDec`-only by construction).
    /// `storageFacadeIfAvailable` below is the NEW, Optional-returning accessor the D2 differential
    /// harness's nil-check actually needs, so nothing forces a choice between the two use cases.
    var storageFacade: TGRichTextInputDecTextStorageFacade { (backend as! IDTextEditorBackend).storageFacadeForTesting! }

    /// TASK D2 ADDITION. `nil` under `.legacy` instead of crashing — used by
    /// `test_storageFacadeIsVendedForInputDecAndNilForLegacy` (moved here from `IDHarnessTests`, driven
    /// by `kind:`), the one call site that must observe both backends without a precondition that it's
    /// always `.inputDec`.
    var storageFacadeIfAvailable: TGRichTextInputDecTextStorageFacade? { (backend as? IDTextEditorBackend)?.storageFacadeForTesting }

    /// TASK D2 ADDITION. A handful of pre-existing `.inputDec`-only suites (`IDBackendFamily2/9/10/11Tests`)
    /// read members that live on the CONCRETE `IDTextEditorBackend` only (`bridgeForTesting`,
    /// `witnessFailures`, `kernelInteraction`, `selectWord()`) or construct
    /// `IDTextEditorBackendClientBridge(backend:)`, which itself requires the concrete type — none of
    /// those are part of the shared `RichTextInputBackend` protocol, so widening `backend` above breaks
    /// them without this convenience. Force-downcast is safe: every one of those suites builds through
    /// the default `kind: .inputDec`, exactly the precondition `storageFacade` above documents.
    var idBackend: IDTextEditorBackend { backend as! IDTextEditorBackend }

    init(backend: any RichTextInputBackend, canvas: DocumentCanvasView,
         host: FakeInputHost, log: RichTextInputEventLog) {
        self.backend = backend; self.canvas = canvas; self.host = host; self.log = log
    }

    /// R1: also clears `RichTextInputContractViolation.reporter`, undoing the install
    /// `makeIDFakeClientHarness` performs below.
    func tearDown() {
        backend.detach()
        // The fake document client's own finish() flags an un-consumed preparation, which is
        // the seam plan's default "token consumed exactly once" assertion.
        document.finish()
        RichTextInputContractViolation.reporter = nil
    }
}

/// Backend-agnostic construction order matters: the canvas must exist before `FakeInputHost` is
/// built (it vends `hostInputView`), and the backend is detached from the canvas and re-attached
/// to the fake host.
///
/// Constructing a SECOND `IDTextEditorBackend` would leave two backends contending for one
/// canvas's associated bridge — the thunks would answer whichever set it last, and the failure
/// would read as a random test-ordering flake — so `IDDocumentCanvasView(inputBackend:)`'s own
/// self-attach (seam Task 20 Step 5) is detached and the SAME backend instance is re-attached to
/// the fake host below.
@MainActor
@available(iOS 17.0, *)
func makeIDFakeClientHarness(kind: RichTextInputBackendKind = .inputDec,
                             paragraphs: [String] = ["Alpha", "Beta"],
                             width: CGFloat = 300) -> IDFakeClientHarness {
    // R1: every witness the returned harness's `backend`/`canvas` can be driven through can hit
    // `IDTextEditorBackend.reportKernelFailure(_:witness:)` → `RichTextInputContractViolation.report`
    // — an `assertionFailure()` in DEBUG unless a reporter is installed first (see that type's own
    // doc comment). Installed here, at the ONE factory every `IDBackendFamilyNTests` file that uses
    // this fake-client harness builds through, mirroring `BackendContractCases`'s "install here,
    // clear in tearDown" pattern. `IDFakeClientHarness.tearDown()` clears it.
    RichTextInputContractViolation.reporter = { message in
        NSLog("RichTextInput contract violation (recorded, not trapped, by the test harness): %@", message)
    }
    let log = RichTextInputEventLog()
    // TASK D2: `kind` selects the concrete backend/canvas PAIR — never mix a `LegacyRichTextInputBackend`
    // with an `IDDocumentCanvasView` or vice versa. Per-backend construction, not a single generic path:
    // `IDBackendDifferentialTraceTests`' own supplement flags this as the expected shape (Legacy's opaque
    // identity types cannot cross into the ID backend, R8/R11/R12).
    let backend: any RichTextInputBackend = kind == .inputDec ? IDTextEditorBackend() : LegacyRichTextInputBackend()
    let canvas: DocumentCanvasView = kind == .inputDec
        ? IDDocumentCanvasView(inputBackend: backend)
        : DocumentCanvasView(inputBackend: backend)
    canvas.frame = CGRect(x: 0, y: 0, width: width, height: 600)
    // TASK D2: seed the CANVAS's own block model too, for `.legacy` ONLY — not only the fake document
    // client's `text`. `.inputDec` never reads canvas content (the façade mirrors FROM
    // `documentClient.plainText(in:)`, never from `canvas.boxes`) and every pre-existing `.inputDec`-only
    // suite built this harness with an unseeded canvas, so this stays scoped to `.legacy` to leave that
    // path byte-for-byte unchanged. `.legacy` is the opposite: its `insertText`/`deleteBackward`/
    // `setMarkedText` witnesses are PLAIN FORWARDS onto `legacyCanvas.legacyInsertText`/
    // `legacyDeleteBackward`/`legacySetMarkedText` — the canvas's OWN block/paragraph storage IS the
    // document engine for Legacy (`LegacyRichTextInputBackend+Insertion.swift`'s own doc comment: "Legacy
    // owns every branch ... because it IS the document engine"). An unseeded canvas made every Legacy
    // scenario body operate on zero paragraphs.
    if kind == .legacy {
        canvas.setParagraphs(paragraphs.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: width)
        canvas.layoutIfNeeded()
    }
    backend.detach()

    let host = FakeInputHost(hostInputView: canvas, log: log, text: paragraphs.joined(separator: "\n"))
    try! backend.attach(to: host)
    return IDFakeClientHarness(backend: backend, canvas: canvas, host: host, log: log)
}

/// TASK D2 ADDITION. Thin alias fixing `kind: .legacy` — see `makeIDFakeClientHarness(kind:)`'s own
/// doc comment for the construction this shares.
@MainActor
@available(iOS 17.0, *)
func makeLegacyFakeClientHarness(paragraphs: [String] = ["Alpha", "Beta"],
                                 width: CGFloat = 300) -> IDFakeClientHarness {
    makeIDFakeClientHarness(kind: .legacy, paragraphs: paragraphs, width: width)
}
#endif

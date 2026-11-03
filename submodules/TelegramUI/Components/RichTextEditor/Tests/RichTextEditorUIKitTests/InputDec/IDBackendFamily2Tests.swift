#if canImport(UIKit)
import RichTextInputDecObjC
import RichTextEditorCore
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C5 — the ID-SPECIFIC assertions for Family 2 (geometry): every assertion here is about
/// the client boundary (the ObjC ↔ Swift bridge and, through it, the fake geometry client), which
/// has no legacy counterpart. The backend-agnostic family-2 assertions live in
/// `BackendSemanticContractCases` (Task C3's shared suite) and are not repeated here.
///
/// Gated exactly like `IDBackendFamily1Tests` (Task C4) and every other `.inputDec` suite in this
/// stage: `isSupported()` evaluates the WHOLE `incomingCallbacks` capability all-or-nothing across
/// all 47 rows, spread over six tasks (see `task-C5-supplement.md` §1). This task lands 12 of the
/// remaining 21 — construction now gets PAST the `-textContainers` blocker C4 traced (see
/// `DIVERGENCES.md` entry 5) — but 9 rows still belong to C6/C12/C14, so `incomingCallbacks` stays
/// rejected and `isSupported()` stays FALSE on this runtime, and every test below is still expected
/// to SKIP. That is expected here, not a regression — see `task-C5-report.md` for the measured
/// mismatch count (21 → 9) and the real, non-skipped evidence that DOES move: the attach-failure
/// text observed through the C3 inherited contract suites (`IDBackendMutationContractTests` etc.),
/// which reach real `attach(to:)` unconditionally and are not gated on `isSupported()`.
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily2Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    func test_caretRectForAKnownOffset_matchesTheGeometryClient() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let rect = CGRect(x: 3, y: 4, width: 5, height: 6)
        h.geometry.caretGeometryToReturn = RichTextInputCaretGeometry(
            position: .downstream(0), rect: rect, writingDirection: .leftToRight,
            lineID: RichTextInputLineID(blockID: BlockID(""), regionIndex: 0),
            documentRevision: h.document.revision, layoutGeneration: 1)
        XCTAssertEqual(h.canvas.caretRect(for: h.canvas.beginningOfDocument), rect)
    }

    /// The spec's "never a fabricated CGRect.zero" rule is a CLIENT-boundary rule — the `.zero`
    /// at the UIKit edge is deviation D9's pinned behavior that callers already branch on. Both
    /// halves are asserted: the geometry client really was asked (proving the NO is genuine, not
    /// skipped over), and the UIKit-facing witness still answers `.zero`.
    func test_missingGeometryIsNilAcrossTheBridge_butZeroAtTheUIKitWitness() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.geometry.caretGeometryToReturn = nil
        let rect = h.canvas.caretRect(for: h.canvas.beginningOfDocument)
        XCTAssertEqual(rect, .zero, "the UIKit-facing witness keeps deviation D9's .zero fallback")
        XCTAssertEqual(h.geometry.callCounts["caretGeometry"], 1,
                       "the geometry client must actually be asked — and answer NO — before .zero " +
                       "is produced; a .zero with no query would be a fabrication, not a translation")
    }

    /// 500-paragraph Select All. The bounded-request contract (already proven at the client
    /// boundary by `BoundedSelectionGeometryTests`) requires the double optional to be unwrapped —
    /// `XCTUnwrap` fails loudly if no request was ever recorded, which is the vacuous case.
    func test_selectionRectsAreBoundedByTheVisibleRect() throws {
        let paragraphs = (0..<500).map { "Paragraph number \($0)" }
        let h = makeIDFakeClientHarness(paragraphs: paragraphs); defer { h.tearDown() }
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument, to: h.canvas.endOfDocument)!
        _ = h.canvas.selectionRects(for: whole)
        XCTAssertEqual(try XCTUnwrap(h.geometry.receivedRequests.last?.visibleRect), h.canvas.bounds)
    }

    /// Mirrors the seam's `BoundedSelectionGeometryTests.test_boundedRequestRealizesNoAdditionalBlockViews`:
    /// a geometry query must not itself force persistent block-view realization.
    func test_selectAllRealizesNoAdditionalBlockViews() {
        let paragraphs = (0..<500).map { "Paragraph number \($0)" }
        let h = makeIDFakeClientHarness(paragraphs: paragraphs); defer { h.tearDown() }
        let before = h.canvas.realizedBlockViewCountForTesting
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument, to: h.canvas.endOfDocument)!
        _ = h.canvas.selectionRects(for: whole)
        XCTAssertEqual(h.canvas.realizedBlockViewCountForTesting, before,
                       "a geometry query may not create persistent block views")
    }

    /// Every `TGRichTextInputDecGeometryPurpose` case reaches the geometry client unchanged.
    /// Constructs a second `IDTextEditorBackendClientBridge` sharing the harness's own host/backend
    /// — legal (`internal`, `@testable`) and the most direct way to drive
    /// `caretGeometry(atOffset:...purpose:...)` with every purpose value in turn, since none of
    /// this family's 12 `id_`-prefixed layout-controller callbacks (deliberately undeclared, so
    /// nothing can call them through static typing — see `TGRichTextInputDecLayoutControllerInternal.h`)
    /// are reachable directly from Swift test code.
    func test_geometryPurposeReachesTheClientUnchanged() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let bridge = IDTextEditorBackendClientBridge(host: h.host, backend: h.idBackend)
        let purposes: [(TGRichTextInputDecGeometryPurpose, String)] = [
            (.keyboard, "keyboard"),
            (.caret, "caret"),
            (.selectionEndpoint, "selectionEndpoint"),
            (.selectionPresentation, "selectionPresentation"),
            (.loupe, "loupe"),
            (.floatingCursor, "floatingCursor"),
            (.editMenu, "editMenu"),
            (.accessibility, "accessibility"),
        ]
        for (objcPurpose, expectedDescription) in purposes {
            var rect = CGRect.zero
            var direction: NSWritingDirection = .natural
            var generation: UInt64 = 0
            _ = withUnsafeMutablePointer(to: &rect) { rectPointer in
                withUnsafeMutablePointer(to: &direction) { directionPointer in
                    withUnsafeMutablePointer(to: &generation) { generationPointer in
                        bridge.caretGeometry(atOffset: 0, affinity: .forward, revision: h.document.revision,
                                            purpose: objcPurpose, outRect: rectPointer,
                                            outWritingDirection: directionPointer,
                                            outLayoutGeneration: generationPointer)
                    }
                }
            }
            XCTAssertEqual(h.log.events.last,
                           .geometryQuery(kind: "caretGeometry", revision: h.document.revision,
                                         purpose: expectedDescription))
        }
    }
}
#endif

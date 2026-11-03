#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C4 — the ID-SPECIFIC assertions for Family 1 (document reads and position/range
/// conversion): backend-owned identity types and client call counts, which have no legacy
/// counterpart. The backend-agnostic family-1 assertions already live in
/// `BackendSemanticContractCases` (Task C3) and are not repeated here.
///
/// Gated exactly like every other `.inputDec` suite in this stage: `isSupported()` evaluates the
/// WHOLE `incomingCallbacks` capability all-or-nothing (47 rows, spread across six tasks — see
/// `task-C4-supplement.md` §1), so it stays false — and every test below SKIPS — until Task C14
/// lands the last row. That is expected here, not a regression; see `task-C4-report.md`.
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily1Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    func test_beginningAndEndOfDocument_areBackendOwnedIdentity() {
        let h = makeBackendHarness(backend: .inputDec); defer { h.tearDown() }
        XCTAssertTrue(h.canvas.beginningOfDocument is TGRichTextInputDecPosition,
                      "the ID backend must not vend the legacy identity type")
        XCTAssertTrue(h.canvas.endOfDocument is TGRichTextInputDecPosition)
    }

    func test_textInRange_matchesTheDocumentClientProjection() {
        let h = makeIDFakeClientHarness(paragraphs: ["Alpha", "Beta"]); defer { h.tearDown() }
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument,
                                       to: h.canvas.endOfDocument)!
        XCTAssertEqual(h.canvas.text(in: whole), h.document.text)
    }

    /// TASK R2 UPDATE: baseline is `1`, not `0` — `attach(to:)` now seeds the initial selection
    /// with one `clamp(.downstream(0))` call of its own (mirrors
    /// `LegacyRichTextInputBackend.installInitialState(from:)`; see `IDFakeClientHarnessTests
    /// .test_theNewCountersStartAtZeroAndAreMutable`'s own updated doc comment for the full
    /// reasoning). The two calls THIS test drives are still exactly two on top of that baseline —
    /// unchanged from before.
    func test_positionArithmetic_clampsThroughTheDocumentClient() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let baseline = h.document.clampCallCount
        let start = h.canvas.beginningOfDocument
        XCTAssertNil(h.canvas.position(from: start, offset: -1))
        XCTAssertNotNil(h.canvas.position(from: start, offset: 1))
        XCTAssertEqual(h.document.clampCallCount, baseline + 2,
                       "position arithmetic must clamp through the client, not locally")
    }

    /// Position identity compares (utf16Offset, affinity) only. The revision is staleness
    /// metadata, not identity — otherwise two logically identical positions would compare
    /// unequal across an unrelated edit.
    func test_positionEqualityIgnoresTheRevision() {
        let a = TGRichTextInputDecPosition(offset: 3, affinity: .forward, revision: 1)
        let b = TGRichTextInputDecPosition(offset: 3, affinity: .forward, revision: 9)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hash, b.hash)
        XCTAssertNotEqual(a, TGRichTextInputDecPosition(offset: 3, affinity: .backward, revision: 1))
    }

    func test_aStalePosition_isRebasedExactlyOnce() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let stale = TGRichTextInputDecPosition(offset: 3, affinity: .forward,
                                               revision: h.document.revision)
        h.document.settableRevision += 1
        _ = h.canvas.offset(from: h.canvas.beginningOfDocument, to: stale)
        XCTAssertEqual(h.document.rebaseCallCount, 1,
                       "one rebase per operation — a second miss must give up, not loop")
    }
}
#endif

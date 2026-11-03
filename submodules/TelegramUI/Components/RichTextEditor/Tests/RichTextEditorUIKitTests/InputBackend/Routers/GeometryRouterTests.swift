#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 25 — Family 2 (geometry), the second family task, same shape as `TextReadRouterTests` (Task
/// 24). Every routing test below uses `XCTAssertRoutesOnly` (`T/Support/RouterAssertions.swift`) —
/// exit criterion 3's four clauses ("one backend call", "exact arguments", "exact return propagation",
/// "and nothing else" on both the backend log and the canvas state) in one line, exactly like Family 1.
///
/// `RouterStateSnapshot`'s canvas-side "did no work" clause is INERT for this family too (carried
/// forward from Task 24's review): none of the eight pre-seam bodies mutated revision, layout
/// generation, anchor/head, marked range, undo count, or the edit-menu counter, so that half of
/// `XCTAssertRoutesOnly` passes identically whether or not the witness is routed. It is still used, for
/// uniformity, but the load-bearing clauses here are the single-call/arguments check and the
/// return-value check.
///
/// Two bespoke tests below (`test_caretRect_returnsZeroWhenTheGeometryClientReturnsNil` /
/// `…_returnsTheStubbedRectOtherwise`) exercise the REAL `LegacyRichTextInputBackend` behind a
/// `FakeInputGeometryClient` instead of the canvas-router spy — they pin Deviation D9's `?? .zero`
/// translation itself (a `SpyRichTextInputBackend`-based router test cannot: the spy's own
/// `caretRect(for:)` never calls a geometry client at all, so it cannot exercise the translation this
/// family's whole `+Geometry.swift` file exists to add). `FakeInputHost`/`LegacyRichTextInputBackend`
/// are constructed directly here — legal because `GeometryRouterTests` is a plain `XCTestCase`, not a
/// `BackendContractCases` descendant, so R10/R11 (`InputBackendSourceBoundaryTests.swift`) — which
/// restrict concrete-type construction only inside that ancestry — do not apply to this file at all.
@MainActor
@available(iOS 16.0, *)
final class GeometryRouterTests: XCTestCase {
    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        spy.reset()
        return (v, spy)
    }

    // MARK: - The eight witnesses, routed through the canvas onto the spy backend

    /// Vacuity check (documented, not asserted mechanically): the unrouted canvas's own
    /// `firstRect(for:)` on `spy.sentinelRange` (offsets −9009/−9008, both far outside any leaf
    /// region) resolves `selectionRects(globalFrom:-9009, globalTo:-9008)` to an EMPTY rect list per
    /// region (`lo = max(-9009, r.globalStart)` is positive, `hi = min(-9008, r.end)` stays deeply
    /// negative, so `lo < hi` never holds) — `.first` is `nil`, so `?? .zero` yields `CGRect.zero`.
    /// `spy.stubbedFirstRect` is `(55, 66, 77, 88)`, which cannot coincide with that.
    func test_firstRect_returnsTheBackendsExactRect() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "firstRect(for:)",
                                         arguments: [ObjectIdentifier(spy.sentinelRange).debugDescription]) {
            v.firstRect(for: spy.sentinelRange)
        }
        XCTAssertEqual(result, spy.stubbedFirstRect)
    }

    /// Vacuity check: the unrouted canvas's `caretRect(for:)` on `spy.sentinelPosition` (offset
    /// −9009) clamps to 0 (`clampGlobal`), finds no leaf region there (the fixture's first region
    /// starts at global 1), no media gap, no collapsed-quote gap, so `legacyCaretRect` returns `nil`
    /// and the witness answers `.zero`. `spy.stubbedCaretRect` is `(11, 22, 33, 44)`, which differs.
    func test_caretRect_returnsTheBackendsExactRect() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "caretRect(for:)",
                                         arguments: [ObjectIdentifier(spy.sentinelPosition).debugDescription]) {
            v.caretRect(for: spy.sentinelPosition)
        }
        XCTAssertEqual(result, spy.stubbedCaretRect)
    }

    /// Vacuity check: the unrouted canvas's `selectionRects(for:)` on `spy.sentinelRange` (same
    /// far-out-of-range offsets as `firstRect` above) collects zero rects for the same reason, so an
    /// unrouted read would answer `[]`. `spy.stubbedSelectionRects` was deliberately changed away from
    /// `[]` (Task 23 fix round 1) to `[spy.sentinelSelectionRect]` for exactly this reason — a `[]`
    /// default would make this assertion pass whether or not the canvas actually routes.
    func test_selectionRects_returnsTheBackendsExactRects() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "selectionRects(for:)",
                                         arguments: [ObjectIdentifier(spy.sentinelRange).debugDescription]) {
            v.selectionRects(for: spy.sentinelRange)
        }
        // Guarded (not a bare `XCTAssertEqual` + unconditional index): found via this task's own
        // red-check that an unguarded `result[0]` after a FAILED count assertion crashes the test
        // process (`Fatal error: Index out of range`) against the pre-seam, unrouted body, which
        // returns `[]` — XCTest continues past a failed assertion, so the very next line's array
        // index still runs. Failing cleanly here keeps the mutation a reportable test failure rather
        // than a process crash.
        guard result.count == 1 else {
            XCTFail("expected exactly one selection rect forwarded, got \(result.count)")
            return
        }
        XCTAssertTrue(result[0] === spy.sentinelSelectionRect,
                      "the router must forward the object, not rebuild it")
    }

    /// Identity-based: an unrouted canvas always CONSTRUCTS a fresh `DocumentTextPosition` from
    /// `closestGlobalPosition(to:)`'s Int, never the spy's own persistent `sentinelPosition` instance —
    /// so `===` discriminates a non-routing canvas regardless of which coordinate the tap resolves to.
    func test_closestPositionToPoint_forwardsThePoint() {
        let (v, spy) = spyCanvas()
        let point = CGPoint(x: 12, y: 34)
        let result = XCTAssertRoutesOnly(v, spy, member: "closestPosition(to:)",
                                         arguments: [String(describing: point)]) {
            v.closestPosition(to: point)
        }
        XCTAssertTrue(result === spy.sentinelPosition,
                      "the router must forward the object, not rebuild it")
    }

    /// Same identity argument as `closestPosition(to:)` above, plus the range argument is asserted
    /// explicitly (a router that dropped it would still return the sentinel and still record one call).
    func test_closestPositionToPointWithinRange_forwardsPointAndRange() {
        let (v, spy) = spyCanvas()
        let point = CGPoint(x: 5, y: 6)
        let result = XCTAssertRoutesOnly(v, spy, member: "closestPosition(to:within:)",
                                         arguments: [String(describing: point),
                                                     ObjectIdentifier(spy.sentinelRange).debugDescription]) {
            v.closestPosition(to: point, within: spy.sentinelRange)
        }
        XCTAssertTrue(result === spy.sentinelPosition,
                      "the router must forward the object, not rebuild it")
    }

    /// Identity-based, same reasoning as `closestPosition(to:)`: an unrouted canvas builds a fresh
    /// `DocumentTextRange`, never the spy's own `sentinelRange`.
    func test_characterRangeAt_forwardsThePoint() {
        let (v, spy) = spyCanvas()
        let point = CGPoint(x: 7, y: 8)
        let result = XCTAssertRoutesOnly(v, spy, member: "characterRange(at:)",
                                         arguments: [String(describing: point)]) {
            v.characterRange(at: point)
        }
        XCTAssertTrue(result === spy.sentinelRange,
                      "the router must forward the object, not rebuild it")
    }

    /// Vacuity check: the "Alpha" fixture is plain English (LTR), auto-detected, and
    /// `spy.sentinelPosition`'s offset clamps into range — so an unrouted read resolves
    /// `.leftToRight`, which `spy.stubbedWritingDirection` (`.rightToLeft`) cannot coincide with.
    func test_baseWritingDirectionForIn_forwardsPositionAndDirection() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "baseWritingDirection(for:in:)",
                                         arguments: [ObjectIdentifier(spy.sentinelPosition).debugDescription,
                                                     String(describing: UITextStorageDirection.forward)]) {
            v.baseWritingDirection(for: spy.sentinelPosition, in: .forward)
        }
        XCTAssertEqual(result, spy.stubbedWritingDirection)
    }

    /// `setBaseWritingDirection` is a no-op on both sides (pre-seam AND the backend's routed body), so
    /// there is no return value or canvas-state effect to assert return-propagation against — the
    /// single-call/exact-arguments clause is the whole test, same shape `XCTAssertRoutesOnly` gives
    /// every other member.
    func test_setBaseWritingDirectionForRange_forwardsDirectionAndRange() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "setBaseWritingDirection(_:for:)",
                           arguments: [String(describing: NSWritingDirection.rightToLeft),
                                       ObjectIdentifier(spy.sentinelRange).debugDescription]) {
            v.setBaseWritingDirection(.rightToLeft, for: spy.sentinelRange)
        }
    }

    // MARK: - Deviation D9, pinned directly against the REAL backend

    /// The D9 translation itself: when the geometry client reports no geometry, the backend's
    /// `caretRect(for:)` must answer `.zero` — asserted as the ONLY transformation performed anywhere
    /// in this family (every other member either forwards a value unchanged or reproduces pure
    /// pre-seam arithmetic, per `+Geometry.swift`'s header comment).
    func test_caretRect_returnsZeroWhenTheGeometryClientReturnsNil() {
        let log = RichTextInputEventLog()
        let host = FakeInputHost(log: log)
        let backend = LegacyRichTextInputBackend()
        try! backend.attach(to: host)
        host.fakeGeometryClient.caretGeometryToReturn = nil

        let result = backend.caretRect(for: DocumentTextPosition(5))

        XCTAssertEqual(result, .zero)
    }

    /// The other half: when the client DOES report geometry, its exact rect passes through unchanged —
    /// no rounding, no offsetting, no further transformation.
    func test_caretRect_returnsTheStubbedRectOtherwise() {
        let log = RichTextInputEventLog()
        let host = FakeInputHost(log: log)
        let backend = LegacyRichTextInputBackend()
        try! backend.attach(to: host)
        let rect = CGRect(x: 3, y: 4, width: 5, height: 6)
        host.fakeGeometryClient.caretGeometryToReturn = RichTextInputCaretGeometry(
            position: .downstream(5), rect: rect, writingDirection: .leftToRight,
            lineID: RichTextInputLineID(blockID: BlockID(""), regionIndex: 0),
            documentRevision: host.fakeDocumentClient.revision, layoutGeneration: 1)

        let result = backend.caretRect(for: DocumentTextPosition(5))

        XCTAssertEqual(result, rect)
    }
}
#endif

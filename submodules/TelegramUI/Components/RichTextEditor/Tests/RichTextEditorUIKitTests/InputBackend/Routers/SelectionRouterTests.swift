#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 26 — Family 3, the ROUTING half: `selectedTextRange` and `inputDelegate`.
///
/// **Which backend each test runs against, and therefore which assertion helper is correct.** The
/// carry-forward note from Task 25's review said `XCTAssertRoutesOnly`'s canvas-side
/// "and-nothing-else" clause "flips from inert to load-bearing" in this family. Checked, and the
/// precise answer is: it flips only for the REAL backend, and it flips to *wrong*, not to
/// load-bearing.
///   * Against the **spy** (every test in the first section below) the backend does no work at all, so
///     `RouterStateSnapshot`'s seven fields cannot move and `XCTAssertRoutesOnly` is exactly right —
///     and it is now genuinely non-inert for `selectedTextRange`'s SETTER, which under the real
///     backend moves `anchor`, `head` and `dismissEditMenuCountForTesting`. A canvas router that
///     "helpfully" kept a copy of the old inline body alongside the forward would fail here.
///   * Against the **real legacy backend** (the second section) a correctly-routed selection write
///     legitimately moves those same three fields, so `XCTAssertRouterDidNoWork` would fail FOR
///     CORRECT CODE. Those tests assert an expected DELTA instead — which is the stronger assertion
///     anyway, since it pins the canvas body Task 26 moved rather than its absence.
/// Verified empirically, not assumed: `test_selectedTextRangeSetter_forwardsTheRangeObject` (spy) and
/// `test_selectedTextRangeSetter_runsTheWholeCanvasBodyThroughTheBackend` (real) are the same write
/// through the same router, and only the second one moves the snapshot.
///
/// Every test reads through a real `DocumentCanvasView` member, never `canvas.inputBackend.…` — the
/// vacuity trap R14 (`InputBackendSourceBoundaryTests`) mechanically forbids in this directory.
@MainActor
@available(iOS 16.0, *)
final class SelectionRouterTests: XCTestCase {

    // MARK: - Section 1: the spy backend — "one call, exact arguments, exact return, nothing else"

    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        spy.reset()
        return (v, spy)
    }

    func test_selectedTextRangeGetter_callsTheBackendOnceAndReturnsItsExactRange() {
        let (v, spy) = spyCanvas()
        let result = XCTAssertRoutesOnly(v, spy, member: "selectedTextRange.get", arguments: []) {
            v.selectedTextRange
        }
        XCTAssertTrue(result === spy.sentinelRange,
                      "the router must forward the object, not rebuild it from the sentinel's content")
    }

    func test_selectedTextRangeSetter_forwardsTheRangeObject() {
        let (v, spy) = spyCanvas()
        let range = DocumentTextRange(DocumentTextPosition(3), DocumentTextPosition(5))
        XCTAssertRoutesOnly(v, spy, member: "selectedTextRange.set",
                            arguments: [ObjectIdentifier(range).debugDescription]) {
            v.selectedTextRange = range
        }
    }

    /// A `nil` write is the shape UIKit uses to clear the selection, and it must reach the backend as
    /// `nil` rather than being swallowed or substituted at the router.
    func test_selectedTextRangeSetter_forwardsANilWriteUnchanged() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "selectedTextRange.set", arguments: ["nil"]) {
            v.selectedTextRange = nil
        }
    }

    func test_inputDelegateSetter_forwardsToTheBackend() {
        let (v, spy) = spyCanvas()
        let delegate = InputDelegateSpy()
        XCTAssertRoutesOnly(v, spy, member: "inputDelegate.set",
                            arguments: [ObjectIdentifier(delegate as AnyObject).debugDescription]) {
            v.inputDelegate = delegate
        }
    }

    func test_inputDelegateGetter_returnsTheBackendsDelegate() {
        let (v, spy) = spyCanvas()
        let delegate = InputDelegateSpy()
        v.inputDelegate = delegate          // seeded through the router itself; `XCTAssertRoutesOnly` resets the log
        let result = XCTAssertRoutesOnly(v, spy, member: "inputDelegate.get", arguments: []) {
            v.inputDelegate
        }
        XCTAssertTrue(result === delegate,
                      "the getter must return the very object the backend stored, not a copy or a " +
                      "canvas-side cache — the canvas has no delegate storage left at all")
    }

    /// The spy half of the floating-cursor invariant: UIKit's write still REACHES the backend exactly
    /// once. Suppression is the backend's decision (`LegacyRichTextInputBackend`'s
    /// `floatingCursorActive` guard), not something the canvas router may pre-empt — a router that
    /// re-added the old `if floatingCursorActive { return }` would record zero calls here.
    func test_selectedTextRangeSetter_stillReachesTheBackendWhileTheFloatingCursorIsActive() {
        let (v, spy) = spyCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)   // collapsed: begin's own collapse bracket is a no-op
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        let range = DocumentTextRange(DocumentTextPosition(2), DocumentTextPosition(4))
        XCTAssertRoutesOnly(v, spy, member: "selectedTextRange.set",
                            arguments: [ObjectIdentifier(range).debugDescription]) {
            v.selectedTextRange = range
        }
        v.endFloatingCursor()
    }

    // MARK: - Section 2: the real legacy backend — the canvas body the routing moved

    private func realCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Beta")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    /// The real-backend counterpart of the spy test above: with the floating cursor owning the caret,
    /// the write reaches the backend and the BACKEND drops it, so the selection does not move.
    ///
    /// This is the load-bearing half. The canvas keeps its own `floatingCursorActive` (the real
    /// hold-spacebar gesture's writer) until Task 33, while the backend has a separate flag of the same
    /// name, so a routed setter that consulted only the backend's flag would silently turn a cursor
    /// MOVE into a text SELECTION. Verified red against exactly that: with the setter's guard reading
    /// only `floatingCursorActive` (the backend's own), this test and
    /// `FloatingCursorTests.test_selectedTextRange_ignoredDuringFloatingCursor` both failed.
    func test_selectedTextRangeSetter_isIgnoredWhileFloatingCursorIsActive() {
        let v = realCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        let anchorBefore = v.anchor, headBefore = v.head
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))

        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart),
                                                DocumentTextPosition(v.boxes[0].textStart + 3))
        XCTAssertEqual(v.anchor, anchorBefore, "the gesture owns the caret; this write must be dropped")
        XCTAssertEqual(v.head, headBefore)

        v.endFloatingCursor()
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart),
                                                DocumentTextPosition(v.boxes[0].textStart + 3))
        XCTAssertEqual(v.anchor, v.boxes[0].textStart,
                       "the SAME write must be accepted once the gesture ends — the contrast that " +
                       "makes the dropped write above non-vacuous")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 3)
    }

    /// TASK 26 decision C2, pinned. The routed member has TWO destinations and BOTH must happen: the
    /// canvas body (which is the whole observable behavior of this witness in the app) and the
    /// backend's canonical store (which is what the contract suites read). A member that kept only the
    /// canonical write would leave the editor's selection frozen; one that kept only the canvas write
    /// would leave the backend's published state lying. Both are asserted here, from one write.
    ///
    /// The canvas half is checked through the four side effects that are observable without extra
    /// instrumentation: the clamped endpoints, the edit-menu dismissal counter, the cleared structural
    /// (image) selection with its `imageObjectDeletePending` stash, and the host selection report.
    ///
    /// RED IF: the setter dropped `legacyApplySelectedTextRange(_:)` (anchor/head/menu/image all stop
    /// moving), or dropped the `setSelection` call (`canonicalSelection` stops tracking), or stopped
    /// clamping (the out-of-range write below would land past `documentSizeValue`).
    func test_selectedTextRangeSetter_runsTheWholeCanvasBodyThroughTheBackend() {
        let v = realCanvas()
        var selectionReports = 0
        v.onSelectionChange = { selectionReports += 1 }
        let menuDismissalsBefore = v.dismissEditMenuCountForTesting

        let target = v.boxes[1].textStart
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(target),
                                                DocumentTextPosition(target))

        XCTAssertEqual(v.anchor, target, "the canvas half must still write the canvas's own selection")
        XCTAssertEqual(v.head, target)
        XCTAssertGreaterThan(v.dismissEditMenuCountForTesting, menuDismissalsBefore,
                             "dismissEditMenuForSelectionOrTextChange() is part of the moved body")
        XCTAssertEqual(selectionReports, 1,
                       "onSelectionChange fires exactly once — it now arrives through the backend's " +
                       "publication (lifecycle client), not from the canvas body directly, and " +
                       "must not be delivered twice. That single report is ALSO the canonical half's " +
                       "evidence here: the only route to onSelectionChange for a `.selection` reason " +
                       "is publishState, which setSelection reaches only after writing " +
                       "canonicalSelectionStorage. The recorded VALUE is pinned separately, backend-" +
                       "side, by BackendSelectionContractTests" +
                       ".test_selectedTextRangeGetter_handsUIKitAnUnorderedRange_forAReversedSelection " +
                       "(this directory may not read `.inputBackend.` — rule R14).")
    }

    /// The clamping half of the same body, separated so a failure names which half broke. The canvas —
    /// the only party that knows `documentSize` — clamps BOTH endpoints; the pre-seam backend member
    /// wrote them raw (its own doc comment said so), and Task 26 resolves that divergence in the
    /// canvas's favour.
    func test_selectedTextRangeSetter_clampsBothEndpointsLikeTheCanvasAlwaysDid() {
        let v = realCanvas()
        let past = v.documentSizeValue + 500
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(-42), DocumentTextPosition(past))
        XCTAssertEqual(v.anchor, 0)
        XCTAssertEqual(v.head, v.documentSizeValue)
    }

    /// The nil-collapse: the canvas has always mapped a `nil` (or non-`DocumentTextRange`) write to a
    /// caret at offset 0 via `r?.from.offset ?? 0`, while the pre-seam backend member DROPPED it. The
    /// routed member keeps the canvas's behavior.
    func test_selectedTextRangeSetter_collapsesANilWriteToOffsetZero() {
        let v = realCanvas()
        v.setCaret(global: v.boxes[1].textStart)
        XCTAssertGreaterThan(v.head, 0, "precondition: the caret is somewhere other than 0")
        v.selectedTextRange = nil
        XCTAssertEqual(v.anchor, 0)
        XCTAssertEqual(v.head, 0)
    }

    /// A canvas selection funnel that never calls `setSelection` is still visible through the getter.
    ///
    /// **TASK 35 INVERTED WHY, so the test is kept and the reasoning replaced.** It used to read: the
    /// getter reads the CANVAS's live selection, not the canonical store, "a deliberate, temporary
    /// asymmetry … until Task 35 unifies the two" — and its RED-IF said reading
    /// `canonicalSelectionStorage` would report `(0, 0)` because `setCaret` never touches it. Task 35
    /// unified them: `setCaret` writes `anchor`/`head`, those are now forwarders onto
    /// `canonicalSelectionStorage`, and the getter reads that store. Same observable result, opposite
    /// mechanism — which is precisely the property this test is worth keeping for. (It was renamed in
    /// the same commit: the old name asserted the write "never reaches the backend's canonical store",
    /// which is now false.)
    ///
    /// RED IF: the canvas forwarders stopped writing the backend store, or `setCaret` stopped writing
    /// them — the range below would report `(0, 0)` either way.
    func test_selectedTextRangeGetter_reportsASelectionSetByACanvasFunnelThatNeverCallsSetSelection() {
        let v = realCanvas()
        v.setCaret(global: v.boxes[1].textStart)
        guard let range = v.selectedTextRange as? DocumentTextRange else {
            XCTFail("expected a DocumentTextRange"); return
        }
        XCTAssertEqual(range.from.offset, v.boxes[1].textStart)
        XCTAssertEqual(range.to.offset, v.boxes[1].textStart)
    }
}
#endif

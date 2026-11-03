#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
@MainActor
final class BoundedSelectionGeometryTests: XCTestCase {
    private func makeLongDocument(_ count: Int = 500)
        -> (DocumentCanvasView, TelegramGeometryInputClient) {
        let v = DocumentCanvasView()
        v.setBlocks((0..<count).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"),
                                      runs: [TextRun(text: "Paragraph number \($0) with some text")]))
        }, width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 640); v.layoutIfNeeded()
        return (v, TelegramGeometryInputClient(canvas: v))
    }
    private func wholeDocumentRequest(_ v: DocumentCanvasView, visible: CGRect?)
        -> RichTextInputSelectionGeometryRequest {
        RichTextInputSelectionGeometryRequest(
            range: NSRange(location: 0, length: v.documentSizeValue),
            visibleRect: visible, includeStartEndpoint: true, includeEndEndpoint: true,
            purpose: .selectionPresentation)
    }

    /// TASK 25 FIX ROUND 1 (Major, reviewer) — the FROZEN pre-seam oracle for `containsStart`/
    /// `containsEnd`, inlining the pre-seam witness's own array-position rule
    /// (`rects.enumerated().map { index, frame in ... index == 0 ... index == rects.count - 1 }`,
    /// `DocumentCanvasView+UITextInput.swift`, before Task 25 routed it) over the UNTOUCHED
    /// `selectionRects(globalFrom:globalTo:)` helper — NEVER over `v.selectionRects(for:)`, which Task
    /// 25 routed through `LegacyRichTextInputBackend` and therefore through the SAME
    /// `legacySelectionSegments` `TelegramGeometryInputClient.selectionSegments(for:revision:)` calls.
    /// Comparing `viaClient` against `v.selectionRects(for:)` post-routing would be tautological (both
    /// sides run the same function) — this helper is what makes the two tests below genuine oracles
    /// again, not a convenience rename.
    private func preSeamWitnessRects(_ v: DocumentCanvasView, from: Int, to: Int)
        -> [(rect: CGRect, containsStart: Bool, containsEnd: Bool)] {
        let rects = v.selectionRects(globalFrom: min(from, to), globalTo: max(from, to))
        return rects.enumerated().map { index, frame in
            (rect: frame, containsStart: index == 0, containsEnd: index == rects.count - 1)
        }
    }

    func test_unboundedRequestCoversTheWholeDocument() {
        let (v, c) = makeLongDocument()
        let segments = c.selectionSegments(for: wholeDocumentRequest(v, visible: nil),
                                           revision: v.documentRevision)!
        XCTAssertGreaterThan(segments.count, 400)
    }

    /// The spec's large-Select-All requirement: a visible rectangle bounds the DRAWING geometry
    /// while the canonical selection stays complete.
    func test_boundedRequestReturnsViewportSizedGeometry() {
        let (v, c) = makeLongDocument()
        let viewport = CGRect(x: 0, y: 0, width: 320, height: 640)
        let segments = c.selectionSegments(for: wholeDocumentRequest(v, visible: viewport),
                                           revision: v.documentRevision)!
        XCTAssertLessThan(segments.count, 60, "bounded geometry must not be O(document)")
    }

    func test_boundedRequestStillIncludesBothEndpointSegments() {
        let (v, c) = makeLongDocument()
        let viewport = CGRect(x: 0, y: 2_000, width: 320, height: 640)   // mid-document viewport
        let segments = c.selectionSegments(for: wholeDocumentRequest(v, visible: viewport),
                                           revision: v.documentRevision)!
        XCTAssertTrue(segments.contains { $0.containsStart })
        XCTAssertTrue(segments.contains { $0.containsEnd })
    }

    func test_boundedRequestRealizesNoAdditionalBlockViews() {
        let (v, c) = makeLongDocument()
        let before = v.realizedBlockViewCountForTesting
        _ = c.selectionSegments(for: wholeDocumentRequest(v, visible: v.bounds),
                                revision: v.documentRevision)
        XCTAssertEqual(v.realizedBlockViewCountForTesting, before,
                       "a geometry query may not create persistent block views")
    }

    func test_segmentsAreInCanonicalDocumentOrder() {
        let (v, c) = makeLongDocument(40)
        let segments = c.selectionSegments(for: wholeDocumentRequest(v, visible: nil),
                                           revision: v.documentRevision)!
        XCTAssertEqual(segments.map(\.range.location), segments.map(\.range.location).sorted())
    }

    /// TASK 25 FIX ROUND 1 (Major, reviewer) — re-based onto `preSeamWitnessRects(_:from:to:)`
    /// instead of `v.selectionRects(for:)`: after Task 25 routed that witness, comparing it against
    /// `c.selectionSegments(for:revision:)` compared the code under test against itself (both call
    /// `legacySelectionSegments`), so this test could no longer fail no matter what the flags said.
    func test_segmentsMatchTheWitnessRectsForASmallSelection() {
        let (v, c) = makeLongDocument(3)
        let from = v.boxes[0].textStart, to = v.boxes[2].textStart + 5
        let request = RichTextInputSelectionGeometryRequest(
            range: NSRange(location: from, length: to - from), visibleRect: nil,
            includeStartEndpoint: true, includeEndEndpoint: true, purpose: .selectionPresentation)
        let viaClient = c.selectionSegments(for: request, revision: v.documentRevision)!
        let viaWitness = preSeamWitnessRects(v, from: from, to: to)
        XCTAssertEqual(viaClient.count, viaWitness.count)
        for (a, b) in zip(viaClient, viaWitness) {
            XCTAssertEqual(a.rect, b.rect)
            // Flags too, not just geometry — a fix-round addition. This 3-paragraph fixture has no
            // structural atom, so containment is unambiguous here; it would NOT have caught the
            // interior-gap defect below (that needs a genuine gap position — see
            // test_containsEndMatchesTheWitnessAtAnInteriorStructuralGap), and it never WRAPS either
            // (see test_wrappingRegion_flagsOnlyTheFirstAndLastRectNotEveryRectInTheRegion for that).
            XCTAssertEqual(a.containsStart, b.containsStart)
            XCTAssertEqual(a.containsEnd, b.containsEnd)
        }
    }

    /// A genuine INTERIOR structural gap (a captioned media atom's 2-position gap before its caption
    /// region — `MediaBlockBox.textStart == nodeStart + 2`), selected up to the gap with
    /// `includeEndEndpoint: true`. This is an entirely ordinary "select text up to just before this
    /// image" — not a document-boundary sentinel — so the endpoint-resolution fallback must prefer the
    /// PRECEDING region (the paragraph whose text is actually selected), not the following one (the
    /// image's caption, which is NOT selected and can never appear in the output since its clamped span
    /// is empty). Comparing against the frozen `preSeamWitnessRects` oracle rather than a hardcoded
    /// expectation is the point: it is the pinned oracle for `containsEnd`.
    ///
    /// TASK 25 FIX ROUND 1 (Major, reviewer) — re-based onto `preSeamWitnessRects(_:from:to:)`, same
    /// reason as `test_segmentsMatchTheWitnessRectsForASmallSelection` above: this test exists
    /// SPECIFICALLY because the endpoint-owner derivation had already been wrong once (the RED-before-
    /// the-fix note below), so leaning on the now-routed `v.selectionRects(for:)` as its oracle would
    /// have silently disarmed the one test written to catch a regression of exactly this shape.
    ///
    /// RED before the (original) fix: the old direction-agnostic fallback resolved the end endpoint to
    /// the FOLLOWING region (the caption), which never survives `legacySelectionSegments`'s `lo < hi`
    /// clamp for this range — so `containsEnd` was `false` on every returned segment, while the witness
    /// (which flags by array position over the full unbounded walk) correctly flags the paragraph's
    /// last rect.
    func test_containsEndMatchesTheWitnessAtAnInteriorStructuralGap() {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 80, height: 50)).image { c in
            UIColor.darkGray.setFill(); c.fill(CGRect(x: 0, y: 0, width: 80, height: 50)) } }
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Above")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                              caption: [TextRun(text: "Cap")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Below")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        let c = TelegramGeometryInputClient(canvas: v)

        let img = v.boxes[1] as! MediaBlockBox
        let from = v.boxes[0].textStart
        let to = img.nodeStart   // the gap immediately before the image — owned by NO leaf region
        XCTAssertNotEqual(to, img.textStart, "the probe needs a genuine gap, or this test is vacuous")

        let request = RichTextInputSelectionGeometryRequest(
            range: NSRange(location: from, length: to - from), visibleRect: nil,
            includeStartEndpoint: true, includeEndEndpoint: true, purpose: .selectionPresentation)
        let viaClient = c.selectionSegments(for: request, revision: v.documentRevision)!
        let viaWitness = preSeamWitnessRects(v, from: from, to: to)
        XCTAssertFalse(viaWitness.isEmpty, "the probe must actually produce witness geometry, or this test is vacuous")
        let witnessContainsEnd = viaWitness.contains { $0.containsEnd }
        let clientContainsEnd = viaClient.contains { $0.containsEnd }
        XCTAssertTrue(witnessContainsEnd, "sanity: the (untouched) witness must flag SOME rect as containing the end")
        XCTAssertEqual(clientContainsEnd, witnessContainsEnd,
                       "containsEnd must land on the region the witness flags — the last real content before the gap")
    }

    /// TASK 25 FIX ROUND 1 (Major, reviewer) — the WRAPPING fixture neither pre-existing test ever
    /// used ("Paragraph number N with some text" at width 320, and the 3-block fixture above, are both
    /// one line each), which is exactly why the Critical this test guards against passed review
    /// undetected: a region whose text wraps into MULTIPLE lines contributes MULTIPLE rects from
    /// `r.layout.selectionRects(start:end:)`, and `legacySelectionSegments` copies the SAME per-region
    /// `containsStart`/`containsEnd` flag onto every one of them — where the pre-seam witness (and the
    /// backend's fixed derivation) flags only the very first and very last rect in the WHOLE selection,
    /// by array position, regardless of how many regions or lines it spans.
    ///
    /// RED before the fix: every rect in this single-paragraph, multi-line selection came back
    /// `containsStart == containsEnd == true` (verified: reverted `+Geometry.swift`'s
    /// `selectionRects(for:)` to read `$0.containsStart`/`$0.containsEnd` off the segments directly and
    /// re-ran — see the fix-round report for the exact command/output).
    ///
    /// Compares the ROUTED, OS-facing witness (`v.selectionRects(for:)` — canvas → backend → geometry
    /// client, the exact seam the Critical was in) against the frozen oracle, NOT the client's raw
    /// `selectionSegments(for:revision:)` — those segments still carry `legacySelectionSegments`' own
    /// per-REGION `containsStart`/`containsEnd` (unchanged; that derivation is not wrong for what IT
    /// promises, only for what the pre-seam per-RECT witness promised), so comparing them here would
    /// compare two DIFFERENT rules against each other and fail for the wrong reason on every fixture,
    /// wrapping or not. The backend's fix — deriving flags by array position over `segments`, in
    /// `+Geometry.swift` — is what makes `v.selectionRects(for:)`'s flags independent of
    /// `legacySelectionSegments`' own, and therefore a genuine (non-tautological) match against a
    /// frozen oracle built by an entirely different function
    /// (`selectionRects(globalFrom:globalTo:)`, never `legacySelectionSegments`).
    func test_wrappingRegion_flagsOnlyTheFirstAndLastRectNotEveryRectInTheRegion() {
        let v = DocumentCanvasView()
        // Deliberately NOT asserting a specific rect count or checking a hardcoded "interior" index:
        // this fixture also runs under TK1 via `Scripts/matrix.sh` (`RTE_FORCE_TK1`), which
        // measures/wraps text differently from TK2 — found the hard way when an earlier version of
        // this test hardcoded `viaWitness[1]` as "the" interior rect and TK1 wrapped the same fixture
        // into only 2 lines, where index 1 legitimately IS the last rect.
        //
        // TASK 25 RE-REVIEW (Minor, reviewer) — ATTRIBUTION CORRECTED, and this comment is the template
        // later families copy, so read it carefully. The `filter(...).count == 1` checks on `viaWitness`
        // below CANNOT capture the Critical: `viaWitness` is the FROZEN ORACLE, built by
        // `selectionRects(globalFrom:globalTo:)`, which no `+Geometry.swift` mutation can change — so on
        // that side they are tautologies of `index == 0`/`count - 1` and serve only as self-consistency
        // checks on the oracle. What actually caught the per-region bug is the zip loop's per-rect
        // flag comparison (hence the reported `("true") is not equal to ("false")` output — an Int count
        // assertion cannot produce that). The same two filters are therefore ALSO applied to
        // `viaRoutedWitness` below, where they are genuinely discriminating.
        //
        // Engine-independence rule (the durable half): rect cardinality and ordering are ENGINE-CHOSEN
        // INPUTS, never test-owned expectations. A count or index may appear only when every side of the
        // comparison came from the same engine in the same run — `zip` element comparisons and
        // `XCTAssertEqual(a.count, b.count)` are fine; a `filter(...).count == 1` is fine when the `1` is
        // a property of the RULE under test; `count > 1` is fine as a loud non-vacuity precondition.
        // Forbidden: literal expected rect counts, an index standing in for a role ("the interior rect"),
        // literal rect coordinates, and inferring first/last from an assumed count.
        let longText = Array(repeating: "wide word", count: 30).joined(separator: " ")
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: longText)])], width: 120)
        v.frame = CGRect(x: 0, y: 0, width: 120, height: 600); v.layoutIfNeeded()

        let from = v.boxes[0].textStart
        let to = from + (longText as NSString).length

        // The frozen oracle, checked for self-consistency first: it must actually WRAP (more than one
        // rect) — otherwise this test is vacuous or is silently testing the single-line case the other
        // two tests already cover.
        let viaWitness = preSeamWitnessRects(v, from: from, to: to)
        XCTAssertGreaterThan(viaWitness.count, 1,
                             "the fixture must actually wrap into multiple rects, or this test cannot " +
                             "distinguish per-region flagging from per-rect flagging")
        XCTAssertEqual(viaWitness.filter(\.containsStart).count, 1,
                       "exactly one rect must be flagged as the start regardless of how many rects " +
                       "the wrapped selection spans — the per-region bug flags ALL of them")
        XCTAssertEqual(viaWitness.filter(\.containsEnd).count, 1,
                       "exactly one rect must be flagged as the end regardless of how many rects " +
                       "the wrapped selection spans — the per-region bug flags ALL of them")
        XCTAssertTrue(viaWitness.first!.containsStart)
        XCTAssertTrue(viaWitness.last!.containsEnd)

        // The actual regression pin: the ROUTED witness must match the frozen oracle rect-for-rect
        // AND flag-for-flag.
        let viaRoutedWitness = v.selectionRects(
            for: DocumentTextRange(DocumentTextPosition(from), DocumentTextPosition(to)))
        XCTAssertEqual(viaRoutedWitness.count, viaWitness.count)
        // The genuinely discriminating form of the two filters above: on the ROUTED side, the per-region
        // derivation flags EVERY rect, so these counts would equal `viaRoutedWitness.count` rather than 1.
        XCTAssertEqual(viaRoutedWitness.filter(\.containsStart).count, 1,
                       "exactly one ROUTED rect may be flagged as the start — the per-region bug flags all")
        XCTAssertEqual(viaRoutedWitness.filter(\.containsEnd).count, 1,
                       "exactly one ROUTED rect may be flagged as the end — the per-region bug flags all")
        for (a, b) in zip(viaRoutedWitness, viaWitness) {
            XCTAssertEqual(a.rect, b.rect)
            XCTAssertEqual(a.containsStart, b.containsStart)
            XCTAssertEqual(a.containsEnd, b.containsEnd)
        }
    }

    /// Closes the gating hole flagged across rounds 1 and 2 of review: every OTHER test in this file
    /// requests `includeStartEndpoint: true, includeEndEndpoint: true`, so nothing pins that
    /// `containsStart`/`containsEnd` are computed INDEPENDENTLY of those flags — the flags govern only
    /// forced MATERIALIZATION of an offscreen endpoint region (per the spec and the untouched UIKit
    /// witness, which computes both descriptive flags unconditionally too). A future change that
    /// mistakenly gated the flags on the include-flags would pass every other test in this file.
    ///
    /// The viewport (`y: 0..640`) is chosen to cover the WHOLE selected range on its own — `boxes[3]` is
    /// well inside it (the same viewport `test_boundedRequestReturnsViewportSizedGeometry` uses to fit
    /// dozens of paragraphs) — so both endpoint-owning regions are already in the ordinary windowed walk
    /// with `alwaysInclude` empty (both include-flags `false`). If they were only present BECAUSE of
    /// forcing, turning materialization off would legitimately make them absent and this test would be
    /// asserting the wrong thing; the leading `XCTAssertFalse(segments.isEmpty, ...)` guards exactly that.
    ///
    /// RED before the fix would look like: `containsStart`/`containsEnd` gated as
    /// `includeStart/EndEndpoint && r.globalStart == …OwnerGlobalStart` — see the round-2 report for the
    /// reproduction (gated locally, ran red, reverted, ran green).
    func test_containsFlags_areIndependentOfTheIncludeEndpointFlags() {
        let (v, c) = makeLongDocument()
        let viewport = CGRect(x: 0, y: 0, width: 320, height: 640)
        let from = v.boxes[0].textStart
        let to = v.boxes[3].textStart + 5
        let request = RichTextInputSelectionGeometryRequest(
            range: NSRange(location: from, length: to - from), visibleRect: viewport,
            includeStartEndpoint: false, includeEndEndpoint: false, purpose: .selectionPresentation)
        let segments = c.selectionSegments(for: request, revision: v.documentRevision)!
        XCTAssertFalse(segments.isEmpty,
                       "the endpoints' owning regions must already be in the ordinary windowed walk " +
                       "without forcing, or this test cannot distinguish the flag from materialization")
        XCTAssertTrue(segments.contains { $0.containsStart },
                     "containsStart must fire even with includeStartEndpoint: false — the flag governs " +
                     "forced materialization only, never the descriptive flag")
        XCTAssertTrue(segments.contains { $0.containsEnd },
                     "containsEnd must fire even with includeEndEndpoint: false — same reasoning")
    }

    func test_staleRevisionReturnsNil() {
        let (v, c) = makeLongDocument(3)
        XCTAssertNil(c.selectionSegments(for: wholeDocumentRequest(v, visible: nil),
                                         revision: v.documentRevision &- 1))
    }

    func test_segmentsCarryTheRevisionAndGeneration() {
        let (v, c) = makeLongDocument(3)
        let segments = c.selectionSegments(for: wholeDocumentRequest(v, visible: nil),
                                           revision: v.documentRevision)!
        for s in segments {
            XCTAssertEqual(s.documentRevision, v.documentRevision)
            XCTAssertEqual(s.layoutGeneration, v.layoutGeneration)
        }
    }
}
#endif

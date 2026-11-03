#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
@MainActor
final class TelegramDocumentInputClientReadTests: XCTestCase {
    private func makeClient(_ texts: [String] = ["Alpha", "Beta"])
        -> (DocumentCanvasView, TelegramDocumentInputClient) {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return (v, TelegramDocumentInputClient(canvas: v))
    }

    func test_revisionTracksTheCanvasCounter() {
        let (v, c) = makeClient()
        XCTAssertEqual(c.revision, v.documentRevision)
        v.editing { .unchanged }
        XCTAssertEqual(c.revision, v.documentRevision)
    }

    func test_utf16LengthIsTheStructuralDocumentSize() {
        let (v, c) = makeClient()
        XCTAssertEqual(c.utf16Length, v.documentSizeValue)
    }

    /// plainText must reproduce text(in:) EXACTLY — it is load-bearing for the Hangul/CJK IME.
    func test_plainTextMatchesTheUITextInputProjectionAcrossAParagraphBoundary() {
        let (v, c) = makeClient()
        let from = v.boxes[0].textStart, to = v.boxes[1].textStart + 4
        let viaWitness = v.text(in: DocumentTextRange(DocumentTextPosition(from), DocumentTextPosition(to)))
        XCTAssertEqual(c.plainText(in: NSRange(location: from, length: to - from)), viaWitness)
        XCTAssertEqual(viaWitness, "Alpha\nBeta")
    }

    func test_plainTextOfAnEmptyRangeIsEmpty() {
        let (v, c) = makeClient()
        XCTAssertEqual(c.plainText(in: NSRange(location: v.boxes[0].textStart, length: 0)), "")
    }

    func test_plainTextOutOfBoundsReturnsNil() {
        // NOTE: `c` holds the canvas `unowned` (by design — see the retain test below), so the canvas
        // must be bound to a name (`v`), not `_`. A discard pattern releases the tuple's other element
        // immediately (no name extends its lifetime), deallocating the canvas out from under `c` before
        // the assertion runs and trapping ("Attempted to read an unowned reference…") on the next access.
        let (v, c) = makeClient()
        withExtendedLifetime(v) {
            XCTAssertNil(c.plainText(in: NSRange(location: -1, length: 2)))
            XCTAssertNil(c.plainText(in: NSRange(location: 0, length: Int.max / 2)))
        }
    }

    /// Fix round 1 pin: `attributedText(in:)` and `plainText(in:)` MUST agree on where separators go.
    /// The original `legacyAttributedText` inserted "\n" between every pair of appended leaf regions
    /// with no top-level/table distinction, so a cross-cell range came out "Alpha\nBeta" as attributed
    /// text while `plainText(in:)`/`text(in:)` correctly glue table cells to "AlphaBeta" (the documented
    /// invariant — a table is one editing surface). Red if the two ever diverge again, e.g. if
    /// `legacyAttributedText` stops routing through the shared `forEachLeafRegionInRange` separator rule.
    func test_attributedTextAgreesWithPlainTextAcrossATableCellBoundary() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(
            id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [
                Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "Alpha")]))]),
                Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "Beta")]))]),
            ])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let c = TelegramDocumentInputClient(canvas: v)
        let regions = v.allLeafRegions()
        let cellA = regions[0], cellB = regions[1]
        let range = NSRange(location: cellA.globalStart,
                             length: (cellB.globalStart + cellB.length) - cellA.globalStart)
        XCTAssertEqual(c.plainText(in: range), "AlphaBeta", "cross-cell text must glue with no separator")
        XCTAssertEqual(c.attributedText(in: range)?.string, c.plainText(in: range),
                       "attributedText must agree with plainText on separator placement")
    }

    func test_attributedTextReturnsASnapshotNotLiveStorage() {
        let (v, c) = makeClient()
        let range = NSRange(location: v.boxes[0].textStart, length: 3)
        let snapshot = c.attributedText(in: range)
        XCTAssertEqual(snapshot?.string, "Alp")
        v.setCaret(global: v.boxes[0].textStart); v.insertText("Z")
        XCTAssertEqual(snapshot?.string, "Alp", "the snapshot must not track later mutations")
    }

    func test_typingAttributesMatchTheCanvasResolver() {
        let (v, c) = makeClient()
        let offset = v.boxes[0].textStart + 2
        let viaClient = c.typingAttributes(at: .downstream(offset))
        let viaCanvas = v.typingAttributesAtGlobal(offset)
        XCTAssertEqual(viaClient[.font] as? UIFont, viaCanvas[.font] as? UIFont)
    }

    /// DEVIATION D25. The spec's authority table gives the backend a "transient typing-attribute
    /// cache … refreshed after a formatting external change". The legacy path has NO cache:
    /// typingAttributesAtGlobal (+UITextInput.swift:135) re-resolves from the owning leaf region on
    /// every call, so a formatting change is visible to the very next read with no invalidation
    /// step. This test pins the absence, so a later reader cannot mistake the missing cache for an
    /// oversight; the matching backend-side assertion is
    /// BackendMutationContractTests.test_typingAttributesAreResolvedPerCall_theLegacyBackendCachesNothing.
    func test_typingAttributesReflectAFormattingChangeImmediately_thereIsNoCache() {
        let (v, c) = makeClient()
        let offset = v.boxes[0].textStart + 2
        let before = c.typingAttributes(at: .downstream(offset))[.font] as? UIFont
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 4)
        v.toggleBold()
        let after = c.typingAttributes(at: .downstream(offset))[.font] as? UIFont
        XCTAssertNotEqual(before, after,
                          "a cache would have to be invalidated here; the legacy resolver has none")
    }

    func test_clampPinsToTheDocumentBounds() {
        let (v, c) = makeClient()
        XCTAssertEqual(c.clamp(.downstream(-5)).utf16Offset, 0)
        XCTAssertEqual(c.clamp(.downstream(v.documentSizeValue + 99)).utf16Offset, v.documentSizeValue)
    }

    func test_clampPreservesAffinity() {
        // NOTE: `c` holds the canvas `unowned` (by design — see the retain test below), so the canvas
        // must be bound to a name (`v`), not `_`. A discard pattern releases the tuple's other element
        // immediately (no name extends its lifetime), deallocating the canvas out from under `c` before
        // the assertion runs and trapping ("Attempted to read an unowned reference…") on the next access.
        let (v, c) = makeClient()
        withExtendedLifetime(v) {
            XCTAssertEqual(c.clamp(RichTextInputPosition(utf16Offset: -1, affinity: .upstream)).affinity, .upstream)
        }
    }

    func test_isValidInsertionPositionMatchesIsRenderablePosition() {
        let (v, c) = makeClient()
        for offset in 0...v.documentSizeValue {
            XCTAssertEqual(c.isValidInsertionPosition(.downstream(offset)),
                           v.isRenderablePosition(offset), "offset \(offset)")
        }
    }

    /// The legacy rebase is identity-or-nil. Anything richer would be new behavior.
    func test_rebaseReturnsThePositionAtTheCurrentRevision() {
        // NOTE: `c` holds the canvas `unowned` (by design — see the retain test below), so the canvas
        // must be bound to a name (`v`), not `_`. A discard pattern releases the tuple's other element
        // immediately (no name extends its lifetime), deallocating the canvas out from under `c` before
        // the assertion runs and trapping ("Attempted to read an unowned reference…") on the next access.
        let (v, c) = makeClient()
        withExtendedLifetime(v) {
            let p = RichTextInputPosition.downstream(3)
            XCTAssertEqual(c.rebase(p, fromRevision: c.revision), p)
        }
    }

    func test_rebaseReturnsNilForAStaleRevision() {
        let (v, c) = makeClient()
        let stale = c.revision
        v.editing { .unchanged }
        XCTAssertNil(c.rebase(.downstream(3), fromRevision: stale))
    }

    func test_clientHoldsTheCanvasWithoutRetainingIt() {
        weak var probe: DocumentCanvasView?
        autoreleasepool {
            let (v, c) = makeClient()
            probe = v
            _ = c.revision
        }
        XCTAssertNil(probe, "the client must hold the canvas unowned")
    }
}
#endif

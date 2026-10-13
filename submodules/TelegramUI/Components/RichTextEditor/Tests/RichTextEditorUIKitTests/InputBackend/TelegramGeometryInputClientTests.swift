#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
@MainActor
final class TelegramGeometryInputClientTests: XCTestCase {
    private func makeClient(_ texts: [String] = ["Alpha", "Beta"], width: CGFloat = 300)
        -> (DocumentCanvasView, TelegramGeometryInputClient) {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 400); v.layoutIfNeeded()
        return (v, TelegramGeometryInputClient(canvas: v))
    }

    /// The client must READ `canvas.layoutGeneration` through, never cache it at init — else a
    /// post-init bump (a scroll, a viewport change) would go unseen.
    func test_layoutGenerationTracksTheCanvasCounter() {
        let (v, c) = makeClient()
        XCTAssertEqual(c.layoutGeneration, v.layoutGeneration)
        let before = c.layoutGeneration
        v.viewportDidChange()
        XCTAssertGreaterThan(v.layoutGeneration, before, "the probe must actually bump the counter, or the read-through assertion below is vacuous")
        XCTAssertEqual(c.layoutGeneration, v.layoutGeneration)
    }

    // MARK: caretGeometry

    func test_caretGeometryMatchesTheWitnessRect() {
        let (v, c) = makeClient()
        let offset = v.boxes[0].textStart + 2
        let geom = c.caretGeometry(at: .downstream(offset), revision: v.documentRevision, purpose: .caret)
        XCTAssertEqual(geom?.rect, v.caretRect(for: DocumentTextPosition(offset)))
    }

    /// Deviation D9, asserted in both directions: nil exactly where the UIKit witness (`caretRect(for:)`)
    /// returns `.zero`, and non-nil exactly where it returns a real rect. Red if either the client starts
    /// fabricating a rect at a non-renderable position, or starts returning nil at a genuinely renderable one.
    func test_caretGeometryIsNilWhereTheWitnessReturnsZero() {
        let (v, c) = makeClient()
        // A structural token slot just past a paragraph's end — the D9 baseline probe
        // (GeometryWitnessMatrixTests.test_caretRect_forANonRenderablePosition_isZero uses the same shape).
        let structural = v.boxes[0].textStart + v.boxes[0].textLength + 1
        XCTAssertFalse(v.isRenderablePosition(structural), "the probe must actually be non-renderable, or this test is vacuous")
        XCTAssertEqual(v.caretRect(for: DocumentTextPosition(structural)), .zero)
        XCTAssertNil(c.caretGeometry(at: .downstream(structural), revision: v.documentRevision, purpose: .caret),
                     "nil where the witness returns .zero")

        let renderable = v.boxes[0].textStart
        XCTAssertNotEqual(v.caretRect(for: DocumentTextPosition(renderable)), .zero)
        XCTAssertNotNil(c.caretGeometry(at: .downstream(renderable), revision: v.documentRevision, purpose: .caret),
                        "non-nil where the witness returns a real rect")
    }

    /// D9's OTHER zero-path — `tableSelection != nil` — which this task's extraction RESTRUCTURED from a
    /// single `return .zero` into a two-halved composition: `legacyCaretRect` returns nil at
    /// `+UITextInput.swift:293`, the witness re-wraps it `?? .zero` at `:282`. Unpinned since Task 5;
    /// closed here because either half is now independently droppable (removing the helper's early nil,
    /// or dropping the witness's `?? .zero`) with nothing else going red. Establishes a REAL table
    /// selection (not merely a probe position that happens to be non-renderable) and asserts both halves:
    /// the witness `.zero` and the client `nil`, at a position that would otherwise be perfectly
    /// renderable (an in-cell text start — the GeometryWitnessMatrixTests table-cell rows prove such a
    /// position normally yields a real rect).
    func test_caretGeometryIsNilWhenATableSelectionIsActive() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [
                Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "Alpha")]))]),
                Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "Beta")]))]),
            ])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 300); v.layoutIfNeeded()
        let c = TelegramGeometryInputClient(canvas: v)

        let table = v.boxes[0] as! TableBlockBox
        let cellPos = table.cellTextStart(row: 0, column: 0)!
        v.setSelectionForTesting(anchor: cellPos, head: cellPos)
        v.selectTableRows(0...0)
        XCTAssertNotNil(v.tableSelection, "the probe must actually establish a table selection, or this test is vacuous")

        XCTAssertEqual(v.caretRect(for: DocumentTextPosition(cellPos)), .zero,
                       "witness half of D9's table-selection zero-path")
        XCTAssertNil(c.caretGeometry(at: .downstream(cellPos), revision: v.documentRevision, purpose: .caret),
                     "client half of D9's table-selection zero-path")
    }

    func test_caretGeometryCarriesTheCurrentRevisionAndGeneration() {
        let (v, c) = makeClient()
        let geom = c.caretGeometry(at: .downstream(v.boxes[0].textStart), revision: v.documentRevision, purpose: .caret)
        XCTAssertEqual(geom?.documentRevision, v.documentRevision)
        XCTAssertEqual(geom?.layoutGeneration, v.layoutGeneration)
    }

    /// D32: every geometry member checks the revision and refuses a stale one outright — no rebase
    /// attempt (unlike `TelegramDocumentInputClient.rebase`, which this client has no equivalent of).
    func test_caretGeometryIsNilForAStaleRevision() {
        let (v, c) = makeClient()
        let p = RichTextInputPosition.downstream(v.boxes[0].textStart)
        // `&-` (not `-`): a fresh canvas's very first revision could be 0, and a real `-1` would trap on
        // an unsigned underflow. Any mismatch proves the point; the wrapped value is still a mismatch.
        XCTAssertNil(c.caretGeometry(at: p, revision: v.documentRevision &- 1, purpose: .caret))
    }

    /// Red if the client hardcodes `.leftToRight` instead of consulting `resolvedDirection(forGlobal:)` —
    /// which a Latin-only fixture couldn't catch (both would coincidentally agree), so this seeds Arabic.
    func test_caretGeometryCarriesTheResolvedWritingDirection() {
        let (v, c) = makeClient(["مرحبا"])
        let offset = v.boxes[0].textStart
        XCTAssertEqual(v.resolvedDirection(forGlobal: offset), .rightToLeft,
                       "the probe text must actually auto-detect RTL, or this test is vacuous")
        let geom = c.caretGeometry(at: .downstream(offset), revision: v.documentRevision, purpose: .caret)
        XCTAssertEqual(geom?.writingDirection, .rightToLeft)
    }

    // MARK: closestPosition

    func test_closestPositionMatchesTheWitness() {
        let (v, c) = makeClient(["Alpha Beta"])
        let caret = v.caretRect(for: DocumentTextPosition(v.boxes[0].textStart + 3))
        let point = CGPoint(x: caret.midX, y: caret.midY)
        let viaWitness = (v.closestPosition(to: point) as! DocumentTextPosition).offset
        let viaClient = c.closestPosition(to: point, within: nil, revision: v.documentRevision, purpose: .caret)
        XCTAssertEqual(viaClient?.utf16Offset, viaWitness)
    }

    func test_closestPositionWithinRangeClampsToTheRange() {
        let (v, c) = makeClient(["Alpha", "Beta"])
        let s = v.boxes[0].textStart
        let range = NSRange(location: s, length: 2)
        let deepBelow = CGPoint(x: 10, y: v.bounds.height - 1)
        let unbounded = c.closestPosition(to: deepBelow, within: nil, revision: v.documentRevision, purpose: .caret)
        XCTAssertGreaterThan(unbounded!.utf16Offset, s + 2,
                             "the probe must resolve outside [s, s+2] unclamped, or the clamp check below is vacuous")
        let clamped = c.closestPosition(to: deepBelow, within: range, revision: v.documentRevision, purpose: .caret)
        XCTAssertGreaterThanOrEqual(clamped!.utf16Offset, s)
        XCTAssertLessThanOrEqual(clamped!.utf16Offset, s + 2)
    }

    // MARK: characterRange(at:)

    func test_characterRangeAtPointMatchesTheWitness() {
        let (v, c) = makeClient(["Alpha"])
        let caret = v.caretRect(for: DocumentTextPosition(v.boxes[0].textStart + 1))
        let point = CGPoint(x: caret.midX, y: caret.midY)
        let witness = v.characterRange(at: point) as! DocumentTextRange
        let viaClient = c.characterRange(at: point, revision: v.documentRevision)
        XCTAssertEqual(viaClient, NSRange(location: witness.from.offset, length: witness.to.offset - witness.from.offset))
    }

    // MARK: lineRange — D7 (whole leaf region) and D6 (always .downstream)

    /// D7: a paragraph wrapped onto SEVERAL visual lines still reports one `lineRange` spanning the
    /// WHOLE leaf region, not the visual line the probe sits on — this editor has no visual-line API.
    func test_lineRangeReturnsTheWholeEnclosingLeafRegion() {
        let longText = Array(repeating: "word", count: 40).joined(separator: " ")
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: longText)])], width: 120)
        v.frame = CGRect(x: 0, y: 0, width: 120, height: 2000); v.layoutIfNeeded()
        let c = TelegramGeometryInputClient(canvas: v)

        // Prove the paragraph actually wraps onto multiple lines (derived from this canvas's own single-
        // line reference height, not a hardcoded constant), or the "whole region, not one visual line"
        // claim below is untested.
        let single = DocumentCanvasView()
        single.setParagraphs([ParagraphBlock(id: BlockID("s"), runs: [TextRun(text: "x")])], width: 120)
        single.frame = CGRect(x: 0, y: 0, width: 120, height: 200); single.layoutIfNeeded()
        XCTAssertGreaterThan(v.boxes[0].frame.height, single.boxes[0].frame.height * 2,
                             "the paragraph must wrap onto multiple lines, or this test is vacuous")

        let region = v.allLeafRegions()[0]
        let mid = region.globalStart + region.length / 2
        let result = c.lineRange(enclosing: .downstream(mid), revision: v.documentRevision)
        XCTAssertEqual(result?.range, NSRange(location: region.globalStart, length: region.length))
    }

    /// D6: the legacy backend has no affinity model at all — every resolved position reports
    /// `.downstream`, at a line's start, middle, and end alike.
    func test_lineRangeResolvedAffinityIsAlwaysDownstream() {
        let (v, c) = makeClient(["Alpha Beta Gamma"])
        let region = v.allLeafRegions()[0]
        let positions = [region.globalStart, region.globalStart + region.length / 2, region.globalStart + region.length]
        for offset in positions {
            let result = c.lineRange(enclosing: .downstream(offset), revision: v.documentRevision)
            XCTAssertEqual(result?.resolvedAffinity, .downstream, "offset \(offset) must resolve .downstream")
        }
    }

    // MARK: caretGeometry.lineID

    func test_caretGeometryLineIDIsStableWithinOneLayoutGeneration() {
        let (v, c) = makeClient(["Alpha Beta Gamma"])
        let region = v.allLeafRegions()[0]
        let a = c.caretGeometry(at: .downstream(region.globalStart), revision: v.documentRevision, purpose: .caret)!.lineID
        let b = c.caretGeometry(at: .downstream(region.globalStart + region.length), revision: v.documentRevision, purpose: .caret)!.lineID
        XCTAssertEqual(a, b, "two positions inside the same paragraph must share one lineID")
    }

    func test_caretGeometryLineIDDiffersBetweenRegions() {
        let (v, c) = makeClient(["Alpha", "Beta"])
        let r0 = v.allLeafRegions()[0], r1 = v.allLeafRegions()[1]
        let a = c.caretGeometry(at: .downstream(r0.globalStart), revision: v.documentRevision, purpose: .caret)!.lineID
        let b = c.caretGeometry(at: .downstream(r1.globalStart), revision: v.documentRevision, purpose: .caret)!.lineID
        XCTAssertNotEqual(a, b, "two positions in different paragraphs must get different lineIDs")
    }

    // MARK: navigate

    /// Seeds a composed grapheme cluster (e + combining acute = "é") so one .right move must step over
    /// BOTH UTF-16 units, mirroring ArrowNavGraphemeTests' surrogate-pair proof for the witness path.
    func test_navigateRightMovesOneGraphemeCluster() {
        let (v, c) = makeClient(["e\u{0301}x"])
        let base = v.boxes[0].textStart
        let result = c.navigate(from: .downstream(base), direction: .right, offset: 1,
                                anchorPositionOffset: nil, revision: v.documentRevision)
        XCTAssertEqual(result?.position.utf16Offset, base + 2, "one right-step must cross the whole composed cluster")
    }

    func test_navigateDownMatchesVerticalPosition() {
        let (v, c) = makeClient(["Alpha", "Beta"])
        let start = v.boxes[0].textStart + 1
        let expected = v.verticalPosition(from: start, down: true)
        let result = c.navigate(from: .downstream(start), direction: .down, offset: 1,
                                anchorPositionOffset: nil, revision: v.documentRevision)
        XCTAssertEqual(result?.position.utf16Offset, expected)
    }

    /// D8: sticky-x is not preserved today — `navigate` always reports nil regardless of input.
    func test_navigateReturnsNilAnchorPositionOffset() {
        let (v, c) = makeClient()
        let result = c.navigate(from: .downstream(v.boxes[0].textStart), direction: .right, offset: 1,
                                anchorPositionOffset: nil, revision: v.documentRevision)
        XCTAssertNil(result?.anchorPositionOffset)
    }

    func test_navigateIgnoresAProvidedAnchorPositionOffset() {
        let (v, c) = makeClient(["Alpha", "Beta"])
        let start = v.boxes[0].textStart
        let withNil = c.navigate(from: .downstream(start), direction: .down, offset: 1,
                                 anchorPositionOffset: nil, revision: v.documentRevision)
        let with120 = c.navigate(from: .downstream(start), direction: .down, offset: 1,
                                 anchorPositionOffset: 120, revision: v.documentRevision)
        XCTAssertEqual(withNil?.position, with120?.position)
        XCTAssertNil(with120?.anchorPositionOffset)
    }

    // MARK: firstRect

    func test_firstRectMatchesTheWitness() {
        let (v, c) = makeClient(["Alpha Beta"])
        let s = v.boxes[0].textStart
        let range = DocumentTextRange(DocumentTextPosition(s), DocumentTextPosition(s + 9))
        let witness = v.firstRect(for: range)
        let viaClient = c.firstRect(for: NSRange(location: s, length: 9), revision: v.documentRevision, purpose: .caret)
        XCTAssertEqual(viaClient, witness)
    }

    func test_firstRectIsNilForAnEmptyRange() {
        let (v, c) = makeClient(["Alpha"])
        let s = v.boxes[0].textStart
        XCTAssertEqual(v.firstRect(for: DocumentTextRange(DocumentTextPosition(s), DocumentTextPosition(s))), .zero)
        XCTAssertNil(c.firstRect(for: NSRange(location: s, length: 0), revision: v.documentRevision, purpose: .caret))
    }

    // MARK: baseWritingDirection

    func test_baseWritingDirectionMatchesTheWitness() {
        let (v, c) = makeClient(["مرحبا"])
        let offset = v.boxes[0].textStart
        let witness = v.baseWritingDirection(for: DocumentTextPosition(offset), in: .forward)
        let viaClient = c.baseWritingDirection(at: .downstream(offset), revision: v.documentRevision)
        let expected: RichTextInputWritingDirection = witness == .rightToLeft ? .rightToLeft : .leftToRight
        XCTAssertEqual(viaClient, expected)
    }

    // MARK: no query mutates the canvas

    func test_everyQueryIsSideEffectFree() {
        let (v, c) = makeClient(["Alpha", "Beta"])
        let offset = v.boxes[0].textStart + 1
        func snapshot() -> (UInt64, UInt64, Int, Int, Int) {
            (v.documentRevision, v.layoutGeneration, v.anchor, v.head, v.realizedBlockViewCountForTesting)
        }
        let before = snapshot()
        _ = c.caretGeometry(at: .downstream(offset), revision: v.documentRevision, purpose: .caret)
        _ = c.closestPosition(to: CGPoint(x: 5, y: 5), within: nil, revision: v.documentRevision, purpose: .caret)
        _ = c.characterRange(at: CGPoint(x: 5, y: 5), revision: v.documentRevision)
        _ = c.lineRange(enclosing: .downstream(offset), revision: v.documentRevision)
        _ = c.navigate(from: .downstream(offset), direction: .right, offset: 1,
                       anchorPositionOffset: nil, revision: v.documentRevision)
        _ = c.firstRect(for: NSRange(location: offset, length: 1), revision: v.documentRevision, purpose: .caret)
        _ = c.selectionSegments(for: RichTextInputSelectionGeometryRequest(
            range: NSRange(location: offset, length: 1), visibleRect: nil,
            includeStartEndpoint: true, includeEndEndpoint: true, purpose: .caret), revision: v.documentRevision)
        _ = c.baseWritingDirection(at: .downstream(offset), revision: v.documentRevision)
        XCTAssertEqual(before.0, snapshot().0)
        XCTAssertEqual(before.1, snapshot().1)
        XCTAssertEqual(before.2, snapshot().2)
        XCTAssertEqual(before.3, snapshot().3)
        XCTAssertEqual(before.4, snapshot().4)
    }
}
#endif

#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Pins the geometry witnesses (`caretRect`/`selectionRects`/`firstRect`/`closestPosition`/
/// `characterRange(at:)`) across the block-kind matrix, exactly like `TextInputWitnessMatrixTests` does
/// for the text/range primitives. This is also where deviation D9 (the `.zero`-for-missing-geometry
/// baseline) and D8 (vertical nav loses the sticky-x column) are pinned.
@available(iOS 16.0, *)
final class GeometryWitnessMatrixTests: XCTestCase {
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }
    private func pos(_ o: Int) -> DocumentTextPosition { DocumentTextPosition(o) }

    func test_caretRect_isNonDegenerateForARenderablePosition() {
        let v = canvas([para("p0", "Alpha")])
        let r = v.caretRect(for: pos(v.boxes[0].textStart + 2))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertFalse(r.isNull)
    }

    /// D9 baseline: a NON-renderable position yields CGRect.zero, and callers branch on it.
    /// Phase 2 makes the CLIENT return nil while the witness keeps returning .zero.
    func test_caretRect_forANonRenderablePosition_isZero() {
        let v = canvas([para("p0", "Alpha"), para("p1", "Beta")])
        let structural = v.boxes[0].textStart + v.boxes[0].textLength + 1
        if !v.isRenderablePosition(structural) {
            XCTAssertEqual(v.caretRect(for: pos(structural)), .zero)
        }
    }

    func test_caretRect_advancesAcrossBlocks() {
        let v = canvas([para("p0", "Alpha"), para("p1", "Beta")])
        let first = v.caretRect(for: pos(v.boxes[0].textStart))
        let second = v.caretRect(for: pos(v.boxes[1].textStart))
        XCTAssertGreaterThan(second.minY, first.minY)
    }

    func test_firstRect_equalsTheFirstSelectionRect() {
        let v = canvas([para("p0", "Alpha Beta")])
        let s = v.boxes[0].textStart
        let range = DocumentTextRange(pos(s), pos(s + 9))
        let rects = v.selectionRects(for: range)
        XCTAssertFalse(rects.isEmpty)
        XCTAssertEqual(v.firstRect(for: range), rects[0].rect)
    }

    func test_firstRect_forAnEmptyRange_isZero() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        XCTAssertEqual(v.firstRect(for: DocumentTextRange(pos(s), pos(s))), .zero)
    }

    func test_selectionRects_carryContainsStartAndContainsEndOnTheCorrectElements() {
        let v = canvas([para("p0", "Alpha"), para("p1", "Beta")])
        let range = DocumentTextRange(pos(v.boxes[0].textStart), pos(v.boxes[1].textStart + 4))
        let rects = v.selectionRects(for: range)
        XCTAssertTrue(rects.first!.containsStart)
        XCTAssertTrue(rects.last!.containsEnd)
        XCTAssertFalse(rects.first!.containsEnd || rects.count == 1)
    }

    /// DocumentSelectionRect hardcodes both of these (S/Input/DocumentTextPosition.swift:30,33).
    func test_selectionRects_hardcodeLeftToRightAndNonVertical() {
        let v = canvas([para("p0", "Alpha Beta")])
        let s = v.boxes[0].textStart
        for r in v.selectionRects(for: DocumentTextRange(pos(s), pos(s + 9))) {
            XCTAssertEqual(r.writingDirection, .leftToRight)
            XCTAssertFalse(r.isVertical)
        }
    }

    func test_selectionRects_areInCanonicalDocumentOrder() {
        let v = canvas([para("p0", "Alpha"), para("p1", "Beta"), para("p2", "Gamma")])
        let range = DocumentTextRange(pos(v.boxes[0].textStart), pos(v.boxes[2].textStart + 5))
        let ys = v.selectionRects(for: range).map { $0.rect.minY }
        XCTAssertEqual(ys, ys.sorted())
    }

    func test_closestPosition_toAPointInsideTheFirstLine() {
        let v = canvas([para("p0", "Alpha Beta")])
        let caret = v.caretRect(for: pos(v.boxes[0].textStart + 3))
        let p = v.closestPosition(to: CGPoint(x: caret.midX, y: caret.midY)) as! DocumentTextPosition
        XCTAssertEqual(p.offset, v.boxes[0].textStart + 3, accuracy: 1)
    }

    /// The `within:` variant clamps the unbounded answer to the range (+UITextInput.swift:286-289).
    func test_closestPositionWithinRange_clampsToTheRange() {
        let v = canvas([para("p0", "Alpha"), para("p1", "Beta")])
        let s = v.boxes[0].textStart
        let range = DocumentTextRange(pos(s), pos(s + 2))
        let deepBelow = CGPoint(x: 10, y: v.bounds.height - 1)
        let p = v.closestPosition(to: deepBelow, within: range) as! DocumentTextPosition
        XCTAssertGreaterThanOrEqual(p.offset, s)
        XCTAssertLessThanOrEqual(p.offset, s + 2)
    }

    /// The naive [p, p+1] answer is deliberate — it is NOT grapheme-aware (+UITextInput.swift:291-294).
    func test_characterRangeAtPoint_isTheNaiveOneCharacterRange() {
        let v = canvas([para("p0", "Alpha")])
        let caret = v.caretRect(for: pos(v.boxes[0].textStart + 1))
        let r = v.characterRange(at: CGPoint(x: caret.midX, y: caret.midY)) as! DocumentTextRange
        XCTAssertEqual(r.to.offset - r.from.offset, 1)
    }

    func test_baseWritingDirection_isLeftToRightForLatinContent() {
        let v = canvas([para("p0", "Alpha")])
        XCTAssertEqual(v.baseWritingDirection(for: pos(v.boxes[0].textStart), in: .forward), .leftToRight)
    }

    /// D8 baseline: vertical navigation does NOT preserve a sticky x column across a short line.
    func test_verticalNavigation_losesTheColumnAcrossAShortLine() {
        let v = canvas([para("p0", "Alpha Beta Gamma"), para("p1", "Hi"), para("p2", "Alpha Beta Gamma")])
        let start = v.boxes[0].textStart + 14
        let mid = v.verticalPosition(from: start, down: true)
        let end = v.verticalPosition(from: mid, down: true)
        let column = end - v.boxes[2].textStart
        XCTAssertLessThan(column, 14, "sticky-x is not preserved today; deviation D8 records this")
    }

    // MARK: block-kind matrix (lifted verbatim from TextInputWitnessMatrixTests Step 2a per the brief)

    enum BlockKind: String, CaseIterable {
        case heading, listItem, codeBlock, blockQuote, pullQuote, detailsBody
        case tableCellInCell, tableCellCrossCell, mediaCaption, imageGap
        case formulaAtom, customEmojiAtom, buttonRow
    }

    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id),
             blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }

    /// One seeded, laid-out canvas per block kind. `probe` is a global offset INSIDE that kind's
    /// editable text — every row's three tests start from it, so no test re-derives geometry.
    private func seed(_ kind: BlockKind) -> (canvas: DocumentCanvasView, probe: Int, text: String) {
        let v: DocumentCanvasView
        switch kind {
        case .heading:
            v = canvas([.paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1,
                                                  runs: [TextRun(text: "Alpha")]))])
        case .listItem:
            v = canvas([.paragraph(ParagraphBlock(id: BlockID("li"),
                                                  list: ListMembership(marker: .bullet),
                                                  runs: [TextRun(text: "Alpha")]))])
        case .codeBlock:
            v = canvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "Alpha")]))])
        case .blockQuote:
            v = canvas([.blockQuote(BlockQuote(
                id: BlockID("q"),
                children: [.paragraph(ParagraphBlock(id: BlockID("qp"), runs: [TextRun(text: "Alpha")]))],
                collapsed: false))])
        case .pullQuote:
            v = canvas([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Alpha")]))])
        case .detailsBody:
            v = canvas([.details(DetailsBlock(
                id: BlockID("d"), title: [TextRun(text: "T")],
                children: [.paragraph(ParagraphBlock(id: BlockID("db"), runs: [TextRun(text: "Alpha")]))],
                expanded: true))])
        case .tableCellInCell, .tableCellCrossCell:
            v = canvas([.table(TableBlock(
                id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])]))])
        case .mediaCaption, .imageGap:
            v = canvas([.media(MediaBlock(id: BlockID("m"), mediaID: "k",
                                          naturalSize: Size2D(width: 100, height: 100),
                                          caption: [TextRun(text: "Alpha")]))])
        case .formulaAtom:
            // Without a `formulaRenderer` a formula run falls back to raw LaTeX TEXT ("x^2", 3 chars,
            // no `.attachment` at all — `AttributedStringMapper.attributedFormulaString`), NOT a single
            // U+FFFC atom. The single-atom `att.latex` path only exists when a host supplies a renderer
            // (both real hosts do), so wire one here — same pattern as `TextInputWitnessMatrixTests`.
            let fv = DocumentCanvasView()
            fv.mapper.formulaRenderer = { context in
                let size = CGSize(width: max(12.0, CGFloat((context.latex as NSString).length) * 4.0), height: 14.0)
                let image = UIGraphicsImageRenderer(size: size).image { _ in }
                return RichTextFormulaRenderResult(image: image, size: size, ascent: 10.0, descent: 4.0)
            }
            fv.setBlocks([.paragraph(ParagraphBlock(id: BlockID("f"), runs: [
                TextRun(text: "\u{FFFC}", attributes: {
                    var a = CharacterAttributes.plain; a.formula = "x^2"; return a }())]))], width: 320)
            fv.frame = CGRect(x: 0, y: 0, width: 320, height: 600); fv.layoutIfNeeded()
            v = fv
        case .customEmojiAtom:
            v = canvas([.paragraph(ParagraphBlock(id: BlockID("e"), runs: [
                TextRun(text: "\u{FFFC}", attributes: {
                    var a = CharacterAttributes.plain
                    a.emoji = EmojiRef(id: "1", instanceID: "i1", altText: "😀"); return a }())]))])
        case .buttonRow:
            v = canvas([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])),
                        .buttonRow(ButtonRowBlock(id: BlockID("br")))])
        }
        // The probe is the first editable slot of the kind's own region. `allLeafRegions()` is in
        // document order, so index 0 is the kind's region for every single-block seed; the two
        // container kinds and the button row need an explicit pick.
        let regions = v.allLeafRegions()
        let region: LeafTextRegion
        switch kind {
        case .detailsBody:        region = regions[1]                 // [0] = title, [1] = body
        case .tableCellCrossCell: region = regions[1]                 // cell B
        case .buttonRow:          region = regions[0]                 // ButtonRowBox has NO leaf region
        default:                  region = regions[0]
        }
        let probe = kind == .imageGap ? v.boxes[0].nodeStart : region.globalStart
        return (v, probe, kind == .customEmojiAtom ? "😀" : (kind == .formulaAtom ? "x^2" : "Alpha"))
    }

    // MARK: worked triple (Step 2a) + the seven mechanically-identical rows (Step 2b)

    func test_caretRect_heading_isNonDegenerate() {
        let (v, probe, _) = seed(.heading)
        let r = v.caretRect(for: pos(probe))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertFalse(r.isNull)
        XCTAssertNotEqual(r, .zero, "a renderable position must not take the D9 .zero branch")
    }

    func test_caretRect_listItem_isNonDegenerate() {
        let (v, probe, _) = seed(.listItem)
        let r = v.caretRect(for: pos(probe))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertFalse(r.isNull)
        XCTAssertNotEqual(r, .zero, "a renderable position must not take the D9 .zero branch")
    }

    func test_caretRect_codeBlock_isNonDegenerate() {
        let (v, probe, _) = seed(.codeBlock)
        let r = v.caretRect(for: pos(probe))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertFalse(r.isNull)
        XCTAssertNotEqual(r, .zero, "a renderable position must not take the D9 .zero branch")
    }

    func test_caretRect_blockQuote_isNonDegenerate() {
        let (v, probe, _) = seed(.blockQuote)
        let r = v.caretRect(for: pos(probe))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertFalse(r.isNull)
        XCTAssertNotEqual(r, .zero, "a renderable position must not take the D9 .zero branch")
    }

    func test_caretRect_pullQuote_isNonDegenerate() {
        let (v, probe, _) = seed(.pullQuote)
        let r = v.caretRect(for: pos(probe))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertFalse(r.isNull)
        XCTAssertNotEqual(r, .zero, "a renderable position must not take the D9 .zero branch")
    }

    func test_caretRect_detailsBody_isNonDegenerate() {
        let (v, probe, _) = seed(.detailsBody)
        let r = v.caretRect(for: pos(probe))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertFalse(r.isNull)
        XCTAssertNotEqual(r, .zero, "a renderable position must not take the D9 .zero branch")
    }

    func test_caretRect_mediaCaption_isNonDegenerate() {
        let (v, probe, _) = seed(.mediaCaption)
        let r = v.caretRect(for: pos(probe))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertFalse(r.isNull)
        XCTAssertNotEqual(r, .zero, "a renderable position must not take the D9 .zero branch")
    }

    func test_caretRect_formulaAtom_isNonDegenerate() {
        let (v, probe, _) = seed(.formulaAtom)
        let r = v.caretRect(for: pos(probe))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertFalse(r.isNull)
        XCTAssertNotEqual(r, .zero, "a renderable position must not take the D9 .zero branch")
    }

    // MARK: the two rows whose caret takes a different branch (Step 2c)

    /// The image gap takes the media branch (+UITextInput.swift:261-264): the caret is a thin (2pt) bar
    /// positioned at `img.mediaRect()`'s leading edge, with the media's own HEIGHT — not a glyph-derived
    /// height, since there is no text leaf here.
    ///
    /// The brief predicted `r.minX == media.frame.minX`. Verified real value: `r.minX == 0`, NOT
    /// `frame.minX` (16, the default page margin). `MediaBlockBox.mediaRect()`
    /// (`S/Canvas/MediaBlockBox.swift:225-230`) computes `bleedX = frame.minX - horizontalBleed`, and the
    /// default top-level media style bleeds a FULL page margin (`horizontalBleed == pageMargin == 16`),
    /// so the bleed exactly cancels `frame.minX` and the gap caret sits at the canvas edge (x=0), not the
    /// text column's left edge. Pinned against `mediaRect()` itself (the box's own oracle), not a literal,
    /// since that IS the documented computation `caretRect` delegates to.
    func test_caretRect_imageGap_usesTheFullWidthMediaBranch() {
        let (v, probe, _) = seed(.imageGap)
        let r = v.caretRect(for: pos(probe))
        let media = v.boxes.compactMap { $0 as? MediaBlockBox }.first!
        let mediaRect = media.mediaRect()
        XCTAssertEqual(r.minX, mediaRect.minX, accuracy: 0.5)
        XCTAssertEqual(r.minY, mediaRect.minY, accuracy: 0.5)
        XCTAssertEqual(r.height, mediaRect.height, accuracy: 0.5, "the caret height is the MEDIA's height, not a glyph-derived one")
        XCTAssertEqual(r.width, 2, "the gap caret is a fixed 2pt bar, not the media's full width")
        XCTAssertEqual(r.minX, 0, accuracy: 0.5, "the bleed cancels the page margin at the default media style")
    }

    /// A COLLAPSED block quote takes the collapsed branch (+UITextInput.swift:267-269): its body
    /// regions are not laid out, so the caret resolves against the collapsed header row.
    func test_caretRect_collapsedBlockQuote_usesTheCollapsedBranch() {
        let v = canvas([.blockQuote(BlockQuote(
            id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("qp"), runs: [TextRun(text: "Alpha")]))],
            collapsed: true))])
        let r = v.caretRect(for: pos(v.boxes[0].textStart))
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertLessThanOrEqual(r.maxY, v.boxes[0].frame.maxY + 1.0,
                                 "a collapsed quote's caret stays within the collapsed header row")
    }
    // `.buttonRow` gets NO caret row: `ButtonRowBox.leafRegions()` is empty (`S/Canvas/ButtonRowBox.swift:250`),
    // so there is no in-row caret position to pin — Task 4 Step 2e records that fact instead.
}
#endif

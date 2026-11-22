#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Pins the UITextInput text/range primitives across the block-kind matrix. Phase 4 family 1
/// moves every one of these witnesses behind the backend; this is its regression gate.
@available(iOS 16.0, *)
final class TextInputWitnessMatrixTests: XCTestCase {
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func pos(_ v: DocumentCanvasView, _ offset: Int) -> DocumentTextPosition {
        DocumentTextPosition(offset)
    }
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }

    // MARK: beginning/end of document

    func test_beginningOfDocument_isRenderable_notTheStructuralZeroSlot() {
        let v = canvas([para("p0", "Alpha")])
        let begin = v.beginningOfDocument as! DocumentTextPosition
        XCTAssertEqual(begin.offset, v.boxes[0].textStart)
        XCTAssertTrue(v.isRenderablePosition(begin.offset))
    }

    func test_endOfDocument_isRenderable_notDocumentSize() {
        let v = canvas([para("p0", "Alpha"), para("p1", "Beta")])
        let end = v.endOfDocument as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(end.offset))
        XCTAssertLessThanOrEqual(end.offset, v.documentSizeValue)
    }

    // MARK: textRange(from:to:) — ORDERS its arguments

    func test_textRangeFromTo_ordersItsArguments() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        let r = v.textRange(from: pos(v, s + 3), to: pos(v, s)) as! DocumentTextRange
        XCTAssertEqual(r.from.offset, s)
        XCTAssertEqual(r.to.offset, s + 3)
    }

    // MARK: position(from:offset:)

    func test_positionFromOffset_forwardAndBackward() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        XCTAssertEqual((v.position(from: pos(v, s), offset: 2) as! DocumentTextPosition).offset, s + 2)
        XCTAssertEqual((v.position(from: pos(v, s + 2), offset: -2) as! DocumentTextPosition).offset, s)
    }

    func test_positionFromOffset_outOfDocument_returnsNil() {
        let v = canvas([para("p0", "Alpha")])
        XCTAssertNil(v.position(from: pos(v, 0), offset: -1))
        XCTAssertNil(v.position(from: pos(v, v.documentSizeValue), offset: 1))
    }

    func test_positionFromOffset_snapsAcrossAParagraphBoundaryToARenderableSlot() {
        let v = canvas([para("p0", "Alpha"), para("p1", "Beta")])
        let endOfFirst = v.boxes[0].textStart + v.boxes[0].textLength
        let next = v.position(from: pos(v, endOfFirst), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    // MARK: offset(from:to:) and compare(_:to:)

    func test_offsetFromTo_isSignedAndSymmetric() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        XCTAssertEqual(v.offset(from: pos(v, s), to: pos(v, s + 4)), 4)
        XCTAssertEqual(v.offset(from: pos(v, s + 4), to: pos(v, s)), -4)
    }

    func test_compare_ordersByOffset() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        XCTAssertEqual(v.compare(pos(v, s), to: pos(v, s + 1)), .orderedAscending)
        XCTAssertEqual(v.compare(pos(v, s + 1), to: pos(v, s)), .orderedDescending)
        XCTAssertEqual(v.compare(pos(v, s), to: pos(v, s)), .orderedSame)
    }

    // MARK: text(in:)

    func test_textInRange_withinOneParagraph() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        XCTAssertEqual(v.text(in: DocumentTextRange(pos(v, s), pos(v, s + 3))), "Alp")
    }

    func test_textInRange_acrossTopLevelParagraphs_insertsANewline() {
        let v = canvas([para("p0", "Alpha"), para("p1", "Beta")])
        let from = v.boxes[0].textStart
        let to = v.boxes[1].textStart + 4
        XCTAssertEqual(v.text(in: DocumentTextRange(pos(v, from), pos(v, to))), "Alpha\nBeta")
    }

    func test_textInRange_emptyRange_isEmptyString() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        XCTAssertEqual(v.text(in: DocumentTextRange(pos(v, s), pos(v, s))), "")
    }

    // MARK: characterRange(byExtending:in:) and position(within:farthestIn:)

    // NOTE: despite its name (kept verbatim from the brief's literal Step-1 code), this does NOT grow by
    // one character. `characterRange(byExtending:in:)` (+UITextInput.swift:218-223) extends to the FAR END
    // of the axis in the requested direction — `.right`/`.down` go all the way to `documentSize`, `.left`/
    // `.up` all the way to 0 — regardless of how far `position` is from that end. The brief's predicted
    // value (`s + 1`) was wrong; verified real value is `v.documentSizeValue`.
    func test_characterRangeByExtending_right_extendsToDocumentEnd() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        let r = v.characterRange(byExtending: pos(v, s), in: .right) as! DocumentTextRange
        XCTAssertEqual(r.from.offset, s)
        XCTAssertEqual(r.to.offset, v.documentSizeValue, "extends to the DOCUMENT END, not position+1")
    }

    func test_positionWithinFarthestIn_returnsTheRangeEndpoint() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        let range = DocumentTextRange(pos(v, s), pos(v, s + 4))
        XCTAssertEqual((v.position(within: range, farthestIn: .right) as! DocumentTextPosition).offset, s + 4)
        XCTAssertEqual((v.position(within: range, farthestIn: .left) as! DocumentTextPosition).offset, s)
    }

    // MARK: setBaseWritingDirection is a deliberate no-op

    func test_setBaseWritingDirection_isANoOp() {
        let v = canvas([para("p0", "Alpha")])
        let s = v.boxes[0].textStart
        let before = v.baseWritingDirection(for: pos(v, s), in: .forward)
        v.setBaseWritingDirection(.rightToLeft, for: DocumentTextRange(pos(v, s), pos(v, s + 4)))
        XCTAssertEqual(v.baseWritingDirection(for: pos(v, s), in: .forward), before)
    }

    // MARK: block-kind matrix

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
            // (both real hosts do), so wire one here — same pattern as
            // `ComposerSelectionMappingTests.makeFormulaCanvas` — to characterize that path faithfully.
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
        case .codeBlock:          region = regions[1]                 // [0] = language line, [1] = code text
        case .detailsBody:        region = regions[1]                 // [0] = title, [1] = body
        case .tableCellCrossCell: region = regions[1]                 // cell B
        case .buttonRow:          region = regions[0]                 // ButtonRowBox has NO leaf region
        default:                  region = regions[0]
        }
        let probe = kind == .imageGap ? v.boxes[0].nodeStart : region.globalStart
        return (v, probe, kind == .customEmojiAtom ? "😀" : (kind == .formulaAtom ? "x^2" : "Alpha"))
    }
    // (`.buttonRow` deliberately has no leaf region of its own — `ButtonRowBox.leafRegions()` returns `[]`
    // (`S/Canvas/ButtonRowBox.swift:250`). That is exactly the fact its three tests record: position
    // arithmetic must step OVER the row without landing in it.)

    // MARK: .heading (worked triple)

    func test_heading_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.heading)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + (text as NSString).length))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_heading_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.heading)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_heading_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.heading)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }

    // MARK: .listItem

    func test_listItem_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.listItem)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + (text as NSString).length))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_listItem_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.listItem)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_listItem_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.listItem)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }

    // MARK: .codeBlock

    func test_codeBlock_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.codeBlock)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + (text as NSString).length))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_codeBlock_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.codeBlock)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_codeBlock_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.codeBlock)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }

    // MARK: .blockQuote

    func test_blockQuote_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.blockQuote)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + (text as NSString).length))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_blockQuote_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.blockQuote)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_blockQuote_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.blockQuote)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }

    // MARK: .pullQuote

    func test_pullQuote_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.pullQuote)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + (text as NSString).length))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_pullQuote_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.pullQuote)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_pullQuote_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.pullQuote)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }

    // MARK: .detailsBody

    func test_detailsBody_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.detailsBody)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + (text as NSString).length))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_detailsBody_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.detailsBody)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_detailsBody_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.detailsBody)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }

    // MARK: .tableCellInCell

    func test_tableCellInCell_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.tableCellInCell)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + (text as NSString).length))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_tableCellInCell_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.tableCellInCell)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_tableCellInCell_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.tableCellInCell)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }

    // MARK: .tableCellCrossCell — text(in:) glues cells with NO separator (the row's point)

    func test_tableCellCrossCell_textInRange_projectsExpectedText() {
        let (v, _, _) = seed(.tableCellCrossCell)
        let regions = v.allLeafRegions()
        let cellA = regions[0], cellB = regions[1]
        let r = DocumentTextRange(pos(v, cellA.globalStart), pos(v, cellB.globalStart + cellB.length))
        // NO separator between cells — text(in:) only inserts "\n" at TOP-LEVEL paragraph boundaries
        // (+UITextInput.swift:23-30); a table is one editing surface and cells don't compose marked text.
        XCTAssertEqual(v.text(in: r), "AlphaBeta")
    }

    func test_tableCellCrossCell_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.tableCellCrossCell)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_tableCellCrossCell_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.tableCellCrossCell)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }

    // MARK: .mediaCaption

    func test_mediaCaption_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.mediaCaption)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + (text as NSString).length))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_mediaCaption_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.mediaCaption)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_mediaCaption_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.mediaCaption)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }

    // MARK: .imageGap — the probe is the gap (nodeStart), not the caption; text(in:) over the gap is ""

    func test_imageGap_textInRange_projectsExpectedText() {
        let (v, probe, _) = seed(.imageGap)
        // The gap itself carries no text; a zero-length range there is empty.
        XCTAssertEqual(v.text(in: DocumentTextRange(pos(v, probe), pos(v, probe))), "")
    }

    func test_imageGap_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.imageGap)
        XCTAssertTrue(v.isRenderablePosition(probe))
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_imageGap_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.imageGap)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 1)), 1)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 1)), .orderedAscending)
    }

    // MARK: .formulaAtom — text(in:) over the single U+FFFC slot returns the LaTeX source

    func test_formulaAtom_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.formulaAtom)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + 1))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_formulaAtom_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.formulaAtom)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_formulaAtom_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.formulaAtom)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 1)), 1)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 1)), .orderedAscending)
    }

    // MARK: .customEmojiAtom — text(in:) over the single U+FFFC slot returns the emoji's alt text

    func test_customEmojiAtom_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.customEmojiAtom)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + 1))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_customEmojiAtom_positionArithmeticStaysRenderable() {
        let (v, probe, _) = seed(.customEmojiAtom)
        let next = v.position(from: pos(v, probe), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
    }

    func test_customEmojiAtom_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.customEmojiAtom)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 1)), 1)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 1)), .orderedAscending)
    }

    // MARK: .buttonRow — position arithmetic must step OVER the row; it owns no leaf region

    func test_buttonRow_textInRange_projectsExpectedText() {
        let (v, probe, text) = seed(.buttonRow)
        let r = DocumentTextRange(pos(v, probe), pos(v, probe + (text as NSString).length))
        XCTAssertEqual(v.text(in: r), text)
    }

    func test_buttonRow_positionArithmeticStaysRenderable() {
        let (v, probe, text) = seed(.buttonRow)
        // The button row is the document's LAST block and owns no leaf region, so stepping forward from
        // the paragraph's end cannot advance INTO it — there is no renderable slot inside the row to land
        // on, so the position stays parked at the same renderable slot instead.
        let afterParagraph = probe + (text as NSString).length
        let next = v.position(from: pos(v, afterParagraph), offset: 1) as! DocumentTextPosition
        XCTAssertTrue(v.isRenderablePosition(next.offset))
        XCTAssertNotEqual(next.offset, afterParagraph + 1, "must not land inside the button row's structural slot")
    }

    func test_buttonRow_offsetAndCompareAreConsistent() {
        let (v, probe, _) = seed(.buttonRow)
        XCTAssertEqual(v.offset(from: pos(v, probe), to: pos(v, probe + 3)), 3)
        XCTAssertEqual(v.compare(pos(v, probe), to: pos(v, probe + 3)), .orderedAscending)
    }
}
#endif

import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The selection wash is measured against each block's SLOT — its canvas plus the space reserved
/// around it — instead of being clipped to its text container. Slots tile the document, which is
/// what closes the 3-40pt of unwashed space this editor used to leave between every pair of blocks.
@available(iOS 18.4, *)
final class EngineBlockSelectionRectTests: XCTestCase {
    var window: UIWindow!
    var editor: RichTextEngineEditorView!

    final class StubMediaView: UIView, RichTextMediaItemView {
        func update(size: CGSize) {}
        var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?
    }

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 900))
        editor.registerMediaViewProvider { _, _, _, _ in StubMediaView() }
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 900))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    // MARK: - the document every test measures

    func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }
    func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [para("\(id)p", text)], background: nil, isHeader: false)
    }
    /// A paragraph, an image with a caption, a quote with two children and an author, a code block
    /// with a language line, a bordered 2x2 table, a closing paragraph — one of every kind the
    /// defect report named, in one document.
    func loadProbeDocument() {
        editor.document = Document(blocks: [
            para("p0", "Plain paragraph one."),
            .media(MediaBlock(id: BlockID("m0"),
                              items: [MediaItem(mediaID: "x", kind: .image,
                                                naturalSize: Size2D(width: 1000, height: 500),
                                                isSpoiler: false)],
                              caption: [TextRun(text: "Caption here")])),
            .blockQuote(BlockQuote(id: BlockID("q0"),
                                   children: [para("q0a", "Quoted line one."), para("q0b", "Quoted two.")],
                                   author: [TextRun(text: "Someone")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "let x = 1\nlet y = 2")])),
            .table(TableBlock(id: BlockID("t0"),
                              columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                              rows: [Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B")]),
                                     Row(id: BlockID("r1"), cells: [cell("c", "C"), cell("d", "D")])],
                              bordered: true)),
            para("p1", "Plain paragraph two."),
        ])
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
    }

    /// Every engine block's slot, in engine content coordinates, in document order.
    func slots() -> [CGRect] {
        (0 ..< editor.currentRoles.count).map { editor.engine.id_selectionSlotForBlock(at: UInt($0)) }
    }

    // MARK: - Task 1

    /// The property the whole design rests on: one block's slot ends exactly where the next begins,
    /// so a wash built from slots has nothing to leave behind.
    ///
    /// Between STACKED NEIGHBOURS, which is where the stacking pass's `y` runs continuously. A
    /// placed run — a table — is laid out by its own anchor and extent, so it interrupts the
    /// sequence and the two stacked blocks either side of it are not neighbours at all. Whether the
    /// document as a whole is covered, table included, is
    /// `test_noRowOfAFullySelectedDocumentIsLeftUnwashed`'s question, asked of the rects rather than
    /// of the slots.
    func test_theSlotsOfStackedBlocksTileWithoutGapOrOverlap() {
        loadProbeDocument()
        let all = slots()
        let roles = editor.currentRoles
        var pairs = 0
        for index in 0 ..< roles.count {
            XCTAssertFalse(all[index].isNull, "role \(index) has no slot")
            XCTAssertGreaterThan(all[index].height, 0, "role \(index) slot \(all[index])")
            guard index + 1 < roles.count,
                  roles[index].owningTable == nil, roles[index + 1].owningTable == nil else { continue }
            pairs += 1
            XCTAssertEqual(all[index].maxY, all[index + 1].minY, accuracy: 0.01,
                           "role \(index) slot \(all[index]) does not meet role \(index + 1) slot \(all[index + 1])")
        }
        XCTAssertEqual(pairs, 7, "expected 8 stacked blocks in one run plus one after the table")
    }

    /// A slot is the block's canvas GROWN by the space reserved around it — never the canvas itself,
    /// which is the rect the old wash was clipped to.
    func test_aSlotContainsItsBlocksFrameAndTheSpaceReservedAroundIt() {
        loadProbeDocument()
        // The quote's first child: the band's 8pt interior sits above its frame.
        guard let child = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("q0a") })
        else { return XCTFail("no q0a role") }
        let frame = editor.engine.id_frameForBlock(at: UInt(child))
        let slot = editor.engine.id_selectionSlotForBlock(at: UInt(child))
        XCTAssertTrue(slot.contains(frame), "slot \(slot) does not contain frame \(frame)")
        XCTAssertLessThan(slot.minY, frame.minY, "the quote's interior padding is above the frame")
    }

    /// The grid cell `id` carries, in engine content coordinates.
    ///
    /// A cell role's `blockID` is the CELL's id, not the id of the paragraph whose text it carries
    /// (`EngineBlockRole.swift:205`), and `EngineTableGrid.CellGeometry` is keyed the same way — so
    /// both sides of every comparison below say "a", never "ap".
    func gridCell(_ id: String) -> (index: Int, rect: CGRect)? {
        guard let index = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID(id) }),
              let grid = editor.tableGrids[BlockID("t0")],
              let geometry = grid.cell(withID: BlockID(id)),
              let table = editor.tableFrame(forTableAt: index) else { return nil }
        return (index, geometry.rect.offsetBy(dx: table.minX, dy: table.minY))
    }

    /// A PLACED block's slot is its whole cell, padding included — 153.5 x 48 where the text canvas
    /// is 140.5 x 34, which is the 14pt every cell used to leave unwashed.
    ///
    /// Asked of a SECOND-row cell. A first-row cell also carries the run's leading rhythm, which is
    /// `test_aFirstRowCellCarriesTheRhythmReservedAboveItsTable`'s subject.
    func test_aCellsSlotIsTheWholeCellAndNotItsTextCanvas() {
        loadProbeDocument()
        guard let c = gridCell("c") else { return XCTFail("no cell geometry") }
        let slot = editor.engine.id_selectionSlotForBlock(at: UInt(c.index))
        XCTAssertEqual(slot.minX, c.rect.minX, accuracy: 0.5, "slot \(slot) vs cell \(c.rect)")
        XCTAssertEqual(slot.width, c.rect.width, accuracy: 0.5, "slot \(slot) vs cell \(c.rect)")
        XCTAssertEqual(slot.minY, c.rect.minY, accuracy: 1.0, "slot \(slot) vs cell \(c.rect)")
        XCTAssertEqual(slot.height, c.rect.height, accuracy: 1.0, "slot \(slot) vs cell \(c.rect)")
    }

    /// The gap a host reserves above a table lives INSIDE the placed run — its frames start below
    /// the run's anchor — so it belongs to no cell's rect and was the one hole a document of slots
    /// still had. The first row owns it, the way every stacked block owns the space up to its
    /// neighbour.
    func test_aFirstRowCellCarriesTheRhythmReservedAboveItsTable() {
        loadProbeDocument()
        guard let a = gridCell("a"), let c = gridCell("c") else { return XCTFail("no cell geometry") }
        let first = editor.engine.id_selectionSlotForBlock(at: UInt(a.index))
        let second = editor.engine.id_selectionSlotForBlock(at: UInt(c.index))
        XCTAssertEqual(first.width, a.rect.width, accuracy: 0.5, "the width is still the cell's")
        XCTAssertLessThan(first.minY, a.rect.minY - 1.0, "the first row did not take the rhythm above it")
        XCTAssertEqual(first.maxY, a.rect.maxY, accuracy: 1.0, "it grew downward too: \(first)")
        XCTAssertEqual(second.minY, c.rect.minY, accuracy: 1.0, "a second row took rhythm it has none of")
    }

    /// An index past the end is NULL, not zero: zero is a plausible rect and a caller would park on it.
    func test_anUnknownBlockHasNoSlot() {
        loadProbeDocument()
        XCTAssertTrue(editor.engine.id_selectionSlotForBlock(at: UInt(editor.currentRoles.count + 5)).isNull)
    }

    // MARK: - Task 2

    /// The rects UIKit paints for a selection of the whole document.
    func selectAllRects() -> [CGRect] {
        let blocks = editor.engine.attributedBlocks
        let total = blocks.reduce(0) { $0 + $1.length } + max(blocks.count - 1, 0)
        guard let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 0),
              let end = editor.engine.position(from: start, offset: total),
              let range = editor.engine.textRange(from: start, to: end) else {
            XCTFail("the document has no full range")
            return []
        }
        return editor.engine.selectionRects(for: range).map(\.rect)
    }

    /// The defect's "3-40pt of unwashed space between every pair", as one assertion: scan the
    /// selected column a point at a time and demand ink everywhere. A gap anywhere is a row no rect
    /// covers.
    func test_noRowOfAFullySelectedDocumentIsLeftUnwashed() {
        loadProbeDocument()
        let rects = selectAllRects()
        XCTAssertFalse(rects.isEmpty)
        // From the first block's glyphs to the last block's, NOT slot to slot. The first block's
        // top inset and the last block's bottom inset are outside the selection on the side that
        // matters — nothing precedes the first block, nothing follows the last — so they are
        // correctly never washed, exactly as a stock text view leaves the space above its first
        // line alone.
        let first = editor.engine.id_frameForBlock(at: 0)
        let last = editor.engine.id_frameForBlock(at: UInt(editor.currentRoles.count - 1))
        let top = first.minY
        let bottom = last.maxY
        var uncovered: [CGFloat] = []
        var y = top + 0.5
        while y < bottom {
            if !rects.contains(where: { $0.minY <= y && y <= $0.maxY }) { uncovered.append(y) }
            y += 1.0
        }
        // Not "nothing is uncovered": a bordered grid's rules are the TABLE's to draw, and washing
        // over them would stop it reading as a grid. So every uncovered run must be at most a
        // border thick AND lie inside the table. Anything else is a hole in the rhythm.
        guard let cellIndex = editor.currentRoles.firstIndex(where: { $0.owningTable != nil }),
              let table = editor.tableFrame(forTableAt: cellIndex) else { return XCTFail("no table") }
        var runs: [(CGFloat, CGFloat)] = []
        for row in uncovered {
            if let last = runs.last, row - last.1 <= 1.5 { runs[runs.count - 1].1 = row }
            else { runs.append((row, row)) }
        }
        for run in runs {
            XCTAssertLessThanOrEqual(run.1 - run.0, 1.5,
                                     "a \(run.1 - run.0 + 1)pt band at y \(run.0) has no selection over it")
            XCTAssertTrue(table.insetBy(dx: 0, dy: -1.5).contains(CGPoint(x: table.midX, y: run.0)),
                          "an uncovered row at y \(run.0) is outside the table \(table)")
        }
    }

    /// The last paragraph of a select-all HUGS its final glyph rather than filling the column, and
    /// that is correct — the same rule as `test_aSelectionEndingMidParagraphStillHugsItsGlyphs`,
    /// since the selection ends there too. A stock text view does the same on the last line of a
    /// select-all. What DID change is the vertical: it now reaches up into the rhythm above it,
    /// because the selection does continue past that side.
    func test_theLastParagraphOfASelectAllHugsItsFinalGlyphButFillsTheRhythmAboveIt() {
        loadProbeDocument()
        let last = editor.currentRoles.count - 1
        let slot = editor.engine.id_selectionSlotForBlock(at: UInt(last))
        let frame = editor.engine.id_frameForBlock(at: UInt(last))
        let rects = selectAllRects().filter { $0.midY > slot.minY && $0.midY < slot.maxY }
        XCTAssertEqual(rects.count, 1, "\(rects)")
        XCTAssertLessThan(rects[0].maxX, slot.maxX - 100, "it filled the column: \(rects[0])")
        XCTAssertEqual(rects[0].minY, slot.minY, accuracy: 0.5,
                       "it did not reach the rhythm above it: rect \(rects[0]) slot \(slot)")
        XCTAssertLessThan(rects[0].minY, frame.minY - 1.0, "the rhythm above it is not empty")
    }

    /// Every cell used to leave its 14pt of padding bare — a 20pt stripe in a 48pt cell. The rect
    /// UIKit paints is now the cell.
    func test_aFullySelectedCellIsWashedOverItsWholePadding() {
        loadProbeDocument()
        guard let index = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("a") })
        else { return XCTFail("no cell role") }
        let slot = editor.engine.id_selectionSlotForBlock(at: UInt(index))
        let rects = selectAllRects().filter { slot.insetBy(dx: -1, dy: -1).contains($0.insetBy(dx: 0.5, dy: 0.5)) }
        XCTAssertEqual(rects.count, 1, "\(rects)")
        XCTAssertEqual(rects[0].height, slot.height, accuracy: 0.5, "rect \(rects[0]) vs cell \(slot)")
        XCTAssertEqual(rects[0].width, slot.width, accuracy: 0.5, "rect \(rects[0]) vs cell \(slot)")
    }

    /// The guard against the trailing rule over-firing: a selection that ENDS inside a paragraph
    /// must still stop at the glyph it ends on, not run to the column's edge.
    func test_aSelectionEndingMidParagraphStillHugsItsGlyphs() {
        editor.document = Document(blocks: [para("p0", "Plain paragraph one and a bit more text.")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 0),
              let end = editor.engine.position(from: start, offset: 5),
              let range = editor.engine.textRange(from: start, to: end) else { return XCTFail() }
        let rects = editor.engine.selectionRects(for: range).map(\.rect)
        let slot = editor.engine.id_selectionSlotForBlock(at: 0)
        XCTAssertEqual(rects.count, 1)
        XCTAssertLessThan(rects[0].maxX, slot.maxX - 50, "\"Plain\" washed to the column edge: \(rects[0])")
    }

    /// A word in the middle of a paragraph is uncovered on BOTH sides, so no rule fires and its
    /// rects are the container-clipped geometry they have always been — which is what keeps the
    /// autocorrect underline and the selection handles on the word rather than on the line.
    func test_aWordsSelectionRectsStillHugItsGlyphs() {
        editor.document = Document(blocks: [para("p0", "alpha beta gamma delta")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 6),
              let end = editor.engine.position(from: start, offset: 4),
              let range = editor.engine.textRange(from: start, to: end) else { return XCTFail() }
        let rects = editor.engine.selectionRects(for: range).map(\.rect)
        let slot = editor.engine.id_selectionSlotForBlock(at: 0)
        XCTAssertEqual(rects.count, 1)
        XCTAssertGreaterThan(rects[0].minX, slot.minX + 10, "\"beta\" reached the leading edge: \(rects[0])")
        XCTAssertLessThan(rects[0].maxX, slot.maxX - 50, "\"beta\" reached the trailing edge: \(rects[0])")
    }

    // MARK: - Task 3

    /// The union of every rect that touches `box` — how a multi-block container's wash is compared
    /// against the one frame its decoration was given.
    ///
    /// Intersecting, not contained. A container's first child legitimately reaches ABOVE its band:
    /// that child's top inset carries both the rhythm separating the container from what precedes it
    /// AND the band's own interior padding, and the wash covers the rhythm too. So the claim is that
    /// the wash COVERS the band vertically and matches it EXACTLY across — the second half being the
    /// column this task is about.
    func washCovering(_ box: CGRect) -> CGRect {
        selectAllRects().filter { $0.intersects(box.insetBy(dx: 1, dy: 1)) }
            .reduce(CGRect.null) { $0.union($1) }
    }

    func assertWashSpans(_ box: CGRect, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let wash = washCovering(box)
        XCTAssertEqual(wash.minX, box.minX, accuracy: 0.5, "\(label): \(wash) vs \(box)", file: file, line: line)
        XCTAssertEqual(wash.maxX, box.maxX, accuracy: 0.5, "\(label): \(wash) vs \(box)", file: file, line: line)
        XCTAssertLessThanOrEqual(wash.minY, box.minY + 0.5, "\(label) top uncovered: \(wash) vs \(box)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(wash.maxY, box.maxY - 0.5, "\(label) bottom uncovered: \(wash) vs \(box)", file: file, line: line)
    }

    /// A quote's wash is its BAND — and the band's frame is the one the decoration view was given,
    /// not a second derivation of it.
    func test_aFullySelectedQuoteIsWashedOverItsBand() {
        loadProbeDocument()
        guard let band = editor.containerDecorationViews[BlockID("q0")] else { return XCTFail("no band") }
        assertWashSpans(band.frame, "quote band")
    }

    /// A top-level code box bleeds past the text column to the canvas edge; its wash goes with it.
    func test_aFullySelectedCodeBlockIsWashedOverItsBox() {
        loadProbeDocument()
        guard let band = editor.containerDecorationViews[BlockID("c0")] else { return XCTFail("no band") }
        XCTAssertEqual(band.frame.minX, 0.0, accuracy: 0.5, "the box is expected to bleed")
        assertWashSpans(band.frame, "code box")
    }

    /// An inner quote's wash stops at the INNER band. The slot alone is the full column, so without
    /// a host-declared column the wash runs straight across the outer quote's bar.
    func test_aNestedQuotesWashStopsAtItsOwnBand() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("outer"), children: [
                para("a", "outer line"),
                .blockQuote(BlockQuote(id: BlockID("inner"), children: [para("b", "inner line")], author: [])),
            ], author: [])),
        ])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let outer = editor.containerDecorationViews[BlockID("outer")],
              let inner = editor.containerDecorationViews[BlockID("inner")] else { return XCTFail("no bands") }
        XCTAssertGreaterThan(inner.frame.minX, outer.frame.minX, "the inner band is indented")
        guard let index = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("b") })
        else { return XCTFail("no inner child") }
        let slot = editor.engine.id_selectionSlotForBlock(at: UInt(index))
        XCTAssertEqual(slot.minX, inner.frame.minX, accuracy: 0.5, "slot \(slot) vs inner band \(inner.frame)")
        XCTAssertEqual(slot.width, inner.frame.width, accuracy: 0.5, "slot \(slot) vs inner band \(inner.frame)")
    }

    /// An image bleeds 16pt past the column on each side. Its wash is the hosted view's frame, so
    /// the whole photo is covered at one alpha instead of a darker core inside a lighter frame.
    func test_aFullySelectedMediaAtomIsWashedOverItsHostedView() {
        loadProbeDocument()
        guard let host = editor.mediaAtomViews[BlockID("m0")] else { return XCTFail("no hosted view") }
        XCTAssertLessThan(host.frame.minX, 0.0, "the image is expected to bleed past the column")
        guard let index = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("m0") })
        else { return XCTFail("no media role") }
        let slot = editor.engine.id_selectionSlotForBlock(at: UInt(index))
        XCTAssertEqual(slot.minX, host.frame.minX, accuracy: 0.5, "slot \(slot) vs host \(host.frame)")
        XCTAssertEqual(slot.width, host.frame.width, accuracy: 0.5, "slot \(slot) vs host \(host.frame)")
        // And the rect UIKit actually paints, not just the slot behind it.
        let rects = selectAllRects().filter { $0.midY > slot.minY && $0.midY < slot.maxY }
        XCTAssertEqual(rects.count, 1, "\(rects)")
        XCTAssertEqual(rects[0].minX, host.frame.minX, accuracy: 0.5, "rect \(rects[0]) vs host \(host.frame)")
        XCTAssertEqual(rects[0].maxX, host.frame.maxX, accuracy: 0.5, "rect \(rects[0]) vs host \(host.frame)")
    }

    /// A cell keeps its own slot even inside a quote: a band's column must not stretch each cell's
    /// wash across the whole grid.
    func test_aCellInsideAQuoteKeepsItsOwnColumn() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .table(TableBlock(id: BlockID("t"),
                                  columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                                  rows: [Row(id: BlockID("r"), cells: [cell("a", "A"), cell("b", "B")])],
                                  bordered: true)),
            ], author: [])),
        ])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let band = editor.containerDecorationViews[BlockID("q")],
              let index = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("a") })
        else { return XCTFail("no band or cell") }
        let slot = editor.engine.id_selectionSlotForBlock(at: UInt(index))
        XCTAssertLessThan(slot.width, band.frame.width - 20.0,
                          "the cell took the band's column: slot \(slot) band \(band.frame)")
    }

    // MARK: - Task 4

    /// One painter. The hosted view carries no tint of its own, so a selected photo reads at the
    /// same alpha as selected text instead of a darker core inside a lighter frame.
    func test_aSelectedImageIsPaintedOnceByTheWashAlone() {
        loadProbeDocument()
        guard let host = editor.mediaAtomViews[BlockID("m0")] else { return XCTFail("no hosted view") }
        _ = editor.engine.becomeFirstResponder()
        guard let index = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID("m0") })
        else { return XCTFail("no media role") }
        editor.engineSelectedRange = editor.flatRange(ofRoleAt: index)
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        let tinted = host.subviews.filter { $0.backgroundColor != nil && $0.backgroundColor != .clear }
        XCTAssertEqual(tinted, [], "the hosted view still paints a tint of its own: \(tinted)")
    }

    // MARK: - reported from the device, 2026-09-15

    /// A block's reserved space is two different things. The gap SEPARATING it from its neighbours
    /// is washed only when the selection reaches past it; the padding INSIDE its own box is part of
    /// the block and is washed whenever the block's content is. Selecting a quote on its own used to
    /// hug its text and author — 8pt of band bare at the top, 5pt at the bottom.
    func test_aQuoteSelectedOnItsOwnIsStillWashedOverItsWholeBand() {
        editor.document = Document(blocks: [
            para("p0", "before"),
            .blockQuote(BlockQuote(id: BlockID("q"), children: [para("a", "Quoted one."), para("b", "Quoted two.")],
                                   author: [TextRun(text: "Someone")])),
            para("p1", "after"),
        ])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let band = editor.containerDecorationViews[BlockID("q")] else { return XCTFail("no band") }
        // "before" is 6 long, so the quote's own content runs [7, 38): "Quoted one." [7, 18),
        // "Quoted two." [19, 30), "Someone" [31, 38) — its first character to the author's last,
        // with neither the separator before it nor the one after it selected. (This read 37 until
        // 2026-09-22, one short of the author's last character; it passed only because the bottom
        // padding then went to any segment that was last in its block, which also washed a word on
        // a code block's first line down to the block's bottom.)
        guard let s = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 7),
              let e = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 38),
              let r = editor.engine.textRange(from: s, to: e) else { return XCTFail("no range") }
        let rects = editor.engine.selectionRects(for: r).map(\.rect)
        let wash = rects.reduce(CGRect.null) { $0.union($1) }
        // COVERS the band, within UIKit's own 1pt. The rects carrying a selection's logical start
        // and end come back one point taller than the engine measured them — UIKit's doing, present
        // long before any of this and visible in the very first measurement of the defect (a
        // paragraph's frame at y 14 washing from y 13). So the claim is coverage with a cap, not
        // equality: it must reach the band, and must not reach a point further than UIKit's margin.
        XCTAssertLessThanOrEqual(wash.minY, band.frame.minY, "top of the band bare: \(wash) vs \(band.frame)")
        XCTAssertGreaterThanOrEqual(wash.minY, band.frame.minY - 1.5, "it swallowed rhythm above: \(wash)")
        XCTAssertGreaterThanOrEqual(wash.maxY, band.frame.maxY, "bottom of the band bare: \(wash) vs \(band.frame)")
        XCTAssertLessThanOrEqual(wash.maxY, band.frame.maxY + 1.5, "it swallowed rhythm below: \(wash)")
        // And it must NOT have taken the rhythm outside the band, which nothing selected.
        let before = editor.engine.id_selectionSlotForBlock(at: 0)
        XCTAssertGreaterThan(wash.minY, before.maxY - 0.5, "it swallowed the gap above the quote: \(wash)")
    }

    /// An empty line the selection ENDS on gets a small rect. It used to get nothing at all: the
    /// zero-width segment a head-only extension produces was dropped as empty, so pressing Return at
    /// the end of a document and selecting all left that line blank.
    func test_anEmptyLineTheSelectionEndsOnGetsASmallRect() {
        editor.document = Document(blocks: [para("a", "alpha"), para("e", "")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let s = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 0),
              let e = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 6),
              let r = editor.engine.textRange(from: s, to: e) else { return XCTFail("no range") }
        let rects = editor.engine.selectionRects(for: r).map(\.rect)
        let empty = editor.engine.id_frameForBlock(at: 1)
        let onTheEmptyLine = rects.filter { $0.midY > empty.minY && $0.midY < empty.maxY }
        XCTAssertEqual(onTheEmptyLine.count, 1, "the empty line got \(onTheEmptyLine.count) rects: \(rects)")
        guard let rect = onTheEmptyLine.first else { return }
        XCTAssertGreaterThan(rect.width, 0.5, "a zero-width rect draws nothing: \(rect)")
        XCTAssertLessThan(rect.width, 20.0, "small, not a filled line: \(rect)")
        XCTAssertEqual(rect.minX, empty.minX, accuracy: 0.5, "it sits at the line's leading edge: \(rect)")
    }

    /// ...and the trailing HANDLE belongs on that mark, not a line above it. A selection's logical
    /// end is a place on screen — the caret for the end offset, which sits at the start of the line
    /// after the break. The separator's canonical range still belongs to the block before it; only
    /// the endpoint moves (device, 2026-09-15).
    func test_theTrailingHandleSitsOnTheEmptyLinesMarkAndNotALineAbove() {
        editor.document = Document(blocks: [para("a", "alpha"), para("e", "")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let s = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 0),
              let e = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 6),
              let r = editor.engine.textRange(from: s, to: e) else { return XCTFail("no range") }
        let rects = editor.engine.selectionRects(for: r)
        let ends = rects.filter { $0.containsEnd }
        XCTAssertEqual(ends.count, 1, "exactly one rect carries the end: \(rects.map { ($0.rect, $0.containsEnd) })")
        let empty = editor.engine.id_frameForBlock(at: 1)
        guard let end = ends.first else { return }
        XCTAssertGreaterThan(end.rect.midY, empty.minY, "the end is above the empty line: \(end.rect) vs \(empty)")
        XCTAssertLessThan(end.rect.midY, empty.maxY, "the end is below the empty line: \(end.rect) vs \(empty)")
        // It lands where the caret for that offset does — the same place, by the same reasoning.
        let caret = editor.engine.caretRect(for: e)
        // Overlapping the caret's span, not identical to it: the mark takes the segment's glyph
        // height while the caret is padded to the line. What matters is that they are on the same
        // line, which the bounds above already pin.
        XCTAssertTrue(end.rect.intersects(caret.insetBy(dx: -4, dy: 0)),
                      "end \(end.rect) does not meet the caret \(caret)")
        // And exactly one rect still carries the start, on "alpha".
        XCTAssertEqual(rects.filter { $0.containsStart }.count, 1)
    }

    /// The guard on the other side: an empty line the selection passes THROUGH still fills, because
    /// the whole line is covered. Small means "the selection stops here", not "empty lines are small".
    func test_anEmptyLineTheSelectionPassesThroughStillFills() {
        editor.document = Document(blocks: [para("a", "alpha"), para("e", ""), para("b", "beta")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let s = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 0),
              let e = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 11),
              let r = editor.engine.textRange(from: s, to: e) else { return XCTFail("no range") }
        let rects = editor.engine.selectionRects(for: r).map(\.rect)
        let empty = editor.engine.id_frameForBlock(at: 1)
        let onTheEmptyLine = rects.filter { $0.midY > empty.minY && $0.midY < empty.maxY }
        XCTAssertEqual(onTheEmptyLine.count, 1, "\(rects)")
        XCTAssertEqual(onTheEmptyLine.first?.width ?? 0, empty.width, accuracy: 0.5, "it should fill")
    }

    /// The mark is the LINE's height, not the glyph box's. A head-extended zero-length segment
    /// measures the glyphs — several points short of the pinned line — so the mark read small
    /// against the full-width fill this same line gets when a selection passes through it, and the
    /// handle attached to it sat high.
    func test_theBreakMarkIsTheHeightOfItsLine() {
        editor.document = Document(blocks: [para("a", "alpha"), para("e", "")])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        guard let s = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 0),
              let e = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 6),
              let r = editor.engine.textRange(from: s, to: e) else { return XCTFail("no range") }
        let empty = editor.engine.id_frameForBlock(at: 1)
        guard let mark = editor.engine.selectionRects(for: r).map(\.rect)
            .first(where: { $0.midY > empty.minY && $0.midY < empty.maxY }) else { return XCTFail("no mark") }
        // The LINE, bottom-aligned in its box — not the box. A pinned line box is the line plus the
        // spacing that separates it from the block above, and that spacing is all at the TOP: a mark
        // filling the box reached up into the previous line (device, 2026-09-15).
        //
        // Asserted against the line ABOVE, because that is the complaint and because it is the one
        // claim UIKit cannot blur: it expands the rect carrying the selection's end by a point and
        // then integralizes it, which is why this arrives as 37…60 where the engine measured
        // 38.71…59.00. A mark sized to the whole box arrives at 36 and fails here; one sized to the
        // line arrives at 37 and does not.
        let above = editor.engine.id_frameForBlock(at: 0)
        XCTAssertGreaterThanOrEqual(mark.minY, above.maxY - 0.5,
                                    "the mark reaches into the line above: \(mark) vs \(above)")
        XCTAssertEqual(mark.maxY, empty.maxY, accuracy: 1.5, "not bottom-aligned: \(mark) in \(empty)")
        XCTAssertGreaterThan(mark.height, empty.height * 0.7, "it is still the line, not a sliver: \(mark)")
    }

    /// Whatever else moves, a selection names its own endpoints: exactly one rect carries the start
    /// and exactly one the end, and both are rects that exist.
    ///
    /// This replaced a claim that a selection ending at the start of a line WITH TEXT ends on that
    /// line. It did, briefly — but only because the geometry named no end at all there and UIKit
    /// synthesised a rect of its own at the caret. The engine's own contract forbids that
    /// (`IDDocumentLayoutCoordinatorTests.testSelectionsBoundedByAnEmptyBlockKeepTheirGeometry`), so
    /// the end stays with the block before the break when the block after contributes nothing — and
    /// the handle with it. The empty-line case is unaffected: there the mark IS a segment, and it
    /// takes the end (see the two tests above).
    func test_aSelectionAlwaysNamesExactlyOneStartAndOneEnd() {
        for blocks in [[para("a", "alpha"), para("b", "beta")],
                       [para("a", "alpha"), para("e", "")],
                       [para("a", "alpha"), para("e", ""), para("b", "beta")]] {
            editor.document = Document(blocks: blocks)
            editor.setNeedsLayout(); editor.layoutIfNeeded()
            let engineBlocks = editor.engine.attributedBlocks
            let total = engineBlocks.reduce(0) { $0 + $1.length } + max(engineBlocks.count - 1, 0)
            for end in 1 ... total {
                guard let s = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 0),
                      let e = editor.engine.position(from: editor.engine.beginningOfDocument, offset: end),
                      let r = editor.engine.textRange(from: s, to: e) else { continue }
                let rects = editor.engine.selectionRects(for: r)
                XCTAssertEqual(rects.filter(\.containsStart).count, 1,
                               "0..\(end) of \(blocks.count) blocks: \(rects.map { ($0.rect, $0.containsStart) })")
                XCTAssertEqual(rects.filter(\.containsEnd).count, 1,
                               "0..\(end) of \(blocks.count) blocks: \(rects.map { ($0.rect, $0.containsEnd) })")
                for rect in rects {
                    XCTAssertFalse(rect.rect.isNull, "0..\(end) vended a null rect")
                }
            }
        }
    }
}

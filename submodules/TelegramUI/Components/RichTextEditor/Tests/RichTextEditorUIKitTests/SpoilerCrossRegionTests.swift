#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The DEFINING spoiler scope: spoilers work "everywhere text lives" — table cells (dust riding the
/// table's horizontal scroll), structurally-selected rows, and cross-cell text selections. The existing
/// SpoilerReconcileTests/SpoilerHideTests only exercise body paragraphs; these cover the cross-region path.
final class SpoilerCrossRegionTests: XCTestCase {
    // MARK: builders (mirroring CanvasCharacterFormatTests idioms)

    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }

    /// A canvas with a leading body paragraph + a 2×2 table (header row + body row). The leading paragraph
    /// gives a text position OUTSIDE the table so the caret can be moved out of a spoilered cell.
    private func tableCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("lead"), runs: [TextRun(text: "Lead")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Name"), cell("b", "Role")]),
                       Row(id: BlockID("r1"), cells: [cell("c", "Alpha"), cell("d", "Beta")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }

    /// First-paragraph runs of table cell (row,col) from the live model.
    private func cellRuns(_ v: DocumentCanvasView, _ row: Int, _ col: Int) -> [TextRun] {
        guard let t = v.boxes.first(where: { $0 is TableBlockBox }) as? TableBlockBox,
              case .table(let model) = t.currentBlock() else { return [] }
        if case .paragraph(let p) = model.rows[row].cells[col].blocks[0] { return p.runs }
        return []
    }

    private func leaf(_ v: DocumentCanvasView, _ paragraphID: String) -> LeafTextRegion {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID(paragraphID)) }!
    }

    /// Concatenated text of cell (row,col)'s runs whose model attribute carries `spoiler`.
    private func spoileredText(_ v: DocumentCanvasView, _ row: Int, _ col: Int) -> String {
        cellRuns(v, row, col).filter { $0.attributes.spoiler }.map { $0.text }.joined()
    }

    // MARK: tests

    func test_spoilerInTableCell_hidesAndHostsInTableContentView() {
        let v = tableCanvas()
        // Spoiler the body cell (row 1, col 0 = "Alpha"; "cp" is its first paragraph).
        let cellRegion = leaf(v, "cp")
        v.setSelectionForTesting(anchor: cellRegion.globalStart, head: cellRegion.globalStart + 5)   // "Alpha"
        v.toggleSpoiler()
        XCTAssertTrue(v.documentHasSpoilers)
        // Move the caret OUT of the cell (to document start) so the spoiler hides.
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart)
        v.layoutIfNeeded()
        v.refreshSelectionUI()

        XCTAssertEqual(v.spoilerDustCountForTesting, 1, "one hidden cell spoiler → one dust view")
        XCTAssertTrue(v.spoilerRunsForTesting[0].hidden)
        // Cell dust must ride the table's horizontal scroll → hosted in the table's content view.
        XCTAssertTrue(v.firstSpoilerDustForTesting?.superview is TableContentView,
                      "cell dust must be parented in the table's scrolling content view")
    }

    func test_toggleSpoiler_onStructurallySelectedRow_spoilersEveryCell() {
        let v = tableCanvas()
        // Park the caret in the table, then structurally select a BODY row (row 1; the char-format row
        // test uses row 1 too — the header row's render-only bold is irrelevant to spoiler, which persists).
        let cellRegion = leaf(v, "cp")
        v.setSelectionForTesting(anchor: cellRegion.globalStart, head: cellRegion.globalStart)
        v.selectTableRow(1)
        XCTAssertNotNil(v.tableSelection)
        v.toggleSpoiler()                       // no text selection — drives off the row selection
        // Every cell in row 1 must be spoilered in the model.
        XCTAssertEqual(spoileredText(v, 1, 0), "Alpha")
        XCTAssertEqual(spoileredText(v, 1, 1), "Beta")
    }

    func test_toggleSpoiler_acrossTwoCells_spoilersBoth() {
        let v = tableCanvas()
        // A TEXT selection spanning two body cells (row 1): anchor in "Alpha", head in "Beta".
        let a = leaf(v, "cp")   // "Alpha"
        let b = leaf(v, "dp")   // "Beta"
        v.setSelectionForTesting(anchor: a.globalStart + 1, head: b.globalStart + 3)   // "lpha" + "Bet"
        v.toggleSpoiler()
        XCTAssertEqual(spoileredText(v, 1, 0), "lpha")
        XCTAssertEqual(spoileredText(v, 1, 1), "Bet")
    }

    /// Regression for the `test_spoilerInTableCell_hidesAndHostsInTableContentView` hang. `recompute()` runs
    /// every layout pass and re-applies the cell render overrides; it must NOT churn a cell layout's
    /// `renderVersion`. It used to re-assign `layout.attributedString` unconditionally in
    /// `applyDisplayOverride`, which (a) defeated the render-signature repaint gate and (b) reset the layout's
    /// spoiler-hide ranges every pass — so `setSpoilerHidden` never reported "unchanged", `syncSpoilers` called
    /// `setNeedsLayout()` every pass, and `layoutIfNeeded()` looped forever for a HIDDEN cell spoiler. Fast +
    /// hang-free: it asserts the idempotency directly rather than relying on `layoutIfNeeded` to converge.
    func test_tableRecompute_doesNotChurnCellRenderVersion() {
        let v = tableCanvas()
        let table = v.boxes.first { $0 is TableBlockBox } as! TableBlockBox
        let cell = table.cellParagraphBoxes().first!.box
        let sig = cell.renderSignature
        table.recompute()
        XCTAssertEqual(cell.renderSignature, sig,
                       "recompute must not bump a cell layout's renderVersion (else syncSpoilers loops on a hidden cell spoiler)")
    }

    func test_spoilerInImageCaption_hidesWithDust() {
        let v = DocumentCanvasView()
        let img = MediaBlock(id: BlockID("i"), mediaID: "x", naturalSize: Size2D(width: 40, height: 40),
                             caption: [TextRun(text: "Caption")])
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("lead"), runs: [TextRun(text: "Lead")])),
            .media(img),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let cap = v.allLeafRegions().first { $0.ref == .caption(BlockID("i")) }!
        v.setSelectionForTesting(anchor: cap.globalStart, head: cap.globalStart + 7)   // "Caption"
        v.toggleSpoiler()
        XCTAssertTrue(v.documentHasSpoilers)
        // Move the caret out of the caption so the spoiler hides.
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart)
        v.layoutIfNeeded()
        v.refreshSelectionUI()
        XCTAssertEqual(v.spoilerDustCountForTesting, 1, "a hidden caption spoiler realizes dust (canvas overlay)")
        XCTAssertTrue(v.spoilerRunsForTesting.first?.hidden ?? false)
    }
}
#endif

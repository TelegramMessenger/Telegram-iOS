#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasCrossCellEditTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    /// [ paragraph "Top", table( "Alpha" | "Beta" ), paragraph "Bot" ]
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 500); v.layoutIfNeeded()
        return v
    }
    /// (block count, first paragraph text) of cell (row,col).
    func cellInfo(_ v: DocumentCanvasView, _ row: Int, _ col: Int) -> (blocks: Int, firstText: String)? {
        guard let t = v.boxes.first(where: { $0 is TableBlockBox }) as? TableBlockBox,
              case .table(let model) = t.currentBlock() else { return nil }
        let cell = model.rows[row].cells[col]
        let texts = cell.blocks.compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
        return (cell.blocks.count, texts.first ?? "")
    }
    func hasTable(_ v: DocumentCanvasView) -> Bool {
        v.currentBlocks().contains { if case .table = $0 { return true } else { return false } }
    }

    func test_sameCellMultiParagraphSelection_deleteMerges() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(cellA.globalStart + 2),
                                                DocumentTextPosition(cellA.globalStart + 2))
        v.insertText("\n")
        XCTAssertEqual(cellInfo(v, 0, 0)?.blocks, 2)
        let regions = v.allLeafRegions()
        let i = regions.firstIndex { $0.ref == .paragraph(BlockID("ap")) }!
        v.setSelectionForTesting(anchor: regions[i].globalStart + 1, head: regions[i + 1].globalStart + 1)
        v.deleteBackward()
        XCTAssertEqual(cellInfo(v, 0, 0)?.blocks, 1)
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Aha")
        XCTAssertTrue(hasTable(v))
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "Beta")
    }

    func test_sameCellSingleParagraphSelection_deleteClearsRange() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart + 1, head: cellA.globalStart + 4)
        v.deleteBackward()
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Aa")
    }

    func test_crossCellDelete_clearsTouchedCells_preservesGrid() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart + 2, head: cellB.globalStart + 2)   // after "Al" after "Be"
        v.deleteBackward()
        XCTAssertTrue(hasTable(v))
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Al")    // cell A prefix kept
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "ta")    // cell B suffix kept
        XCTAssertEqual(cellInfo(v, 0, 0)?.blocks, 1)          // every cell keeps ≥1 block
        XCTAssertEqual(cellInfo(v, 0, 1)?.blocks, 1)
        XCTAssertEqual(v.head, cellA.globalStart + 2)         // caret collapses to selFrom
        XCTAssertEqual(v.anchor, v.head)
    }

    func test_crossCellTypeOver_textInFirstRegionOnly() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart + 2, head: cellB.globalStart + 2)
        v.insertText("Z")
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "AlZ")   // text lands in the FIRST region
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "ta")    // later regions only clear
    }

    func test_cellToBodyDelete_preservesTable() {
        let v = canvas()                                       // [Top, table, Bot]
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let bot = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bot")) }!
        v.setSelectionForTesting(anchor: cellB.globalStart + 2, head: bot.globalStart + 1)   // in cell B, after "Be" in "Bot", after "B"
        v.deleteBackward()
        XCTAssertTrue(hasTable(v), "table survives a cell↔body selection delete")
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Alpha")  // cell A untouched
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "Be")     // cell B suffix cleared
        let botText = v.currentBlocks().compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.id == BlockID("bot") ? p.text : nil }; return nil
        }.first
        XCTAssertEqual(botText, "ot")                          // "B" cleared from "Bot"
    }

    func test_crossCellDelete_isSingleUndo() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart + 2, head: cellB.globalStart + 2)
        um.beginUndoGrouping()
        v.deleteBackward()
        um.endUndoGrouping()
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Al")
        um.undo()
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Alpha", "one undo restores the pre-edit document")
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "Beta")
    }

    func test_crossCellDelete_spanMathMatchesCore() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart + 2, head: cellB.globalStart + 2)
        v.deleteBackward()
        let doc = Document(blocks: v.currentBlocks())
        XCTAssertEqual(v.documentSizeValue, DocumentTree.documentSize(doc))
    }

    func test_cellToBodyDelete_isDragDirectionIndependent() {
        func run(swap: Bool) -> (Int, String, String) {
            let v = canvas()
            let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
            let bot = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bot")) }!
            let p = cellB.globalStart + 2, q = bot.globalStart + 1
            if swap { v.setSelectionForTesting(anchor: q, head: p) } else { v.setSelectionForTesting(anchor: p, head: q) }
            v.deleteBackward()
            let botText = v.currentBlocks().compactMap { b -> String? in
                if case .paragraph(let x) = b { return x.id == BlockID("bot") ? x.text : nil }; return nil
            }.first ?? ""
            return (v.head, cellInfo(v, 0, 1)?.firstText ?? "", botText)
        }
        let forward = run(swap: false)
        let backward = run(swap: true)
        XCTAssertEqual(forward.0, backward.0)
        XCTAssertEqual(forward.1, backward.1)
        XCTAssertEqual(forward.2, backward.2)
    }

    func test_crossCellDelete_keepsImageInCoveredCell() {
        let v = DocumentCanvasView()
        let imgCell = Cell(id: BlockID("c"), blocks: [
            .paragraph(ParagraphBlock(id: BlockID("cp"), runs: [TextRun(text: "Cap")])),
            .media(MediaBlock(id: BlockID("ci"), mediaID: "x", naturalSize: Size2D(width: 10, height: 10))),
        ])
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [imgCell, cell("d", "Beta")])])),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 700); v.layoutIfNeeded()
        let dCell = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("dp")) }!
        v.setSelectionForTesting(anchor: 1, head: dCell.globalStart + 2)
        v.deleteBackward()
        guard case .table(let model) = v.currentBlocks().first(where: { if case .table = $0 { return true } else { return false } })!
        else { return XCTFail() }
        let cellCKeepsImage = model.rows[0].cells[0].blocks.contains { if case .media = $0 { return true } else { return false } }
        XCTAssertTrue(cellCKeepsImage, "an image in a covered cell is preserved (only its caption text clears)")
    }

    // MARK: - Holistic-review fixes (Task 7)

    func emptyCell(_ id: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: []))])
    }
    /// A 1-row 2-column table whose two cells are EMPTY.
    func canvasEmptyCells() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [emptyCell("a"), emptyCell("b")])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 300); v.layoutIfNeeded()
        return v
    }
    /// A 2×2 table: (0,0)"Alpha"(ap) (0,1)"Beta"(bp) / (1,0)"Gamma"(cp) (1,1)"Delta"(dp).
    func canvas2x2() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")]),
                Row(id: BlockID("r1"), cells: [cell("c", "Gamma"), cell("d", "Delta")]),
            ]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }

    // Finding 1: type-over a selection spanning only EMPTY cells must land the char in selFrom's
    // cell and collapse the selection (was: keystroke dropped + selection stuck).
    func test_emptyCellsCrossSelection_typeOver_landsInFirstCell_andCollapses() {
        let v = canvasEmptyCells()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart, head: cellB.globalStart)
        XCTAssertNotEqual(v.anchor, v.head)        // a real cross-cell selection over empty regions
        v.insertText("X")
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "X")   // lands in selFrom's cell
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "")
        XCTAssertEqual(v.anchor, v.head, "selection collapses — not stuck")
    }

    // A selection covering the table's WHOLE content (here: both — i.e. every — cell of a 1×2 table), on
    // delete, REMOVES the table — resetting to a single empty body paragraph, exactly like Select-All →
    // Backspace. (Empty cells are covered too: a range ending at the last empty cell's start spans its
    // zero-length content.) Only an empty-text DELETE triggers this; type-over still lands the char in the
    // first cell (see `test_emptyCellsCrossSelection_typeOver_landsInFirstCell_andCollapses`).
    func test_emptyCellsCrossSelection_delete_removesTable() {
        let v = canvasEmptyCells()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart, head: cellB.globalStart)   // covers every cell of the table
        v.deleteBackward()
        v.layoutIfNeeded()
        XCTAssertEqual(v.anchor, v.head, "selection collapses to a caret")
        XCTAssertNil(v.boxes.first { $0 is TableBlockBox }, "deleting every cell removes the table")
        XCTAssertEqual(v.boxes.count, 1, "collapses to one empty paragraph")
        XCTAssertEqual(v.boxes[0].textLength, 0)
    }

    // Minor fix: when the FIRST covered region's start cell is empty, type-over lands in selFrom's
    // cell (not the later non-empty cell).
    func test_firstRegionEmpty_typeOver_landsInSelFromCell() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [emptyCell("a"), cell("b", "Beta")])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 300); v.layoutIfNeeded()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart, head: cellB.globalStart + 2)
        v.insertText("X")
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "X")    // text lands in selFrom's (empty) cell
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "ta")   // cell B prefix "Be" cleared
    }

    // Coverage: multi-row cross-cell clear preserves all rows/cells + matches Core span math.
    func test_multiRowCrossCell_delete_preservesAllRows() {
        let v = canvas2x2()
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!   // (0,0) "Alpha"
        let d = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("dp")) }!   // (1,1) "Delta"
        v.setSelectionForTesting(anchor: a.globalStart + 2, head: d.globalStart + 2)
        v.deleteBackward()
        XCTAssertTrue(hasTable(v))
        for loc in [(0, 0), (0, 1), (1, 0), (1, 1)] { XCTAssertEqual(cellInfo(v, loc.0, loc.1)?.blocks, 1) }
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Al")    // start prefix kept
        XCTAssertEqual(cellInfo(v, 1, 1)?.firstText, "lta")   // end suffix kept
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "")      // middle cleared
        XCTAssertEqual(cellInfo(v, 1, 0)?.firstText, "")      // middle cleared
        let doc = Document(blocks: v.currentBlocks())
        XCTAssertEqual(v.documentSizeValue, DocumentTree.documentSize(doc))
    }

    // Coverage: redo re-applies a cross-cell delete.
    func test_crossCellDelete_redoReapplies() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        um.beginUndoGrouping()
        v.setSelectionForTesting(anchor: cellA.globalStart + 2, head: cellB.globalStart + 2)
        v.deleteBackward()
        um.endUndoGrouping()
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Al")
        um.undo()
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Alpha")
        um.redo()
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Al")
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "ta")
    }

    // Coverage: Enter over a cross-cell selection clears the touched cells, then splits at the
    // collapsed caret in selFrom's cell — table survives.
    func test_enterOverCrossCellSelection_clearsAndSplits() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: cellA.globalStart + 2, head: cellB.globalStart + 2)
        v.insertText("\n")
        XCTAssertTrue(hasTable(v))
        XCTAssertEqual(cellInfo(v, 0, 0)?.blocks, 2)          // "Al" split into "Al" + ""
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Al")
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "ta")    // cell B suffix kept, not split
    }

    // Coverage: plain-text extraction across cells (the copy path).
    func test_textInRange_acrossCells_concatenates() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let range = DocumentTextRange(DocumentTextPosition(cellA.globalStart + 2),
                                      DocumentTextPosition(cellB.globalStart + 2))
        XCTAssertEqual(v.text(in: range), "phaBe")   // "pha" (cell A tail) + "Be" (cell B head)
    }

    // Finding 2: the replace(_:withText:) witness (autocorrect/dictation/marked-text) over a
    // cross-cell range must route structure-preservingly — not silently no-op via applyReplaceOutcome's guard.
    func test_replaceWitness_crossCellRange_clearsStructurePreserving() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let range = DocumentTextRange(DocumentTextPosition(cellA.globalStart + 2),
                                      DocumentTextPosition(cellB.globalStart + 2))
        v.replace(range, withText: "Z")
        XCTAssertTrue(hasTable(v))
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "AlZ")   // text lands in selFrom's cell
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "ta")    // cell B prefix cleared
    }
}
#endif

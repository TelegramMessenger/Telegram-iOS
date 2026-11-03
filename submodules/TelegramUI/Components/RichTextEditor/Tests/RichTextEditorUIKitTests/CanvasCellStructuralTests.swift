#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasCellStructuralTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])]))], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 400); v.layoutIfNeeded()
        return v
    }
    /// The TableBlockBox's cell at (row,col): its block-stack box count + first paragraph text.
    func cellInfo(_ v: DocumentCanvasView, _ row: Int, _ col: Int) -> (blocks: Int, firstText: String)? {
        guard let t = v.boxes.first as? TableBlockBox else { return nil }
        guard case .table(let model) = t.currentBlock() else { return nil }
        let cell = model.rows[row].cells[col]
        let texts = cell.blocks.compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
        return (cell.blocks.count, texts.first ?? "")
    }

    func test_enterInsideCell_splitsCellParagraph() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(cellA.globalStart + 2),
                                                DocumentTextPosition(cellA.globalStart + 2))  // after "Al"
        v.insertText("\n")
        // cell A now has 2 paragraphs: "Al" and "pha"; cell B untouched
        XCTAssertEqual(cellInfo(v, 0, 0)?.blocks, 2)
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Al")
        XCTAssertEqual(cellInfo(v, 0, 1)?.blocks, 1)
        XCTAssertEqual(cellInfo(v, 0, 1)?.firstText, "Beta")
    }

    func test_enterInCell_spanMathStillMatchesCore() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(cellA.globalStart + 2),
                                                DocumentTextPosition(cellA.globalStart + 2))
        v.insertText("\n")
        let doc = Document(blocks: v.currentBlocks())
        XCTAssertEqual(v.documentSizeValue, DocumentTree.documentSize(doc))
    }

    func test_backspaceAtCellSecondParagraphStart_mergesWithinCell() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        // First split "Alpha" → "Al" | "pha" (cell A has 2 paragraphs), caret at start of "pha".
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(cellA.globalStart + 2), DocumentTextPosition(cellA.globalStart + 2))
        v.insertText("\n")
        XCTAssertEqual(cellInfo(v, 0, 0)?.blocks, 2)
        // caret is at the start of "pha" (the new lower paragraph). Backspace merges → "Alpha" again.
        v.deleteBackward()
        XCTAssertEqual(cellInfo(v, 0, 0)?.blocks, 1)
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Alpha")
    }

    func test_backspaceAtCellFirstParagraphStart_isNoOp() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(cellA.globalStart), DocumentTextPosition(cellA.globalStart))
        v.deleteBackward()
        XCTAssertEqual(cellInfo(v, 0, 0)?.blocks, 1)
        XCTAssertEqual(cellInfo(v, 0, 0)?.firstText, "Alpha")   // unchanged (no cross-cell-wall merge)
    }
}
#endif

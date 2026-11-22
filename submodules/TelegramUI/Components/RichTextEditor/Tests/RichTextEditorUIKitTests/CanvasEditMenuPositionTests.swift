#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The system edit menu (`UIEditMenuInteraction`) positions itself AROUND the rect returned by
/// `editMenuInteraction(_:targetRectFor:)`. Without that hook the target rect defaults to a zero-size
/// rect at the source point, so the menu covers the selected word and the selection handles. These
/// tests pin `editMenuTargetRect()` — the pure geometry the delegate returns — for each present case.
@available(iOS 16.0, *)
final class CanvasEditMenuPositionTests: XCTestCase {
    private func paragraphCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello world")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func region(_ v: DocumentCanvasView, _ id: String) -> LeafTextRegion {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
    }
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }
    private func tableCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 300); v.layoutIfNeeded()
        return v
    }

    /// A range selection must yield a target rect that CONTAINS the whole selection union and is grown
    /// vertically by the handle allowance (so the menu clears the round drag-handle knobs), but NOT grown
    /// horizontally. This is the reported bug: the menu was covering the word and the handles.
    func test_targetRect_rangeSelection_coversUnion_andPadsForHandles() {
        let v = paragraphCanvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // "Hello"
        let union = v.selectionRects(globalFrom: v.selFrom, globalTo: v.selTo)
            .reduce(CGRect.null) { $0.union($1) }
        XCTAssertFalse(union.isNull, "precondition: the selection produces rects")

        let target = v.editMenuTargetRect()
        XCTAssertTrue(target.contains(union), "target must contain the full selection union (menu never covers the word)")
        XCTAssertEqual(target.minY, union.minY - DocumentCanvasView.selectionHandleAllowance, accuracy: 0.5)
        XCTAssertEqual(target.maxY, union.maxY + DocumentCanvasView.selectionHandleAllowance, accuracy: 0.5)
        XCTAssertEqual(target.minX, union.minX, accuracy: 0.5, "no horizontal padding")
        XCTAssertEqual(target.maxX, union.maxX, accuracy: 0.5, "no horizontal padding")
    }

    /// A multi-region selection's target rect is the UNION of every fragment (not just the first), so a
    /// Select-All / cross-cell selection is fully cleared. Mirrors the secondary fix to `presentEditMenu`.
    func test_targetRect_crossCellSelection_unionSpansBothCells() {
        let v = tableCanvas()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let rB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: rA.globalStart + 2, head: rB.globalStart + 2)
        let target = v.editMenuTargetRect()
        XCTAssertLessThan(target.minX, rB.canvasOrigin.x - 1, "target reaches into cell A")
        XCTAssertGreaterThan(target.maxX, rB.canvasOrigin.x - 1, "target continues into cell B")
    }

    /// A collapsed text caret anchors the menu at the thin caret bar, with no handle padding (a caret has
    /// no drag handles).
    func test_targetRect_collapsedCaret_isCaretRect_unpadded() {
        let v = paragraphCanvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 2, head: r.globalStart + 2)
        let caret = v.caretRect(for: DocumentTextPosition(v.head))
        XCTAssertFalse(caret.isEmpty, "precondition: caret has a rect")
        XCTAssertEqual(v.editMenuTargetRect(), caret)
    }

    /// A structural row/column selection anchors the menu around the selection OUTLINE (so the menu does
    /// not cover the row/column being edited), unpadded — the structural handles aren't text drag handles.
    func test_targetRect_columnSelection_isOutline() {
        let v = tableCanvas()
        let t = v.boxes[0] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 1)!, head: t.cellTextStart(row: 0, column: 1)!)   // caret in the table → activeTable resolves
        v.selectTableColumn(1)
        let outline = v.tableSelectionOutlineRect()
        XCTAssertNotNil(outline, "precondition: a column is structurally selected")
        XCTAssertEqual(v.editMenuTargetRect(), outline)
    }
}
#endif

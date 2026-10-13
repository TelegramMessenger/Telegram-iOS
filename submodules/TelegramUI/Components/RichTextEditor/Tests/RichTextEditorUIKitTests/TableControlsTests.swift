#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class TableControlsTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id+"p"), runs: [TextRun(text: t)]))])
    }
    /// 3-col × 2-row table (row 0 header) preceded by a paragraph, laid out at 390pt.
    func canvasWithTable() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("intro"), runs: [TextRun(text: "Intro")])),
            .table(TableBlock(id: BlockID("t"),
                columns: [ColumnSpec(width: 120), ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","Name"), cell("b","Mass"), cell("c","Dist")]),
                       Row(id: BlockID("r1"), cells: [cell("d","Sgr"), cell("e","4.3M"), cell("f","26kly")])])),
        ], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600); v.layoutIfNeeded()
        return v
    }
    func table(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes[1] as! TableBlockBox }

    func test_handles_forCaretRowAndColumn() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        let handles = v.tableHandles()
        XCTAssertEqual(handles.count, 2)
        let kinds = handles.map(\.kind)
        XCTAssertTrue(kinds.contains(.rows(1...1)))
        XCTAssertTrue(kinds.contains(.columns(1...1)))
        let rowH = handles.first { $0.kind == .rows(1...1) }!.rect
        XCTAssertLessThan(rowH.minX, CanvasMetrics.pageMargin)   // row handle anchored in the left gutter
    }

    func test_handles_emptyWhenCaretNotInTable() {
        let v = canvasWithTable()
        v.setSelectionForTesting(anchor: 0, head: 0)
        XCTAssertTrue(v.tableHandles().isEmpty)
    }

    // A stationary hold on a table's structural grip must NOT begin the loupe / move-cursor pickup — the grip TAP
    // selects the row/column instead. (Table grips join selection handles + resize knobs in the prohibited zone.)
    func test_cursorLongPress_prohibitedOnRowAndColumnGrips() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)   // collapsed caret in a cell → grips show
        let handles = v.tableHandles()
        let rowGrip = handles.first { $0.kind == .rows(1...1) }!.rect
        let colGrip = handles.first { $0.kind == .columns(1...1) }!.rect
        XCTAssertFalse(v.shouldBeginCursorLongPress(at: CGPoint(x: rowGrip.midX, y: rowGrip.midY)),
                       "a hold on the row grip does not pick up the cursor")
        XCTAssertFalse(v.shouldBeginCursorLongPress(at: CGPoint(x: colGrip.midX, y: colGrip.midY)),
                       "a hold on the column grip does not pick up the cursor")
        // Away from any grip (inside the cell), the pickup still proceeds.
        let cell = t.cellRect(row: 1, column: 1)!
        XCTAssertTrue(v.shouldBeginCursorLongPress(at: CGPoint(x: cell.midX, y: cell.midY)),
                      "a hold inside the cell still picks up the cursor")
    }

    func test_columnHandle_staysWithinTableFrame_soTrailingTableHandleIsntClipped() {
        let v = canvasWithTable()   // [paragraph, table] — the table is the LAST block
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        let colHandle = v.tableHandles().first { if case .columns = $0.kind { return true }; return false }!.rect
        // The table reserves space below its grid, so the ••• column handle's dots fall inside the
        // table's own frame. For a trailing table the canvas height == the table's bottom, so if the
        // handle sat below that frame it would be clipped off-screen and untappable.
        XCTAssertLessThanOrEqual(colHandle.midY, t.frame.maxY)
    }

    func test_selectColumn_setsStateAndLandsCaret() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(2)
        XCTAssertEqual(v.tableSelection?.kind, .columns(2...2))
        XCTAssertEqual(v.tableSelection?.table, BlockID("t"))
        XCTAssertEqual(v.head, t.cellTextStart(row: 0, column: 2))
    }

    func test_selectRow_setsStateAndLandsCaret() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 2)!, head: t.cellTextStart(row: 0, column: 2)!)   // caret in the table
        v.selectTableRow(1)
        XCTAssertEqual(v.tableSelection?.kind, .rows(1...1))
        XCTAssertEqual(v.tableSelection?.table, BlockID("t"))
        XCTAssertEqual(v.head, t.cellTextStart(row: 1, column: 0))        // lands in (1, 0)
    }

    func test_selectColumn_thenDelete_removesThatColumn() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(1)
        v.deleteTableColumn()
        guard case .table(let tb) = v.boxes[1].currentBlock() else { return XCTFail() }
        XCTAssertEqual(tb.columnCount, 2)
        XCTAssertEqual(tb.rows[0].cells.map { ($0.blocks.first.flatMap { if case .paragraph(let p) = $0 { return p.runs.first?.text } else { return nil } }) ?? "" },
                       ["Name", "Dist"])
    }

    func test_clear_resetsSelection() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableRow(1)
        XCTAssertNotNil(v.tableSelection)
        v.clearTableSelection()
        XCTAssertNil(v.tableSelection)
    }

    func test_caretHidden_whileStructurallySelected() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)   // caret in the table
        v.selectTableColumn(0)
        XCTAssertEqual(v.caretRect(for: DocumentTextPosition(v.head)), .zero)   // no caret while selected
        v.clearTableSelection()
        XCTAssertNotEqual(v.caretRect(for: DocumentTextPosition(v.head)), .zero) // caret returns
    }

    // MARK: - tableStructuralMenuRequest tests

    func actionKinds(_ req: TableStructuralMenuRequest?) -> [TableStructuralMenuRequest.Kind] {
        req?.actions.map { $0.kind } ?? []
    }

    func test_columnMenu_hasAddDeleteAlign() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(1)
        let req = v.tableStructuralMenuRequest()
        let kinds = actionKinds(req)
        XCTAssertEqual(kinds.filter { $0 == .addColumnLeft || $0 == .addColumnRight }.count, 2)
        XCTAssertTrue(kinds.contains(.deleteColumn))
        XCTAssertNotNil(req?.alignment)
    }

    func test_structuralMenuRequest_carriesHVAlignment_forColumnAndRow() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        v.selectTableColumn(1)
        let colReq = v.tableStructuralMenuRequest()
        XCTAssertNotNil(colReq?.alignment, "column selection carries alignment")
        colReq?.alignment?.apply(.right, .bottom)
        guard case .table(let afterCol) = v.boxes.first(where: { $0 is TableBlockBox })!.currentBlock() else { return XCTFail() }
        XCTAssertEqual(afterCol.rows[1].cells[1].horizontalAlignment, .right)
        XCTAssertEqual(afterCol.rows[1].cells[1].verticalAlignment, .bottom)

        v.selectTableRow(1)
        let rowReq = v.tableStructuralMenuRequest()
        XCTAssertNotNil(rowReq?.alignment, "row selection ALSO carries alignment now")
        // horizontal is uniform across the just-set row? cell (1,1) is .right, others .center → mixed → nil.
        XCTAssertNil(rowReq?.alignment?.horizontal, "mixed horizontal across the row reports nil")
    }

    func test_rowMenu_headerOmitsDeleteAndAddAbove() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableRow(0)                       // header row
        let kinds = actionKinds(v.tableStructuralMenuRequest())
        XCTAssertFalse(kinds.contains(.deleteRow))
        XCTAssertFalse(kinds.contains(.addRowAbove))
        XCTAssertTrue(kinds.contains(.addRowBelow))
    }

    func test_rowMenu_bodyHasAllRowActions() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableRow(1)
        let kinds = actionKinds(v.tableStructuralMenuRequest())
        XCTAssertTrue(kinds.contains(.addRowAbove) && kinds.contains(.addRowBelow) && kinds.contains(.deleteRow))
    }

    func test_columnMenu_singleColumnOmitsDelete() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 200)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","Only")]),
                   Row(id: BlockID("r1"), cells: [cell("b","x")])]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 400); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(0)
        XCTAssertFalse(actionKinds(v.tableStructuralMenuRequest()).contains(.deleteColumn))
    }

    // MARK: - Tap handle tests (Task 4)

    func test_tapColumnHandle_selectsColumn() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 2)!, head: t.cellTextStart(row: 1, column: 2)!)   // caret in (1,2) → handles for row1/col2
        let colHandle = v.tableHandles().first { $0.kind == .columns(2...2) }!.rect
        v.performSingleTap(at: CGPoint(x: colHandle.midX, y: colHandle.midY))
        XCTAssertEqual(v.tableSelection?.kind, .columns(2...2))
    }

    func test_tapRowHandle_selectsRow() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        let rowHandle = v.tableHandles().first { $0.kind == .rows(1...1) }!.rect
        v.performSingleTap(at: CGPoint(x: rowHandle.midX, y: rowHandle.midY))
        XCTAssertEqual(v.tableSelection?.kind, .rows(1...1))
    }

    func test_tapSelectedColumnHandle_firesStructuralMenuRequest() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 2)!, head: t.cellTextStart(row: 1, column: 2)!)
        v.selectTableColumn(2)                                   // 1st: select column 2
        var received: TableStructuralMenuRequest?
        v.onRequestTableStructuralMenu = { received = $0 }
        let colHandle = v.tableHandles().first { $0.kind == .columns(2...2) }!.rect
        v.performSingleTap(at: CGPoint(x: colHandle.midX, y: colHandle.midY))   // 2nd: tap selected handle → menu
        XCTAssertNotNil(received)
        XCTAssertTrue(received?.view === v)
        XCTAssertEqual(received?.sourceRect, colHandle)
        XCTAssertTrue((received?.actions.map { $0.kind } ?? []).contains(.deleteColumn))
    }

    // A table resize-KNOB drag that extends a row/column STRUCTURAL selection must, on release, ask the host
    // to present the structural menu — NOT the system edit menu (`editMenuInteraction(_:menuFor:)` no longer
    // has a `tableSelection` branch, so falling through to `presentEditMenu()` shows the wrong menu).
    func test_knobDragEnd_firesStructuralMenuRequest_notSystemMenu() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        v.selectTableColumn(1)                                   // active structural selection (as after a knob extend)
        var received: TableStructuralMenuRequest?
        v.onRequestTableStructuralMenu = { received = $0 }
        v.presentMenuAfterSelectionDrag(tableKnob: true)        // the drag-end decision, knob case
        XCTAssertNotNil(received)
        XCTAssertTrue((received?.actions.map { $0.kind } ?? []).contains(.addColumnLeft))
    }

    func test_toggleTableCompact_flipsModelAndState_inOneUndoStep() {
        let v = canvasWithTable()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        XCTAssertFalse(v.currentState().isTableCompact)

        let before = v.undoRegistrationCount
        um.beginUndoGrouping(); v.toggleTableCompact(); um.endUndoGrouping()
        XCTAssertEqual(v.undoRegistrationCount - before, 1, "the toggle registers exactly one undo step")

        guard case .table(let out) = v.currentBlocks()[1] else { return XCTFail("expected a table") }
        XCTAssertTrue(out.compact, "the model flipped")
        XCTAssertTrue(v.currentState().isTableCompact, "EditorState agrees with the model")

        um.undo()
        guard case .table(let back) = v.currentBlocks()[1] else { return XCTFail("expected a table") }
        XCTAssertFalse(back.compact)
        XCTAssertFalse(v.currentState().isTableCompact)
    }

    // MARK: - Draw helpers (Task 5)

    func test_selectionOutlineRect_wrapsColumn() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(1)
        let rect = v.tableSelectionOutlineRect()!
        let top = t.cellRect(row: 0, column: 1)!, bot = t.cellRect(row: 1, column: 1)!
        XCTAssertEqual(rect.minY, top.minY - TableBlockBox.border, accuracy: 0.5)   // flush with the table border
        XCTAssertEqual(rect.maxY, bot.maxY + TableBlockBox.border, accuracy: 0.5)
        XCTAssertEqual(rect.midX, top.midX, accuracy: 0.5)
    }

    func test_selectionOutlineRect_nilWhenNoSelection() {
        let v = canvasWithTable()
        XCTAssertNil(v.tableSelectionOutlineRect())
    }

    func test_tableControls_renderNonBlank() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        v.selectTableColumn(1)
        let img = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in v.drawHierarchy(in: v.bounds, afterScreenUpdates: true) }
        XCTAssertNotNil(img.cgImage)
    }

    func test_setCaret_clearsStructuralSelection() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(1)
        XCTAssertNotNil(v.tableSelection)
        v.setCaret(global: v.boxes[0].textStart)   // move the caret into the intro paragraph
        XCTAssertNil(v.tableSelection)
    }

    func test_insertText_clearsStructuralSelection() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(1)
        v.insertText("x")
        XCTAssertNil(v.tableSelection)
    }

    func test_tapOutsideTable_clearsStructuralSelection() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(1)
        XCTAssertNotNil(v.tableSelection)
        // tap in the intro paragraph (top of the canvas, well above the table)
        v.performSingleTap(at: CGPoint(x: 100, y: v.boxes[0].frame.midY))
        XCTAssertNil(v.tableSelection)
    }

    func test_arrowKeyCaretMove_clearsStructuralSelection() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(1)
        XCTAssertNotNil(v.tableSelection)
        // simulate a system caret commit (e.g. arrow key) via the UITextInput selectedTextRange setter
        let pos = v.head + 1
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
        XCTAssertNil(v.tableSelection)
        XCTAssertNotEqual(v.caretRect(for: DocumentTextPosition(v.head)), .zero)  // caret visible again
    }

    func test_tapSelectedHandle_opensMenu() {
        let v = canvasWithTable()
        let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        let h = v.tableHandles().first { $0.kind == .columns(1...1) }!.rect
        let p = CGPoint(x: h.midX, y: h.midY)
        XCTAssertEqual(v.tableHandleTap(at: p), .select(.columns(1...1)))   // not selected → first tap selects
        v.performSingleTap(at: p)
        XCTAssertEqual(v.tableSelection?.kind, .columns(1...1))
        XCTAssertEqual(v.tableHandleTap(at: p), .menu)                 // already selected → next tap opens the menu
    }

    // MARK: - point → row/column index (Task 3)

    func test_rowIndex_mapsYToRow() {
        let t = table(canvasWithTable())
        for r in 0..<t.rowCount {
            let mid = t.cellRect(row: r, column: 0)!.midY
            XCTAssertEqual(t.rowIndex(atY: mid), r)
        }
    }

    func test_columnIndex_mapsXToColumn() {
        let t = table(canvasWithTable())
        for c in 0..<t.columnCount {
            let mid = t.cellRect(row: 0, column: c)!.midX
            XCTAssertEqual(t.columnIndex(atX: mid), c)
        }
    }

    func test_rowIndex_clampsAboveAndBelow() {
        let t = table(canvasWithTable())
        XCTAssertEqual(t.rowIndex(atY: -9999), 0)
        XCTAssertEqual(t.rowIndex(atY: 9999), t.rowCount - 1)
    }

    func test_columnIndex_clampsLeftAndRight() {
        let t = table(canvasWithTable())
        XCTAssertEqual(t.columnIndex(atX: -9999), 0)
        XCTAssertEqual(t.columnIndex(atX: 9999), t.columnCount - 1)
    }

    func test_rowIndex_borderResolvesToRowAbove() {
        let t = table(canvasWithTable())
        let r0 = t.cellRect(row: 0, column: 0)!
        XCTAssertEqual(t.rowIndex(atY: r0.maxY), 0)                              // on the border → row above
        XCTAssertEqual(t.rowIndex(atY: r0.maxY + TableBlockBox.border / 2), 1)   // lower half → row below
    }

    // MARK: Selection-outline corners follow the table's outer corners (Task 6d follow-up)

    func test_outlineCorners_firstColumn_roundsTopLeftOnly() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableColumn(0)
        // column handle is at the bottom → bottom corners square; only the top-left table corner rounds
        let c = v.tableSelectionOutlineCorners()
        XCTAssertTrue(c.contains(.topLeft))
        XCTAssertFalse(c.contains(.bottomLeft) || c.contains(.topRight) || c.contains(.bottomRight))
    }
    func test_outlineCorners_middleColumn_square() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 1)!, head: t.cellTextStart(row: 0, column: 1)!)
        v.selectTableColumn(1)                                   // 3-column table → col 1 is interior
        XCTAssertTrue(v.tableSelectionOutlineCorners().isEmpty)
    }
    func test_outlineCorners_lastColumn_roundsTopRightOnly() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 2)!, head: t.cellTextStart(row: 0, column: 2)!)
        v.selectTableColumn(2)
        let c = v.tableSelectionOutlineCorners()
        XCTAssertTrue(c.contains(.topRight))
        XCTAssertFalse(c.contains(.bottomRight) || c.contains(.topLeft) || c.contains(.bottomLeft))
    }
    func test_outlineCorners_headerRow_roundsTopRightOnly() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableRow(0)                                      // header (first) row
        // row handle is at the left → left corners square; only the top-right table corner rounds
        let c = v.tableSelectionOutlineCorners()
        XCTAssertTrue(c.contains(.topRight))
        XCTAssertFalse(c.contains(.topLeft) || c.contains(.bottomLeft) || c.contains(.bottomRight))
    }
    func test_outlineCorners_lastRow_roundsBottomRightOnly() {
        let v = canvasWithTable(); let t = table(v)
        let last = t.rowCount - 1
        v.setSelectionForTesting(anchor: t.cellTextStart(row: last, column: 0)!, head: t.cellTextStart(row: last, column: 0)!)
        v.selectTableRow(last)
        let c = v.tableSelectionOutlineCorners()
        XCTAssertTrue(c.contains(.bottomRight))
        XCTAssertFalse(c.contains(.bottomLeft) || c.contains(.topLeft) || c.contains(.topRight))
    }

    // MARK: - resize knobs (Task 4)

    func test_resizeKnobs_emptyWhenNoStructuralSelection() {
        XCTAssertTrue(canvasWithTable().tableResizeKnobs().isEmpty)
    }

    func test_resizeKnobs_columnSelection_atLeftAndRightEdges() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 1)!, head: t.cellTextStart(row: 0, column: 1)!)
        v.selectTableColumn(1)
        let knobs = v.tableResizeKnobs()
        XCTAssertEqual(knobs.count, 2)
        // Knobs center on the outline STROKE's centerline (the raw rect inset by half the line width).
        let inset = DocumentCanvasView.selectionOutlineWidth / 2
        let outline = v.tableSelectionOutlineRect()!.insetBy(dx: inset, dy: inset)
        let lower = knobs.first { $0.end == .lower }!.rect
        let upper = knobs.first { $0.end == .upper }!.rect
        XCTAssertEqual(lower.midX, outline.minX, accuracy: 0.5)   // left edge (on the stroke line)
        XCTAssertEqual(upper.midX, outline.maxX, accuracy: 0.5)   // right edge
        XCTAssertEqual(lower.midY, outline.midY, accuracy: 0.5)
    }

    func test_resizeKnobs_rowSelection_atTopAndBottomEdges() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableRow(1)
        let knobs = v.tableResizeKnobs()
        let inset = DocumentCanvasView.selectionOutlineWidth / 2
        let outline = v.tableSelectionOutlineRect()!.insetBy(dx: inset, dy: inset)
        XCTAssertEqual(knobs.first { $0.end == .lower }!.rect.midY, outline.minY, accuracy: 0.5)   // top (on the stroke line)
        XCTAssertEqual(knobs.first { $0.end == .upper }!.rect.midY, outline.maxY, accuracy: 0.5)   // bottom
    }

    func test_resizeKnobs_multiColumnRange_spansRangeEnds() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableColumns(0...1)
        let knobs = v.tableResizeKnobs()
        let inset = DocumentCanvasView.selectionOutlineWidth / 2
        let outline = v.tableSelectionOutlineRect()!.insetBy(dx: inset, dy: inset)
        let lower = knobs.first { $0.end == .lower }!.rect
        let upper = knobs.first { $0.end == .upper }!.rect
        // lower knob at the left edge of col 0; upper at the right edge of col 1 (range ends, not one cell) —
        // each on the stroke centerline, i.e. the cell-range edge pulled in by the half-line-width inset.
        XCTAssertEqual(lower.midX, t.cellRect(row: 0, column: 0)!.minX - TableBlockBox.border + inset, accuracy: 0.5)
        XCTAssertEqual(upper.midX, t.cellRect(row: 0, column: 1)!.maxX + TableBlockBox.border - inset, accuracy: 0.5)
        XCTAssertEqual(lower.midX, outline.minX, accuracy: 0.5)
        XCTAssertEqual(upper.midX, outline.maxX, accuracy: 0.5)
    }

    func test_resizeKnobAt_hitsTheKnob() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 1)!, head: t.cellTextStart(row: 0, column: 1)!)
        v.selectTableColumn(1)
        let upper = v.tableResizeKnobs().first { $0.end == .upper }!.rect
        XCTAssertEqual(v.tableResizeKnob(at: CGPoint(x: upper.midX, y: upper.midY)), .upper)
        XCTAssertNil(v.tableResizeKnob(at: CGPoint(x: upper.midX + 500, y: upper.midY)))
    }

    // MARK: - range commands + menu (Task 6)

    private func rowTexts(_ tb: TableBlock, _ r: Int) -> [String] {
        tb.rows[r].cells.map { ($0.blocks.first.flatMap { if case .paragraph(let p) = $0 { return p.runs.first?.text } else { return nil } }) ?? "" }
    }

    func test_deleteColumns_range_removesAllSelected() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableColumns(0...1)                       // a 2-column range of the 3-column table
        v.deleteTableColumn()
        guard case .table(let tb) = v.boxes[1].currentBlock() else { return XCTFail() }
        XCTAssertEqual(tb.columnCount, 1)
        XCTAssertEqual(rowTexts(tb, 0), ["Dist"])          // only the un-selected column survives
    }

    func test_deleteRows_range_skipsHeader() {
        // 3-row table: header + 2 body rows; select rows 0...2 (incl header) and delete.
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","H0"), cell("b","H1")]),
                   Row(id: BlockID("r1"), cells: [cell("c","A0"), cell("d","A1")]),
                   Row(id: BlockID("r2"), cells: [cell("e","B0"), cell("f","B1")])]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableRows(0...2)
        v.deleteTableRow()
        guard case .table(let tb) = v.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertEqual(tb.rowCount, 1)
        XCTAssertTrue(tb.rows[0].isHeader)
        XCTAssertEqual(rowTexts(tb, 0), ["H0", "H1"], "header survives; both body rows removed")
    }

    func test_addColumnRight_range_insertsAfterUpperBound() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableColumns(0...1)
        v.insertTableColumnRight()
        guard case .table(let tb) = v.boxes[1].currentBlock() else { return XCTFail() }
        XCTAssertEqual(tb.columnCount, 4)
        XCTAssertEqual(rowTexts(tb, 0), ["Name", "Mass", "", "Dist"], "new empty column inserted at index 2")
    }

    func test_alignRight_range_setsEverySelectedColumn() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableColumns(0...1)
        v.setSelectionHorizontalAlignment(.right)
        guard case .table(let tb) = v.boxes[1].currentBlock() else { return XCTFail() }
        XCTAssertEqual(tb.rows[0].cells[0].horizontalAlignment, .right)
        XCTAssertEqual(tb.rows[1].cells[0].horizontalAlignment, .right)
        XCTAssertEqual(tb.rows[0].cells[1].horizontalAlignment, .right)
        XCTAssertEqual(tb.rows[1].cells[1].horizontalAlignment, .right)
        XCTAssertEqual(tb.rows[0].cells[2].horizontalAlignment, .center, "the un-selected column is untouched")
        XCTAssertEqual(tb.rows[1].cells[2].horizontalAlignment, .center, "the un-selected column is untouched")
    }

    func test_menu_hidesDeleteWhenAllColumns() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableColumns(0...1)                                   // multi-column, not all → delete shown
        XCTAssertTrue(actionKinds(v.tableStructuralMenuRequest()).contains(.deleteColumn))
        v.selectTableColumns(0...2)                                   // all 3 columns → no delete
        XCTAssertFalse(actionKinds(v.tableStructuralMenuRequest()).contains(.deleteColumn))
    }

    func test_menu_rowRangeIncludingHeader_hidesAddAbove_keepsDeleteRows() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableRows(0...1)                                       // header + body row
        let kinds = actionKinds(v.tableStructuralMenuRequest())
        XCTAssertFalse(kinds.contains(.addRowAbove))                  // range includes the header
        XCTAssertTrue(kinds.contains(.deleteRow))                     // body row(s) deletable → shown
    }

    // MARK: - drag to extend (Task 5)

    func test_extendColumns_growsRightThenClampsAtLastColumn() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableColumn(0)
        // drag the upper (right) knob toward column 1, then far right
        v.extendTableSelection(end: .upper, toward: CGPoint(x: t.cellRect(row: 0, column: 1)!.midX, y: 0))
        XCTAssertEqual(v.tableSelection?.kind, .columns(0...1))
        v.extendTableSelection(end: .upper, toward: CGPoint(x: 9999, y: 0))
        XCTAssertEqual(v.tableSelection?.kind, .columns(0...2))   // clamped to the last column
    }

    func test_extendColumns_upperKnobCannotCrossLowerBound() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 1)!, head: t.cellTextStart(row: 0, column: 1)!)
        v.selectTableColumn(1)
        // drag the upper knob far LEFT — it must not pass the fixed lower bound (col 1); min width 1
        v.extendTableSelection(end: .upper, toward: CGPoint(x: -9999, y: 0))
        XCTAssertEqual(v.tableSelection?.kind, .columns(1...1))
    }

    func test_extendColumns_lowerKnobMovesLeft() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 2)!, head: t.cellTextStart(row: 0, column: 2)!)
        v.selectTableColumn(2)
        v.extendTableSelection(end: .lower, toward: CGPoint(x: t.cellRect(row: 0, column: 0)!.midX, y: 0))
        XCTAssertEqual(v.tableSelection?.kind, .columns(0...2))
    }

    func test_extendRows_growsDown() {
        let v = canvasWithTable(); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableRow(0)
        v.extendTableSelection(end: .upper, toward: CGPoint(x: 0, y: t.cellRect(row: 1, column: 0)!.midY))
        XCTAssertEqual(v.tableSelection?.kind, .rows(0...1))
    }

    // MARK: - extend under scroll (Task 4 review)

    func test_extendColumns_underScroll_convertsVisibleTouchX() {
        func wcell(_ id: String, _ s: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: s)]))])
        }
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: (0..<6).map { wcell("h\($0)", "H\($0)") }),
                   Row(id: BlockID("r1"), cells: (0..<6).map { wcell("c\($0)", "C\($0)") })]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        // Place the caret in the table so activeTable() resolves before calling selectTableColumns.
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 4)!, head: t.cellTextStart(row: 0, column: 4)!)
        v.selectTableColumns(0...0)
        t.contentOffsetX = 150
        // Drag the upper knob toward column 3, addressed by its VISIBLE canvas x (unscrolled midX − offset).
        let visibleX = t.cellRect(row: 0, column: 3)!.midX - 150
        v.extendTableSelection(end: .upper, toward: CGPoint(x: visibleX, y: 0))
        XCTAssertEqual(v.structuralColumnRange(), 0...3, "column hit-test converts the visible touch x back to grid space")
    }

    // MARK: - chrome tracks contentOffsetX (Task 4)

    func test_chrome_outlineTracksContentOffset() {
        func wcell(_ id: String, _ s: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: s)]))])
        }
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: (0..<6).map { wcell("h\($0)", "H\($0)") }),
                   Row(id: BlockID("r1"), cells: (0..<6).map { wcell("c\($0)", "C\($0)") })]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        // Place the caret in the table so activeTable() resolves before calling selectTableColumns.
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 4)!, head: t.cellTextStart(row: 0, column: 4)!)
        v.selectTableColumns(4...4)
        let unscrolled = v.tableSelectionOutlineRect()!
        t.contentOffsetX = 150
        let scrolled = v.tableSelectionOutlineRect()!
        XCTAssertEqual(scrolled.minX, unscrolled.minX - 150, accuracy: 0.5, "outline tracks the scroll offset")
        let knob = v.tableResizeKnobs().first(where: { $0.end == .upper })!
        XCTAssertEqual(v.tableResizeKnob(at: CGPoint(x: knob.rect.midX, y: knob.rect.midY)), .upper)
    }

    func test_selectTableRow_notifiesInputDelegate_soArrowNavStartsFromCell() {
        // Structurally selecting a row parks the caret in its first cell. Like selectImage, the OS only
        // re-reads selectedTextRange after the input delegate is notified — without selectionDidChange it
        // keeps the STALE prior caret, so a hardware Arrow navigates from the old cell, not the selected row.
        let v = canvasWithTable(); let t = table(v)
        v.setCaret(global: t.cellTextStart(row: 0, column: 0)!)   // caret in a DIFFERENT cell first
        let spy = InputDelegateSpy(); v.inputDelegate = spy
        v.selectTableRow(1)
        XCTAssertGreaterThanOrEqual(spy.selectionDidChangeCount, 1,
            "selectTableRows must notify the input delegate so the OS re-reads selectedTextRange")
        let range = v.selectedTextRange as? DocumentTextRange
        XCTAssertEqual(range?.to.offset, t.cellTextStart(row: 1, column: 0),
                       "the synced OS selection sits in the selected row's first cell")
    }

    func test_selectTableColumn_notifiesInputDelegate_soArrowNavStartsFromCell() {
        let v = canvasWithTable(); let t = table(v)
        v.setCaret(global: t.cellTextStart(row: 0, column: 0)!)   // caret in a DIFFERENT cell first
        let spy = InputDelegateSpy(); v.inputDelegate = spy
        v.selectTableColumn(2)
        XCTAssertGreaterThanOrEqual(spy.selectionDidChangeCount, 1,
            "selectTableColumns must notify the input delegate so the OS re-reads selectedTextRange")
        let range = v.selectedTextRange as? DocumentTextRange
        XCTAssertEqual(range?.to.offset, t.cellTextStart(row: 0, column: 2),
                       "the synced OS selection sits in the selected column's first cell")
    }

    // MARK: - structural menu header descriptor (Task 5)

    func test_structuralMenu_carriesHeaderDescriptor_reflectingMixedState() {
        func cell(_ id: String) -> Cell { Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p")))]) }
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a"), cell("b")]),
                   Row(id: BlockID("r1"), cells: [cell("c"), cell("d")])]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 400); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableColumn(0)   // column 0: r0 header, r1 body → mixed
        let req = v.tableStructuralMenuRequest()
        XCTAssertNotNil(req?.header)
        XCTAssertNil(req?.header?.isHeader, "mixed selection reports nil (indeterminate)")
        // Applying flips the mixed column ON.
        req?.header?.apply()
        guard case .table(let out) = v.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertTrue(out.rows[0].cells[0].isHeader && out.rows[1].cells[0].isHeader)
    }
}
#endif

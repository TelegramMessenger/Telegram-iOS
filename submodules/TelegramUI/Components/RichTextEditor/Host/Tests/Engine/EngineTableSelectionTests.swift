import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-tables rung B — the structural selection axis: a selection that is not a text selection.
///
/// The caret PARKS in the range's first cell so the structural commands resolve to it, and selecting
/// deliberately fires no `onChange` — legacy records that publishing here invents a host selection
/// report on every row tap.
@available(iOS 18.4, *)
final class EngineTableSelectionTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    /// A 2x2 table whose cells read "a" "b" / "c" "d".
    private func table(_ id: String = "t") -> Block {
        var built = TableBlock.empty(rows: 2, columns: 2)
        built.id = BlockID(id)
        let texts = [["a", "b"], ["c", "d"]]
        for r in 0..<2 {
            for c in 0..<2 {
                built.rows[r].cells[c].blocks = [para("\(id)-\(r)\(c)", texts[r][c])]
            }
        }
        return .table(built)
    }

    private func cellCoordinatesAtCaret() -> (row: Int, column: Int)? {
        guard let index = editor.roleIndex(atFlatOffset: editor.engineSelectedRange.location) else { return nil }
        return editor.currentRoles[index].tableCellCoordinates
    }

    // MARK: The axis

    func test_selectingARowParksTheCaretInItsFirstCell() {
        editor.document = Document(blocks: [table()])
        editor.selectTableRows(1...1)
        XCTAssertEqual(editor.structuralRowRange(), 1...1)
        XCTAssertEqual(cellCoordinatesAtCaret()?.row, 1)
        XCTAssertEqual(cellCoordinatesAtCaret()?.column, 0)
    }

    func test_selectingAColumnParksTheCaretInItsFirstCell() {
        editor.document = Document(blocks: [table()])
        editor.selectTableColumns(1...1)
        XCTAssertEqual(editor.structuralColumnRange(), 1...1)
        XCTAssertEqual(cellCoordinatesAtCaret()?.row, 0)
        XCTAssertEqual(cellCoordinatesAtCaret()?.column, 1)
    }

    func test_selectingFiresNoChangeNotification() {
        editor.document = Document(blocks: [table()])
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.selectTableRows(0...0)
        XCTAssertEqual(changes, 0, "publishing here would invent a host selection report per row tap")
    }

    /// A rect that merely bisects a merged cell is grown to cover it, so no consumer is ever handed a
    /// selection that half-covers an anchor.
    func test_aCellRectThatBisectsAMergedCellIsStoredExpanded() {
        var built = TableBlock.empty(rows: 2, columns: 2)
        built.id = BlockID("t")
        built.rows[0].cells[0].colspan = 2
        built.rows[0].cells.remove(at: 1)
        editor.document = Document(blocks: [.table(built)])
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))
        XCTAssertEqual(editor.structuralCellRect(), TableRect(top: 0, left: 0, bottom: 0, right: 1))
    }

    // MARK: Clearing — ONE guarded site

    func test_aCaretMoveClearsTheSelection() {
        editor.document = Document(blocks: [para("p", "before"), table()])
        editor.selectTableRows(0...0)
        XCTAssertNotNil(editor.structuralRowRange())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        XCTAssertNil(editor.structuralRowRange(), "a caret move by any other route clears it")
    }

    func test_aTextEditClearsTheSelection() {
        editor.document = Document(blocks: [table()])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.selectTableRows(0...0)
        editor.engine.insertText("x")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertNil(editor.structuralRowRange())
    }

    func test_aDocumentSetClearsTheSelection() {
        editor.document = Document(blocks: [table()])
        editor.selectTableRows(0...0)
        editor.document = Document(blocks: [para("p", "fresh")])
        XCTAssertNil(editor.structuralRowRange())
    }

    // MARK: The focus chrome, and the covered cells

    /// With nothing committed, the caret's OWN cell is what the outline and the four corner knobs
    /// surround — which is what makes the corner drag discoverable.
    func test_theFocusedCellIsTheCaretsOwnCellWhenNothingIsCommitted() {
        editor.document = Document(blocks: [table()])
        guard let last = editor.currentRoles.lastIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("no cells")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: last), length: 0)
        XCTAssertEqual(editor.focusedOrSelectedCellRect(), TableRect(top: 1, left: 1, bottom: 1, right: 1))
    }

    func test_theCoveredCellRangesAreOneRangePerCell() {
        editor.document = Document(blocks: [table()])
        editor.selectTableRows(0...0)
        XCTAssertEqual(editor.structuralSelectionCellRanges().count, 2, "row 0 has two cells")
        editor.selectTableColumns(0...0)
        XCTAssertEqual(editor.structuralSelectionCellRanges().count, 2, "column 0 has two cells")
    }

    // MARK: Knob drag — row and column ranges

    /// A table-local y that lands in `row`, read from the grid the view actually solved.
    private func yInRow(_ row: Int) -> CGFloat {
        guard let grid = editor.tableGrids[BlockID("t")] else { return 0 }
        let border = grid.borderWidth
        let top = border + grid.rowHeights[0 ..< row].reduce(0, +) + CGFloat(row) * border
        return top + grid.rowHeights[row] / 2
    }

    private func xInColumn(_ column: Int) -> CGFloat {
        guard let grid = editor.tableGrids[BlockID("t")] else { return 0 }
        let border = grid.borderWidth
        let left = border + grid.columnWidths[0 ..< column].reduce(0, +) + CGFloat(column) * border
        return left + grid.columnWidths[column] / 2
    }

    func test_draggingTheUpperRowKnobGrowsTheRange() {
        editor.document = Document(blocks: [table()])
        window.layoutIfNeeded()
        editor.selectTableRows(0...0)
        editor.extendTableSelection(end: .upper, towardTableLocal: CGPoint(x: 10, y: yInRow(1)))
        XCTAssertEqual(editor.structuralRowRange(), 0...1)
    }

    /// The dragged end cannot cross the fixed one: the range floors at width 1 and never swaps.
    func test_theDraggedEndCannotCrossTheFixedOne() {
        editor.document = Document(blocks: [table()])
        window.layoutIfNeeded()
        editor.selectTableRows(1...1)
        editor.extendTableSelection(end: .lower, towardTableLocal: CGPoint(x: 10, y: yInRow(0)))
        XCTAssertEqual(editor.structuralRowRange(), 0...1)
        // Now pull the UPPER end above the lower one — it must stop at the lower bound.
        editor.extendTableSelection(end: .upper, towardTableLocal: CGPoint(x: 10, y: -500))
        XCTAssertEqual(editor.structuralRowRange(), 0...0)
    }

    func test_draggingPastTheLastRowClampsToTheGrid() {
        editor.document = Document(blocks: [table()])
        window.layoutIfNeeded()
        editor.selectTableRows(0...0)
        editor.extendTableSelection(end: .upper, towardTableLocal: CGPoint(x: 10, y: 10_000))
        XCTAssertEqual(editor.structuralRowRange(), 0...1, "a 2-row table has no row 2")
    }

    func test_draggingAColumnKnobGrowsTheColumnRange() {
        editor.document = Document(blocks: [table()])
        window.layoutIfNeeded()
        editor.selectTableColumns(0...0)
        editor.extendTableSelection(end: .upper, towardTableLocal: CGPoint(x: xInColumn(1), y: 10))
        XCTAssertEqual(editor.structuralColumnRange(), 0...1)
    }

    func test_draggingDoesNotFireChangeNotifications() {
        editor.document = Document(blocks: [table()])
        window.layoutIfNeeded()
        editor.selectTableRows(0...0)
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.extendTableSelection(end: .upper, towardTableLocal: CGPoint(x: 10, y: yInRow(1)))
        XCTAssertEqual(changes, 0, "a live drag reports many transient ranges; none is a content change")
    }

    // MARK: Knob drag — cell rects

    /// The drag's whole point: with nothing committed there is still an outline (the focus chrome), and
    /// dragging one of its corners PROMOTES it to a real selection on the very first update.
    func test_aCornerDragPromotesTheFocusChromeToACommittedSelection() {
        editor.document = Document(blocks: [table()])
        window.layoutIfNeeded()
        guard let first = editor.currentRoles.firstIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("no cells")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: first), length: 0)
        XCTAssertNil(editor.structuralCellRect(), "precondition: nothing is committed")
        editor.extendCellSelection(corner: .topLeft,
                                   towardTableLocal: CGPoint(x: xInColumn(1), y: yInRow(1)))
        XCTAssertEqual(editor.structuralCellRect(), TableRect(top: 0, left: 0, bottom: 1, right: 1))
    }

    /// The FIXED corner is the current rect's OPPOSITE corner, so dragging back shrinks the rect.
    func test_theFixedCornerIsTheOppositeOne() {
        editor.document = Document(blocks: [table()])
        window.layoutIfNeeded()
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))
        editor.extendCellSelection(corner: .topLeft,
                                   towardTableLocal: CGPoint(x: xInColumn(1), y: yInRow(1)))
        XCTAssertEqual(editor.structuralCellRect(), TableRect(top: 0, left: 0, bottom: 1, right: 1))
        editor.extendCellSelection(corner: .bottomRight,
                                   towardTableLocal: CGPoint(x: xInColumn(0), y: yInRow(0)))
        XCTAssertEqual(editor.structuralCellRect(), TableRect(top: 0, left: 0, bottom: 0, right: 0))
    }

    func test_aCornerDragIsClampedToTheGrid() {
        editor.document = Document(blocks: [table()])
        window.layoutIfNeeded()
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))
        editor.extendCellSelection(corner: .topLeft, towardTableLocal: CGPoint(x: 10_000, y: 10_000))
        XCTAssertEqual(editor.structuralCellRect(), TableRect(top: 0, left: 0, bottom: 1, right: 1))
    }

    /// A drag that lands on a merged cell stores the EXPANDED rect, like every other write.
    func test_aCornerDragAcrossAMergedCellStoresTheExpandedRect() {
        var built = TableBlock.empty(rows: 2, columns: 2)
        built.id = BlockID("t")
        built.rows[1].cells[0].colspan = 2
        built.rows[1].cells.remove(at: 1)
        for c in 0..<2 { built.rows[0].cells[c].blocks = [para("c\(c)", "x")] }
        built.rows[1].cells[0].blocks = [para("merged", "m")]
        editor.document = Document(blocks: [.table(built)])
        window.layoutIfNeeded()
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))
        editor.extendCellSelection(corner: .topLeft, towardTableLocal: CGPoint(x: xInColumn(0), y: yInRow(1)))
        XCTAssertEqual(editor.structuralCellRect(), TableRect(top: 0, left: 0, bottom: 1, right: 1),
                       "the merged bottom row pulls the rect out to both columns")
    }

    // MARK: Backspace before a table

    func test_backspaceAtAnEmptyParagraphAfterATableRemovesItAndSelectsTheTable() {
        editor.document = Document(blocks: [table(), para("p", "")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        guard let after = editor.currentRoles.firstIndex(where: { $0.containerID == BlockID("p") }) else {
            return XCTFail("no paragraph role")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: after), length: 0)
        editor.engine.deleteBackward()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(editor.document.blocks.count, 1, "the empty trailing paragraph is gone")
        XCTAssertEqual(editor.structuralRowRange(), 0...1, "and the whole table is selected")
    }

    func test_backspaceAtANonEmptyParagraphAfterATableKeepsItAndSelectsTheTable() {
        editor.document = Document(blocks: [table(), para("p", "after")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        guard let after = editor.currentRoles.firstIndex(where: { $0.containerID == BlockID("p") }) else {
            return XCTFail("no paragraph role")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: after), length: 0)
        editor.engine.deleteBackward()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(editor.document.blocks.count, 2, "the paragraph survives")
        XCTAssertEqual(editor.structuralRowRange(), 0...1)
    }

    // MARK: The selection cannot outlive its table

    /// Deleting the table while a row of it is selected must leave nothing behind. If this ever fails,
    /// the fix belongs in the document setter's clear — NOT a second `clearTableStructuralSelection()`
    /// bolted on at the deleting site, which is how per-site clearing starts.
    func test_deletingTheTableClearsTheSelection() {
        editor.document = Document(blocks: [para("p", "before"), table()])
        editor.selectTableRows(0...0)
        XCTAssertNotNil(editor.structuralRowRange(), "precondition")
        editor.deleteTable()
        XCTAssertNil(editor.tableStructuralSelection)
        window.layoutIfNeeded()
        XCTAssertTrue(editor.tableStructuralChromeViews.isEmpty, "and its chrome went with it")
    }

    /// The completeness check's reverse direction, exercised: no pooled chrome names a table the roles
    /// no longer hold.
    func test_noStructuralChromeOutlivesItsTable() {
        editor.document = Document(blocks: [para("p", "before"), table()])
        editor.selectTableRows(0...0)
        window.layoutIfNeeded()
        editor.deleteTable()
        window.layoutIfNeeded()
        XCTAssertEqual(editor.derivedViewShortfall(), [])
    }
}

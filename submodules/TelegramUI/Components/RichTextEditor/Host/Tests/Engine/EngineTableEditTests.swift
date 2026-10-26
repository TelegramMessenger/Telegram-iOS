import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-tables rung C — the structural edits.
///
/// All nine ride ONE splice, so the splice is tested here first, on its own, with a hand-modified
/// `TableBlock`. If it holds, each verb is Core's primitive plus two lines.
@available(iOS 18.4, *)
final class EngineTableEditTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
        window.addSubview(editor); window.makeKeyAndVisible()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    /// A 2x2 table reading "aa" "bb" / "cc" "dd". Row 0 is a HEADER — `TableBlock.empty` makes it one.
    private func grid(_ id: String = "t", rows: Int = 2, columns: Int = 2) -> TableBlock {
        var built = TableBlock.empty(rows: rows, columns: columns)
        built.id = BlockID(id)
        let letters = ["a", "b", "c", "d", "e", "f", "g", "h", "i"]
        var next = 0
        for r in 0..<rows {
            for c in 0..<columns {
                let text = String(repeating: letters[min(next, letters.count - 1)], count: 2)
                built.rows[r].cells[c].blocks = [para("\(id)-\(r)\(c)", text)]
                next += 1
            }
        }
        return built
    }

    private func load(_ table: TableBlock) {
        editor.document = Document(blocks: [.table(table)])
        window.layoutIfNeeded()
    }

    /// The model's table, read back.
    fileprivate func table(_ id: String = "t") -> TableBlock? {
        guard let block = editor.document.blocksByID[BlockID(id)], case let .table(table) = block else { return nil }
        return table
    }

    fileprivate func cellTexts(_ id: String = "t") -> [[String]] {
        (table(id)?.rows ?? []).map { row in
            row.cells.map { $0.blocks.flatMap { $0.asParagraph?.runs ?? [] }.map(\.text).joined() }
        }
    }

    fileprivate func putCaretInCell(row: Int, column: Int, ofTable id: String = "t") {
        guard let table = table(id), let anchor = TableMap(table).anchor(atRow: row, column: column),
              let index = editor.currentRoles.firstIndex(where: { $0.blockID == anchor.cellID })
        else { return XCTFail("no cell (\(row),\(column))") }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: index), length: 0)
    }

    // MARK: The splice

    func test_theSpliceKeepsEveryCellsText() {
        load(grid())
        putCaretInCell(row: 0, column: 0)
        var updated = grid()
        updated.rows[1].cells[1].blocks = [para("t-11", "zz")]
        editor.replaceTable(with: updated, parkingAt: nil)
        XCTAssertEqual(cellTexts(), [["aa", "bb"], ["cc", "zz"]])
    }

    /// The whole reason for a splice rather than `insertTable`'s document swap, which clears history.
    func test_undoRestoresTheGridAndEarlierTyping() {
        load(grid())
        putCaretInCell(row: 1, column: 0)
        editor.engine.insertText("Z")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(cellTexts()[1][0], "Zcc", "precondition: typed before the edit (the caret parks at the cell START)")

        editor.replaceTable(with: grid("t", rows: 3, columns: 2), parkingAt: nil)
        XCTAssertEqual(table()?.rows.count, 3)

        editor.engine.undoManager?.undo()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(table()?.rows.count, 2, "the splice is undone")
        XCTAssertEqual(cellTexts()[1][0], "Zcc", "and the typing before it survives")
    }

    func test_theSpliceFiresExactlyOneChangeNotification() {
        load(grid())
        putCaretInCell(row: 0, column: 0)
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.replaceTable(with: grid("t", rows: 3, columns: 2), parkingAt: nil)
        XCTAssertEqual(changes, 1)
    }

    func test_theSpliceLeavesNoPresentationDrift() {
        load(grid())
        putCaretInCell(row: 0, column: 0)
        editor.replaceTable(with: grid("t", rows: 3, columns: 2), parkingAt: nil)
        window.layoutIfNeeded()
        guard let run = editor.roleRun(ofTableWithID: BlockID("t")) else { return XCTFail("no run") }
        for index in run {
            XCTAssertEqual(editor.presentationDrift(atBlock: index), [], "role \(index) drifted")
        }
    }

    /// THE case the `within:` parameter buys. Built at top level and re-parented afterwards, a quoted
    /// table would come back with correct structure wrapped around body-sized text.
    func test_aQuotedTableStaysQuotedAndKeepsItsQuoteSizedText() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [.table(grid())], author: [])),
        ])
        window.layoutIfNeeded()
        guard let quotedIndex = editor.currentRoles.firstIndex(where: { $0.owningTable != nil })
        else { return XCTFail("no quoted cell") }
        let quotedFace = editor.engine.attributedBlocks[quotedIndex]
            .attribute(.font, at: 0, effectiveRange: nil) as? UIFont

        putCaretInCell(row: 0, column: 0)
        editor.replaceTable(with: grid("t", rows: 3, columns: 2), parkingAt: nil)
        window.layoutIfNeeded()

        guard case let .blockQuote(quote) = editor.document.blocks[0] else {
            return XCTFail("the table was lifted out of its quote: \(editor.document.blocks)")
        }
        XCTAssertTrue(quote.children.contains { $0.id == BlockID("t") })
        guard let after = editor.currentRoles.firstIndex(where: { $0.owningTable != nil })
        else { return XCTFail("no cell after the splice") }
        let afterFace = editor.engine.attributedBlocks[after]
            .attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(afterFace?.pointSize, quotedFace?.pointSize,
                       "the spliced cells keep the quote's size, so they were rendered inside it")
    }

    // MARK: Rows

    /// `TableBlock.empty` always makes row 0 a header; this one has none, which is the shape whose
    /// every row CAN be selected for deletion.
    private func headerlessGrid(_ id: String = "t", rows: Int = 2) -> TableBlock {
        var built = grid(id, rows: rows, columns: 2)
        // `Row.isHeader` is DERIVED — "every cell is a header cell" — so per-cell is the only place to
        // set it, which is Core's own note: `Cell.isHeader` is the single source of truth.
        for r in built.rows.indices {
            for c in built.rows[r].cells.indices { built.rows[r].cells[c].isHeader = false }
        }
        return built
    }

    func test_addRowAboveInsertsAtTheRangesLowerBound() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableRows(1...2)
        editor.insertTableRowAbove()
        XCTAssertEqual(table()?.rows.count, 4)
        XCTAssertEqual(cellTexts()[1], ["", ""], "the fresh row landed at the range's start")
        XCTAssertEqual(cellTexts()[2], ["cc", "dd"], "and the old row 1 moved down")
    }

    func test_addRowBelowInsertsAfterTheRangesUpperBound() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableRows(0...1)
        editor.insertTableRowBelow()
        XCTAssertEqual(table()?.rows.count, 4)
        XCTAssertEqual(cellTexts()[2], ["", ""], "the fresh row landed after the range's end")
    }

    func test_withNoSelectionARowInsertUsesTheCaretsRow() {
        load(grid("t", rows: 3, columns: 2))
        putCaretInCell(row: 2, column: 0)
        editor.insertTableRowAbove()
        XCTAssertEqual(table()?.rows.count, 4)
        XCTAssertEqual(cellTexts()[2], ["", ""])
    }

    func test_deleteRowRemovesTheSelectedRows() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableRows(1...1)
        editor.deleteTableRow()
        XCTAssertEqual(table()?.rows.count, 2)
        XCTAssertEqual(cellTexts(), [["aa", "bb"], ["ee", "ff"]])
    }

    /// Core's `removingRows(in:)` filters HEADER rows out of the victims itself, so this is Core's
    /// guarantee rather than the engine's — pinned because the engine must not duplicate it.
    func test_deletingARangeIncludingTheHeaderKeepsTheHeader() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableRows(0...1)
        editor.deleteTableRow()
        XCTAssertEqual(cellTexts(), [["aa", "bb"], ["ee", "ff"]], "the header survived, row 1 went")
    }

    /// The one floor Core LACKS: `removingRows` has no "keep at least one row", so a header-less table
    /// whose every row is selected would be emptied. A table with no rows is not a table.
    func test_deletingEveryRowOfAHeaderlessTableIsRefused() {
        load(headerlessGrid("t", rows: 2))
        editor.selectTableRows(0...1)
        editor.engine.undoManager?.removeAllActions()
        editor.deleteTableRow()
        XCTAssertEqual(table()?.rows.count, 2, "nothing was deleted")
        XCTAssertEqual(editor.engine.undoManager?.canUndo, false, "and a no-op registered no undo step")
    }

    func test_aRowVerbOutsideATableDoesNothing() {
        editor.document = Document(blocks: [para("p", "text")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        let before = editor.document.blocks.count
        editor.insertTableRowAbove()
        editor.deleteTableRow()
        XCTAssertEqual(editor.document.blocks.count, before)
    }

    // MARK: Columns

    func test_addColumnLeftInsertsAtTheRangesLowerBound() {
        load(grid("t", rows: 2, columns: 3))
        editor.selectTableColumns(1...2)
        editor.insertTableColumnLeft()
        XCTAssertEqual(table()?.columns.count, 4)
        XCTAssertEqual(cellTexts()[0], ["aa", "", "bb", "cc"])
    }

    func test_addColumnRightInsertsAfterTheRangesUpperBound() {
        load(grid("t", rows: 2, columns: 3))
        editor.selectTableColumns(0...1)
        editor.insertTableColumnRight()
        XCTAssertEqual(table()?.columns.count, 4)
        XCTAssertEqual(cellTexts()[0], ["aa", "bb", "", "cc"])
    }

    /// The fresh column takes the width of the one it was inserted beside, so a table of unequal
    /// columns does not gain a differently-sized stripe.
    func test_theFreshColumnTakesItsNeighboursWidth() {
        var built = grid("t", rows: 2, columns: 2)
        built.columns[1] = ColumnSpec(width: 250)
        load(built)
        editor.selectTableColumns(1...1)
        editor.insertTableColumnRight()
        XCTAssertEqual(table()?.columns.map(\.width), [100, 250, 250])
    }

    func test_deleteColumnRemovesTheSelectedColumns() {
        load(grid("t", rows: 2, columns: 3))
        editor.selectTableColumns(1...1)
        editor.deleteTableColumn()
        XCTAssertEqual(table()?.columns.count, 2)
        XCTAssertEqual(cellTexts()[0], ["aa", "cc"])
    }

    /// Core keeps one column whatever it is asked, but the engine refuses BEFORE the edit so a
    /// no-op cannot register an undo step.
    func test_deletingEveryColumnIsRefused() {
        load(grid("t", rows: 2, columns: 2))
        editor.selectTableColumns(0...1)
        editor.engine.undoManager?.removeAllActions()
        editor.deleteTableColumn()
        XCTAssertEqual(table()?.columns.count, 2, "nothing was deleted")
        XCTAssertEqual(editor.engine.undoManager?.canUndo, false, "and no undo step was registered")
    }

    func test_withNoSelectionAColumnInsertUsesTheCaretsColumn() {
        load(grid("t", rows: 2, columns: 3))
        putCaretInCell(row: 1, column: 2)
        editor.insertTableColumnLeft()
        XCTAssertEqual(table()?.columns.count, 4)
        XCTAssertEqual(cellTexts()[0], ["aa", "bb", "", "cc"])
    }

    // MARK: Merge and split

    private func anchors(_ id: String = "t") -> [TableMap.Anchor] {
        table(id).map { TableMap($0).anchors } ?? []
    }

    func test_mergingACellRectLeavesOneSpanningAnchor() {
        load(grid("t", rows: 2, columns: 2))
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        editor.mergeSelectedCells()
        XCTAssertEqual(anchors().count, 1)
        XCTAssertEqual(anchors().first?.colspan, 2)
        XCTAssertEqual(anchors().first?.rowspan, 2)
    }

    func test_splittingAMergedCellRestoresTheDenseGrid() {
        load(grid("t", rows: 2, columns: 2))
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        editor.mergeSelectedCells()
        XCTAssertEqual(anchors().count, 1, "precondition")
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))
        editor.splitSelectedCell()
        XCTAssertEqual(anchors().count, 4)
        XCTAssertTrue(anchors().allSatisfy { $0.colspan == 1 && $0.rowspan == 1 })
    }

    func test_mergingASingleAnchorIsRefused() {
        load(grid("t", rows: 2, columns: 2))
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))
        editor.engine.undoManager?.removeAllActions()
        editor.mergeSelectedCells()
        XCTAssertEqual(anchors().count, 4, "nothing merged")
        XCTAssertEqual(editor.engine.undoManager?.canUndo, false, "and no undo step was registered")
    }

    func test_splittingAnUnmergedCellIsRefused() {
        load(grid("t", rows: 2, columns: 2))
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))
        editor.engine.undoManager?.removeAllActions()
        editor.splitSelectedCell()
        XCTAssertEqual(anchors().count, 4)
        XCTAssertEqual(editor.engine.undoManager?.canUndo, false)
    }

    /// The merged cell keeps the covered cells' content — Core concatenates it into the anchor.
    func test_aMergeKeepsTheCoveredCellsText() {
        load(grid("t", rows: 2, columns: 2))
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 1))
        editor.mergeSelectedCells()
        let merged = cellTexts()[0].joined()
        XCTAssertTrue(merged.contains("aa") && merged.contains("bb"),
                      "both cells' text survived into the anchor, got \(merged)")
    }

    // MARK: Alignment and the header toggle

    private func alignments(_ id: String = "t") -> [[TextAlignment]] {
        (table(id)?.rows ?? []).map { $0.cells.map(\.horizontalAlignment) }
    }
    private func headers(_ id: String = "t") -> [[Bool]] {
        (table(id)?.rows ?? []).map { $0.cells.map(\.isHeader) }
    }

    func test_alignmentAppliesToEveryCellOfTheSelectedRow() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableRows(1...1)
        editor.setSelectionAlignment(horizontal: .right, vertical: nil)
        XCTAssertEqual(alignments()[1], [.right, .right])
        XCTAssertEqual(alignments()[2], [.center, .center], "the unselected row is untouched")
    }

    /// A nil axis leaves that axis alone, which is what the host's control relies on when only one
    /// half of it is used.
    func test_aNilAxisIsLeftAlone() {
        load(grid("t", rows: 2, columns: 2))
        editor.selectTableRows(1...1)
        editor.setSelectionAlignment(horizontal: nil, vertical: .bottom)
        XCTAssertEqual(alignments()[1], [.center, .center], "horizontal untouched")
        XCTAssertEqual((table()?.rows[1].cells ?? []).map(\.verticalAlignment), [.bottom, .bottom])
    }

    func test_theHeaderToggleFlipsEveryCoveredCell() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableRows(1...1)
        XCTAssertEqual(headers()[1], [false, false], "precondition")
        editor.toggleSelectionHeader()
        XCTAssertEqual(headers()[1], [true, true])
        editor.selectTableRows(1...1)
        editor.toggleSelectionHeader()
        XCTAssertEqual(headers()[1], [false, false])
    }

    /// Mixed cells go uniformly ON, the same decide-once rule the formatting commands use.
    func test_aMixedHeaderSelectionGoesUniformlyOn() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableCells(TableRect(top: 1, left: 0, bottom: 1, right: 0))
        editor.toggleSelectionHeader()
        XCTAssertEqual(headers()[1], [true, false], "precondition: mixed")
        editor.selectTableRows(1...1)
        editor.toggleSelectionHeader()
        XCTAssertEqual(headers()[1], [true, true])
    }

    func test_anAttributeVerbFiresExactlyOneChangeNotification() {
        load(grid("t", rows: 2, columns: 2))
        editor.selectTableRows(1...1)
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.setSelectionAlignment(horizontal: .left, vertical: nil)
        XCTAssertEqual(changes, 1)
    }

    // MARK: Backspace with a structural selection

    func test_backspaceDeletesTheSelectedRows() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableRows(1...1)
        editor.engine.deleteBackward()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(cellTexts(), [["aa", "bb"], ["ee", "ff"]])
        XCTAssertNil(editor.tableStructuralSelection, "and the selection is cleared")
    }

    func test_backspaceDeletesTheSelectedColumns() {
        load(grid("t", rows: 2, columns: 3))
        editor.selectTableColumns(1...1)
        editor.engine.deleteBackward()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(cellTexts()[0], ["aa", "cc"])
    }

    /// Covering EVERY row would empty the table, so the whole table goes and an empty paragraph is
    /// left IN PLACE — distinct from rung A's `deleteTable`, which joins the surrounding content.
    func test_backspaceOverEveryRowReplacesTheTableWithAParagraph() {
        editor.document = Document(blocks: [para("p0", "before"), .table(headerlessGrid("t", rows: 2))])
        window.layoutIfNeeded()
        editor.selectTableRows(0...1)
        editor.engine.deleteBackward()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertNil(table(), "the table is gone")
        XCTAssertEqual(editor.document.blocks.count, 2, "and a paragraph stands in its place")
        XCTAssertNil(editor.tableStructuralSelection)
    }

    func test_backspaceOverEveryColumnReplacesTheTableWithAParagraph() {
        editor.document = Document(blocks: [para("p0", "before"), .table(grid("t", rows: 2, columns: 2))])
        window.layoutIfNeeded()
        editor.selectTableColumns(0...1)
        editor.engine.deleteBackward()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertNil(table())
        XCTAssertEqual(editor.document.blocks.count, 2)
    }

    /// The gate's door: UIKit may deliver the same keystroke as a RANGE replace.
    func test_theRangeDoorDeletesTheSelectionToo() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableRows(1...1)
        let caret = editor.engineSelectedRange.location
        guard let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: caret - 1),
              let end = editor.engine.position(from: start, offset: 1),
              let range = editor.engine.textRange(from: start, to: end) else { return XCTFail("bad range") }
        editor.engine.replace(range, withText: "")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(cellTexts(), [["aa", "bb"], ["ee", "ff"]], "the range door deleted the row too")
    }

    // MARK: One verb is ONE undo step

    /// If this ever needs two undos the splice is registering twice, and the fix is in
    /// `replaceTable` — NOT a `removeAllActions` bolted on, which is how the undo-clearing this rung
    /// exists to avoid gets reintroduced.
    func test_aRowInsertIsASingleUndoStep() {
        load(grid("t", rows: 2, columns: 2))
        putCaretInCell(row: 1, column: 0)
        editor.engine.insertText("Z")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        editor.selectTableRows(1...1)
        editor.insertTableRowAbove()
        XCTAssertEqual(table()?.rows.count, 3, "precondition")

        editor.engine.undoManager?.undo()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(table()?.rows.count, 2, "ONE undo took the row back")
        XCTAssertEqual(cellTexts()[1][0], "Zcc", "and the typing before it is still there")
    }

    func test_aDeleteRowIsASingleUndoStep() {
        load(grid("t", rows: 3, columns: 2))
        editor.selectTableRows(1...1)
        editor.deleteTableRow()
        XCTAssertEqual(table()?.rows.count, 2, "precondition")
        editor.engine.undoManager?.undo()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(table()?.rows.count, 3, "ONE undo brought the row back")
        XCTAssertEqual(cellTexts()[1], ["cc", "dd"], "with its text")
    }

    // MARK: The attribute verbs keep the selection

    /// Alignment and the header toggle act on the selection and LEAVE it: the menu's attribute group
    /// stays open for a second pick, and legacy clears only after a structural action. The splice
    /// parks the caret, and the selection funnel cleared the selection on that move (K3, 2026-09-11:
    /// choosing an alignment dropped the column selection, so the header toggle that followed acted
    /// on the caret's cell alone).
    func test_settingAlignmentKeepsTheStructuralSelection() {
        load(grid())
        editor.selectTableColumns(1...1)
        editor.setSelectionAlignment(horizontal: .center, vertical: nil)
        XCTAssertEqual(editor.structuralColumnRange(), 1...1)
        XCTAssertEqual(editor.tableForEditing()?.table.rows[1].cells[1].horizontalAlignment, .center)
    }

    func test_togglingTheHeaderKeepsTheStructuralSelection() {
        load(grid())
        editor.selectTableRows(1...1)
        editor.toggleSelectionHeader()
        XCTAssertEqual(editor.structuralRowRange(), 1...1)
    }
}

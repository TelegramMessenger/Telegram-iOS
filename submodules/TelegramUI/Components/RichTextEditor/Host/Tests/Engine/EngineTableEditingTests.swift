import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

@available(iOS 18.4, *)
final class EngineTableEditingTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: text.isEmpty ? [] : [.paragraph(ParagraphBlock(id: BlockID("\(id)p"), runs: [TextRun(text: text)]))])
    }
    private func twoByTwo(_ texts: [String] = ["aa", "bb", "cc", "dd"]) -> TableBlock {
        TableBlock(id: BlockID("t0"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                   rows: [Row(id: BlockID("r0"), cells: [cell("a", texts[0]), cell("b", texts[1])]),
                          Row(id: BlockID("r1"), cells: [cell("c", texts[2]), cell("d", texts[3])])])
    }
    /// Backspace at the START of a table's first cell travels — it never merges. WHERE it travels is
    /// a container question, and the answer is the container's own leading line if it has one.
    ///
    /// A DETAILS has a title above its body, so the caret belongs at its end — the same wall a
    /// paragraph first-body-child gets. A QUOTE has no leading own line, so there is nothing inside
    /// it to travel to and the caret leaves it. Decided 2026-09-08; before that the two differed only
    /// because of where `index - 1` happened to land.
    func test_backspaceAtTheFirstCellOfADetailsTableJumpsToTheTitle() {
        editor.document = Document(blocks: [
            .details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "Notes")],
                                  children: [.table(twoByTwo())], expanded: true)),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        guard let firstCell = editor.currentRoles.firstIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("no cells")
        }
        let title = firstCell - 1
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: firstCell), length: 0)
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange,
                       NSRange(location: editor.flatOffset(ofRoleAt: title) + editor.flatLength(ofRoleAt: title), length: 0),
                       "the caret lands at the title's end, inside the block")
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string).first, "Notes", "and nothing was deleted")
    }

    func test_backspaceAtTheFirstCellOfAQuotedTableLeavesTheQuote() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("zz"), runs: [TextRun(text: "zz")])),
            .blockQuote(BlockQuote(id: BlockID("q"), children: [.table(twoByTwo())], author: [])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        guard let firstCell = editor.currentRoles.firstIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("no cells")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: firstCell), length: 0)
        editor.engine.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange,
                       NSRange(location: editor.flatOffset(ofRoleAt: 0) + editor.flatLength(ofRoleAt: 0), length: 0),
                       "a quote owns no leading line, so the caret leaves it for the block above")
    }

    private func cellTexts() -> [[String]] {
        guard case let .table(t) = editor.document.blocks.first(where: { if case .table = $0 { return true }; return false }) ?? .paragraph(ParagraphBlock(id: BlockID("none"))) else { return [] }
        return t.rows.map { $0.cells.map { $0.blocks.first?.asParagraph?.runs.map(\.text).joined() ?? "" } }
    }
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))   // the repairs are main.async
    }
    /// Flat offsets: "before\n" = 7; cells "aa\nbb\ncc\ndd\n" start at 7, 10, 13, 16; "after" at 19.
    private func loadSandwich() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .table(twoByTwo()),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }

    func test_returnInsideACellMovesToTheNextCellAndChangesNothing() {
        loadSandwich()
        editor.engineSelectedRange = NSRange(location: 8, length: 0)   // a|a
        editor.engine.insertText("\n")
        settle()
        XCTAssertEqual(cellTexts(), [["aa", "bb"], ["cc", "dd"]], "the cell is not split")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 10, length: 0), "caret at the start of b")
        XCTAssertFalse(editor.engine.undoManager?.canUndo ?? false, "a caret move registers no undo step")
    }

    func test_returnInTheLastCellLeavesTheTableIntoTheParagraphAfter() {
        loadSandwich()
        editor.engineSelectedRange = NSRange(location: 18, length: 0)   // dd|
        editor.engine.insertText("\n")
        settle()
        XCTAssertEqual(editor.document.blocks.count, 3)
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 19, length: 0), "caret at the start of `after`")
    }

    func test_returnInTheLastCellOfATrailingTableAppendsAnEmptyParagraph() {
        editor.document = Document(blocks: [.table(twoByTwo())])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 11, length: 0)   // dd| (cells at 0, 3, 6, 9)
        editor.engine.insertText("\n")
        settle()
        XCTAssertEqual(editor.document.blocks.count, 2)
        XCTAssertEqual(editor.document.blocks[1].asParagraph?.runs.map(\.text).joined() ?? "", "")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 12, length: 0))
    }

    /// Tab past the last cell of a TRAILING table appends a paragraph — a structural edit issued
    /// by a command, from outside the gate. The gate decides keystrokes; a command has decided
    /// already and carries its plan, so its edit must reach the controller unread. Before
    /// `performHostStructuralEdit` the gate read that "\n" as a Return in a cell, ran the command
    /// again one level down and vetoed the outer edit, dropping its plan: right only because the
    /// two plans were computed from the same roles.
    func test_tabPastTheLastCellOfATrailingTableIsNotDecidedByTheGate() {
        editor.document = Document(blocks: [.table(twoByTwo())])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // The surface consults the gate for every edit that reaches it; what is pinned here is the
        // gate's ANSWER — a veto (nil) is a decision, the text back unchanged is a pass.
        let installed = editor.engine.tgid_textInputGate
        var answers: [String?] = []
        editor.engine.tgid_textInputGate = { range, text in
            let answer = installed?(range, text) ?? text
            answers.append(answer)
            return answer
        }
        editor.engineSelectedRange = NSRange(location: 11, length: 0)   // dd| (cells at 0, 3, 6, 9)
        editor.moveCaretToNextTableCell()
        settle()
        XCTAssertEqual(answers, ["\n"], "the command's own edit passes unread, not vetoed and decided again")
        XCTAssertEqual(editor.document.blocks.count, 2)
        XCTAssertNotNil(editor.document.blocks[1].asParagraph, "a body paragraph after the table")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 12, length: 0))
        editor.engine.undoManager?.undo()
        settle()
        XCTAssertEqual(editor.document.blocks.count, 1, "and the table is alone again")
        XCTAssertEqual(cellTexts(), [["aa", "bb"], ["cc", "dd"]])
    }

    func test_shiftReturnInsertsALineSeparatorAsOneUndoableKeystroke() {
        loadSandwich()
        editor.engineSelectedRange = NSRange(location: 8, length: 0)
        editor.insertTableCellNewline()
        settle()
        XCTAssertEqual(cellTexts()[0][0], "a\na")
        XCTAssertEqual(editor.engine.attributedBlocks[1].string, "a\u{2028}a")
        XCTAssertTrue(editor.engine.undoManager?.canUndo ?? false)
    }

    func test_backspaceAtACellStartTravelsToThePreviousCellsEndWithoutMerging() {
        loadSandwich()
        editor.engineSelectedRange = NSRange(location: 10, length: 0)   // |bb
        editor.engine.deleteBackward()
        settle()
        XCTAssertEqual(cellTexts(), [["aa", "bb"], ["cc", "dd"]])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 9, length: 0), "end of aa")
        editor.engineSelectedRange = NSRange(location: 7, length: 0)    // |aa, the first cell
        editor.engine.deleteBackward()
        settle()
        XCTAssertEqual(cellTexts(), [["aa", "bb"], ["cc", "dd"]])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 6, length: 0), "out of the table: end of `before`")
    }

    func test_tabAndShiftTabMoveBetweenCells() {
        loadSandwich()
        editor.engineSelectedRange = NSRange(location: 8, length: 0)
        editor.moveCaretToNextTableCell()
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 10, length: 0))
        editor.moveCaretToPreviousTableCell()
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 7, length: 0), "start of the previous cell")
        XCTAssertEqual(editor.keyCommands?.count, 3, "Tab, Shift-Tab, Shift-Return while in a cell")
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        XCTAssertEqual(editor.keyCommands?.count ?? 0, 0, "…and none outside")
    }

    func test_aWhollyEmptyTableDissolvesOnBackspaceAtItsFirstCell() {
        editor.document = Document(blocks: [.table(twoByTwo(["", "", "", ""]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.deleteBackward()
        settle()
        XCTAssertEqual(editor.document.blocks.count, 1)
        XCTAssertNotNil(editor.document.blocks[0].asParagraph, "the table became an empty paragraph")
    }

    func test_aSelectionSpanningCellsIsReplacedPerCellNotMerged() {
        loadSandwich()
        editor.engineSelectedRange = NSRange(location: 8, length: 6)   // a|a … c|c  (through bb)
        editor.engine.insertText("X")
        settle()
        XCTAssertEqual(cellTexts(), [["aX", ""], ["c", "dd"]], "head + typed text; middle emptied; tail kept")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 9, length: 0))
        XCTAssertTrue(editor.engine.undoManager?.canUndo ?? false)
    }

    func test_aMultiLinePasteIntoACellStaysInThatCell() {
        loadSandwich()
        editor.engineSelectedRange = NSRange(location: 8, length: 0)
        editor.engine.insertText("x\ny")
        settle()
        XCTAssertEqual(cellTexts(), [["ax\nya", "bb"], ["cc", "dd"]])
        XCTAssertEqual(editor.engine.attributedBlocks[1].string, "ax\u{2028}ya")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 11, length: 0), "after the pasted text")
    }

    func test_insertTableReplacesAnEmptyParagraphWithAnEmptyGridAndLandsInItsFirstCell() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), style: .body))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.insertTable(rows: 2, cols: 3)
        guard case let .table(t) = editor.document.blocks.first else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(t.rowCount, 2); XCTAssertEqual(t.columnCount, 3)
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 0))
        XCTAssertTrue(editor.engine.undoManager?.canUndo ?? false)
    }

    func test_typingIntoAnEmptyCellThenBackspacingLeavesTheTableAlone() {
        // The engine re-stamps the separator after a freshly filled empty block as a same-text
        // replace; that must never read as an edit spanning two cells.
        loadSandwich()
        editor.engineSelectedRange = NSRange(location: 12, length: 0)   // bb|
        editor.engine.deleteBackward(); editor.engine.deleteBackward(); settle()   // empty bb → ""
        XCTAssertEqual(cellTexts()[0][1], "", "precondition: an empty cell")
        editor.engineSelectedRange = NSRange(location: 10, length: 0)
        editor.engine.insertText("x"); settle()
        XCTAssertEqual(cellTexts(), [["aa", "x"], ["cc", "dd"]], "typing into the empty cell adds nothing else")
        editor.engine.deleteBackward(); settle()
        XCTAssertEqual(cellTexts(), [["aa", ""], ["cc", "dd"]])
        XCTAssertEqual(editor.document.blocks.count, 3, "no line appeared before the table")
    }

    func test_theTypingPolicyCarriesNoBaseFontAcrossABlockBoundary() {
        // Captured on device: the first character typed at a cell's start arrived with
        // `current` = the cell's 15pt font and `preceding` = the paragraph before the table, whose
        // last character carried a 17pt base-font marker. The marker is what a bold toggle derives
        // its face from, so inheriting it bolded the cell's text at the body size.
        loadSandwich()
        let cellFont = UIFont.systemFont(ofSize: StyleSheet.tableCells.metrics.body.size)
        let bodyFont = UIFont.systemFont(ofSize: 17)
        let current: [NSAttributedString.Key: Any] = [.font: cellFont]
        let preceding: [NSAttributedString.Key: Any] = [.font: bodyFont,
                                                        NSAttributedString.Key.IDInlineTextBaseFontAttributeName: bodyFont]
        editor.engineSelectedRange = NSRange(location: 10, length: 0)   // |bb — a block's START
        let atStart = editor.attributesForTypedText(current: current, preceding: preceding, insertedText: "Q")
        XCTAssertNil(atStart[NSAttributedString.Key.IDInlineTextBaseFontAttributeName],
                     "nothing carries over from the previous block")
        XCTAssertEqual((atStart[.font] as? UIFont)?.pointSize, cellFont.pointSize)
        editor.engineSelectedRange = NSRange(location: 11, length: 0)   // b|b — inside the block
        let inside = editor.attributesForTypedText(current: current, preceding: preceding, insertedText: "Q")
        XCTAssertEqual((inside[NSAttributedString.Key.IDInlineTextBaseFontAttributeName] as? UIFont)?.pointSize, 17,
                       "inside a block the marker still continues, as inline code relies on")
    }

    func test_typingAfterReturnLeavesTheLastCellUsesBodyAttributesNotTheCells() {
        // Measured: the paragraph appended after a table took the last cell's 15pt centred face,
        // because a wholesale re-render moved the engine's selection to the end before its
        // empty-line map was in place, and the caret placement that followed changed nothing.
        editor.document = Document(blocks: [.table(TableBlock.empty(rows: 1, columns: 2))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 1, length: 0)   // the last (header) cell
        editor.engine.insertText("\n"); settle()
        XCTAssertEqual(editor.currentRoles.map { $0.owningTable != nil }, [true, true, false])
        editor.engine.insertText("F"); settle()
        let appended = editor.engine.attributedBlocks[2]
        let font = appended.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let style = appended.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(font?.pointSize, editor.bridge.styleSheet.metrics.body.size)
        XCTAssertFalse(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true, "not the header's bold")
        XCTAssertEqual(style?.alignment, .natural, "not the cell's centring")
    }

    func test_typingIntoAnEmptyHeaderCellIsBoldFromTheFirstCharacter() {
        editor.document = Document(blocks: [.table(TableBlock.empty(rows: 2, columns: 2))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("F"); settle()
        let font = editor.engine.attributedBlocks[0].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true,
                      "a header cell's typing attributes carry its bold, not only its re-render")
        XCTAssertEqual(font?.pointSize, StyleSheet.tableCells.metrics.body.size)
    }
}

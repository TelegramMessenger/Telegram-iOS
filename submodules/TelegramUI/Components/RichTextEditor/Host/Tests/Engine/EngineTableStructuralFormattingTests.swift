import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-tables rung B — formatting across a structural selection.
///
/// TWO mechanisms, because the engine offers two. Inline code and spoiler go through
/// `transformInlineAttributes`, which is a SET: decide once, apply per cell, uniform by construction.
/// The four native traits are toggle-only and are `EngineTableStructuralFormattingTests`' second half.
@available(iOS 18.4, *)
final class EngineTableStructuralFormattingTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    /// THREE rows on purpose. `TableBlock.empty` makes row 0 a HEADER, and a header cell's bold is
    /// deliberately not modelled — it is bold by STYLE, and the read-back must not pin that as the
    /// user's. So the trait tests act on row 1 and check row 2 is untouched.
    private func loadTable() {
        var built = TableBlock.empty(rows: 3, columns: 2)
        built.id = BlockID("t")
        let texts = [["aa", "bb"], ["cc", "dd"], ["ee", "ff"]]
        for r in 0..<3 {
            for c in 0..<2 { built.rows[r].cells[c].blocks = [para("t-\(r)\(c)", texts[r][c])] }
        }
        editor.document = Document(blocks: [.table(built)])
        window.layoutIfNeeded()
    }

    /// Every run of every cell in `row`, read back from the model.
    private func runs(inRow row: Int) -> [TextRun] {
        guard let block = editor.document.blocksByID[BlockID("t")], case let .table(table) = block,
              table.rows.indices.contains(row) else { return [] }
        return table.rows[row].cells.flatMap { cell in
            cell.blocks.flatMap { $0.asParagraph?.runs ?? [] }
        }
    }

    // MARK: Inline code — a SET, so uniformity is by construction

    func test_inlineCodeAppliesToEveryCellOfTheSelectedRow() {
        loadTable()
        editor.selectTableRows(0...0)
        editor.toggleInlineCode()
        XCTAssertEqual(runs(inRow: 0).map(\.attributes.inlineCode), [true, true])
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.inlineCode), [false, false],
                       "the unselected row is untouched")
    }

    func test_aRowThatIsAlreadyAllCodeIsCleared() {
        loadTable()
        editor.selectTableRows(0...0)
        editor.toggleInlineCode()
        editor.selectTableRows(0...0)
        editor.toggleInlineCode()
        XCTAssertEqual(runs(inRow: 0).map(\.attributes.inlineCode), [false, false])
    }

    /// Decided ONCE across the whole selection: a row where only some cells are code becomes ALL
    /// code, not each cell flipped independently.
    func test_aPartlyCodedRowBecomesAllCode() {
        loadTable()
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))
        editor.toggleInlineCode()
        XCTAssertEqual(runs(inRow: 0).map(\.attributes.inlineCode), [true, false], "precondition")
        editor.selectTableRows(0...0)
        editor.toggleInlineCode()
        XCTAssertEqual(runs(inRow: 0).map(\.attributes.inlineCode), [true, true])
    }

    func test_spoilerAppliesToEveryCellOfTheSelectedColumn() {
        loadTable()
        editor.selectTableColumns(0...0)
        editor.toggleSpoiler()
        XCTAssertEqual(runs(inRow: 0).map(\.attributes.spoiler), [true, false])
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.spoiler), [true, false])
        XCTAssertEqual(runs(inRow: 2).map(\.attributes.spoiler), [true, false])
    }

    func test_formattingAcrossASelectionFiresExactlyOneChangeNotification() {
        loadTable()
        editor.selectTableRows(0...0)
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.toggleInlineCode()
        XCTAssertEqual(changes, 1, "one verb is one notification, however many cells it touched")
    }

    /// Formatting is not typing: the row stays selected so the next command acts on it too.
    func test_theSelectionSurvivesFormatting() {
        loadTable()
        editor.selectTableRows(0...0)
        editor.toggleInlineCode()
        XCTAssertEqual(editor.structuralRowRange(), 0...0)
    }

    func test_withNoStructuralSelectionInlineCodeStillActsOnTheCaret() {
        editor.document = Document(blocks: [para("p", "abcd")])
        editor.engineSelectedRange = NSRange(location: 0, length: 4)
        editor.toggleInlineCode()
        XCTAssertEqual(editor.document.blocks[0].asParagraph?.runs.map(\.attributes.inlineCode), [true])
    }

    // MARK: The four native traits — toggle-only, so a target and one toggle per differing cell

    func test_boldAppliesToEveryCellOfTheSelectedRow() {
        loadTable()
        editor.selectTableRows(1...1)
        editor.toggleBold()
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.bold), [true, true])
        XCTAssertEqual(runs(inRow: 2).map(\.attributes.bold), [false, false],
                       "the unselected row is untouched")
    }

    /// A HEADER row renders bold by STYLE, so the read-back refuses to pin it as the user's bold —
    /// the same distinction that makes the engine's trait marker come from `.rtBold` and never from
    /// the rendered face. Selecting one and pressing Bold therefore changes no model bold.
    func test_aHeaderRowsBoldIsNotTheUsers() {
        loadTable()
        editor.selectTableRows(0...0)
        editor.toggleBold()
        XCTAssertEqual(runs(inRow: 0).map(\.attributes.bold), [false, false])
    }

    func test_aRowThatIsAlreadyAllBoldIsUnbolded() {
        loadTable()
        editor.selectTableRows(1...1)
        editor.toggleBold()
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.bold), [true, true], "precondition")
        editor.selectTableRows(1...1)
        editor.toggleBold()
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.bold), [false, false])
    }

    /// THE measured rule. The engine offers no SET for its four traits, only toggle + state, and a
    /// toggle takes a `mixed` selection to `on` — so with the target decided as "off only when EVERY
    /// cell is on", a differing cell always reaches the target in ONE toggle and the mixed-to-off
    /// two-step is unreachable by construction.
    func test_aPartlyBoldRowGoesUniformlyBoldInOnePass() {
        loadTable()
        editor.selectTableCells(TableRect(top: 1, left: 0, bottom: 1, right: 0))
        editor.toggleBold()
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.bold), [true, false], "precondition: mixed")
        editor.selectTableRows(1...1)
        editor.toggleBold()
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.bold), [true, true])
    }

    func test_italicUnderlineAndStrikeApplyTheSameWay() {
        loadTable()
        editor.selectTableRows(1...1)
        editor.toggleItalic()
        editor.selectTableRows(1...1)
        editor.toggleUnderline()
        editor.selectTableRows(1...1)
        editor.toggleStrikethrough()
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.italic), [true, true])
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.underline), [true, true])
        XCTAssertEqual(runs(inRow: 1).map(\.attributes.strikethrough), [true, true])
    }

    /// The toolbar must describe the SELECTION, not the cell the caret happens to be parked in.
    func test_theReportedTraitIsTheCombinedStateAcrossTheCells() {
        loadTable()
        editor.selectTableCells(TableRect(top: 1, left: 0, bottom: 1, right: 0))
        editor.toggleBold()
        editor.selectTableRows(1...1)
        XCTAssertEqual(editor.currentInlineTraits().bold, .mixed, "one cell bold, one not")
        editor.toggleBold()
        editor.selectTableRows(1...1)
        XCTAssertEqual(editor.currentInlineTraits().bold, .on)
    }

    func test_aTraitAcrossASelectionFiresExactlyOneChangeNotification() {
        loadTable()
        editor.selectTableRows(1...1)
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.toggleBold()
        XCTAssertEqual(changes, 1)
    }

    func test_withNoStructuralSelectionBoldStillActsOnTheCaret() {
        editor.document = Document(blocks: [para("p", "abcd")])
        editor.engineSelectedRange = NSRange(location: 0, length: 4)
        editor.toggleBold()
        XCTAssertEqual(editor.document.blocks[0].asParagraph?.runs.map(\.attributes.bold), [true])
    }
}

#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasCharacterFormatTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    /// [ paragraph "Hello", paragraph "World", table( "Alpha" | "Beta" ) ]
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello")])),
            .paragraph(ParagraphBlock(id: BlockID("w"), runs: [TextRun(text: "World")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    /// Runs of the top-level paragraph `id` from the live model.
    func runs(_ v: DocumentCanvasView, _ id: String) -> [TextRun] {
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID(id) { return p.runs } }
        return []
    }
    /// Concatenated text of paragraph `id`'s runs whose attribute matches `pred`.
    func text(_ v: DocumentCanvasView, _ id: String, matching pred: (CharacterAttributes) -> Bool) -> String {
        runs(v, id).filter { pred($0.attributes) }.map { $0.text }.joined()
    }
    /// First-paragraph runs of table cell (row,col).
    func cellRuns(_ v: DocumentCanvasView, _ row: Int, _ col: Int) -> [TextRun] {
        guard let t = v.boxes.first(where: { $0 is TableBlockBox }) as? TableBlockBox,
              case .table(let model) = t.currentBlock() else { return [] }
        if case .paragraph(let p) = model.rows[row].cells[col].blocks[0] { return p.runs }
        return []
    }
    /// Select [globalStart+lo, globalStart+hi) within the leaf region for paragraph `id`.
    func selectParagraph(_ v: DocumentCanvasView, _ id: String, _ lo: Int, _ hi: Int) {
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
        v.setSelectionForTesting(anchor: r.globalStart + lo, head: r.globalStart + hi)
    }

    func test_toggleBold_appliesToSelectionOnly() {
        let v = canvas()
        selectParagraph(v, "h", 1, 4)                 // "ell" of "Hello"
        v.toggleBold()
        XCTAssertEqual(text(v, "h") { $0.bold }, "ell")
        XCTAssertEqual(text(v, "h") { !$0.bold }, "Ho")
    }
    func test_toggleBold_offWhenAllBold() {
        let v = canvas()
        selectParagraph(v, "h", 0, 5); v.toggleBold()
        XCTAssertEqual(text(v, "h") { $0.bold }, "Hello")
        selectParagraph(v, "h", 0, 5); v.toggleBold()
        XCTAssertEqual(text(v, "h") { $0.bold }, "")
    }
    func test_toggleBold_crossBlock() {
        let v = canvas()
        let h = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("h")) }!
        let w = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("w")) }!
        v.setSelectionForTesting(anchor: h.globalStart + 2, head: w.globalStart + 3)   // "llo" + "Wor"
        v.toggleBold()
        XCTAssertEqual(text(v, "h") { $0.bold }, "llo")
        XCTAssertEqual(text(v, "w") { $0.bold }, "Wor")
    }
    func test_toggleBold_crossCell_headerRowBoldIsRenderOnly() {
        let v = canvas()
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let b = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: a.globalStart + 1, head: b.globalStart + 3)   // "lpha" + "Bet"
        v.toggleBold()
        // Both cells are in the header row (row 0), whose bold is render-only and stripped from the
        // model on extraction (markdown-clean invariant) — so neither persists user bold.
        XCTAssertEqual(cellRuns(v, 0, 0).filter { $0.attributes.bold }.map { $0.text }.joined(), "")
        XCTAssertEqual(cellRuns(v, 0, 1).filter { $0.attributes.bold }.map { $0.text }.joined(), "")
    }
    func test_toggleBold_bodyCellPersistsInModel() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Name"), cell("b", "Role")]),
                   Row(id: BlockID("r1"), cells: [cell("c", "Ada"), cell("d", "Eng")])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let c = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("cp")) }!
        v.setSelectionForTesting(anchor: c.globalStart, head: c.globalStart + 3)   // "Ada" in a body cell
        v.toggleBold()
        // Body rows have no render-only bold, so user bold persists in the model.
        XCTAssertEqual(cellRuns(v, 1, 0).filter { $0.attributes.bold }.map { $0.text }.joined(), "Ada")
    }
    func test_toggleBold_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        selectParagraph(v, "h", 0, 5)
        um.beginUndoGrouping(); v.toggleBold(); um.endUndoGrouping()
        XCTAssertEqual(text(v, "h") { $0.bold }, "Hello")
        um.undo()
        XCTAssertEqual(text(v, "h") { $0.bold }, "", "undo removes the bold")
    }
    func test_toggleItalic_appliesToSelection() {
        let v = canvas()
        selectParagraph(v, "h", 0, 5); v.toggleItalic()
        XCTAssertEqual(text(v, "h") { $0.italic }, "Hello")
    }
    func test_toggleStrikethrough_appliesAndToggles() {
        let v = canvas()
        selectParagraph(v, "h", 0, 5); v.toggleStrikethrough()
        XCTAssertEqual(text(v, "h") { $0.strikethrough }, "Hello")
        selectParagraph(v, "h", 0, 5); v.toggleStrikethrough()
        XCTAssertEqual(text(v, "h") { $0.strikethrough }, "")
    }
    func test_toggleUnderline_appliesAndToggles() {
        let v = canvas()
        selectParagraph(v, "h", 0, 5); v.toggleUnderline()
        XCTAssertEqual(text(v, "h") { $0.underline }, "Hello")
        selectParagraph(v, "h", 0, 5); v.toggleUnderline()
        XCTAssertEqual(text(v, "h") { $0.underline }, "")
    }
    func test_toggleInlineCode_setsAndClears() {
        let v = canvas()
        selectParagraph(v, "h", 0, 5); v.toggleInlineCode()
        XCTAssertEqual(text(v, "h") { $0.inlineCode }, "Hello")
        selectParagraph(v, "h", 0, 5); v.toggleInlineCode()
        XCTAssertEqual(text(v, "h") { $0.inlineCode }, "")
    }
    func test_collapsedCaret_isNoOp() {
        let v = canvas()
        selectParagraph(v, "h", 2, 2); v.toggleBold()
        XCTAssertEqual(text(v, "h") { $0.bold }, "")
    }

    /// A 2×2 table (header row + body row) as the only block.
    private func tableCanvas() -> (DocumentCanvasView, TableBlockBox) {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Name"), cell("b", "Role")]),
                   Row(id: BlockID("r1"), cells: [cell("c", "Ada"), cell("d", "Eng")])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return (v, v.boxes[0] as! TableBlockBox)
    }

    func test_toggleBold_appliesToSelectedRow() {
        let (v, t) = tableCanvas()
        let start = t.cellTextStart(row: 1, column: 0)!
        v.setSelectionForTesting(anchor: start, head: start)   // caret in the table so a row can be selected
        v.selectTableRow(1)
        XCTAssertNotNil(v.tableSelection)
        v.toggleBold()                            // no text selection — drives off the row selection
        XCTAssertEqual(cellRuns(v, 1, 0).filter { $0.attributes.bold }.map { $0.text }.joined(), "Ada")
        XCTAssertEqual(cellRuns(v, 1, 1).filter { $0.attributes.bold }.map { $0.text }.joined(), "Eng")
    }

    func test_toggleItalic_appliesToSelectedColumn() {
        let (v, t) = tableCanvas()
        let start = t.cellTextStart(row: 0, column: 1)!
        v.setSelectionForTesting(anchor: start, head: start)
        v.selectTableColumn(1)
        XCTAssertNotNil(v.tableSelection)
        v.toggleItalic()                          // applies to every cell in column 1 (header + body)
        XCTAssertEqual(cellRuns(v, 0, 1).filter { $0.attributes.italic }.map { $0.text }.joined(), "Role")
        XCTAssertEqual(cellRuns(v, 1, 1).filter { $0.attributes.italic }.map { $0.text }.joined(), "Eng")
    }
}
#endif

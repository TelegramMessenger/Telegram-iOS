#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Backspace at the start of a paragraph directly after a table selects the whole table (first press),
/// and a second Backspace deletes it (replaced by an empty body paragraph in place).
final class CanvasTableBackspaceSelectTests: XCTestCase {
    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    /// [ "Top", table(1 row: Alpha|Beta), trailing paragraph (`botText`, empty string ⇒ empty paragraph) ]
    private func canvas(botText: String) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
            .paragraph(ParagraphBlock(id: BlockID("bot"),
                                      runs: botText.isEmpty ? [] : [TextRun(text: botText)])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 500); v.layoutIfNeeded()
        return v
    }
    private func botStart(_ v: DocumentCanvasView) -> Int {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bot")) }!.globalStart
    }
    private func collapse(_ v: DocumentCanvasView, at pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }
    private func hasTable(_ v: DocumentCanvasView) -> Bool {
        v.currentBlocks().contains { if case .table = $0 { return true } else { return false } }
    }
    private func paraTexts(_ v: DocumentCanvasView) -> [String] {
        v.currentBlocks().compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
    }

    func test_firstBackspace_nonEmptyParagraphAfterTable_selectsWholeTable_deletesNothing() {
        let v = canvas(botText: "Bot")
        let before = v.documentSizeValue
        collapse(v, at: botStart(v))
        v.deleteBackward()
        XCTAssertEqual(v.documentSizeValue, before, "first Backspace deletes nothing")
        XCTAssertTrue(hasTable(v), "table is still present")
        guard case .rows(let r)? = v.tableSelection?.kind else { return XCTFail("expected a whole-table rows selection") }
        XCTAssertEqual(r, 0...0, "the whole (single-row) table is selected")
        XCTAssertNotNil(v.activeTable(), "the caret is parked inside the table so activeTable() resolves")
    }

    func test_firstBackspace_emptyParagraphAfterTable_removesParagraph_andSelectsTable() {
        let v = canvas(botText: "")   // trailing EMPTY paragraph
        collapse(v, at: botStart(v))
        v.deleteBackward()
        XCTAssertTrue(hasTable(v), "table is still present")
        XCTAssertFalse(v.currentBlocks().contains {
            if case .paragraph(let p) = $0 { return p.id == BlockID("bot") } else { return false }
        }, "the empty trailing paragraph is removed")
        XCTAssertNotNil(v.tableSelection, "the whole table is structurally selected")
    }

    func test_secondBackspace_deletesSelectedTable_toEmptyParagraphInPlace() {
        let v = canvas(botText: "Bot")
        collapse(v, at: botStart(v))
        v.deleteBackward()               // selects the table
        v.deleteBackward()               // deletes it
        v.layoutIfNeeded()
        XCTAssertFalse(hasTable(v), "second Backspace deletes the table")
        XCTAssertEqual(paraTexts(v), ["Top", "", "Bot"], "table replaced by an empty paragraph in place; Bot preserved")
        XCTAssertNil(v.tableSelection, "the structural selection is cleared")
    }

    func test_tapAfterSelect_clearsSelection_withoutDeletingTable() {
        let v = canvas(botText: "Bot")
        collapse(v, at: botStart(v))
        v.deleteBackward()               // selects the table
        XCTAssertNotNil(v.tableSelection)
        v.clearStructuralSelections()    // stands in for any tap / caret set / other-input dismissal
        v.deleteBackward()               // a normal in-cell Backspace now, NOT a table delete
        XCTAssertTrue(hasTable(v), "clearing the selection means the next Backspace does not delete the table")
    }

    // The table's last-cell end — the head of the OS object-replacement range at the boundary below.
    private func tableLastCellEnd(_ v: DocumentCanvasView) -> Int {
        let cellB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        return cellB.globalStart + cellB.length
    }

    func test_firstBackspace_rangeForm_nonEmptyParagraph_selectsWholeTable() {
        let v = canvas(botText: "Bot")
        let before = v.documentSizeValue
        // iOS object-replacement range: [tableLastCellEnd … paragraphStart].
        v.setSelectionForTesting(anchor: tableLastCellEnd(v), head: botStart(v))
        v.deleteBackward()
        XCTAssertEqual(v.documentSizeValue, before, "range-form first Backspace deletes nothing")
        XCTAssertNotNil(v.tableSelection, "the whole table is structurally selected")
        XCTAssertTrue(hasTable(v))
    }

    func test_firstBackspace_rangeForm_emptyParagraph_removesParagraph_andSelectsTable() {
        let v = canvas(botText: "")
        v.setSelectionForTesting(anchor: tableLastCellEnd(v), head: botStart(v))
        v.deleteBackward()
        XCTAssertNotNil(v.tableSelection, "the whole table is structurally selected")
        XCTAssertFalse(v.currentBlocks().contains {
            if case .paragraph(let p) = $0 { return p.id == BlockID("bot") } else { return false }
        }, "the empty trailing paragraph is removed")
    }

    func test_genuineSelectionSpanningTable_stillDeletesAndMerges_notSelect() {
        let v = canvas(botText: "Bot")
        let top = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("top")) }!
        v.setSelectionForTesting(anchor: top.globalStart + 1, head: botStart(v) + 1)   // inside "Top" (after "T") — well before the table inside "Bot" (after "B"), local 1 (not the paragraph start)
        v.deleteBackward()
        XCTAssertNil(v.tableSelection, "a genuine spanning selection must not become a whole-table selection")
        XCTAssertFalse(hasTable(v), "the spanning delete drops the table and merges endpoints")
    }
}
#endif

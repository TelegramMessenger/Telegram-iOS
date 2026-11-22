#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasInsertTableTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    /// [ paragraph "Hello", table( header "Alpha" | "Beta" ) ]
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    func tables(_ v: DocumentCanvasView) -> [TableBlock] {
        v.currentBlocks().compactMap { if case .table(let t) = $0 { return t } else { return nil } }
    }
    func paraTexts(_ v: DocumentCanvasView) -> [String] {
        v.currentBlocks().compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
    }
    func caretAtEndOf(_ v: DocumentCanvasView, _ id: String) {
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
        v.setSelectionForTesting(anchor: r.globalStart + r.length, head: r.globalStart + r.length)
    }

    func test_insertTable_afterParagraph_insertsAndLandsCaretInHeaderCell() {
        let v = canvas()
        caretAtEndOf(v, "p")
        v.insertTable(rows: 2, columns: 2)
        let ts = tables(v)
        XCTAssertEqual(ts.count, 2, "a new table was added")
        XCTAssertEqual(ts[0].rowCount, 2)
        XCTAssertEqual(ts[0].columnCount, 2)
        XCTAssertTrue(ts[0].rows[0].isHeader)
        XCTAssertTrue(v.isInsideTable(v.head), "caret lands inside the new table")
    }

    func test_insertTable_whenUnfocused_doesNotStealFocus_butCaretIsInTable() {
        // Inserting a table must NOT grab first responder / pop the keyboard when the editor was unfocused.
        // The table is still inserted and the MODEL caret lands live in the new table (first cell), so a
        // later tap/focus operates on it — but the editor stays unfocused.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        window.makeKeyAndVisible()
        let v = canvas()
        window.addSubview(v)
        v.layoutIfNeeded()
        caretAtEndOf(v, "p")
        XCTAssertFalse(v.isFirstResponder, "precondition: not focused before the insert")
        v.insertTable(rows: 2, columns: 2)
        XCTAssertFalse(v.isFirstResponder, "inserting a table must NOT steal focus when the editor was unfocused")
        XCTAssertNotNil(v.activeTable(), "the caret is live inside the new table")
        // Hygiene: don't leak a key window into sibling tests.
        v.removeFromSuperview()
        window.isHidden = true
        window.resignKey()
    }

    func test_insertTable_midParagraph_splitsParagraph() {
        let v = canvas()
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("p")) }!
        v.setSelectionForTesting(anchor: r.globalStart + 2, head: r.globalStart + 2)   // mid "He|llo"
        v.insertTable(rows: 2, columns: 2)
        let texts = paraTexts(v)
        XCTAssertTrue(texts.contains("He"))
        XCTAssertTrue(texts.contains("llo"))
        XCTAssertEqual(tables(v).count, 2)
    }

    func test_insertTable_caretInsideCell_isNoOp() {
        let v = canvas()
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.setSelectionForTesting(anchor: a.globalStart + 1, head: a.globalStart + 1)
        let before = v.currentBlocks().count
        v.insertTable(rows: 2, columns: 2)
        XCTAssertEqual(v.currentBlocks().count, before, "no-op when the caret is inside a table cell")
        XCTAssertEqual(tables(v).count, 1)
    }

    func test_insertTable_onImageGap_isNoOp() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 50, height: 50))),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let img = v.boxes.first { $0 is MediaBlockBox }!
        v.setSelectionForTesting(anchor: img.nodeStart, head: img.nodeStart)
        let before = v.currentBlocks().count
        v.insertTable(rows: 2, columns: 2)
        XCTAssertEqual(v.currentBlocks().count, before, "no-op when the caret is on an image gap")
    }

    func test_insertTable_spanMathSelfConsistent() {
        let v = canvas()
        caretAtEndOf(v, "p")
        v.insertTable(rows: 2, columns: 2)
        let v2 = DocumentCanvasView()
        v2.setBlocks(v.currentBlocks(), width: 320)
        XCTAssertEqual(v.documentSizeValue, v2.documentSizeValue,
                       "token span math is self-consistent after insert")
    }

    func test_insertTable_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        caretAtEndOf(v, "p")
        let before = v.currentBlocks().count
        um.beginUndoGrouping(); v.insertTable(rows: 2, columns: 2); um.endUndoGrouping()
        XCTAssertEqual(v.currentBlocks().count, before + 1)
        um.undo()
        XCTAssertEqual(v.currentBlocks().count, before)
    }

    func test_insertTable_replacesSelection() {
        let v = canvas()
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("p")) }!
        v.setSelectionForTesting(anchor: r.globalStart + 2, head: r.globalStart + 5)   // select "llo" of "Hello"
        v.insertTable(rows: 2, columns: 2)
        let texts = paraTexts(v)
        XCTAssertTrue(texts.contains("He"), "selected text is replaced")
        XCTAssertFalse(texts.contains("Hello"))
        XCTAssertEqual(tables(v).count, 2)
        XCTAssertTrue(v.isInsideTable(v.head))
    }

    func test_insertTable_atParagraphStart_insertsBefore() {
        let v = canvas()
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("p")) }!
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart)   // caret at local 0
        v.insertTable(rows: 2, columns: 2)
        guard case .table = v.currentBlocks().first else { return XCTFail("table should be inserted before the first paragraph") }
        XCTAssertEqual(tables(v).count, 2)
    }

    func test_insertTable_onEmptyParagraph_replacesParagraph() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("e"), runs: []))], width: 320)   // a single empty paragraph
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart)
        v.insertTable(rows: 2, columns: 2)
        XCTAssertEqual(v.currentBlocks().count, 1, "the empty paragraph is replaced by the table, not left beside it")
        guard case .table = v.currentBlocks().first else { return XCTFail("the only block should be the table") }
        XCTAssertTrue(v.isInsideTable(v.head), "caret lands inside the new table")
    }

    func test_insertTable_onEmptyParagraphBetweenContent_replacesIt() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "A")])),
            .paragraph(ParagraphBlock(id: BlockID("e"), runs: [])),                  // empty middle paragraph
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "B")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.setSelectionForTesting(anchor: v.boxes[1].textStart, head: v.boxes[1].textStart)
        v.insertTable(rows: 2, columns: 2)
        XCTAssertEqual(v.currentBlocks().count, 3, "A | table | B — the empty paragraph is replaced, not split into two empties")
        XCTAssertEqual(paraTexts(v), ["A", "B"])
        XCTAssertEqual(tables(v).count, 1)
    }

    func test_insertTable_noOpInCell_registersNoUndo() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.setSelectionForTesting(anchor: a.globalStart + 1, head: a.globalStart + 1)
        v.insertTable(rows: 2, columns: 2)
        XCTAssertFalse(um.canUndo, "a no-op must not register an undo entry")
    }
}
#endif

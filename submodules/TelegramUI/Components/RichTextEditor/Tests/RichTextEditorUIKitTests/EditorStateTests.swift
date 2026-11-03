#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class EditorStateTests: XCTestCase {
    private func editor(_ blocks: [Block]) -> RichTextEditorView {
        let e = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        e.document = Document(blocks: blocks)
        e.layoutIfNeeded()
        return e
    }

    func test_currentState_topLevelParagraph_styleAndNotInTable() {
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), style: .heading1, runs: [TextRun(text: "Hi")]))])
        let pos = DocumentTextPosition(e.canvas.boxes[0].textStart + 1)
        e.canvas.selectedTextRange = DocumentTextRange(pos, pos)
        let s = e.currentState()
        XCTAssertEqual(s.paragraphStyle, .heading1)
        XCTAssertFalse(s.isInTable)
        XCTAssertNil(s.listMarker)
        XCTAssertFalse(s.hasSelection)
    }

    func test_currentState_hasSelection() {
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        let lo = DocumentTextPosition(e.canvas.boxes[0].textStart)
        let hi = DocumentTextPosition(e.canvas.boxes[0].textStart + 3)
        e.canvas.selectedTextRange = DocumentTextRange(lo, hi)
        XCTAssertTrue(e.currentState().hasSelection)
    }

    func test_currentState_listMarker() {
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), list: ListMembership(marker: .bullet, level: 0),
                                                  runs: [TextRun(text: "Item")]))])
        let pos = DocumentTextPosition(e.canvas.boxes[0].textStart + 1)
        e.canvas.selectedTextRange = DocumentTextRange(pos, pos)
        XCTAssertEqual(e.currentState().listMarker, .bullet)
    }

    func test_currentState_caretInTableCell_isInTableTrue_styleNil() {
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [
                Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "A")]))]),
                Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "B")]))])])])
        let e = editor([.table(table)])
        let t = e.canvas.boxes[0] as! TableBlockBox
        let cellStart = t.cellTextStart(row: 0, column: 0)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(cellStart), DocumentTextPosition(cellStart))
        let s = e.currentState()
        XCTAssertTrue(s.isInTable)
        XCTAssertNil(s.paragraphStyle, "in a cell there is no top-level paragraph style")
    }

    func test_currentState_caretInCodeBlock_isCodeBlockTrue_styleNil() {
        let e = editor([.code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x = 1")]))])
        let pos = DocumentTextPosition(e.canvas.boxes[0].textStart + 1)
        e.canvas.selectedTextRange = DocumentTextRange(pos, pos)
        let s = e.currentState()
        XCTAssertTrue(s.isCodeBlock, "caret inside a code block reports isCodeBlock")
        XCTAssertNil(s.paragraphStyle, "a code block is not a top-level paragraph style")
    }

    func test_currentState_bodyParagraph_isCodeBlockFalse() {
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        let pos = DocumentTextPosition(e.canvas.boxes[0].textStart + 1)
        e.canvas.selectedTextRange = DocumentTextRange(pos, pos)
        XCTAssertFalse(e.currentState().isCodeBlock, "a body paragraph is not a code block")
    }

    func test_currentState_selectionWithinParagraph_isTextOnly() {
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        let lo = e.canvas.boxes[0].textStart, hi = lo + 3
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(lo), DocumentTextPosition(hi))
        XCTAssertTrue(e.currentState().selectionIsTextOnly, "a selection over plain paragraph text is text-only")
    }

    func test_currentState_collapsedCaret_isNotTextOnly() {
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        let pos = DocumentTextPosition(e.canvas.boxes[0].textStart + 1)
        e.canvas.selectedTextRange = DocumentTextRange(pos, pos)
        XCTAssertFalse(e.currentState().selectionIsTextOnly, "a collapsed caret has no selection, so it is not text-only")
    }

    func test_currentState_selectionAcrossParagraphs_isTextOnly() {
        let e = editor([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "First")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Second")])),
        ])
        let lo = DocumentTextPosition(e.canvas.boxes[0].textStart)
        let hi = DocumentTextPosition(e.canvas.boxes[1].textStart + 2)
        e.canvas.selectedTextRange = DocumentTextRange(lo, hi)
        XCTAssertTrue(e.currentState().selectionIsTextOnly, "a multi-paragraph text selection is text-only")
    }

    func test_currentState_selectionSpanningMedia_isNotTextOnly() {
        let e = editor([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "First")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x",
                              naturalSize: Size2D(width: 100, height: 60), caption: [])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Second")])),
        ])
        let lo = DocumentTextPosition(e.canvas.boxes[0].textStart)
        let hi = DocumentTextPosition(e.canvas.boxes[2].textStart + 2)
        e.canvas.selectedTextRange = DocumentTextRange(lo, hi)
        XCTAssertFalse(e.currentState().selectionIsTextOnly,
                       "a selection spanning a media block (both endpoints in paragraphs) is not text-only")
    }

    func test_currentState_selectionInsideTableCell_isNotTextOnly() {
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [
                Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "AB")]))]),
                Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "CD")]))])])])
        let e = editor([.table(table)])
        let t = e.canvas.boxes[0] as! TableBlockBox
        let cellStart = t.cellTextStart(row: 0, column: 0)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(cellStart), DocumentTextPosition(cellStart + 2))
        XCTAssertFalse(e.currentState().selectionIsTextOnly, "a selection inside a table cell is not text-only")
    }

    func test_currentState_boldOverSelection() {
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        let lo = e.canvas.boxes[0].textStart, hi = lo + 5
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(lo), DocumentTextPosition(hi))
        XCTAssertFalse(e.currentState().bold, "plain text is not bold")
        e.toggleBold()
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(lo), DocumentTextPosition(hi))
        XCTAssertTrue(e.currentState().bold, "after toggling bold over the selection, state.bold is true")
    }

    func test_currentState_boldNonUniformSelection_isFalse() {
        var boldAttr = CharacterAttributes(); boldAttr.bold = true
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [
            TextRun(text: "AB", attributes: boldAttr),
            TextRun(text: "cd"),
        ]))])
        let lo = e.canvas.boxes[0].textStart, hi = lo + 4
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(lo), DocumentTextPosition(hi))
        XCTAssertFalse(e.currentState().bold, "a partly-bold selection is not uniformly bold")
    }

    func test_currentState_plainHeadingNotReportedAsBold() {
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), style: .heading1, runs: [TextRun(text: "Title")]))])
        let pos = DocumentTextPosition(e.canvas.boxes[0].textStart + 1)
        e.canvas.selectedTextRange = DocumentTextRange(pos, pos)
        XCTAssertFalse(e.currentState().bold, "a plain heading is regular weight, so Bold is not active")
    }

    func test_currentState_boldAtCaretInBoldRun() {
        var boldAttr = CharacterAttributes(); boldAttr.bold = true
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Bold", attributes: boldAttr)]))])
        let pos = DocumentTextPosition(e.canvas.boxes[0].textStart + 2)   // collapsed caret inside the bold run
        e.canvas.selectedTextRange = DocumentTextRange(pos, pos)
        XCTAssertTrue(e.currentState().bold, "a collapsed caret inside a bold run reports bold (inherited typing format)")
    }

    func test_currentState_spoilerOverSelection() {
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        let lo = e.canvas.boxes[0].textStart, hi = lo + 5
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(lo), DocumentTextPosition(hi))
        XCTAssertFalse(e.currentState().spoiler, "plain text is not a spoiler")
        e.toggleSpoiler()
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(lo), DocumentTextPosition(hi))
        XCTAssertTrue(e.currentState().spoiler, "after toggling spoiler over the selection, state.spoiler is true")
    }

    func test_currentState_spoilerNonUniformSelection_isFalse() {
        var spoilerAttr = CharacterAttributes(); spoilerAttr.spoiler = true
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [
            TextRun(text: "AB", attributes: spoilerAttr),
            TextRun(text: "cd"),
        ]))])
        let lo = e.canvas.boxes[0].textStart, hi = lo + 4
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(lo), DocumentTextPosition(hi))
        XCTAssertFalse(e.currentState().spoiler, "a partly-spoilered selection is not uniformly a spoiler")
    }

    func test_currentState_spoilerAtCaretInSpoilerRun() {
        var spoilerAttr = CharacterAttributes(); spoilerAttr.spoiler = true
        let e = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Secret", attributes: spoilerAttr)]))])
        let pos = DocumentTextPosition(e.canvas.boxes[0].textStart + 3)   // collapsed caret inside the spoiler run
        e.canvas.selectedTextRange = DocumentTextRange(pos, pos)
        XCTAssertTrue(e.currentState().spoiler, "a collapsed caret inside a spoiler run reports spoiler (inherited typing format)")
    }
}
#endif

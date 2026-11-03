#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasFacadeTests: XCTestCase {
    func test_multiParagraphRoundTrips() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let doc = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("a"), style: .heading1, runs: [TextRun(text: "Title")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Body one.")])),
            .paragraph(ParagraphBlock(id: BlockID("c"), runs: [TextRun(text: "Body two.")])),
        ])
        editor.document = doc
        editor.layoutIfNeeded()
        let out = editor.document
        XCTAssertEqual(out.blocks.count, 3)
        guard case .paragraph(let p0) = out.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p0.style, .heading1)
        XCTAssertEqual(out.blocks.compactMap { if case .paragraph(let p) = $0 { return p.runs.map(\.text).joined() } else { return nil } },
                       ["Title", "Body one.", "Body two."])
    }

    /// `insertInlineButton` is COMPOSED from the canvas's own verbs — type the label, select it,
    /// `makeSelectionInlineButton`, `replaceInlineButton` — because the canvas is closed to the branch
    /// that added the verb; this pins the composition end to end, authored button included.
    func test_insertInlineButtonPutsAnAuthoredPillAtTheCaret() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "let  stand")]))])
        editor.layoutIfNeeded()
        let start = editor.canvas.boxes[0].textStart
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(start + 4), DocumentTextPosition(start + 4))
        let button = ButtonRef(label: [TextRun(text: "Go")], action: .url("https://example.com"))
        editor.insertInlineButton(button)
        guard case let .paragraph(p) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.runs.map(\.text).joined(), "let \u{FFFC} stand")
        XCTAssertEqual(p.runs.compactMap(\.attributes.button), [button])
    }

    func test_nonParagraphBlocksArePreserved() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 10)],
                               rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("c"))])])
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "P")])),
                                     .table(table)])
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.document.blocks.contains { if case .table = $0 { return true } else { return false } })
    }

    func test_interleavedTableSurvivesStructuralEdits() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 10)],
                               rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("c"))])])
        editor.document = Document(
            blocks: [
                .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")])),
                .table(table),
                .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")])),
            ])
        editor.layoutIfNeeded()

        // Split "Alpha" via the canvas, then merge it back via Backspace.
        editor.canvas.selectedTextRange = DocumentTextRange(
            DocumentTextPosition(editor.canvas.boxes[0].textStart + 2),
            DocumentTextPosition(editor.canvas.boxes[0].textStart + 2))
        editor.canvas.insertText("\n")

        let afterSplit = editor.document
        XCTAssertEqual(afterSplit.blocks.count, 4)                       // 3 paragraphs + table, none lost
        XCTAssertTrue(afterSplit.blocks.contains { if case .table = $0 { return true } else { return false } })
        // Table stays in its original document position (canvas renders it in place at blocks[2],
        // after the two halves of the split paragraph; blocks[1] = preservedBlocks anchor is retired).
        guard case .table = afterSplit.blocks[2] else { return XCTFail("table not at expected position after split") }

        // Now merge the two halves back; the table must still be present exactly once.
        // boxes[1] = BlockBox("pha") — the second paragraph half after the split.
        editor.canvas.selectedTextRange = DocumentTextRange(
            DocumentTextPosition(editor.canvas.boxes[1].textStart),
            DocumentTextPosition(editor.canvas.boxes[1].textStart))
        editor.canvas.deleteBackward()
        let afterMerge = editor.document
        XCTAssertEqual(afterMerge.blocks.filter { if case .table = $0 { return true } else { return false } }.count, 1)
    }

    func test_facadeSetList_appliesAcrossSelection() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(
            blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Item")]))])
        editor.layoutIfNeeded()
        editor.selectAll()
        editor.setList(.bullet)
        guard case .paragraph(let p) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.list?.marker, .bullet)
    }

    func test_roundTrip_preservesLeadingAndAdjacentNonParagraphBlocks() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        func table(_ id: String) -> Block {
            .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 10)],
                              rows: [Row(id: BlockID(id + "r"), cells: [Cell(id: BlockID(id + "c"))])]))
        }
        editor.document = Document(
            blocks: [
                table("t0"),                                                       // leading non-paragraph
                .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")])),
                table("t1"), table("t2"),                                          // two adjacent at same anchor
                .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")])),
            ])
        editor.layoutIfNeeded()
        let out = editor.document.blocks
        func isTable(_ b: Block, _ id: String) -> Bool {
            if case .table(let t) = b { return t.id == BlockID(id) } else { return false }
        }
        XCTAssertEqual(out.count, 5)
        XCTAssertTrue(isTable(out[0], "t0"))
        if case .paragraph(let p) = out[1] { XCTAssertEqual(p.id, BlockID("a")) } else { XCTFail("out[1] should be paragraph a") }
        XCTAssertTrue(isTable(out[2], "t1"))
        XCTAssertTrue(isTable(out[3], "t2"))
        if case .paragraph(let p) = out[4] { XCTAssertEqual(p.id, BlockID("b")) } else { XCTFail("out[4] should be paragraph b") }
    }

    func test_imageRoundTripsThroughCanvas_withPreservedTable() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 10)],
                               rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("c"))])])
        editor.document = Document(
            blocks: [
                .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")])),
                .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                                  caption: [TextRun(text: "Cap")])),
                .table(table),
                .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")])),
            ])
        editor.layoutIfNeeded()
        let out = editor.document.blocks
        XCTAssertEqual(out.count, 4)
        guard case .paragraph = out[0], case .media(let img) = out[1], case .table = out[2], case .paragraph = out[3]
        else { return XCTFail("order/type not preserved") }
        XCTAssertEqual(img.caption.map(\.text).joined(), "Cap")
    }

    func test_facadeInsertMedia_addsMediaBlock() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.document = Document(
            blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]))])
        editor.layoutIfNeeded()
        editor.selectAll()
        editor.insertMedia(mediaID: "m1", naturalSize: CGSize(width: 60, height: 40), kind: .image)
        XCTAssertTrue(editor.document.blocks.contains { if case .media = $0 { return true } else { return false } })
    }

    func test_tableRoundTripsThroughCanvas_inOrder() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 340, height: 600))
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [
                Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "A")]))]),
                Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "B")]))])])])
        editor.document = Document(
            blocks: [
                .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Above")])),
                .table(table),
                .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Below")])),
            ])
        editor.layoutIfNeeded()
        let out = editor.document.blocks
        XCTAssertEqual(out.count, 3)
        guard case .paragraph = out[0], case .table(let t) = out[1], case .paragraph = out[2]
        else { return XCTFail("order/type not preserved") }
        XCTAssertEqual(t.rowCount, 1); XCTAssertEqual(t.columnCount, 2)
    }
}
#endif

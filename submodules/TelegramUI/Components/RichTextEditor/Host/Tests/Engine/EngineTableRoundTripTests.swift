import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

@available(iOS 18.4, *)
final class EngineTableRoundTripTests: XCTestCase {
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

    private func cell(_ id: String, _ text: String, header: Bool = false,
                      colspan: Int = 1, rowspan: Int = 1) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID("\(id)p"), runs: [TextRun(text: text)]))],
             background: header ? nil : RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.2),
             horizontalAlignment: .left, verticalAlignment: .middle, isHeader: header,
             colspan: colspan, rowspan: rowspan)
    }
    private func table() -> TableBlock {
        TableBlock(id: BlockID("t0"),
                   columns: [ColumnSpec(width: 120), ColumnSpec(width: 80)],
                   rows: [Row(id: BlockID("r0"), height: 30, cells: [cell("a", "A", header: true), cell("b", "B", header: true)]),
                          Row(id: BlockID("r1"), cells: [cell("c", "C", colspan: 2)])],
                   compact: true, bordered: false)
    }
    private func cellText(_ table: TableBlock, _ r: Int, _ c: Int) -> String? {
        table.rows[r].cells[c].blocks.first?.asParagraph?.runs.map(\.text).joined()
    }

    func test_aTableSurvivesBeingSetAndReadBack_withEverythingButTheText() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .table(table()),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
        guard editor.document.blocks.count == 3, case let .table(back) = editor.document.blocks[1] else {
            return XCTFail("got \(editor.document.blocks)")
        }
        XCTAssertEqual(back.columns.map(\.width), [120, 80])
        XCTAssertTrue(back.compact); XCTAssertFalse(back.bordered)
        XCTAssertEqual(back.rows[0].height, 30)
        XCTAssertTrue(back.rows[0].cells[0].isHeader)
        XCTAssertEqual(back.rows[1].cells[0].colspan, 2)
        XCTAssertEqual(back.rows[1].cells[0].background, RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.2),
                       "a non-header cell keeps its background (headers are made without one above)")
        XCTAssertEqual(back.rows[0].cells[0].verticalAlignment, .middle)
        XCTAssertEqual([cellText(back, 0, 0), cellText(back, 0, 1), cellText(back, 1, 0)], ["A", "B", "C"])
        XCTAssertEqual(editor.currentRoles.count, 5, "p0 + three cells + p1")
    }

    func test_aNewlineInACellIsALineSeparatorInTheEngineAndANewlineInTheModel() {
        var t = table()
        t.rows[1].cells[0].blocks = [.paragraph(ParagraphBlock(id: BlockID("cp"), runs: [TextRun(text: "line one\nline two")]))]
        editor.document = Document(blocks: [.table(t)])
        let engineTexts = editor.engine.attributedBlocks.map(\.string)
        XCTAssertEqual(engineTexts[2], "line one\u{2028}line two")
        XCTAssertFalse(engineTexts.contains { $0.contains("\n") }, "the engine raises on an interior U+000A")
        guard case let .table(back) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(cellText(back, 1, 0), "line one\nline two")
    }

    func test_aMultiBlockCellIsFlattenedToOneParagraph() {
        var t = table()
        t.rows[1].cells[0].blocks = [
            .paragraph(ParagraphBlock(id: BlockID("x1"), runs: [TextRun(text: "first")])),
            .paragraph(ParagraphBlock(id: BlockID("x2"), runs: [TextRun(text: "second")])),
        ]
        editor.document = Document(blocks: [.table(t)])
        guard case let .table(back) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(back.rows[1].cells[0].blocks.count, 1)
        XCTAssertEqual(cellText(back, 1, 0), "first\nsecond")
    }

    func test_anEmptyCellRoundTripsEmptyAndTypesAtTheCellSize() {
        var t = table()
        t.rows[1].cells[0].blocks = []
        editor.document = Document(blocks: [.table(t)])
        guard case let .table(back) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(cellText(back, 1, 0), "")
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 4, length: 0)   // "A\nB\n" → the empty cell
        editor.engine.insertText("z")
        let font = editor.engine.attributedBlocks[2].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, StyleSheet.tableCells.metrics.body.size, "typed into an empty cell at the cell size")
    }

    func test_aRowlessTableIsRescuedAsAnEmptyOneByOne() {
        editor.document = Document(blocks: [.table(TableBlock(id: BlockID("empty")))])
        guard case let .table(back) = editor.document.blocks.first else { return XCTFail("the table vanished") }
        XCTAssertEqual(back.rowCount, 1); XCTAssertEqual(back.columnCount, 1)
    }

    func test_cellTextRendersAtTheTableCellSizeAndHeaderCellsBold() {
        editor.document = Document(blocks: [.table(table())])
        let blocks = editor.engine.attributedBlocks
        let a = blocks[0].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let c = blocks[2].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(c?.pointSize, StyleSheet.tableCells.metrics.body.size)
        XCTAssertTrue(a?.fontDescriptor.symbolicTraits.contains(.traitBold) == true, "a header cell renders bold")
        guard case let .table(back) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(back.rows[0].cells[0].blocks.first?.asParagraph?.runs.first?.attributes.bold ?? false, false,
                       "…but the bold is display-only and never reaches the model")
    }
}

import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

@available(iOS 18.4, *)
final class EngineTableLayoutTests: XCTestCase {
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
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID("\(id)p"), runs: [TextRun(text: text)]))])
    }
    private func twoByTwo(_ texts: [String] = ["a", "b", "c", "d"]) -> TableBlock {
        TableBlock(id: BlockID("t0"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                   rows: [Row(id: BlockID("r0"), cells: [cell("a", texts[0]), cell("b", texts[1])]),
                          Row(id: BlockID("r1"), cells: [cell("c", texts[2]), cell("d", texts[3])])])
    }

    func test_cellsAreLaidOutOnAGridAndTheParagraphAfterSitsBelowIt() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .table(twoByTwo()),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
        editor.layoutIfNeeded()
        let a = editor.engine.id_frameForBlock(at: 1), b = editor.engine.id_frameForBlock(at: 2)
        let c = editor.engine.id_frameForBlock(at: 3), after = editor.engine.id_frameForBlock(at: 5)
        XCTAssertEqual(a.minY, b.minY, accuracy: 0.5, "a row shares one y")
        XCTAssertGreaterThan(b.minX, a.maxX - 1, "b is to the right of a")
        XCTAssertGreaterThan(c.minY, a.maxY - 1, "c is below a")
        XCTAssertEqual(c.minX, a.minX, accuracy: 0.5, "c is under a")
        XCTAssertGreaterThan(after.minY, c.maxY, "the paragraph after the table sits below the grid")
        guard let grid = editor.tableGrids[BlockID("t0")] else { return XCTFail("no grid solved") }
        XCTAssertEqual(a.width, grid.columnWidths[0] - 6 - 7, accuracy: 0.5, "text width = column − side insets")
    }

    func test_theSecondPassPushesFramesOnceAndThenNothing() {
        editor.document = Document(blocks: [.table(twoByTwo())])
        editor.layoutIfNeeded()
        let settled = editor.engine.blockFrames
        editor.syncTableFrames()
        XCTAssertEqual(editor.engine.blockFrames as NSDictionary?, settled as NSDictionary?, "a converged layout pushes nothing")
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.blockFrames as NSDictionary?, settled as NSDictionary?)
    }

    func test_aTallCellGrowsItsWholeRow() {
        let longText = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen"
        editor.document = Document(blocks: [.table(twoByTwo(["a", longText, "c", "d"]))])
        editor.layoutIfNeeded()
        let a = editor.engine.id_frameForBlock(at: 0), b = editor.engine.id_frameForBlock(at: 1)
        let c = editor.engine.id_frameForBlock(at: 2)
        // Frames carry the ROW height after the second pass; the wrap shows in the used size.
        XCTAssertEqual(a.height, b.height, accuracy: 0.5, "one row, one height")
        XCTAssertGreaterThan(editor.engine.id_usedSizeForBlock(at: 1).height,
                             editor.engine.id_usedSizeForBlock(at: 0).height + 10, "b wraps")
        XCTAssertGreaterThan(c.minY, b.maxY - 1, "c sits below the WRAPPED b, i.e. the row grew")
        let grid = editor.tableGrids[BlockID("t0")]!
        XCTAssertEqual(grid.rowHeights[0], editor.engine.id_usedSizeForBlock(at: 1).height + 28, accuracy: 0.5)
    }

    func test_typingIntoACellReflowsTheRowsBelow() {
        editor.document = Document(blocks: [.table(twoByTwo())])
        editor.layoutIfNeeded()
        let cBefore = editor.engine.id_frameForBlock(at: 2)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 1, length: 0)   // end of "a"
        editor.engine.insertText(" one two three four five six seven eight nine ten eleven twelve")
        editor.layoutIfNeeded()
        XCTAssertGreaterThan(editor.engine.id_frameForBlock(at: 2).minY, cBefore.minY + 10, "c moved down")
    }

    func test_theGapAboveATableIsTheRhythmsAndTheGapBelowBelongsToTheNextBlock() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .table(twoByTwo()),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
        editor.layoutIfNeeded()
        let metrics = editor.bridge.styleSheet.metrics
        let expectedAbove = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .table, kind: .topLevel, metrics: metrics)
        let before = editor.engine.id_frameForBlock(at: 0)
        let grid = editor.tableGrids[BlockID("t0")]!
        let a = editor.engine.id_frameForBlock(at: 1)
        // a's text origin = table top + border + top inset (14); the table top = before.maxY + gap.
        // `before.maxY` is a frame bottom, one trailing line-box overhang below the paragraph's
        // glyphs; the rhythm gives that band back, so the table sits `expectedAbove` below the TEXT
        // rather than below the box (2026-09-15).
        // `before.maxY` is also one baseline drop HIGHER than V2's item bottom: the lift makes a
        // text block's canvas exactly its glyph box, so its bottom edge is the last descender where
        // V2's item runs `drop` further. The table did not move — it is PLACED, which the lift
        // excludes — so the drop is added back here rather than being a change in the gap (2026-09-16).
        XCTAssertEqual(a.minY - (grid.borderWidth + 14),
                       before.maxY + editor.v2BaselineDrop(atRole: 0) + expectedAbove
                           - editor.trailingLineBoxOverhang(atRole: 0),
                       accuracy: 0.5)
    }
}

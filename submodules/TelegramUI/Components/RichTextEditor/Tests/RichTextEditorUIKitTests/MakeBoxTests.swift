#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

/// Regression guard for the shared `makeBox` factory (Task 3 of the block-quote rewrite).
/// Asserts that the document root and table cells build the same box TYPES as before the refactor.
final class MakeBoxTests: XCTestCase {

    // MARK: - Root builds all box types

    func test_root_buildsAllBoxTypes_unchanged() {
        let canvas = DocumentCanvasView()
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        canvas.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "a")])),
            .code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "x")])),
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "q")])),
        ], width: 320)
        XCTAssertTrue(canvas.boxes[0] is BlockBox,       "paragraph → BlockBox")
        XCTAssertTrue(canvas.boxes[1] is CodeBlockBox,   "code → CodeBlockBox")
        XCTAssertTrue(canvas.boxes[2] is PullQuoteBox,   "pullQuote → PullQuoteBox")
    }

    // MARK: - Cell restriction preserved

    func test_tableCell_stillRestrictsToParagraphAndMedia() {
        // A 1×1 table whose single cell holds [paragraph, code].
        // After the makeBox refactor the cell must still yield exactly ONE box (the paragraph)
        // — the code block must be dropped by the restriction guard.
        let cell = Cell(id: BlockID("cell"), blocks: [
            .paragraph(ParagraphBlock(id: BlockID("para"), runs: [TextRun(text: "hello")])),
            .code(CodeBlock(id: BlockID("code"), runs: [TextRun(text: "x")])),
        ])
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 200)],
            rows: [Row(id: BlockID("r0"), cells: [cell])]
        )
        let canvas = DocumentCanvasView()
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        canvas.setBlocks([.table(table)], width: 320)
        canvas.layoutIfNeeded()

        let tableBox = canvas.boxes.first as! TableBlockBox
        let cellStack = tableBox.cells[0][0]
        // The paragraph is built; the code block is dropped (restriction preserved).
        XCTAssertEqual(cellStack.boxes.count, 1, "cell stack must have exactly 1 box (code block dropped)")
        XCTAssertTrue(cellStack.boxes[0] is BlockBox,   "the surviving box is the paragraph BlockBox")
    }
}
#endif

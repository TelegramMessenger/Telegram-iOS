#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class EmojiTableHostingTests: XCTestCase {
    private func canvasWithTableEmoji() -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.emojiViewProvider = { id, size in
            let v = TestEmojiView(frame: CGRect(origin: .zero, size: size)); v.accessibilityIdentifier = id; return v
        }
        // One 1×2 table (row 0 header). Cell (0,0) gets the caret.
        // Cells default to CENTER alignment (Task 2, per-cell alignment); this test asserts the emoji's
        // frame is content-local (small x, left of the table origin), which only holds for a left-aligned
        // cell — force `.left` here so the coordinate-system assertion below stays meaningful.
        let cell = { (id: String) in
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p")))],
                 horizontalAlignment: .left) }
        let table = TableBlock(id: BlockID("t1"),
                               columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
                               rows: [Row(id: BlockID("r1"), cells: [cell("c1"), cell("c2")])])
        c.setBlocks([.table(table)], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        c.simulateParentLayout()
        // Place the caret in cell (0,0) and insert an emoji there.
        if let t = c.boxes.first as? TableBlockBox, let start = t.cellTextStart(row: 0, column: 0) {
            c.setSelectionForTesting(anchor: start, head: start)
        }
        c.insertEmoji(id: "star", altText: nil)
        c.layoutIfNeeded()
        return c
    }

    func test_cellEmoji_isHostedInsideTableContentView() {
        let c = canvasWithTableEmoji()
        let view = c.firstHostedEmojiForTesting
        XCTAssertTrue(view?.superview is TableContentView,
                      "a cell emoji must be parented in the table's scrolling content view so it rides scroll")
    }

    func test_cellEmoji_frameIsContentLocal() {
        let c = canvasWithTableEmoji()
        guard let t = c.boxes.first as? TableBlockBox, let view = c.firstHostedEmojiForTesting else {
            return XCTFail("missing table/emoji")
        }
        // Content-local x = canvas-space x − table.frame.minX, so it must be SMALLER than table.frame.minX
        // itself (the cell's left border+padding < the page margin). A raw canvas coordinate would be
        // table.frame.minX + border + padding, i.e. >= table.frame.minX — this assertion fails for it.
        XCTAssertLessThan(view.frame.minX, t.frame.minX,
                          "frame is content-local (canvas rect − table.frame.origin), not canvas-space")
        XCTAssertFalse(view.frame.isEmpty)
    }
}
#endif

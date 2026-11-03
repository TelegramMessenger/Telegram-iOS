#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Vertical (Up/Down) keyboard navigation from an image's gap caret. Previously a no-op that stranded
/// the caret on the gap (a low-contrast bar over the image → "stuck / hidden"); now Up escapes to the
/// block above and Down drops into the caption.
final class ImageGapNavTests: XCTestCase {
    private func tealProvider() -> (String) -> UIImage? {
        { _ in UIGraphicsImageRenderer(size: CGSize(width: 80, height: 50)).image { c in
            UIColor.darkGray.setFill(); c.fill(CGRect(x: 0, y: 0, width: 80, height: 50)) } }
    }
    /// ["Above", image(caption "Cap"), "Below"]
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = tealProvider()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Above")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                              caption: [TextRun(text: "Cap")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Below")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }
    private func upDown(_ v: DocumentCanvasView, from pos: Int, down: Bool) -> Int {
        (v.position(from: DocumentTextPosition(pos), in: down ? .down : .up, offset: 1) as! DocumentTextPosition).offset
    }

    func test_upFromImageGap_movesToBlockAbove() {
        let v = canvas(); let img = v.boxes[1] as! MediaBlockBox
        let up = upDown(v, from: img.nodeStart, down: false)
        XCTAssertNotEqual(up, img.nodeStart, "Up from the image gap must move (was a no-op)")
        XCTAssertTrue(v.isRenderablePosition(up), "the destination MUST be a renderable caret slot (else the caret hides)")
        let above = v.boxes[0]
        XCTAssertEqual(up, above.textStart + above.textLength,
                       "Up lands at the END of the block above (structural neighbour — always renderable)")
    }

    func test_downFromImageGap_movesIntoCaption() {
        let v = canvas(); let img = v.boxes[1] as! MediaBlockBox
        let down = upDown(v, from: img.nodeStart, down: true)
        XCTAssertNotEqual(down, img.nodeStart, "Down from the image gap must move (was a no-op)")
        XCTAssertTrue(v.isRenderablePosition(down), "the destination MUST be renderable")
        XCTAssertEqual(down, img.textStart, "Down lands at the caption start (structural neighbour)")
    }

    func test_selectedTextRangeSetter_firesOnSelectionChange() {
        // The OS moves the caret (hardware arrows) through the selectedTextRange setter, which — unlike a
        // tap's setCaret — can land it off-screen (Up out of a tall image → block above). The host hook
        // must fire so the façade can scroll that destination into view.
        let v = canvas()
        var fired = false
        v.onSelectionChange = { fired = true }
        let p = DocumentTextPosition(v.boxes[0].textStart)
        v.selectedTextRange = DocumentTextRange(p, p)
        XCTAssertTrue(fired, "selectedTextRange setter notifies the host to scroll the caret into view")
    }

    /// Builds [Heading paragraph, `cols`-column / 2-row table (row 0 header), `image`] at `width`.
    private func tableThenImage(cols: Int, image: MediaBlock, width: CGFloat = 390) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = tealProvider()
        func cell(_ id: String, _ t: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
        }
        let columns = (0..<cols).map { _ in ColumnSpec(width: 100) }
        let header = Row(id: BlockID("r0"), isHeader: true, cells: (0..<cols).map { cell("h\($0)", "H\($0)") })
        let body = Row(id: BlockID("r1"), cells: (0..<cols).map { cell("c\($0)", "C\($0)") })
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Heading")])),
            .table(TableBlock(id: BlockID("t"), columns: columns, rows: [header, body])),
            .media(image),
        ], width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }
    private func fullBleedImage() -> MediaBlock {   // no displayWidth ⇒ fills the canvas; leading edge at x≈0
        MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                   caption: [TextRun(text: "Cap")])
    }

    func test_upFromImageGap_aboveTable_landsInTableLastCell() {
        // [paragraph, table, image] — Up from the image gap must ENTER the table's LAST ROW, not skip the
        // table (whose node boundary is non-renderable) to the heading before it.
        let v = tableThenImage(cols: 2, image: fullBleedImage())
        let img = v.boxes[2] as! MediaBlockBox
        let table = v.boxes[1] as! TableBlockBox
        let up = upDown(v, from: img.nodeStart, down: false)
        XCTAssertTrue(v.isRenderablePosition(up), "Up must land on a renderable slot, not the table's degenerate boundary")
        XCTAssertEqual(table.cellLocation(containing: up)?.row, table.rowCount - 1,
                       "Up from the gap enters a cell in the table's LAST row, not the heading before the table")
    }

    func test_upFromImageGap_aboveFullBleedImage_landsInColumn0() {
        // The gap caret is drawn at the image's leading edge (`caretRect` → `mediaRect().minX`). A full-bleed
        // image's leading edge is the page's left, so Up lands under it = column 0 — the common real-world
        // case. (A regression to the earlier `midX` mapping would land in the MIDDLE column instead.)
        let v = tableThenImage(cols: 3, image: fullBleedImage())
        let img = v.boxes[2] as! MediaBlockBox
        let table = v.boxes[1] as! TableBlockBox
        let up = upDown(v, from: img.nodeStart, down: false)
        XCTAssertTrue(v.isRenderablePosition(up), "Up must land on a renderable slot")
        XCTAssertEqual(up, table.cellTextStart(row: table.rowCount - 1, column: 0),
                       "Up lands under the gap caret's leading edge = column 0 for a full-bleed image")
        XCTAssertNotEqual(up, table.cellTextStart(row: table.rowCount - 1, column: 1),
                          "and specifically NOT the middle column the old `midX` mapping produced")
    }

    func test_upFromImageGap_aboveTable_alignedImage_landsUnderGapColumn() {
        // A narrow RIGHT-aligned image's leading edge (`mediaRect().minX`) sits over the LAST column of a
        // 3-column table, so Up lands there (column 2) — proving the column genuinely FOLLOWS the gap caret's
        // drawn x and is not hard-coded to column 0. (80pt-wide, right-aligned over a 390pt canvas →
        // minX ≈ 310, inside the 3rd column's band — boundary-free.)
        let rightImg = MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                                  displayWidth: 80, alignment: .right, caption: [TextRun(text: "Cap")])
        let v = tableThenImage(cols: 3, image: rightImg)
        let img = v.boxes[2] as! MediaBlockBox
        let table = v.boxes[1] as! TableBlockBox
        let up = upDown(v, from: img.nodeStart, down: false)
        XCTAssertTrue(v.isRenderablePosition(up), "Up must land on a renderable slot")
        XCTAssertEqual(up, table.cellTextStart(row: table.rowCount - 1, column: 2),
                       "Up lands in the last column, under the right-aligned image's leading edge")
        XCTAssertNotEqual(up, table.cellTextStart(row: table.rowCount - 1, column: 0),
                          "the column FOLLOWS the gap caret's x — not the old hard-coded column 0")
    }

    func test_selectImage_movesOSCaretToGap_soArrowNavStartsFromImage() {
        // Tapping an image parks the caret on its gap. The OS only re-reads `selectedTextRange` after the
        // input delegate is notified — without `selectionDidChange`, the OS keeps the STALE prior caret and a
        // hardware Arrow key navigates from the previous position instead of the image (the reported bug).
        let v = canvas(); let img = v.boxes[1] as! MediaBlockBox
        v.setCaret(global: v.boxes[0].textStart)        // caret somewhere ABOVE the image
        let spy = InputDelegateSpy(); v.inputDelegate = spy
        v.selectImage(img)
        XCTAssertGreaterThanOrEqual(spy.selectionDidChangeCount, 1,
            "selectImage must notify the input delegate so the OS re-reads selectedTextRange (the gap)")
        let range = v.selectedTextRange as? DocumentTextRange
        XCTAssertEqual(range?.from.offset, img.nodeStart, "the synced OS selection sits at the image gap")
        XCTAssertEqual(range?.to.offset, img.nodeStart)
    }

    func test_upFromLeadingImageGap_isNoOp() {
        // Image is the FIRST block → nothing above → Up stays put (cannot move up).
        let v = DocumentCanvasView()
        v.imageProvider = tealProvider()
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                              caption: [TextRun(text: "Cap")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Below")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        let img = v.boxes[0] as! MediaBlockBox
        XCTAssertEqual(upDown(v, from: img.nodeStart, down: false), img.nodeStart,
                       "Up from a leading image's gap stays put (nothing above)")
    }
}
#endif

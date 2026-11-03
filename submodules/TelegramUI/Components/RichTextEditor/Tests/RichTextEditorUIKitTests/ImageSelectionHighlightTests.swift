#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class ImageSelectionHighlightTests: XCTestCase {
    /// ["Above", image(caption "Caption"), "Below"] at 300pt, with a teal stand-in image provider.
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 80, height: 50)).image { c in
            UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 80, height: 50)) } }
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Above")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                              caption: [TextRun(text: "Caption")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Below")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }
    func img(_ v: DocumentCanvasView) -> MediaBlockBox { v.boxes[1] as! MediaBlockBox }

    func test_isImageSelected_whenTapSelected() {
        let v = canvas(); let i = img(v)
        v.imageSelection = i.id
        XCTAssertTrue(v.isImageSelected(i))
        XCTAssertEqual(v.imageSelectionTintRect(for: i), i.mediaRect())
    }
    func test_isImageSelected_whenRangeCoversAtom() {
        let v = canvas(); let i = img(v)
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 1, head: v.boxes[2].textStart + 1)   // inside "Above" inside "Below" → spans the image
        XCTAssertTrue(v.isImageSelected(i))
        XCTAssertNotNil(v.imageSelectionTintRect(for: i))
    }
    func test_notSelected_forCollapsedGapCaret() {
        let v = canvas(); let i = img(v)
        v.setSelectionForTesting(anchor: i.nodeStart, head: i.nodeStart)   // collapsed caret on the gap
        XCTAssertFalse(v.isImageSelected(i))
        XCTAssertNil(v.imageSelectionTintRect(for: i))
    }
    func test_notSelected_forCaptionOnlySelection() {
        let v = canvas(); let i = img(v)
        v.setSelectionForTesting(anchor: i.textStart, head: i.textStart + 3)   // within the caption only
        XCTAssertFalse(v.isImageSelected(i))
    }
    func test_clearImageSelection_resetsFlag() {
        let v = canvas(); let i = img(v)
        v.imageSelection = i.id
        v.clearImageSelection()
        XCTAssertNil(v.imageSelection)
    }

    /// Full RGBA8 (premultiplied) pixel buffer of a CGImage.
    private func pixels(of image: CGImage) -> [UInt8] {
        let w = image.width, h = image.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return px
    }

    func test_caretRect_reportsGapGeometry_evenWhileImageSelected() {
        // caretRect must keep reporting the gap's geometry while the image is atom-selected, so the OS
        // can run arrow-key navigation OUT of the selection (vertical arrows step from the caret rect).
        // The VISIBLE caret is suppressed separately by updateCaretView (the tint is the indicator).
        let v = canvas(); let i = img(v)
        let unselected = v.caretRect(for: DocumentTextPosition(i.nodeStart))
        XCTAssertFalse(unselected.isEmpty, "the gap caret is a real rect")
        v.imageSelection = i.id
        XCTAssertEqual(v.caretRect(for: DocumentTextPosition(i.nodeStart)), unselected,
                       "caret geometry is still reported while atom-selected (so the OS can navigate)")
    }

    func test_arrowUpFromSelectedImage_deselectsAndMovesAbove() {
        // Tap-select an image, then mimic UIKit applying a hardware Up (new position from .up → set as
        // the selection). The image deselects and the caret moves into the block above, visibly.
        let v = canvas(); let i = img(v)
        v.selectImage(i)
        XCTAssertEqual(v.imageSelection, i.id)
        let up = v.position(from: DocumentTextPosition(v.head), in: .up, offset: 1) as! DocumentTextPosition
        v.selectedTextRange = DocumentTextRange(up, up)
        XCTAssertNil(v.imageSelection, "arrow nav deselects the image")
        let above = v.boxes[0]
        XCTAssertTrue(v.head >= above.textStart && v.head <= above.textStart + above.textLength,
                      "caret moved into the block above")
        XCTAssertFalse(v.caretRect(for: DocumentTextPosition(v.head)).isEmpty, "caret is reportable again")
    }

    func test_canvasOverlay_paintsTintOverImage_onlyWhenSelected() {
        // The image wash now renders ON TOP via the canvas `selectionHighlight` overlay
        // (`drawNonTableSelectionHighlight`), not inside the image's block view.
        func render(selected: Bool) -> [UInt8] {
            let v = canvas(); let i = img(v)
            if selected { v.imageSelection = i.id }
            let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false; fmt.scale = 1
            let image = UIGraphicsImageRenderer(bounds: v.bounds, format: fmt).image { ctx in
                v.drawNonTableSelectionHighlight(in: ctx.cgContext)
            }
            return pixels(of: image.cgImage!)
        }
        XCTAssertNotEqual(render(selected: false), render(selected: true),
                          "the selection wash (now drawn on top by the canvas overlay) must change the rendered pixels")
    }

    func test_selectImage_setsStateAndParksCaretAtGap() {
        let v = canvas(); let i = img(v)
        v.tableSelection = (i.id, .rows(0...0))   // pre-set; selectImage must clear it
        v.selectImage(i)
        XCTAssertEqual(v.imageSelection, i.id)
        XCTAssertEqual(v.head, i.nodeStart)
        XCTAssertNil(v.tableSelection)
    }
    func test_performSingleTap_onImage_selectsAtom() {
        let v = canvas(); let i = img(v)
        let c = CGPoint(x: i.mediaRect().midX, y: i.mediaRect().midY)
        v.performSingleTap(at: c)
        XCTAssertEqual(v.imageSelection, i.id)
    }
    func test_performSingleTap_onCaption_placesCaret_notAtomSelect() {
        let v = canvas(); let i = img(v)
        let cap = v.caretRect(for: DocumentTextPosition(i.textStart + 1))   // a caption caret position
        v.performSingleTap(at: CGPoint(x: cap.midX, y: cap.midY))
        XCTAssertNil(v.imageSelection)
        XCTAssertEqual(v.selFrom, v.selTo, "caption tap is a collapsed caret")
    }
    func test_performSingleTap_offImage_clearsImageSelection() {
        let v = canvas(); let i = img(v)
        v.selectImage(i)
        let above = v.caretRect(for: DocumentTextPosition(v.boxes[0].textStart + 1))
        v.performSingleTap(at: CGPoint(x: above.midX, y: above.midY))
        XCTAssertNil(v.imageSelection)
    }
    func test_handleTap_secondTapOnSelectedImage_keepsSelection() {
        let v = canvas(); let i = img(v)
        let c = CGPoint(x: i.mediaRect().midX, y: i.mediaRect().midY)
        v.handleTap(at: c, time: 100)        // 1st tap selects
        XCTAssertEqual(v.imageSelection, i.id)
        v.handleTap(at: c, time: 100.1)      // quick 2nd tap → menu branch, NOT word-escalate / deselect
        XCTAssertEqual(v.imageSelection, i.id, "still selected after the menu-toggle tap")
    }

    func test_setCaret_clearsImageSelection() {
        let v = canvas(); let i = img(v)
        v.selectImage(i)
        v.setCaret(global: v.boxes[0].textStart + 1)
        XCTAssertNil(v.imageSelection)
    }
    func test_selectAll_clearsImageSelection() {
        let v = canvas(); let i = img(v)
        v.selectImage(i)
        v.selectAllText()
        XCTAssertNil(v.imageSelection)
    }
    func test_typing_clearsImageSelection() {
        let v = canvas(); let i = img(v)
        v.selectImage(i)
        v.insertText("x")
        XCTAssertNil(v.imageSelection)
    }

    /// A document with a leading image and a following table — for mutual-exclusion tests.
    func canvasWithImageAndTable() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 80, height: 50)).image { c in
            UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 80, height: 50)) } }
        func cell(_ id: String, _ t: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id+"p"), runs: [TextRun(text: t)]))])
        }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                              caption: [TextRun(text: "Cap")])),
            .table(TableBlock(id: BlockID("t"),
                columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","A"), cell("b","B")]),
                       Row(id: BlockID("r1"), cells: [cell("c","C"), cell("d","D")])])),
        ], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600); v.layoutIfNeeded()
        return v
    }
    func test_selectingTable_clearsImageSelection() {
        let v = canvasWithImageAndTable()
        let i = v.boxes[0] as! MediaBlockBox
        v.selectImage(i)
        let t = v.boxes[1] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(0)
        XCTAssertNil(v.imageSelection, "selecting a table clears the image selection")
        XCTAssertNotNil(v.tableSelection)
    }
    func test_selectImage_clearsTableSelection() {
        let v = canvasWithImageAndTable()
        let t = v.boxes[1] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(0)
        XCTAssertNotNil(v.tableSelection)
        let i = v.boxes[0] as! MediaBlockBox
        v.selectImage(i)
        XCTAssertNil(v.tableSelection, "selecting an image clears the table selection")
        XCTAssertEqual(v.imageSelection, i.id)
    }

    func test_menuForHook_returnsNoMenu_whenImageSelected() {
        // Media has no tap-select edit menu — Spoiler/Delete live in the host's per-media "•••" menu.
        let v = canvas(); let i = img(v)
        v.selectImage(i)
        let interaction = UIEditMenuInteraction(delegate: nil)
        let cfg = UIEditMenuConfiguration(identifier: nil, sourcePoint: .zero)
        XCTAssertNil(v.editMenuInteraction(interaction, menuFor: cfg, suggestedActions: []))
    }
    func test_deleteBackward_whileImageSelected_removesBlock_andClearsSelection() {
        let v = canvas(); let i = img(v)
        v.selectImage(i)
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox })
        XCTAssertNil(v.imageSelection)
    }
    func test_deleteSelectedImage_isUndoable() {
        let v = canvas(); let i = img(v)
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.selectImage(i)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox })
        um.undo()
        XCTAssertTrue(v.boxes.contains { $0 is MediaBlockBox })
    }

    // MARK: – Change 1: setBlocks clears structural selections

    func test_setBlocks_clearsImageSelection() {
        let v = canvas(); let i = img(v)
        v.selectImage(i)
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("only"), runs: [TextRun(text: "New doc")]))], width: 300)
        XCTAssertNil(v.imageSelection)
    }

    // MARK: – Change 2: pixel test — range covering atom tints the image

    func test_canvasOverlay_paintsTint_whenRangeCoversImageAtom() {
        // The image wash renders ON TOP via the canvas overlay (`drawNonTableSelectionHighlight`), so a
        // range covering the atom tints it there — not in the image's block view.
        func render(coverAtom: Bool) -> [UInt8] {
            let v = canvas(); let i = img(v)
            if coverAtom { v.setSelectionForTesting(anchor: v.boxes[0].textStart + 1, head: i.textStart) }  // gap+atom, stops at caption start
            let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false; fmt.scale = 1
            let image = UIGraphicsImageRenderer(bounds: v.bounds, format: fmt).image { ctx in
                v.drawNonTableSelectionHighlight(in: ctx.cgContext)
            }
            return pixels(of: image.cgImage!)
        }
        XCTAssertNotEqual(render(coverAtom: false), render(coverAtom: true),
                          "a text range covering the image atom tints the image (via the canvas overlay)")
    }

    // MARK: – Change 3: negative — range ending at gap does NOT tint

    func test_notSelected_forRangeEndingAtGap() {
        let v = canvas(); let i = img(v)
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 1, head: i.nodeStart)   // ends exactly at the gap, before the atom
        XCTAssertFalse(v.isImageSelected(i))
    }
}
#endif

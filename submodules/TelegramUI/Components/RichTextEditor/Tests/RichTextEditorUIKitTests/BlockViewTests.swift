#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class BlockViewTests: XCTestCase {
    private func paragraphCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200); v.layoutIfNeeded()
        return v
    }

    func test_paragraphs_areBackedByBlockViews() {
        let v = paragraphCanvas()
        XCTAssertTrue(v.boxes[0].rendersAsBlockView, "paragraphs now render via block views")
        XCTAssertNotNil(v.blockViews[BlockID("a")], "each paragraph has a pooled block view")
        XCTAssertNotNil(v.blockViews[BlockID("b")])
        let view = v.blockViews[BlockID("a")]!
        XCTAssertEqual(view.frame.minY, v.boxes[0].frame.minY, accuracy: 0.01)
        XCTAssertEqual(view.frame.height, v.boxes[0].frame.height, accuracy: 0.01)
    }

    func test_renderSignature_changesWithContent_stableOtherwise() {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hi")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 100); v.layoutIfNeeded()
        let box = v.boxes[0] as! BlockBox
        let s1 = box.renderSignature
        v.layoutIfNeeded()                                   // re-layout, no content change
        XCTAssertEqual(box.renderSignature, s1, "signature stable when nothing changed")
        box.layout.attributedString = NSAttributedString(string: "Hi there")
        XCTAssertNotEqual(box.renderSignature, s1, "signature changes when text changes")
    }

    func test_renderSignature_changesAfterCharacterFormatToggle() {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 100); v.layoutIfNeeded()
        let box = v.boxes[0] as! BlockBox
        let s1 = box.renderSignature
        v.setSelectionForTesting(anchor: box.textStart, head: box.textStart + box.textLength)   // select the whole word
        v.toggleBold()
        XCTAssertNotEqual(box.renderSignature, s1,
                          "toggling bold changes the render signature (so a view-backed paragraph repaints)")
    }

    func test_renderSignature_changesAfterSetLink() {
        // Links mutate storage via the OTHER chokepoint (applyCharacterAttribute) — it must bump too.
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 100); v.layoutIfNeeded()
        let box = v.boxes[0] as! BlockBox
        let s1 = box.renderSignature
        v.setSelectionForTesting(anchor: box.textStart, head: box.textStart + box.textLength)
        v.setLink("https://example.com")
        XCTAssertNotEqual(box.renderSignature, s1,
                          "setting a link changes the render signature (so a view-backed paragraph repaints)")
    }

    func test_splitParagraph_repaintsTheReusedUpperView() {
        // Splitting a paragraph (Return mid-text) replaces the surviving UPPER block's BlockBox with a
        // brand-new instance (fresh BlockLayout, renderVersion == 0) that keeps the original BlockID — so
        // the canvas REUSES the same BlockBackingView for it. The lower half gets a fresh BlockID + fresh
        // view (always repaints). The upper view's repaint is gated by `renderSignature`, which encodes the
        // per-instance `renderVersion` (a counter that resets to 0 for every new box). When the split keeps
        // the upper block's HEIGHT and style unchanged and the prior render was at renderVersion 0, the new
        // box's signature COLLIDES with the old one and the gate wrongly skips setNeedsDisplay — leaving the
        // stale full-text bitmap. Height stays unchanged when the split paragraph already has a following
        // sibling (its bottom inset is already the shrunk inter-paragraph value, before and after), so split
        // the MIDDLE of three body paragraphs.
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "First")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "HelloWorld")]),
            ParagraphBlock(id: BlockID("c"), runs: [TextRun(text: "Third")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        v.simulateParentLayout()
        let upperView = v.blockViews[BlockID("b")]!
        let heightBefore = v.boxes[1].frame.height
        let before = upperView.setNeedsDisplayCountForTesting
        v.setCaret(global: v.boxes[1].textStart + 5)          // caret between "Hello" and "World"
        v.insertText("\n")                                     // routes to insertParagraphBreak (split)
        v.layoutIfNeeded()
        XCTAssertTrue(v.blockViews[BlockID("b")] === upperView, "upper half keeps BlockID 'b' ⇒ same view reused")
        XCTAssertEqual((v.boxes[1] as! BlockBox).textLength, 5, "upper box now holds the truncated 'Hello'")
        XCTAssertEqual(v.boxes[1].frame.height, heightBefore, accuracy: 0.01,
                       "precondition: the split keeps the upper block's height unchanged (so the signature collides — the bug path)")
        XCTAssertGreaterThan(upperView.setNeedsDisplayCountForTesting, before,
                             "the reused upper view must be repainted after the split (else it shows stale full text)")
    }

    func test_selectionRects_regionFilter_excludesFilteredRegions() {
        let v = paragraphCanvas()
        let all = v.selectionRects(globalFrom: 0, globalTo: v.documentSizeValue)
        let none = v.selectionRects(globalFrom: 0, globalTo: v.documentSizeValue, regionFilter: { _ in false })
        XCTAssertFalse(all.isEmpty)
        XCTAssertTrue(none.isEmpty, "a false filter yields no rects")
    }

    private func imageCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 100, height: 60)).image { c in
            UIColor.systemBlue.setFill(); c.fill(CGRect(x: 0, y: 0, width: 100, height: 60)) } }
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Above")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 100, height: 60),
                              caption: [TextRun(text: "Cap")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Below")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        v.simulateParentLayout()
        return v
    }

    func test_imageBlock_isBackedByABlockView() {
        let v = imageCanvas()
        XCTAssertTrue(v.boxes[1].rendersAsBlockView)
        XCTAssertNotNil(v.blockViews[BlockID("img")], "the image has a pooled block view")
        // The view's frame is the block's DRAWN extent (blockViewFrame), so its bounds-sized backing
        // store covers the full-bleed image. UIKit pixel-rounds frames; compare at 0.01pt.
        let viewFrame = v.blockViews[BlockID("img")]!.frame
        let drawn = v.boxes[1].blockViewFrame
        XCTAssertEqual(viewFrame.origin.x, drawn.origin.x, accuracy: 0.01)
        XCTAssertEqual(viewFrame.origin.y, drawn.origin.y, accuracy: 0.01)
        XCTAssertEqual(viewFrame.size.width, drawn.size.width, accuracy: 0.01)
        XCTAssertEqual(viewFrame.size.height, drawn.size.height, accuracy: 0.01)
        XCTAssertNotNil(v.blockViews[BlockID("a")], "paragraphs are view-backed too")
    }

    func test_imageCaption_caretAndSelectionGeometryUnchanged() {
        let v = imageCanvas()
        let cap = v.allLeafRegions().first { $0.ref == .caption(BlockID("img")) }!
        let imgBox = v.boxes[1] as! MediaBlockBox
        let stripLeft = cap.canvasOrigin.x
        let stripRight = cap.canvasOrigin.x + imgBox.layoutWidth
        // Caption is CENTERED. The caret at the START of "Cap" is indented from the left edge, and the caret
        // at the END is the same distance in from the right edge — text symmetric about the strip's center.
        // (Before centering, the start caret sat AT the left edge.) This is the one test that drives the
        // centered caption through caretRect(for:).
        let startCaret = v.caretRect(for: DocumentTextPosition(cap.globalStart))
        let endCaret = v.caretRect(for: DocumentTextPosition(cap.globalStart + cap.length))
        let leftGap = startCaret.minX - stripLeft
        let rightGap = stripRight - endCaret.minX
        XCTAssertGreaterThan(leftGap, 1.0, "start caret is indented (centered), not at the left edge")
        XCTAssertEqual(leftGap, rightGap, accuracy: 2.0, "caption text is centered (symmetric gaps)")
        // Still within the content strip (canvas-coordinate geometry intact under block-view backing).
        XCTAssertGreaterThanOrEqual(startCaret.minX, stripLeft - 1.0, "caret not left of the strip")
        XCTAssertLessThanOrEqual(endCaret.minX, stripRight + 1.0, "caret not right of the strip")
        let rects = v.selectionRects(globalFrom: cap.globalStart, globalTo: cap.globalStart + cap.length)
        XCTAssertFalse(rects.isEmpty)
    }

    func test_crossBlockSelection_spanningImage_stillCoversAllThree() {
        let v = imageCanvas()
        let rects = v.selectionRects(globalFrom: v.boxes[0].textStart + 1,
                                     globalTo: v.boxes[2].textStart + 1)
        func hits(_ box: CanvasBlock) -> Bool { rects.contains { box.frame.intersects($0) } }
        XCTAssertTrue(hits(v.boxes[0]))
        XCTAssertTrue(hits(v.boxes[2]))   // selection continues past the image into the paragraph below
        XCTAssertTrue(hits(v.boxes[1]), "selection also covers the image's caption (continuous through the image)")
    }

    func test_imageCanvas_rendersNonBlank() {
        let v = imageCanvas()
        let image = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in
            v.drawHierarchy(in: v.bounds, afterScreenUpdates: true)
        }
        XCTAssertNotNil(image.cgImage)
    }

    /// A minimal hosted media view (the medium is now a host-supplied overlay view, not a CPU-drawn bitmap).
    private final class StubMediaView: UIView, RichTextMediaItemView {
        func update(size: CGSize) {}
        var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?
    }

    func test_fullBleedMediaView_coversTheBleed() {
        // The medium is now a host-supplied overlay view positioned at `mediaRect()` (not drawn into the
        // block's backing store), so the bleed is covered by THAT view, not the block backing view. The
        // block backing view is now caption-only (blockViewFrame == frame).
        let v = imageCanvas()
        v.mediaViewProvider = { _, _, _, _ in StubMediaView() }
        v.setNeedsLayout(); v.layoutIfNeeded()
        let imgBox = v.boxes[1] as! MediaBlockBox
        let r = imgBox.mediaRect()
        XCTAssertLessThan(r.minX, imgBox.frame.minX, "a top-level image bleeds left past its inset content frame")
        XCTAssertGreaterThan(r.maxX, imgBox.frame.maxX, "...and right past it")
        // The block backing view is now the inset frame only (the medium overlays it separately).
        // UIKit pixel-rounds view frames, so compare at 0.01pt.
        let blockView = v.blockViews[BlockID("img")]!
        XCTAssertEqual(blockView.frame.minX, imgBox.frame.minX, accuracy: 0.01, "block backing view is caption-only (no longer covers the bleed)")
        XCTAssertEqual(blockView.frame.minY, imgBox.frame.minY, accuracy: 0.01)
        XCTAssertEqual(blockView.frame.width, imgBox.frame.width, accuracy: 0.01)
        XCTAssertEqual(blockView.frame.height, imgBox.frame.height, accuracy: 0.01)
        // The hosted media view is positioned at mediaRect() and so covers the full bleed.
        let media = v.hostedMediaViewForTesting(BlockID("img"))
        XCTAssertNotNil(media, "a registered provider realizes a hosted media view")
        XCTAssertEqual(media!.frame.minX, r.minX, accuracy: 0.01, "media view covers the left bleed")
        XCTAssertEqual(media!.frame.maxX, r.maxX, accuracy: 0.01, "media view covers the right bleed")
    }

    func test_blockView_isReusedAcrossEditAndUndo() {
        let v = imageCanvas()
        let before = v.blockViews[BlockID("img")]
        XCTAssertNotNil(before)
        // Edit a paragraph (rebuilds the boxes array; the image keeps its BlockID).
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.insertText("Z")
        v.layoutIfNeeded()
        XCTAssertTrue(v.blockViews[BlockID("img")] === before, "same view instance reused after an edit")
        v.effectiveUndoManager?.undo()
        v.layoutIfNeeded()
        XCTAssertTrue(v.blockViews[BlockID("img")] === before, "same view instance survives undo")
    }

    func test_removingTheImage_tearsDownItsBlockView() {
        let v = imageCanvas()
        XCTAssertNotNil(v.blockViews[BlockID("img")])
        // Select-all + delete removes the image block.
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(0),
                                                DocumentTextPosition(v.documentSizeValue))
        v.deleteBackward()
        v.layoutIfNeeded()
        XCTAssertNil(v.blockViews[BlockID("img")], "removed block's view is dropped from the pool")
        XCTAssertNil(v.subviews.first { ($0 as? BlockBackingView)?.box?.id == BlockID("img") },
                     "and removed from the view hierarchy")
    }

    private func tableCanvas() -> DocumentCanvasView {
        func cell(_ id: String, _ t: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
        }
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")]),
                   Row(id: BlockID("r1"), cells: [cell("c", "Gamma"), cell("d", "Delta")])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 320); v.layoutIfNeeded()
        return v
    }

    func test_cellParagraphs_areHostedAsViewsInTheTableContentView() {
        let v = tableCanvas()
        let tv = v.blockViews[BlockID("t")] as! TableBackingView
        tv.layoutIfNeeded()
        for id in ["ap", "bp", "cp", "dp"] {
            XCTAssertNotNil(tv.cellBlockViews[BlockID(id)], "cell paragraph \(id) is view-backed")
        }
        let apView = tv.cellBlockViews[BlockID("ap")]!
        XCTAssertTrue(apView.isDescendant(of: tv.scroll), "cell paragraph view lives inside the table scroll")
    }

    func test_table_isBackedByABlockView_andSkippedByCanvasDraw() {
        let v = tableCanvas()
        XCTAssertTrue(v.boxes[0].rendersAsBlockView)
        XCTAssertNotNil(v.blockViews[BlockID("t")])
        let t = v.boxes[0] as! TableBlockBox
        let view = v.blockViews[BlockID("t")]!
        // The grid (incl. its borders) fits the content-strip width, and the view frame == the exact grid
        // extent so the bounds-sized backing store doesn't clip the right outer border (a UIView clips its
        // own draw to its bounds; clipsToBounds is irrelevant to own-draw).
        XCTAssertEqual(t.gridWidth, t.frame.width, accuracy: 0.5, "table grid fits the content-strip width")
        XCTAssertEqual(view.frame.minX, t.frame.minX, accuracy: 0.01)
        XCTAssertEqual(view.frame.minY, t.frame.minY, accuracy: 0.01)
        XCTAssertEqual(view.frame.width, t.gridWidth, accuracy: 0.01, "view frame width == grid width (covers the right border)")
        XCTAssertEqual(view.frame.height, t.frame.height, accuracy: 0.01)
    }

    func test_tableGridWidth_matchesSiblingBlockWidth() {
        // A table must share the same content width as every other block — its grid (incl. borders) must
        // not overflow the page margin that paragraphs/quotes respect.
        func cell(_ id: String, _ s: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: s)]))])
        }
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Para")])),
            .table(TableBlock(id: BlockID("t"),
                columns: [ColumnSpec(width: 140), ColumnSpec(width: 110), ColumnSpec(width: 110)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B"), cell("c", "C")])])),
        ], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 400); v.layoutIfNeeded()
        let para = v.boxes[0], table = v.boxes[1] as! TableBlockBox
        XCTAssertEqual(table.gridWidth, para.frame.width, accuracy: 0.5,
                       "table grid width matches a sibling paragraph's content width")
        XCTAssertEqual(table.frame.minX + table.gridWidth, para.frame.maxX, accuracy: 0.5,
                       "table right edge aligns with the paragraph right edge")
    }

    func test_crossCellSelection_unionStillCoversBothCells() {
        let v = tableCanvas()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let rB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let rects = v.selectionRects(globalFrom: rA.globalStart + 2, globalTo: rB.globalStart + 2)
        XCTAssertTrue(rects.contains { $0.minX < rB.canvasOrigin.x - 1 }, "covers part of cell A")
        XCTAssertTrue(rects.contains { $0.maxX > rB.canvasOrigin.x - 1 }, "continues into cell B")
    }

    func test_structuralSelection_outlineRectUnchanged() {
        let v = tableCanvas()
        // Park the caret inside the table (activeTable() requires head inside a cell).
        let t = v.boxes[0] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableColumn(0)
        XCTAssertNotNil(v.tableSelectionOutlineRect(), "structural outline geometry still computes")
    }

    func test_tableCanvas_rendersNonBlank() {
        let v = tableCanvas()
        let image = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in
            v.drawHierarchy(in: v.bounds, afterScreenUpdates: true)
        }
        XCTAssertNotNil(image.cgImage)
    }

    func test_chromeOverlay_isTopmostAndExtendsLeftForGrip() {
        let v = tableCanvas()
        let overlay = v.subviews.compactMap { $0 as? BlockChromeOverlay }.first
        XCTAssertNotNil(overlay, "the canvas owns a chrome overlay")
        XCTAssertEqual(v.subviews.last as? BlockChromeOverlay, overlay, "overlay is the topmost subview")
        // Covers the canvas and EXTENDS LEFT of x=0 so the row grip can draw in the left gutter / field padding
        // (a draw(_:) is bounded by the frame). bounds.origin matches frame.origin → still draws in canvas coords.
        XCTAssertLessThan(overlay!.frame.minX, 0, "overlay extends left of the canvas for the row grip")
        XCTAssertEqual(overlay!.frame.maxX, v.bounds.maxX, accuracy: 0.5, "overlay still covers the canvas to the right")
        XCTAssertEqual(overlay!.frame.height, v.bounds.height, accuracy: 0.5)
        XCTAssertEqual(overlay!.bounds.origin, overlay!.frame.origin, "bounds.origin matches frame.origin → draws in canvas coordinates")
        XCTAssertFalse(overlay!.isUserInteractionEnabled, "overlay never takes touches")
    }

    func test_paragraphCanvas_rendersNonBlank_viaSubviews() {
        let v = paragraphCanvas()
        XCTAssertFalse(v.blockViews.isEmpty, "paragraphs are view-backed")
        XCTAssertNotNil(v.subviews.first { ($0 as? BlockBackingView)?.box?.id == BlockID("a") })
        let img = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in
            v.drawHierarchy(in: v.bounds, afterScreenUpdates: true)
        }
        XCTAssertNotNil(img.cgImage)
    }

    func test_longDocument_noBlockViewExceedsMaxSurface() {
        let v = DocumentCanvasView()
        let paras = (0..<400).map { ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Paragraph \($0)")]) }
        v.setParagraphs(paras, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: v.intrinsicContentSize.height); v.layoutIfNeeded()
        let maxDim: CGFloat = 8192
        for box in v.boxes {
            XCTAssertLessThan(box.blockViewFrame.height, maxDim, "each paragraph layer is bounded")
            XCTAssertLessThan(box.blockViewFrame.width, maxDim)
        }
        XCTAssertGreaterThan(v.intrinsicContentSize.height, maxDim,
                             "the document as a whole exceeds a single surface — the case this fixes")
    }

    func test_wideTable_getsTableBackingView_withScrollableContentSize() {
        func cell(_ id: String, _ t: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
        }
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "C\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let view = v.blockViews[BlockID("t")]
        XCTAssertTrue(view is TableBackingView, "a table is backed by a TableBackingView")
        let tv = view as! TableBackingView
        tv.layoutIfNeeded()
        XCTAssertEqual(tv.scroll.contentSize.width, t.gridWidth, accuracy: 0.5, "scroll content == full grid width")
        XCTAssertGreaterThan(tv.scroll.contentSize.width, tv.bounds.width, "content wider than the window → scrollable")
    }
}
#endif

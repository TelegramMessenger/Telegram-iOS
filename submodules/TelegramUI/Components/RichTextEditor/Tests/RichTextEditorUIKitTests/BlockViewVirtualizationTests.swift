#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class BlockViewVirtualizationTests: XCTestCase {
    /// A bare canvas of `n` single-line paragraphs, laid out at FULL document height (no scroll host).
    private func longCanvas(_ n: Int, width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs((0..<n).map { ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Paragraph \($0)")]) },
                        width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: v.intrinsicContentSize.height)
        v.layoutIfNeeded()
        return v
    }

    func test_viewportRect_fallsBackToBoundsWithoutScrollHost() {
        let v = longCanvas(10)
        XCTAssertEqual(v.viewportRect(), v.bounds, "no UIScrollView superview ⇒ viewport == bounds (realize all)")
    }

    func test_viewportBand_growsByOverscan_default_isOneViewportHeight() {
        let v = longCanvas(10)
        // Default overscan (negative sentinel) ⇒ one viewport height each side.
        let band = v.viewportBand()
        XCTAssertEqual(band.minY, v.bounds.minY - v.bounds.height, accuracy: 0.01)
        XCTAssertEqual(band.maxY, v.bounds.maxY + v.bounds.height, accuracy: 0.01)
    }

    func test_blockWindow_oneByteBandInsideABox_yieldsThatBoxOnly() {
        let v = longCanvas(10)
        let mid = v.boxes[5].frame
        let band = CGRect(x: 0, y: mid.minY + 1, width: 300, height: 1)
        XCTAssertEqual(v.blockWindow(forBand: band), [5], "a 1pt band inside box 5 yields exactly [5]")
    }

    func test_blockWindow_spanningBand_yieldsContiguousRange() {
        let v = longCanvas(20)
        let band = CGRect(x: 0, y: v.boxes[4].frame.minY + 1, width: 300,
                          height: v.boxes[8].frame.minY - v.boxes[4].frame.minY)
        XCTAssertEqual(v.blockWindow(forBand: band), [4, 5, 6, 7, 8], "band over boxes 4..8 ⇒ [4,5,6,7,8]")
    }

    func test_blockWindow_empty_whenBandBelowDocument() {
        let v = longCanvas(10)
        XCTAssertTrue(v.blockWindow(forBand: CGRect(x: 0, y: 100_000, width: 300, height: 50)).isEmpty)
    }

    func test_blockWindow_empty_whenBandAboveDocument() {
        let v = longCanvas(10)
        XCTAssertTrue(v.blockWindow(forBand: CGRect(x: 0, y: -100_000, width: 300, height: 50)).isEmpty)
    }

    func test_reconcile_realizesOnlyTheVisibleWindow() {
        let v = longCanvas(200)
        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 300, height: 300))
        XCTAssertLessThan(v.realizedBlockViewCountForTesting, v.boxes.count, "not every box is realized")
        XCTAssertTrue(v.isBlockViewRealizedForTesting(BlockID("p0")), "top paragraph realized")
        XCTAssertFalse(v.isBlockViewRealizedForTesting(BlockID("p199")), "far-offscreen paragraph not realized")
    }

    func test_reconcile_scroll_shiftsRealizedSet_andRecycles() {
        let v = longCanvas(200)
        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 300, height: 300))
        XCTAssertTrue(v.isBlockViewRealizedForTesting(BlockID("p0")), "top realized at offset 0")
        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 3000, width: 300, height: 300))
        XCTAssertFalse(v.isBlockViewRealizedForTesting(BlockID("p0")), "top recycled away after scrolling down")
        XCTAssertGreaterThan(v.recycleQueueDepthForTesting, 0, "recycled views returned to the reuse queue")
        let midBox = v.boxes.first { $0.frame.minY > 3000 && $0.frame.minY < 3300 }
        XCTAssertNotNil(midBox, "precondition: a box near y=3000 exists")
        XCTAssertTrue(v.isBlockViewRealizedForTesting(midBox!.id), "a box at the new viewport is realized (set shifted)")
        XCTAssertLessThan(v.realizedBlockViewCountForTesting, v.boxes.count / 4,
                          "realized count is well below the full document (virtualization is effective)")
    }

    func test_reconcile_recycledView_isReused_notReallocated() {
        let v = longCanvas(200)
        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 300, height: 300))
        let p0view = v.blockViews[BlockID("p0")]
        XCTAssertNotNil(p0view)
        // Scroll just far enough to cull p0 (past the overscan band), NOT a whole-document jump: the
        // recycle queue is a LIFO capped at 24, so culling many screenfuls at once evicts p0's instance
        // through overflow and the round trip legitimately reallocates. Tightened when V2's 1pt
        // inter-paragraph gap made a y=3000 jump span far more paragraphs than it used to.
        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 700, width: 300, height: 300))   // cull p0
        XCTAssertNil(v.blockViews[BlockID("p0")], "p0 culled")
        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 300, height: 300))       // realize the top again
        XCTAssertTrue(v.blockViews.values.contains { $0 === p0view }, "the recycled instance is reused, not reallocated")
        XCTAssertNotNil(p0view?.box, "the reused view is rebound to a box")
    }

    func test_reconcile_noScrollHost_realizesEveryBox() {
        let v = longCanvas(50)   // layoutIfNeeded already ran reconcile via viewportRect()==bounds
        XCTAssertEqual(v.realizedBlockViewCountForTesting, v.boxes.count, "no scroll host ⇒ all realized (invariance)")
    }

    func test_reconcile_overscanBand_realizesJustOffscreenBox_butNotFarOnes() {
        let v = longCanvas(200)
        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 300, height: 300))   // overscan auto = 300
        let justBelow = v.boxes.first { $0.frame.minY > 320 && $0.frame.minY < 560 }!
        XCTAssertTrue(v.isBlockViewRealizedForTesting(justBelow.id), "a box within the overscan band is realized")
        let farBelow = v.boxes.first { $0.frame.minY > 1200 }!
        XCTAssertFalse(v.isBlockViewRealizedForTesting(farBelow.id), "a box beyond the band is not realized")
    }

    func test_reconcile_realizedView_zOrder_aboveQuoteUnderlay_belowSelectionWash() {
        let v = longCanvas(60)
        // Target a mid-document box by its actual frame (robust to inter-block spacing) rather than a
        // hardcoded scroll offset, which drifts below the document when body paragraphs stack tight.
        let midY = v.boxes[30].frame.minY
        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: midY, width: 300, height: 300))   // realize mid-doc only
        let block = v.subviews.compactMap { $0 as? BlockBackingView }.first
        XCTAssertNotNil(block, "a block view was realized in the window")
        let iBlock = v.subviews.firstIndex(of: block!)!
        let iQuote = v.subviews.firstIndex(of: v.blockquoteUnderlay)!
        let iWash = v.subviews.firstIndex(of: v.selectionHighlight)!
        XCTAssertGreaterThan(iBlock, iQuote, "block view sits above the back-most blockquote underlay")
        XCTAssertLessThan(iBlock, iWash, "block view sits below the selection-wash overlay")
    }

    func test_viewportDidChange_reRealizesAgainstTheCurrentViewport() {
        // Embed a bare canvas inside a real scroll view so viewportRect() reads the scroll window.
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let v = DocumentCanvasView()
        v.setParagraphs((0..<200).map { ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Paragraph \($0)")]) },
                        width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: v.intrinsicContentSize.height)
        scroll.contentSize = v.frame.size
        scroll.addSubview(v)
        v.layoutIfNeeded()
        XCTAssertTrue(v.isBlockViewRealizedForTesting(BlockID("p0")), "top realized at offset 0")
        scroll.contentOffset = CGPoint(x: 0, y: 3000)
        v.viewportDidChange()
        XCTAssertFalse(v.isBlockViewRealizedForTesting(BlockID("p0")), "top recycled after the viewport moved down")
    }

    func test_blockViewOverscan_isTunable_throughTheFacade() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.blockViewOverscan = 999
        XCTAssertEqual(editor.canvas.blockViewOverscan, 999, "the façade passes the overscan knob through to the canvas")
    }

    /// A bare canvas holding one WIDE (scrollable) table, laid out small enough that it scrolls.
    private func wideTableCanvas() -> DocumentCanvasView {
        func cell(_ id: String, _ t: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
        }
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "C\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        return v
    }

    func test_table_horizontalScroll_survivesCullAndRealize() {
        let v = wideTableCanvas()
        let tv = v.blockViews[BlockID("t")] as! TableBackingView
        tv.layoutIfNeeded()
        XCTAssertGreaterThan(tv.scroll.contentSize.width, tv.bounds.width, "precondition: the table is scrollable")
        tv.scroll.contentOffset.x = 120                       // user scrolls right → tableDidScroll syncs the box
        let t = v.boxes[0] as! TableBlockBox
        XCTAssertEqual(t.contentOffsetX, 120, accuracy: 0.5, "the box records the H-scroll")

        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 5000, width: 390, height: 300))  // cull off-screen
        XCTAssertFalse(v.isBlockViewRealizedForTesting(BlockID("t")), "table culled")
        XCTAssertEqual(t.contentOffsetX, 120, accuracy: 0.5, "the box retains the H-scroll while culled")

        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 390, height: 300))       // realize again (fresh view)
        let tv2 = v.blockViews[BlockID("t")] as! TableBackingView
        XCTAssertFalse(tv2 === tv, "a fresh TableBackingView was created on re-realize")
        tv2.layoutIfNeeded()
        XCTAssertEqual(tv2.scroll.contentOffset.x, 120, accuracy: 0.5, "the H-scroll is restored into the new view")
    }

    func test_visibleBlockquoteFills_noScrollHost_keepsAllRuns() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("q0"), runs: [TextRun(text: "Q0")])),
            .paragraph(ParagraphBlock(id: BlockID("q1"), runs: [TextRun(text: "Q1")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: v.intrinsicContentSize.height); v.layoutIfNeeded()
        // Every run is on-screen via the bounds band.
        XCTAssertEqual(v.visibleBlockquoteFills(band: v.viewportBand()).count, v.blockQuoteFillRects().count,
                       "no scroll host ⇒ every run kept (invariance)")
    }

    func test_reconcile_signalsWhenAFreshTableIsRealized() {
        let v = wideTableCanvas()
        // Cull the table (reconcile far below it): no fresh table created.
        XCTAssertFalse(v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 5000, width: 390, height: 300)),
                       "culling creates no fresh table ⇒ false")
        XCTAssertFalse(v.isBlockViewRealizedForTesting(BlockID("t")), "table culled")
        // Re-realize it ⇒ a fresh TableBackingView is created ⇒ signals true (this is what drives the
        // cell-emoji re-host in viewportDidChange).
        XCTAssertTrue(v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 390, height: 300)),
                      "re-realizing a culled table creates a fresh view ⇒ true")
        // A stays-realized table does not re-signal.
        XCTAssertFalse(v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 390, height: 300)),
                       "a stays-realized table does not re-signal")
    }

    func test_coordinateFree_queriesUnchangedForUnrealizedRegion() {
        let v = longCanvas(200)
        let fullHeight = v.intrinsicContentSize.height
        // A far-down paragraph; record its geometry while everything is realized (full-height layout).
        let far = v.boxes[180]
        let pos = far.textStart + 1   // an interior offset, so caretRect resolves a real TextKit rect (not the empty-line fallback)
        let caretRealized = v.caretRect(for: DocumentTextPosition(pos))
        let rectsRealized = v.selectionRects(globalFrom: far.textStart, globalTo: far.textStart + far.textLength)
        XCTAssertFalse(rectsRealized.isEmpty, "precondition: the far paragraph has selection rects (so the post-cull equality isn't vacuous)")
        let hitRealized = v.closestGlobalPosition(to: CGPoint(x: far.frame.midX, y: far.frame.midY))

        // Cull it (realize only the top), then re-query — geometry must be byte-identical (coordinate-free).
        v.reconcileBlockViews(visibleRect: CGRect(x: 0, y: 0, width: 300, height: 300))
        XCTAssertFalse(v.isBlockViewRealizedForTesting(far.id), "the far paragraph is culled")
        XCTAssertEqual(v.caretRect(for: DocumentTextPosition(pos)), caretRealized, "caretRect independent of realization")
        XCTAssertEqual(v.selectionRects(globalFrom: far.textStart, globalTo: far.textStart + far.textLength),
                       rectsRealized, "selectionRects independent of realization")
        XCTAssertEqual(v.closestGlobalPosition(to: CGPoint(x: far.frame.midX, y: far.frame.midY)),
                       hitRealized, "hit-testing independent of realization")
        XCTAssertEqual(v.intrinsicContentSize.height, fullHeight, accuracy: 0.5,
                       "content height still spans the whole document even with the far box culled (scroll reaches it)")
        XCTAssertGreaterThan(fullHeight, far.frame.maxY, "precondition: the document extends past the culled far box")
    }
}
#endif

import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

@available(iOS 18.4, *)
final class EngineTableScrollingTests: XCTestCase {
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
    /// A second wide table, for the cases that need two of them.
    private func quoted(columns count: Int = 4) -> TableBlock {
        TableBlock(id: BlockID("t1"), columns: (0..<count).map { _ in ColumnSpec(width: 100) },
                   rows: [Row(id: BlockID("qr0"), cells: (0..<count).map { cell("q\($0)", "q\($0)") })])
    }

    /// Four 100pt-floored columns: 404pt wide in a 320pt editor → scrolls.
    private func wide(columns count: Int = 4) -> TableBlock {
        TableBlock(id: BlockID("t0"), columns: (0..<count).map { _ in ColumnSpec(width: 100) },
                   rows: [Row(id: BlockID("r0"), cells: (0..<count).map { cell("c\($0)", "c\($0)") })])
    }

    func test_chromeLivesInsideTheRunsScrollingContentAndScrollsWithTheCells() {
        editor.document = Document(blocks: [.table(wide())])
        editor.layoutIfNeeded()
        guard let chrome = editor.tableChromeViews[BlockID("t0")],
              let content = editor.engine.id_placedRunContentViewForBlock(at: 0) else { return XCTFail() }
        XCTAssertEqual(chrome.superview, content)
        XCTAssertEqual(content.subviews.firstIndex(of: chrome), 0)
        let restingOrigin = chrome.frame.origin
        XCTAssertEqual(restingOrigin.x, 0, "the chrome spans the run from its left edge")
        let dBefore = editor.engine.id_frameForBlock(at: 3)
        editor.engine.id_setPlacedRunContentOffset(80, forBlockAt: 0)
        editor.layoutIfNeeded()
        XCTAssertEqual(dBefore.minX - editor.engine.id_frameForBlock(at: 3).minX, 80, accuracy: 0.5)
        XCTAssertEqual(chrome.frame.origin, restingOrigin, "the chrome did not move in its content view — the content scrolled")
    }

    func test_theScrollOffsetSurvivesAWholesaleReRender() {
        editor.document = Document(blocks: [.table(wide())])
        editor.layoutIfNeeded()
        editor.engine.id_setPlacedRunContentOffset(60, forBlockAt: 0)
        editor.document = editor.document            // a repair re-applies the model wholesale
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: 0), 60, accuracy: 0.5)
    }

    func test_aNarrowTableHasNoScrollButStillItsChromeInTheContentView() {
        let narrow = TableBlock(id: BlockID("t1"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r0"), cells: [cell("a", "a"), cell("b", "b")])])
        editor.document = Document(blocks: [.table(narrow)])
        editor.layoutIfNeeded()
        let content = editor.engine.id_placedRunContentViewForBlock(at: 0)
        XCTAssertNotNil(content)
        XCTAssertEqual(editor.tableChromeViews[BlockID("t1")]?.superview, content)
        XCTAssertFalse((content?.superview as? UIScrollView)?.isScrollEnabled ?? true)
    }

    // MARK: The structural chrome under scroll

    private func structuralChrome() -> TableStructuralChromeView? {
        editor.layoutIfNeeded()
        return editor.tableStructuralChromeViews[BlockID("t0")]
    }

    /// A document set parks the caret in the LAST cell; the first is the one these tests reason about.
    private func focusFirstCell() {
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: 0), length: 0)
    }

    /// A run's scroll marks the ENGINE for layout and nothing else — the editor learns of the pass
    /// through `engineDidLayout` and re-places the chrome from there. So the harness, like the
    /// device, lays out only what the scroll dirtied.
    private func scrollRun(to offset: CGFloat) {
        editor.engine.id_setPlacedRunContentOffset(offset, forBlockAt: 0)
        editor.engine.layoutIfNeeded()
    }

    /// Told apart by SHAPE, not position: a scrolled column grip can sit left of the table's origin.
    private func columnGrip(of chrome: TableStructuralChromeView) -> CGRect? {
        chrome.drawnHandleRects.first { $0.height <= EngineTableStructuralChrome.gripHeight + 0.5 }
    }
    private func rowGrip(of chrome: TableStructuralChromeView) -> CGRect? {
        chrome.drawnHandleRects.first { $0.width <= EngineTableStructuralChrome.gripWidth + 0.5 }
    }

    /// The engine's cell frames ride the run's scroll, so a chrome anchored at the first cell's frame
    /// moved with the content — and then `viewRect(_:)` applied the offset a second time. On
    /// K3 (2026-09-10) the outline sat one offset LEFT of its cell, the column grip with it, and the
    /// row grip had left the gutter with the content. The view is anchored at the table's UNSCROLLED
    /// origin, and the offset is applied once, per element.
    func test_theStructuralChromeIsAnchoredAtTheRunNotAtTheScrolledCells() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        guard let chrome = structuralChrome() else { return XCTFail("no structural chrome") }
        let resting = chrome.frame
        scrollRun(to: 80)
        XCTAssertEqual(chrome.frame, resting)
    }

    /// The defect as reported ("cell selection does not follow scrolling", K3 2026-09-11): the cells
    /// scrolled 34pt and the outline, knobs and column grip stayed. The chrome was re-placed only from
    /// the EDITOR's `layoutSubviews`, and a scroll never runs that — it dirties the engine alone.
    func test_theChromeFollowsAScrollThatLaidOutOnlyTheEngine() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        guard let chrome = structuralChrome() else { return XCTFail("no structural chrome") }
        guard let before = chrome.drawnOutlineRect else { return XCTFail("no outline") }
        editor.engine.id_setPlacedRunContentOffset(50, forBlockAt: 0)
        editor.engine.layoutIfNeeded()          // the engine's pass, and only that
        guard let after = chrome.drawnOutlineRect else { return XCTFail("no outline after the scroll") }
        XCTAssertEqual(before.minX - after.minX, 50, accuracy: 0.5, "the outline rode the scroll")
    }

    /// EVERY piece of the chrome rides the table, the row grip included. It used to be anchored to
    /// the table's unscrolled left edge and sat in the gutter whatever the run did; a grip hangs off
    /// an EDGE of the table now, and an edge that scrolls away takes its grip with it.
    func test_scrollingMovesEveryGripWithTheTable() {
        // The app's own margin. A grip lives in the text inset at the top level, and the harness's
        // default inset is narrower than one, so it would leave the clip window within a few points
        // of scrolling and this would measure its absence instead of its movement.
        editor.engine.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        guard let chrome = structuralChrome() else { return XCTFail("no structural chrome") }
        guard let outlineBefore = chrome.drawnOutlineRect, let rowBefore = rowGrip(of: chrome),
              let columnBefore = columnGrip(of: chrome) else { return XCTFail("no chrome shown") }
        scrollRun(to: 10)
        guard let outlineAfter = chrome.drawnOutlineRect, let rowAfter = rowGrip(of: chrome),
              let columnAfter = columnGrip(of: chrome) else { return XCTFail("no chrome after the scroll") }
        XCTAssertEqual(outlineBefore.minX - outlineAfter.minX, 10, accuracy: 0.5)
        XCTAssertEqual(columnBefore.minX - columnAfter.minX, 10, accuracy: 0.5)
        XCTAssertEqual(rowBefore.minX - rowAfter.minX, 10, accuracy: 0.5, "the row grip rides it too")
    }

    /// Far enough and the leading grip is gone with the first column, while the mirrored one arrives
    /// with the last: on a wide table each gutter belongs to the edge it hangs off.
    func test_theLeadingGripLeavesAndTheTrailingOneArrives() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        guard let chrome = structuralChrome() else { return XCTFail("no structural chrome") }
        let tall = { (rects: [CGRect]) in rects.filter { $0.width <= EngineTableStructuralChrome.gripWidth + 0.5 } }
        XCTAssertEqual(tall(chrome.drawnHandleRects).count, 1, "at rest only the leading grip is in the band")
        XCTAssertLessThan(tall(chrome.drawnHandleRects)[0].minX, chrome.currentTableOrigin.x)
        scrollRun(to: 1000)   // clamped to the end
        let atEnd = tall(chrome.drawnHandleRects)
        XCTAssertEqual(atEnd.count, 1, "at the end only the trailing one is")
        XCTAssertGreaterThan(atEnd[0].minX, chrome.currentTableOrigin.x,
                             "and it hangs off the table's right edge")
    }

    /// The outline is ON the cell — the same frame the engine placed the cell's text in.
    func test_theOutlineSitsOnItsCellAfterAScroll() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        guard let chrome = structuralChrome() else { return XCTFail("no structural chrome") }
        scrollRun(to: 80)
        guard let outline = chrome.drawnOutlineRect, let grid = editor.tableGrids[BlockID("t0")],
              let cell = grid.cells.first(where: { $0.row == 0 && $0.column == 0 }),
              let scrolledTable = editor.tableFrame(forTableAt: 0) else { return XCTFail("no geometry") }
        let inEngine = chrome.convert(outline, to: editor.engine)
        XCTAssertEqual(inEngine.minX, scrolledTable.minX + cell.rect.minX - grid.borderWidth, accuracy: 0.5)
        XCTAssertEqual(inEngine.minY, scrolledTable.minY + cell.rect.minY - grid.borderWidth, accuracy: 0.5)
    }

    /// Legacy's `drawTableChrome` clips to the table's visible band: a column grip whose column has
    /// scrolled out of the run is not left floating beside the table, and cannot be hit there either.
    func test_aColumnGripOutsideTheVisibleBandIsNeitherDrawnNorHittable() {
        editor.document = Document(blocks: [.table(wide(columns: 6))])   // 606pt: the last column is off the right edge
        focusFirstCell()
        editor.selectTableColumns(5...5)
        guard let chrome = structuralChrome(), let grid = editor.tableGrids[BlockID("t0")],
              let last = grid.cells.first(where: { $0.column == 5 }) else { return XCTFail("no structural chrome") }
        XCTAssertNil(columnGrip(of: chrome), "the selected column is beyond the run's right edge at offset 0")
        let gripCentre = chrome.viewRect(CGRect(x: last.rect.midX, y: grid.size.height + 8, width: 0, height: 0)).origin
        XCTAssertNil(chrome.handle(at: gripCentre))
        XCTAssertFalse(chrome.point(inside: gripCentre, with: nil))
        // Scrolled to the end, the column is in the band and its grip is back.
        scrollRun(to: 1000)   // clamped to the maximum
        XCTAssertNotNil(columnGrip(of: chrome))
    }

    // MARK: A table edit keeps the scroll

    /// "Setting alignment on cells resets scrolling" (K3, 2026-09-11). The splice keeps the first
    /// cell's identity — so the run's scroll view survives — but every other cell is a fresh block
    /// the host has not yet placed when the engine's change pass runs. For that one pass the run is a
    /// single cell wide, and the engine clamps the offset to that width's maximum: zero. The host
    /// pushes the frames a layout later, and the run is wide again — at zero.
    func test_aCellEditKeepsTheRunsScrollOffset() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        scrollRun(to: 60)
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: 0), 60, accuracy: 0.5, "precondition")
        editor.setSelectionAlignment(horizontal: .center, vertical: nil)
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: 0), 60, accuracy: 0.5,
                       "the edit is the cells' business, not the scroll's")
    }

    /// The article host re-runs its layout from `onChange`, SYNCHRONOUSLY, and that lays the engine out
    /// — with every cell placed again — before the splice has finished its own bookkeeping. The first
    /// cut of the restore recorded the offset after the notification block: the one layout pass that
    /// could have restored it found nothing to restore, and the entry then waited for an engine layout
    /// that never came. On K3 the table still reset (2026-09-11).
    func test_aCellEditKeepsTheScrollWhenTheHostLaysOutFromOnChange() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        scrollRun(to: 60)
        editor.onChange = { [weak self] in
            guard let engine = self?.editor.engine else { return }
            engine.setNeedsLayout()
            engine.layoutIfNeeded()
        }
        editor.setSelectionAlignment(horizontal: .center, vertical: nil)
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: 0), 60, accuracy: 0.5)
    }

    /// The run's scroller is invisible infrastructure — a host draws what it wants around the table —
    /// so it shows no indicator of its own. Reached the way the chrome is hosted: through the content
    /// view the engine hands out.
    func test_theRunsScrollerShowsNoIndicator() {
        editor.document = Document(blocks: [.table(wide())])
        editor.layoutIfNeeded()
        guard let scroll = editor.engine.id_placedRunContentViewForBlock(at: 0)?.superview as? UIScrollView else {
            return XCTFail("no run scroll view")
        }
        XCTAssertFalse(scroll.showsHorizontalScrollIndicator)
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
    }

    /// The run is the union of the placed cell frames, and the table's outer border lies outside every
    /// cell — so the content ended one border short and the last column's right border could never
    /// scroll into view (K3, 2026-09-11: the rounded corner cut, no right line). The bottom border was
    /// already handled by the last row's bottom inset, which extends the run; the right one goes on
    /// the last column's frame and right inset together.
    func test_theRunHoldsTheTablesRightBorder() {
        editor.document = Document(blocks: [.table(wide())])
        editor.layoutIfNeeded()
        guard let scroll = editor.engine.id_placedRunContentViewForBlock(at: 0)?.superview as? UIScrollView,
              let grid = editor.tableGrids[BlockID("t0")] else { return XCTFail("no run") }
        guard let content = editor.engine.id_placedRunContentViewForBlock(at: 0) else {
            return XCTFail("no run content")
        }
        XCTAssertEqual(content.frame.width, grid.size.width, accuracy: 0.5,
                       "the content spans the whole grid, outer border included")
        XCTAssertEqual(scroll.contentSize.width - scroll.bounds.width,
                       grid.size.width - editor.availableTableWidth, accuracy: 0.5,
                       "and the scrollable range is the grid against its column, clip or no clip")
        // And the text column of a last-column cell is what the grid gave it, not one border wider.
        guard let last = grid.cells.first(where: { $0.column == 3 }) else { return XCTFail("no last cell") }
        let text = editor.engine.id_frameForBlock(at: 3)
        XCTAssertEqual(text.width, last.rect.width - last.textInsets.left - last.textInsets.right, accuracy: 0.5)
    }

    /// Drawing and hit-testing have to answer from ONE list. A knob is SHOWN when its centre is in
    /// the run's visible band; its hit box is 44pt wide and reaches 22pt further, so a knob that had
    /// scrolled out of the run kept a strip of invisible hit area at the band's edge. The document's
    /// scroll pan yields to knobs and to nothing else, so a horizontal drag there resized a
    /// selection instead of scrolling the table — the reported symptom, from the other end.
    func test_aKnobThatHasLeftTheRunTakesNoTouchAtTheRunsEdge() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        editor.selectTableColumns(3...3)
        guard let chrome = structuralChrome() else { return XCTFail("no structural chrome") }
        // Here the selected column's trailing knob sits ~20pt past the run's right edge: off screen,
        // with its hit box still reaching back inside.
        scrollRun(to: 70)
        guard let outline = chrome.drawnOutlineRect else { return XCTFail("no outline") }
        XCTAssertEqual(chrome.drawnKnobRects.count, 1,
                       "precondition: only the leading knob is on screen at this offset")
        XCTAssertTrue(chrome.drawnKnobRects.allSatisfy { $0.midX <= chrome.bounds.maxX },
                      "precondition: a knob past the run's edge is not drawn")
        let edge = CGPoint(x: chrome.bounds.maxX - 2, y: outline.midY)
        XCTAssertNil(chrome.knob(at: edge),
                     "an invisible knob took the touch the run's own scroll should have had")
        XCTAssertFalse(chrome.point(inside: edge, with: nil))
    }

    /// `height(forWidth:)` promises to leave nothing behind. It lays the engine out at a width the
    /// caller has not committed to, and a probe WIDER than the table leaves the run with no
    /// scrolling range at all — the engine clamps the offset to zero, and putting the frame back
    /// does not put the scroll back. The composer probes before choosing a width, so this is the
    /// ordinary path, not an edge case.
    func test_aHeightProbeLeavesATablesScrollWhereItWas() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        scrollRun(to: 60)
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: 0), 60, accuracy: 0.5, "precondition")

        _ = editor.height(forWidth: 420)   // wider than the 405pt table: the run stops scrolling

        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: 0), 60, accuracy: 0.5,
                       "the probe spent the table's scroll")
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: 0), 60, accuracy: 0.5)
    }

    /// The host owns the offset, so it survives a rebuild whoever caused it — not only the edits
    /// that remembered to park one.
    func test_theHostRemembersEachRunsScroll() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        scrollRun(to: 60)
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.runScrollOffsets[BlockID("t0")] ?? 0, 60, accuracy: 0.5)
        editor.setSelectionAlignment(horizontal: .center, vertical: nil)
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: 0), 60, accuracy: 0.5)
        XCTAssertEqual(editor.runScrollOffsets[BlockID("t0")] ?? 0, 60, accuracy: 0.5)
    }

    // MARK: One table, one run (K3, 2026-09-11)

    /// **Two tables are two scrolling surfaces, whatever sits between them.** Adjacent placed blocks
    /// are ONE run in the engine — that is what makes a table's cells scroll together — and a table
    /// whose predecessor is also a table had nothing stacked in between, so the two shared a run and
    /// a single scroll view: dragging either moved both ("scrolling one table scrolls another on the
    /// top level", user, K3). The host declares each table's first cell as a run start.
    func test_twoTablesScrollIndependently() {
        editor.document = Document(blocks: [
            .table(wide()),
            .blockQuote(BlockQuote(id: BlockID("q"), children: [.table(quoted())], author: [])),
        ])
        editor.layoutIfNeeded()
        guard let topIndex = editor.currentRoles.firstIndex(where: { $0.owningTable?.id == BlockID("t0") }),
              let quotedIndex = editor.currentRoles.firstIndex(where: { $0.owningTable?.id == BlockID("t1") })
        else { return XCTFail("no tables") }
        XCTAssertNotEqual(editor.engine.id_placedRunContentViewForBlock(at: UInt(topIndex)),
                          editor.engine.id_placedRunContentViewForBlock(at: UInt(quotedIndex)),
                          "one run each")

        editor.engine.id_setPlacedRunContentOffset(60, forBlockAt: UInt(topIndex))
        editor.engine.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: UInt(topIndex)), 60, accuracy: 0.5)
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: UInt(quotedIndex)), 0, accuracy: 0.5,
                       "the quoted table stays where it was")
    }

    /// …and each table is clipped by its OWN window. The engine keys a run's clip by the run's FIRST
    /// block, so while two tables shared a run the second one wore the first's clip: a quoted table
    /// following a top-level one was cut at the canvas edge instead of at the quote's interior
    /// ("a scrollable table inside a block quote is not properly clipped", same report).
    func test_aQuotedTableAfterATopLevelOneIsStillCutAtItsContainersInterior() {
        editor.document = Document(blocks: [
            .table(wide()),
            .blockQuote(BlockQuote(id: BlockID("q"), children: [.table(quoted())], author: [])),
        ])
        editor.layoutIfNeeded()
        guard let quotedIndex = editor.currentRoles.firstIndex(where: { $0.owningTable?.id == BlockID("t1") }),
              let run = editor.engine.id_placedRunContentViewForBlock(at: UInt(quotedIndex))?.superview,
              let placement = editor.tablePlacements[BlockID("t1")] else { return XCTFail("no quoted run") }
        XCTAssertGreaterThan(placement.containerIndent, 0, "precondition: the quote indents its content")
        let window = run.convert(run.bounds, to: editor.engine)
        let gutter = EngineTableStructuralChrome.gripGutter
        XCTAssertEqual(window.minX,
                       editor.engine.textContainerInset.left + placement.containerIndent - gutter,
                       accuracy: 0.5, "cut at the quote's interior, not at the canvas")
        XCTAssertEqual(window.maxX,
                       editor.engine.textContainerInset.left + editor.availableTableWidth
                           - placement.containerTrailingInset + gutter,
                       accuracy: 0.5, "and at the quote's trailing side, not at the canvas")
    }

    /// **A quoted table can be scrolled to its own right edge, and the grip hanging off it arrives
    /// whole.** The clip narrows a nested run's window by the quote's trailing inset, and the run's
    /// TRAVEL was the full column's either way — so the last 22pt of the last column could not be
    /// reached and the trailing grip, which hangs `gripGutter` past that edge, was never drawn at
    /// all ("table's right control handle is clipped inside a quote", user, K3).
    func test_aQuotedTableScrollsToItsOwnRightEdgeAndShowsItsTrailingGrip() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [.table(wide(columns: 5))], author: [])),
        ])
        editor.layoutIfNeeded()
        guard let index = editor.currentRoles.firstIndex(where: { $0.owningTable != nil })
        else { return XCTFail("no table") }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: index), length: 0)
        editor.layoutIfNeeded()
        guard let run = editor.engine.id_placedRunContentViewForBlock(at: UInt(index))?.superview
                as? UIScrollView else { return XCTFail("no run") }

        editor.engine.id_setPlacedRunContentOffset(9999, forBlockAt: UInt(index))
        editor.engine.layoutIfNeeded()
        editor.setNeedsLayout(); editor.layoutIfNeeded()

        guard let lastCell = editor.currentRoles.lastIndex(where: { $0.owningTable != nil }),
              let chrome = editor.tableStructuralChromeViews[BlockID("t0")] else { return XCTFail("no chrome") }
        let cellFrame = editor.engine.id_frameForBlock(at: UInt(lastCell))
        let window = run.convert(run.bounds, to: editor.engine)
        XCTAssertLessThanOrEqual(cellFrame.maxX, window.maxX + 0.5,
                                 "scrolled to the end, no part of the table is left beyond its window")

        // …and the grip that hangs off that edge is inside the chrome's own window, whole.
        let trailing = chrome.drawnHandleRects.filter { $0.height > EngineTableStructuralChrome.gripHeight + 0.5 }
            .max { $0.minX < $1.minX }
        guard let trailing else { return XCTFail("no row grip at all — \(chrome.drawnHandleRects)") }
        XCTAssertGreaterThan(trailing.minX, chrome.bounds.midX, "it is the TRAILING grip")
        XCTAssertLessThanOrEqual(trailing.maxX, chrome.bounds.maxX + 0.5, "drawn whole, not cut by the window")
    }

    /// **Everything the table draws stops at the same x.** The cells' clip and the chrome's window
    /// used to differ by a grip's reach, and the half nobody was looking at was the OUTLINE: a
    /// selected cell scrolled partly out had its outline drawn 15pt further into the quote's indent
    /// than its own cells — 1pt from the band's edge, against the bar.
    ///
    /// Measured on the drawn outline, converted into the engine's space, against the window the
    /// engine cuts the cells at.
    func test_aScrolledOutlineIsCutWhereTheCellsAre() {
        editor.engine.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [.table(wide(columns: 5))], author: [])),
        ])
        guard let index = editor.currentRoles.firstIndex(where: { $0.owningTable != nil })
        else { return XCTFail("no table") }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: index), length: 0)
        editor.layoutIfNeeded()
        // Enough to carry the first cell's left edge out of the window, so its outline straddles it.
        editor.engine.id_setPlacedRunContentOffset(40, forBlockAt: UInt(index))
        editor.engine.layoutIfNeeded()
        editor.setNeedsLayout(); editor.layoutIfNeeded()

        guard let chrome = editor.tableStructuralChromeViews[BlockID("t0")],
              let outline = chrome.drawnOutlineRect,
              let run = editor.engine.id_placedRunContentViewForBlock(at: UInt(index))?.superview
        else { return XCTFail("no chrome") }
        let cells = run.convert(run.bounds, to: editor.engine)
        let drawn = chrome.convert(outline, to: editor.engine).intersection(chrome.convert(chrome.bounds, to: editor.engine))
        XCTAssertLessThan(outline.minX, 0, "precondition: the outline really does straddle the edge")
        XCTAssertEqual(drawn.minX, cells.minX, accuracy: 0.5,
                       "the outline is cut where the cells are, not a grip's reach further in")
    }

    // MARK: The placement check

    /// The instrument, on the defect it was written for. "The chrome stayed put while the cells
    /// scrolled" is exactly a view whose frame is no longer what the geometry says — so moving one
    /// by hand is the same shape as a placement pass that did not run.
    func test_thePlacementCheckSeesAChromeThatIsNotWhereTheGeometryPutsIt() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        guard let chrome = structuralChrome() else { return XCTFail("no structural chrome") }
        XCTAssertTrue(editor.derivedViewPlacementDrift().isEmpty,
                      "precondition: \(editor.derivedViewPlacementDrift())")
        chrome.frame = chrome.frame.offsetBy(dx: 40, dy: 0)
        XCTAssertEqual(editor.derivedViewPlacementDrift().count, 1,
                       "\(editor.derivedViewPlacementDrift())")
    }

    /// And that it RUNS on the pass nothing else sees. A run's scroll dirties the engine alone, so
    /// without a check on the engine's own pass a chrome that stopped following would be caught by
    /// nothing until the next host layout — which a scroll does not schedule.
    func test_theEnginesOwnPassChecksPlacement() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        _ = structuralChrome()
        let before = editor.derivedViewPlacementVerificationCount
        scrollRun(to: 40)
        XCTAssertGreaterThan(editor.derivedViewPlacementVerificationCount, before)
    }

    // MARK: Nothing draws

    /// The whole point of the chrome being a view tree: a scroll moves every piece of it, every
    /// tick, and rasterises nothing. A `draw(_:)` override is the one thing that would put a
    /// per-pixel pass back on that path, so its ABSENCE is what this asserts — on the class, where
    /// it cannot come back unnoticed.
    func test_noTableChromeClassOverridesDraw() {
        let plain = class_getMethodImplementation(UIView.self, #selector(UIView.draw(_:)))
        for subject in [TableChromeView.self, TableStructuralChromeView.self,
                        TableStructuralControlView.self] as [AnyClass] {
            XCTAssertEqual(class_getMethodImplementation(subject, #selector(UIView.draw(_:))), plain,
                           "\(subject) draws; the chrome is a view tree")
        }
    }

    /// `contentMode = .redraw` is the other door: it asks UIKit for a fresh `draw(_:)` on every
    /// bounds change, which for chrome that resizes with the selection is every frame of a knob
    /// drag. The chrome's views stretch instead.
    func test_noTableChromeViewAsksToRedrawOnResize() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        guard let chrome = structuralChrome() else { return XCTFail("no structural chrome") }
        var pending: [UIView] = [chrome, editor.tableChromeViews[BlockID("t0")]].compactMap { $0 }
        var index = 0
        while index < pending.count {
            let view = pending[index]; index += 1
            XCTAssertNotEqual(view.contentMode, .redraw, "\(type(of: view)) redraws when resized")
            pending.append(contentsOf: view.subviews)
        }
        XCTAssertGreaterThan(pending.count, 4, "the sweep reached the chrome's pieces")
    }

    /// And the same question asked of the run: after a scroll has moved the outline, the grips and
    /// the knobs, no layer in either chrome has anything to rasterise.
    func test_aScrollLeavesEveryChromeLayerWithNothingToDisplay() {
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        editor.selectTableColumns(1...1)
        guard let chrome = structuralChrome() else { return XCTFail("no structural chrome") }
        window.layoutIfNeeded()
        scrollRun(to: 40)
        window.layoutIfNeeded()
        var pending: [CALayer] = [chrome.layer, editor.tableChromeViews[BlockID("t0")]?.layer].compactMap { $0 }
        var index = 0
        while index < pending.count {
            let layer = pending[index]; index += 1
            let owner = layer.delegate.map { String(describing: type(of: $0)) } ?? String(describing: type(of: layer))
            XCTAssertFalse(layer.needsDisplay(), "\(owner) wants to redraw after a scroll")
            pending.append(contentsOf: layer.sublayers ?? [])
        }
        XCTAssertGreaterThan(pending.count, 4, "the sweep reached the chrome's layers")
    }

    // MARK: Where a table is clipped

    /// The top level: the table is positioned at the text inset like every other block, but its clip
    /// is the CANVAS, so a scrolled table passes under the inset and is cut at the editor's edge
    /// rather than stopping short of it. The chrome was already cut there — by the engine's own
    /// bounds — while the cells stopped at the column, which is the mismatch as reported.
    func test_aTopLevelTableIsCutAtTheCanvasAndNotAtTheTextInset() {
        editor.engine.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        editor.document = Document(blocks: [.table(wide())])
        focusFirstCell()
        editor.layoutIfNeeded()
        guard let run = editor.engine.id_placedRunContentViewForBlock(at: 0)?.superview,
              let clip = editor.tableClipX(forTableAt: 0),
              let chrome = structuralChrome() else { return XCTFail("no run") }
        XCTAssertEqual(clip.min, 0, accuracy: 0.5)
        XCTAssertEqual(clip.max, editor.engine.bounds.width, accuracy: 0.5)
        let window = run.convert(run.bounds, to: editor.engine)
        XCTAssertEqual(window.minX, 0, accuracy: 0.5, "the cells are cut at the canvas")
        XCTAssertEqual(window.maxX, editor.engine.bounds.width, accuracy: 0.5)
        XCTAssertEqual(chrome.frame.minX, window.minX, accuracy: 0.5, "and so is the chrome")
        XCTAssertEqual(chrome.frame.maxX, window.maxX, accuracy: 0.5)
        // The table itself did not move: it is still laid out at the text inset.
        XCTAssertEqual(editor.tableFrame(forTableAt: 0)?.minX ?? -1, 16, accuracy: 0.5)
    }

    /// Nested, the table and its chrome are cut at ONE boundary: the container's interior opened by
    /// a grip's reach, which is where the handles hanging off the table's edges are drawn.
    ///
    /// The cells' clip and the chrome's window used to differ by exactly that gutter, and the
    /// difference showed on more than the handles — a selected cell scrolled half out had its
    /// OUTLINE drawn 15pt further into the quote's indent than its cells. Where the table comes to
    /// REST is the separate question (`tableColumnOutsets`): the interior itself.
    func test_aNestedTableIsCutAtOneBoundaryWithItsChrome() {
        editor.engine.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [.table(wide())], author: []))
        ])
        guard let index = editor.currentRoles.firstIndex(where: { $0.owningTable != nil })
        else { return XCTFail("no table role") }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: index), length: 0)
        editor.layoutIfNeeded()
        guard let clip = editor.tableClipX(forTableAt: index),
              let run = editor.engine.id_placedRunContentViewForBlock(at: UInt(index))?.superview,
              let chrome = editor.tableStructuralChromeViews[BlockID("t0")],
              let placement = editor.tablePlacements[BlockID("t0")] else { return XCTFail("no run") }
        XCTAssertGreaterThan(placement.containerIndent, 0, "the quote indents its content")
        // ONE BOUNDARY: the cells are cut at the container's interior opened by a grip's reach on
        // each side, and the chrome's window is the same rect (asserted below), so nothing the table
        // draws stops anywhere else.
        let gutter = EngineTableStructuralChrome.gripGutter
        let window = run.convert(run.bounds, to: editor.engine)
        XCTAssertEqual(window.minX, 16 + placement.containerIndent - gutter, accuracy: 0.5,
                       "a grip's reach inside the quote's bar, and no further")
        XCTAssertEqual(window.maxX,
                       16 + editor.availableTableWidth - placement.containerTrailingInset + gutter,
                       accuracy: 0.5, "and the same reach into the quote's trailing margin")
        // …while the table RESTS on the interior itself: the column is not the window.
        let column = editor.tableColumnOutsets(forTableAt: index)
        XCTAssertEqual(column.left, -placement.containerIndent, accuracy: 0.5)
        XCTAssertEqual(column.right, -placement.containerTrailingInset, accuracy: 0.5)
        // THE TABLE is flush with that interior: it reserves nothing for its own chrome, because the
        // quote's indent is already the gutter the grips hang in (user report, 2026-09-11 — the
        // reserved version read as a table pushed in from everything around it).
        XCTAssertEqual(placement.indent, placement.containerIndent, accuracy: 0.5,
                       "a nested table lines up with the quote's other children")
        // THE CHROME IS THAT SAME WINDOW — one boundary, two consumers, no overhang between them.
        XCTAssertEqual(clip.min, window.minX, accuracy: 0.5, "the cells are cut where the chrome is")
        XCTAssertEqual(clip.max, window.maxX, accuracy: 0.5)
        XCTAssertEqual(chrome.frame.minX, clip.min, accuracy: 0.5, "the chrome view IS that window")
        XCTAssertEqual(chrome.frame.maxX, clip.max, accuracy: 0.5)
        // …and the table sits a gutter inside it, which is what gives the leading grip its room.
        // A GRID BORDER more is allowed and no more: the table's own frame starts one border right
        // of the run's window, and pinning that incidental point here would make this test a second
        // statement about border bookkeeping rather than about the grip fitting.
        XCTAssertGreaterThanOrEqual(chrome.currentTableOrigin.x, gutter - 0.5,
                                    "the leading grip would be clipped against the quote's bar")
        XCTAssertLessThanOrEqual(chrome.currentTableOrigin.x, gutter + 2.0,
                                 "and the table is not pushed in from its container")
    }

    // MARK: - A tap that catches a moving table presses nothing

    /// Stopping a scrolling or bouncing table with a finger is a CATCH, not a tap on what is under
    /// it — which is what every scroll view in iOS does for its own content, and what a placed run
    /// cannot do for itself: it never receives the touch. So the host's chrome inside a run refuses
    /// the touch on the run's behalf, at touch-DOWN (a tap fires on release, by which time the
    /// finger has lifted and the run has been let go — a gate asked then sees a settled run).
    func test_aTouchOnChromeInsideAMovingRunIsRefusedAndOneInsideASettledRunIsNot() {
        editor.document = Document(blocks: [.table(wide())])
        editor.layoutIfNeeded()
        guard let content = editor.engine.id_placedRunContentViewForBlock(at: 0),
              let run = content.superview as? UIScrollView else { return XCTFail("no run") }

        // A control the host hangs inside the run — a pill or a formula target is exactly this.
        let chrome = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        content.addSubview(chrome)
        let recognizer = editor.gatedTapRecognizer(action: #selector(RichTextEngineEditorView.layoutSubviews))
        chrome.addGestureRecognizer(recognizer)
        guard let gate = recognizer.delegate else { return XCTFail("the gate is the delegate") }

        XCTAssertTrue(gate.gestureRecognizer!(recognizer, shouldReceive: UITouch()),
                      "a settled run presses normally")

        // The run in flight: the state a catch leaves it in, reached the way the run itself reads it.
        run.setValue(CACurrentMediaTime(), forKey: "id_lastAnimatedMotionTime")
        XCTAssertFalse(gate.gestureRecognizer!(recognizer, shouldReceive: UITouch()),
                       "a touch that catches a moving run does not also press what is under it")

        // And it comes back: the gate suppresses nothing once the run has genuinely settled.
        run.setValue(CACurrentMediaTime() - 1.0, forKey: "id_lastAnimatedMotionTime")
        XCTAssertTrue(gate.gestureRecognizer!(recognizer, shouldReceive: UITouch()),
                      "a settled run presses normally again")
    }

    /// The structural grips and knobs are parented to the ENGINE, not into the run — the row grip
    /// would otherwise ride the horizontal scroll out of the gutter — so the run's pan, which is
    /// hosted on the canvas BELOW, is never offered a touch the chrome swallows. Refusing the grip's
    /// own recogniser therefore stopped the action and left nothing to catch the table: the touch did
    /// nothing at all (K3). The chrome declines the HIT instead, so the touch reaches the run.
    func test_theStructuralChromeIsTransparentWhileItsTableIsMovingSoTheTouchReachesTheRun() {
        editor.document = Document(blocks: [.table(wide())])
        editor.layoutIfNeeded()
        editor.selectTableStructure(.rows(0...0))
        editor.layoutIfNeeded()
        guard let chrome = editor.tableStructuralChromeViews[BlockID("t0")] else {
            return XCTFail("no structural chrome")
        }
        guard let content = editor.engine.id_placedRunContentViewForBlock(at: 0),
              let run = content.superview as? UIScrollView else { return XCTFail("no run") }
        // A GRIP specifically: a knob is drawing only — it claims a drag through the editor's pan and
        // deliberately takes no hit, or its 44pt box would swallow taps meant for the cell.
        guard let grip = chrome.controlViews.first(where: { !$0.isHidden && $0.payload.isGrip }) else {
            return XCTFail("no visible grip")
        }
        let onTheControl = CGPoint(x: grip.frame.midX, y: grip.frame.midY)

        XCTAssertTrue(chrome.point(inside: onTheControl, with: nil),
                      "a settled table's controls take their own touches")

        run.setValue(CACurrentMediaTime(), forKey: "id_lastAnimatedMotionTime")
        XCTAssertFalse(chrome.point(inside: onTheControl, with: nil),
                       "while the table moves the chrome takes no touch, so the run below catches it")
        XCTAssertNil(chrome.hitTest(onTheControl, with: nil),
                     "and hit-testing walks past the whole chrome, controls included")

        run.setValue(CACurrentMediaTime() - 1.0, forKey: "id_lastAnimatedMotionTime")
        XCTAssertTrue(chrome.point(inside: onTheControl, with: nil),
                      "and the controls come back once it settles")
    }
    /// A FOCUSED CELL STAYS TAPPABLE: the resize knobs claim a drag, never the tap under them.
    ///
    /// A knob's hit box is 44pt — the right size for a drag and far too big for a tap — and while
    /// those boxes were hit-testable views, **77% of an 87x34 focused cell was dead**: the touch
    /// landed on a view with only a pan attached, so the text interaction never saw it and neither a
    /// caret nor the edit menu could be placed ("almost impossible to invoke the context menu by
    /// tapping in a cell when focused", K3 — and it worked in body text, which has no chrome over
    /// it). The knob's drag moved to a pan on the EDITOR, which competes for the gesture without
    /// owning the touch.
    ///
    /// Asserted as coverage over the whole cell rather than at one point: the defect was an AREA,
    /// and a single sampled point would have passed against three of the four knobs.
    func test_aFocusedCellIsFullyTappableThoughItsKnobBoxesCoverIt() {
        editor.document = Document(blocks: [.table(wide())])
        editor.layoutIfNeeded()
        for focused in 0..<4 {
            editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: focused), length: 0)
            editor.layoutIfNeeded()
            guard let chrome = editor.tableStructuralChromeViews[BlockID("t0")] else {
                return XCTFail("the chrome is live whenever the caret is in a table")
            }
            let cell = editor.engine.id_frameForBlock(at: UInt(focused))
            guard !cell.isNull else { return XCTFail("no frame for cell \(focused)") }

            var swallowed: [CGPoint] = []
            var y = cell.minY + 1
            while y < cell.maxY { var x = cell.minX + 1
                while x < cell.maxX {
                    let p = CGPoint(x: x, y: y)
                    if chrome.point(inside: editor.engine.convert(p, to: chrome), with: nil) {
                        swallowed.append(p)
                    }
                    x += 2 }
                y += 2 }
            XCTAssertEqual(swallowed.count, 0,
                           "cell \(focused): \(swallowed.count) points inside it are taken by the chrome")

            // The knobs are still THERE — this is not "the chrome stopped drawing them".
            XCTAssertFalse(chrome.drawnKnobRects.isEmpty, "cell \(focused) still shows its knobs")
            XCTAssertTrue(chrome.drawnKnobRects.contains { $0.intersects(cell) },
                          "cell \(focused): a knob box still overlaps the cell, which is the point")
        }
    }
}

#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Table horizontal scroll is folded into every canvas-space geometry answer via
/// tableContentOffsetX(forGlobal:) (DCV). The seam must not lose it.
///
/// NOTE: `TableBackingView` has no `contentOffset` property of its own — it hosts a real `UIScrollView`
/// (`scroll`, internal) whose `contentOffset` is the single source of truth (see the type's doc comment).
/// The brief's literal snippet (`tableView.contentOffset = …`) does not compile; every scroll-offset write
/// below goes through `tableView.scroll.contentOffset` instead, which is the real production knob
/// (`scrollViewDidScroll` calls `canvas.tableDidScroll(self)` on exactly that scroll view).
@available(iOS 16.0, *)
final class TableScrollGeometryCharacterizationTests: XCTestCase {
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id),
             blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }

    /// A table that MUST scroll horizontally at canvas width 320. That is the load-bearing
    /// precondition for the two shift assertions below: four 160pt columns = 640pt of content
    /// against a ~320pt canvas (less the content padding), so `contentOffset.x = 40` is reachable
    /// and the caret genuinely moves. `T/CanvasTableNavTests.swift:11-18` builds the same shape
    /// with two 120pt columns, which fits and would NOT scroll — do not copy that one verbatim.
    private func makeWideTableCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 160), ColumnSpec(width: 160),
                      ColumnSpec(width: 160), ColumnSpec(width: 160)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta"),
                                                  cell("c", "Gamma"), cell("d", "Delta")])]))],
            width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 300)
        v.layoutIfNeeded()
        return v
    }

    func test_caretRect_insideAScrolledCell_shiftsWithTheContentOffset() {
        let v = makeWideTableCanvas()
        // NOTE: `v.boxes.first!.textStart` (the brief's literal snippet) is the TABLE's own DEGENERATE
        // text extent (a `TableBlockBox`'s real content lives in its cells, not its own `textStart` —
        // see the "resolveBox degenerate-container misroute" tech-debt note in the package CLAUDE.md), so
        // `textStart + 1` does NOT land inside cell "a"'s text — it resolves to no leaf region at all, and
        // `caretRect` falls through to `.zero` regardless of scroll (verified: this made the assertion
        // trivially fail at 0 == 0, not a real shift). The real in-cell probe is the cell's own leaf
        // region, exactly as `CanvasTableNavTests` resolves it.
        let inCell = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!.globalStart + 1
        let before = v.caretRect(for: DocumentTextPosition(inCell))
        guard let tableView = v.blockViewForTesting(v.boxes.first!.id) as? TableBackingView else {
            return XCTFail("the table must be realized for this characterization")
        }
        tableView.scroll.contentOffset = CGPoint(x: 40, y: 0)
        v.tableDidScroll(tableView)
        let after = v.caretRect(for: DocumentTextPosition(inCell))
        XCTAssertEqual(after.minX, before.minX - 40, accuracy: 0.5)
    }

    func test_selectionRects_insideAScrolledCell_shiftWithTheContentOffset() {
        let v = makeWideTableCanvas()
        // Same fix as the caretRect test above: probe cell "a"'s own leaf region, not the table box's
        // degenerate `textStart` — the brief's literal offset resolved to no leaf region, which made
        // `before` an EMPTY array and the `zip` loop below a silent no-op (a vacuous pass).
        let start = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!.globalStart + 1
        let range = DocumentTextRange(DocumentTextPosition(start), DocumentTextPosition(start + 3))
        let before = v.selectionRects(for: range).map { $0.rect.minX }
        XCTAssertFalse(before.isEmpty, "the probe range must resolve to at least one selection rect, or the shift check below is vacuous")
        guard let tableView = v.blockViewForTesting(v.boxes.first!.id) as? TableBackingView else {
            return XCTFail("the table must be realized for this characterization")
        }
        tableView.scroll.contentOffset = CGPoint(x: 40, y: 0)
        v.tableDidScroll(tableView)
        let after = v.selectionRects(for: range).map { $0.rect.minX }
        XCTAssertEqual(before.count, after.count)
        for (b, a) in zip(before, after) { XCTAssertEqual(a, b - 40, accuracy: 0.5) }
    }

    func test_tableDidScroll_bumpsTheLayoutGeneration() {
        let v = makeWideTableCanvas()
        guard let tableView = v.blockViewForTesting(v.boxes.first!.id) as? TableBackingView else {
            return XCTFail("the table must be realized")
        }
        let before = v.layoutGeneration
        v.tableDidScroll(tableView)
        XCTAssertGreaterThan(v.layoutGeneration, before)
    }

    func test_caretIsReparentedIntoARealizedTableBackingView() {
        let v = makeWideTableCanvas()
        // Same fix as above: the table box's own `textStart` is a degenerate structural extent, not
        // in-cell text (see the "resolveBox degenerate-container misroute" note) — probe the real cell.
        let inCell = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!.globalStart + 1
        let placement = v.caretHostPlacement(forGlobal: inCell)
        XCTAssertNotNil(placement)
        XCTAssertFalse(placement!.container === v, "an in-cell caret hosts in the table's scrolling view")
    }

    func test_theSeededTableIsActuallyHorizontallyScrollable() {
        let v = makeWideTableCanvas()
        guard let tableView = v.blockViewForTesting(v.boxes.first!.id) as? TableBackingView else {
            return XCTFail("the table must be realized")
        }
        XCTAssertGreaterThan(tableView.scroll.contentSize.width, tableView.scroll.bounds.width + 40,
                             "widen the columns until it does — the two shift tests are vacuous otherwise")
    }
}
#endif

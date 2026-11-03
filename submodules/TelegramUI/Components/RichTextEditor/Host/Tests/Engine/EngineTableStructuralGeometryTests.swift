import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// R7-tables rung B — the structural chrome's geometry, computed with NO view and NO engine.
///
/// That is the point of the struct, and it is what let `EngineBlockSpacing`'s rules be pinned at all:
/// a geometry that needs a live editor can only be tested through one.
///
/// Every rect here is TABLE-LOCAL — the grid's own space, table top-left at the origin. The view
/// applies the table's origin and the horizontal scroll offset, so this struct never sees either.
@available(iOS 18.4, *)
final class EngineTableStructuralGeometryTests: XCTestCase {

    private func grid(rows: Int = 2, columns: Int = 2) -> EngineTableGrid {
        EngineTableGrid.solve(table: TableBlock.empty(rows: rows, columns: columns),
                              availableWidth: 320, usedHeights: [:])
    }

    private func chrome(_ selection: EngineTableStructuralSelection?,
                        focused: TableRect? = nil,
                        rows: Int = 2, columns: Int = 2) -> EngineTableStructuralChrome {
        EngineTableStructuralChrome(grid: grid(rows: rows, columns: columns),
                                    rowCount: rows, columnCount: columns,
                                    selection: selection, focusedCell: focused)
    }

    // MARK: Grips

    func test_theRowGripSitsLeftOfTheTable() {
        let handles = chrome(.rows(0...0)).handles()
        guard let row = handles.first(where: { $0.side == .leading })
        else { return XCTFail("no leading row grip") }
        XCTAssertEqual(row.rect.width, 17)
        XCTAssertLessThanOrEqual(row.rect.maxX, 2, "its right edge tucks 2pt under the table's left border")
        XCTAssertLessThan(row.rect.minX, 0, "so it is always LEFT of the table, even at zero page margin")
    }

    /// The mirror: the same grip in the right gutter, tucked under the table's other border. Both
    /// ride the scroll, so a wide table shows the leading one at its start and this one at its end.
    func test_theRowGripIsMirroredOnTheTablesRightEdge() {
        let handles = chrome(.rows(0...0)).handles()
        guard let leading = handles.first(where: { $0.side == .leading }),
              let trailing = handles.first(where: { $0.side == .trailing })
        else { return XCTFail("no mirrored pair") }
        XCTAssertEqual(trailing.rect.width, leading.rect.width)
        XCTAssertEqual(trailing.rect.minY, leading.rect.minY, accuracy: 0.01)
        XCTAssertEqual(trailing.rect.height, leading.rect.height, accuracy: 0.01)
        XCTAssertEqual(trailing.rect.minX, grid().size.width - 2, accuracy: 0.01,
                       "its left edge tucks 2pt under the table's right border")
        XCTAssertEqual(trailing.kind, leading.kind, "both select the same rows")
    }

    func test_theRowGripSpansTheWholeSelectedRange() {
        let one = chrome(.rows(0...0)).handles().first { $0.side == .leading }
        let both = chrome(.rows(0...1)).handles().first { $0.side == .leading }
        XCTAssertGreaterThan(both!.rect.height, one!.rect.height)
        XCTAssertEqual(both!.rect.minY, one!.rect.minY, accuracy: 0.01, "the range starts where row 0 does")
    }

    func test_theColumnGripSitsBelowTheTable() {
        let handles = chrome(.columns(0...0)).handles()
        guard let column = handles.first(where: { if case .columns = $0.kind { return true }; return false })
        else { return XCTFail("no column grip") }
        XCTAssertEqual(column.rect.height, 17)
        XCTAssertGreaterThanOrEqual(column.rect.minY, grid().size.height - 1)
    }

    func test_theColumnGripSpansTheWholeSelectedRange() {
        let one = chrome(.columns(0...0)).handles().first { $0.side == .below }
        let both = chrome(.columns(0...1)).handles().first { $0.side == .below }
        XCTAssertGreaterThan(both!.rect.width, one!.rect.width)
    }

    /// With nothing committed the grips still show, spanning the FOCUSED cell — that is how a tap on a
    /// grip is reachable in the first place.
    func test_theGripsSpanTheFocusedCellWhenNothingIsCommitted() {
        let handles = chrome(nil, focused: TableRect(top: 1, left: 1, bottom: 1, right: 1)).handles()
        XCTAssertEqual(handles.count, 3, "a row grip in each gutter, and the column's")
    }

    // MARK: Knobs

    func test_aRowSelectionHasTwoKnobsOnItsVerticalEnds() {
        let knobs = chrome(.rows(0...0)).knobs()
        XCTAssertEqual(knobs.count, 2)
        XCTAssertEqual(knobs.compactMap(\.end).sorted { "\($0)" < "\($1)" }.count, 2)
        XCTAssertTrue(knobs.allSatisfy { $0.corner == nil })
        XCTAssertEqual(knobs[0].rect.midX, knobs[1].rect.midX, accuracy: 0.01, "vertically stacked")
        XCTAssertEqual(knobs[0].rect.width, 44, "a generous hit box")
    }

    func test_aColumnSelectionHasTwoKnobsOnItsHorizontalEnds() {
        let knobs = chrome(.columns(0...0)).knobs()
        XCTAssertEqual(knobs.count, 2)
        XCTAssertTrue(knobs.allSatisfy { $0.corner == nil })
        XCTAssertEqual(knobs[0].rect.midY, knobs[1].rect.midY, accuracy: 0.01, "side by side")
    }

    /// Four knobs, drawn at the CENTRE OF EACH SIDE but each keeping its corner identity, so the 2D
    /// drag (which pins the opposite corner) is unchanged — only the anchor moves.
    func test_aCellSelectionHasFourCornerKnobsAtTheSideCentres() {
        let knobs = chrome(.cells(TableRect(top: 0, left: 0, bottom: 0, right: 0))).knobs()
        XCTAssertEqual(knobs.count, 4)
        XCTAssertTrue(knobs.allSatisfy { $0.end == nil })
        XCTAssertEqual(Set(knobs.compactMap(\.corner)).count, 4, "all four identities are distinct")
    }

    func test_theFocusedCellGetsTheSameFourKnobs() {
        let knobs = chrome(nil, focused: TableRect(top: 0, left: 0, bottom: 0, right: 0)).knobs()
        XCTAssertEqual(knobs.count, 4)
        XCTAssertEqual(Set(knobs.compactMap(\.corner)).count, 4)
    }

    func test_nothingSelectedAndNoFocusMeansNoChromeAtAll() {
        XCTAssertTrue(chrome(nil).handles().isEmpty)
        XCTAssertTrue(chrome(nil).knobs().isEmpty)
        XCTAssertNil(chrome(nil).outlineRect())
    }

    // MARK: Outline

    func test_aRowSelectionsOutlineSpansTheFullTableWidth() {
        guard let outline = chrome(.rows(0...0)).outlineRect() else { return XCTFail("no outline") }
        XCTAssertEqual(outline.width, grid().size.width, accuracy: 1.0)
    }

    func test_aColumnSelectionsOutlineSpansTheFullTableHeight() {
        guard let outline = chrome(.columns(0...0)).outlineRect() else { return XCTFail("no outline") }
        XCTAssertEqual(outline.height, grid().size.height, accuracy: 1.0)
    }

    /// Corners round only where the selection meets the table's OWN rounded outer corner — and the
    /// corners adjacent to a grip stay square, because the grip's bar abuts them.
    /// A row selection has a grip on BOTH sides, so neither end rounds: an outline corner curving
    /// away from a bar's square edge reads as a notch. The left pair has been square since the grip
    /// existed; the right pair joined them when the grip was mirrored.
    func test_aRowSelectionRoundsNothingBecauseAGripAbutsEachEnd() {
        XCTAssertTrue(chrome(.rows(0...0)).outlineCorners().isEmpty)
        XCTAssertTrue(chrome(.rows(0...1)).outlineCorners().isEmpty, "including the whole table")
    }

    func test_aColumnSelectionRoundsOnlyItsTopCorners() {
        let corners = chrome(.columns(0...0)).outlineCorners()
        XCTAssertTrue(corners.contains(.topLeft), "column 0 reaches the table's top-left")
        XCTAssertFalse(corners.contains(.bottomLeft), "the column grip is BELOW, so that corner is square")
    }

    func test_aFocusedCornerCellRoundsThatCornerOnly() {
        let corners = chrome(nil, focused: TableRect(top: 0, left: 0, bottom: 0, right: 0)).outlineCorners()
        XCTAssertEqual(corners, .topLeft)
    }

    func test_aWholeTableCellRectRoundsAllFour() {
        let corners = chrome(.cells(TableRect(top: 0, left: 0, bottom: 1, right: 1))).outlineCorners()
        XCTAssertTrue(corners.contains(.topLeft) && corners.contains(.topRight)
                      && corners.contains(.bottomLeft) && corners.contains(.bottomRight))
    }
}

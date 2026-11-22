import XCTest
@testable import RichTextEditorCore

/// Covers `TableBlock.mergingCells(in:)` / `TableBlock.splittingCell(at:)` — the pure structural
/// transforms backing the table merge/split commands. See `TableBlock+Editing.swift`'s doc comment.
final class TableMergeSplitTests: XCTestCase {

    // MARK: Fixtures

    /// A dense table built from a row-major grid of labels; each cell is a single labelled-text
    /// paragraph (label used as both the cell's `BlockID` and its plain text, so identity and content
    /// assertions can share one label).
    private func denseTable(_ labels: [[String]], columnWidths: Double = 100) -> TableBlock {
        let columnCount = labels.first?.count ?? 0
        let columns = (0..<columnCount).map { _ in ColumnSpec(width: columnWidths) }
        let rows: [Row] = labels.enumerated().map { (r, rowLabels) in
            Row(id: BlockID("r\(r)"), cells: rowLabels.map { labelledCell($0) })
        }
        return TableBlock(id: BlockID("t"), columns: columns, rows: rows)
    }

    private func labelledCell(_ label: String, colspan: Int = 1, rowspan: Int = 1,
                              background: RGBAColor? = nil,
                              horizontalAlignment: TextAlignment = .center,
                              verticalAlignment: VerticalAlignment = .top,
                              isHeader: Bool = false) -> Cell {
        Cell(id: BlockID(label),
             blocks: [.paragraph(ParagraphBlock(id: BlockID(label + "_p"), runs: [TextRun(text: label)]))],
             background: background, horizontalAlignment: horizontalAlignment,
             verticalAlignment: verticalAlignment, isHeader: isHeader,
             colspan: colspan, rowspan: rowspan)
    }

    /// A cell containing a single empty (default) paragraph — the shape of a freshly-created empty cell.
    private func emptyCell(_ id: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "_p")))])
    }

    /// The plain texts of a cell's paragraph blocks, in declaration order.
    private func texts(of cell: Cell) -> [String] {
        cell.blocks.compactMap { block -> String? in
            guard case .paragraph(let p) = block else { return nil }
            return p.text
        }
    }

    // MARK: 1. Merge 2x2

    func test_mergingCells_2x2_concatenatesBlocksRowMajor() {
        let table = denseTable([["A", "B"], ["C", "D"]])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 1))

        let map = TableMap(merged)
        XCTAssertTrue(map.isWellFormed)

        let anchor = map.anchor(atRow: 0, column: 0)
        XCTAssertEqual(anchor?.colspan, 2)
        XCTAssertEqual(anchor?.rowspan, 2)

        XCTAssertEqual(merged.rows[0].cells.count, 1)
        XCTAssertEqual(merged.rows[1].cells.count, 0)

        let anchorCell = merged.rows[0].cells[0]
        XCTAssertEqual(texts(of: anchorCell), ["A", "B", "C", "D"])
    }

    // MARK: 1b. Empty cells contribute NO blank paragraph to the merged cell

    func test_mergingCells_dropsEmptyCells_noBlankParagraphs() {
        // Row: "A" | (empty) | "C" — merging all three must not pool the empty cell's blank paragraph.
        let table = TableBlock(id: BlockID("t"),
            columns: (0..<3).map { _ in ColumnSpec(width: 100) },
            rows: [Row(id: BlockID("r0"), cells: [labelledCell("A"), emptyCell("e"), labelledCell("C")])])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 2))
        XCTAssertEqual(texts(of: merged.rows[0].cells[0]), ["A", "C"],
                       "the empty middle cell adds no blank paragraph between A and C")
    }

    func test_mergingCells_emptyAnchor_keepsOnlyNonEmptyContent() {
        // Anchor empty, neighbor "B": the anchor's own blank must be dropped, not lead the content.
        let table = TableBlock(id: BlockID("t"),
            columns: (0..<2).map { _ in ColumnSpec(width: 100) },
            rows: [Row(id: BlockID("r0"), cells: [emptyCell("a"), labelledCell("B")])])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
        XCTAssertEqual(texts(of: merged.rows[0].cells[0]), ["B"],
                       "an empty anchor contributes no blank; only the neighbor's content survives")
    }

    func test_mergingCells_allEmpty_keepsSingleEmptyParagraph() {
        // Every cell empty → the merged cell must stay valid with exactly one empty paragraph (never blank-less).
        let table = TableBlock(id: BlockID("t"),
            columns: (0..<2).map { _ in ColumnSpec(width: 100) },
            rows: [Row(id: BlockID("r0"), cells: [emptyCell("a"), emptyCell("b")])])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
        let anchorCell = merged.rows[0].cells[0]
        XCTAssertEqual(anchorCell.blocks.count, 1, "an all-empty merge keeps exactly one paragraph")
        XCTAssertEqual(texts(of: anchorCell), [""], "and it is an empty paragraph")
    }

    // MARK: 2a. Merge a row pair (colspan only)

    func test_mergingCells_rowPair_colspanOnly() {
        let table = denseTable([["A", "B", "C"]])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))

        let map = TableMap(merged)
        XCTAssertTrue(map.isWellFormed)
        let anchor = map.anchor(atRow: 0, column: 0)
        XCTAssertEqual(anchor?.colspan, 2)
        XCTAssertEqual(anchor?.rowspan, 1)

        XCTAssertEqual(merged.rows[0].cells.count, 2, "the merged cell + the untouched 'C' cell")
        XCTAssertEqual(texts(of: merged.rows[0].cells[0]), ["A", "B"])
        XCTAssertEqual(texts(of: merged.rows[0].cells[1]), ["C"])
    }

    // MARK: 2b. Merge a column pair (rowspan only)

    func test_mergingCells_columnPair_rowspanOnly() {
        let table = denseTable([["A"], ["B"], ["C"]])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 0))

        let map = TableMap(merged)
        XCTAssertTrue(map.isWellFormed)
        let anchor = map.anchor(atRow: 0, column: 0)
        XCTAssertEqual(anchor?.colspan, 1)
        XCTAssertEqual(anchor?.rowspan, 2)

        XCTAssertEqual(merged.rows[0].cells.count, 1)
        XCTAssertEqual(merged.rows[1].cells.count, 0)
        XCTAssertEqual(merged.rows[2].cells.count, 1, "the untouched 'C' row")
        XCTAssertEqual(texts(of: merged.rows[0].cells[0]), ["A", "B"])
        XCTAssertEqual(texts(of: merged.rows[2].cells[0]), ["C"])
    }

    // MARK: 3. Merge no-op on a single cell

    func test_mergingCells_singleCell_isNoOp() {
        let table = denseTable([["A", "B"], ["C", "D"]])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 0))
        XCTAssertEqual(merged, table)
    }

    // MARK: 4. Split the merged 2x2 back

    func test_splittingCell_undoesA2x2Merge() {
        let table = denseTable([["A", "B"], ["C", "D"]])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 1))
        let split = merged.splittingCell(at: (row: 0, column: 0))

        let map = TableMap(split)
        XCTAssertTrue(map.isWellFormed)

        let anchor = map.anchor(atRow: 0, column: 0)
        XCTAssertEqual(anchor?.colspan, 1)
        XCTAssertEqual(anchor?.rowspan, 1)

        XCTAssertEqual(split.rows[0].cells.count, 2)
        XCTAssertEqual(split.rows[1].cells.count, 2)

        // The anchor still holds the pooled A,B,C,D content.
        XCTAssertEqual(texts(of: split.rows[0].cells[0]), ["A", "B", "C", "D"])

        // The three re-materialized cells are fresh and empty.
        let freshCells = [split.rows[0].cells[1], split.rows[1].cells[0], split.rows[1].cells[1]]
        for cell in freshCells {
            XCTAssertEqual(cell.blocks.count, 1)
            guard case .paragraph(let p) = cell.blocks[0] else { return XCTFail("expected paragraph") }
            XCTAssertEqual(p.utf16Count, 0)
        }

        // Grid dimensions are unchanged.
        XCTAssertEqual(split.columns.count, table.columns.count)
        XCTAssertEqual(split.rows.count, table.rows.count)
    }

    func test_splittingCell_notMerged_isNoOp() {
        let table = denseTable([["A", "B"], ["C", "D"]])
        let split = table.splittingCell(at: (row: 0, column: 0))
        XCTAssertEqual(split, table)
    }

    // MARK: 5. Merge-then-split round-trips grid shape

    func test_mergeThenSplit_roundTripsGridShape() {
        // 2 rows x 3 columns; merge a 2x2 sub-region (A,B,D,E), leaving C and F untouched, to make sure
        // the split re-materialization doesn't disturb cells OUTSIDE the merged footprint.
        let table = denseTable([["A", "B", "C"], ["D", "E", "F"]])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 1))
        let split = merged.splittingCell(at: (row: 0, column: 0))

        XCTAssertEqual(split.rows.map { $0.cells.count }, table.rows.map { $0.cells.count },
                        "cell counts per row match the original dense grid")
        XCTAssertTrue(TableMap(split).isWellFormed)

        // Content: the anchor pools A,B,D,E; C and F are untouched and keep their own content/position.
        XCTAssertEqual(texts(of: split.rows[0].cells[0]), ["A", "B", "D", "E"])
        XCTAssertEqual(texts(of: split.rows[0].cells[2]), ["C"])
        XCTAssertEqual(texts(of: split.rows[1].cells[2]), ["F"])

        let map = TableMap(split)
        XCTAssertEqual(map.anchor(atRow: 0, column: 2)?.cellID, BlockID("C"))
        XCTAssertEqual(map.anchor(atRow: 1, column: 2)?.cellID, BlockID("F"))
    }

    // MARK: 6. Merge over a rect that bisects an existing merged cell expands first

    func test_mergingCells_rectBisectingAnExistingMergedCell_expandsToCoverIt() {
        // Grid:
        // A A B
        // C D D
        // "A" spans cols 0-1 on row 0; "D" spans cols 1-2 on row 1. Request a rect that only nominally
        // covers (0,1)-(1,1) — straddling BOTH merged cells on an edge — and confirm the merge covers
        // their full footprint, not just the requested rect.
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [
                    Cell(id: BlockID("A"), blocks: [.paragraph(ParagraphBlock(id: BlockID("A_p"), runs: [TextRun(text: "A")]))], colspan: 2),
                    Cell(id: BlockID("B"), blocks: [.paragraph(ParagraphBlock(id: BlockID("B_p"), runs: [TextRun(text: "B")]))]),
                ]),
                Row(id: BlockID("r1"), cells: [
                    Cell(id: BlockID("C"), blocks: [.paragraph(ParagraphBlock(id: BlockID("C_p"), runs: [TextRun(text: "C")]))]),
                    Cell(id: BlockID("D"), blocks: [.paragraph(ParagraphBlock(id: BlockID("D_p"), runs: [TextRun(text: "D")]))], colspan: 2),
                ]),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let merged = table.mergingCells(in: TableRect(top: 0, left: 1, bottom: 1, right: 1))
        let map = TableMap(merged)
        XCTAssertTrue(map.isWellFormed)

        // The merge must have expanded to cover "A"'s full span (cols 0-1) and "D"'s full span
        // (cols 1-2), i.e. the whole grid — a single anchor covering everything.
        let anchor = map.anchor(atRow: 0, column: 0)
        XCTAssertEqual(anchor?.colspan, 3)
        XCTAssertEqual(anchor?.rowspan, 2)
        XCTAssertEqual(map.anchor(atRow: 1, column: 2)?.cellID, anchor?.cellID)

        XCTAssertEqual(texts(of: merged.rows[0].cells[0]), ["A", "B", "C", "D"])
    }

    // MARK: 7. Split with a rowspan cell adjacent to the footprint

    func test_splittingCell_withAdjacentRowspan_preservesTheRowspanAndReMaterializesCorrectly() {
        // Grid (3x3):
        //   M P Q       M = colspan1/rowspan3 in column 0
        //   M Z Z       Z = colspan2/rowspan2 anchored at (1,1), spanning cols 1-2 rows 1-2
        //   M Z Z
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [labelledCell("M", rowspan: 3), labelledCell("P"), labelledCell("Q")]),
                Row(id: BlockID("r1"), cells: [labelledCell("Z", colspan: 2, rowspan: 2)]),
                Row(id: BlockID("r2"), cells: []),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        let split = table.splittingCell(at: (row: 1, column: 1))
        let map = TableMap(split)
        XCTAssertTrue(map.isWellFormed)

        // M's rowspan-3 in column 0 is untouched.
        let m = map.anchor(atRow: 0, column: 0)
        XCTAssertEqual(m?.cellID, BlockID("M"))
        XCTAssertEqual(m?.colspan, 1)
        XCTAssertEqual(m?.rowspan, 3)

        // Z is now a single cell at its origin, still holding its content.
        let z = map.anchor(atRow: 1, column: 1)
        XCTAssertEqual(z?.cellID, BlockID("Z"))
        XCTAssertEqual(z?.colspan, 1)
        XCTAssertEqual(z?.rowspan, 1)
        XCTAssertEqual(texts(of: split.rows[1].cells.first { $0.id == BlockID("Z") }!), ["Z"])

        // Three fresh empty cells re-materialize at covering columns (1,2), (2,1), (2,2).
        for (r, c) in [(1, 2), (2, 1), (2, 2)] {
            let anchor = map.anchor(atRow: r, column: c)
            XCTAssertNotEqual(anchor?.cellID, BlockID("Z"), "slot (\(r),\(c)) is a fresh cell, not Z")
            XCTAssertEqual(anchor?.colspan, 1)
            XCTAssertEqual(anchor?.rowspan, 1)
            let cell = split.rows[r].cells.first { $0.id == anchor?.cellID }!
            XCTAssertEqual(texts(of: cell), [""], "re-materialized cell at (\(r),\(c)) is empty")
        }

        // Grid shape is dense again beside M: row1 = [Z, fresh]; row2 = [fresh, fresh]; row0 unchanged.
        XCTAssertEqual(split.rows[0].cells.count, 3)
        XCTAssertEqual(split.rows[1].cells.count, 2)
        XCTAssertEqual(split.rows[2].cells.count, 2)
    }

    // MARK: 8. Merge whose top-left is covered by a rowspan descending from row 0

    func test_mergingCells_topLeftUnderRowspan_removesFromCorrectOriginRows() {
        // Grid (3x2):
        //   X Y      X = colspan1/rowspan2 in column 0 (rows 0-1)
        //   X Z      Z at (1,1)
        //   W0 W1    untouched body row
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [labelledCell("X", rowspan: 2), labelledCell("Y")]),
                Row(id: BlockID("r1"), cells: [labelledCell("Z")]),
                Row(id: BlockID("r2"), cells: [labelledCell("W0"), labelledCell("W1")]),
            ])
        XCTAssertTrue(TableMap(table).isWellFormed, "fixture sanity check")

        // Request a rect whose top-left slot (1,0) is covered by X's rowspan — expanded() must pull in
        // X's full footprint (rows 0-1) and thereby its row-0 sibling Y.
        let merged = table.mergingCells(in: TableRect(top: 1, left: 0, bottom: 1, right: 1))
        let map = TableMap(merged)
        XCTAssertTrue(map.isWellFormed)

        // X is the anchor (origin of the expanded rect), now colspan2/rowspan2 covering rows 0-1.
        let anchor = map.anchor(atRow: 0, column: 0)
        XCTAssertEqual(anchor?.cellID, BlockID("X"))
        XCTAssertEqual(anchor?.colspan, 2)
        XCTAssertEqual(anchor?.rowspan, 2)
        // Content pooled row-major: X, Y, Z.
        XCTAssertEqual(texts(of: merged.rows[0].cells[0]), ["X", "Y", "Z"])

        // Y removed from origin row 0; Z removed from origin row 1.
        XCTAssertEqual(merged.rows[0].cells.count, 1, "only the X anchor remains in row 0")
        XCTAssertEqual(merged.rows[1].cells.count, 0, "Z removed from row 1")

        // The untouched body row below is intact.
        XCTAssertEqual(merged.rows[2].cells.count, 2)
        XCTAssertEqual(texts(of: merged.rows[2].cells[0]), ["W0"])
        XCTAssertEqual(texts(of: merged.rows[2].cells[1]), ["W1"])
    }

    // MARK: 9. Split a colspan-only and a rowspan-only merged cell

    func test_splittingCell_colspanOnly_reMaterializesOneFreshCell() {
        let table = denseTable([["A", "B", "C"]])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))  // colspan 2
        let split = merged.splittingCell(at: (row: 0, column: 0))

        XCTAssertTrue(TableMap(split).isWellFormed)
        XCTAssertEqual(split.rows[0].cells.count, 3, "anchor + one fresh cell + untouched C")

        let map = TableMap(split)
        XCTAssertEqual(map.anchor(atRow: 0, column: 0)?.colspan, 1)
        XCTAssertEqual(texts(of: split.rows[0].cells[0]), ["A", "B"], "anchor keeps pooled content")
        XCTAssertEqual(texts(of: split.rows[0].cells[1]), [""], "fresh cell at (0,1) is empty")
        XCTAssertEqual(texts(of: split.rows[0].cells[2]), ["C"], "C untouched at (0,2)")
    }

    func test_splittingCell_rowspanOnly_reMaterializesOneFreshCell() {
        let table = denseTable([["A"], ["B"], ["C"]])
        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 0))  // rowspan 2
        let split = merged.splittingCell(at: (row: 0, column: 0))

        XCTAssertTrue(TableMap(split).isWellFormed)
        XCTAssertEqual(split.rows[0].cells.count, 1)
        XCTAssertEqual(split.rows[1].cells.count, 1, "one fresh cell re-materialized in row 1")
        XCTAssertEqual(split.rows[2].cells.count, 1, "C untouched")

        let map = TableMap(split)
        XCTAssertEqual(map.anchor(atRow: 0, column: 0)?.rowspan, 1)
        XCTAssertEqual(texts(of: split.rows[0].cells[0]), ["A", "B"], "anchor keeps pooled content")
        XCTAssertEqual(texts(of: split.rows[1].cells[0]), [""], "fresh cell at (1,0) is empty")
        XCTAssertEqual(texts(of: split.rows[2].cells[0]), ["C"], "C untouched at (2,0)")
    }

    // MARK: 10. Merge preserves the anchor's non-content attributes

    func test_mergingCells_preservesAnchorNonContentAttributes() {
        let bg = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        let anchorCell = labelledCell("A", background: bg, horizontalAlignment: .right,
                                      verticalAlignment: .bottom, isHeader: true)
        let table = TableBlock(
            id: BlockID("t"),
            columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
            rows: [
                Row(id: BlockID("r0"), cells: [anchorCell, labelledCell("B")]),
                Row(id: BlockID("r1"), cells: [labelledCell("C"), labelledCell("D")]),
            ])

        let merged = table.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 1))
        let result = merged.rows[0].cells[0]

        // Non-content attributes carried over from the anchor.
        XCTAssertEqual(result.id, BlockID("A"))
        XCTAssertEqual(result.background, bg)
        XCTAssertEqual(result.horizontalAlignment, .right)
        XCTAssertEqual(result.verticalAlignment, .bottom)
        XCTAssertTrue(result.isHeader)

        // Only blocks / colspan / rowspan changed.
        XCTAssertEqual(result.colspan, 2)
        XCTAssertEqual(result.rowspan, 2)
        XCTAssertEqual(texts(of: result), ["A", "B", "C", "D"])
        XCTAssertTrue(TableMap(merged).isWellFormed)
    }
}

import XCTest
@testable import RichTextEditorCore

final class TableSelectionConversionTests: XCTestCase {
    // A 1x2 table whose two cells each hold a paragraph "X".
    // Map: 0 <table> 1 <row> 2 <cellA> 3 <pA> 4 'X' 5 </pA> 6 </cellA> 7 <cellB> 8 <pB> 9 'X' 10 </pB> 11 </cellB> 12 </row> 13 </table> 14
    // pos 4 is inside cellA (before 'X'); pos 8 is inside cellB → a cross-cell span.
    private func doc() -> Document {
        func cell(_ id: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"),
                                                                     runs: [TextRun(text: "X")]))])
        }
        return Document(
            blocks: [.table(TableBlock(id: BlockID("t1"),
                columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a"), cell("b")])]))])
    }

    func test_detectsRangeAcrossDifferentCellsOfSameTable() {
        let result = TableSelectionConversion.cellSpan(
            from: 4, to: 8, in: doc())   // inside cell A → inside cell B
        XCTAssertEqual(result?.tableID, BlockID("t1"))
        XCTAssertEqual(result?.anchor, CellPath(tableID: BlockID("t1"), row: 0, column: 0))
        XCTAssertEqual(result?.head, CellPath(tableID: BlockID("t1"), row: 0, column: 1))
    }

    func test_returnsNilWhenBothEndsInSameCell() {
        XCTAssertNil(TableSelectionConversion.cellSpan(from: 3, to: 4, in: doc()))
    }

    // A 1x2 table (same token map as doc(), positions 0..13) followed by a paragraph "Z".
    // Token walk: 13 </table> 14 <paragraphZ> 15 'Z' 16 </paragraphZ> 17
    // Position 15 is offset 0 inside paragraph "Z" — outside the table.
    private func docWithTrailingParagraph() -> Document {
        func cell(_ id: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"),
                                                                     runs: [TextRun(text: "X")]))])
        }
        return Document(
            blocks: [.table(TableBlock(id: BlockID("t1"),
                        columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
                        rows: [Row(id: BlockID("r0"), cells: [cell("a"), cell("b")])])),
                     .paragraph(ParagraphBlock(id: BlockID("z"), runs: [TextRun(text: "Z")]))])
    }

    func test_cellToOutsideParagraph_isNotACellSpan() {
        let d = docWithTrailingParagraph()
        let root = DocumentTree.build(from: d)
        // offset 0 inside the "Z" text node resolves to global position 15 (outside the table)
        let zPos = PositionResolver.globalPosition(of: .paragraph(BlockID("z")), offset: 0, in: root)!
        XCTAssertNil(TableSelectionConversion.cellSpan(from: 4, to: zPos, in: d),
                     "a cell->body range is a linear range, not a rectangular cell span")
    }
}

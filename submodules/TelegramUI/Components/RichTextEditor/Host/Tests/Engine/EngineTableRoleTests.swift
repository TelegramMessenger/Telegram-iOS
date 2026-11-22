import XCTest
import RichTextEditorCore
@testable import RichTextEngineEditor

/// The regroup of cell roles into a table (`EngineBlockRole.document(roles:blocks:)`): a role is the
/// cell's structure, its materialised block the cell's paragraph.
@available(iOS 18.4, *)
final class EngineTableRoleTests: XCTestCase {
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID("\(id)p"), runs: [TextRun(text: text)]))])
    }
    private func table(id: String = "t0") -> TableBlock {
        TableBlock(id: BlockID(id),
                   columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                   rows: [Row(id: BlockID("\(id)r0"), cells: [cell("\(id)a", "a"), cell("\(id)b", "b")]),
                          Row(id: BlockID("\(id)r1"), cells: [cell("\(id)c", "c"), cell("\(id)d", "d")])],
                   compact: true, bordered: false)
    }
    /// One role per cell, and the paragraph the engine would hold for it.
    private func roles(for table: TableBlock) -> (roles: [EngineBlockRole], blocks: [Block]) {
        let shape = TableShape(table)
        var roles: [EngineBlockRole] = []
        var blocks: [Block] = []
        for (r, row) in table.rows.enumerated() {
            for (c, cell) in row.cells.enumerated() {
                roles.append(.tableCell(table: shape, row: r, column: c, cell: cell.id, within: []))
                blocks.append(.paragraph(ParagraphBlock(id: cell.id, runs: cell.blocks.first?.asParagraph?.runs ?? [])))
            }
        }
        return (roles, blocks)
    }

    func test_aCellRoleReportsItsCellAndItsTable() {
        let t = table()
        let role = roles(for: t).roles[3]
        XCTAssertEqual(role.blockID, BlockID("t0d"))
        XCTAssertEqual(role.containerID, BlockID("t0"))
        XCTAssertEqual(role.owningTable?.id, BlockID("t0"))
        XCTAssertEqual(role.tableCellCoordinates?.row, 1)
        XCTAssertEqual(role.tableCellCoordinates?.column, 1)
        XCTAssertNil(role.secondaryKind)
        XCTAssertNil(role.innermostAncestor)
    }

    func test_consecutiveCellsRegroupIntoOneTableCarryingEverythingButTheText() {
        let t = table()
        let (rs, bs) = roles(for: t)
        let document = EngineBlockRole.document(roles: rs, blocks: bs)
        guard document.blocks.count == 1, case let .table(back) = document.blocks[0] else {
            return XCTFail("expected one table, got \(document.blocks)")
        }
        XCTAssertEqual(back.id, t.id)
        XCTAssertEqual(back.columns.map(\.width), [100, 100])
        XCTAssertTrue(back.compact); XCTAssertFalse(back.bordered)
        XCTAssertEqual(back.rows.map { $0.cells.map { $0.blocks.first?.asParagraph?.runs.first?.text } },
                       [["a", "b"], ["c", "d"]])
    }

    func test_editedCellTextReplacesOnlyThatCell() {
        let t = table()
        var (rs, bs) = roles(for: t)
        bs[2] = .paragraph(ParagraphBlock(id: BlockID("t0c"), runs: [TextRun(text: "C!\nmore")]))
        guard case let .table(back) = EngineBlockRole.document(roles: rs, blocks: bs).blocks[0] else { return XCTFail() }
        XCTAssertEqual(back.rows[1].cells[0].blocks.first?.asParagraph?.runs.first?.text, "C!\nmore")
        XCTAssertEqual(back.rows[1].cells[1].blocks.first?.asParagraph?.runs.first?.text, "d")
        XCTAssertEqual(rs[2].tableCellCoordinates?.row, 1)
        rs[2] = rs[2].replacingShape(.paragraph(ParagraphShape(id: BlockID("other"), style: .heading1)))
        XCTAssertEqual(rs[2].blockID, BlockID("t0c"), "a cell is a plain paragraph by definition and keeps its shape")
    }

    func test_twoAdjacentTablesStayTwo() {
        let a = roles(for: table(id: "tA")), b = roles(for: table(id: "tB"))
        let document = EngineBlockRole.document(roles: a.roles + b.roles, blocks: a.blocks + b.blocks)
        XCTAssertEqual(document.blocks.count, 2)
        XCTAssertEqual(document.blocks.map(\.id), [BlockID("tA"), BlockID("tB")])
    }

    func test_aMissingCellBlockLeavesAnEmptyCellInPlace() {
        let t = table()
        var (rs, bs) = roles(for: t)
        rs.remove(at: 1); bs.remove(at: 1)   // cell b's engine block is gone
        guard case let .table(back) = EngineBlockRole.document(roles: rs, blocks: bs).blocks[0] else { return XCTFail() }
        XCTAssertEqual(back.rows[0].cells.count, 2, "the grid stays rectangular")
        XCTAssertEqual(back.rows[0].cells[1].blocks, [], "the missing cell reads back EMPTY, at its own coordinates")
        XCTAssertEqual(back.rows[1].cells[0].blocks.first?.asParagraph?.runs.first?.text, "c", "nothing shifted")
    }

    func test_aStrayParagraphBetweenCellsSplitsTheTableAroundIt() {
        let t = table()
        var (rs, bs) = roles(for: t)
        rs.insert(.standalone(.paragraph(ParagraphShape(id: BlockID("stray"))), within: []), at: 2)
        bs.insert(.paragraph(ParagraphBlock(id: BlockID("stray"), runs: [TextRun(text: "x")])), at: 2)
        let document = EngineBlockRole.document(roles: rs, blocks: bs)
        XCTAssertEqual(document.blocks.count, 3)
        XCTAssertEqual(document.blocks[1].id, BlockID("stray"))
    }

    func test_aTableShapeHoldsNoCellBlocks() {
        let shape = TableShape(table())
        XCTAssertEqual(shape.rows.map { $0.cells.map(\.id.rawValue) }, [["t0a", "t0b"], ["t0c", "t0d"]])
        XCTAssertTrue(shape.emptyTable.rows.allSatisfy { $0.cells.allSatisfy { $0.blocks.isEmpty } })
        XCTAssertEqual(TableShape(TableBlock(id: BlockID("empty"))).rows.count, 1, "a table with no rows is rescued to one cell")
    }
}

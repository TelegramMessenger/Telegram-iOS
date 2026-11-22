import Foundation

public enum TableSelectionConversion {
    public struct CellSpan: Equatable {
        public let tableID: BlockID
        public let anchor: CellPath
        public let head: CellPath
    }

    /// If `from` and `to` resolve into two *different* cells of the *same* table, returns the
    /// corresponding cell paths; otherwise nil. Used to offer a rectangular cell selection for
    /// structural operations.
    public static func cellSpan(from: Int, to: Int, in document: Document) -> CellSpan? {
        let root = DocumentTree.build(from: document)
        guard let a = cellPath(at: from, in: root, document: document),
              let b = cellPath(at: to, in: root, document: document),
              a.tableID == b.tableID,
              !(a.row == b.row && a.column == b.column)
        else { return nil }
        return CellSpan(tableID: a.tableID, anchor: a, head: b)
    }

    /// Resolves a position to the cell that contains it, if any.
    static func cellPath(at pos: Int, in root: DocNode, document: Document) -> CellPath? {
        let resolved = PositionResolver.resolve(pos, in: root)
        // Find the nearest enclosing .cell ancestor and the .table above it.
        var cellID: BlockID?
        var tableID: BlockID?
        for ancestor in resolved.path {
            if case .cell(let id, _) = ancestor.node { cellID = id }
            if case .table(let id, _) = ancestor.node { tableID = id }
        }
        guard let cellID, let tableID else { return nil }
        // Locate row/column of cellID within the table.
        for case .table(let t) in document.blocks where t.id == tableID {
            for (r, row) in t.rows.enumerated() {
                for (c, cell) in row.cells.enumerated() where cell.id == cellID {
                    return CellPath(tableID: tableID, row: r, column: c)
                }
            }
        }
        return nil
    }
}

import Foundation

/// A cell address within a table: row/column indices plus the owning table's id.
public struct CellPath: Equatable {
    public let tableID: BlockID
    public let row: Int
    public let column: Int
    public init(tableID: BlockID, row: Int, column: Int) {
        self.tableID = tableID
        self.row = row
        self.column = column
    }
}

public enum RTSelection: Equatable {
    /// A linear range. `anchor` is fixed, `head` is the moving end.
    case range(anchor: Int, head: Int)
    /// A rectangular whole-cell selection for structural table operations.
    case cells(anchor: CellPath, head: CellPath)
    /// A block-level cursor before/after an atom or table.
    case gap(Int)

    public var from: Int {
        switch self {
        case .range(let a, let h): return min(a, h)
        case .gap(let p): return p
        case .cells: return 0   // cell selections are not linear; callers use the CellPaths
        }
    }

    public var to: Int {
        switch self {
        case .range(let a, let h): return max(a, h)
        case .gap(let p): return p
        case .cells: return 0
        }
    }

    public var isCollapsed: Bool {
        switch self {
        case .range(let a, let h): return a == h
        case .gap: return true
        case .cells: return false
        }
    }
}

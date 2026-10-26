import Foundation

public struct ColumnSpec: Codable, Equatable {
    public var width: Double
    public init(width: Double) { self.width = width }
}

/// A table cell. In v1 cells contain paragraph and media blocks (no nested tables). `horizontalAlignment`
/// / `verticalAlignment` are per-cell render overrides applied to the cell's paragraphs (not stored on them).
public struct Cell: Codable, Equatable {
    public var id: BlockID
    public var blocks: [Block]
    public var background: RGBAColor?
    public var horizontalAlignment: TextAlignment
    public var verticalAlignment: VerticalAlignment
    /// Per-cell header/highlight flag (fill + bold). Replaces the old whole-row header concept.
    public var isHeader: Bool
    /// Number of grid columns this cell spans (default 1).
    public var colspan: Int
    /// Number of grid rows this cell spans (default 1).
    public var rowspan: Int

    public init(id: BlockID, blocks: [Block] = [], background: RGBAColor? = nil,
                horizontalAlignment: TextAlignment = .center, verticalAlignment: VerticalAlignment = .top,
                isHeader: Bool = false, colspan: Int = 1, rowspan: Int = 1) {
        self.id = id
        self.blocks = blocks
        self.background = background
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.isHeader = isHeader
        self.colspan = colspan
        self.rowspan = rowspan
    }

    private enum CodingKeys: String, CodingKey { case id, blocks, background, horizontalAlignment, verticalAlignment, isHeader, colspan, rowspan }

    // Custom decode so cells written before these fields existed still load (defaults applied).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(BlockID.self, forKey: .id)
        blocks = try c.decodeIfPresent([Block].self, forKey: .blocks) ?? []
        background = try c.decodeIfPresent(RGBAColor.self, forKey: .background)
        horizontalAlignment = try c.decodeIfPresent(TextAlignment.self, forKey: .horizontalAlignment) ?? .center
        verticalAlignment = try c.decodeIfPresent(VerticalAlignment.self, forKey: .verticalAlignment) ?? .top
        isHeader = try c.decodeIfPresent(Bool.self, forKey: .isHeader) ?? false
        colspan = try c.decodeIfPresent(Int.self, forKey: .colspan) ?? 1
        rowspan = try c.decodeIfPresent(Int.self, forKey: .rowspan) ?? 1
    }
}

public struct Row: Equatable {
    public var id: BlockID
    public var height: Double?
    public var cells: [Cell]

    /// Whether EVERY cell is a header cell (and the row is non-empty). Derived — there is no stored
    /// row-level header; per-cell `Cell.isHeader` is the single source of truth.
    public var isHeader: Bool { !cells.isEmpty && cells.allSatisfy { $0.isHeader } }

    /// `isHeader: true` seeds every cell as a header cell (convenience for callers/tests that think in
    /// whole rows). `false` leaves each cell's own flag untouched.
    public init(id: BlockID, height: Double? = nil, isHeader: Bool = false, cells: [Cell] = []) {
        self.id = id
        self.height = height
        self.cells = isHeader ? cells.map { var c = $0; c.isHeader = true; return c } : cells
    }
}

extension Row: Codable {
    private enum CodingKeys: String, CodingKey { case id, height, cells; case legacyIsHeader = "isHeader" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(BlockID.self, forKey: .id)
        height = try c.decodeIfPresent(Double.self, forKey: .height)
        var decodedCells = try c.decodeIfPresent([Cell].self, forKey: .cells) ?? []
        // Migration: a row written before per-cell header carried a row-level `isHeader`. Fold it in.
        // Edge case: a legacy row with `isHeader: true` but ZERO cells folds into nothing, so it
        // decodes to a non-header row (the computed getter's `!cells.isEmpty` guard). Acceptable —
        // the grid invariant guarantees every row has ≥1 column, so this shape never occurs in practice.
        if (try c.decodeIfPresent(Bool.self, forKey: .legacyIsHeader)) == true {
            decodedCells = decodedCells.map { var cell = $0; cell.isHeader = true; return cell }
        }
        cells = decodedCells
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(height, forKey: .height)
        try c.encode(cells, forKey: .cells)
        // Deliberately does NOT encode `isHeader` — it is derived from the cells.
    }
}

public struct TableBlock: Codable, Equatable {
    public var id: BlockID
    public var columns: [ColumnSpec]
    public var rows: [Row]
    /// `pageBlockTable`'s `compact` flag: cells are laid out with half the usual padding.
    public var compact: Bool
    /// `pageBlockTable`'s `bordered` flag. NOT merely a paint toggle: V2 sets the whole border WIDTH to
    /// zero when false (`bordered ? v2TableBorderWidth : 0.0`), so the 1pt gaps between cells collapse
    /// and the grid is narrower. The editor mirrors the rule, or its table would be wider than the
    /// message's by one border per boundary.
    ///
    /// Defaults to TRUE — every table authored before this flag existed drew its grid, and
    /// `InstantPageBuilder` hard-coded `bordered: true` on the way out.
    public var bordered: Bool

    public init(id: BlockID, columns: [ColumnSpec] = [], rows: [Row] = [], compact: Bool = false,
                bordered: Bool = true) {
        self.id = id
        self.columns = columns
        self.rows = rows
        self.compact = compact
        self.bordered = bordered
    }

    private enum CodingKeys: String, CodingKey { case id, columns, rows, compact, bordered }

    // Hand-written so a draft persisted before `compact` / `bordered` existed still decodes.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(BlockID.self, forKey: .id)
        self.columns = try c.decodeIfPresent([ColumnSpec].self, forKey: .columns) ?? []
        self.rows = try c.decodeIfPresent([Row].self, forKey: .rows) ?? []
        self.compact = try c.decodeIfPresent(Bool.self, forKey: .compact) ?? false
        // Absent => true: an older draft's table was always bordered.
        self.bordered = try c.decodeIfPresent(Bool.self, forKey: .bordered) ?? true
    }

    public var columnCount: Int { columns.count }
    public var rowCount: Int { rows.count }
}

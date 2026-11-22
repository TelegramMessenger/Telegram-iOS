#if canImport(UIKit)
import Foundation
import RichTextEditorCore

/// The STRUCTURE of one engine block's own model block: everything but its runs.
///
/// A role holds one of these and never a `Block`, so a role cannot carry text. The engine's storage
/// is the only copy of the text, read at the moment of use (`EngineDocumentBridge.block(for:from:)`).
/// Only these six kinds — `paragraph`, `code`, `pullQuote`, `media`, `buttonRow` and
/// `collapsedQuote` — ever reach the engine's axis, at any depth inside containers; the bridge traps
/// on the rest.
///
/// `collapsedQuote` is the odd one and deliberately so: it is the only shape that is a CONTAINER in
/// the model. A block quote is an `EngineAncestor` while it is open and one of these while it is
/// folded, because a folded quote has no children on the axis for an ancestry to enclose
/// (R7-collapse §3.1).
public enum EngineBlockShape: Equatable {
    case paragraph(ParagraphShape)
    case code(id: BlockID, language: String?)
    case pullQuote(id: BlockID)
    /// A media block's ATOM: one attachment character. Its caption is a `.secondary` line.
    case media(MediaShape)
    /// A button row's ATOM: one attachment character, whatever the pill count. Unlike `.media` it
    /// has NO companion line — a row owns no text at all, so its labels ride in the shape.
    case buttonRow(ButtonRowShape)
    /// A FOLDED block quote's atom: one attachment character, whatever it holds. Like `.buttonRow`
    /// it owns no editable text, so the shape carries the whole model.
    case collapsedQuote(QuoteShape)

    public var id: BlockID {
        switch self {
        case let .paragraph(paragraph): return paragraph.id
        case let .code(id, _): return id
        case let .pullQuote(id): return id
        case let .media(media): return media.id
        case let .buttonRow(row): return row.id
        case let .collapsedQuote(quote): return quote.id
        }
    }

    /// The shape of a block that can be an engine block; nil for the kinds that cannot.
    public init?(of block: Block) {
        switch block {
        case let .paragraph(paragraph): self = .paragraph(ParagraphShape(paragraph))
        case let .code(code): self = .code(id: code.id, language: code.language)
        case let .pullQuote(quote): self = .pullQuote(id: quote.id)
        case let .media(media): self = .media(MediaShape(media))
        case let .buttonRow(row): self = .buttonRow(ButtonRowShape(row))
        // BEFORE the catch-all below: a `where` clause does not reorder itself, and a collapsed
        // quote reaching that line would read as "not an engine block" and vanish.
        case let .blockQuote(quote) where quote.collapsed: self = .collapsedQuote(QuoteShape(quote))
        case .table, .blockQuote, .details: return nil
        }
    }

    /// This shape holding `runs`. A media shape IGNORES them: the atom's engine text is not model
    /// text, and its caption arrives through `EngineBlockRole.document(roles:blocks:)`'s merge.
    public func block(runs: [TextRun]) -> Block {
        switch self {
        case let .paragraph(paragraph): return .paragraph(paragraph.block(runs: runs))
        case let .code(id, language): return .code(CodeBlock(id: id, language: language, runs: runs))
        case let .pullQuote(id): return .pullQuote(PullQuote(id: id, runs: runs))
        case let .media(media): return .media(media.block(caption: []))
        case let .buttonRow(row): return .buttonRow(row.block)
        // The atom's text carries nothing of the model, so the SHAPE is the block — `.buttonRow`'s
        // rule, for the same reason.
        case let .collapsedQuote(quote):
            return .blockQuote(BlockQuote(id: quote.id, children: quote.foldedChildren,
                                          collapsed: true, author: quote.author))
        }
    }

    public var paragraph: ParagraphShape? {
        if case let .paragraph(paragraph) = self { return paragraph }
        return nil
    }

    public var media: MediaShape? {
        if case let .media(media) = self { return media }
        return nil
    }

    public var buttonRowShape: ButtonRowShape? {
        if case let .buttonRow(row) = self { return row }
        return nil
    }

    public var collapsedQuote: QuoteShape? {
        if case let .collapsedQuote(quote) = self { return quote }
        return nil
    }
}

/// A button row without any text, which is the whole of it: a row's labels are chrome, not document
/// text, so this carries the ENTIRE model. It is the one shape for which `block(runs:)` has nothing
/// to merge — even `.media` has a caption line to take its runs from.
public struct ButtonRowShape: Equatable {
    public var id: BlockID
    public var buttons: [ButtonRef]
    public var alignment: ButtonRowAlignment

    public init(_ block: ButtonRowBlock) {
        id = block.id
        buttons = block.buttons
        alignment = block.alignment
    }

    public var block: ButtonRowBlock {
        ButtonRowBlock(id: id, buttons: buttons, alignment: alignment)
    }
}

/// A paragraph without its runs: the fields `attributedString(for:)` consumes to build a rendering
/// and cannot read back.
public struct ParagraphShape: Equatable {
    public var id: BlockID
    public var style: ParagraphStyleName
    public var paragraph: ParagraphAttributes
    public var list: ListMembership?

    public init(id: BlockID, style: ParagraphStyleName = .body,
                paragraph: ParagraphAttributes = .default, list: ListMembership? = nil) {
        self.id = id
        self.style = style
        self.paragraph = paragraph
        self.list = list
    }

    public init(_ block: ParagraphBlock) {
        self.init(id: block.id, style: block.style, paragraph: block.paragraph, list: block.list)
    }

    public func block(runs: [TextRun]) -> ParagraphBlock {
        ParagraphBlock(id: id, style: style, paragraph: paragraph, list: list, runs: runs)
    }
}

/// A media block without its caption: what the atom carries and the caption line cannot recover.
public struct MediaShape: Equatable {
    public var id: BlockID
    public var items: [MediaItem]
    public var displayWidth: Double?
    public var alignment: MediaAlignment
    public var displayMode: MediaDisplayMode

    public init(_ block: MediaBlock) {
        id = block.id
        items = block.items
        displayWidth = block.displayWidth
        alignment = block.alignment
        displayMode = block.displayMode
    }

    /// Audio and document have no caption line at all (`MediaKind.isCaptionless`).
    public var isCaptionless: Bool { items.first?.kind.isCaptionless ?? false }

    /// `MediaBlockBox.spacingKind`'s rule: an album is raw whatever its kinds; a single audio or
    /// document row is not.
    public var isRawMedia: Bool {
        if items.count > 1 { return true }
        switch items.first?.kind {
        case .image, .video, .location, nil: return true
        case .audio, .document: return false
        }
    }

    public func block(caption: [TextRun]) -> MediaBlock {
        MediaBlock(id: id, items: items, displayWidth: displayWidth, alignment: alignment,
                   displayMode: displayMode, caption: caption)
    }

    /// The caption line's identity, derived from the media's so it is stable across document sets —
    /// `#language` and `#author` follow the same rule.
    public static func captionLineID(for id: BlockID) -> BlockID { BlockID("\(id.rawValue)#caption") }
    public var captionLineID: BlockID { Self.captionLineID(for: id) }
}

/// A block quote without its children and author: what is not recoverable from the run of engine
/// blocks that make it up.
///
/// **Except when it is COLLAPSED**, where there is no such run: a folded quote is one atom on the
/// axis (R7-collapse §3.1), so `foldedChildren` and `author` are the only copy of its content while
/// it is folded. Both are empty when expanded, and that is the invariant — `DetailsShape`'s own doc
/// comment carries the reasoning for why model content on a shape is not a violation of "structure
/// only" but a consequence of "no TWO sources of truth hold the same text", and it is not restated
/// here.
public struct QuoteShape: Equatable {
    public var id: BlockID
    public var collapsed: Bool
    /// The body in MODEL form while COLLAPSED; empty when expanded.
    public var foldedChildren: [Block]
    /// Carried for the round trip only — a folded quote draws no author line (R7-collapse §2). Empty
    /// when expanded, where the `#author` secondary line is the source of truth.
    public var author: [TextRun]

    public init(id: BlockID, collapsed: Bool = false,
                foldedChildren: [Block] = [], author: [TextRun] = []) {
        self.id = id
        self.collapsed = collapsed
        self.foldedChildren = foldedChildren
        self.author = author
    }

    public init(_ quote: BlockQuote) {
        self.init(id: quote.id, collapsed: quote.collapsed,
                  foldedChildren: quote.collapsed ? quote.children : [],
                  author: quote.collapsed ? quote.author : [])
    }
}

/// A cell without its blocks.
public struct CellShape: Equatable {
    public var id: BlockID
    public var background: RGBAColor?
    public var horizontalAlignment: TextAlignment
    public var verticalAlignment: VerticalAlignment
    public var isHeader: Bool
    public var colspan: Int
    public var rowspan: Int

    public init(_ cell: Cell) {
        id = cell.id
        background = cell.background
        horizontalAlignment = cell.horizontalAlignment
        verticalAlignment = cell.verticalAlignment
        isHeader = cell.isHeader
        colspan = cell.colspan
        rowspan = cell.rowspan
    }

    public func cell(blocks: [Block]) -> Cell {
        Cell(id: id, blocks: blocks, background: background,
             horizontalAlignment: horizontalAlignment, verticalAlignment: verticalAlignment,
             isHeader: isHeader, colspan: colspan, rowspan: rowspan)
    }
}

public struct RowShape: Equatable {
    public var id: BlockID
    public var height: Double?
    public var cells: [CellShape]

    public init(_ row: Row) {
        id = row.id
        height = row.height
        cells = row.cells.map(CellShape.init)
    }
}

/// A table without any cell's blocks. A cell whose engine block vanished reads back EMPTY at its
/// own coordinates rather than resurrecting text or shifting its neighbours.
public struct TableShape: Equatable {
    public var id: BlockID
    public var columns: [ColumnSpec]
    public var rows: [RowShape]
    public var compact: Bool
    public var bordered: Bool

    /// A table with no rows is rescued to one empty cell rather than dropped: it keeps a caret
    /// target and loses nothing a recipient could have seen.
    public init(_ table: TableBlock) {
        id = table.id
        compact = table.compact
        bordered = table.bordered
        if table.rows.isEmpty {
            columns = [ColumnSpec(width: 100)]
            rows = [RowShape(Row(id: BlockID(UUID().uuidString), cells: [Cell(id: BlockID(UUID().uuidString))]))]
        } else {
            columns = table.columns
            rows = table.rows.map(RowShape.init)
        }
    }

    /// The table with these cells' paragraphs in place and every other cell empty.
    public func table(cells: [(row: Int, column: Int, paragraph: ParagraphBlock)]) -> TableBlock {
        var built = emptyTable
        for cell in cells
        where built.rows.indices.contains(cell.row) && built.rows[cell.row].cells.indices.contains(cell.column) {
            built.rows[cell.row].cells[cell.column].blocks = [.paragraph(cell.paragraph)]
        }
        return built
    }

    /// The table with every cell empty — what a geometry solver needs and nothing more.
    public var emptyTable: TableBlock {
        TableBlock(id: id, columns: columns,
                   rows: rows.map { row in Row(id: row.id, height: row.height, cells: row.cells.map { $0.cell(blocks: []) }) },
                   compact: compact, bordered: bordered)
    }

    public func cell(row: Int, column: Int) -> CellShape? {
        guard rows.indices.contains(row), rows[row].cells.indices.contains(column) else { return nil }
        return rows[row].cells[column]
    }
}

/// The container an engine block belongs to, as structure: itself for a standalone block, the quote
/// for a child or a quote's author line, the table for a cell, the owner for a language or author
/// line.
public enum EngineContainerShape: Equatable {
    case block(EngineBlockShape)
    case blockQuote(QuoteShape)
    case details(DetailsShape)
    case table(TableShape)

    public var id: BlockID {
        switch self {
        case let .block(shape): return shape.id
        case let .blockQuote(quote): return quote.id
        case let .details(details): return details.id
        case let .table(table): return table.id
        }
    }
}
#endif

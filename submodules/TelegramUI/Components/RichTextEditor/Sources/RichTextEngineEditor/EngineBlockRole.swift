#if canImport(UIKit)
import Foundation
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// Which second line of its container an engine block is.
public enum SecondaryRegionKind {
    /// A code block's `language`, authored in an always-visible line ABOVE the code.
    case codeLanguage
    /// A pull quote's `author`, authored in a line BELOW the quote. Unlike a language line this one
    /// is conditional: an empty quote has no author region at all, mirroring
    /// `PullQuoteBox.shouldShowAuthor`, so a fresh quote gains no stray blank row.
    case pullQuoteAuthor
    /// A block quote's `author`, in a line BELOW its children. Rendered bold `.caption` and
    /// LEADING-aligned, where a pull quote's is bold + italic and centred — `BlockQuoteBox` and
    /// `PullQuoteBox` differ here, so the two kinds do too.
    case blockQuoteAuthor
    /// A media block's `caption`, in a line BELOW its atom. Rendered `.caption` and centred, and —
    /// unlike an author line — it keeps its RUNS on the way back: a caption may be bold, linked,
    /// or hold a custom emoji.
    case mediaCaption
    /// A detail block's `title`, in an always-visible line ABOVE its children — the same shape as a
    /// code block's language line, and unconditional like it: a details ALWAYS has exactly one title
    /// line and it is the FIRST role of the details' span. Keeps its RUNS on the way back, like a
    /// caption and unlike an author line: a title is authored text, not a re-derived attribution.
    case detailsTitle
}

/// A container that holds BLOCKS and so can enclose an engine block (nesting design §3.1). Two cases
/// as of R7-details. The regroup below opens and closes any ancestor kind, so adding a THIRD is a new
/// case here and nothing else IN THIS FILE — and emphatically not "nothing else" everywhere: the
/// package `CLAUDE.md`'s "R7 details" section enumerates the ~10 sites a third case touches, because
/// this comment claimed otherwise for two rungs running and was wrong both times.
public enum EngineAncestor: Equatable {
    case blockQuote(QuoteShape)
    case details(DetailsShape)

    public var id: BlockID {
        switch self {
        case let .blockQuote(quote): return quote.id
        case let .details(details): return details.id
        }
    }

    public var quote: QuoteShape? {
        if case let .blockQuote(quote) = self { return quote }
        return nil
    }

    public var details: DetailsShape? {
        if case let .details(details) = self { return details }
        return nil
    }

    /// How much this container indents the CONTENT inside it.
    ///
    /// A quote indents one `quoteIndent`. A details indents **nothing**: legacy indents only its
    /// TITLE's glyphs (`DetailsShape.titleGlyphIndent`, a display-only paragraph indent that leaves
    /// the title's frame full width) and its body sits flush with surrounding content. So
    /// `quoteIndent × ancestry.count` does not merely use a wrong width for a details — it adds an
    /// indent that must not be there at all, which is why geometry reads THIS and never the depth
    /// (R7-details spec §3.4).
    public func contentIndent(styleSheet: StyleSheet) -> CGFloat {
        switch self {
        case .blockQuote: return styleSheet.quoteIndent
        case .details: return 0.0
        }
    }

    /// How much this container keeps the CONTENT inside it short of the trailing edge — the mirror
    /// of `contentIndent`, and a separate number because the two are not equal: legacy's quote is
    /// `leadingInset` in and `trailingInset` short (16 and 22 by default).
    ///
    /// A details contributes nothing here either, for the same reason it contributes no indent: its
    /// body sits flush with the surrounding content on both sides.
    public func contentTrailingInset(styleSheet: StyleSheet) -> CGFloat {
        switch self {
        case .blockQuote: return styleSheet.quoteTrailingInset
        case .details: return 0.0
        }
    }

    /// How many block-quote levels indent their content. A quote nested deeper than this still
    /// nests — the model, the role's ancestry and what is sent are untouched — but adds no indent,
    /// so its text column keeps the width it had at this depth.
    ///
    /// Each level used to take its `quoteIndent` from the column with nothing to stop it: at 402pt a
    /// line 16 quotes deep was 27pt wide and from 18 deep it had NO width — every caret offset at one
    /// point, typed text in the model and drawn nowhere, a selection with no geometry (composer
    /// harness p20, `HarnessDeepQuoteColumnTests`; reached by repeated Quote, a fragment paste or an
    /// edited message). This is the FIXED ceiling; the editor lowers it further for its width
    /// (`StyleSheet.indentedQuoteLevelLimit`, `minimumQuotedColumnWidth` below), because the p20 sizing
    /// ("eight levels leave 155pt at 402pt") used the screen width, not the composer's text column, and
    /// left 6-7 levels with almost no column (p21). The V2 renderer has no cap of its own to keep parity
    /// with; the legacy canvas floors its quote column at 1pt.
    public static let maxIndentedQuoteLevels = 8

    /// The narrowest text column (points) the indenting levels may leave at the editor's width: the
    /// editor lowers `StyleSheet.indentedQuoteLevelLimit` below `maxIndentedQuoteLevels` until each
    /// level's leading + trailing inset leaves at least this much.
    ///
    /// The fixed cap alone was sized for the SCREEN width: the composer's text column is 267pt at a
    /// 402pt screen (the attach and send buttons take the rest), and at 38pt a level eight levels need
    /// 304pt. Six levels left 39pt, seven 1pt (one character per line), and eight or more a NEGATIVE
    /// width that TextKit ignores, so the column jumped back to ~117pt — narrowest just below the cap
    /// and not monotonic (composer harness p21, `HarnessDeepQuoteNarrowColumnTests`).
    public static let minimumQuotedColumnWidth: CGFloat = 72.0

    /// How many levels indent in a text column `column` wide, at `perLevel` points a level.
    public static func indentedQuoteLevelLimit(column: CGFloat, perLevel: CGFloat) -> Int {
        guard perLevel > 0.0 else { return maxIndentedQuoteLevels }
        let fitting = Int(((column - minimumQuotedColumnWidth) / perLevel).rounded(.down))
        return Swift.min(maxIndentedQuoteLevels, Swift.max(0, fitting))
    }
}

public extension Sequence where Element == EngineAncestor {
    /// The leading indent of content inside these containers, outermost first: the sum of what each
    /// contributes, with quotes past `EngineAncestor.maxIndentedQuoteLevels` contributing nothing.
    /// EVERY consumer sums through this (the bridge's paragraph styles, decorations, chrome, tables,
    /// media, markers), so text and what is drawn around it agree at any depth.
    func contentIndent(styleSheet: StyleSheet) -> CGFloat {
        indentSum(styleSheet) { $0.contentIndent(styleSheet: styleSheet) }
    }

    /// The trailing inset, summed and capped exactly as `contentIndent(styleSheet:)`.
    func contentTrailingInset(styleSheet: StyleSheet) -> CGFloat {
        indentSum(styleSheet) { $0.contentTrailingInset(styleSheet: styleSheet) }
    }

    /// Capped at the fixed `maxIndentedQuoteLevels` AND at the sheet's width-derived
    /// `indentedQuoteLevelLimit`, so the column the indenting levels leave is never below
    /// `EngineAncestor.minimumQuotedColumnWidth` (p21).
    private func indentSum(_ styleSheet: StyleSheet, _ contribution: (EngineAncestor) -> CGFloat) -> CGFloat {
        let limit = Swift.min(EngineAncestor.maxIndentedQuoteLevels, styleSheet.indentedQuoteLevelLimit)
        var quoteLevels = 0
        var total: CGFloat = 0.0
        for ancestor in self {
            if case .blockQuote = ancestor {
                quoteLevels += 1
                if quoteLevels > limit { continue }
            }
            total += contribution(ancestor)
        }
        return total
    }
}

/// A folding detail block, as an ancestor: an always-visible title line above a body that the fold
/// hides.
///
/// `foldedChildren` holds the body in MODEL form while folded and is empty when expanded. That is
/// model content living in a shape, which reads as a violation of "a role is STRUCTURE ONLY" — it is
/// not, and the rule it actually rests on is sharper: **no TWO sources of truth hold the same text.**
/// A folded body is the first content in this editor that is not editable — it cannot be caret-walked,
/// selected or spell-checked, because it is not in the engine at all — so it has exactly one home and
/// nothing to drift from. Shapes already carry non-editable per-block data (a media shape its items,
/// a table shape its column specs); what they have never carried is text the user can edit, and a
/// folded body is not that until it is unfolded, when it becomes engine blocks and leaves the shape.
///
/// Do NOT "fix" this into a side table keyed by id: the body would then need purge-on-delete,
/// remap-on-identity-churn and restore-on-undo, and it is lost by the first one that is missed. In the
/// shape it travels with the role through plans, the regroup, the identity map and the undo replay
/// snapshot for free (R7-details spec §7.1).
public struct DetailsShape: Equatable {
    public var id: BlockID
    public var expanded: Bool
    public var foldedChildren: [Block]

    public init(id: BlockID, expanded: Bool, foldedChildren: [Block]) {
        self.id = id
        self.expanded = expanded
        self.foldedChildren = foldedChildren
    }

    public init(_ details: DetailsBlock) {
        self.init(id: details.id, expanded: details.expanded,
                  foldedChildren: details.expanded ? [] : details.children)
    }

    /// Derived and DISTINCT from the details' own id — chrome and line are separate view-pool entries
    /// and would collide on one id, exactly as `"<quote>#author"` avoids.
    public static func titleLineID(_ id: BlockID) -> BlockID { BlockID("\(id.rawValue)#title") }
    public var titleLineID: BlockID { DetailsShape.titleLineID(id) }

    /// Legacy's `DetailsBox` geometry, inlined with its provenance because `BlockBox` is INTERNAL to
    /// `RichTextEditorUIKit` and unreachable from here — the same way `EngineBlockSpacing` already
    /// carries the one value it borrows from it.
    ///
    /// The top inset is the SAME in both states, deliberately, so the title and chevron do not move
    /// when folding; only the bottom differs.
    public static let topInset: CGFloat = 6.0
    /// `BlockBox.defaultVerticalInset` (8) + 8.
    public static let expandedBottomInset: CGFloat = 16.0
    public static let foldedBottomInset: CGFloat = 17.0
    public static let titleBodyGap: CGFloat = 14.0
    /// Left edge → the title's glyphs, clearing the chevron. Applied to the TITLE only.
    public static let titleGlyphIndent: CGFloat = 26.0
    public static let chevronSize: CGFloat = 18.0
    public static let chevronLeadingInset: CGFloat = 3.0
}

/// What one ENGINE block is, in model terms — and never what it holds.
///
/// `IDBlock` has no kind and the engine's document is a flat list, so every container's structure is
/// carried host-side, one role per engine block, parallel to the engine. A role is STRUCTURE ONLY, by
/// type: shapes, never text (structure-only roles design, 2026-09-04).
///
/// Two halves (nesting design §3): `ancestry`, the containers enclosing this block from the outermost
/// in, empty at top level; and `position`, what the block itself is. **An engine block belongs to
/// quote Q iff Q is in its ancestry** — a child, a nested container's lines and the quote's own author
/// line alike (§3.2), so spans, bands, spacing, coverage and presence all ask that one question. The
/// immediate container (`container`) is the LEAF one: the block itself, the owner of a second line,
/// the table of a cell.
public struct EngineBlockRole: Equatable {
    public enum Position: Equatable {
        /// A block that is its own engine block: a paragraph, a code block, a pull quote, a media atom.
        case standalone(EngineBlockShape)
        /// A container's SECOND editable line — a code block's language, a quote's author, a media
        /// caption. `owner` is the container's shape; `line` the identity of the paragraph this engine
        /// block IS; `kind` which of the owner's fields its text supplies.
        case secondary(owner: EngineContainerShape, line: BlockID, kind: SecondaryRegionKind)
        /// One cell of a table, grouped back by identity at (`row`, `column`). `cell` is the cell's
        /// identity, which is also its paragraph's.
        case tableCell(table: TableShape, row: Int, column: Int, cell: BlockID)
    }

    /// The containers enclosing this engine block, outermost first. Empty at top level.
    ///
    /// **Never defaulted.** Every factory below and this initializer REQUIRE it, and a top-level
    /// role says `within: []` outright. Defaulted, an omission read as "top level" and produced a
    /// role that sat visually inside a quote while belonging to no quote at all — the regroup then
    /// closed the quote before it and reopened one after. That shape shipped three times in the
    /// R7-nesting rung (a media unit inserted into a quote, `applyMediaShape`'s rebuild, and the
    /// survivor of a covered range), each time silently. Requiring it turns "I forgot" into a
    /// compile error and leaves "this really is top level" a decision someone wrote down.
    public var ancestry: [EngineAncestor]
    public var position: Position

    public init(ancestry: [EngineAncestor], position: Position) {
        self.ancestry = ancestry
        self.position = position
    }

    // MARK: Factories — the spellings every rule uses

    public static func standalone(_ shape: EngineBlockShape, within ancestry: [EngineAncestor]) -> EngineBlockRole {
        EngineBlockRole(ancestry: ancestry, position: .standalone(shape))
    }

    public static func secondary(owner: EngineContainerShape, line: BlockID, kind: SecondaryRegionKind,
                                 within ancestry: [EngineAncestor]) -> EngineBlockRole {
        EngineBlockRole(ancestry: ancestry, position: .secondary(owner: owner, line: line, kind: kind))
    }

    public static func tableCell(table: TableShape, row: Int, column: Int, cell: BlockID,
                                 within ancestry: [EngineAncestor]) -> EngineBlockRole {
        EngineBlockRole(ancestry: ancestry, position: .tableCell(table: table, row: row, column: column, cell: cell))
    }

    // MARK: Reads

    /// The shape of the model block this ENGINE block holds — a plain paragraph for a secondary line
    /// or a cell.
    public var shape: EngineBlockShape {
        switch position {
        case let .standalone(shape): return shape
        case let .secondary(_, line, _): return .paragraph(ParagraphShape(id: line))
        case let .tableCell(_, _, _, cell): return .paragraph(ParagraphShape(id: cell))
        }
    }

    public var blockID: BlockID { shape.id }

    /// The IMMEDIATE container: itself for a standalone block, the owner for a secondary line, the
    /// table for a cell. The quotes above it are in `ancestry`, not here.
    public var container: EngineContainerShape {
        switch position {
        case let .standalone(shape): return .block(shape)
        case let .secondary(owner, _, _): return owner
        case let .tableCell(table, _, _, _): return .table(table)
        }
    }

    public var containerID: BlockID { container.id }

    public var secondaryKind: SecondaryRegionKind? {
        if case let .secondary(_, _, kind) = position { return kind }
        return nil
    }

    /// A line that holds ONE line of text whatever is typed, pasted or set into it: a code block's
    /// language, a details title, a pull quote's or block quote's author. (A media caption is a
    /// secondary line too, and multi-line.) Their rule is `EngineDocumentBridge.oneLineText`.
    public var isOneLineField: Bool {
        switch secondaryKind {
        case .codeLanguage?, .detailsTitle?, .pullQuoteAuthor?, .blockQuoteAuthor?: return true
        case .mediaCaption?, nil: return false
        }
    }

    public var owningTable: TableShape? {
        if case let .tableCell(table, _, _, _) = position { return table }
        return nil
    }

    public var tableCellCoordinates: (row: Int, column: Int)? {
        if case let .tableCell(_, row, column, _) = position { return (row, column) }
        return nil
    }

    /// The container this block is DIRECTLY in, whatever kind it is.
    ///
    /// Every membership read wants this. Spelt `ancestry.last?.quote`, it answered nil as soon as a
    /// non-quote ancestor was innermost, which would have silently un-quoted ten rules the moment a
    /// details existed (R7-details spec §3.3).
    public var innermostAncestor: EngineAncestor? { ancestry.last }

    /// How many containers enclose this block, of either kind. A COUNT, and INTERNAL on purpose.
    ///
    /// It was called `quoteDepth` and it was public, and the name lied: it has counted CONTAINERS
    /// since R7-details, so three separate reads that meant QUOTES silently got the wrong number the
    /// moment a details existed. The host's quote-level control reported 1 for a caret in a top-level
    /// details; "None" un-DETAILED a block; and the quote-sized 15pt mapper was chosen for a details'
    /// body that is in no quote at all. The rename IS the fix — a raw depth should be awkward to
    /// reach and impossible to mistake for a count of quotes.
    ///
    /// Ask `enclosingQuoteCount`, `innermostEnclosingQuote` or `isInsideAQuote` when QUOTES are what
    /// you mean, and `EngineAncestor.contentIndent(styleSheet:)` when INDENT is — a details
    /// contributes none, so a depth is not a width. What legitimately wants this count: the spacing
    /// walk's nesting level, the child-depth walk in `childUnits`, and "is this inside any container
    /// at all" in the bridge.
    internal var containerDepth: Int { ancestry.count }

    /// The innermost QUOTE enclosing this block, skipping any container between.
    ///
    /// NOT the `innermostQuote` this rung deleted, which was `ancestry.last?.quote` — the trap that
    /// read nil the moment a non-quote ancestor was innermost. Every read that meant *the container
    /// I am directly in* became `innermostAncestor`; these three are the reads that genuinely mean
    /// *the quote*, and they must skip whatever else is nested inside it.
    public var innermostEnclosingQuote: QuoteShape? { ancestry.last { $0.quote != nil }?.quote }

    /// How many QUOTES enclose this block — the host's `blockQuoteDepth`, and the reason a details
    /// nested in nothing must report 0.
    public var enclosingQuoteCount: Int { ancestry.reduce(0) { $0 + ($1.quote == nil ? 0 : 1) } }

    /// Whether any ancestor is a quote — the predicate that chooses the quote-sized mapper. Quote
    /// text is 15pt at any depth; a details inside no quote is body-sized, exactly as legacy's
    /// `DetailsBox` renders its children with the mapper it was handed.
    public var isInsideAQuote: Bool { ancestry.contains { $0.quote != nil } }

    /// Whether this role is a line the container `id` OWNS — its author, its title — rather than
    /// part of a child.
    ///
    /// THE one spelling of container ownership, and it lives here rather than on the view so that
    /// `EngineBlockSpacing` — a free function over a roles array, with no view to call — uses the
    /// same test the rules do. Keyed on `containerID`, never on the kind: a CHILD's own second line
    /// (a code block's language, whose container is the code block) belongs to its child's unit, not
    /// to the container around it, and conflating the two is what made a span's first and last role
    /// read as its first and last child.
    public func isOwnedLine(of id: BlockID) -> Bool {
        secondaryKind != nil && containerID == id
    }

    /// The same question narrowed to one kind — "is this THAT container's title / author line".
    public func isOwnedLine(_ kind: SecondaryRegionKind, of id: BlockID) -> Bool {
        secondaryKind == kind && containerID == id
    }

    /// Whether this role is a line owned by an ANCESTOR container rather than by a leaf block — a
    /// quote's author, a details' title. Such a line has no sibling primary sharing its `containerID`
    /// (the container's primaries are its CHILDREN, which carry their own ids), so every rule that
    /// asks "does my container still have content" must ask its SPAN instead.
    public var isOwnedByAnAncestorContainer: Bool {
        switch secondaryKind {
        case .blockQuoteAuthor, .detailsTitle: return true
        case .codeLanguage, .pullQuoteAuthor, .mediaCaption, nil: return false
        }
    }

    /// The content indent this block sits at: the sum of what each enclosing container contributes.
    public func contentIndent(styleSheet: StyleSheet) -> CGFloat {
        ancestry.contentIndent(styleSheet: styleSheet)
    }

    /// How far short of the trailing edge this block stops: the sum of what each enclosing container
    /// keeps back. The mirror of `contentIndent`, summed the same way so nesting composes.
    public func contentTrailingInset(styleSheet: StyleSheet) -> CGFloat {
        ancestry.contentTrailingInset(styleSheet: styleSheet)
    }

    public func isWithin(_ id: BlockID) -> Bool { ancestry.contains { $0.id == id } }

    /// The same role with its own block's shape replaced — a paragraph restyled, a list joined. A
    /// secondary line and a cell are plain paragraphs by definition and keep theirs.
    public func replacingShape(_ shape: EngineBlockShape) -> EngineBlockRole {
        guard case .standalone = position else { return self }
        return EngineBlockRole(ancestry: ancestry, position: .standalone(shape))
    }

    /// The same role with its owning TABLE's shape replaced, preserving row, column and cell id.
    /// Returns self unchanged for a role that is not a table cell.
    ///
    /// Separate from `replacingShape` because a cell carries its table in the role's POSITION, not
    /// its shape — a cell's `shape` is the plain paragraph it is, by definition.
    public func replacingOwningTable(_ table: TableShape) -> EngineBlockRole {
        guard case let .tableCell(_, row, column, cell) = position else { return self }
        return EngineBlockRole(ancestry: ancestry,
                               position: .tableCell(table: table, row: row, column: column, cell: cell))
    }

    /// The same position at another depth.
    public func within(_ ancestry: [EngineAncestor]) -> EngineBlockRole {
        EngineBlockRole(ancestry: ancestry, position: position)
    }

    // MARK: Regroup

    /// The model document these engine blocks describe, `blocks` being the materialised block of
    /// each role (engine-parallel; `EngineDocumentBridge.blocks(for:from:)`).
    ///
    /// A stack walk over ancestries (§3.4). For each primary role: close every open container that
    /// is not a prefix of the role's ancestry (a closed quote takes its author from the secondary
    /// map and joins its parent's children), open the rest, then append the leaf — a materialised
    /// block merged with its own second lines, or a cell into the open table run. Keyed on
    /// identity, not adjacency, so two quotes with one id separated by another block stay two.
    public static func document(roles: [EngineBlockRole], blocks: [Block]) -> Document {
        var secondaryByOwner: [BlockID: [SecondaryRegionKind: Block]] = [:]
        for (index, role) in roles.enumerated() where index < blocks.count {
            guard case let .secondary(owner, _, kind) = role.position else { continue }
            secondaryByOwner[owner.id, default: [:]][kind] = blocks[index]
        }

        struct Open { let ancestor: EngineAncestor; var children: [Block] }
        var result: [Block] = []
        var open: [Open] = []
        var pendingTable: TableShape?
        var pendingCells: [(row: Int, column: Int, paragraph: ParagraphBlock)] = []

        func append(_ block: Block) {
            if open.isEmpty { result.append(block) } else { open[open.count - 1].children.append(block) }
        }
        func flushTable() {
            guard let table = pendingTable else { return }
            append(.table(table.table(cells: pendingCells)))
            pendingTable = nil
            pendingCells = []
        }
        func close() {
            flushTable()
            let closed = open.removeLast()
            switch closed.ancestor {
            case let .blockQuote(quote):
                let built = BlockQuote(id: quote.id, children: closed.children, collapsed: quote.collapsed)
                append(Block.blockQuote(built).merging(secondaryByOwner[quote.id]))
            case let .details(details):
                // Expanded, the children are the ones just closed; FOLDED, they are the ones the
                // shape has been carrying, because a folded body is not in the engine at all
                // (R7-details spec §7.1). The title comes from the secondary line, like an author.
                let built = DetailsBlock(id: details.id, title: [],
                                         children: details.expanded ? closed.children : details.foldedChildren,
                                         expanded: details.expanded)
                append(Block.details(built).merging(secondaryByOwner[details.id]))
            }
        }
        func isPrefix(_ open: [Open], of ancestry: [EngineAncestor]) -> Bool {
            open.count <= ancestry.count && zip(open, ancestry).allSatisfy { $0.ancestor.id == $1.id }
        }

        for (index, role) in roles.enumerated() where index < blocks.count {
            // EVERY role opens and closes its ancestry, secondary lines included — only PRIMARY roles
            // contribute a child block, which is what the `continue` below still enforces.
            //
            // Driven by primaries alone, as it was, a container whose every role is secondary is
            // never opened and vanishes from the document: a FOLDED details' only engine block is
            // its title (§7.1), so `[details(folded)]` read back as an EMPTY document and the first
            // consumer to index into it crashed. Quotes are unaffected — a quote always has a
            // primary child (the bridge mints a rescue one for an empty quote), so its author line
            // finds the quote already open and this changes nothing for it.
            while !open.isEmpty, !isPrefix(open, of: role.ancestry) { close() }
            if open.count < role.ancestry.count {
                flushTable()
                for ancestor in role.ancestry[open.count...] { open.append(Open(ancestor: ancestor, children: [])) }
            }
            if role.secondaryKind != nil { continue }
            if case let .tableCell(table, row, column, cell) = role.position {
                if pendingTable?.id != table.id { flushTable(); pendingTable = table }
                pendingCells.append((row, column, blocks[index].asParagraph ?? ParagraphBlock(id: cell)))
            } else {
                flushTable()
                append(blocks[index].merging(secondaryByOwner[role.containerID]))
            }
        }
        while !open.isEmpty { close() }
        flushTable()
        return Document(blocks: result)
    }
}

private extension Block {
    /// This block with each second line's contribution folded in.
    ///
    /// The two versions of one container are built by the same reverse pass — the primary rebuilds
    /// `runs`, the secondary rebuilds the field its line supplies — so merging is choosing the right
    /// field from each rather than reconciling them.
    /// An author line's model runs: its RUNS, like a caption's, with only the render-only emphasis
    /// taken out. The author's bold + italic is the line's style and must never persist
    /// (`PullQuote.author` says so), and a size is never the user's. Everything else is: a mention,
    /// a link, a date, a custom emoji in an author are the message's. The line used to be rebuilt as
    /// `[TextRun(text: flatText)]`, which dropped every entity on a mere set → get — opening an edited
    /// message — and kept a custom emoji's attachment character as a bare `U+FFFC` with no entity
    /// (composer harness p13, `HarnessAuthorLineEntityTests`).
    static func authorRuns(_ line: Block) -> [TextRun] {
        let runs = (line.asParagraph?.runs ?? []).compactMap { run -> TextRun? in
            guard !run.text.isEmpty else { return nil }
            var run = run
            run.attributes.bold = false
            run.attributes.italic = false
            run.attributes.fontSize = nil
            return run
        }
        return runs
    }

    func merging(_ secondary: [SecondaryRegionKind: Block]?) -> Block {
        guard let secondary, !secondary.isEmpty else { return self }
        var result = self
        if case var .blockQuote(quote) = result, let author = secondary[.blockQuoteAuthor] {
            quote.author = Self.authorRuns(author)
            result = .blockQuote(quote)
        }
        if case var .pullQuote(quote) = result, let author = secondary[.pullQuoteAuthor] {
            quote.author = Self.authorRuns(author)
            result = .pullQuote(quote)
        }
        if case var .code(code) = result, let language = secondary[.codeLanguage]?.flatText {
            // An emptied line means "no language", not an empty one: `nil` is what every consumer
            // reads as absent, and an empty string would render a blank highlight header.
            // The CASE is always the user's: the line renders the language as stored, so nothing
            // lowercases it any more on the way round (see `EngineDocumentBridge.languageLine(for:)`).
            // So is the WHITESPACE (composer harness p24, `HarnessCodeLanguageEdgeWhitespaceTests`): the
            // model holds the line as typed, edge spaces included, so model and engine agree on every
            // offset. The read-back used to trim, and the next re-render from the model (a theme change)
            // dropped the space the user had just typed — the space before the next word of
            // "objective c" — and restored the selection on an offset one character past the shortened
            // line, so the caret jumped to the code body's end; model offsets were a character off from
            // then on. A `Pre` language is a token, so it is trimmed where it is SENT
            // (`chatInputCodeLanguageForSending`, TelegramCore), not while the user is typing it.
            code.language = language.isEmpty ? nil : language
            result = .code(code)
        }
        if case var .details(details) = result, let title = secondary[.detailsTitle] {
            // RUNS, like a caption: a title may be bold, linked, or hold a custom emoji.
            details.title = title.asParagraph?.runs ?? []
            result = .details(details)
        }
        if case var .media(media) = result, let caption = secondary[.mediaCaption] {
            // RUNS, not text: bold, links and custom emoji in a caption are the user's.
            media.caption = caption.asParagraph?.runs ?? []
            result = .media(media)
        }
        return result
    }
}

#endif

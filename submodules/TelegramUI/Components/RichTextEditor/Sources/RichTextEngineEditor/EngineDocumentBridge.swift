#if canImport(UIKit)
import Foundation
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// Maps between Telegram's value model and the engine's `attributedBlocks`.
///
/// It owns NO mapping logic of its own: `AttributedStringMapper` already goes both ways
/// (`attributedString(for:)` and `runs(from:)`) and carries the InstantPage render metrics.
/// This type is the block-level shell around it, plus the paragraph-structure reuse policy.
@available(iOS 18.4, *)
public struct EngineDocumentBridge {
    /// INTERNAL rather than private, for one consumer: `+ButtonRows.swift` hands it to
    /// `RichTextButtonRowView`, whose packing needs the metrics, the theme, the writing direction and
    /// the mapper's own two measuring closures — that is the whole mapper, so a narrower accessor
    /// would buy nothing. Still narrower than the `styleSheet` below it, which is public.
    internal private(set) var mapper: AttributedStringMapper

    /// The stylesheet this bridge renders with. Read by the host for the quote geometry it has to
    /// reserve in the LAYOUT rather than in the text (`quoteTopInset`/`quoteBottomInset`).
    public var styleSheet: StyleSheet { mapper.styleSheet }
    /// The palette the mapper renders with — read by the host-positioned overlays that draw text of
    /// their own (a list marker), so their colour comes from the same place the text's does.
    public var theme: RichTextEditorTheme { mapper.theme }

    /// Quoted content one step below body, per V2's `quoteScale` — the same 15/17 the renderer
    /// applies, derived from the host's mapper so its theme, metrics and writing direction carry over.
    private let quoteMapper: AttributedStringMapper
    /// The mapper a code block's text is rendered AND read back through.
    ///
    /// A code block is flattened onto the engine's axis as an ordinary `.body` paragraph — there is
    /// no code paragraph style to select — so the way to give it the code FONT is to hand that pass a
    /// mapper whose body spec IS `metrics.codeBlock` (V2's absolute 15pt monospace). Substituting the
    /// face afterwards cannot work: the paragraph style's pinned line height is computed from
    /// whichever font the mapper laid out, so the text would be spaced for a font it is not set in.
    /// Same shape as `quoteMapper`, and for the same reason.
    private let codeMapper: AttributedStringMapper

    /// Cells read at 15pt in both editors — the legacy canvas builds every cell box from this
    /// variant (`TableBlockBox` derives it once per table).
    private let tableCellMapper: AttributedStringMapper

    /// Pull-quote geometry, which the stylesheet does not carry (it holds only the italic + centred
    /// TEXT attributes for `.pullQuote`; the pill's own numbers live in `PullQuoteStyle`).
    private let pullQuoteStyle: PullQuoteStyle

    /// Media geometry the stylesheet does not carry: the bleed the attachment's height is computed
    /// at (`MediaTextAttachment`). Travels with the bridge like `pullQuoteStyle`, and for the same
    /// reason — a document set renders it, so a change rebuilds the bridge (`applyMediaBlockStyle`).
    internal let mediaBlockStyle: MediaBlockStyle

    public init(mapper: AttributedStringMapper, pullQuoteStyle: PullQuoteStyle = .default,
                mediaBlockStyle: MediaBlockStyle = .default) {
        self.mapper = mapper
        self.pullQuoteStyle = pullQuoteStyle
        self.mediaBlockStyle = mediaBlockStyle
        let bodySize = mapper.styleSheet.metrics.body.size
        quoteMapper = mapper.withBodyFontSize(floor(bodySize * RichTextRenderMetrics.quoteScale))
        var codeMetrics = mapper.styleSheet.metrics
        codeMetrics.body = codeMetrics.codeBlock
        codeMapper = mapper.withRenderMetrics(codeMetrics)
        tableCellMapper = mapper.tableCellVariant()
    }

    /// Paragraphs, the two LEAF containers, and now media. Table, block quote, details and button row
    /// still TRAP naming rung R7. This is deliberate, not an oversight: a silent drop here would read
    /// as data loss the first time a user pastes a table. The trap itself is exercised at R7 in the
    /// Host app, not by an XCTest here — a `preconditionFailure` cannot be caught in-process, so a test
    /// that "expects" it would only be asserting something weaker than its name claims.
    ///
    /// **`IDBlock` has no kind.** The engine's document is a flat list of `(NSUUID, attributedText)`;
    /// there is no field in which "this block is a code block" could be stored. So a container is
    /// FLATTENED to its text here and its kind travels host-side, in the identity table the reverse
    /// function reads — the same mechanism paragraph style and list membership already use, for the
    /// same reason.
    ///
    /// `CodeBlock` and `PullQuote` are LEAF containers: one `runs` list each, so each maps to exactly
    /// one engine block and the flattening loses only the kind. `BlockQuote` has `children: [Block]`
    /// and so is SEVERAL engine blocks, which this one-string-per-block API cannot express — it
    /// traps HERE for that reason alone, not for lack of a recursive pass: `engineRepresentation(for:)`
    /// is the live path a document set actually uses, and it flattens a quote (any child kind, any
    /// depth) via `flatten(_:within:into:roles:)`.
    public func attributedBlocks(for document: Document) -> [NSAttributedString] {
        document.blocks.map { block in
            switch block {
            case let .paragraph(paragraph):
                return Self.engineReadable(mapper.attributedString(for: Self.engineParagraph(paragraph)))
            case let .code(code):
                return Self.engineReadable(Self.padded(Self.stampingMonospaceBaseFont(codeMapper.attributedString(
                    for: ParagraphBlock(id: code.id, style: .body, runs: Self.engineRuns(Self.plainCodeRuns(code.runs))))),
                    by: mapper.styleSheet.codeHorizontalInset))
            case let .pullQuote(quote):
                // `.pullQuote` IS a paragraph style the mapper renders, so the quote's own look comes
                // for free. Its `author` line is a SECOND region with no engine counterpart — it is
                // preserved through the identity table rather than flattened, and is not editable on
                // this path yet.
                return Self.engineReadable(Self.padded(mapper.attributedString(
                    for: ParagraphBlock(id: quote.id, style: .pullQuote, runs: Self.pullQuoteRuns(quote.runs))),
                    by: pullQuoteStyle.horizontalPadding))
            case let .media(media):
                return mediaAtom(for: MediaShape(media))
            case .table, .blockQuote, .details, .buttonRow:
                richTextEngineUnimplemented("Block.\(block.caseNameForDiagnostics)", rung: "R7")
            }
        }
    }

    /// The attributes the bridge renders `role`'s first character with — what an empty block of
    /// that role should be measured, typed into and restyled with. One probe render of THAT block.
    internal func lineAttributes(for role: EngineBlockRole) -> [NSAttributedString.Key: Any] {
        // A media atom is one attachment character, never an empty LINE of its own to measure. If it
        // is ever empty, integrity settle (Task 8) makes it a paragraph — so it measures as one
        // meanwhile.
        if case .media = role.shape, role.secondaryKind == nil {
            return lineAttributes(for: .standalone(.paragraph(ParagraphShape(id: role.blockID)), within: role.ancestry))
        }
        let (probeBlocks, probeRoles) = engineRepresentation(for: Document(blocks: [probeBlock(for: role)]))
        let match = zip(probeBlocks, probeRoles).first { candidate, candidateRole in
            candidate.length > 0 && candidateRole.secondaryKind == role.secondaryKind
        }
        return match?.0.attributes(at: 0, effectiveRange: nil) ?? [:]
    }

    /// How far along its line an EMPTY block's caret sits: at the start of a centred prompt for a
    /// pull quote's author line or a media caption, else 0. A centred prompt is centred on the line,
    /// so its leading edge is half its own width left of the insertion point the line's alignment
    /// produces.
    internal func emptyLineCaretOffset(for role: EngineBlockRole) -> CGFloat {
        switch role.secondaryKind {
        case .pullQuoteAuthor:
            let font = Self.authorPromptFont(styleSheet: mapper.styleSheet)
            return -(quoteAuthorPlaceholderText as NSString).size(withAttributes: [.font: font]).width / 2.0
        case .mediaCaption:
            let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
            return -(mediaCaptionPlaceholderText as NSString).size(withAttributes: [.font: font]).width / 2.0
        case .codeLanguage, .blockQuoteAuthor, .detailsTitle, nil:
            // A title is LEADING-aligned like a language line, so its caret sits at the line start.
            return 0.0
        }
    }

    /// The face the prompt is drawn in — bold + italic caption, matching the author line itself.
    internal static func authorPromptFont(styleSheet: StyleSheet) -> UIFont {
        let base = UIFont.systemFont(ofSize: styleSheet.metrics.caption.size)
        let traits = base.fontDescriptor.symbolicTraits.union([.traitBold, .traitItalic])
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }

    /// What makes two blocks render their empty line the same way: the role, the block's kind, and
    /// the paragraph fields the stylesheet reads. Never the text.
    internal static func probeShapeKey(for role: EngineBlockRole) -> String {
        var key = role.secondaryKind.map { "secondary-\($0)" } ?? "primary"
        // The ancestry's KIND SEQUENCE, not its length. Depth alone pins neither the face nor the
        // indent: `quote > quote` and `quote > details` are both depth 2, render at the same size and
        // at DIFFERENT indents (32 against 16), so keyed on depth they shared one cached measurement
        // and whichever was measured first gave the other its empty-line indent and typing attributes.
        key += "|ancestry\(role.ancestry.map { $0.details == nil ? "q" : "d" }.joined())"
        if let table = role.owningTable, let (row, column) = role.tableCellCoordinates {
            let cell = table.cell(row: row, column: column)
            key += "|tableCell|\(cell?.isHeader ?? false)|\(String(describing: cell?.horizontalAlignment))"
        }
        switch role.shape {
        case let .paragraph(paragraph):
            key += "|paragraph|\(paragraph.style)|\(String(describing: paragraph.list?.marker))"
            key += "|\(String(describing: paragraph.list?.level))"
            key += "|\(paragraph.paragraph.alignment)"
        case .code: key += "|code"
        case .pullQuote: key += "|pullQuote"
        case let .media(media): key += "|media|\(media.isCaptionless)"
        // The pill COUNT and alignment change the packed height, which is what an empty-line
        // measurement caches — two rows differing only in pill count must not share one.
        case let .buttonRow(row): key += "|buttonRow|\(row.buttons.count)|\(row.alignment)"
        case .collapsedQuote: key += "|collapsedQuote"
        }
        return key
    }

    /// The same block with one character in it, so its rendering can be measured.
    private func probeBlock(for role: EngineBlockRole) -> Block {
        let probe = [TextRun(text: "x")]
        let leaf: Block
        switch role.position {
        case let .tableCell(table, row, column, cell):
            // One cell with the probe in it, rendered with the cell mapper. The REAL cell's shape is
            // used so its header flag and alignment shape the probe: a fresh `Cell` here gave a
            // header cell non-bold typing attributes until the next re-render (seen on device).
            var probeCell = table.cell(row: row, column: column)?.cell(blocks: []) ?? Cell(id: cell)
            probeCell.id = cell
            probeCell.blocks = [.paragraph(ParagraphBlock(id: BlockID("probe-p"), runs: probe))]
            leaf = .table(TableBlock(id: table.id, columns: table.columns,
                                     rows: [Row(id: BlockID("probe-row"), cells: [probeCell])],
                                     compact: table.compact, bordered: table.bordered))
        case let .secondary(owner, _, kind):
            switch (kind, owner) {
            case let (.codeLanguage, .block(.code(id, _))):
                leaf = .code(CodeBlock(id: id, language: "x", runs: []))
            case let (.blockQuoteAuthor, .blockQuote(quote)):
                leaf = .blockQuote(BlockQuote(id: quote.id, children: [], collapsed: quote.collapsed, author: probe))
            case let (.pullQuoteAuthor, .block(.pullQuote(id))):
                leaf = .pullQuote(PullQuote(id: id, runs: [], author: probe))
            case let (.mediaCaption, .block(.media(shape))):
                leaf = .media(shape.block(caption: probe))
            case let (.detailsTitle, .details(details)):
                // Built EXPANDED and childless: the probe measures the title LINE, and a folded one
                // would be fine too, but `expanded` also decides nothing about the title's own face.
                // Without this arm the probe fell to the paragraph default, `lineAttributes` found
                // no role with a matching `secondaryKind`, and returned NOTHING — so a freshly
                // inserted details' empty title had no font and no paragraph style, putting its
                // caret under the chevron while the placeholder drew 26pt in.
                leaf = .details(DetailsBlock(id: details.id, title: probe, children: [], expanded: true))
            default:
                leaf = .paragraph(ParagraphBlock(id: Self.probeBlockID, runs: probe))
            }
        case let .standalone(shape):
            leaf = shape.block(runs: probe)
        }
        // A quote's own author line already IS its quote (the arm above builds one), so it is
        // enclosed in the quote's parents only; everything else in its whole ancestry.
        let enclosing = role.ancestry.last?.id == role.containerID ? Array(role.ancestry.dropLast()) : role.ancestry
        return Self.enclosed(leaf, in: enclosing)
    }

    /// `block` wrapped in each ancestor, innermost first — the document a set would render it in, so
    /// an empty nested line is measured at its own indent and face.
    private static func enclosed(_ block: Block, in ancestry: [EngineAncestor]) -> Block {
        ancestry.reversed().reduce(block) { inner, ancestor in
            switch ancestor {
            case let .blockQuote(quote):
                return .blockQuote(BlockQuote(id: quote.id, children: [inner], collapsed: quote.collapsed, author: []))
            case let .details(details):
                // The probe measures a LINE at its own indent, so the enclosing details is rebuilt
                // EXPANDED whatever its real state: a folded one would drop the very child being
                // measured, and the probe would come back at the wrong indent.
                return .details(DetailsBlock(id: details.id, title: [], children: [inner], expanded: true))
            }
        }
    }

    /// A detail block's title line: Body style, and the ONLY thing a details indents — its glyphs
    /// clear the leading chevron by `DetailsShape.titleGlyphIndent`, on top of whatever the enclosing
    /// containers indent. The details itself contributes nothing to that enclosing indent (§3.4), so
    /// this is an indent the title carries and its children do not.
    ///
    /// A display-only paragraph indent, exactly as legacy does it, so the line's FRAME stays full
    /// width and only the text moves.
    static func detailsTitleLine(runs: [TextRun], using mapper: AttributedStringMapper,
                                 contentIndent: CGFloat,
                                 contentTrailingInset: CGFloat = 0) -> NSAttributedString {
        let line = mapper.attributedString(for: ParagraphBlock(id: probeBlockID, style: .body,
                                                               runs: oneLineRuns(runs)))
        return quoteIndented(engineReadable(line), by: contentIndent + DetailsShape.titleGlyphIndent,
                             trailing: contentTrailingInset)
    }

    /// Identity for a throwaway probe block; never reaches the document.
    private static let probeBlockID = BlockID("empty-line-probe")

    public func engineRepresentation(for document: Document) -> ([NSAttributedString], [EngineBlockRole]) {
        var blocks: [NSAttributedString] = []
        var roles: [EngineBlockRole] = []
        flatten(Self.withoutInlineCodeOverLinks(document.blocks), within: [], into: &blocks, roles: &roles)
        let rendered = Self.withoutBlockSeparators(blocks, roles: roles)
        if let hook = Self.testHookRenderedBlocks {
            return (hook(rendered, roles), roles)
        }
        return (rendered, roles)
    }

    /// TEST ONLY: rewrites a document set's rendering after the bridge's own contract has run — how a test
    /// puts a block separator into a rendered block (the state no shipping path reaches since p23) to drive the
    /// role-count recovery (`HarnessRoleRecoveryByIdentityTests`). Always nil in the app.
    internal static var testHookRenderedBlocks: (([NSAttributedString], [EngineBlockRole]) -> [NSAttributedString])?

    /// The bridge's output contract, enforced where every rendering leaves it: no engine block holds a
    /// `U+000A`, which IS the engine's block separator. One that did became two engine blocks against
    /// one role, every role after it shifted, and the layout pass trapped (debug) or the message lost
    /// its last block (release) — a code language or an author rendered with its newline raw (composer
    /// harness p23, `HarnessNewlineInOneLineFieldCrashTests`). Each kind maps its own newlines; this is
    /// the backstop for a kind that does not: a one-line field's newline becomes a space (its rule,
    /// `oneLineText`), any other block's a line separator (`engineText`).
    private static func withoutBlockSeparators(_ blocks: [NSAttributedString],
                                               roles: [EngineBlockRole]) -> [NSAttributedString] {
        // LITERAL, as every structural "\n" search is (p20): CRLF is one composed character.
        func holdsSeparator(_ block: NSAttributedString) -> Bool {
            (block.string as NSString).range(of: "\n", options: .literal).location != NSNotFound
        }
        guard blocks.contains(where: holdsSeparator) else { return blocks }
        return blocks.enumerated().map { index, block in
            guard holdsSeparator(block) else { return block }
            NSLog("RichTextEngineEditor: a rendered block held U+000A — mapped (bridge backstop)")
            let oneLine = index < roles.count && roles[index].isOneLineField
            let result = NSMutableAttributedString(attributedString: block)
            var location = (result.string as NSString).range(of: "\n", options: .literal).location
            while location != NSNotFound {
                result.replaceCharacters(in: NSRange(location: location, length: 1), with: oneLine ? " " : lineSeparator)
                let next = location + 1
                location = (result.string as NSString).range(of: "\n", options: .literal,
                                                             range: NSRange(location: next, length: result.length - next)).location
            }
            return result
        }
    }

    /// The engine representation of `blocks` as if they sat inside `ancestry`.
    ///
    /// The entry point above hard-codes `within: []`, which is right for a whole document and WRONG
    /// for a FRAGMENT that lives inside a container: a quoted table's cells render through the quote
    /// mapper and are indented, so building them at top level and re-parenting the roles afterwards
    /// gives correct structure wrapped around wrong TEXT. Passing the ancestry down makes the render
    /// and the roles come from one call, which also removes the R7-nesting trap about factory-built
    /// roles returning top-level rather than leaving it to be remembered.
    internal func engineRepresentation(for blocks: [Block],
                                       within ancestry: [EngineAncestor]) -> ([NSAttributedString], [EngineBlockRole]) {
        var rendered: [NSAttributedString] = []
        var roles: [EngineBlockRole] = []
        flatten(Self.withoutInlineCodeOverLinks(blocks), within: ancestry, into: &rendered, roles: &roles)
        return (Self.withoutBlockSeparators(rendered, roles: roles), roles)
    }

    /// One block after another onto the engine's axis, each role stamped `ancestry` (nesting design
    /// §4.1). A quote pushes itself and recurses; every other kind emits exactly what it emits at top
    /// level. Text inside a quote is indented `quoteIndent` per level in its paragraph style; a cell is
    /// PLACED and is not (§4.2).
    private func flatten(_ source: [Block], within ancestry: [EngineAncestor],
                         into blocks: inout [NSAttributedString], roles: inout [EngineBlockRole]) {
        let depth = ancestry.count
        // Whether a QUOTE encloses this level — the 15pt question, which is not the depth question:
        // a details contributes a level and no size change.
        let insideAQuote = ancestry.contains { $0.quote != nil }
        // The SUM of what each container contributes, not the count times a constant: a details
        // contributes nothing (R7-details spec §3.4).
        let contentIndent = ancestry.contentIndent(styleSheet: mapper.styleSheet)
        let indent = contentIndent
        // …and how far short of the column each one stops. A quote keeps its content back on BOTH
        // sides (legacy's `BlockQuoteBox`: `inner = width - leadingInset - trailingInset`), so the
        // same sum is taken over the trailing insets and travels as a negative `tailIndent`.
        let trailing = ancestry.contentTrailingInset(styleSheet: mapper.styleSheet)
        func emit(_ text: NSAttributedString, _ role: EngineBlockRole) {
            blocks.append(depth > 0 ? Self.quoteIndented(text, by: indent, trailing: trailing) : text)
            roles.append(role)
        }
        for block in source {
            switch block {
            case let .table(table):
                // The shape rescues a table with no rows to one empty cell.
                let shape = TableShape(table)
                for (r, row) in shape.rows.enumerated() {
                    for (c, cellShape) in row.cells.enumerated() {
                        let cell = table.rows.indices.contains(r) && table.rows[r].cells.indices.contains(c)
                            ? table.rows[r].cells[c] : cellShape.cell(blocks: [])
                        blocks.append(cellLine(for: cell, paragraph: Self.cellParagraph(for: cell)))
                        roles.append(.tableCell(table: shape, row: r, column: c, cell: cell.id, within: ancestry))
                    }
                }
            case let .code(code):
                // The LANGUAGE is a second editable line ABOVE the code, emitted even when empty: it is
                // the affordance for adding one. Padded like the code so the label sits at its x.
                emit(Self.padded(Self.languageLine(for: code, using: mapper), by: mapper.styleSheet.codeHorizontalInset),
                     .secondary(owner: .block(.code(id: code.id, language: code.language)),
                                line: BlockID("\(code.id.rawValue)#language"), kind: .codeLanguage, within: ancestry))
                emit(attributedBlock(for: block), .standalone(.code(id: code.id, language: code.language), within: ancestry))
            case let .pullQuote(pull):
                emit(attributedBlock(for: block, using: insideAQuote ? quoteMapper : nil, within: ancestry),
                     .standalone(.pullQuote(id: pull.id), within: ancestry))
                // Conditional where a language line is unconditional (`PullQuoteBox.shouldShowAuthor`).
                if !pull.author.isEmpty || !pull.text.isEmpty {
                    emit(Self.padded(Self.authorLine(runs: pull.author, centred: true, using: mapper), by: pullQuoteStyle.horizontalPadding),
                         .secondary(owner: .block(.pullQuote(id: pull.id)), line: BlockID("\(pull.id.rawValue)#author"),
                                    kind: .pullQuoteAuthor, within: ancestry))
                }
            case let .media(media):
                let shape = MediaShape(media)
                emit(mediaAtom(for: shape, within: ancestry), .standalone(.media(shape), within: ancestry))
                // The caption BELOW the atom, unconditional for a captioned kind, absent for audio/document.
                if !shape.isCaptionless {
                    emit(Self.captionLine(runs: media.caption, using: mapper),
                         .secondary(owner: .block(.media(shape)), line: shape.captionLineID, kind: .mediaCaption, within: ancestry))
                }
            case let .paragraph(paragraph):
                // A QUOTE makes text 15pt, at any depth. `depth` counts CONTAINERS, so keyed on it a
                // paragraph inside a top-level details rendered quote-sized although no quote
                // enclosed it — while its title, always built with the plain mapper, stayed 17pt.
                // Legacy's `DetailsBox` builds its children with the mapper it was handed, so a
                // details is body-sized outside a quote and quote-sized inside one, throughout.
                emit(attributedBlock(for: block, using: insideAQuote ? quoteMapper : nil, within: ancestry),
                     .standalone(.paragraph(ParagraphShape(paragraph)), within: ancestry))
            case let .blockQuote(quote):
                // FOLDED: one atom, no children on the axis, no author line. The quote does NOT
                // join the ancestry — it is a leaf here, and the shape is the only copy of what it
                // holds (R7-collapse §3.1). `emit` still gives the atom the ENCLOSING containers'
                // indent, which is what a folded quote inside an open one needs.
                if quote.collapsed {
                    let shape = QuoteShape(quote)
                    emit(collapsedQuoteAtom(for: shape, within: ancestry),
                         .standalone(.collapsedQuote(shape), within: ancestry))
                    continue
                }
                let inner = ancestry + [.blockQuote(QuoteShape(quote))]
                // An empty quote still needs one engine block, or it would vanish on the round trip.
                let children: [Block] = quote.children.isEmpty
                    ? [.paragraph(ParagraphBlock(id: BlockID(UUID().uuidString)))] : quote.children
                flatten(children, within: inner, into: &blocks, roles: &roles)
                // The quote's own AUTHOR line, below everything it holds — shown once anything is
                // quoted. A quote holds CHILDREN, so the question is whether it holds one, not
                // whether any engine block it produced carries text: an empty TABLE, an empty code
                // block, a captionless medium and an empty nested quote are all structure the user
                // put there, and a quote holding one has something to attribute. Asked as "any
                // primary engine block non-empty" — which it was — a quote whose only child was a
                // fresh table never got its author line (K3, 2026-09-11). Settle's twin is
                // `authorLinePresenceThatIsWrong`, which asks `ContainerContents.isEmpty`; the two
                // must agree or a document SET and the next keystroke disagree about one document.
                let quoted = children.contains { !Self.isEmptyBodyParagraph($0) }
                if !quote.author.isEmpty || quoted {
                    blocks.append(Self.quoteIndented(
                        Self.authorLine(runs: quote.author, centred: false, using: mapper),
                        by: inner.contentIndent(styleSheet: mapper.styleSheet),
                        trailing: inner.contentTrailingInset(styleSheet: mapper.styleSheet)))
                    roles.append(.secondary(owner: .blockQuote(QuoteShape(quote)), line: BlockID("\(quote.id.rawValue)#author"),
                                            kind: .blockQuoteAuthor, within: inner))
                }
            case let .details(details):
                // The TITLE first — always, and always exactly one, which is what makes a folded
                // details' span a single engine block. Then the children, ONLY when expanded: a
                // folded body is not in the engine at all, it rides in the shape (§7.1).
                let shape = DetailsShape(details)
                let inner = ancestry + [.details(shape)]
                // `detailsTitleLine` is the ONE spelling of a title, shared with `render(role:)`
                // below, so a title emitted by a document set and one re-rendered after an edit
                // cannot drift. Every other secondary kind is built inline in its own arm.
                blocks.append(Self.detailsTitleLine(
                    runs: details.title, using: insideAQuote ? quoteMapper : mapper,
                    contentIndent: inner.contentIndent(styleSheet: mapper.styleSheet),
                    contentTrailingInset: inner.contentTrailingInset(styleSheet: mapper.styleSheet)))
                roles.append(.secondary(owner: .details(shape), line: shape.titleLineID,
                                        kind: .detailsTitle, within: inner))
                if details.expanded {
                    let children: [Block] = details.children.isEmpty
                        ? [.paragraph(ParagraphBlock(id: BlockID(UUID().uuidString)))] : details.children
                    flatten(children, within: inner, into: &blocks, roles: &roles)
                }
            case let .buttonRow(row):
                let shape = ButtonRowShape(row)
                emit(buttonRowAtom(for: shape, within: ancestry),
                     .standalone(.buttonRow(shape), within: ancestry))
            }
        }
    }

    /// One block's engine text. Shared by both paths so a quote's child is rendered exactly as the
    /// same paragraph would be at top level.
    private func attributedBlock(for block: Block,
                                 using mapper: AttributedStringMapper? = nil,
                                 within ancestry: [EngineAncestor] = []) -> NSAttributedString {
        let mapper = mapper ?? self.mapper
        switch block {
        case let .paragraph(paragraph):
            return Self.engineReadable(mapper.attributedString(for: Self.engineParagraph(paragraph)))
        case let .code(code):
            return Self.engineReadable(Self.padded(Self.stampingMonospaceBaseFont(codeMapper.attributedString(
                for: ParagraphBlock(id: code.id, style: .body, runs: Self.engineRuns(Self.plainCodeRuns(code.runs))))),
                by: mapper.styleSheet.codeHorizontalInset))
        case let .pullQuote(quote):
            return Self.engineReadable(Self.padded(Self.stampingAmbientItalicBaseFont(mapper.attributedString(
                for: ParagraphBlock(id: quote.id, style: .pullQuote, runs: Self.pullQuoteRuns(quote.runs)))),
                by: pullQuoteStyle.horizontalPadding))
        case let .media(media):
            return mediaAtom(for: MediaShape(media), within: ancestry)
        case let .buttonRow(row):
            return buttonRowAtom(for: ButtonRowShape(row), within: ancestry)
        // A FOLDED quote renders as its atom. An EXPANDED one still traps: `flatten` recurses into
        // it, so nothing else should ever ask this for one.
        case let .blockQuote(quote) where quote.collapsed:
            return collapsedQuoteAtom(for: QuoteShape(quote), within: ancestry)
        case .table, .blockQuote, .details:
            richTextEngineUnimplemented("Block.\(block.caseNameForDiagnostics)", rung: "R7")
        }
    }

    /// The roles after an edit, by the engine's own identities: an identity in the table keeps its
    /// role, one the table has never seen is genuinely new — the engine minted it inside this edit —
    /// and arrives as a body paragraph with a fresh `BlockID`. No text is read here: a role is
    /// structure only, and what the engine holds is read when it is used.
    public func roles(for identifiers: [UUID],
                      reusingStructureOf previous: [UUID: EngineBlockRole]) -> [EngineBlockRole] {
        identifiers.map { identifier in
            // `within: []` is PROVISIONAL, not a claim that the block is top level: a fresh
            // identity has no structure yet, and `declareFreshBlocks` (settle) gives it its
            // predecessor's ancestry before anything reads it.
            previous[identifier] ?? .standalone(.paragraph(ParagraphShape(id: BlockID(UUID().uuidString))),
                                                within: [])
        }
    }

    /// The model block an engine block holds: the role's shape with its runs read back from the
    /// engine's text through the mapper the role was RENDERED with — the only one it can be read
    /// back through, since `runs(from:)` strips a font size that equals its mapper's default and
    /// pins one that does not. A secondary line is a plain paragraph; a cell's newlines come back
    /// in model form.
    internal func block(for role: EngineBlockRole, from attributed: NSAttributedString) -> Block {
        let mapper = readBackMapper(for: role)
        switch role.position {
        case let .secondary(_, line, kind):
            // A caption was rendered at `.caption`; read back at `.body` it would pin 15pt as an
            // explicit size on every run. An AUTHOR line is rendered at `.caption` too
            // (`authorLine(runs:centred:using:)`) and now keeps its runs, so it reads back there as
            // well — at `.body` its runs would carry the caption's size and colour as explicit
            // overrides. The other lines are body-sized fields.
            let style: ParagraphStyleName
            switch kind {
            case .mediaCaption, .pullQuoteAuthor, .blockQuoteAuthor: style = .caption
            case .codeLanguage, .detailsTitle: style = .body
            }
            let runs = modelRuns(readingBack: attributed, style: style, through: mapper)
            // A one-line field reads back on one line too, so no model ever holds — or sends — a line
            // break there, whatever the engine holds for a moment (an open composition) (p23).
            return .paragraph(ParagraphBlock(id: line, runs: role.isOneLineField ? Self.oneLineRuns(runs) : runs))
        case let .tableCell(table, row, column, cell):
            var runs = modelRuns(readingBack: attributed, style: .body, through: mapper)
            if table.cell(row: row, column: column)?.isHeader == true {
                // A header cell renders bold as a font trait, which is what the engine path reads bold
                // from: in a header cell bold is ambient and never the model's.
                for index in runs.indices { runs[index].attributes.bold = false }
            }
            return .paragraph(ParagraphBlock(id: cell, runs: runs))
        case let .standalone(shape):
            switch shape {
            case let .paragraph(paragraph):
                return .paragraph(paragraph.block(runs: modelRuns(readingBack: attributed, style: paragraph.style, through: mapper)))
            case .code:
                return shape.block(runs: Self.plainCodeRuns(modelRuns(readingBack: attributed, style: .body, through: mapper)))
            case .pullQuote:
                return shape.block(runs: modelRuns(readingBack: attributed, style: .pullQuote, through: mapper))
            case let .media(media):
                return .media(media.block(caption: []))
            case let .buttonRow(row):
                // The atom's text is one attachment character and carries nothing of the model, so
                // the shape IS the block — nothing to read back.
                return .buttonRow(row.block)
            case .collapsedQuote:
                // Like a row: the atom's text is one attachment character and carries nothing of
                // the model, so the shape IS the block.
                return shape.block(runs: [])
            }
        }
    }

    /// The engine's text as MODEL runs, read through `mapper` at `style`: every line separator a
    /// newline again; a formula run's text its source, which the renderer replaced with one
    /// attachment character; and the size the mapper pins on every read-back dropped when it is the
    /// size the style gives the run anyway. `nil` in the model means "the style's size", and the
    /// render size of a quote child, a cell or code must not persist as an explicit override the
    /// text would keep when moved out of its container.
    private func modelRuns(readingBack attributed: NSAttributedString, style: ParagraphStyleName,
                           through mapper: AttributedStringMapper) -> [TextRun] {
        let source = Self.withCarriedTraitsOnFallbackFaces(attributed)
        return Self.withLinkUnderlines(mapper.runs(from: source, style: style), from: source).map { run in
            var run = run
            run.text = Self.modelText(run.text)
            // An entity is never inline code too (`withoutInlineCodeOverLinks`).
            if run.attributes.link != nil { run.attributes.inlineCode = false }
            if let formula = run.attributes.formula, !formula.isEmpty, run.text == "\u{FFFC}" {
                run.text = formula
            }
            if let size = run.attributes.fontSize {
                var ambient = run.attributes
                ambient.fontSize = nil
                if abs(mapper.styleSheet.font(for: style, attributes: ambient).pointSize - CGFloat(size)) < 0.01 {
                    run.attributes.fontSize = nil
                }
            }
            return run
        }
    }

    /// The runs with an UNDERLINE on a linked run read back from the storage.
    ///
    /// The shared mapper's read-back drops underline on any run carrying a link — a rule from when a
    /// link's underline was render-derived. Nothing draws one now ("No underline: reference design
    /// shows links as accent-colored text only"), so an underline on a link is the USER's, and the
    /// engine drew it while the model — and the sent message — dropped it: Format ▸ Underline and
    /// Format ▸ Link on one word, in either order (composer harness, 2026-09-23,
    /// `HarnessLinkUnderlineTests`). Restored here rather than in the mapper, which the legacy canvas
    /// shares and whose link removal still strips `.underlineStyle`.
    ///
    /// `runs(from:)` emits exactly one run per attribute run, so the same enumeration lines up with
    /// it run for run; a count mismatch leaves the runs as they are.
    private static func withLinkUnderlines(_ runs: [TextRun], from source: NSAttributedString) -> [TextRun] {
        var ranges: [[NSAttributedString.Key: Any]] = []
        source.enumerateAttributes(in: NSRange(location: 0, length: source.length), options: []) { attributes, _, _ in
            ranges.append(attributes)
        }
        guard ranges.count == runs.count else { return runs }
        var result = runs
        for (index, attributes) in ranges.enumerated()
        where attributes[.link] != nil && ((attributes[.underlineStyle] as? Int) ?? 0) != 0 {
            result[index].attributes.underline = true
        }
        return result
    }

    /// Engine-parallel: one block per role. A role the engine has no block for yet (a transient
    /// inside a set) materialises empty, so the two arrays stay the same length.
    internal func blocks(for roles: [EngineBlockRole], from attributed: [NSAttributedString]) -> [Block] {
        roles.enumerated().map { index, role in
            index < attributed.count ? block(for: role, from: attributed[index]) : role.shape.block(runs: [])
        }
    }

    /// What the block `role` holds carries that the COMPOSER's model cannot: a text colour other than
    /// the theme's, a highlight, a font family. `ChatInputContent` has no field for any of them, so a run
    /// carrying one is drawn in the composer and not sent. The derived-presentation check cannot see it —
    /// the read-back keeps the colour, so the re-render draws it too — which is how a pasted foreign
    /// colour survived a whole fuzz sweep (composer harness p20, `HarnessPastedForeignColourTests`).
    /// Answers each offending field with its value and the start of its run; empty when clean. A check, never a trap: the article editor
    /// shares this bridge and its own sink decides what it can carry.
    internal func modelUnrepresentableFields(role: EngineBlockRole, from attributed: NSAttributedString) -> [String] {
        let block = Self.withoutCarriedPresentation(self.block(for: role, from: Self.withoutAmbientTraits(attributed)),
                                                    theme: mapper.theme)
        let runs: [TextRun]
        switch block {
        case let .paragraph(paragraph): runs = paragraph.runs
        case let .code(code): runs = code.runs
        case let .pullQuote(quote): runs = quote.runs
        case .media, .table, .blockQuote, .details, .buttonRow: runs = []
        }
        var fields: Set<String> = []
        for run in runs {
            if let c = run.attributes.foreground { fields.insert("foreground=\(c) \(run.text.prefix(12))") }
            if let c = run.attributes.highlight { fields.insert("highlight=\(c) \(run.text.prefix(12))") }
            if run.attributes.fontFamily != nil { fields.insert("fontFamily") }
        }
        return fields.sorted()
    }

    /// The engine text `role` should hold for the block it holds now — the rendering
    /// `engineRepresentation(for:)` gives that block in a document set, its text read back first.
    /// Settle applies the presentation of this to the blocks an edit touched (structure-only roles
    /// design §9): presentation is derived from the role and the model, never carried by the text.
    internal func render(role: EngineBlockRole, from attributed: NSAttributedString) -> NSAttributedString {
        let block = Self.withoutCarriedPresentation(self.block(for: role, from: Self.withoutAmbientTraits(attributed)),
                                                    theme: mapper.theme)
        switch role.position {
        case let .tableCell(table, row, column, cell):
            let source = table.cell(row: row, column: column)?.cell(blocks: []) ?? Cell(id: cell)
            return cellLine(for: source, paragraph: block.asParagraph ?? ParagraphBlock(id: cell))
        case let .secondary(_, _, kind):
            let runs = block.asParagraph?.runs ?? []
            // Nested at any depth >= 1, indented the same `quoteIndent * depth` as a standalone
            // child below — `flatten`'s `emit` applies this to every secondary line it produces
            // (`.codeLanguage`, `.pullQuoteAuthor`, `.mediaCaption`, padded first if padded at
            // all), and this must match or a touched nested line's indent is overwritten by
            // `normalisePresentation` and an untouched one drifts under `verifyPresentationIsDerived`.
            func nested(_ text: NSAttributedString) -> NSAttributedString {
                role.containerDepth > 0
                    ? Self.quoteIndented(text, by: role.contentIndent(styleSheet: mapper.styleSheet),
                                         trailing: role.contentTrailingInset(styleSheet: mapper.styleSheet))
                    : text
            }
            switch kind {
            case .codeLanguage:
                return nested(Self.padded(Self.languageLine(text: block.flatText, using: mapper),
                                          by: mapper.styleSheet.codeHorizontalInset))
            case .pullQuoteAuthor:
                return nested(Self.padded(Self.authorLine(runs: runs, centred: true, using: mapper),
                                          by: pullQuoteStyle.horizontalPadding))
            case .blockQuoteAuthor:
                return Self.quoteIndented(Self.authorLine(runs: runs, centred: false, using: mapper),
                                          by: role.contentIndent(styleSheet: mapper.styleSheet),
                                          trailing: role.contentTrailingInset(styleSheet: mapper.styleSheet))
            case .mediaCaption:
                return nested(Self.captionLine(runs: runs, using: mapper))
            case .detailsTitle:
                // The quote's size, when a quote encloses it: a title is the details' own line, and
                // a line inside a quote is 15pt whatever it is. Built with the plain mapper, as it
                // was, a quoted details wore a 17pt title above 15pt siblings.
                return Self.detailsTitleLine(runs: runs, using: role.isInsideAQuote ? quoteMapper : mapper,
                                             contentIndent: role.contentIndent(styleSheet: mapper.styleSheet),
                                             contentTrailingInset: role.contentTrailingInset(styleSheet: mapper.styleSheet))
            }
        case .standalone:
            // Text at any depth >= 1 is the quote mapper's (15pt, never rescaled) and indented one
            // quoteIndent per level (§4.2); a code child keeps its face — the code arm below ignores
            // the mapper it is handed.
            let rendered = attributedBlock(for: block, using: role.isInsideAQuote ? quoteMapper : nil,
                                           within: role.ancestry)
            return role.containerDepth > 0
                ? Self.quoteIndented(rendered, by: role.contentIndent(styleSheet: mapper.styleSheet),
                                     trailing: role.contentTrailingInset(styleSheet: mapper.styleSheet))
                : rendered
        }
    }

    /// The block with the presentation its text carried from another role dropped, so the role's
    /// own wins: the mapper pins a run's rendered size on read-back by design ("a run keeps its
    /// rendered size when moved across contexts"), which is exactly the carrying this pass undoes,
    /// and it records a foreground that is not the style's default — the other style's default,
    /// for text that came from an author line. Neither editor lets the user set a size, and a
    /// colour the theme itself paints is not the user's either.
    private static func withoutCarriedPresentation(_ block: Block, theme: RichTextEditorTheme) -> Block {
        func strip(_ runs: [TextRun]) -> [TextRun] {
            runs.map { run in
                var run = run
                run.attributes.fontSize = nil
                if let foreground = run.attributes.foreground,
                   isThemeText(foreground, theme: theme) {
                    run.attributes.foreground = nil
                }
                // The inline-code pill's fill on text that is NOT inline code is that pill's
                // presentation left behind, never a user highlight: typing or composing over a
                // selection Monospace was just applied to took the controller's typing attributes,
                // which carry the background and not the marker, so the composer drew a grey
                // highlight the model could not send (composer harness p20 fix wave, found by the
                // fuzz's model-unrepresentable check; `HarnessPastedForeignColourTests`).
                if let highlight = run.attributes.highlight, !run.attributes.inlineCode,
                   matches(highlight, [theme.inlineCodeBackground]) {
                    run.attributes.highlight = nil
                }
                return run
            }
        }
        switch block {
        case let .paragraph(paragraph):
            var stripped = paragraph
            stripped.runs = strip(paragraph.runs)
            return .paragraph(stripped)
        case let .code(code): return .code(CodeBlock(id: code.id, language: code.language, runs: strip(code.runs)))
        case let .pullQuote(quote): return .pullQuote(PullQuote(id: quote.id, runs: strip(quote.runs), author: quote.author))
        case .media, .table, .blockQuote, .details, .buttonRow: return block
        }
    }

    /// The text with each run's rendered face given back the user's bold and italic that TextKit's
    /// font fixing took from it, so the mapper's read-back (which derives italic, and here bold,
    /// from the FACE) sees them.
    ///
    /// Font fixing replaces `.font` in the engine's storage with a fallback face for text the style
    /// face cannot draw — PingFang for Chinese, an Arabic face, Apple Color Emoji — and those faces
    /// often have no italic (emoji: no bold either). The engine keeps the user's intent in its own
    /// markers (`IDInlineTextItalic` / `IDInlineTextBold`, which its trait pass and toolbar read),
    /// so the storage said italic while the model — what is sent — said plain (composer harness,
    /// 2026-09-23, `HarnessFallbackFontFormattingTests`). Only a trait a marker carries AND the
    /// rendered face lacks is restored, on the run's base face (`IDInlineTextBaseFontAttributeName`,
    /// what the engine derives the face from); a trait the base face itself carries is ambient
    /// (a header cell, an author line) and is not the marker's to restore. Runs whose face kept its
    /// traits — every non-substituted run — are left exactly as they are. The presentation verifier
    /// compares the stored face through the same restoration, or the model's (correct) italic reads
    /// as drift against a fallback face that cannot carry it.
    internal static func withCarriedTraitsOnFallbackFaces(_ source: NSAttributedString) -> NSAttributedString {
        var faces: [(NSRange, UIFont)] = []
        source.enumerateAttributes(in: NSRange(location: 0, length: source.length), options: []) { attributes, range, _ in
            guard let font = attributes[.font] as? UIFont,
                  let base = attributes[NSAttributedString.Key.IDInlineTextBaseFontAttributeName] as? UIFont else { return }
            var carried: UIFontDescriptor.SymbolicTraits = []
            if (attributes[NSAttributedString.Key.IDInlineTextBoldAttributeName] as? Bool) == true { carried.insert(.traitBold) }
            if (attributes[NSAttributedString.Key.IDInlineTextItalicAttributeName] as? Bool) == true { carried.insert(.traitItalic) }
            let emphasis: UIFontDescriptor.SymbolicTraits = [.traitBold, .traitItalic]
            let baseTraits = base.fontDescriptor.symbolicTraits
            let rendered = font.fontDescriptor.symbolicTraits.intersection(emphasis)
            let traits: UIFontDescriptor.SymbolicTraits
            if font.familyName != base.familyName {
                // A SUBSTITUTED face: its traits are the substitute's, not the run's. It is read as
                // what the engine derives the run from — the base face (whose traits are ambient: an
                // author line's emphasis, a header cell's bold, a pull quote's slant) plus the user's
                // markers — which is also what the run would wear had nothing been substituted. Kept
                // as the substitute's own, a face could ADD a trait nobody set: a heading's New York
                // Medium falls back to a BOLD face for Hebrew and Thai, and once that text left the
                // heading (a cross-block edit merged it into a body paragraph) the read-back took the
                // bold for the user's, the model gained it, and normalisation drew it bold from then
                // on (composer harness, 2026-09-23, fuzz seed 12, `HarnessSubstitutedFaceTraitTests`);
                // or LACK one it should carry: an emoji or CJK in an author line cannot be bold or
                // italic (`HarnessAuthorLineFallbackFaceTests`).
                //
                // ALWAYS replaced, even when the substitute already carries exactly the intended
                // traits: the mapper does not trust a bold SUBSTITUTED face (`boldIsAmbient` re-runs
                // the substitution on the non-bold base and calls the bold ambient when that is bold
                // too), so left as it was, Format ▸ Bold over a heading's Thai or Hebrew — whose
                // substitute is bold before and after — never reached the model, and the verifier
                // saw the bold face as drift against the unbolded model (composer harness,
                // 2026-09-23, fuzz seed 35, `HarnessHeadingFallbackBoldTests`). On the base face's
                // family the face reads as exactly what it is meant to carry.
                let intended = baseTraits.intersection(emphasis).union(carried)
                traits = baseTraits.subtracting(emphasis).union(intended)
            } else {
                let missing = carried.subtracting(baseTraits).subtracting(rendered)
                guard !missing.isEmpty else { return }
                traits = baseTraits.subtracting(emphasis).union(rendered).union(missing)
            }
            guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return }
            faces.append((range, UIFont(descriptor: descriptor, size: font.pointSize)))
        }
        guard !faces.isEmpty else { return source }
        let result = NSMutableAttributedString(attributedString: source)
        for (range, face) in faces { result.addAttribute(.font, value: face, range: range) }
        return result
    }

    /// The text with the bold and italic its BASE face carries removed from its rendered face, so the
    /// read-back does not take an ambient trait for the user's. The base face is the engine's own
    /// notion of ambient (`IDInlineTextBaseFontAttributeName`, what its trait pass derives from);
    /// the bridge stamps it bold on a header cell and emphasised on an author line, and code's is
    /// plain. Text without a base face reads as it is.
    private static func withoutAmbientTraits(_ source: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let whole = NSRange(location: 0, length: result.length)
        source.enumerateAttributes(in: whole, options: []) { attributes, range, _ in
            guard let font = attributes[.font] as? UIFont,
                  let base = attributes[NSAttributedString.Key.IDInlineTextBaseFontAttributeName] as? UIFont else { return }
            let ambient = base.fontDescriptor.symbolicTraits.intersection([.traitBold, .traitItalic])
            guard !ambient.isEmpty else { return }
            let traits = font.fontDescriptor.symbolicTraits.subtracting(ambient)
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return }
            result.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: range)
        }
        return result
    }

    private static func isThemeText(_ colour: RGBAColor, theme: RichTextEditorTheme) -> Bool {
        matches(colour, [theme.primaryText, theme.secondaryText])
    }

    private static func matches(_ colour: RGBAColor, _ candidates: [UIColor]) -> Bool {
        candidates.contains { candidate in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard candidate.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return false }
            return abs(Double(red) - colour.red) < 0.005 && abs(Double(green) - colour.green) < 0.005
                && abs(Double(blue) - colour.blue) < 0.005 && abs(Double(alpha) - colour.alpha) < 0.005
        }
    }

    /// The model document: every role materialised, then regrouped.
    public func document(for roles: [EngineBlockRole], from attributed: [NSAttributedString]) -> Document {
        EngineBlockRole.document(roles: roles, blocks: blocks(for: roles, from: attributed))
    }

    /// The mapper a role is RENDERED with — which is also the one it reads back through, so there
    /// is one answer rather than two. Internal because the list-marker pass needs it: a marker is
    /// drawn by the host beside text the bridge rendered, and a marker resolving its font from the
    /// plain mapper is 17pt beside a quote's 15pt text.
    internal func renderMapper(for role: EngineBlockRole) -> AttributedStringMapper {
        readBackMapper(for: role)
    }

    private func readBackMapper(for role: EngineBlockRole) -> AttributedStringMapper {
        // A details' title is authored text and is rendered at the quote's size inside one, so it
        // reads back through the same mapper. Every other secondary line is a field the bridge
        // re-derives, so the plain mapper stays right for those.
        if role.secondaryKind == .detailsTitle { return role.isInsideAQuote ? quoteMapper : mapper }
        if role.secondaryKind != nil { return mapper }
        if case .code = role.shape { return codeMapper }
        if role.owningTable != nil { return tableCellMapper }
        // Must track the FORWARD choice exactly, or a read-back pins a size the render never used.
        if role.isInsideAQuote { return quoteMapper }
        return mapper
    }

    /// Records each run's unstyled face in `IDInlineTextBaseFontAttributeName`, the key the engine's
    /// trait pass DERIVES bold and italic from. Writing only `.font` would be undone by the next
    /// trait toggle, exactly as it would be for inline code.
    ///
    /// This used to SUBSTITUTE the face too — `monospacedSystemFont` at whatever size the body mapper
    /// had already produced — which is what left code at 17pt system-monospace instead of 15pt Menlo:
    /// a face swap cannot reach the pinned line height, so the text was also spaced for a font it was
    /// no longer set in. The face now comes from `codeMapper`, and only the base-font stamp is left.
    /// Stripping the traits matters for the same reason the stamp does: a bold run inside code would
    /// otherwise derive its base from the BOLD face and never toggle back.
    ///
    /// It deliberately does NOT set `.rtInlineCode`: that marker is what `runs(from:)` reads back into
    /// `CharacterAttributes.inlineCode`, and a code block's runs must not come back as inline-code
    /// runs nested inside it. The monospacing here is presentation only.
    /// A pull quote's italic is AMBIENT — the `.pullQuote` style forces it at render time and the
    /// mapper's read-back strips it (`ca.italic = style == .pullQuote ? false : …`), so the model can
    /// never carry it. The engine derives the face from `IDInlineTextBaseFontAttributeName` plus its
    /// trait markers, so the italic belongs in the BASE face, as an author line's emphasis does.
    /// Stamped from the upright base with the italic kept, every trait the engine recomputes (Italic
    /// toggled off, Bold toggled on) keeps the slant the role derives. Left unstamped, the default
    /// stamp stripped the italic into an `IDInlineTextItalic` marker and Format ▸ Italic took it
    /// away — the word drawn upright while the model, and the sent message, stayed italic (composer
    /// harness, 2026-09-23, `HarnessPullQuoteInlineFormatDriftTests`).
    ///
    /// An inline-code run is left to the default stamp: the mapper renders code in a pull quote
    /// UPRIGHT (the italic is not the user's, so `ca.italic` is false there), and that is the face
    /// the legacy editor draws.
    private static func stampingAmbientItalicBaseFont(_ source: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        var stamps: [(NSRange, UIFont)] = []
        source.enumerateAttributes(in: NSRange(location: 0, length: source.length), options: []) { attributes, range, _ in
            guard (attributes[.rtInlineCode] as? Bool) != true, let font = attributes[.font] as? UIFont else { return }
            var traits = font.fontDescriptor.symbolicTraits
            guard traits.contains(.traitItalic) else { return }
            traits.remove(.traitBold)
            let base = font.fontDescriptor.withSymbolicTraits(traits)
                .map { UIFont(descriptor: $0, size: font.pointSize) } ?? font
            stamps.append((range, base))
        }
        for (range, base) in stamps {
            result.addAttribute(NSAttributedString.Key.IDInlineTextBaseFontAttributeName, value: base, range: range)
        }
        return result
    }

    private static func stampingMonospaceBaseFont(_ source: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let whole = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.font, in: whole, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            var traits = font.fontDescriptor.symbolicTraits
            traits.subtract([.traitBold, .traitItalic])
            let base = font.fontDescriptor.withSymbolicTraits(traits)
                .map { UIFont(descriptor: $0, size: font.pointSize) } ?? font
            result.addAttribute(NSAttributedString.Key.IDInlineTextBaseFontAttributeName,
                                value: base, range: range)
        }
        return result
    }

    /// A quote child's leading inset AND the trailing inset it stops short of, applied to a COPIED
    /// paragraph style so V2's pinned line geometry survives — the same rule the code block's
    /// padding follows.
    ///
    /// `tailIndent` is NEGATIVE by convention: a negative value is the distance from the container's
    /// trailing edge, which is what "stop 22pt short of the column" means, and it composes for
    /// nesting because each level subtracts its own. Legacy narrows the same way and leaves the fill
    /// full width (`BlockQuoteBox`: `inner = width - leadingInset - trailingInset`).
    ///
    /// Presentation only: the mapper never reads an indent back, so this cannot reach the model.
    private static func quoteIndented(_ source: NSAttributedString, by indent: CGFloat,
                                      trailing: CGFloat = 0) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let whole = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.paragraphStyle, in: whole, options: []) { value, range, _ in
            let base = (value as? NSParagraphStyle) ?? NSParagraphStyle.default
            guard let style = base.mutableCopy() as? NSMutableParagraphStyle else { return }
            style.firstLineHeadIndent += indent
            style.headIndent += indent
            style.tailIndent -= trailing
            result.addAttribute(.paragraphStyle, value: style, range: range)
        }
        return result
    }

    /// Restores bold that the shared mapper drops on the way to the engine.
    ///
    /// `attributes(from:)` renders an inline-code run with
    /// `monospacedSystemFont(ofSize:weight: .regular)`, flattening the user's bold. That is fine on
    /// the LEGACY path, where `.rtBold` carries the intent separately and read-back prefers it. The
    /// engine has no such marker — it writes `IDInlineTextBold` and otherwise derives bold from the
    /// RENDERED FONT — so a bold code run arrived plain, and the next read-back would then report
    /// `bold: false` and lose it from the model too.
    ///
    /// Fixed HERE rather than in the mapper on purpose: the mapper is shared, and changing what it
    /// draws would change legacy rendering for every existing user. This is the engine's own import.
    ///
    /// Italic has no equivalent marker, and needs none: since 2026-09-23 the mapper renders an italic
    /// inline-code run in the ITALIC monospace face, so the face carries it both ways
    /// (`HarnessMonospaceItalicTests` — italic on monospace text was dropped by the next edit anywhere).
    /// How the engine's rendered strings express V2's line geometry.
    ///
    /// `StyleSheet` pins `minimumLineHeight == maximumLineHeight == pitch`, and TextKit BOTTOM-ALIGNS
    /// a line inside a pinned box — so a pitch taller than the font's own line puts the difference
    /// ABOVE the line as dead space. The legacy canvas absorbs that with
    /// `BlockLayoutEngine.baselineDelta`, a render-time correction the engine has no counterpart to:
    /// it draws this string as-is. Re-expressing the same pitch as a smaller box plus a `lineSpacing`
    /// remainder moves the baseline without moving baseline-to-baseline.
    ///
    /// `.off` is today's behaviour and the rollback. See
    /// the RichTextEditor `CLAUDE.md`, "A block's FRAME is a line box; the rhythm below it is the renderer's".
    internal enum V2BaselinePlacement: Hashable {
        /// Today: the box IS the pitch; the first baseline sits `pitch - |descender|` from the top.
        case off
        /// Box = `ceil(ascender + |descender|)`. The block's height stays exactly V2's, so the
        /// rhythm is untouched; the baseline lands `ceil(fontBox) - fontBox` low.
        case safe
        /// Box = `ascender + |descender|`. The baseline is exactly V2's; the block measures
        /// `ceil(fontBox) - fontBox` short unless that is restored elsewhere.
        case exact
        /// `.exact` plus that shortfall as `paragraphSpacing`, which IS counted in the used height —
        /// exact on both axes if TextKit 2 agrees. An engine block is one paragraph by construction
        /// (`engineText` maps "\n" to U+2028), so it is applied once.
        case exactWithTrailingSpacing
    }

    internal static var v2BaselinePlacement: V2BaselinePlacement = .safe

    private static func engineReadable(_ source: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let whole = NSRange(location: 0, length: result.length)
        // Collected then applied, never written inside the walk: adding a NEW key splits runs, and a
        // walk that mutates its own subject re-enumerates what it just changed.
        var boldFaces: [(NSRange, UIFont)] = []
        result.enumerateAttributes(in: whole, options: []) { attributes, range, _ in
            guard (attributes[.rtBold] as? Bool) == true,
                  let font = attributes[.font] as? UIFont,
                  !font.fontDescriptor.symbolicTraits.contains(.traitBold) else { return }
            let wanted = font.fontDescriptor.symbolicTraits.union(.traitBold)
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(wanted) else { return }
            boldFaces.append((range, UIFont(descriptor: descriptor, size: font.pointSize)))
        }
        for (range, font) in boldFaces { result.addAttribute(.font, value: font, range: range) }
        stampInlineTraitMarkers(result)
        applyV2BaselinePlacement(result)
        return result
    }

    /// Re-expresses V2's pinned line box so TextKit lands the first baseline where V2 puts it.
    /// See `V2BaselinePlacement`. Engine-only: it runs in the bridge, not in the shared `StyleSheet`,
    /// so legacy rendering (which corrects this its own way and would then double-correct) is
    /// untouched.
    ///
    /// **The guard is `pitch > box`, and it is NOT about attachments.** A paragraph whose first run
    /// carries an explicit `CharacterAttributes.fontSize` larger than its style's
    /// (`StyleSheet.swift:84`; `RTFImport` produces these) has a font box TALLER than the pitch, which
    /// `StyleSheet.paragraphStyle` derives from the style's BASE font. `NSParagraphStyle.lineSpacing`
    /// is non-negative, so such a paragraph is skipped entirely. Do not clamp the remainder to 0 —
    /// that would grow the pin, and the pitch with it.
    private static func applyV2BaselinePlacement(_ result: NSMutableAttributedString) {
        guard v2BaselinePlacement != .off else { return }
        let whole = NSRange(location: 0, length: result.length)
        // Collected then applied, for the same reason the bold pass above collects: writing inside
        // the walk re-enumerates what it just changed.
        var restyled: [(NSRange, NSParagraphStyle)] = []
        result.enumerateAttribute(.paragraphStyle, in: whole, options: []) { value, range, _ in
            guard let pinned = value as? NSParagraphStyle,
                  // The font of the style run's FIRST character, mirroring `BlockLayoutEngine
                  // .primaryFont` — an engine block is one paragraph, so this is its font.
                  let font = result.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont,
                  let style = v2BaselinePlacedStyle(pinned, font: font)
            else { return }
            restyled.append((range, style))
        }
        for (range, style) in restyled { result.addAttribute(.paragraphStyle, value: style, range: range) }
    }

    /// The re-expression for ONE pinned paragraph style, or nil when the style is not pinned, the mode
    /// is `.off`, or the guard refuses it.
    ///
    /// **Shared by two callers, and the second one is not obvious.** `applyV2BaselinePlacement` walks a
    /// rendered block's string; `collapsedQuotePreviewAttributes` builds ONE style directly for a
    /// folded quote's preview, which is laid out by the LEGACY `BlockLayoutEngine` and so never passes
    /// through `engineReadable` at all. That preview draws at
    /// `rawFirstBaselineFromTop - firstLineBaselineFromTop` (`CollapsedQuotePreviewView`), and `raw`
    /// is measured from THIS box — so a preview left on the old pitch draws `pitch - box` below the
    /// expanded text it stands for, and a quote's text visibly jumps when you fold it. Measured at
    /// 1.0pt for a 15pt quote before this was shared, by
    /// `EngineQuoteCollapseFidelityTests.test_theFoldedTextSitsWhereTheExpandedTextSits`.
    ///
    /// **The guard is `pitch > box`, and it is NOT about attachments.** A paragraph whose first run
    /// carries an explicit `CharacterAttributes.fontSize` larger than its style's
    /// (`StyleSheet.swift:84`; `RTFImport` produces these) has a font box TALLER than the pitch, which
    /// `StyleSheet.paragraphStyle` derives from the style's BASE font. `NSParagraphStyle.lineSpacing`
    /// is non-negative, so such a paragraph is skipped entirely. Do not clamp the remainder to 0 —
    /// that would grow the pin, and the pitch with it.
    internal static func v2BaselinePlacedStyle(_ pinned: NSParagraphStyle,
                                               font: UIFont) -> NSParagraphStyle? {
        let mode = v2BaselinePlacement
        guard mode != .off,
              pinned.maximumLineHeight > 0,
              pinned.maximumLineHeight == pinned.minimumLineHeight else { return nil }
        let fontBox = font.ascender - font.descender      // `descender` is negative
        let pitch = pinned.maximumLineHeight
        let box = (mode == .safe) ? ceil(fontBox) : fontBox
        guard pitch > box, let style = pinned.mutableCopy() as? NSMutableParagraphStyle else { return nil }
        style.minimumLineHeight = box
        style.maximumLineHeight = box
        style.lineSpacing = pitch - box
        if mode == .exactWithTrailingSpacing { style.paragraphSpacing += ceil(fontBox) - fontBox }
        return style
    }

    /// Writes the engine's OWN trait markers for what the shared mapper rendered.
    ///
    /// `IDInlineTextStyleResolver.traitsInAttributes:` reads `IDInlineTextBold` / `Italic` /
    /// `Underline` / `Strikethrough` **and nothing else** — it does not derive state from the rendered
    /// font (`baseFontForAttributes:` picks the base FACE, which is a different question, and is what
    /// this file's older comment was describing). The mapper emits the DERIVED form and none of those
    /// markers, so before this every trait reported `off` for text that arrived through a document set
    /// — a reopened draft, a paste, the composer seeding content.
    ///
    /// The measured consequences, worst first: the model and the render DIVERGED (un-bolding left
    /// `bold: true` in the document while the face went regular, so the message would send bold while
    /// the editor showed plain); un-bolding took two presses, the first writing the marker and
    /// recomputing the identical face; and the toolbar showed Bold unlit over visibly bold text.
    ///
    /// It ADDS keys and moves nothing rendered: `.font`, `.underlineStyle` and `.strikethroughStyle`
    /// already equal what the engine derives from these markers, so they are left as the mapper wrote
    /// them. And it runs INSIDE the render path, so `render(role:from:)` and the stored block produce
    /// the same string and `verifyPresentationIsDerived` cannot drift.
    private static func stampInlineTraitMarkers(_ result: NSMutableAttributedString) {
        var stamps: [(NSRange, [NSAttributedString.Key: Any])] = []
        result.enumerateAttributes(in: NSRange(location: 0, length: result.length),
                                   options: []) { attributes, range, _ in
            guard let font = attributes[.font] as? UIFont else { return }
            let traits = font.fontDescriptor.symbolicTraits
            var added: [NSAttributedString.Key: Any] = [:]
            // From `.rtBold` ALONE, never from the rendered face. The face is bold for reasons that
            // are not the user's: a pull quote's AUTHOR line and a code block's LANGUAGE line are
            // style-bold, and the system "Bold Text" setting forces the trait onto substituted
            // scripts. That is the whole reason `.rtBold` exists. Deriving from the face instead
            // stamped a marker the re-render could not reproduce, and `verifyPresentationIsDerived`
            // trapped on every pull quote with `RTBold` as the drifting key.
            if (attributes[.rtBold] as? Bool) == true {
                added[.IDInlineTextBoldAttributeName] = true
            }
            // Italic from the face, EXCEPT an italic the base face already carries: that one is
            // ambient (a pull quote's body, its author line) and the marker is the user's. Stamped
            // anyway, the engine reported Italic lit over a pull quote and its toggle took the
            // user's marker away from text whose slant was never theirs.
            let baseIsItalic = (attributes[.IDInlineTextBaseFontAttributeName] as? UIFont)?
                .fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
            if traits.contains(.traitItalic), !baseIsItalic { added[.IDInlineTextItalicAttributeName] = true }
            // Nothing renders a link underlined, so an underline on a linked run is the user's and
            // carries the marker like any other (`withLinkUnderlines` reads it back).
            if ((attributes[.underlineStyle] as? Int) ?? 0) != 0 {
                added[.IDInlineTextUnderlineAttributeName] = true
            }
            if ((attributes[.strikethroughStyle] as? Int) ?? 0) != 0 {
                added[.IDInlineTextStrikethroughAttributeName] = true
            }
            // The base face is what the engine derives from, and its traits MUST be stripped or a bold
            // run derives its base from the bold face and can never toggle back — the rule
            // `stampingMonospaceBaseFont` states for code. That one runs FIRST on the code path, so an
            // already-stamped base is left alone rather than recomputed from a face it deliberately
            // replaced.
            if attributes[.IDInlineTextBaseFontAttributeName] == nil {
                let stripped = traits.subtracting([.traitBold, .traitItalic])
                added[.IDInlineTextBaseFontAttributeName] = font.fontDescriptor
                    .withSymbolicTraits(stripped)
                    .map { UIFont(descriptor: $0, size: font.pointSize) } ?? font
            }
            if !added.isEmpty { stamps.append((range, added)) }
        }
        for (range, added) in stamps {
            for (key, value) in added { result.addAttribute(key, value: value, range: range) }
        }
        // `.rtBold` is REMOVED once its fact is carried by the engine's own marker, so engine storage
        // holds exactly ONE bold representation.
        //
        // Keeping both meant they could disagree, and they did: the engine's toggle rewrites its
        // marker and recomputes the face but never touches `.rtBold`, so un-bolding loaded text left
        // the document reading `bold: true` while the face went regular. Reconciling on the way back
        // instead was tried and rejected — `setAllowedTypingAttributeNames:` admits the engine's four
        // traits and not a host marker, so a typed character carries one and not the other, and the
        // re-render then disagreed with storage on `RTBold` for every edited author line.
        //
        // Safe because this is precisely the "marker-less storage" case the mapper's read-back is
        // written for: it falls back to the ambient-stripped `.traitBold`, whose `boldIsAmbient` check
        // is what keeps the system "Bold Text" setting from leaking bold into the model. The engine
        // keeps that face in lockstep with its marker, so the fallback reads the engine's answer.
        result.removeAttribute(.rtBold, range: NSRange(location: 0, length: result.length))
    }

    /// A code block's language line: bold sans at the BODY size, lowercased — the same derivation
    /// `CodeBlockBox.languageLine` uses, so the two editors render it identically.
    ///
    /// Lowercased HERE rather than at draw time, which means the model keeps whatever case the user
    /// typed and only the display is normalised — until the line is read back, at which point the
    /// lowercased text IS what was authored. That matches the legacy editor, whose language line is
    /// likewise the authored text.
    // MARK: - Tables

    /// A cell's newline. The engine raises on an interior `U+000A` — that IS its block separator —
    /// so inside the engine a cell's newline is LINE SEPARATOR, which TextKit wraps at and the
    /// engine never splits on. The model keeps `\n`; these two are the only crossing points.
    internal static let lineSeparator = "\u{2028}"

    /// A body's text as the engine holds it: every paragraph break a line separator. CR, CRLF, `U+2029` and NEL
    /// are paragraph breaks first (Core `normalisedLineBreaks`, the one normaliser of every door): the render is
    /// the SET's door, and a CR kept here stayed in the model as `U+000D`, was sent, and made the tokenizer's
    /// paragraph boundaries disagree with the rest of `UITextInput` (composer harness p24,
    /// `HarnessSetCarriageReturnTests`). The read-back gives "\n", so the set is reported to the chat.
    internal static func engineText(_ text: String) -> String {
        normalisedLineBreaks(text).replacingOccurrences(of: "\n", with: lineSeparator, options: .literal)
    }

    internal static func modelText(_ text: String) -> String {
        text.replacingOccurrences(of: lineSeparator, with: "\n")
    }

    /// No run is inline code AND a link — a mention, a date and a URL are all links in this model. The
    /// platform's nesting rule (Bot API "Formatting options": bold, italic, underline, strikethrough and
    /// spoiler nest with anything except `pre` / `code`; no other entity contains another) does not let a
    /// `Code` entity overlap a `MentionName`, `FormattedDate` or `TextUrl`, so a composer showing a monospaced
    /// mention sent one the server normalises (composer harness p23, `HarnessInlineCodeOverEntityTests`).
    /// The COMMANDS refuse to make one, as legacy does (Monospace over a range holding a link, Link over a
    /// range holding inline code: `inlineTargetsHold`). Content that arrives with both — a set, a paste, an
    /// external pasteboard's monospaced link — keeps the ENTITY and drops the inline code: the entity carries
    /// data (a user, a date, a URL), the code is a face. Applied on render and on read-back, so settle's
    /// presentation pass (`.rtInlineCode` is a presentation key) takes the marker off whatever an edit left.
    internal static func withoutInlineCodeOverLinks(_ runs: [TextRun]) -> [TextRun] {
        guard runs.contains(where: { $0.attributes.inlineCode && $0.attributes.link != nil }) else { return runs }
        return runs.map { run in
            guard run.attributes.inlineCode, run.attributes.link != nil else { return run }
            var run = run
            run.attributes.inlineCode = false
            return run
        }
    }

    /// `withoutInlineCodeOverLinks` over every run of `blocks`, containers, captions, authors and cells included.
    internal static func withoutInlineCodeOverLinks(_ blocks: [Block]) -> [Block] {
        return blocks.map { block in
            switch block {
            case var .paragraph(paragraph):
                paragraph.runs = withoutInlineCodeOverLinks(paragraph.runs)
                return .paragraph(paragraph)
            case var .pullQuote(quote):
                quote.runs = withoutInlineCodeOverLinks(quote.runs)
                quote.author = withoutInlineCodeOverLinks(quote.author)
                return .pullQuote(quote)
            case var .blockQuote(quote):
                quote.children = withoutInlineCodeOverLinks(quote.children)
                quote.author = withoutInlineCodeOverLinks(quote.author)
                return .blockQuote(quote)
            case var .details(details):
                details.title = withoutInlineCodeOverLinks(details.title)
                details.children = withoutInlineCodeOverLinks(details.children)
                return .details(details)
            case var .media(media):
                media.caption = withoutInlineCodeOverLinks(media.caption)
                return .media(media)
            case var .table(table):
                for r in table.rows.indices {
                    for c in table.rows[r].cells.indices {
                        table.rows[r].cells[c].blocks = withoutInlineCodeOverLinks(table.rows[r].cells[c].blocks)
                    }
                }
                return .table(table)
            case .code, .buttonRow:
                return block
            }
        }
    }

    /// Text as a ONE-LINE field holds it (a code block's language, a details title, a quote's or pull
    /// quote's author): every run of whitespace that contains a line break — `"\n"`, CR, CRLF, `U+2028`,
    /// `U+2029`, NEL, every `Character.isNewline` — becomes one space, which is what a stock
    /// `UITextField` does with a newline, so "123 Main St⏎City" keeps its word boundary (composer harness
    /// p12, `HarnessSingleLineFieldNewlineTests`). A run collapses to ONE space because a blank line or an
    /// indented continuation is layout of the text it came from, not two word boundaries.
    ///
    /// The ONE rule for these fields, on every door: the render (`languageLine`, `authorLine`,
    /// `detailsTitleLine` — a set, an edit load, a re-render), the surface gate (typed and replaced text,
    /// the chat's inserts), a paste or a drop, and settle's repair of a composition's commit. Before p23 the
    /// render kept a language's and an author's "\n" RAW — the engine's block separator — and the gate
    /// flattened only text containing "\n", so a `U+2028` typed into one read back as "\n" and the next
    /// render split the line (`HarnessNewlineInOneLineFieldCrashTests`).
    internal static func oneLineText(_ text: String) -> String {
        guard text.contains(where: { $0.isNewline }) else { return text }
        var result = ""
        var pendingWhitespace = ""
        var runHasNewline = false
        for character in text {
            if character.isNewline {
                runHasNewline = true
                pendingWhitespace.append(character)
            } else if character.isWhitespace {
                pendingWhitespace.append(character)
            } else {
                result += runHasNewline ? " " : pendingWhitespace
                pendingWhitespace = ""
                runHasNewline = false
                result.append(character)
            }
        }
        result += runHasNewline ? " " : pendingWhitespace
        return result
    }

    /// `oneLineText` over a one-line field's runs, run by run (a run's attributes stay its own).
    internal static func oneLineRuns(_ runs: [TextRun]) -> [TextRun] {
        runs.map { TextRun(text: oneLineText($0.text), attributes: $0.attributes) }
    }

    /// A body's runs as the engine holds them: every newline a line separator. A code block and a
    /// pull quote are multi-line bodies in ONE engine block; a raw U+000A in their runs split them
    /// into several engine blocks the roles knew nothing about (measured: a code block "a\nb"
    /// rendered as two blocks while the document still read "a\nb").
    internal static func engineRuns(_ runs: [TextRun]) -> [TextRun] {
        runs.map { TextRun(text: engineText($0.text), attributes: $0.attributes) }
    }

    /// A pull quote's runs as the engine renders them: `engineRuns` with every run's ITALIC cleared.
    /// A pull quote's slant is the role's and the read-back strips italic there
    /// (`ca.italic = style == .pullQuote ? false : …`), so an italic a model run still carries — text
    /// made a pull quote by Format ▸ Pull Quote keeps its runs' attributes — must not render either.
    /// For plain text it made no visible difference (the style is italic anyway); for an INLINE-CODE
    /// run, whose face the role composes upright, the mapper drew it monospaced italic, the read-back
    /// dropped the italic, and the block drifted on NSFont against its own re-render from then on
    /// (composer harness, 2026-09-23, fuzz seed 5 — the conversion twin of
    /// `HarnessPullQuoteItalicOverCodeTests`).
    internal static func pullQuoteRuns(_ runs: [TextRun]) -> [TextRun] {
        engineRuns(runs).map { run in
            var run = run
            run.attributes.italic = false
            return run
        }
    }

    /// A code block's runs as this editor holds them: no inline format and no link — bold, italic,
    /// underline, strikethrough, inline code, spoiler and `link` cleared, text and atoms kept.
    ///
    /// A code block is plain text wherever it goes: on the text route it is a `Pre` entity, which
    /// can contain no other entity, the shared decoder reads a code region back as one plain run,
    /// and the legacy composer's model holds it plain. Formats the engine let the user apply inside
    /// code were drawn and kept in the model, then dropped by the send — or sent after all when a
    /// heading elsewhere took the message onto the rich route (composer harness p20,
    /// `HarnessSendPathCodeFormattingTests`). Applied on render AND read-back, so a set of formatted
    /// code, a paste into code and a move into code all come out plain on screen and in the model;
    /// the inline commands refuse code too (`inlineFormatTargetRanges`).
    ///
    /// An INLINE ATOM there is its text, as Core `runsPlainText` gives it (a custom emoji its alt text, a
    /// formula its LaTeX, a pill its label): every user path already put the text there (p16 Format ▸ Code,
    /// p21's emoji keyboard into code), but a SET kept the atom — drawn in the code block while the text route
    /// sent the plain emoji (composer harness p24, `HarnessAtomInSetCodeBodyTests`). Render and read-back
    /// agree because both come through here.
    internal static func plainCodeRuns(_ runs: [TextRun]) -> [TextRun] {
        runs.compactMap { run in
            var attributes = run.attributes
            attributes.bold = false
            attributes.italic = false
            attributes.underline = false
            attributes.strikethrough = false
            attributes.inlineCode = false
            attributes.spoiler = false
            attributes.link = nil
            var text = run.text
            if attributes.emoji != nil || attributes.formula != nil || attributes.button != nil {
                text = runsPlainText([run])
                attributes.emoji = nil
                attributes.formula = nil
                attributes.button = nil
                if text.isEmpty { return nil }
            }
            return TextRun(text: text, attributes: attributes)
        }
    }

    internal static func modelRuns(_ runs: [TextRun]) -> [TextRun] {
        runs.map { TextRun(text: modelText($0.text), attributes: $0.attributes) }
    }

    internal static func engineParagraph(_ paragraph: ParagraphBlock) -> ParagraphBlock {
        var engine = paragraph
        engine.runs = engineRuns(paragraph.runs)
        return engine
    }

    /// One paragraph for a cell, in MODEL form: paragraphs joined by `\n`, containers contributing
    /// their inline runs. On the wire a cell is one inline text; nothing beyond that was ever sent.
    internal static func cellParagraph(for cell: Cell) -> ParagraphBlock {
        var runs: [TextRun] = []
        for (index, block) in cell.blocks.enumerated() {
            if index > 0 { runs.append(TextRun(text: "\n")) }
            switch block {
            case let .paragraph(paragraph): runs += paragraph.runs
            case let .code(code): runs += code.runs
            case let .pullQuote(quote): runs += quote.runs
            case let .blockQuote(quote):
                runs += quote.children.flatMap { $0.asParagraph?.runs ?? [] }
            case .media, .table, .details, .buttonRow: break
            }
        }
        return ParagraphBlock(id: cell.id, runs: runs)
    }

    private static func aligned(_ source: NSAttributedString, to alignment: TextAlignment) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let whole = NSRange(location: 0, length: result.length)
        let target: NSTextAlignment
        switch alignment {
        case .left: target = .left
        case .center: target = .center
        case .right: target = .right
        case .justified: target = .justified
        case .natural: target = .natural
        }
        result.enumerateAttribute(.paragraphStyle, in: whole) { value, range, _ in
            let base = (value as? NSParagraphStyle) ?? NSParagraphStyle.default
            guard let style = base.mutableCopy() as? NSMutableParagraphStyle else { return }
            style.alignment = target
            result.addAttribute(.paragraphStyle, value: style, range: range)
        }
        return result
    }

    /// Header bold is a FONT TRAIT only — not the mapper's `.rtBold` marker, which is what reads
    /// back — so it renders bold and never reaches the model. Display-only by the mapper's own rule.
    private static func emboldened(_ source: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let whole = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.font, in: whole) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let traits = font.fontDescriptor.symbolicTraits.union(.traitBold)
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return }
            let bold = UIFont(descriptor: descriptor, size: font.pointSize)
            result.addAttribute(.font, value: bold, range: range)
            // AMBIENT: the base face the engine derives user traits from is itself bold, so neither
            // the engine's trait state nor `render(role:from:)`'s read-back takes it for the user's.
            // The base carries the bold and ONLY the bold — the author line's rule. The user's own
            // italic stays out of it, as the engine keeps it (its trait pass puts a toggled italic in
            // the marker and leaves the base alone); stamped from the rendered face, an italic header
            // run rendered a base the engine never holds, and Format ▸ Italic over a header cell
            // drifted on `IDInlineTextBaseFont` (composer harness, 2026-09-23, fuzz seeds 5 and 17,
            // `HarnessTableHeaderItalicTests`).
            let baseTraits = font.fontDescriptor.symbolicTraits.subtracting([.traitBold, .traitItalic]).union(.traitBold)
            let base = font.fontDescriptor.withSymbolicTraits(baseTraits)
                .map { UIFont(descriptor: $0, size: font.pointSize) } ?? bold
            result.addAttribute(NSAttributedString.Key.IDInlineTextBaseFontAttributeName, value: base, range: range)
        }
        return result
    }

    private func cellLine(for cell: Cell, paragraph: ParagraphBlock) -> NSAttributedString {
        let engineParagraph = ParagraphBlock(id: paragraph.id,
                                             runs: paragraph.runs.map { run in
                                                 TextRun(text: Self.engineText(run.text), attributes: run.attributes) })
        var rendered = Self.engineReadable(tableCellMapper.attributedString(for: engineParagraph))
        rendered = Self.aligned(rendered, to: cell.horizontalAlignment)
        if cell.isHeader { rendered = Self.emboldened(rendered) }
        return rendered
    }

    /// The language AS STORED. It used to be rendered lowercased, and the line is also what the
    /// language is read back from, so every render wrote the lowercased text back as the user's value:
    /// opening an edited message turned `Swift` into `swift`, and undo / redo of typing in the line
    /// lowercased what was typed (composer harness p13, `HarnessCodeLanguageRedoTests`). The editor's
    /// rule is that the value is the user's; only highlighting normalises it
    /// (`richTextNormalizedCodeLanguage`, which lowercases on its own).
    private static func languageLine(for code: CodeBlock,
                                     using mapper: AttributedStringMapper) -> NSAttributedString {
        languageLine(text: code.language ?? "", using: mapper)
    }

    /// The line as typed: normalisation keeps the characters and only re-derives the face.
    ///
    /// **It carries the body paragraph style**, which every other line in the editor gets from the
    /// mapper and this one was built without. Without it the line has no pinned box at all, so its
    /// height is TextKit's raw font box — measured 20.2871 where every other body line is 21 — which
    /// is off the V2 pitch and off the pixel grid, and it pushed the whole code block and everything
    /// below it onto fractional origins. Taken from the style sheet rather than pinned by hand so
    /// there is one definition of the body box.
    private static func languageLine(text: String, using mapper: AttributedStringMapper) -> NSAttributedString {
        let size = mapper.styleSheet.metrics.body.size
        return Self.engineReadable(NSAttributedString(string: oneLineText(text), attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: mapper.theme.primaryText,
            .paragraphStyle: mapper.styleSheet.paragraphStyle(for: .body, attributes: ParagraphAttributes()),
            NSAttributedString.Key.IDInlineTextBaseFontAttributeName:
                UIFont.systemFont(ofSize: size, weight: .semibold),
        ]))
    }

    /// A pull quote's author line: the `.caption` style rendered bold + ITALIC and centred, matching
    /// `PullQuoteBox`'s own author layout. The emphasis is render-only and never read back — see
    /// `PullQuote.author`.
    /// The ONE block that may be internally empty: a bare body paragraph. Everything else — a
    /// table, a code block, a media atom, a button row, a container — is explicitly always
    /// non-empty, because it is structure somebody added rather than an absence of text.
    ///
    /// The role-side spelling of this is `ContainerContents.isEmpty`, which asks it of each child
    /// UNIT (`shape.paragraph != nil && flatLength == 0`); this is the same question asked of a
    /// model block, for the passes that run before there are any roles. A list item is a paragraph
    /// here as it is there — an empty one is an empty line, whatever marker it wears.
    internal static func isEmptyBodyParagraph(_ block: Block) -> Bool {
        guard case let .paragraph(paragraph) = block else { return false }
        return paragraph.runs.allSatisfy { $0.text.isEmpty }
    }

    private static func authorLine(runs: [TextRun], centred: Bool,
                                   using mapper: AttributedStringMapper) -> NSAttributedString {
        let paragraph = ParagraphBlock(id: BlockID(UUID().uuidString),
                                       style: .caption,
                                       paragraph: ParagraphAttributes(
                                           alignment: centred ? .center : .natural),
                                       runs: oneLineRuns(runs))
        let rendered = NSMutableAttributedString(attributedString:
            mapper.attributedString(for: paragraph))
        let whole = NSRange(location: 0, length: rendered.length)
        // A pull quote's author is bold + ITALIC, a block quote's just bold — `PullQuoteBox` and
        // `BlockQuoteBox` differ, and the slant is what distinguishes them.
        let emphasis: UIFontDescriptor.SymbolicTraits = centred ? [.traitBold, .traitItalic] : [.traitBold]
        rendered.enumerateAttribute(.font, in: whole, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let traits = font.fontDescriptor.symbolicTraits.union(emphasis)
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return }
            let emphasised = UIFont(descriptor: descriptor, size: font.pointSize)
            rendered.addAttribute(.font, value: emphasised, range: range)
            // AMBIENT, as a header cell's bold is: the base face carries the emphasis — and ONLY
            // the emphasis. The user's own italic on a run stays out of it, as the engine keeps it
            // (its trait pass puts a toggled italic in the marker and leaves the base alone), or a
            // block-quote author with an italic run rendered a base the engine never holds: Italic
            // over a quote's author line drifted on `IDInlineTextBaseFont` (composer harness,
            // 2026-09-23, fuzz seed 20, `HarnessAuthorLineItalicTests`).
            let baseTraits = font.fontDescriptor.symbolicTraits.subtracting([.traitBold, .traitItalic]).union(emphasis)
            let base = font.fontDescriptor.withSymbolicTraits(baseTraits)
                .map { UIFont(descriptor: $0, size: font.pointSize) } ?? emphasised
            rendered.addAttribute(NSAttributedString.Key.IDInlineTextBaseFontAttributeName, value: base, range: range)
        }
        return Self.engineReadable(rendered)
    }

    // MARK: - Media

    /// The atom's face. One point, so the line box is the attachment's own height plus a descent
    /// too small to see (P3): a real font would add its descender below every image.
    internal static let mediaAtomFont = UIFont.systemFont(ofSize: 1)

    /// One attachment character. The paragraph's alignment is the shape's, so TextKit places a
    /// narrower single image the way `MediaBlockBox.mediaRect` does.
    ///
    /// `ancestry` is the atom's own: the attachment carries the head indent its line is laid out
    /// with, because TextKit 2 proposes the FULL container width regardless of it (probe P1, measured;
    /// nesting design §4.4). An ANCESTRY rather than a depth, because the indent is the sum of what
    /// each container contributes and a details contributes nothing (R7-details spec §3.4).
    internal func mediaAtom(for shape: MediaShape, within ancestry: [EngineAncestor] = []) -> NSAttributedString {
        let atom = NSMutableAttributedString(attachment: mediaAttachment(for: shape, within: ancestry))
        atom.addAttributes(mediaAtomAttributes(for: shape, within: ancestry), range: NSRange(location: 0, length: atom.length))
        return atom
    }

    /// Whether rows draw their "…" control — stamped from whether a host is listening. It is part of
    /// the MEASUREMENT, not only the drawing: a row that shows no control reserves no width for one,
    /// so composer pills match the sent message exactly rather than being needlessly narrower.
    internal var showsButtonRowMenuAffordance: Bool = false

    /// A button row's atom. The ONE place a `ButtonRowTextAttachment` is built, so the atom's string
    /// and the attributes a menu verb merges over it can never disagree.
    internal func buttonRowAtom(for shape: ButtonRowShape,
                                within ancestry: [EngineAncestor] = []) -> NSAttributedString {
        let atom = NSMutableAttributedString(attachment: buttonRowAttachment(for: shape, within: ancestry))
        atom.addAttributes(buttonRowAtomAttributes(for: shape, within: ancestry),
                           range: NSRange(location: 0, length: atom.length))
        return atom
    }

    /// The atom's attributes alone — what a host command writes onto a freshly inserted `U+FFFC`.
    ///
    /// The FONT and PARAGRAPH STYLE are pinned here, not merely the attachment, and that is
    /// load-bearing for the same reason it is on the media atom: a rendered atom is built from
    /// `NSAttributedString(attachment:)` and carries no typography, while an inserted one is a
    /// `U+FFFC` typed into the engine and carries the ambient TYPING attributes. Pin only the
    /// attachment and the two disagree on `.font` the moment a row is inserted rather than rendered
    /// — which is exactly what `verifyPresentationIsDerived` trapped on, correctly, the first time
    /// this shipped without them.
    ///
    /// One point of face, like the media atom's: the line box is then the attachment's own height
    /// plus a descent too small to see, where a real font would add its descender under every row.
    /// A fresh paragraph style, because a row's ALIGNMENT is the packer's business inside the hosted
    /// view and never the line's — unlike media, whose alignment does travel here.
    internal func buttonRowAtomAttributes(for shape: ButtonRowShape,
                                          within ancestry: [EngineAncestor]) -> [NSAttributedString.Key: Any] {
        [
            .attachment: buttonRowAttachment(for: shape, within: ancestry),
            .paragraphStyle: NSMutableParagraphStyle(),
            .font: Self.mediaAtomFont,
        ]
    }

    /// A folded quote's atom. The ONE place a `CollapsedQuoteTextAttachment` is built, so the atom's
    /// string and any attributes merged over it can never disagree.
    internal func collapsedQuoteAtom(for shape: QuoteShape,
                                     within ancestry: [EngineAncestor] = []) -> NSAttributedString {
        let atom = NSMutableAttributedString(attachment: collapsedQuoteAttachment(for: shape, within: ancestry))
        atom.addAttributes(collapsedQuoteAtomAttributes(for: shape, within: ancestry),
                           range: NSRange(location: 0, length: atom.length))
        return atom
    }

    /// The atom's attributes alone.
    ///
    /// The FONT and PARAGRAPH STYLE are pinned here and not merely the attachment, R9-buttons'
    /// recorded lesson: a RENDERED atom comes from `NSAttributedString(attachment:)` and carries no
    /// typography, while an INSERTED one is a `U+FFFC` carrying the ambient typing attributes. Pin
    /// only the attachment and `verifyPresentationIsDerived` traps the moment one is inserted.
    ///
    /// One point of face, like the other two atoms': the line box is then the attachment's own
    /// height plus a descent too small to see. A fresh paragraph style, because a folded quote's
    /// content alignment is the preview view's business and never the line's — `emit` still adds the
    /// ENCLOSING containers' indent to it, which is what a nested folded quote needs.
    internal func collapsedQuoteAtomAttributes(for shape: QuoteShape,
                                               within ancestry: [EngineAncestor]) -> [NSAttributedString.Key: Any] {
        [
            .attachment: collapsedQuoteAttachment(for: shape, within: ancestry),
            .paragraphStyle: NSMutableParagraphStyle(),
            .font: Self.mediaAtomFont,
        ]
    }

    /// The preview's face: the quote mapper's body (15pt at every depth — assign, never multiply),
    /// the theme's primary text, WRAPPING. `BlockQuoteBox.previewAttributes(mapper:)`'s recipe, and
    /// the reason it takes the style from the sheet rather than building one is that the sheet's
    /// pinned line box IS the pitch the cap counts.
    ///
    /// **The truncation is deliberately NOT here — it is the layout container's**
    /// (`BlockLayoutEngine.capLines`). A truncating mode in the PARAGRAPH STYLE beats the container
    /// in both text systems that read this string, and beats it by collapsing the text to a single
    /// line however long it is: `boundingRect` measures one line (which is why
    /// `CollapsedQuoteTextAttachment.measuring` exists), and TextKit lays out one line even with
    /// `maximumNumberOfLines` set to three — measured 19.0pt against the 57.0pt the same string
    /// gives when the style wraps and the container truncates. That second half is what a device
    /// pass reported as "the height of a collapsed quote is correct, but it only displays one line,
    /// ellipsized, instead of 3". Truncation is a property of the BOX the text is poured into, not
    /// of the text; spelled on the text it silently becomes a line cap of one.
    internal var collapsedQuotePreviewAttributes: [NSAttributedString.Key: Any] {
        let base = quoteMapper.styleSheet.paragraphStyle(for: .body, attributes: .default)
        let style = (base.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let font = quoteMapper.styleSheet.font(for: .body, attributes: .plain)
        // The SAME re-expression a rendered block gets. This string never passes through
        // `engineReadable` — it is laid out by the legacy `BlockLayoutEngine` — but the preview's draw
        // origin is `rawFirstBaselineFromTop - firstLineBaselineFromTop`, and `raw` is measured from
        // this box. Left on the old pitch the folded text sits `pitch - box` below the expanded text
        // it stands for, so a quote's text jumps when you fold it. See `v2BaselinePlacedStyle`.
        let placed = Self.v2BaselinePlacedStyle(style, font: font) ?? style
        return [.font: font,
                .foregroundColor: quoteMapper.theme.primaryText,
                .paragraphStyle: placed]
    }

    /// The folded body as ONE wrapped run, with its formatting intact.
    ///
    /// Built through `quoteMapper`, so every run keeps bold, italic, underline, strikethrough,
    /// inline code, link and colour — and so a custom emoji keeps the `EmojiTextAttachment` the
    /// preview hosts a view over. `blockPlainText`, which this replaces, threw all of that away and
    /// additionally leaked spoilered text as plain characters.
    ///
    /// Blocks are joined by exactly one space AT the join rather than by replacing newlines in a
    /// finished string: a run's own text is never rewritten, which is what keeps its attributes
    /// aligned to its characters.
    internal func collapsedQuotePreviewText(for children: [Block]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in children {
            let piece = collapsedQuotePreviewPiece(for: child)
            guard piece.length > 0 else { continue }
            if result.length > 0 {
                result.append(NSAttributedString(string: " ", attributes: collapsedQuotePreviewAttributes))
            }
            result.append(piece)
        }
        // The preview's paragraph style over the WHOLE run: the mapper gives each piece its own
        // block's style, and a preview is one wrapped line whatever it came from.
        if let style = collapsedQuotePreviewAttributes[.paragraphStyle] {
            result.addAttributes([.paragraphStyle: style],
                                 range: NSRange(location: 0, length: result.length))
        }
        return result
    }

    /// One block's contribution. Text blocks give their runs; a block with no text of its own gives
    /// one marker attachment (`CollapsedQuoteMarkers`).
    private func collapsedQuotePreviewPiece(for block: Block) -> NSAttributedString {
        switch block {
        case let .paragraph(paragraph):
            return quoteMapper.attributedString(for: ParagraphBlock(
                id: paragraph.id, style: .body, runs: paragraph.runs))
        case let .code(code):
            return quoteMapper.attributedString(for: ParagraphBlock(id: code.id, style: .body, runs: code.runs))
        case let .pullQuote(pull):
            return quoteMapper.attributedString(for: ParagraphBlock(id: pull.id, style: .body, runs: pull.runs))
        case let .blockQuote(inner):
            // A nested quote's text is a thing that was said, so it contributes it — as the plain
            // walk did. Its own fold state is irrelevant here: this preview is already the fold.
            return collapsedQuotePreviewText(for: inner.children)
        case let .details(details):
            return collapsedQuotePreviewText(for: details.children)
        case .media, .table, .buttonRow:
            // A block with no text of its own says it is THERE. Dropping it silently reads as
            // content loss: the quote looks shorter than it is.
            return CollapsedQuoteMarkers.marker(for: block, attributes: collapsedQuotePreviewAttributes)
        }
    }

    private func collapsedQuoteAttachment(for shape: QuoteShape,
                                          within ancestry: [EngineAncestor]) -> CollapsedQuoteTextAttachment {
        CollapsedQuoteTextAttachment(
            shape: shape,
            horizontalIndent: Self.atomHorizontalReduction(within: ancestry, styleSheet: mapper.styleSheet),
            leadingInset: mapper.styleSheet.quoteIndent,
            trailingInset: mapper.styleSheet.quoteTrailingInset,
            previewText: collapsedQuotePreviewText(for: shape.foldedChildren),
            attributes: collapsedQuotePreviewAttributes)
    }

    private func buttonRowAttachment(for shape: ButtonRowShape,
                                     within ancestry: [EngineAncestor]) -> ButtonRowTextAttachment {
        ButtonRowTextAttachment(
            shape: shape,
            horizontalIndent: Self.atomHorizontalReduction(within: ancestry, styleSheet: mapper.styleSheet),
            showsMenuAffordance: showsButtonRowMenuAffordance,
            mapper: mapper)
    }

    /// The one place a `MediaTextAttachment` is built, so the atom's string and the attributes a ••• verb
    /// merges over it can never disagree about either number.
    ///
    /// **Inside a quote the bleed is 0, decided HERE rather than in the attachment's arithmetic** —
    /// legacy makes the same call at the same place (`BlockQuoteBox` builds every nested child box with
    /// `horizontalBleed: 0`), and it is simply the true value: the hosted view does not bleed at depth
    /// ≥ 1 (`syncMediaViews`), so the medium's canvas IS its drawn width. Leaving the style's bleed on
    /// would be invisible in the width — `MediaSlotGeometry` derives the HEIGHT from `line + bleed × 2`
    /// and `slot` clamps the width back to `line` — and would reserve height the medium never fills
    /// (163 rather than 147 for a 1000×500 photo drawn 294pt wide), growing the quote's band with it.
    private func mediaAttachment(for shape: MediaShape, within ancestry: [EngineAncestor]) -> MediaTextAttachment {
        // Inside ANY container the bleed is 0 — legacy makes the same call for both kinds
        // (`BlockQuoteBox` and `DetailsBox` each build their children with `horizontalBleed: 0`).
        MediaTextAttachment(shape: shape,
                            horizontalBleed: ancestry.isEmpty ? mediaBlockStyle.horizontalBleed : 0,
                            horizontalIndent: Self.atomHorizontalReduction(within: ancestry, styleSheet: mapper.styleSheet))
    }

    /// How much narrower than the PROPOSED fragment an atom's column is inside `ancestry`: the
    /// containers' leading indent PLUS their trailing inset.
    ///
    /// Probe P1 answered "full fragment" for a head indent, and the same holds for a tail one —
    /// measured, not assumed: with the leading half alone a photo in a quote came back 294pt wide on
    /// a 272pt line, centred alignment hanging it 11pt off each end of the line its own paragraph
    /// stops at. So BOTH halves of the narrowing are the atom's to subtract.
    internal static func atomHorizontalReduction(within ancestry: [EngineAncestor],
                                                 styleSheet: StyleSheet) -> CGFloat {
        ancestry.contentIndent(styleSheet: styleSheet) + ancestry.contentTrailingInset(styleSheet: styleSheet)
    }

    /// The atom's attributes alone — what a host command writes onto a freshly inserted `U+FFFC`.
    internal func mediaAtomAttributes(for shape: MediaShape, within ancestry: [EngineAncestor] = []) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        switch shape.alignment {
        case .left: style.alignment = .left
        case .center: style.alignment = .center
        case .right: style.alignment = .right
        }
        return [
            .attachment: mediaAttachment(for: shape, within: ancestry),
            .paragraphStyle: style,
            .font: Self.mediaAtomFont,
        ]
    }

    /// A media block's caption rendered with THIS bridge's mapper — what a host command that
    /// inserts a unit with a caption applies over the caption line, so bold, a link or a custom
    /// emoji in a passed caption survives instead of being flattened to plain text.
    internal func captionLine(runs: [TextRun]) -> NSAttributedString {
        Self.captionLine(runs: runs, using: mapper)
    }

    /// A media block's caption: `MediaBlockBox`'s caption paragraph exactly — `.caption`, centred.
    internal static func captionLine(runs: [TextRun], using mapper: AttributedStringMapper) -> NSAttributedString {
        let paragraph = ParagraphBlock(id: BlockID(UUID().uuidString), style: .caption,
                                       paragraph: ParagraphAttributes(alignment: .center),
                                       runs: Self.engineRuns(runs))
        return Self.engineReadable(mapper.attributedString(for: paragraph))
    }

    /// A container's horizontal padding inside its own background — a code block's band, a pull
    /// quote's pill.
    ///
    /// The decoration view is a background BEHIND the text, so it cannot push the text inward — the
    /// padding has to come from the text's own layout, which is why it is applied here and not in the
    /// view. Without it the code sits flush against its own band and reads as broken; the legacy
    /// composer insets it by `CodeStyle.horizontalInset`, and this reproduces that.
    ///
    /// The paragraph style is COPIED and mutated, never replaced: the mapper has already put V2's
    /// line geometry in it (`minimumLineHeight`/`maximumLineHeight` pinned to the pitch), and
    /// substituting a fresh style would silently drop that and change every line's spacing.
    ///
    /// Measured baseline worth knowing: every block already carries ~5pt of the text container's own
    /// `lineFragmentPadding` horizontally, and ZERO vertically. So the horizontal inset here ADDS to
    /// a non-zero baseline while the vertical one is the whole of it.
    private static func padded(_ source: NSAttributedString,
                               by horizontalInset: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: source)
        let whole = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.paragraphStyle, in: whole, options: []) { value, range, _ in
            let base = (value as? NSParagraphStyle) ?? NSParagraphStyle.default
            guard let style = base.mutableCopy() as? NSMutableParagraphStyle else { return }
            style.firstLineHeadIndent += horizontalInset
            style.headIndent += horizontalInset
            // Negative measures from the trailing edge, which is what keeps the inset symmetric
            // regardless of how wide the container turns out to be.
            style.tailIndent = -horizontalInset
            result.addAttribute(.paragraphStyle, value: style, range: range)
        }
        return result
    }

    /// The host's `CodeStyle.horizontalInset`, resolved into the stylesheet.
    ///
    /// **Horizontal only, and that is a measured limitation rather than a choice.** Vertical padding
    /// was implemented here first, as `paragraphSpacingBefore`/`paragraphSpacing`, and measured to do
    /// NOTHING: the attributes reach the render intact (verified through
    /// `id_renderedTextForBlockAtIndex:`) but TextKit ignores spacing-before on the first paragraph of
    /// a container, and trailing spacing does not extend the used height — so the band came out
    /// exactly as tall as its text, 0pt of padding, top and bottom.
    ///
    /// It is not re-added as a no-op knob: a value that changes nothing is not configuration, and it
    /// would read as working. Real vertical padding needs the ENGINE to reserve space for a block
    /// (a per-block content inset), which is an upstream addition, not a host-side attribute — and
    /// that is where it now lives: `blockInsets` reserves it and `EngineBlockSpacing` sources it from
    /// `StyleSheet.codeVerticalInset`, so the two halves of a code block's padding are applied by two
    /// different mechanisms for this reason and not by oversight.

    /// The inverse. Paragraph KIND (`style`, `paragraph`, `list`) is genuinely unrecoverable from an
    /// attributed string alone: `attributedString(for:)` *consumes* those fields to build a rendering
    /// artifact (an `NSParagraphStyle`), it does not encode them so they could be read back. So the
    /// host must carry it — and it must carry it **keyed by the engine's own block identity**, never
    /// by array position.
    ///
    /// `engineIdentifiers` is `TGIDObservingBlockTextView.tgid_blockIdentifiers`: one `NSUUID` per
    /// entry of `blocks`, straight off `IDBlockDocument.blocks`. `previous` maps those same `NSUUID`s
    /// to the `Block` each of them last resolved to — the whole block, not just a paragraph, because
    /// since containers flatten onto this axis the table also carries the block KIND and the fields
    /// that kind owns (a code block's `language`, a pull quote's `author`). A block whose identifier is
    /// IN the table keeps its kind, `id` and structural fields; only `runs` is rebuilt from
    /// `attributed`. A block whose identifier the table has NEVER SEEN is genuinely new — the
    /// engine minted that `NSUUID` inside this edit's affected span — so it mints a fresh `BlockID`
    /// and gets DEFAULT structure (`.body`, `ParagraphAttributes.default`, no list); continuing e.g.
    /// list membership into it is a host policy decision, not this bridge's (see
    /// `RichTextEngineEditorView+Paragraph.swift`'s list-continuation section).
    ///
    /// **Why identity rather than position, concretely.**
    /// `-[IDBlockDocument replaceCanonicalRange:withAttributedString:]` (`IDBlockDocument.m`) builds
    /// its result identifiers in three spans: every block BEFORE the affected range keeps its
    /// `NSUUID`, every block AFTER keeps its own, and only the blocks produced INSIDE the affected
    /// span get freshly minted ones. Positional reuse agrees with that only when new blocks appear
    /// at the very END of the document. Take `[p0 body "A"][p1 heading1 "B"]` with the caret at the
    /// end of "A" and press Return: the engine produces `["A"→u0, ""→new, "B"→u1]`. Positional reuse
    /// hands index 1 (the blank new line) p1's heading structure and index 2 ("B", the real heading)
    /// a default body — the heading migrates onto the blank line and the real one silently demotes.
    /// The merge direction fails the same way: backspacing at the start of B in `[A][B][C]` gives C
    /// block B's identity. Keying on the engine's own answer cannot express either mistake.
    ///
    /// Also NOT a strict identity with `attributedBlocks(for:)` even for `runs`:
    /// `AttributedStringMapper.characterAttributes(from:)` unconditionally pins `CharacterAttributes.
    /// fontSize` to the rendered font's point size on every read-back (by design — see that
    /// function's doc comment), so a run whose model `fontSize` was `nil` comes back with an explicit
    /// size after the first round trip. That normalization is idempotent, though: once a run has been
    /// through this bridge once, further round trips leave it unchanged
    /// (`EngineDocumentBridgeTests.test_theRoundTripDoesNotDriftOnRepeatedApplication` pins this). So
    /// the contract this function actually provides is "round-trips to a fixed point on the first
    /// pass, then is exact thereafter," not "round-trips to the identity."
    ///
    /// The REUSED style — not a default — must be threaded into `mapper.runs(from:style:)`: that
    /// style feeds `AttributedStringMapper`'s `boldIsAmbient` comparison base and its per-style
    /// default-foreground stripping, so reading a non-`.body` paragraph back at the wrong style
    /// either misclassifies an ambient weight as an explicit user `bold` or fails to strip a
    /// default colour (`EngineDocumentBridgeTests.test_aHeadingRoundTripsWithoutAcquiringExplicitBold`
    /// and `…test_aCaptionsDefaultForegroundIsStrippedOnlyWhenReadAtItsOwnStyle` pin the two halves).
    ///
    /// `blocks` and `engineIdentifiers` are parallel arrays. A shorter `engineIdentifiers` (which
    /// cannot happen — both are projections of the same `IDBlockDocument.blocks`) would leave the
    /// tail unidentified, so those blocks are treated as new rather than silently reusing an
    /// unrelated neighbour's structure.
    public func document(fromAttributedBlocks blocks: [NSAttributedString],
                         engineIdentifiers: [UUID],
                         reusingStructureOf previous: [UUID: Block]) -> Document {
        Document(blocks: blocks.enumerated().map { index, attributed in
            guard index < engineIdentifiers.count,
                  let prior = previous[engineIdentifiers[index]] else {
                // A brand-new block is always a paragraph. Splitting a container is a container
                // operation the commands own; the engine minting an identifier cannot tell us a kind.
                return .paragraph(ParagraphBlock(id: BlockID(UUID().uuidString),
                                                 runs: mapper.runs(from: attributed)))
            }
            switch prior {
            case let .paragraph(paragraph):
                return .paragraph(ParagraphBlock(
                    id: paragraph.id,
                    style: paragraph.style,
                    paragraph: paragraph.paragraph,
                    list: paragraph.list,
                    runs: mapper.runs(from: attributed, style: paragraph.style)))
            case let .code(code):
                // Read at the DEFAULT style, matching how the forward path rendered it: the mono face
                // is presentation the mapper never round-trips, so the runs come back clean.
                return .code(CodeBlock(id: code.id, language: code.language,
                                       runs: Self.plainCodeRuns(mapper.runs(from: attributed))))
            case let .pullQuote(quote):
                // `author` has no engine counterpart, so it survives only by being carried here.
                return .pullQuote(PullQuote(id: quote.id,
                                            runs: mapper.runs(from: attributed, style: .pullQuote),
                                            author: quote.author))
            case .media, .table, .blockQuote, .details, .buttonRow:
                // Unreachable by construction: `attributedBlocks(for:)` traps on these, so one can
                // never have reached the engine and so can never be in this table. Returned unchanged
                // rather than rebuilt, because its text is not in `attributed` to rebuild FROM —
                // fabricating a paragraph from someone else's text is the data loss the trap exists
                // to prevent.
                return prior
            }
        })
    }
}

extension Block {
    /// Diagnostic name only — never a behavioural switch.
    var caseNameForDiagnostics: String {
        switch self {
        case .paragraph: return "paragraph"
        case .media: return "media"
        case .table: return "table"
        case .code: return "code"
        case .pullQuote: return "pullQuote"
        case .blockQuote: return "blockQuote"
        case .details: return "details"
        case .buttonRow: return "buttonRow"
        }
    }
}
#endif

#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The placeholder strings drawn in empty paragraphs. Configurable so a host can localize them or suppress
/// them entirely (a chat composer draws its own placeholder, so it sets all to ""). An empty string means
/// "no placeholder" for that case. Defaults preserve the editor's built-in English hints.
@available(iOS 13.0, *)
public struct RichTextEditorPlaceholders: Equatable {
    /// Shown on the document's last empty body paragraph.
    public var body: String
    /// Shown on an empty top-level list item ("return ends the list").
    public var listEnd: String
    /// Shown on an empty nested list item ("return outdents").
    public var listOutdent: String
    /// Shown centered in an empty pull-quote block.
    public var pullQuote: String
    /// Shown in an empty block-quote (left-aligned at the quote's text position).
    public var blockQuote: String
    /// Shown in an empty code block.
    public var codeBlock: String
    /// Shown on a code block's EMPTY language line (the line is always visible).
    public var codeLanguage: String
    /// Shown in an empty detail-block title (summary) line.
    public var detailsTitle: String
    /// Shown on an empty author line in a block quote or pull quote.
    public var quoteAuthor: String
    /// Shown centered below media when its caption is empty.
    public var caption: String

    public init(body: String, listEnd: String, listOutdent: String, pullQuote: String = "Type a quote here",
                blockQuote: String = "Type a quote here", codeBlock: String = "Type code here",
                codeLanguage: String = "Language",
                detailsTitle: String = "Title", quoteAuthor: String = "Add author", caption: String = "Add caption") {
        self.body = body
        self.listEnd = listEnd
        self.listOutdent = listOutdent
        self.pullQuote = pullQuote
        self.blockQuote = blockQuote
        self.codeBlock = codeBlock
        self.codeLanguage = codeLanguage
        self.detailsTitle = detailsTitle
        self.quoteAuthor = quoteAuthor
        self.caption = caption
    }

    public static let `default` = RichTextEditorPlaceholders(
        body: "Type something…",
        listEnd: "Press return to end the list",
        listOutdent: "Press return to outdent",
        pullQuote: "Type a quote here",
        blockQuote: "Type a quote here",
        codeBlock: "Type code here",
        codeLanguage: "Language",
        detailsTitle: "Title",
        quoteAuthor: "Add author",
        caption: "Add caption"
    )
}

/// One paragraph block in the canvas: a TextKit 2 layout plus the structural
/// fields not stored in the attributed string, its frame in canvas coordinates, and its start in the
/// document-wide global position space.
@available(iOS 13.0, *)
final class BlockBox {
    let id: BlockID
    var style: ParagraphStyleName
    var listMembership: ListMembership?
    var paragraphAttributes: ParagraphAttributes
    let layout: BlockLayoutEngine
    let mapper: AttributedStringMapper

    var frame: CGRect = .zero
    var globalStart: Int = 0
    /// Default vertical inset above/below a block's text — half of the full gap between two
    /// default-spaced blocks. The owning `BlockStack` may shrink the facing inset for adjacent blocks.
    static let defaultVerticalInset: CGFloat = 8
    // x is always 0 — the horizontal page margin lives in frame.minX (set by the root BlockStack layout
    // origin); inside a table cell the frame already starts past the cell padding.
    let textInset = CGPoint(x: 0, y: BlockBox.defaultVerticalInset)
    // Vertical insets above/below the text, set per-layout by the owning `BlockStack`. They default to
    // `defaultVerticalInset`, but the facing inset shrinks between adjacent blocks (0 between list items
    // and 0 between two plain body paragraphs, so both stack like paragraph lines).
    var topInset: CGFloat = BlockBox.defaultVerticalInset
    var bottomInset: CGFloat = BlockBox.defaultVerticalInset

    /// The Core `ListNumbering` marker label for this box (e.g. "1.", "•"), stamped by the canvas
    /// during layout (numbering is document-wide). nil = not a list item / not stamped (table cells
    /// are never stamped, matching today's top-level-only marker rendering). Presentation only.
    var resolvedListMarker: String?

    /// True only for boxes laid out as the document root's children (set by the canvas during layout).
    /// Gates placeholder drawing so empty TABLE-CELL paragraphs draw no placeholder (parity with today,
    /// where placeholders are a top-level-only concern). Default false.
    var isTopLevelBlock = false

    /// True only when this is the document's SOLE top-level block (set by the canvas during layout). Gates
    /// the body "Type something…" placeholder so it shows only in an otherwise-empty document — never when
    /// any other block exists. Default false.
    var isOnlyBlock = false

    /// The placeholder strings to draw in this box when empty. Stamped by the canvas during layout
    /// (`stampListMarkers`) from its configurable `placeholders`. Default = the editor's built-in hints.
    var placeholders: RichTextEditorPlaceholders = .default

    /// Set during layout (`stampListMarkers`) iff the canvas has a checklist checkbox provider AND this
    /// is a checklist item — then `draw` suppresses the Unicode glyph (a hosted CheckNode shows instead).
    var hostsChecklistCheckbox = false

    /// When set, overrides the mapper's base writing direction for THIS box only — used so an empty
    /// paragraph adopts the live keyboard direction in auto mode (the caret opens on the correct side).
    /// A `didSet` pushes the value into the layout engine's `emptyTextCaretDirection` hint.
    var writingDirectionOverride: NSWritingDirection? {
        didSet { layout.emptyTextCaretDirection = writingDirectionOverride }
    }

    /// A plain body paragraph (not a list item) — the spacing between two of these is tightened.
    var isBodyParagraph: Bool { style == .body && listMembership == nil }

    /// A cheap value that changes iff this box's rendered output would change: text/attribute version,
    /// frame size (wrapping/extent), and the stamped decoration state (marker label, top-level/placeholder
    /// gate). Used to skip a `setNeedsDisplay` when nothing changed.
    var renderSignature: Int {
        var h = Hasher()
        h.combine(layout.renderVersion)
        h.combine(frame.size.width); h.combine(frame.size.height)
        h.combine(resolvedListMarker)
        h.combine(isTopLevelBlock)
        // Sole-block-ness gates the body placeholder and can flip on a SURVIVING box instance (another
        // block added/removed) without a renderVersion bump, so capture it structurally.
        h.combine(isOnlyBlock)
        // Defensive: a STYLE or list-LEVEL change on an EMPTY paragraph (where `restyle()` early-returns
        // and renderVersion may not bump) changes the placeholder text / marker indent. Capture it
        // structurally rather than coincidentally.
        h.combine(style)
        h.combine(listMembership?.level)
        // A provider registered AFTER first layout flips this false→true on the SAME box instance
        // (no instance swap, so `bindRealizedView`'s `view.box !== box` repaint bypass doesn't fire).
        // Capture it so the now-suppressed Unicode glyph actually disappears (and reappears if a
        // provider is later cleared).
        h.combine(hostsChecklistCheckbox)
        return h.finalize()
    }

    init(paragraph: ParagraphBlock, mapper: AttributedStringMapper, width: CGFloat) {
        id = paragraph.id
        style = paragraph.style
        listMembership = paragraph.list
        paragraphAttributes = paragraph.paragraph
        self.mapper = mapper
        layout = makeBlockLayout(attributedString: mapper.attributedString(for: paragraph),
                                 width: max(width, 1))
    }

    /// Mirrors `InstantPageBuilder`'s dispatch order exactly: a standalone formula wins over the list
    /// check, which wins over the style switch.
    ///
    /// The formula test is the layout-side equivalent of `ParagraphBlock.standaloneFormulaLatex` (which
    /// is the definition — see it in Core) rather than a call to it: reaching the model would mean
    /// `currentParagraph()`, which re-derives every run from the attributed string, and this is read on
    /// every layout pass for every block.
    var spacingKind: RichTextBlockSpacingKind {
        if style == .body, listMembership == nil, layout.length == 1,
           layout.attributedString.attribute(.attachment, at: 0, effectiveRange: nil) is FormulaTextAttachment {
            return .formula
        }
        if listMembership != nil { return .list }
        switch style {
        case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6: return .heading
        case .body, .caption: return .paragraph
        case .pullQuote: return .pullQuote
        }
    }

    /// The text height without the stack-owned inter-block insets.
    func measuredContentHeight(forWidth width: CGFloat) -> CGFloat {
        max(layout.correctedBoundingHeight(forWidth: max(width - textInset.x * 2, 1)), emptyLineHeight)
    }

    var length: Int { layout.length }
    var textRef: TextNodeRef { .paragraph(id) }
    var height: CGFloat { max(layout.correctedBoundingHeight, emptyLineHeight) + topInset + bottomInset }
    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        max(layout.correctedBoundingHeight(forWidth: max(width - textInset.x * 2, 1)), emptyLineHeight)
            + topInset + bottomInset
    }
    var textOrigin: CGPoint { CGPoint(x: frame.minX + textInset.x, y: frame.minY + topInset) }

    /// Height of one line in this paragraph's font, reserved only when the paragraph is EMPTY (TextKit 2
    /// lays out no fragment for empty text, so `boundingHeight` is ~0). Keeps a blank paragraph — and a
    /// blank table cell, which collapses its row otherwise — at a real line's height, matching what it
    /// becomes once text is typed (the font the style will use).
    private var emptyLineHeight: CGFloat {
        guard layout.length == 0 else { return 0 }
        let font = (mapper.attributes(for: CharacterAttributes(), style: style)[.font] as? UIFont)
            ?? UIFont.preferredFont(forTextStyle: .body)
        // V2's height for a single line: `ascender + |descender|`, not one pitch. Keeping these in
        // agreement is what stops a document changing height when its first character is typed.
        let sheet = mapper.styleSheet
        return RichTextRenderMetrics.textHeight(font, factor: sheet.metrics.spec(for: style).lineSpacingFactor,
                                                lineCount: 1)
    }

    /// Leading text indent (the paragraph style's `firstLineHeadIndent` — the list-marker spacing or
    /// quote inset) to apply to this paragraph's caret and placeholder *while it is EMPTY*. TextKit
    /// applies the indent to laid-out glyphs, but lays out no fragment for empty text, so the empty-line
    /// caret falls back to x=0 and the placeholder to `textOrigin` — both must add this so they align
    /// with where text will appear (past the marker). 0 once any text exists (the glyph layout carries
    /// it, so adding it again would double-indent). Mirrors `emptyLineHeight`.
    var emptyLineLeadingIndent: CGFloat {
        guard layout.length == 0 else { return 0 }
        return mapper.styleSheet.paragraphStyle(for: style, attributes: paragraphAttributes,
                                                list: listMembership,
                                                baseWritingDirection: writingDirectionOverride ?? mapper.baseWritingDirection).firstLineHeadIndent
    }

    func setWidth(_ width: CGFloat) { layout.setWidth(max(width - textInset.x * 2, 1)) }

    /// Y (relative to `textOrigin.y`) at which a list marker's baseline must sit to align with this
    /// paragraph's first text line. Uses the real laid-out baseline when text exists; for an empty list
    /// item it falls back to the style's line metrics, so the marker doesn't jump when the first glyph
    /// is typed (an empty TextKit 2 layout has no fragment to measure).
    func listMarkerBaselineFromTop(markerFont: UIFont) -> CGFloat {
        if let baseline = layout.firstLineBaselineFromTop { return baseline }
        // An empty paragraph lays out no fragment, so the baseline is computed analytically. Under the
        // pinned-box model that is simply V2's first-baseline position — the font's ascender — which is
        // exactly what `firstLineBaselineFromTop` returns once a glyph exists. Keeping the two in
        // agreement is what stops an empty item's marker jumping when the first glyph is typed.
        return RichTextRenderMetrics.firstBaselineFromTop(markerFont)
    }

    /// This box's list-marker draw (label + canvas-coordinate origin + font), or nil when it has no
    /// stamped marker. Mirrors the geometry the canvas `listMarkerDraws()` seam used to compute, so the
    /// marker lands at the same place whether drawn here or by the seam.
    func listMarkerDraw() -> (label: String, origin: CGPoint, font: UIFont)? {
        guard let label = resolvedListMarker, let membership = listMembership else { return nil }
        let font = mapper.styleSheet.font(for: style, attributes: .plain)
        let x = textOrigin.x + StyleSheet.listIndentStep * CGFloat(membership.level)
        let y = textOrigin.y + listMarkerBaselineFromTop(markerFont: font) - font.ascender
        return (label, CGPoint(x: x, y: y), font)
    }

    /// The checkbox rect in CANVAS coordinates for a `.checklist` item. Sized 1.4× the font's cap height
    /// (`checklistMarkerScale`), pixel-snapped, with the LEFT edge anchored at the marker gutter and the
    /// vertical CENTER preserved at the base (bottom-on-baseline) box's center — so the extra height grows
    /// equally into the top and bottom, and extra width grows to the right.
    /// `textOrigin` is already canvas-space (frame origin + insets) — do NOT add `frame` again.
    func checklistMarkerCanvasRect() -> CGRect? {
        guard listMembership?.marker == .checklist, let membership = listMembership else { return nil }
        let font = mapper.styleSheet.font(for: style, attributes: .plain)
        let baseSide = StyleSheet.checklistMarkerSize(for: font)               // cap-height base (unscaled)
        let side = floorToScreenPixels(baseSide * StyleSheet.checklistMarkerScale)
        let x = textOrigin.x + StyleSheet.listIndentStep * CGFloat(membership.level)   // LEFT anchored
        let baselineFromTop = listMarkerBaselineFromTop(markerFont: font)
        // Preserve the base (bottom-on-baseline) box's vertical center, so the extra height grows equally
        // into the top & bottom; extra width grows to the right (left edge fixed).
        let baseCenterY = textOrigin.y + baselineFromTop - baseSide / 2
        let y = baseCenterY - side / 2
        return CGRect(x: floorToScreenPixels(x), y: floorToScreenPixels(y), width: side, height: side)
    }

    /// Placeholder text for THIS empty paragraph, or nil. A list item's hint reflects what Return does.
    var placeholderText: String? {
        // An empty configured string means "no placeholder" for that case (→ nil, so nothing is drawn).
        func nonEmpty(_ s: String) -> String? { s.isEmpty ? nil : s }
        if let list = listMembership {
            return nonEmpty(list.level > 0 ? placeholders.listOutdent : placeholders.listEnd)
        }
        switch style {
        case .body: return isOnlyBlock ? nonEmpty(placeholders.body) : nil   // only when it's the document's sole block
        default:    return nil
        }
    }

    /// This box's placeholder draw (text + canvas-coordinate origin + font), or nil when it shouldn't
    /// show one (non-empty, non-top-level, or a style with no placeholder).
    func placeholderDraw() -> (text: String, origin: CGPoint, font: UIFont)? {
        guard isTopLevelBlock, layout.length == 0, let text = placeholderText else { return nil }
        let font = mapper.styleSheet.font(for: style, attributes: .plain)
        // No baseline shift: under the pinned-box model the first baseline is the font's ascender, which
        // is where a natural draw at `textOrigin` already puts it. (Under the previous
        // `lineHeightMultiple` model this needed half the extra leading.)
        let baselineShift: CGFloat = 0
        let origin = CGPoint(x: textOrigin.x + emptyLineLeadingIndent, y: textOrigin.y + baselineShift)
        return (text, origin, font)
    }

    /// Applies a RENDER-ONLY override to the display layout: paragraph `alignment` (overriding the
    /// cell's own, for table column alignment) and, when `forceBold`, a bold font trait on every run
    /// (for an emphasized column/row, e.g. a table's first column). The stored model is NOT changed —
    /// alignment is read back from `paragraphAttributes` (untouched here), and
    /// `TableBlockBox.currentBlock()` strips the synthetic bold from the emphasized cells. Idempotent.
    /// No-op on empty text (the override re-applies once text exists).
    func applyDisplayOverride(alignment: TextAlignment, forceBold: Bool, mapper: AttributedStringMapper) {
        let storage = layout.attributedString
        guard storage.length > 0 else { return }
        let m = NSMutableAttributedString(attributedString: storage)
        let full = NSRange(location: 0, length: m.length)
        // Alignment: rebuild the paragraph style from this box's own attributes but with the override
        // alignment, preserving list/indent properties.
        var pa = paragraphAttributes
        pa.alignment = alignment
        let ps = mapper.styleSheet.paragraphStyle(for: style, attributes: pa, list: listMembership,
                                                   baseWritingDirection: writingDirectionOverride ?? mapper.baseWritingDirection)
        m.addAttribute(.paragraphStyle, value: ps, range: full)
        // Bold: only ADD the trait (e.g. the first column). Never remove — other cells keep user bold.
        if forceBold {
            m.enumerateAttribute(.font, in: full, options: []) { value, range, _ in
                guard let font = value as? UIFont,
                      !font.fontDescriptor.symbolicTraits.contains(.traitBold) else { return }
                var traits = font.fontDescriptor.symbolicTraits
                traits.insert(.traitBold)
                if let d = font.fontDescriptor.withSymbolicTraits(traits) {
                    m.addAttribute(.font, value: UIFont(descriptor: d, size: font.pointSize), range: range)
                }
            }
        }
        // Truly idempotent (as the doc above promises): assign only when the override actually changes the
        // storage. In the steady state the override is already present, so `m == storage` and we skip the
        // assignment. This matters because `recompute()` calls this on EVERY layout pass: an unconditional
        // re-assign would (1) bump `renderVersion` every pass — defeating the render-signature repaint gate
        // for every table cell — and, more seriously, (2) reset the layout's spoiler-hide ranges every pass
        // (the `attributedString` setter clears them), so `setSpoilerHidden` never reports "no change" and
        // `syncSpoilers` calls `setNeedsLayout()` on every pass → an infinite `layoutIfNeeded` loop whenever a
        // table cell holds a HIDDEN spoiler. (Regression: SpoilerCrossRegionTests.)
        if !m.isEqual(storage) { layout.attributedString = m }
    }

    func currentParagraph() -> ParagraphBlock {
        ParagraphBlock(id: id, style: style, paragraph: paragraphAttributes, list: listMembership,
                       runs: mapper.runs(from: layout.attributedString, style: style))
    }
}

/// Snap a value down to the device pixel grid (editor-local; Display's `floorToScreenPixels` isn't importable here).
@available(iOS 13.0, *)
private func floorToScreenPixels(_ value: CGFloat) -> CGFloat {
    let scale = UIScreen.main.scale
    return (value * scale).rounded(.down) / scale
}

@available(iOS 13.0, *)
extension BlockBox: CanvasBlock {
    var rendersAsBlockView: Bool { true }
    var nodeStart: Int { get { globalStart } set { globalStart = newValue } }
    var nodeSize: Int { length + 2 }
    var textLayout: BlockLayoutEngine { layout }
    var textStart: Int { globalStart }
    var textLength: Int { length }
    func currentBlock() -> Block { .paragraph(currentParagraph()) }
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        textStart + layout.closestOffset(toPoint: CGPoint(x: point.x - textOrigin.x, y: point.y - textOrigin.y))
    }
    func leafRegions() -> [LeafTextRegion] {
        [LeafTextRegion(layout: layout, globalStart: globalStart, length: length,
                        ref: .paragraph(id), canvasOrigin: textOrigin,
                        emptyLineLeadingIndent: emptyLineLeadingIndent, emptyLineHeight: emptyLineHeight)]
    }
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        layout.drawText(in: ctx, at: textOrigin)
        if let d = listMarkerDraw(), !(hostsChecklistCheckbox && listMembership?.marker == .checklist) {
            NSAttributedString(string: d.label,
                attributes: [.font: d.font, .foregroundColor: mapper.theme.listMarker]).draw(at: d.origin)
        }
        if let pd = placeholderDraw() {
            NSAttributedString(string: pd.text,
                attributes: [.font: pd.font, .foregroundColor: mapper.theme.placeholder]).draw(at: pd.origin)
        }
    }
}
#endif

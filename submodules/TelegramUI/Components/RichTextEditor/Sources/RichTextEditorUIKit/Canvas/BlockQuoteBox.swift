#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One block-quote container in the canvas: a `CanvasBlock` that branches on `collapsed`.
///
/// **Expanded** (`collapsed == false`): a container hosting one child `BlockStack` built via `makeBox`,
/// so any block type nests — including nested block quotes (the factory is recursive). Token size =
/// children + 2; `recompute()` assigns child `nodeStart`s and lays out frames; `leafRegions()` /
/// `closestPosition` delegate to the child stack. The fill (accent bar + tinted background) is painted
/// by the `blockQuoteFillRects()` underlay feed — this box draws only its children.
///
/// **Collapsed** (`collapsed == true`): a non-editable ATOM (nodeSize 3, empty leafRegions) drawing a
/// ≤3-line folded preview + a trailing expand glyph — mirroring `CollapsedQuoteBox`. Children are still
/// built (for `currentBlock()` round-trip + expand); the collapsed branch only changes the axis/geometry/draw.
/// This matches `DocumentTree` (Task 2), which maps a collapsed blockQuote to a `.mediaBlock`+`.mediaAtom`
/// atom (nodeSize 3) — so the box's nodeSize MUST also be 3 when collapsed.
@available(iOS 13.0, *)
final class BlockQuoteBox: CanvasBlock {
    // MARK: - Collapsed preview geometry constants
    // (Formerly on the removed CollapsedQuoteBox; kept here so BlockQuoteBox's collapsed mode is self-contained.)
    static let maxPreviewLines: Int = 3
    /// Square side of the trailing "expand" glyph, plus its gap from the text content.
    static let expandGlyphSize: CGFloat = 18
    static let expandGlyphGap: CGFloat = 6

    /// Text attributes used by the collapsed preview layout (body font, primary text color, tail-truncating).
    /// Uses the mapper's body paragraph style (carries lineHeightMultiple + spacing from StyleSheet.metrics)
    /// so the collapsed preview's per-line height exactly matches the expanded child BlockBox, giving the
    /// same total height for a single-line quote regardless of collapsed/expanded state.
    static func previewAttributes(mapper: AttributedStringMapper) -> [NSAttributedString.Key: Any] {
        let base = mapper.styleSheet.paragraphStyle(for: .body, attributes: .default)
        let ps = (base.mutableCopy() as! NSMutableParagraphStyle)
        ps.lineBreakMode = .byTruncatingTail
        return [.font: mapper.styleSheet.font(for: .body, attributes: .plain),
                .foregroundColor: mapper.theme.primaryText,
                .paragraphStyle: ps]
    }

    let id: BlockID
    let mapper: AttributedStringMapper
    let quoteStyle: QuoteStyle
    let pullQuoteStyle: PullQuoteStyle
    let expandImage: UIImage?
    /// Collapse glyph drawn on an expanded box that is tall enough (mirrors QuoteCollapseControlsView's glyph
    /// for the flat quote but self-contained here so nested quotes work and the flat mechanism is untouched).
    let collapseImage: UIImage?
    /// Whether the block quote is collapsed. When true the box is a non-editable atom (nodeSize 3).
    let collapsed: Bool

    var frame: CGRect = .zero
    var nodeStart: Int = 0
    /// Host placeholder strings (stamped by the canvas). Drives the empty block-quote hint.
    var placeholders: RichTextEditorPlaceholders = .default
    private(set) var layoutWidth: CGFloat

    /// Interior top padding (fill → first child). Mirrors `CodeBlockBox`: uses the QuoteStyle vertical
    /// inset if the mapper's stylesheet has one, otherwise the block-box default (8pt).
    var topInset: CGFloat
    /// Interior bottom padding (last child → fill bottom). Mirrors `topInset`.
    var bottomInset: CGFloat

    /// The single child stack — one `BlockStack` analogous to a single table cell. Children are built via
    /// `makeBox`, so any block type (paragraph, code, nested block quote, …) can appear here. The stack
    /// uses the document-standard `BlockBox.defaultVerticalInset` (8pt) between children — not 0 like a
    /// table cell — because the children are regular document blocks with normal inter-block spacing.
    let children: BlockStack

    /// Display-only preview layout for collapsed mode (nil when expanded). NOT part of the position axis.
    private let previewLayout: BlockLayoutEngine?

    /// The author (attribution) line's own TextKit layout, rendered as a bold `.caption` style AFTER the
    /// child stack — recursive: each nested block quote carries its own. Bold and the text color are both
    /// ambient (forced via `quoteAuthorRenderRuns`, stripped on read-back). Unlike the centered pull-quote
    /// author, this one is leading-aligned (mirrors the quote's own leading-aligned body text).
    let authorLayout: BlockLayoutEngine
    /// The author renders leading-aligned (unlike the centered pull-quote author).
    private static let authorParagraph = ParagraphAttributes(alignment: .natural)

    init(blockQuote: BlockQuote, mapper: AttributedStringMapper,
         quoteStyle: QuoteStyle = .default,
         pullQuoteStyle: PullQuoteStyle = .default,
         expandImage: UIImage? = nil,
         collapseImage: UIImage? = nil,
         width: CGFloat) {
        // Derive a 15pt-body mapper for all quote content. This preserves the host's quote insets,
        // spacing, theme, emoji scale, and writing direction (unlike `tableCellVariant()`, which
        // swaps in the fixed `.tableCells` stylesheet). Nested quotes and quotes-in-cells call
        // withBodyFontSize(15) on their already-15pt mapper → idempotent; no per-level shrink.
        let quoteMapper = mapper.withBodyFontSize(15)
        self.id = blockQuote.id
        self.mapper = quoteMapper
        self.quoteStyle = quoteStyle
        self.pullQuoteStyle = pullQuoteStyle
        self.expandImage = expandImage
        self.collapseImage = collapseImage
        self.collapsed = blockQuote.collapsed
        self.layoutWidth = max(width, 1)
        // Vertical insets mirror CodeBlockBox: prefer the QuoteStyle-sourced stylesheet value.
        // Read from quoteMapper so the insets are consistent with the quote's own stylesheet.
        self.topInset = quoteMapper.styleSheet.quoteTopInset ?? BlockBox.defaultVerticalInset
        self.bottomInset = quoteMapper.styleSheet.quoteBottomInset ?? BlockBox.defaultVerticalInset

        let inner = max(width - quoteStyle.leadingInset - quoteStyle.trailingInset, 1)
        let stack = BlockStack(boxes: blockQuote.children.compactMap {
            makeBox(for: $0, mapper: quoteMapper, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                    expandImage: expandImage, collapseImage: collapseImage, horizontalBleed: 0, width: inner)
        })
        // 0 inset base so the first child's content-top aligns with the collapsed preview's text-top
        // (frame.minY + topInset). The collapsed preview starts there; the expanded first child must start
        // there too, so the two modes are visually consistent. Inter-child spacing comes from each child's
        // own topInset/bottomInset (via `facingInset`), exactly like table cells whose cell frame owns all
        // vertical padding. The quote's topInset/bottomInset are the sole outer padding.
        stack.spacingModel = .containerInterior
            stack.verticalInsetBase = 0
        self.children = stack

        // The author line uses the same 15pt quote mapper as the children, laid out at the same inner width.
        self.authorLayout = makeBlockLayout(
            attributedString: quoteMapper.attributedString(for: ParagraphBlock(
                id: blockQuote.id, style: .caption, paragraph: BlockQuoteBox.authorParagraph,
                runs: quoteAuthorRenderRuns(blockQuote.author, textColor: quoteMapper.theme.quoteAuthorText.rgba))),
            width: max(inner, 1))

        // Collapsed mode: build a display-only preview layout from the children's flattened plain text.
        // Newlines → spaces so the preview is a single wrapped text run (≤3 lines), matching BlockQuoteBox.
        if blockQuote.collapsed {
            let joined = blockQuote.children.map { blockPlainText($0) }.joined(separator: "\n")
            let previewText = joined.replacingOccurrences(of: "\n", with: " ")
            let tw = max(width - quoteStyle.leadingInset
                         - (max(quoteStyle.trailingInset, 0)
                            + BlockQuoteBox.expandGlyphSize
                            + BlockQuoteBox.expandGlyphGap), 1)
            let attrs = BlockQuoteBox.previewAttributes(mapper: quoteMapper)
            self.previewLayout = makeBlockLayout(
                attributedString: NSAttributedString(string: previewText, attributes: attrs),
                width: tw)
        } else {
            self.previewLayout = nil
        }
    }

    // MARK: - Collapsed preview helpers (mirror CollapsedQuoteBox geometry)

    private var leadingPad: CGFloat { quoteStyle.leadingInset }
    private var trailingPad: CGFloat {
        max(quoteStyle.trailingInset, 0) + BlockQuoteBox.expandGlyphSize + BlockQuoteBox.expandGlyphGap
    }
    private func previewTextWidth(_ width: CGFloat) -> CGFloat {
        max(width - leadingPad - trailingPad, 1)
    }
    /// One body LINE ADVANCE in this quote's mapper — V2's `linePitch`, not `font.lineHeight`. Used to
    /// cap the collapsed preview at `maxPreviewLines` and to size the collapsed caret, both of which are
    /// "how tall are N lines" questions and so must use the pitch.
    private var lineHeight: CGFloat {
        let sheet = mapper.styleSheet
        return RichTextRenderMetrics.linePitch(sheet.font(for: .body, attributes: .plain),
                                               factor: sheet.metrics.body.lineSpacingFactor)
    }

    /// Caret rect for the COLLAPSED atom's leading gap (canvas coords): a 2pt bar at the folded preview's
    /// leading edge, one line tall. The canvas `caretRect` reports this — the folded quote owns no text leaf,
    /// so without it the caret focused on a collapsed quote would be invisible. Mirrors the media-gap caret.
    var collapsedCaretRect: CGRect {
        CGRect(x: frame.minX + leadingPad, y: frame.minY + topInset, width: 2, height: lineHeight)
    }
    private var previewHeight: CGFloat {
        guard let layout = previewLayout else { return 0 }
        // The cap is "N lines worth" in V2 terms too: N pitches, less the last line's box overhang.
        let capped = lineHeight * CGFloat(BlockQuoteBox.maxPreviewLines)
            + RichTextRenderMetrics.trailingHeightCorrection(mapper.styleSheet.font(for: .body, attributes: .plain),
                                                             pinnedLineHeight: lineHeight)
        return min(layout.correctedBoundingHeight, capped)
    }

    /// Whether the collapse control should appear. Only when the quote's content is TALLER than the
    /// ≤`maxPreviewLines`-line collapsed preview would show — i.e. collapsing actually hides content
    /// ("more than 3 body lines worth of content, vertically"). A short quote gets no collapse glyph.
    var isCollapsible: Bool {
        children.measuredHeight(forWidth: innerWidth(layoutWidth)) > CGFloat(BlockQuoteBox.maxPreviewLines) * lineHeight
    }

    /// The trailing "expand" glyph rect in canvas coordinates (used by the canvas's tap routing, Task 12).
    func expandGlyphRect() -> CGRect {
        CGRect(x: frame.maxX - 4 - BlockQuoteBox.expandGlyphSize,
               y: frame.minY + 4,
               width: BlockQuoteBox.expandGlyphSize, height: BlockQuoteBox.expandGlyphSize)
    }

    /// The top-right "collapse" glyph rect for an EXPANDED box (drawn on every expanded quote regardless
    /// of height or nesting level). Mirrors `expandGlyphRect` geometry.
    func collapseGlyphRect() -> CGRect {
        let s = DocumentCanvasView.collapseButtonSize
        return CGRect(x: frame.maxX - 4 - s, y: frame.minY + 4, width: s, height: s)
    }

    // MARK: - Internal helpers

    private func innerWidth(_ w: CGFloat) -> CGFloat {
        max(w - quoteStyle.leadingInset - quoteStyle.trailingInset, 1)
    }

    // MARK: - Author region helpers (Task 4; mirrors PullQuoteBox but leading-aligned)

    var authorLength: Int { authorLayout.length }

    /// The author line is shown only when the quote has content — the author itself has text, OR the body
    /// has content (any child that is not an empty, list-less `BlockBox`; nested quotes/tables/media/code/
    /// list-items count even when empty). A blank quote hides the author region entirely.
    var shouldShowAuthor: Bool {
        authorLength > 0 || children.boxes.contains { box in
            if let bb = box as? BlockBox { return bb.textLength > 0 || bb.listMembership != nil }
            return true
        }
    }

    private var authorEmptyLineHeight: CGFloat {
        guard authorLayout.length == 0 else { return 0 }
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        let mult = mapper.styleSheet.paragraphStyle(for: .caption, attributes: BlockQuoteBox.authorParagraph,
                                                    list: nil, baseWritingDirection: mapper.baseWritingDirection).lineHeightMultiple
        return font.lineHeight * (mult > 0 ? mult : 1)
    }

    /// Height occupied by the child stack, so the author sits just below it. Uses `BlockStack`'s real
    /// laid-out content height (`contentHeight`, populated by `layout(...)` in `recompute()`) rather than
    /// summing each child's own `height` — the sum would ignore the inter-child spacing (`facingInset`
    /// gaps) `BlockStack.layout` inserts between children, landing the author line too high.
    private var childStackHeight: CGFloat { children.contentHeight }

    /// The author line's canvas origin: below the child stack, at the quote's leading text inset.
    /// NB the author line is placed against the RAW line box, not the V2-corrected height. Author-line
    /// placement is quote INTERIOR geometry, which has no V2 reference in this cycle (the quote-interior
    /// cycle owns it) — correcting it here would shift the attribution 1-2pt with nothing to check it
    /// against. The quote's own HEIGHT is corrected, because that feeds the document's block rhythm.
    private var authorOrigin: CGPoint {
        CGPoint(x: frame.minX + quoteStyle.leadingInset,
                y: frame.minY + topInset + childStackHeight + quoteStyle.authorSpacing)
    }

    /// Bold caption typing attributes (leading-aligned) for the FIRST char typed into an empty author line.
    func authorTypingAttributes() -> [NSAttributedString.Key: Any] {
        var ca = CharacterAttributes(); ca.bold = true; ca.foreground = mapper.theme.quoteAuthorText.rgba
        var attrs = mapper.attributes(for: ca, style: .caption)
        attrs[.paragraphStyle] = mapper.styleSheet.paragraphStyle(for: .caption, attributes: BlockQuoteBox.authorParagraph,
                                                                  list: nil, baseWritingDirection: mapper.baseWritingDirection)
        return attrs
    }

    // MARK: - CanvasBlock

    /// Block-quote boxes use a `BlockBackingView`, like tables and pull-quotes.
    var rendersAsBlockView: Bool { true }

    /// Collapsed → 3 (non-editable atom, matching DocumentTree's collapsed mapping).
    /// Expanded, author shown → open + children tokens + author paragraph (authorLength + 2) + close
    /// (Σchildren + authorLength + 4), matching `DocumentTree`'s `.blockQuote(id, children + [authorPara])`.
    /// Expanded, author hidden → open + children tokens + close (Σchildren + 2), matching `DocumentTree`'s
    /// `.blockQuote(id, children)` (no trailing author paragraph).
    var spacingKind: RichTextBlockSpacingKind { .blockQuote }

    var nodeSize: Int {
        if collapsed { return 3 }
        let childrenSize = children.boxes.reduce(0) { $0 + $1.nodeSize }
        return shouldShowAuthor ? childrenSize + (authorLength + 2) + 2 : childrenSize + 2
    }

    func setWidth(_ width: CGFloat) {
        layoutWidth = max(width, 1)
        if collapsed {
            previewLayout?.setWidth(previewTextWidth(layoutWidth))
        } else {
            let inner = innerWidth(layoutWidth)
            for box in children.boxes { box.setWidth(inner) }
        }
    }

    /// Collapsed → preview height (capped at maxPreviewLines) + insets.
    /// Expanded → topInset + child stack measured height + the author line (gap + its own height) + bottomInset.
    var height: CGFloat {
        if collapsed {
            return previewHeight + topInset + bottomInset
        }
        let base = topInset + children.measuredHeight(forWidth: innerWidth(layoutWidth)) + bottomInset
        guard shouldShowAuthor else { return base }
        return base + quoteStyle.authorSpacing + max(authorLayout.boundingHeight, authorEmptyLineHeight)
    }

    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        if collapsed {
            guard let layout = previewLayout else { return topInset + bottomInset }
            let tw = previewTextWidth(max(width, 1))
            let h = min(layout.correctedBoundingHeight(forWidth: tw),
                        lineHeight * CGFloat(BlockQuoteBox.maxPreviewLines))
            return h + topInset + bottomInset
        }
        let inner = innerWidth(max(width, 1))
        let base = topInset + children.measuredHeight(forWidth: inner) + bottomInset
        guard shouldShowAuthor else { return base }
        return base + quoteStyle.authorSpacing + max(authorLayout.boundingHeight(forWidth: inner), authorEmptyLineHeight)
    }

    /// Assigns `nodeStart` to every child box and lays out child frames. Mirrors `TableBlockBox.recompute()`
    /// for the single-cell (no row/grid) case. Called by the canvas from `recomputeSpans()` and
    /// `layoutContent()` after the root layout has set `self.frame` and `self.nodeStart`.
    /// Recursively recomputes any nested `BlockQuoteBox` children.
    /// Collapsed → early return (children are off the position axis; their spans are irrelevant for layout).
    func recompute() {
        if collapsed { return }
        // Assign nodeStarts: baseOffset = this box's nodeStart (the open token).
        children.recompute(baseOffset: nodeStart)
        // Lay out child frames: content strip offset by the leading inset and top padding.
        // A full-bleed child (a code block) reaches the quote's interior: out to just INSIDE the
        // accent bar on the leading side, so the bar stays continuous down the whole quote rather
        // than being interrupted for the child's height, and to the fill's trailing edge.
        children.layout(
            origin: CGPoint(x: frame.minX + quoteStyle.leadingInset, y: frame.minY + topInset),
            width: innerWidth(frame.width),
            codeBleed: (minXSide: max(0, quoteStyle.leadingInset - quoteStyle.barWidth),
                        maxXSide: quoteStyle.trailingInset)
        )
        // Propagate recompute recursively into nested block quotes (their frames are now set above).
        for case let nested as BlockQuoteBox in children.boxes { nested.recompute() }
        // Refresh the author layout's width now that `frame` is set (it was built at `inner` width in
        // `init`, which is correct on the first pass but stale after a resize via `setWidth`).
        authorLayout.setWidth(max(innerWidth(frame.width), 1))
    }

    /// Round-trips back to the Core model: rebuilds the `BlockQuote` from the current child boxes plus the
    /// read-back author line (bold and the author text color are ambient — stripped here so neither persists
    /// into the model). Children are preserved even in collapsed mode (for expand + send round-trip). The
    /// author is NOT counted as a model child — it's carried on the dedicated `BlockQuote.author` field.
    func currentBlock() -> Block {
        .blockQuote(BlockQuote(id: id,
                               children: children.boxes.map { $0.currentBlock() },
                               collapsed: collapsed,
                               author: quoteAuthorStripAmbientStyle(mapper.runs(from: authorLayout.attributedString, style: .caption),
                                                                    textColor: mapper.theme.quoteAuthorText.rgba)))
    }

    /// Collapsed → [] (non-editable atom, off the position axis).
    /// Expanded, author shown → the child stack's leaf regions (recurses into nested quotes) followed by the
    /// author region — the author paragraph is the LAST child of the `.blockQuote` container (`DocumentTree`),
    /// so its `globalStart` sits right after every child's token span.
    /// Expanded, author hidden → just the child stack's leaf regions (no trailing author region).
    func leafRegions() -> [LeafTextRegion] {
        if collapsed { return [] }
        guard shouldShowAuthor else { return children.leafRegions() }
        let childrenSize = children.boxes.reduce(0) { $0 + $1.nodeSize }
        let authorRegion = LeafTextRegion(
            layout: authorLayout, globalStart: nodeStart + 1 + childrenSize, length: authorLength,
            ref: .quoteAuthor(id), canvasOrigin: authorOrigin,
            emptyLineLeadingIndent: 0, emptyLineHeight: authorEmptyLineHeight)
        return children.leafRegions() + [authorRegion]
    }

    /// The child `BlockStack` + box that owns global position `pos`, with its local offset + index.
    /// Mirrors `TableBlockBox.cellStack(containing:)` for the single-stack (no row) case.
    func childStack(containing pos: Int) -> (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)? {
        for (i, b) in children.boxes.enumerated() {
            if let first = b.leafRegions().first,
               pos >= first.globalStart, pos <= first.globalStart + first.length {
                return (children, b, pos - first.globalStart, i)
            }
        }
        return nil
    }

    /// Collapsed → nodeStart (atom: caret lands at the gap, like CollapsedQuoteBox).
    /// Expanded → a tap at/below the author line routes into the author region (directly editable,
    /// incl. its empty "Add author" placeholder); otherwise into the child stack.
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        if collapsed { return nodeStart }
        if shouldShowAuthor, point.y >= authorOrigin.y {
            // `nodeStart + 1 + childrenSize` is the author region's globalStart (see `leafRegions()`).
            let childrenSize = children.boxes.reduce(0) { $0 + $1.nodeSize }
            return (nodeStart + 1 + childrenSize)
                + authorLayout.closestOffset(toPoint: CGPoint(x: point.x - authorOrigin.x, y: point.y - authorOrigin.y))
        }
        return children.closestPosition(toCanvasPoint: point)
    }

    /// When the (expanded) quote is a single empty paragraph, the host placeholder to show, else nil.
    var placeholderText: String? {
        guard !collapsed, children.boxes.count == 1,
              let first = children.boxes.first as? BlockBox, first.textLength == 0,
              !placeholders.blockQuote.isEmpty else { return nil }
        return placeholders.blockQuote
    }

    /// Collapsed → draws the clipped preview text + the tinted expand glyph (mirrors BlockQuoteBox.draw).
    /// Expanded → draws child boxes. The fill (accent bar + tinted background) is provided by
    /// the `blockQuoteFillRects()` underlay feed in both modes — this method draws only the text content.
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        if collapsed {
            guard let layout = previewLayout else { return }
            let textOrigin = CGPoint(x: frame.minX + leadingPad, y: frame.minY + topInset)
            let tw = previewTextWidth(frame.width)
            let ph = previewHeight
            ctx.saveGState()
            ctx.clip(to: CGRect(x: textOrigin.x, y: textOrigin.y, width: tw, height: ph))
            layout.drawText(in: ctx, at: textOrigin)
            ctx.restoreGState()
            if let image = expandImage {
                image.withTintColor(mapper.theme.accent, renderingMode: .alwaysOriginal).draw(in: expandGlyphRect())
            }
            return
        }
        // Chrome only — child blocks each render via their OWN backing views (hosted by the canvas's
        // recursive `reconcileBlockViews`); flattening them here would double-draw and lose view-hosted
        // content (tables/media). The accent bar + fill are the back-most `blockquoteUnderlay`.
        if let ph = placeholderText, let first = children.boxes.first {
            // Empty quote: draw the host hint left-aligned at the child paragraph's text position (the quote is
            // left-aligned, unlike the centered pull quote). Baseline shift mirrors BlockBox.placeholderDraw.
            let font = mapper.styleSheet.font(for: .body, attributes: .plain)
            let mult = mapper.styleSheet.paragraphStyle(for: .body, attributes: ParagraphAttributes()).lineHeightMultiple
            let origin = CGPoint(x: first.textOrigin.x, y: first.textOrigin.y + (max(mult, 1) - 1) * font.lineHeight / 2)
            NSAttributedString(string: ph, attributes: [.font: font, .foregroundColor: mapper.theme.containerPlaceholder]).draw(at: origin)
        }
        // The author (attribution) line, drawn after the child stack when the quote has content — bold
        // caption, leading-aligned.
        if shouldShowAuthor {
            authorLayout.drawText(in: ctx, at: authorOrigin)
            if authorLength == 0 {
                let font = mapper.styleSheet.font(for: .caption, attributes: CharacterAttributes(bold: true))
                NSAttributedString(string: placeholders.quoteAuthor,
                                   attributes: [.font: font, .foregroundColor: mapper.theme.quoteAuthorPlaceholder]).draw(at: authorOrigin)
            }
        }
        // Draw the collapse glyph only when the quote is worth collapsing (`isCollapsible`: content
        // taller than the ≤maxPreviewLines-line preview), at any nesting level. The flat-quote
        // QuoteCollapseControlsView gating is untouched — this glyph is the BlockQuoteBox's own control.
        if let image = collapseImage, isCollapsible {
            image.withTintColor(mapper.theme.accent, renderingMode: .alwaysOriginal).draw(in: collapseGlyphRect())
        }
    }

    // MARK: - Degenerate single-text-region members (unused: the canvas uses leafRegions())
    // Per-instance (not static): keeps any accidental write to one quote, not all. Mirrors TableBlockBox.
    private let emptyLayout = makeBlockLayout(attributedString: NSAttributedString(string: ""), width: 1)
    var textLayout: BlockLayoutEngine { emptyLayout }
    var textStart: Int { nodeStart }
    var textLength: Int { 0 }
    var textRef: TextNodeRef { .paragraph(id) }
    var textOrigin: CGPoint { frame.origin }
}
#endif

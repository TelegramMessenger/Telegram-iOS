#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One pull-quote block in the canvas: a rich TextKit layout (centered, forced-italic) drawn inside a
/// box with symmetric horizontal and vertical padding. Mirrors `CodeBlockBox` but builds its attributed
/// string via the mapper (rich runs + forced italic/center) instead of a plain monospace string. The
/// pill background + corner marks are added by later tasks via the decorations layer — this box only
/// lays out and draws the (centered, italic) text.
@available(iOS 13.0, *)
final class PullQuoteBox {
    let id: BlockID
    let layout: BlockLayoutEngine
    let mapper: AttributedStringMapper
    let pullQuoteStyle: PullQuoteStyle

    var frame: CGRect = .zero
    var globalStart: Int = 0
    /// Placeholder strings stamped by the canvas in `stampListMarkers()`. Drives the centered
    /// "Type a quote here" hint and the empty-state pill width.
    var placeholders: RichTextEditorPlaceholders = .default

    /// The outer box width last configured via `init`/`setWidth` — construction-time-stable, so geometry that
    /// must be correct BEFORE the canvas assigns `frame` (the empty-line caret indent) reads it instead of the
    /// not-yet-set `frame.width`. Mirrors `MediaBlockBox.layoutWidth`.
    private(set) var layoutWidth: CGFloat

    var leftInset: CGFloat { pullQuoteStyle.horizontalPadding }
    var rightInset: CGFloat { pullQuoteStyle.horizontalPadding }
    var topInset: CGFloat
    var bottomInset: CGFloat

    /// The author (attribution) line's own TextKit layout. Rendered as a bold+ITALIC `.caption` style — unlike
    /// a block quote's bold-only author — bold, italic, and the text color are all ambient (forced here via
    /// `quoteAuthorRenderRuns`, stripped on read-back). Centered like the pull text.
    let authorLayout: BlockLayoutEngine
    /// The author renders centered (matching the pull text / V2 renderer's isPull caption alignment).
    private static let authorParagraph = ParagraphAttributes(alignment: .center)

    init(pullQuote: PullQuote, mapper: AttributedStringMapper, pullQuoteStyle: PullQuoteStyle = .default, width: CGFloat) {
        self.id = pullQuote.id
        self.mapper = mapper
        self.pullQuoteStyle = pullQuoteStyle
        self.topInset = pullQuoteStyle.topInset
        self.bottomInset = pullQuoteStyle.bottomInset
        self.layoutWidth = width
        self.layout = makeBlockLayout(
            attributedString: mapper.attributedString(for: ParagraphBlock(id: pullQuote.id, style: .pullQuote, runs: pullQuote.runs)),
            width: max(width - pullQuoteStyle.horizontalPadding - pullQuoteStyle.horizontalPadding, 1))
        self.authorLayout = makeBlockLayout(
            attributedString: mapper.attributedString(for: ParagraphBlock(
                id: pullQuote.id, style: .caption, paragraph: PullQuoteBox.authorParagraph,
                runs: quoteAuthorRenderRuns(pullQuote.author, textColor: mapper.theme.quoteAuthorText.rgba, italic: true))),
            width: max(width - pullQuoteStyle.horizontalPadding - pullQuoteStyle.horizontalPadding, 1))
    }

    var spacingKind: RichTextBlockSpacingKind { .pullQuote }

    var length: Int { layout.length }
    var textOrigin: CGPoint { CGPoint(x: frame.minX + leftInset, y: frame.minY + topInset) }

    var authorLength: Int { authorLayout.length }
    /// The author line sits below the pull text, inside the same horizontal padding.
    /// NB the author line is placed against the RAW line box, not the V2-corrected height. Author-line
    /// placement is quote INTERIOR geometry, which has no V2 reference in this cycle (the quote-interior
    /// cycle owns it) — correcting it here would shift the attribution 1-2pt with nothing to check it
    /// against. The quote's own HEIGHT is corrected, because that feeds the document's block rhythm.
    var authorOrigin: CGPoint { CGPoint(x: frame.minX + leftInset, y: textOrigin.y + max(layout.boundingHeight, emptyLineHeight) + pullQuoteStyle.authorSpacing) }

    private var authorEmptyLineHeight: CGFloat {
        guard authorLayout.length == 0 else { return 0 }
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        let mult = mapper.styleSheet.paragraphStyle(for: .caption, attributes: PullQuoteBox.authorParagraph,
                                                    list: nil, baseWritingDirection: mapper.baseWritingDirection).lineHeightMultiple
        return font.lineHeight * (mult > 0 ? mult : 1)
    }
    private var authorPlaceholderTextWidth: CGFloat {
        // Placeholder measured in the BOLD+ITALIC caption font (matches the rendered author weight/style).
        let font = mapper.styleSheet.font(for: .caption, attributes: CharacterAttributes(bold: true, italic: true))
        return (placeholders.quoteAuthor as NSString).size(withAttributes: [.font: font]).width
    }
    private var authorEmptyLineIndent: CGFloat {
        guard authorLength == 0 else { return 0 }
        let containerWidth = max(layoutWidth - leftInset - rightInset, 1)
        return max((containerWidth - authorPlaceholderTextWidth) / 2, 0) // centered placeholder's leading edge
    }
    /// Bold caption typing attributes (centered) for the FIRST char typed into an empty author line.
    func authorTypingAttributes() -> [NSAttributedString.Key: Any] {
        var ca = CharacterAttributes(); ca.bold = true; ca.italic = true; ca.foreground = mapper.theme.quoteAuthorText.rgba
        var attrs = mapper.attributes(for: ca, style: .caption)
        attrs[.paragraphStyle] = mapper.styleSheet.paragraphStyle(for: .caption, attributes: PullQuoteBox.authorParagraph,
                                                                  list: nil, baseWritingDirection: mapper.baseWritingDirection)
        return attrs
    }

    /// Placeholder text for an empty pull quote, or nil when non-empty or placeholder string is empty.
    var placeholderText: String? {
        guard layout.length == 0, !placeholders.pullQuote.isEmpty else { return nil }
        return placeholders.pullQuote
    }

    /// Widest laid-out line width (glyph-hugging), for the content-hugging pill. When empty, returns
    /// the placeholder's measured width so the pill hugs it (floored by the Task-10 minWidth).
    var contentWidth: CGFloat {
        if length == 0 {
            guard let ph = placeholderText else { return 0 }
            let font = mapper.styleSheet.font(for: .pullQuote, attributes: .plain)
            return (ph as NSString).size(withAttributes: [.font: font]).width
        }
        return layout.selectionRects(start: 0, end: length).map(\.width).max() ?? 0
    }

    /// Widest laid-out line of the AUTHOR line (or the "Add author" placeholder when empty).
    private var authorContentWidth: CGFloat {
        guard shouldShowAuthor else { return 0 }
        if authorLength == 0 { return authorPlaceholderTextWidth }
        return authorLayout.selectionRects(start: 0, end: authorLength).map(\.width).max() ?? 0
    }
    /// The content-hugging width for the PILL: the WIDER of the pull text (`contentWidth`) and the author line,
    /// so a long author — or the "Add author" placeholder — under a short quote isn't clipped by the pill.
    var pillContentWidth: CGFloat { max(contentWidth, authorContentWidth) }

    private var emptyLineHeight: CGFloat {
        guard layout.length == 0 else { return 0 }
        // Match a single laid-out line's height by applying the pull-quote paragraph style's lineHeightMultiple
        // (TextKit scales each line box by it) — else an empty pull quote is shorter than a one-line one. Mirrors
        // BlockBox.emptyLineHeight.
        let font = mapper.styleSheet.font(for: .pullQuote, attributes: CharacterAttributes())
        let mult = mapper.styleSheet.paragraphStyle(for: .pullQuote, attributes: ParagraphAttributes()).lineHeightMultiple
        return font.lineHeight * (mult > 0 ? mult : 1)
    }

    /// Leading indent for the EMPTY-line caret so it lands at the centered placeholder's leading edge
    /// (→ the container center when there is no placeholder). 0 once any text exists — the centered glyph
    /// layout already carries the position, so adding an indent would double-count. Mirrors the
    /// `contentWidth` / `emptyLineHeight` empty-guards. Placeholder-start (not center) matches the mockup
    /// and the "caret at start" spec decision. Reads `layoutWidth`, NOT `frame.width` — `frame` is `.zero`
    /// until the canvas lays the box out, so this must stay correct before that first layout pass.
    private var emptyLinePlaceholderIndent: CGFloat {
        guard length == 0 else { return 0 }
        let containerWidth = max(layoutWidth - leftInset - rightInset, 1)
        return max((containerWidth - contentWidth) / 2, 0)
    }

    /// Attributes for text typed into a pull quote (italic + centered paragraph style). Used by
    /// `typingAttributeDict` and `insertPullQuoteNewline` so the first character typed into an
    /// empty pull quote is italic/centered, not body-upright-left.
    static func pullQuoteTypingAttributes(_ mapper: AttributedStringMapper) -> [NSAttributedString.Key: Any] {
        let probe = mapper.attributedString(for: ParagraphBlock(id: BlockID("pq-typing"), style: .pullQuote,
                                                                runs: [TextRun(text: " ")]))
        return probe.attributes(at: 0, effectiveRange: nil)
    }
}

@available(iOS 13.0, *)
extension PullQuoteBox: CanvasBlock {
    var rendersAsBlockView: Bool { true }
    var nodeStart: Int { get { globalStart } set { globalStart = newValue } }
    /// The author line is shown only when the quote has content — the author itself has text, OR the pull
    /// text is non-empty. A fresh/empty pull quote hides the author region entirely (no placeholder, no
    /// reserved height, no position tokens, no caret target).
    var shouldShowAuthor: Bool { authorLength > 0 || length > 0 }
    var nodeSize: Int { shouldShowAuthor ? (length + authorLength + 6) : (length + 4) }
    var textLayout: BlockLayoutEngine { layout }
    var textStart: Int { nodeStart + 1 }
    var textLength: Int { length }
    var textRef: TextNodeRef { .pullQuote(id) }
    var height: CGFloat {
        shouldShowAuthor
            ? quoteOnlyHeight + pullQuoteStyle.authorSpacing + max(authorLayout.boundingHeight, authorEmptyLineHeight)
            : quoteOnlyHeight
    }
    /// The box's height AS IF there were no author line — mirrors `height` minus the author + gap terms.
    /// Used to bracket the pull-quote corner marks around the QUOTE TEXT only (the pill background still
    /// spans the full `height`, author included).
    var quoteOnlyHeight: CGFloat {
        topInset + max(layout.correctedBoundingHeight, emptyLineHeight) + bottomInset
    }
    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        let inner = max(width - leftInset - rightInset, 1)
        let base = max(layout.correctedBoundingHeight(forWidth: inner), emptyLineHeight) + topInset + bottomInset
        guard shouldShowAuthor else { return base }
        return base + pullQuoteStyle.authorSpacing + max(authorLayout.boundingHeight(forWidth: inner), authorEmptyLineHeight)
    }
    func setWidth(_ width: CGFloat) {
        layoutWidth = width
        let inner = max(width - leftInset - rightInset, 1)
        layout.setWidth(inner)
        authorLayout.setWidth(inner)
    }
    func currentBlock() -> Block {
        .pullQuote(PullQuote(id: id,
                             runs: mapper.runs(from: layout.attributedString, style: .pullQuote),
                             author: quoteAuthorStripAmbientStyle(mapper.runs(from: authorLayout.attributedString, style: .caption),
                                                                  textColor: mapper.theme.quoteAuthorText.rgba, italic: true)))
    }
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        // A tap at/below the author line's top routes into the author region (so the author — including
        // its empty "Add author" placeholder — is directly tappable); otherwise into the pull text. Only
        // when the author is shown; a hidden author has no area to tap.
        if shouldShowAuthor, point.y >= authorOrigin.y {
            return (nodeStart + length + 3)
                + authorLayout.closestOffset(toPoint: CGPoint(x: point.x - authorOrigin.x, y: point.y - authorOrigin.y))
        }
        return textStart + layout.closestOffset(toPoint: CGPoint(x: point.x - textOrigin.x, y: point.y - textOrigin.y))
    }
    func leafRegions() -> [LeafTextRegion] {
        var regions = [LeafTextRegion(layout: layout, globalStart: nodeStart + 1, length: length,
                                      ref: .pullQuote(id), canvasOrigin: textOrigin,
                                      emptyLineLeadingIndent: emptyLinePlaceholderIndent, emptyLineHeight: emptyLineHeight)]
        if shouldShowAuthor {
            regions.append(LeafTextRegion(layout: authorLayout, globalStart: nodeStart + length + 3, length: authorLength,
                                          ref: .quoteAuthor(id), canvasOrigin: authorOrigin,
                                          emptyLineLeadingIndent: authorEmptyLineIndent, emptyLineHeight: authorEmptyLineHeight))
        }
        return regions
    }
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        // The pill background + corner marks are added by later tasks via the decorations layer.
        // This box draws only the (centered, italic) text.
        layout.drawText(in: ctx, at: textOrigin)
        if let ph = placeholderText {
            let font = mapper.styleSheet.font(for: .pullQuote, attributes: .plain)
            let ps = NSMutableParagraphStyle(); ps.alignment = .center
            let rect = CGRect(x: frame.minX + leftInset, y: textOrigin.y,
                              width: max(frame.width - leftInset - rightInset, 1), height: frame.height - topInset - bottomInset)
            NSAttributedString(string: ph, attributes: [.font: font, .foregroundColor: mapper.theme.containerPlaceholder,
                                                        .paragraphStyle: ps]).draw(in: rect)
        }
        if shouldShowAuthor {
            authorLayout.drawText(in: ctx, at: authorOrigin)
            if authorLength == 0 {
                let font = mapper.styleSheet.font(for: .caption, attributes: CharacterAttributes(bold: true, italic: true))
                let ps = NSMutableParagraphStyle(); ps.alignment = .center
                let rect = CGRect(x: frame.minX + leftInset, y: authorOrigin.y,
                                  width: max(frame.width - leftInset - rightInset, 1), height: authorEmptyLineHeight)
                NSAttributedString(string: placeholders.quoteAuthor,
                                   attributes: [.font: font, .foregroundColor: mapper.theme.quoteAuthorPlaceholder, .paragraphStyle: ps]).draw(in: rect)
            }
        }
    }
}
#endif

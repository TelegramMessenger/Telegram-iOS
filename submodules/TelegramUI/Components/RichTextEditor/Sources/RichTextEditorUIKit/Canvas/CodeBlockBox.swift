#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One code block in the canvas: a monospace TextKit layout (multi-line; interior "\n"s) drawn inside a
/// plain, `tableHeader`-coloured band that spans its container's interior edge to edge, with the code
/// text at the paragraph inset of its nesting level. Mirrors `BlockBox` but is a distinct `Block.code`
/// type and builds its own monospace attributed string (so no `ParagraphStyleName`/StyleSheet change).
/// Inline formatting is not represented inside a code block — runs are plain.
@available(iOS 13.0, *)
final class CodeBlockBox {
    let id: BlockID
    let layout: BlockLayoutEngine
    /// The language line's own TextKit layout — the editable "Language" region. ALWAYS present, even when
    /// the language is nil/empty (unlike a quote's author region, which appears only once its quote has
    /// content): the field is always visible, which is also what keeps the code text's offset stable.
    let languageLayout: BlockLayoutEngine
    let mapper: AttributedStringMapper

    var frame: CGRect = .zero
    var globalStart: Int = 0
    /// Host placeholder strings (stamped by the canvas in `stampListMarkers`). Drives the empty-code hint.
    var placeholders: RichTextEditorPlaceholders = .default
    /// Monospace point size — matches the quote's 15pt so a code block reads at the same scale as a quote.
    static let fontSize: CGFloat = 15

    /// How far this block's BAND extends past its frame on each side, to reach the enclosing
    /// container's interior edges. GEOMETRIC sides (`minXSide` is always the smaller-x edge), matching
    /// the renderer's `InstantPageV2ChildBleed`. Assigned by the `BlockStack` that lays this box out,
    /// not at construction — it moves with the host's content margins while the box does not.
    var horizontalBleed: (minXSide: CGFloat, maxXSide: CGFloat) = (0, 0)

    var topInset: CGFloat
    var bottomInset: CGFloat

    /// The monospace face code renders in. Extracted so the metrics-only readers (empty-line height)
    /// need no colour.
    static var codeFont: UIFont {
        UIFont.monospacedSystemFont(ofSize: CodeBlockBox.fontSize, weight: .regular)
    }

    /// `textColor` is REQUIRED, not defaulted: an attributed string with no `.foregroundColor` draws
    /// BLACK, which is invisible on a dark background — the bug this parameter exists to prevent.
    /// It is render-only and never reaches the model (`currentCode()` reads the plain string back).
    static func codeAttributes(textColor: UIColor) -> [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byWordWrapping
        return [.font: codeFont,
                .paragraphStyle: ps,
                .foregroundColor: textColor]
    }

    static func attributedString(for code: CodeBlock, textColor: UIColor) -> NSAttributedString {
        NSAttributedString(string: code.text, attributes: codeAttributes(textColor: textColor))
    }

    /// Attributes the language line renders with: sans + bold at the BODY size — the same derivation the
    /// quote author uses — so it cannot be set to something the renderer disagrees with. NOT lowercased:
    /// the field shows what the author typed. The renderer lowercases at display
    /// (`instantPageV2CodeLanguageDisplayText`), so casing is a display concern there, not a model one.
    static func languageAttributes(mapper: AttributedStringMapper) -> [NSAttributedString.Key: Any] {
        let font = FontResolver.font(spec: mapper.styleSheet.metrics.body, bold: true, italic: false, family: nil)
        return [.font: font, .foregroundColor: mapper.theme.codeLanguageText]
    }

    static func languageAttributedString(for language: String?, mapper: AttributedStringMapper) -> NSAttributedString {
        NSAttributedString(string: language ?? "", attributes: languageAttributes(mapper: mapper))
    }

    init(code: CodeBlock, mapper: AttributedStringMapper, width: CGFloat) {
        self.id = code.id
        self.mapper = mapper
        self.topInset = mapper.styleSheet.codeVerticalInset
        self.bottomInset = mapper.styleSheet.codeVerticalInset
        self.languageLayout = makeBlockLayout(
            attributedString: CodeBlockBox.languageAttributedString(for: code.language, mapper: mapper),
            width: max(width - mapper.styleSheet.codeHorizontalInset * 2, 1))
        // With no `codeHorizontalInset` the code text measures at the FULL content width — the same
        // measure a sibling paragraph gets, which is what makes the two align on both edges. A host
        // that indents the text inside its band narrows the measure by that inset on each side.
        self.layout = makeBlockLayout(
            attributedString: CodeBlockBox.attributedString(for: code, textColor: mapper.theme.primaryText),
            width: max(width - mapper.styleSheet.codeHorizontalInset * 2, 1))
    }

    var spacingKind: RichTextBlockSpacingKind { .preformatted }

    /// The band: the frame grown outward by the bleed. This is the block's full drawn extent, which
    /// `BlockBackingView` clips to — a bleed missing here renders as a band clipped to the text column.
    var blockViewFrame: CGRect {
        CGRect(x: frame.minX - horizontalBleed.minXSide, y: frame.minY,
               width: frame.width + horizontalBleed.minXSide + horizontalBleed.maxXSide,
               height: frame.height)
    }

    /// Extra inset of the code text inward from the band's edges (host knob; 0 by default, which is
    /// the renderer's rule — the text sits at the paragraph inset and the BAND bleeds outward past it).
    var horizontalInset: CGFloat { mapper.styleSheet.codeHorizontalInset }

    var languageLength: Int { languageLayout.length }

    /// A single empty line's height in the language font. The line is always shown, so an empty language
    /// still reserves a line — that is where the "Language" placeholder is drawn.
    private var languageEmptyLineHeight: CGFloat {
        guard languageLayout.length == 0 else { return 0 }
        return (CodeBlockBox.languageAttributes(mapper: mapper)[.font] as? UIFont)?.lineHeight ?? 0
    }

    /// Height the language line occupies above the code, gap included. UNCONDITIONAL — a language-less
    /// code block still reserves it, and is therefore about one line taller in the editor than the message
    /// it renders to (which draws no language line at all). That is the cost of an always-visible field.
    var languageLineExtent: CGFloat {
        max(languageLayout.correctedBoundingHeight, languageEmptyLineHeight) + mapper.styleSheet.codeLanguageSpacing
    }

    /// Canvas origin of the language line: the band's top-left text position, above the code.
    var languageOrigin: CGPoint { CGPoint(x: frame.minX + horizontalInset, y: frame.minY + topInset) }

    var length: Int { layout.length }
    var textOrigin: CGPoint {
        CGPoint(x: frame.minX + horizontalInset, y: frame.minY + topInset + languageLineExtent)
    }

    private var emptyLineHeight: CGFloat {
        guard layout.length == 0 else { return 0 }
        return CodeBlockBox.codeFont.lineHeight
    }

    /// Placeholder text for an empty code block, or nil when non-empty or the placeholder string is empty.
    var placeholderText: String? {
        guard layout.length == 0, !placeholders.codeBlock.isEmpty else { return nil }
        return placeholders.codeBlock
    }

    /// The tokens currently painted, so an identical answer can be recognised without rebuilding.
    private(set) var syntaxHighlight: [RichTextSyntaxToken] = []

    /// Paint `tokens` over the code text. Returns true when the layout's string actually changed.
    ///
    /// Rebuilding the whole string is lossless HERE specifically: a code block's runs are plain by
    /// construction (no link, emoji, inline-code or spoiler attribute lives inside one), so there is
    /// nothing else in the string to preserve. The rebuilt string is assigned **only when it differs** —
    /// an unconditional re-assign resets the spoiler-hide ranges and spins `layoutIfNeeded`.
    ///
    /// A token range that does not fit the current text means the answer describes text the user has since
    /// edited: the WHOLE set is dropped rather than applied partially, which would colour arbitrary spans.
    @discardableResult
    func applySyntaxHighlight(_ tokens: [RichTextSyntaxToken]) -> Bool {
        // NOTE: this rebuilds the block's whole text storage, which would pull the rug out from under an
        // active IME composition. That is safe TODAY only because marked text is confined to top-level body
        // paragraphs — `isBodyParagraphPosition` requires `box is BlockBox`, and a code block is not one, so
        // a composition cannot exist here. If IME support ever reaches code blocks, this needs a guard that
        // skips a block hosting the marked range.
        let text = layout.attributedString.string as NSString
        var accepted = tokens
        for token in tokens {
            if token.range.location < 0 || token.range.length <= 0 || token.range.location + token.range.length > text.length {
                accepted = []
                break
            }
        }
        if accepted == syntaxHighlight { return false }

        let rebuilt = NSMutableAttributedString(attributedString: NSAttributedString(
            string: text as String, attributes: CodeBlockBox.codeAttributes(textColor: mapper.theme.primaryText)))
        for token in accepted {
            rebuilt.addAttribute(.foregroundColor, value: token.color, range: token.range)
        }
        guard !rebuilt.isEqual(to: layout.attributedString) else {
            syntaxHighlight = accepted
            return false
        }
        syntaxHighlight = accepted
        layout.attributedString = rebuilt
        layout.bumpRenderVersion()
        return true
    }

    func currentCode() -> CodeBlock {
        // Trim, and normalize an all-whitespace/empty line back to nil — "" and nil are the same state
        // (`languageUTF16Count` treats them identically, and the renderer draws no line for either).
        let typed = languageLayout.attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return CodeBlock(id: id, language: typed.isEmpty ? nil : typed,
                         runs: [TextRun(text: layout.attributedString.string)])
    }
}

@available(iOS 13.0, *)
extension CodeBlockBox: CanvasBlock {
    var rendersAsBlockView: Bool { true }
    var nodeStart: Int { get { globalStart } set { globalStart = newValue } }
    /// container(2) + language paragraph(lang + 2) + code paragraph(code + 2). Matches `DocumentTree`'s
    /// `.code` mapping — `CodeLanguageRegionTests.test_nodeSize_matchesDocumentTree` is that check.
    var nodeSize: Int { length + languageLength + 6 }
    var textLayout: BlockLayoutEngine { layout }
    /// The PRIMARY region stays the CODE text — `activeStack` resolves boxes by it, which is what keeps
    /// every existing code-block edit path inert in the language line. See `DocumentCanvasView+Editing`.
    var textStart: Int { globalStart + languageLength + 3 }
    var textLength: Int { length }
    var textRef: TextNodeRef { .code(id) }
    var height: CGFloat {
        max(layout.correctedBoundingHeight, emptyLineHeight) + languageLineExtent + topInset + bottomInset
    }
    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        max(layout.correctedBoundingHeight(forWidth: max(width - horizontalInset * 2, 1)), emptyLineHeight)
            + languageLineExtent + topInset + bottomInset
    }
    func setWidth(_ width: CGFloat) {
        let inner = max(width - horizontalInset * 2, 1)
        layout.setWidth(inner)
        languageLayout.setWidth(inner)
    }
    func currentBlock() -> Block { .code(currentCode()) }
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        // A tap above the code text routes into the language region, so the always-visible "Language"
        // placeholder is directly tappable. Mirrors `PullQuoteBox`'s author branch, inverted — the
        // language line is LEADING, so the comparison is `<` against the code's origin, not `>=`.
        if point.y < textOrigin.y {
            return (globalStart + 1) + languageLayout.closestOffset(
                toPoint: CGPoint(x: point.x - languageOrigin.x, y: point.y - languageOrigin.y))
        }
        return textStart + layout.closestOffset(toPoint: CGPoint(x: point.x - textOrigin.x, y: point.y - textOrigin.y))
    }
    func leafRegions() -> [LeafTextRegion] {
        // DOCUMENT ORDER — language first. `DocumentCanvasView+Navigation` indexes `allLeafRegions()`
        // positionally, so a wrong order breaks arrow-key traversal. Note this makes `leafRegions().first`
        // the LANGUAGE region for a code box: any caller that means "the box's primary text" must use
        // `textStart`, not `.first` (see `activeStack`).
        [LeafTextRegion(layout: languageLayout, globalStart: globalStart + 1, length: languageLength,
                        ref: .codeLanguage(id), canvasOrigin: languageOrigin,
                        emptyLineLeadingIndent: 0, emptyLineHeight: languageEmptyLineHeight),
         LeafTextRegion(layout: layout, globalStart: textStart, length: length,
                        ref: .code(id), canvasOrigin: textOrigin,
                        emptyLineLeadingIndent: 0, emptyLineHeight: emptyLineHeight)]
    }
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        // The band is painted HERE, not by the shared `BlockquoteUnderlay`: a code block is no longer
        // a quote variant, and putting the fill on the box is also what makes a NESTED code block
        // filled at all — the underlay's feed only ever walked top-level boxes.
        mapper.theme.codeBackground.setFill()
        let radius = mapper.styleSheet.codeCornerRadius
        if radius > 0 {
            // Explicit path on `ctx` rather than `UIBezierPath.fill()`, which draws into
            // `UIGraphicsGetCurrentContext()` — not necessarily this one (a table cell draws through
            // a translated context).
            ctx.addPath(UIBezierPath(roundedRect: blockViewFrame, cornerRadius: radius).cgPath)
            ctx.fillPath()
        } else {
            ctx.fill(blockViewFrame)
        }
        languageLayout.drawText(in: ctx, at: languageOrigin)
        if languageLength == 0, !placeholders.codeLanguage.isEmpty {
            var attrs = CodeBlockBox.languageAttributes(mapper: mapper)
            attrs[.foregroundColor] = mapper.theme.codeLanguagePlaceholder
            NSAttributedString(string: placeholders.codeLanguage, attributes: attrs).draw(at: languageOrigin)
        }
        layout.drawText(in: ctx, at: textOrigin)
        if let ph = placeholderText {
            NSAttributedString(string: ph, attributes: [
                .font: CodeBlockBox.codeFont,
                .foregroundColor: mapper.theme.containerPlaceholder
            ]).draw(at: textOrigin)
        }
    }
}
#endif

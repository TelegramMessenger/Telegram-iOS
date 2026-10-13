#if canImport(UIKit)
import UIKit
import CoreText
import RichTextEditorCore

@available(iOS 13.0, *)
extension NSAttributedString.Key {
    /// Marks a run as inline code (GFM `code`). At render time the mapper swaps in a monospaced font
    /// + subtle background; on read-back it round-trips to `CharacterAttributes.inlineCode` (and
    /// suppresses fontFamily/highlight derivation so the mono font + code background don't leak into
    /// the model).
    static let rtInlineCode = NSAttributedString.Key("RTInlineCode")
    /// Marks a run as a spoiler. Render-only storage marker (the `rtInlineCode` precedent); the visible
    /// hide is a SEPARATE display-only `.foregroundColor` rendering attribute (see `BlockLayout`), so this
    /// marker carries no styling and round-trips cleanly to `CharacterAttributes.spoiler`.
    static let rtSpoiler = NSAttributedString.Key("RTSpoiler")
    /// Marks a run as USER-bold (the toolbar/model `CharacterAttributes.bold`), decoupling model bold from the
    /// rendered font's `.traitBold` — which the iOS "Bold Text" accessibility setting forces onto the script
    /// font TextKit substitutes for Arabic/Hebrew/CJK regardless of user intent. Render-only (the `rtInlineCode`
    /// precedent); read back to `CharacterAttributes.bold`, never persisted to the Core model.
    static let rtBold = NSAttributedString.Key("RTBold")
    /// Marks a formula run. With a host renderer the visible storage is one `U+FFFC` attachment; without
    /// one it falls back to raw LaTeX text. In both cases read-back restores `CharacterAttributes.formula`.
    static let rtFormula = NSAttributedString.Key("RTFormula")
}

/// Converts between the Core model and `NSAttributedString` for one paragraph block.
@available(iOS 13.0, *)
public struct AttributedStringMapper {
    public let styleSheet: StyleSheet
    /// Square-side multiplier for inline emoji (× the font's ascender+|descender|). Baked into each
    /// `EmojiTextAttachment`, so a change takes effect on the next reload.
    public let emojiScale: CGFloat
    /// Theme colors used for render-time defaults (primary/secondary text, link accent). Mutable so a
    /// host theme change can be applied to the shared mapper before the next reload.
    public var theme: RichTextEditorTheme
    /// Base writing direction baked into every paragraph style this mapper builds. `.natural` (default)
    /// lets TextKit auto-detect per paragraph; the whole-document override sets `.leftToRight`/`.rightToLeft`.
    public var baseWritingDirection: NSWritingDirection
    /// Host-provided formula renderer. `nil` (or returning nil for invalid LaTeX) makes formula runs
    /// display as raw LaTeX while preserving semantic metadata.
    public var formulaRenderer: ((RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?)?
    /// Host-provided button type icon, already tinted to the colour it is handed. A nil RETURN means
    /// this action has no icon, and the pill then reserves no width for one either — one question with
    /// one answer, so what is drawn and what was measured cannot disagree. (An icon that exists but
    /// whose image could not be loaded is a non-nil `RichTextButtonIcon` with a nil `image`; see there.)
    ///
    /// It has to come from the host: the icon depends on the button's ACTION, and the editor's
    /// Telegram-free model carries every action it cannot name as an opaque `.unsupported` blob. Only
    /// the host can decode that back into the action the renderer will resolve an icon from.
    public var buttonIconProvider: ((ButtonAction) -> RichTextButtonIcon?)?

    public init(styleSheet: StyleSheet = .default, emojiScale: CGFloat = 1.0,
                theme: RichTextEditorTheme = .default,
                baseWritingDirection: NSWritingDirection = .natural,
                formulaRenderer: ((RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?)? = nil,
                buttonIconProvider: ((ButtonAction) -> RichTextButtonIcon?)? = nil) {
        self.styleSheet = styleSheet
        self.emojiScale = emojiScale
        self.theme = theme
        self.baseWritingDirection = baseWritingDirection
        self.formulaRenderer = formulaRenderer
        self.buttonIconProvider = buttonIconProvider
    }

    /// A copy of this mapper that renders table-cell content (a smaller body/quote base size, see
    /// `StyleSheet.tableCells`), preserving the emoji scale and theme. Each `TableBlockBox` derives one
    /// for its cells so the denser cell font is consistent across edits (split/merge boxes inherit it
    /// via their source box's `mapper`).
    public func tableCellVariant() -> AttributedStringMapper {
        AttributedStringMapper(styleSheet: .tableCells, emojiScale: emojiScale, theme: theme,
                               baseWritingDirection: baseWritingDirection, formulaRenderer: formulaRenderer,
                               buttonIconProvider: buttonIconProvider)
    }

    /// A copy that renders body/pull-quote content at `size` points, PRESERVING this mapper's
    /// stylesheet customizations (quote insets, spacing, metrics), emoji scale, theme, and writing direction.
    /// (Unlike `tableCellVariant()`, which swaps in the fixed `.tableCells` stylesheet.)
    public func withBodyFontSize(_ size: CGFloat) -> AttributedStringMapper {
        var s = styleSheet
        s.metrics.body.size = size
        return AttributedStringMapper(styleSheet: s, emojiScale: emojiScale, theme: theme,
                                      baseWritingDirection: baseWritingDirection, formulaRenderer: formulaRenderer,
                                      buttonIconProvider: buttonIconProvider)
    }

    /// Points to enlarge a rendered inline emoji beyond its glyph box, per paragraph style (decoupled from
    /// the layout box, so it never expands the line — see `EmojiTextAttachment.renderBoost`). Body emoji
    /// read small at their bare glyph box, so they get +4pt; other styles use their glyph box as-is.
    public func emojiRenderBoost(for style: ParagraphStyleName) -> CGFloat {
        return style == .body ? 4.0 : 0.0
    }

    func formulaAttachment(latex: String, attributes: [NSAttributedString.Key: Any]) -> FormulaTextAttachment? {
        guard let formulaRenderer else {
            return nil
        }
        let font = (attributes[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
        let textColor = (attributes[.foregroundColor] as? UIColor) ?? theme.primaryText
        guard let result = formulaRenderer(RichTextFormulaRenderContext(
            latex: latex,
            fontSize: font.pointSize,
            textColor: textColor
        )) else {
            return nil
        }
        return FormulaTextAttachment(latex: latex, renderResult: result)
    }

    /// The ONE construction path for both inline and block-row pills — they must agree on whether `size`
    /// includes the padding, because the label centring reads exactly `size.width - 2 * horizontalPadding`.
    /// Two independent constructions drifted apart once already in the renderer.
    /// `horizontalPadding` overrides the padding this pill kind would otherwise take. Passed by the row
    /// packer's tight-fallback measurement (`richTextMeasureRowButton`); every other caller leaves it nil.
    func buttonAttachment(button: ButtonRef, isBlockPill: Bool, maxWidth: CGFloat?,
                          horizontalPadding: CGFloat? = nil) -> ButtonTextAttachment {
        let metrics = styleSheet.metrics.button
        // A link-styled ROW pill draws no background, so it takes no inner padding either — its label
        // sits flush and reads as a link. Mirrors `instantPageBlockButtonPadding(for:)` in the renderer.
        let hPad: CGFloat
        if let horizontalPadding {
            hPad = horizontalPadding
        } else if isBlockPill {
            hPad = button.isLink ? 0.0 : metrics.blockHorizontalPadding
        } else {
            hPad = metrics.inlineHorizontalPadding
        }
        let vPad = metrics.verticalPadding
        let fontSize = isBlockPill ? metrics.blockFontSize : metrics.inlineFontSize

        // A button label carries its OWN typography rather than inheriting the paragraph's: semibold, at a
        // fixed size that does not scale with any host font-size setting (the renderer does the same).
        let label = NSMutableAttributedString()
        for run in button.label {
            var attrs = attributes(for: run.attributes, style: .body)
            // Strip only a NESTED BUTTON attachment (not representable inside a label). An EMOJI
            // attachment must survive: it reserves the emoji's advance in the measured label, and
            // `ButtonPillView.syncEmoji` locates it to host a live view over the pill.
            if attrs[.attachment] is ButtonTextAttachment {
                attrs.removeValue(forKey: .attachment)
            }
            attrs[.paragraphStyle] = nil
            label.append(NSAttributedString(string: run.text, attributes: attrs))
        }
        if label.length > 0 {
            label.addAttribute(.font, value: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                               range: NSRange(location: 0, length: label.length))
        }
        let colors = theme.resolvedButtonColors(color: button.color, isDisabled: button.action == .disabled,
                                                isLink: isBlockPill && button.isLink)
        // Resolved BEFORE measuring, because whether there is an icon is also whether there is width to
        // reserve for one. One question, one answer — a separate "does it have an icon" predicate could
        // disagree with what is actually drawn.
        let icon = buttonIconProvider?(button.action)
        // Only an INLINE pill pays width for its icon; a block pill's badge overlays its fill and the
        // row packer keeps the label clear of it with `blockIconReserve` instead.
        let iconReserve: CGFloat = (icon != nil && !isBlockPill) ? styleSheet.metrics.button.inlineIconReserve : 0.0

        var effective: NSAttributedString = label
        var truncated = false
        if let maxWidth {
            (effective, truncated) = truncatedButtonLabel(label, availableWidth: max(0.0, maxWidth - hPad * 2.0 - iconReserve))
        }

        var ascent: CGFloat = 0.0
        var descent: CGFloat = 0.0
        var inkWidth: CGFloat = 0.0
        if effective.length > 0 {
            let line = CTLineCreateWithAttributedString(effective)
            inkWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        } else {
            // An empty label still needs a real box, or the pill collapses and cannot be tapped.
            let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            ascent = font.ascender
            descent = -font.descender
        }
        return ButtonTextAttachment(
            button: button,
            labelString: effective,
            size: CGSize(width: inkWidth + hPad * 2.0 + iconReserve, height: ascent + descent + vPad * 2.0),
            ascent: ascent + vPad,
            descent: descent + vPad,
            horizontalPadding: hPad,
            isTruncated: truncated,
            colors: colors,
            icon: icon,
            iconReserve: iconReserve,
            isBlockPill: isBlockPill
        )
    }

    /// Whether a button carries a type icon — the RESERVE question, asked without rasterising.
    ///
    /// Falls back to `richTextButtonHasBadge` when no host provider is registered. That coarse rule is
    /// what the row packer used before there was a provider, so an unconfigured editor (a preview, a
    /// test) keeps the geometry it had rather than silently re-flowing its rows; a configured one gets
    /// the renderer's exact answer, including for the actions the editor's own model cannot name.
    func buttonHasIcon(_ action: ButtonAction) -> Bool {
        if let buttonIconProvider {
            return buttonIconProvider(action) != nil
        }
        return richTextButtonHasBadge(action)
    }

    func attributedFormulaString(latex: String, attributes baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var attrs = baseAttributes
        attrs[.rtFormula] = latex
        attrs.removeValue(forKey: .attachment)
        if let attachment = formulaAttachment(latex: latex, attributes: attrs) {
            attrs[.attachment] = attachment
            return NSAttributedString(string: "\u{FFFC}", attributes: attrs)
        } else {
            return NSAttributedString(string: latex, attributes: attrs)
        }
    }

    public func attributes(for ca: CharacterAttributes, style: ParagraphStyleName) -> [NSAttributedString.Key: Any] {
        if let emoji = ca.emoji {
            // An emoji run is purely the inline atom: an invisible square spacer sized to the style font.
            // No other char attributes apply (they'd be ignored on read-back anyway).
            return [.font: styleSheet.font(for: style, attributes: ca),
                    .attachment: EmojiTextAttachment(ref: emoji, scale: emojiScale,
                                                     renderBoost: emojiRenderBoost(for: style))]
        }
        if let button = ca.button {
            // A button run is purely the inline atom, like an emoji: no other character attribute applies
            // (they would be ignored on read-back anyway, and a pill draws its own label typography).
            return [.font: styleSheet.font(for: style, attributes: ca),
                    .attachment: buttonAttachment(button: button, isBlockPill: false, maxWidth: nil)]
        }
        var dict: [NSAttributedString.Key: Any] = [:]
        dict[.font] = styleSheet.font(for: style, attributes: ca)
        if let formula = ca.formula {
            dict[.rtFormula] = formula
            dict[.foregroundColor] = ca.foreground?.uiColor ?? (style == .caption ? theme.secondaryText : theme.primaryText)
            return dict
        }
        if ca.bold { dict[.rtBold] = true }   // user-intent marker (read back as CharacterAttributes.bold)
        // Un-colored runs render in the theme's per-style default (secondary for captions, else primary).
        // This default is stripped back to nil on read-back (characterAttributes(from:style:)), so it never
        // persists into the model and re-themes cleanly.
        dict[.foregroundColor] = ca.foreground?.uiColor ?? (style == .caption ? theme.secondaryText : theme.primaryText)
        if let hl = ca.highlight { dict[.backgroundColor] = hl.uiColor }
        if ca.underline { dict[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if ca.strikethrough { dict[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let link = ca.link {
            dict[.link] = link
            // Visible styling is render-derived from the link and suppressed on read-back (see
            // characterAttributes(from:)), mirroring the rtInlineCode precedent — so it never
            // contaminates the model's foreground/underline fields. If a run is also inline-code, the
            // code font/background win visually; both flags still round-trip independently.
            dict[.foregroundColor] = theme.accent
            // No underline: reference design shows links as accent-colored text only.
        }
        if let b = ca.baselineOffset { dict[.baselineOffset] = b }
        if ca.inlineCode {
            let size = styleSheet.font(for: style, attributes: ca).pointSize
            dict[.font] = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
            dict[.backgroundColor] = theme.inlineCodeBackground
            dict[.rtInlineCode] = true
        }
        if ca.spoiler { dict[.rtSpoiler] = true }
        return dict
    }

    /// True when a run's `.traitBold` is an AMBIENT display artifact rather than user emphasis — specifically
    /// the bold the iOS "Bold Text" accessibility setting forces onto the SCRIPT FONT TextKit substitutes for
    /// glyphs the base font can't render (Arabic/Hebrew/CJK). Under that setting a substituted font carries
    /// `.traitBold` whether or not the user toggled bold, so the rendered font alone can't tell them apart; we
    /// re-substitute the NON-bold style base for the run's text and, if THAT ambient font is also bold, treat
    /// the run's bold as ambient (so it must not round-trip into the model — the `fontFamily` precedent). A run
    /// whose font family matches the non-substituted base (e.g. Latin) can only be bold via a user toggle, so
    /// it is always trusted. Cost is incurred only for already-bold, substituted runs (rare).
    private func boldIsAmbient(renderedFont: UIFont, text: String, style: ParagraphStyleName, ca: CharacterAttributes) -> Bool {
        guard !text.isEmpty else { return false }
        var ambientCA = ca; ambientCA.bold = false
        let base = styleSheet.font(for: style, attributes: ambientCA)   // the non-user-bold base for this run
        // Same family ⇒ no substitution happened ⇒ bold can only be a user toggle (never ambient).
        guard renderedFont.familyName != base.familyName else { return false }
        let ns = text as NSString
        let substituted = CTFontCreateForString(base as CTFont, ns, CFRange(location: 0, length: ns.length)) as UIFont
        return substituted.fontDescriptor.symbolicTraits.contains(.traitBold)
    }

    public func characterAttributes(from dict: [NSAttributedString.Key: Any], style: ParagraphStyleName = .body,
                                    text: String? = nil) -> CharacterAttributes {
        var ca = CharacterAttributes()
        if let att = dict[.attachment] as? FormulaTextAttachment {
            ca.formula = att.latex
            return ca
        }
        if let att = dict[.attachment] as? ButtonTextAttachment {
            ca.button = att.button   // button-only; the render-time label/colour never enter the model
            return ca
        }
        if let att = dict[.attachment] as? EmojiTextAttachment {
            ca.emoji = att.ref   // emoji-only; never leak the spacer font/etc. into the model
            return ca
        }
        let isCode = (dict[.rtInlineCode] as? Bool) == true
        if let font = dict[.font] as? UIFont {
            let traits = font.fontDescriptor.symbolicTraits
            // Pull quotes force italic at render time (ambient); strip it on read-back so it never
            // persists into the model. Other styles round-trip italic normally.
            ca.italic = (style == .pullQuote) ? false : traits.contains(.traitItalic)
            // Bold comes from the user-intent marker when present (decoupled from the rendered `.traitBold`,
            // which system "Bold Text" forces onto substituted scripts). Storage built/edited by this editor
            // always carries the marker (forward path + toggle; TextKit font-fixing rewrites only `.font`).
            // For marker-less storage (e.g. an RTF-imported NSAttributedString) fall back to the ambient-
            // stripped trait so external bold still reads while system/substitution bold does not leak.
            if let userBold = dict[.rtBold] as? Bool {
                ca.bold = userBold
            } else {
                ca.bold = traits.contains(.traitBold)
                if ca.bold, !isCode, let text, boldIsAmbient(renderedFont: font, text: text, style: style, ca: ca) {
                    ca.bold = false
                }
            }
            if !isCode {
                // Font SIZE is pinned on read-back so a run keeps its rendered size when moved across
                // contexts (e.g. a 15pt table cell — see TableBlockBoxTests). Font FAMILY is NOT captured:
                // it is purely display. TextKit's automatic font substitution for scripts the style font
                // can't render (Arabic, Hebrew, CJK, …) rewrites `.font` in storage to a script-specific
                // family; capturing that would bake a display artifact into the model and visibly change
                // the font on the next rebuild (e.g. the paragraph merge on backspace). The model's
                // fontFamily is only ever an explicit, user-/import-set value (forward-applied by `font(for:)`).
                ca.fontSize = Double(font.pointSize)
            }
        }
        if isCode { ca.inlineCode = true }
        let hasLink = dict[.link] != nil
        // A linked run keeps foreground == nil (the accent is render-only). For a normal run, a foreground
        // equal to the theme's per-style default is the render-injected default → treat as unset (nil), so
        // the model stays clean and re-themable; only a genuinely different color round-trips as explicit.
        if !hasLink, let color = dict[.foregroundColor] as? UIColor {
            let rgba = color.rgba
            let styleDefault = (style == .caption ? theme.secondaryText : theme.primaryText).rgba
            ca.foreground = (rgba == styleDefault) ? nil : rgba
        }
        if !isCode, let bg = dict[.backgroundColor] as? UIColor { ca.highlight = bg.rgba }
        if !hasLink, let u = dict[.underlineStyle] as? Int, u != 0 { ca.underline = true }
        if let s = dict[.strikethroughStyle] as? Int, s != 0 { ca.strikethrough = true }
        if let link = dict[.link] as? String { ca.link = link }
        else if let url = dict[.link] as? URL { ca.link = url.absoluteString }
        if let b = dict[.baselineOffset] as? Double { ca.baselineOffset = b }
        else if let b = dict[.baselineOffset] as? CGFloat { ca.baselineOffset = Double(b) }
        if (dict[.rtSpoiler] as? Bool) == true { ca.spoiler = true }
        if let formula = dict[.rtFormula] as? String {
            ca.formula = text ?? formula
        }
        return ca
    }

    public func attributedString(for block: ParagraphBlock) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphStyle = styleSheet.paragraphStyle(for: block.style, attributes: block.paragraph,
                                                       list: block.list,
                                                       baseWritingDirection: baseWritingDirection)
        for run in block.runs {
            var attrs = attributes(for: run.attributes, style: block.style)
            attrs[.paragraphStyle] = paragraphStyle
            if let formula = run.attributes.formula {
                result.append(attributedFormulaString(latex: formula.isEmpty ? run.text : formula, attributes: attrs))
            } else {
                result.append(NSAttributedString(string: run.text, attributes: attrs))
            }
        }
        return result
    }

    public func runs(from attr: NSAttributedString, style: ParagraphStyleName = .body) -> [TextRun] {
        var runs: [TextRun] = []
        let full = NSRange(location: 0, length: attr.length)
        attr.enumerateAttributes(in: full, options: []) { dict, range, _ in
            let text = (attr.string as NSString).substring(with: range)
            runs.append(TextRun(text: text, attributes: characterAttributes(from: dict, style: style, text: text)))
        }
        return runs
    }
}

/// Tail-ellipsis truncation on CLUSTER boundaries, with the ellipsis inheriting the label's own
/// attributes. A pill wider than its line cannot be re-broken by the line-breaker (that recovery path
/// requires the line to hold more than the pill), so the label must shrink instead of overflowing.
///
/// `truncated` is reported rather than inferred from the returned string: a one-character label
/// replaced by a bare ellipsis keeps the same length, so a length comparison would miss exactly the
/// case that is cut hardest.
@available(iOS 13.0, *)
private func truncatedButtonLabel(_ labelString: NSAttributedString, availableWidth: CGFloat) -> (label: NSAttributedString, truncated: Bool) {
    guard labelString.length > 0 else {
        return (labelString, false)
    }
    let fullWidth = CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(labelString), nil, nil, nil))
    guard fullWidth > availableWidth else {
        return (labelString, false)
    }
    let tailAttributes = labelString.attributes(at: labelString.length - 1, effectiveRange: nil)
    let ellipsis = NSAttributedString(string: "\u{2026}", attributes: tailAttributes)
    let ellipsisWidth = CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(ellipsis), nil, nil, nil))
    let widthForText = availableWidth - ellipsisWidth
    guard widthForText > 0.0 else {
        return (ellipsis, true)
    }
    let typesetter = CTTypesetterCreateWithAttributedString(labelString)
    let fittingCount = CTTypesetterSuggestClusterBreak(typesetter, 0, Double(widthForText))
    let result = NSMutableAttributedString(attributedString: labelString.attributedSubstring(
        from: NSRange(location: 0, length: min(fittingCount, labelString.length))))
    result.append(ellipsis)
    return (result, true)
}

#endif

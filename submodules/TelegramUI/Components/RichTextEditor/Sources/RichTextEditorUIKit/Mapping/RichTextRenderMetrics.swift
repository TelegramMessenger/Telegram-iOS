#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Which font family a style resolves through. Mirrors `InstantPageFontStyle` field-for-field so the
/// `InstantPageTheme` adapter (InstantPageUI) is a rename and nothing more.
public enum RichTextFontStyle {
    case sans
    case serif
    case monospace
}

/// Deliberately narrow, mirroring `InstantPageFont.Weight`: every case has a real resolution path.
/// A weight case that is silently ignored type-checks, reads as working, and does nothing.
public enum RichTextFontWeight {
    case regular
    case medium
    case semibold
}

/// One text category's font: the four fields `InstantPageFont` carries. `lineSpacingFactor` is the
/// multiplier V2 applies to the REDUCED line height, not to the font size.
public struct RichTextFontSpec: Equatable {
    public var style: RichTextFontStyle
    public var size: CGFloat
    public var lineSpacingFactor: CGFloat
    public var weight: RichTextFontWeight

    public init(style: RichTextFontStyle, size: CGFloat, lineSpacingFactor: CGFloat, weight: RichTextFontWeight = .regular) {
        self.style = style
        self.size = size
        self.lineSpacingFactor = lineSpacingFactor
        self.weight = weight
    }
}

/// Code-block geometry, shared with the InstantPage V2 renderer.
///
/// There is deliberately NO language-line font here: both surfaces derive it the way they already
/// derive a quote's author line — the body spec plus bold — so the two cannot be set to disagree.
/// That is also why the renderer's old absolute `codeBlockLanguageFontSize` was deleted rather than
/// retyped into this struct.
///
/// The bleed is deliberately absent too: it is a property of the HOST's container geometry (canvas
/// margins, bubble insets), not of the shared type scale, so each surface computes its own.
@available(iOS 13.0, *)
public struct RichTextCodeMetrics: Equatable {
    /// Gap from the band's top/bottom edge to the glyphs. The renderer subtracts the font-box
    /// overhead before applying it (`instantPageV2TextBoxOverheads`), so the value here is the
    /// VISIBLE gap rather than a layout inset that would render several points larger.
    public var verticalInset: CGFloat
    /// Gap between the bold language line and the first code line.
    public var languageSpacing: CGFloat

    public init(verticalInset: CGFloat, languageSpacing: CGFloat) {
        self.verticalInset = verticalInset
        self.languageSpacing = languageSpacing
    }

    /// V2's own values at page scale (`InstantPageMetrics.unscaled`).
    public static let `default` = RichTextCodeMetrics(verticalInset: 14, languageSpacing: 3)
}

/// The editor's render metrics, shaped so a host can hand over the exact numbers the InstantPage V2
/// renderer will use for the same content.
///
/// **This type owns V2's line geometry as formulas.** The renderer computes the same quantities inline
/// in `layoutTextItem`; these statics are the shared definition, and
/// `//submodules/InstantPageUI:InstantPageUITests` asserts they agree with the renderer's real output.
/// Changing a formula here without that test failing means the test stopped covering it.
///
/// Pure UIKit on purpose: `RichTextEditorUIKit` compiles standalone under SwiftPM and must not reach
/// for `InstantPageTheme`. The `InstantPageTheme -> RichTextRenderMetrics` adapter lives on the
/// InstantPageUI side, which already depends on this module.
@available(iOS 13.0, *)
public struct RichTextRenderMetrics: Equatable {
    // MARK: Text categories

    public var heading1: RichTextFontSpec
    public var heading2: RichTextFontSpec
    public var heading3: RichTextFontSpec
    public var heading4: RichTextFontSpec
    public var heading5: RichTextFontSpec
    public var heading6: RichTextFontSpec
    public var body: RichTextFontSpec
    public var caption: RichTextFontSpec
    /// Text inside table cells — V2's `table` category (15pt), the reason cells read denser than body.
    public var table: RichTextFontSpec
    /// V2's `layoutCodeBlock` overrides the theme's 14pt `codeBlock` category with an absolute 15pt,
    /// so this carries 15 and not the theme's nominal size.
    public var codeBlock: RichTextFontSpec
    /// Code-block geometry (the fonts stay in `codeBlock` above).
    public var code: RichTextCodeMetrics

    // MARK: Block rhythm (mirrors the same-named fields of `InstantPageMetrics`)

    public var baseBlockSpacing: CGFloat
    public var blockVerticalPadding: CGFloat
    public var headingVerticalPadding: CGFloat
    public var dividerVerticalPadding: CGFloat
    public var detailsAdjacentSpacing: CGFloat
    /// Points trimmed from the top-level sequence's leading and trailing spacing, clamped at 0.
    /// V2's own parameter of the same name: a host that insets the whole document gives that inset
    /// back out of the document's outer padding, so blocks keep their absolute positions.
    public var edgeSpacingReduction: CGFloat

    // MARK: Buttons

    /// Pill geometry for inline `textButton`s and `pageBlockButtonRow` members.
    public var button: RichTextButtonMetrics

    public init(
        heading1: RichTextFontSpec,
        heading2: RichTextFontSpec,
        heading3: RichTextFontSpec,
        heading4: RichTextFontSpec,
        heading5: RichTextFontSpec,
        heading6: RichTextFontSpec,
        body: RichTextFontSpec,
        caption: RichTextFontSpec,
        table: RichTextFontSpec,
        codeBlock: RichTextFontSpec,
        baseBlockSpacing: CGFloat,
        blockVerticalPadding: CGFloat,
        headingVerticalPadding: CGFloat,
        dividerVerticalPadding: CGFloat,
        detailsAdjacentSpacing: CGFloat,
        edgeSpacingReduction: CGFloat,
        // Defaulted so every existing construction site keeps compiling; the InstantPageUI adapter
        // passes the renderer's own constants explicitly.
        code: RichTextCodeMetrics = .default,
        button: RichTextButtonMetrics = .default
    ) {
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.heading4 = heading4
        self.heading5 = heading5
        self.heading6 = heading6
        self.body = body
        self.caption = caption
        self.table = table
        self.codeBlock = codeBlock
        self.code = code
        self.baseBlockSpacing = baseBlockSpacing
        self.blockVerticalPadding = blockVerticalPadding
        self.headingVerticalPadding = headingVerticalPadding
        self.dividerVerticalPadding = dividerVerticalPadding
        self.detailsAdjacentSpacing = detailsAdjacentSpacing
        self.edgeSpacingReduction = edgeSpacingReduction
        self.button = button
    }

    /// The chat-message look: what a rich message actually renders as in a bubble, which is the
    /// counterpart surface for BOTH editor hosts (the article editor sends into a chat too).
    /// Kept in sync with the extracted `InstantPageTextCategories.chatMessage` factory by a test.
    public static let `default` = RichTextRenderMetrics(
        heading1: RichTextFontSpec(style: .serif, size: 22, lineSpacingFactor: 1.0, weight: .medium),
        heading2: RichTextFontSpec(style: .serif, size: 20, lineSpacingFactor: 1.0, weight: .medium),
        heading3: RichTextFontSpec(style: .serif, size: 18, lineSpacingFactor: 1.0, weight: .medium),
        heading4: RichTextFontSpec(style: .serif, size: 17, lineSpacingFactor: 1.0, weight: .medium),
        heading5: RichTextFontSpec(style: .serif, size: 16, lineSpacingFactor: 1.0, weight: .medium),
        heading6: RichTextFontSpec(style: .serif, size: 15, lineSpacingFactor: 1.0, weight: .medium),
        body: RichTextFontSpec(style: .sans, size: 17, lineSpacingFactor: 0.9),
        caption: RichTextFontSpec(style: .sans, size: 15, lineSpacingFactor: 1.0),
        table: RichTextFontSpec(style: .sans, size: 15, lineSpacingFactor: 1.0),
        codeBlock: RichTextFontSpec(style: .monospace, size: 15, lineSpacingFactor: 1.0),
        baseBlockSpacing: 8,
        blockVerticalPadding: 4,
        headingVerticalPadding: 8,
        dividerVerticalPadding: 4,
        detailsAdjacentSpacing: 4,
        edgeSpacingReduction: 0,
        code: .default
    )

    /// `.pullQuote` resolves to the body category at V2's quote scale. Parity for quote INTERIORS is
    /// a later cycle of this project, so this is a reasonable font today and not yet a verified match.
    public func spec(for style: ParagraphStyleName) -> RichTextFontSpec {
        switch style {
        case .heading1: return heading1
        case .heading2: return heading2
        case .heading3: return heading3
        case .heading4: return heading4
        case .heading5: return heading5
        case .heading6: return heading6
        case .body:     return body
        case .caption:  return caption
        case .pullQuote:
            var spec = body
            spec.size = floor(body.size * RichTextRenderMetrics.quoteScale)
            return spec
        }
    }

    /// V2's `InstantPageMetrics.quoteScale` — quoted content sits one step below body.
    public static let quoteScale: CGFloat = 15.0 / 17.0

    // MARK: - V2 line geometry

    /// V2's `fontLineHeight` — `floor(ascender + descender)` with a NEGATIVE descender, so this is a
    /// REDUCED box (roughly cap-to-baseline), materially smaller than `font.lineHeight`. Every other
    /// formula here is built on it, which is why it is named rather than inlined.
    public static func reducedLineHeight(_ font: UIFont) -> CGFloat {
        return floor(font.ascender + font.descender)
    }

    /// V2's `fontLineSpacing` — the factor multiplies the REDUCED height, not the point size.
    public static func lineSpacing(_ font: UIFont, factor: CGFloat) -> CGFloat {
        return floor(reducedLineHeight(font) * factor)
    }

    /// Baseline-to-baseline advance: V2 advances by `lineAscent + fontLineSpacing`, and `lineAscent`
    /// starts at `fontLineHeight` for a line with no inflating inline attachment.
    public static func linePitch(_ font: UIFont, factor: CGFloat) -> CGFloat {
        return reducedLineHeight(font) + lineSpacing(font, factor: factor)
    }

    /// V2 offsets the line stack by `lineBoxTopInset = max(0, ascender - reducedLineHeight)` and puts
    /// the first baseline `lineAscent` below that — which collapses to exactly the ascender.
    public static func firstBaselineFromTop(_ font: UIFont) -> CGFloat {
        return max(0.0, font.ascender - reducedLineHeight(font)) + reducedLineHeight(font)
    }

    /// V2's item height: `lines.last.frame.maxY + fontDescentBelowBaseline`, CEILED. A single line
    /// measures `ascender + |descender|` rounded up — NOT one pitch — and each further line adds one
    /// pitch.
    ///
    /// **The ceiling is load-bearing, not cosmetic.** `layoutTextItem` returns `ceil(height)` because
    /// callers stack blocks by adding the size to a running origin, so one fractional box would make
    /// every later block origin fractional too; ceiling is the only direction that cannot clip text.
    /// Omitting it here left every editor block up to ~0.7pt short of the renderer's, and the error
    /// accumulated down the document. Note the pitch is already integral (both terms are floors), so
    /// ceiling the whole expression is the same as ceiling `ascender + |descender|` alone — which is
    /// why `trailingHeightCorrection` stays independent of the line count.
    public static func textHeight(_ font: UIFont, factor: CGFloat, lineCount: Int) -> CGFloat {
        guard lineCount > 0 else { return 0 }
        let descentBelowBaseline = max(0.0, -font.descender)
        return ceil(firstBaselineFromTop(font) + descentBelowBaseline)
            + CGFloat(lineCount - 1) * linePitch(font, factor: factor)
    }

    /// What to add to a TextKit-reported height to get V2's item height for the same text.
    ///
    /// TextKit, given a pinned line box, reports `n * pitch`; V2 reports
    /// `ascender + (n-1) * pitch + |descender|`, because it reserves only the DESCENDER below the last
    /// baseline rather than a full line box. The difference is `(ascender + |descender|) - pitch`,
    /// **independent of the line count** — which is why a single per-paragraph constant is enough.
    /// Typically negative (body -1.7pt, caption -2.1pt, H1 -5.4pt at the chat-message factors).
    ///
    /// Defined here, once, because more than one code path measures text height: `BlockBox` for the
    /// live paragraph and `BlockQuoteBox` for the collapsed-quote preview. A second copy of this
    /// formula is exactly how those two silently disagreed before
    /// (`BlockQuoteGeometryTests.test_collapsedVsExpanded_singleLineBodyChild_heightParity`).
    public static func trailingHeightCorrection(_ font: UIFont, factor: CGFloat) -> CGFloat {
        return trailingHeightCorrection(font, pinnedLineHeight: linePitch(font, factor: factor))
    }

    /// The same correction, for a caller that already knows the pinned box height and so does not need
    /// the style's line-spacing factor to recover it — the pinned box IS the pitch. This is the form the
    /// layout engines use: it lets them correct their own reported height knowing nothing about styles.
    public static func trailingHeightCorrection(_ font: UIFont, pinnedLineHeight: CGFloat) -> CGFloat {
        // `ceil` for the same reason `textHeight` ceils — the renderer returns a whole-point box.
        return ceil(font.ascender - font.descender) - pinnedLineHeight
    }
}
#endif

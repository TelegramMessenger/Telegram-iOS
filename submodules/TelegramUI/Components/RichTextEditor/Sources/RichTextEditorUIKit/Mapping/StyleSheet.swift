#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Resolves a paragraph style name to concrete fonts/paragraph layout (UIKit-only, hence here
/// rather than in Core).
@available(iOS 13.0, *)
public struct StyleSheet {
    public init() {}
    public static let `default` = StyleSheet()
    /// A style sheet for content inside table cells: body content renders at the metrics' `table`
    /// size (15pt) instead of the document's body size, so a table reads denser than surrounding
    /// text. Headings and captions keep their own sizes. Selected per-cell via
    /// `AttributedStringMapper.tableCellVariant()`.
    public static let tableCells: StyleSheet = {
        var s = StyleSheet()
        s.metrics.body = s.metrics.table
        return s
    }()

    /// The render metrics this sheet projects — fonts, per-style line-spacing factors, and the
    /// block-rhythm scalars. Defaults to the chat-message look. A host overrides it with the exact
    /// numbers its counterpart renderer will use, via `RichTextEditorView.renderMetrics`.
    public var metrics: RichTextRenderMetrics = .default
    /// Leading indent (points) of a quote paragraph's text past its fill's left edge — the gap that
    /// holds the quote bar. Default 16 (the reference design). Per-host via `QuoteStyle.leadingInset`.
    public var quoteIndent: CGFloat = 16
    /// Interior right padding (points) of a quote: the text container is narrowed by this so text wraps
    /// before the fill's trailing edge (the fill still spans the full content width). Default 0.
    /// Consumed by `BlockBox` (Task 2). Per-host via `QuoteStyle.trailingInset`.
    public var quoteTrailingInset: CGFloat = 0
    /// Paragraph spacing above each quote paragraph (points). Default 8. Per-host via `QuoteStyle.spacingBefore`.
    public var quoteSpacingBefore: CGFloat = 8
    /// Paragraph spacing below each quote paragraph (points). Default 8. Per-host via `QuoteStyle.spacingAfter`.
    public var quoteSpacingAfter: CGFloat = 8
    /// Interior TOP padding (points) of a top-level quote run — the gap between the fill's top edge and
    /// the first text line. `nil` (default) keeps the block-inset-derived value; a value overrides the
    /// quote block's `topInset` at the run's top edge (applied in `BlockStack.layout`). Per-host via
    /// `QuoteStyle.topInset`.
    public var quoteTopInset: CGFloat?
    /// Interior BOTTOM padding (points) of a top-level quote run — the gap between the last text line and
    /// the fill's bottom edge. `nil` (default) keeps the current behavior. Per-host via `QuoteStyle.bottomInset`.
    public var quoteBottomInset: CGFloat?

    /// Visible gap from a code band's top/bottom edge to its glyphs. Defaults to the shared render
    /// metrics; `CodeStyle.verticalInset` overrides it per host. A code block no longer borrows the
    /// quote's insets — its side padding is the paragraph inset by construction, so these two are the
    /// only geometry it still owns.
    public var codeVerticalInset: CGFloat = RichTextCodeMetrics.default.verticalInset
    /// Gap between a code block's bold language line and its first code line. Defaults to the shared
    /// render metrics; `CodeStyle.languageSpacing` overrides it per host.
    public var codeLanguageSpacing: CGFloat = RichTextCodeMetrics.default.languageSpacing
    /// Extra inset of code text inward from its band's edges. 0 = the text sits at the paragraph
    /// inset (the renderer's rule). Per-host via `CodeStyle.horizontalInset`.
    public var codeHorizontalInset: CGFloat = 0
    /// Corner radius of a code band. 0 = square (the renderer's look). Per-host via
    /// `CodeStyle.cornerRadius`.
    public var codeCornerRadius: CGFloat = 0

    /// Points of indentation per list nesting level (where each level's marker hangs).
    public static let listIndentStep: CGFloat = 24
    /// Horizontal gap reserved between a list marker and its text — the text hangs this far past the
    /// marker's column. Half the per-level indent step, so it's decoupled from nesting depth.
    public static let listMarkerSpacing: CGFloat = listIndentStep / 2
    /// Extra text inset applied to ORDERED (numbered) list items on top of `listMarkerSpacing`. A
    /// number marker ("1.", "iii.") is much wider than a bullet, so its text needs more breathing room
    /// after the marker than a bullet's does. The marker itself stays in its level's column; only the
    /// item text shifts right by this amount.
    public static let orderedListTextInset: CGFloat = 4
    /// The side length of the checklist checkbox, sized to the font's cap height so it scales per style
    /// and reads like a capital letter sitting on the baseline. (Tunable: switch capHeight→ascender for a
    /// larger box.) Returns the UNSCALED base — the vertical-center anchor used by both the geometry and
    /// the paragraph-indent computation.
    public static func checklistMarkerSize(for font: UIFont) -> CGFloat { font.capHeight.rounded() }
    /// Horizontal gap between the checkbox's right edge and the item text.
    public static let checklistMarkerGap: CGFloat = 6
    /// The checklist checkbox is drawn this many times its base (cap-height) size — it grows into the top,
    /// bottom, and right (the left edge stays anchored at the marker gutter). Tunable.
    public static let checklistMarkerScale: CGFloat = 1.4

    public func font(for style: ParagraphStyleName, attributes: CharacterAttributes) -> UIFont {
        var spec = self.metrics.spec(for: style)
        // An explicit per-run size overrides the style's size, keeping the style's family and weight.
        if let size = attributes.fontSize { spec.size = CGFloat(size) }
        // Headings are NOT bold by default — the weight comes from the spec. Bold stays pure user
        // emphasis (`CharacterAttributes.bold`), so it round-trips uniformly in every style and no
        // style-injected weight can leak into the model.
        // Pull quotes force italic render — ambient (render-only), stripped on read-back.
        let italic = attributes.italic || style == .pullQuote
        return FontResolver.font(spec: spec, bold: attributes.bold, italic: italic, family: attributes.fontFamily)
    }

    public func paragraphStyle(for style: ParagraphStyleName, attributes: ParagraphAttributes,
                               list: ListMembership? = nil,
                               baseWritingDirection: NSWritingDirection = .natural) -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        switch attributes.alignment {
        case .natural: ps.alignment = .natural
        case .left: ps.alignment = .left
        case .center: ps.alignment = .center
        case .right: ps.alignment = .right
        case .justified: ps.alignment = .justified
        }
        // Pull quotes always render centered regardless of the user's alignment setting.
        if style == .pullQuote { ps.alignment = .center }
        ps.baseWritingDirection = baseWritingDirection
        ps.firstLineHeadIndent = CGFloat(attributes.firstLineIndent)
        ps.headIndent = CGFloat(attributes.headIndent)
        ps.paragraphSpacingBefore = CGFloat(attributes.paragraphSpacingBefore)
        ps.paragraphSpacing = CGFloat(attributes.paragraphSpacingAfter)
        ps.lineHeightMultiple = CGFloat(attributes.lineHeightMultiple)
        // Pin the line box to V2's pitch. A `lineHeightMultiple` cannot express this: at the Instant
        // Page reader's heading factor (0.685) V2 wants a pitch TIGHTER than the font's natural line
        // height, and `NSParagraphStyle.lineSpacing` cannot go negative. `minimumLineHeight ==
        // maximumLineHeight` expresses both directions with one mechanism. An explicit model-level
        // multiple is user content and takes over instead — the two must not combine, or the box is
        // scaled twice. See `LineHeightCenteringTests`.
        if ps.lineHeightMultiple == 1 {
            ps.lineHeightMultiple = 0
            let font = self.font(for: style, attributes: .plain)
            let pitch = RichTextRenderMetrics.linePitch(font, factor: self.metrics.spec(for: style).lineSpacingFactor)
            ps.minimumLineHeight = pitch
            ps.maximumLineHeight = pitch
        }
        var indent: CGFloat = 0
        if let list = list {
            // Marker sits at the level's indent; text hangs `listMarkerSpacing` past it. Ordered
            // (numbered) items get extra text inset since a number marker is wider than a bullet.
            indent += StyleSheet.listIndentStep * CGFloat(list.level) + StyleSheet.listMarkerSpacing
            if list.marker == .ordered { indent += StyleSheet.orderedListTextInset }
            else if list.marker == .checklist {
                let markerFont = self.font(for: style, attributes: .plain)
                let scaledSide = StyleSheet.checklistMarkerSize(for: markerFont) * StyleSheet.checklistMarkerScale
                indent += max(0, scaledSide + StyleSheet.checklistMarkerGap - StyleSheet.listMarkerSpacing)
            }
        }
        ps.firstLineHeadIndent += indent
        ps.headIndent += indent
        return ps
    }
}
#endif

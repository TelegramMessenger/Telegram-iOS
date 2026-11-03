#if canImport(UIKit)
import UIKit

/// Per-host geometry for quote blocks. Every field defaults to the editor's built-in (reference-design)
/// look, so a host that never sets `RichTextEditorView.quoteStyle` is unchanged. The chat composer and the
/// article editor each assign their own before seeding the document (the compact-host knob convention).
@available(iOS 13.0, *)
public struct QuoteStyle: Equatable {
    /// Interior left padding (bar→text gap), in points. → `StyleSheet.quoteIndent`.
    public var leadingInset: CGFloat
    /// Interior right padding, in points (the text container narrows; the fill stays full width).
    /// → `StyleSheet.quoteTrailingInset`.
    public var trailingInset: CGFloat
    /// Paragraph spacing above each quote paragraph, in points. → `StyleSheet.quoteSpacingBefore`.
    public var spacingBefore: CGFloat
    /// Paragraph spacing below each quote paragraph, in points. → `StyleSheet.quoteSpacingAfter`.
    public var spacingAfter: CGFloat
    /// Width of the leading accent bar, in points. → `BlockquoteUnderlay`.
    public var barWidth: CGFloat
    /// Corner radius of the fill + bar, in points. → `BlockquoteUnderlay`.
    public var cornerRadius: CGFloat
    /// Opacity of the accent fill behind the quote (0…1). → `BlockquoteUnderlay`.
    public var fillAlpha: CGFloat
    /// Interior TOP padding (points): the gap between the quote fill's top edge and the first text
    /// line. `nil` (default) keeps the block-inset-derived behavior (`BlockStack.facingInset`, driven
    /// by `blockVerticalInset`); a value overrides it. The vertical parallel to `leadingInset`.
    /// Applies to top-level quote runs only (table-cell quotes use the static `.tableCells` look).
    public var topInset: CGFloat?
    /// Interior BOTTOM padding (points): the gap between the last text line and the quote fill's bottom
    /// edge. `nil` (default) keeps the current behavior. The vertical parallel to `trailingInset`.
    public var bottomInset: CGFloat?
    /// Vertical gap (points) between the quote content and the author line.
    public var authorSpacing: CGFloat

    public init(leadingInset: CGFloat = 16, trailingInset: CGFloat = 22,
                spacingBefore: CGFloat = 8, spacingAfter: CGFloat = 8,
                barWidth: CGFloat = 3, cornerRadius: CGFloat = 6, fillAlpha: CGFloat = 0.10,
                topInset: CGFloat? = nil, bottomInset: CGFloat? = nil, authorSpacing: CGFloat = 1) {
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
        self.barWidth = barWidth
        self.cornerRadius = cornerRadius
        self.fillAlpha = fillAlpha
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.authorSpacing = authorSpacing
    }

    public static let `default` = QuoteStyle()
}
#endif

#if canImport(UIKit)
import UIKit
import CoreText
import RichTextEditorCore

/// A measured inline pill. Mirrors `InstantPageInlineButtonAttachment` in the V2 renderer: the payload
/// carries both the model and the metrics, because the line layout raises the line's ascent/descent from
/// the attachment itself and has no style stack with which to re-measure.
///
/// Unlike `FormulaTextAttachment` this needs NO host renderer — a pill is a rounded rect plus an
/// attributed label, both of which this module can draw itself. It follows the same `NSTextAttachment` +
/// `attachmentBounds` shape, so both layout engines (TextKit 1 and 2) place it with no extra work.
@available(iOS 13.0, *)
public final class ButtonTextAttachment: NSTextAttachment, RichTextInlineAttachment {
    public let button: ButtonRef
    /// The label, already laid out with the pill's own typography (semibold, fixed size).
    let labelString: NSAttributedString
    /// Full pill size — the label's ink box inflated by the padding below.
    public let size: CGSize
    public let ascent: CGFloat
    public let descent: CGFloat
    /// The per-side horizontal padding `size` was inflated by. LOAD-BEARING: the label's ink width is
    /// recovered as `size.width - 2 * horizontalPadding`, so reading a global here instead of the value
    /// that actually built `size` would silently mis-centre the label.
    let horizontalPadding: CGFloat
    /// True when `maxWidth` forced an ellipsis — the label did NOT fit at this padding. The row packer
    /// re-measures such a pill at `blockMinimumHorizontalPadding` to win the difference back as label
    /// room; see `richTextMeasureRowButton`.
    let isTruncated: Bool
    /// Resolved at construction from the theme + the button's colour role, and kept so a row box can
    /// re-render the same pill at its stretched column width without re-deriving them.
    public let colors: (fill: UIColor, label: UIColor)
    /// The type icon, or nil when the action has none. Resolved here, alongside the width held for it,
    /// so what is drawn and what was measured cannot disagree. The ink itself is produced at draw time,
    /// where the tint is known — see `RichTextButtonIcon`.
    let icon: RichTextButtonIcon?
    /// Trailing width inside `size` held for `icon` on an INLINE pill; 0 when there is no icon and for
    /// every block pill, whose badge is a corner overlay. Mirrors
    /// `InstantPageInlineButtonAttachment.iconReserve`.
    let iconReserve: CGFloat
    /// Which placement `icon` is drawn at. Fixed at construction: a pill is built by exactly one kind
    /// of owner and never changes kind.
    public let isBlockPill: Bool

    init(button: ButtonRef, labelString: NSAttributedString, size: CGSize, ascent: CGFloat,
         descent: CGFloat, horizontalPadding: CGFloat, isTruncated: Bool = false,
         colors: (fill: UIColor, label: UIColor), icon: RichTextButtonIcon? = nil, iconReserve: CGFloat = 0.0,
         isBlockPill: Bool = false) {
        self.button = button
        self.labelString = labelString
        self.size = size
        self.ascent = ascent
        self.descent = descent
        self.horizontalPadding = horizontalPadding
        self.isTruncated = isTruncated
        self.colors = colors
        self.icon = icon
        self.iconReserve = iconReserve
        self.isBlockPill = isBlockPill
        super.init(data: nil, ofType: nil)
        // A 1x1 clear spacer, exactly as `EmojiTextAttachment` uses: it makes TextKit call
        // `attachmentBounds` and reserve the pill's box, while the VISIBLE pill is a hosted
        // `ButtonPillView` (see `syncButtonPillViews`). An image-less attachment can lay out zero-width.
        //
        // Deliberately NOT a rendered pill bitmap: a label can contain a custom emoji, which needs a live
        // host view. Baking the pill would make that impossible and double-draw under the hosted view.
        self.image = ButtonTextAttachment.spacerImage
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not used")
    }

    /// Whether `other` is a rendering of the SAME atom with the same geometry — what a document set
    /// asks when it decides whether an engine block changed. Deliberately NOT `isEqual`: two adjacent
    /// atoms with equal attachments would coalesce into one attribute run, and every consumer that
    /// walks attachments expects one object per character. A fresh render of an unchanged model mints
    /// new attachment objects, so `NSAttributedString` equality alone called every block holding one
    /// changed (composer harness p15, `HarnessAtomParagraphReplayIdentityTests`).
    public func drawsTheSameAs(_ other: NSTextAttachment) -> Bool {
        guard let other = other as? ButtonTextAttachment else { return false }
        return button == other.button && labelString.isEqual(to: other.labelString) && size == other.size
            && ascent == other.ascent && descent == other.descent && horizontalPadding == other.horizontalPadding
            && isTruncated == other.isTruncated && colors.fill.isEqual(other.colors.fill)
            && colors.label.isEqual(other.colors.label) && (icon == nil) == (other.icon == nil)
            && iconReserve == other.iconReserve && isBlockPill == other.isBlockPill
    }

    /// `RichTextInlineAttachment`: font-independent — a pill is measured with its own typography.
    public func reservedBox(forFont font: UIFont) -> CGRect { box() }

    private func box() -> CGRect {
        return CGRect(x: 0.0, y: -descent, width: max(1.0, size.width), height: max(1.0, size.height))
    }

    @available(iOS 15.0, *)
    public override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: NSTextLocation,
                                   textContainer: NSTextContainer?, proposedLineFragment: CGRect,
                                   position: CGPoint) -> CGRect {
        return box()
    }

    public override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        return box()
    }

    /// Shared with `EmojiTextAttachment`'s approach: identical for every pill and renders nothing, so it
    /// is created once rather than per attachment.
    private static let spacerImage: UIImage =
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
}
#endif

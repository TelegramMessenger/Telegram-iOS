#if canImport(UIKit)
import UIKit

/// An inline attachment that can report the box it reserves WITHOUT a layout pass.
///
/// The three conformers — a custom emoji, an inline formula, an inline button pill — all ride a text
/// line, and all already compute a baseline-relative box for `attachmentBounds`. This exposes that
/// same computation so a caller reasoning about the LINE can ask what the attachment will do to it
/// before TextKit lays anything out.
///
/// **An ATOM attachment deliberately does not conform** — a media block, a button row, a folded
/// quote. Those are a block's whole content, their line is inflated to them by construction, and
/// nothing that reasons about a pinned text line applies.
@available(iOS 13.0, *)
public protocol RichTextInlineAttachment: AnyObject {
    /// The attachment's box relative to the baseline, +y UP (`attachmentBounds`' own convention):
    /// `origin.y` is the descent below the baseline, negated, and `origin.y + height` the ascent
    /// above it. `font` is the run font, which only an emoji's box depends on.
    func reservedBox(forFont font: UIFont) -> CGRect
}

/// Whether an inline attachment fits inside a PINNED line box, or inflates it.
@available(iOS 13.0, *)
public enum RichTextInlineAttachmentFit {

    /// True when a line pinned to `pinnedLineHeight` lays out at EXACTLY that height with
    /// `attachment` on it — i.e. TextKit has nothing to inflate.
    ///
    /// **The room is asymmetric, and that is the whole of this function.** `StyleSheet` pins
    /// `minimumLineHeight == maximumLineHeight`, and TextKit bottom-aligns the line inside that box:
    /// the baseline sits `|font.descender|` above the bottom. So there is `pinnedLineHeight -
    /// |descender|` of room ABOVE the baseline and only `|descender|` BELOW it, and an attachment
    /// that exceeds EITHER inflates the line by that excess — it is not a question of total height.
    /// Measured at 17pt body (descender 4.1006, pinned 23):
    ///
    /// | attachment | ascent | descent | line |
    /// | --- | --- | --- | --- |
    /// | emoji, 20.29 tall | 16.19 | 4.10 | 23.0 — fits exactly |
    /// | formula, 14 tall | 11.2 | 2.8 | 23.0 — fits |
    /// | formula, 22 tall | 17.6 | 4.4 | 23.2994 — 0.2994 of excess DESCENT, though 22 < 23 |
    /// | pill, 19.90 tall | 15.28 | 4.62 | 23.5176 — likewise, and it is the shortest of the three |
    ///
    /// A formula two points SHORTER than the line box still inflating it is why the obvious
    /// `height <= pinnedLineHeight` test is wrong, and why this takes the box rather than a height.
    ///
    /// An attachment that does not conform to `RichTextInlineAttachment` is an ATOM: its line is
    /// inflated to it by construction, so the answer is false.
    public static func fitsPinnedLine(_ attachment: NSTextAttachment, font: UIFont,
                                      pinnedLineHeight: CGFloat) -> Bool {
        guard pinnedLineHeight > 0,
              let inline = attachment as? RichTextInlineAttachment else { return false }
        let box = inline.reservedBox(forFont: font)
        let descentBelowBaseline = -box.minY
        let ascentAboveBaseline = box.maxY
        let roomBelow = -font.descender
        let roomAbove = pinnedLineHeight - roomBelow
        // A hair of tolerance: an emoji's descent IS the font's descender, and comparing two paths
        // to the same number exactly would turn a rounding difference into an inflated line.
        let epsilon: CGFloat = 0.01
        return descentBelowBaseline <= roomBelow + epsilon
            && ascentAboveBaseline <= roomAbove + epsilon
    }
}
#endif

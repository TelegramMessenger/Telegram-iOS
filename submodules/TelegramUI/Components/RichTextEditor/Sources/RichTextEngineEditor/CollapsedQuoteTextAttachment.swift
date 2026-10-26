#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// Legacy's collapsed-quote constants, borrowed rather than re-derived.
///
/// `BlockQuoteBox` is INTERNAL to `RichTextEditorUIKit` and unreachable from here, which is the same
/// borrow — with the same provenance comment — that `DetailsShape` already makes for
/// `BlockBox.defaultVerticalInset`.
@available(iOS 18.4, *)
public enum CollapsedQuoteGeometry {
    /// `BlockQuoteBox.maxPreviewLines`. Also the renderer's `instantPageV2CollapsedQuoteLineBudget`,
    /// and `InteractiveTextComponent`'s `lineCount > 3` — the three agree, which is why a quote
    /// folded here reads the same size in a sent bubble.
    public static let maxPreviewLines: Int = 3
    /// `BlockQuoteBox.expandGlyphSize`.
    public static let glyphSize: CGFloat = 18.0
    /// `BlockQuoteBox.expandGlyphGap` — the glyph's clearance from the preview text.
    public static let glyphGap: CGFloat = 6.0
    /// `BlockQuoteBox.expandGlyphRect()`'s inset from the box's trailing-top corner.
    public static let glyphCornerInset: CGFloat = 4.0

}

/// The attachment character a COLLAPSED block quote is on the engine's axis (R7-collapse §4.1) —
/// the third of its kind after `MediaTextAttachment` and `ButtonRowTextAttachment`, built to the
/// same rules.
///
/// It reserves the slot and draws nothing: `CollapsedQuotePreviewView` is positioned over the frame
/// TextKit gives it. The 1×1 spacer image is what makes TextKit call `attachmentBounds` at all — an
/// image-less attachment can lay out zero-width.
///
/// The bounds are DYNAMIC: measured from the proposed line fragment on every layout, so a width
/// change (rotation, the composer growing) re-measures with no document edit.
///
/// Value-equal on purpose, for ONE consumer: the document setter's differing-span diff, which
/// compares rendered blocks with `NSAttributedString.isEqual`. A pointer-unequal atom would read as
/// changed on every set.
///
/// **It carries the preview STRING and its ATTRIBUTES**, and the view reads them back off it rather
/// than rebuilding them. The measurement and the drawing then cannot disagree about what is on
/// screen, which is the one way a three-line cap can be wrong without anything looking wrong.
@available(iOS 18.4, *)
public final class CollapsedQuoteTextAttachment: NSTextAttachment {
    public let shape: QuoteShape
    /// How much narrower than the PROPOSED fragment this atom's column is, from the containers
    /// ENCLOSING the folded quote. Probe P1 (2026-09-05) established that TextKit 2 proposes the
    /// whole container width even for a paragraph carrying a head indent, so the attachment
    /// subtracts it itself — `MediaTextAttachment.horizontalIndent`'s note, unchanged.
    public let horizontalIndent: CGFloat
    /// The folded quote's OWN padding, applied inside the host view and subtracted here only for
    /// the measurement.
    public let leadingInset: CGFloat
    public let trailingInset: CGFloat
    /// The folded body, FORMATTED — built by `EngineDocumentBridge.collapsedQuotePreviewText(for:)`
    /// through the quote mapper, so runs keep their traits and a custom emoji keeps its
    /// `EmojiTextAttachment`. It was a plain `String` when the fold shipped, which is why the preview
    /// rendered no formatting, drew an emoji as a blank box, and showed spoilered text in the clear.
    public let previewText: NSAttributedString
    public let attributes: [NSAttributedString.Key: Any]

    private static let spacerImage: UIImage =
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }

    public init(shape: QuoteShape, horizontalIndent: CGFloat,
                leadingInset: CGFloat, trailingInset: CGFloat,
                previewText: NSAttributedString,
                attributes: [NSAttributedString.Key: Any]) {
        self.shape = shape
        self.horizontalIndent = horizontalIndent
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        self.previewText = previewText
        self.attributes = attributes
        super.init(data: nil, ofType: nil)
        self.image = Self.spacerImage
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// The width the preview's GLYPHS get: the line, less the enclosing containers' narrowing, less
    /// this quote's own padding, less the room the expand glyph takes in the trailing-top corner.
    public func textWidth(forLineWidth lineWidth: CGFloat) -> CGFloat {
        let line = max(lineWidth - horizontalIndent, 1)
        let trailingPad = max(trailingInset, 0)
            + CollapsedQuoteGeometry.glyphSize + CollapsedQuoteGeometry.glyphGap
        return max(line - leadingInset - trailingPad, 1)
    }

    /// The slot: the WHOLE line wide, so the band is identical folded and open, and at most
    /// `maxPreviewLines` pinned line boxes tall.
    ///
    /// **The cap is what N lines actually MEASURE — `box + (N−1) × pitch` — and no trailing
    /// correction beyond that.** This box has to CONTAIN the lines the preview view draws. While
    /// nothing re-expresses the style the box IS the pitch (`StyleSheet` leaves `lineSpacing` at 0)
    /// and that reduces to the `N × pitch` this comment named for its first year. Once
    /// `EngineDocumentBridge.v2BaselinePlacedStyle` splits the two, N lines occupy N boxes plus the
    /// N−1 gaps BETWEEN them — a text system adds no trailing `lineSpacing` under the last line — and
    /// a cap of `N × pitch` reserves one remainder more than the preview draws.
    ///
    /// `trailingHeightCorrection` is the RENDERER's convention for how a block's height relates to
    /// the rhythm BELOW it — a block of N lines measures `(N−1) × pitch + fontbox` — and it is
    /// NEGATIVE whenever the pinned box is taller than the font's own, which at 15pt it is by 1pt.
    /// Added here it made the box 56pt where three 19pt lines needed 57, so the label fitted two and
    /// centred them: reported from the device as "two lines with larger vertical insets"
    /// (2026-09-15). That remains the right verdict — note the formula above arrives at 56 for a
    /// re-expressed style because three lines then genuinely MEASURE 56 (18 + 19 + 19), not because
    /// a correction was applied to a 57pt need. It says nothing about how much room glyphs need, and an attachment atom
    /// contributes no trailing overhang to the rhythm anyway (`trailingLineBoxOverhangs` answers 0
    /// for one), so there is nothing here for it to be consistent with.
    ///
    /// The legacy canvas adds the same correction and is NOT wrong to: its preview is a
    /// `BlockLayoutEngine` layout measured by `correctedBoundingHeight`, so both sides of its
    /// comparison use the corrected convention. Only mixing the two is a defect.
    public func slot(forLineWidth lineWidth: CGFloat) -> CGSize {
        let line = max(lineWidth - horizontalIndent, 1)
        let text = Self.measuring(previewText)
        let measured = text.boundingRect(
            with: CGSize(width: textWidth(forLineWidth: lineWidth), height: .greatestFiniteMagnitude),
            options: RichTextFontLeading.drawingOptions, context: nil).height
        let font = (attributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 15)
        let pitch = Self.pitch(of: attributes, font: font)
        // N lines measure `box + (N-1) * pitch`, NOT `N * pitch`: a text system adds no trailing
        // `lineSpacing` below the last line. Identical to `N * pitch` whenever nothing re-expressed
        // the style (`StyleSheet` leaves `lineSpacing` at 0, so box == pitch), and one remainder per
        // line short of the drawn layout once something has — which read as a preview that no longer
        // filled the box the atom reserved.
        let box = Self.lineBox(of: attributes, font: font)
        let cap = box + pitch * CGFloat(CollapsedQuoteGeometry.maxPreviewLines - 1)
        return CGSize(width: line, height: max(min(ceil(measured), cap), 1))
    }

    /// `text` with the line break mode forced to WRAPPING, which is the only form that can be
    /// measured.
    ///
    /// Under a truncating mode `boundingRect(with:options:context:)` measures ONE truncated line
    /// however long the string is — a 2,400-character preview came back 18pt tall and the three-line
    /// cap never engaged. TextKit does the same thing to a LAYOUT (one line even with
    /// `maximumNumberOfLines` set to three), which is why truncation now lives on the layout
    /// container (`BlockLayoutEngine.capLines`) and `collapsedQuotePreviewAttributes` wraps.
    ///
    /// **So this is a guard, not a correction, and it is kept deliberately.** It is the identity for
    /// a preview built by that property today; it stays because the failure it prevents is silent in
    /// both directions — a truncating style reaching here yields a one-line measurement, and a
    /// one-line measurement yields a folded quote whose box is one line tall with nothing anywhere
    /// reporting a problem. The measured height must answer "how tall is this text wrapped", and
    /// asking it in the form that can only be answered that way costs one string copy per fold.
    private static func measuring(_ text: NSAttributedString) -> NSAttributedString {
        let measuring = NSMutableAttributedString(attributedString: text)
        let whole = NSRange(location: 0, length: measuring.length)
        measuring.enumerateAttribute(.paragraphStyle, in: whole, options: []) { value, range, _ in
            let base = (value as? NSParagraphStyle) ?? NSParagraphStyle.default
            guard let style = base.mutableCopy() as? NSMutableParagraphStyle else { return }
            style.lineBreakMode = .byWordWrapping
            measuring.addAttribute(.paragraphStyle, value: style, range: range)
        }
        return measuring
    }

    /// One body line's ADVANCE in the preview's own face. Taken from the paragraph style's pinned
    /// box when it has one — which it does, because the mapper pins every line box — and from the
    /// font otherwise.
    /// The pinned line BOX — where TextKit bottom-aligns the line, as distinct from the ADVANCE
    /// between two baselines that `pitch` reports. They are the same number until
    /// `EngineDocumentBridge.v2BaselinePlacedStyle` splits them.
    private static func lineBox(of attributes: [NSAttributedString.Key: Any], font: UIFont) -> CGFloat {
        if let style = attributes[.paragraphStyle] as? NSParagraphStyle, style.minimumLineHeight > 0 {
            return style.minimumLineHeight
        }
        return pitch(of: attributes, font: font)
    }

    private static func pitch(of attributes: [NSAttributedString.Key: Any], font: UIFont) -> CGFloat {
        if let style = attributes[.paragraphStyle] as? NSParagraphStyle, style.minimumLineHeight > 0 {
            // The ADVANCE, which is the pinned box PLUS the remainder — not the box alone.
            // `EngineDocumentBridge.v2BaselinePlacedStyle` re-expresses V2's pitch as a smaller box
            // and a `lineSpacing` carrying the difference, so reading `minimumLineHeight` by itself
            // returns the box and the three-line slot comes out one remainder per line short.
            // Identical to the old reading whenever nothing re-expressed the style, since
            // `StyleSheet` leaves `lineSpacing` at 0.
            return style.minimumLineHeight + style.lineSpacing
        }
        return RichTextRenderMetrics.linePitch(font, factor: 1.0)
    }

    private func box(forLineWidth lineWidth: CGFloat) -> CGRect {
        CGRect(origin: .zero, size: slot(forLineWidth: lineWidth))
    }

    public override func attachmentBounds(for attributes: [NSAttributedString.Key: Any],
                                          location: NSTextLocation, textContainer: NSTextContainer?,
                                          proposedLineFragment: CGRect, position: CGPoint) -> CGRect {
        box(forLineWidth: proposedLineFragment.width)
    }

    public override func attachmentBounds(for textContainer: NSTextContainer?,
                                          proposedLineFragment lineFrag: CGRect,
                                          glyphPosition position: CGPoint,
                                          characterIndex charIndex: Int) -> CGRect {
        box(forLineWidth: lineFrag.width)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CollapsedQuoteTextAttachment else { return false }
        return other.shape == shape
            && other.horizontalIndent == horizontalIndent
            && other.leadingInset == leadingInset
            && other.trailingInset == trailingInset
            && other.previewText == previewText
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(shape.id.rawValue)
        hasher.combine(previewText.string)
        hasher.combine(horizontalIndent)
        return hasher.finalize()
    }
}
#endif

#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// An INVISIBLE `NSTextAttachment` that only reserves a square box scaled to the run's font, and
/// carries the `EmojiRef` so the renderer can pool/position the host-provided view (the only visual)
/// and `characterAttributes(from:)` can round-trip the emoji. Draws nothing of its own.
///
/// Sizing: `S = (font.ascender + |font.descender|) * scale`, with the box's baseline offset
/// `y = font.descender`, so the square spans descender→ascender and sits on the baseline like a glyph.
///
/// `renderBoost` enlarges only the VISIBLE host view (see `BlockLayout.attachmentBox`) by that many points,
/// centered on the glyph box — it does NOT touch `attachmentBounds`, so the line height stays put and the
/// extra size bleeds into the line's leading. Used to render body emoji a touch larger than their glyph box.
/// Ungated (iOS 7+): a plain `NSTextAttachment` subclass that works under BOTH layout engines. TextKit 2
/// calls the `location:`-bearing `attachmentBounds` variant (iOS 16+, takes an `NSTextLocation`); TextKit 1
/// calls the classic `characterIndex:` variant. Both reserve the same square box, so the line height matches
/// regardless of engine.
/// PUBLIC so the engine editor can find and host these the way the legacy canvas does — by
/// walking the laid-out text, not through TextKit's view providers.
public final class EmojiTextAttachment: NSTextAttachment, RichTextInlineAttachment {
    public let ref: EmojiRef
    public let scale: CGFloat
    public let renderBoost: CGFloat

    /// A 1×1 clear image ensures TextKit calls `attachmentBounds(...)` and reserves layout space (an
    /// image-less attachment can be laid out as zero-width). It's identical for every emoji and renders
    /// nothing visible, so it's shared (a fresh render per attachment would cost on every reload).
    private static let spacerImage: UIImage =
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }

    public init(ref: EmojiRef, scale: CGFloat, renderBoost: CGFloat = 0) {
        self.ref = ref
        self.scale = scale
        self.renderBoost = renderBoost
        super.init(data: nil, ofType: nil)
        self.image = Self.spacerImage
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Whether `other` is a rendering of the SAME atom with the same geometry — what a document set
    /// asks when it decides whether an engine block changed. Deliberately NOT `isEqual`: two adjacent
    /// atoms with equal attachments would coalesce into one attribute run, and every consumer that
    /// walks attachments expects one object per character. A fresh render of an unchanged model mints
    /// new attachment objects, so `NSAttributedString` equality alone called every block holding one
    /// changed (composer harness p15, `HarnessAtomParagraphReplayIdentityTests`).
    public func drawsTheSameAs(_ other: NSTextAttachment) -> Bool {
        guard let other = other as? EmojiTextAttachment else { return false }
        return ref == other.ref && scale == other.scale && renderBoost == other.renderBoost
    }

    /// The VISIBLE box for a reserved glyph box: the reservation grown by `renderBoost`, centred on
    /// it, so the box stays square and the line height is untouched (the extra size bleeds into the
    /// line's leading). Anything that is not a boosted emoji comes back unchanged, so a caller can
    /// pass every attachment box it has through this.
    ///
    /// **ONE definition, because the boost is the difference between what the LAYOUT RESERVES and
    /// what the reader SEES**, and every surface that hosts an emoji view has to apply it to
    /// whatever box its own text system hands back. Spelled once per surface it drifted, silently:
    /// the legacy canvas reads its box through `BlockLayout.attachmentBox` and grew it, while the
    /// engine editor reads `id_attachmentFrame` — the reservation — and grew it NOWHERE, so the
    /// same 15pt emoji was 17.9pt in an engine block and 21.9pt in a folded quote's preview (which
    /// goes through a layout). That difference is what a device pass reported as "the custom emoji
    /// size differs between collapsed and expanded quotes".
    public static func visibleBox(_ reserved: CGRect, for attachment: NSTextAttachment?) -> CGRect {
        guard let boost = (attachment as? EmojiTextAttachment)?.renderBoost, boost > 0 else {
            return reserved
        }
        return reserved.insetBy(dx: -boost / 2, dy: -boost / 2)
    }

    /// The square box for a given run font: `S = (ascender + |descender|) * scale`, baseline offset
    /// `y = descender`, so it spans descender→ascender and sits on the baseline like a glyph.
    /// `RichTextInlineAttachment`: the same box `attachmentBounds` reserves, so a caller asking
    /// what this does to a line and TextKit laying it out cannot disagree.
    public func reservedBox(forFont font: UIFont) -> CGRect { box(for: font) }

    private func box(for font: UIFont?) -> CGRect {
        let f = font ?? UIFont.preferredFont(forTextStyle: .body)
        let side = (f.ascender - f.descender) * scale   // descender is negative → ascender + |descender|
        return CGRect(x: 0, y: f.descender, width: side, height: side)
    }

    /// TextKit 2 variant (the base takes `NSTextLocation`, iOS 15+). The run font arrives in `attributes`.
    @available(iOS 15.0, *)
    public override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: NSTextLocation,
                                   textContainer: NSTextContainer?, proposedLineFragment: CGRect,
                                   position: CGPoint) -> CGRect {
        box(for: attributes[.font] as? UIFont)
    }

    /// TextKit 1 variant (iOS 7+). No `attributes` are passed, so read the run font from the layout
    /// manager's text storage at `charIndex`.
    public override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let font = textContainer?.layoutManager?.textStorage?
            .attribute(.font, at: charIndex, effectiveRange: nil) as? UIFont
        return box(for: font)
    }
}
#endif

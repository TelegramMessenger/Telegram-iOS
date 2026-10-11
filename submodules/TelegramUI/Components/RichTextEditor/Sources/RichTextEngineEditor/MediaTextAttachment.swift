#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// The attachment character a media block is on the engine's axis (spec §3.6).
///
/// It reserves the slot and draws nothing: the hosted media view is positioned over the frame
/// TextKit gives it (`+MediaHosting.swift`), exactly as an emoji's is. The 1×1 spacer image is what
/// makes TextKit call `attachmentBounds` at all — an image-less attachment can lay out zero-width —
/// the same trick `ButtonTextAttachment` and `EmojiTextAttachment` use.
///
/// The bounds are DYNAMIC: computed from the proposed line fragment on every layout, so a width
/// change (rotation, the composer growing) needs no document edit. The height is legacy's, from
/// `MediaSlotGeometry` at legacy's canvas width — the line plus the bleed on both sides — while the
/// width can only ever be the line's: the bleed is the hosted VIEW's to add.
///
/// Value-equal on purpose, for ONE consumer: the document setter's differing-span diff, which
/// compares rendered blocks with `NSAttributedString.isEqual`. A pointer-unequal atom would read as
/// changed on every set and drag its caption's engine identity into the replaced span, so a caret
/// in the caption would be lost on any set at all.
///
/// `.attachment` is deliberately not a presentation key: settle never rewrites it, which is why
/// `insertMedia` and `applyMediaShape` write it explicitly. So the derived-presentation guard never
/// compares it and is not a second consumer of this equality — an earlier version of this comment
/// claimed it was.
@available(iOS 18.4, *)
public final class MediaTextAttachment: NSTextAttachment {
    public let shape: MediaShape
    public let horizontalBleed: CGFloat
    /// The head indent of the atom's line inside a quote (`quoteIndent × depth`), nesting design §4.4.
    ///
    /// **Probe P1, measured 2026-09-05, answered "full fragment":** TextKit 2 proposes the WHOLE
    /// container width to `attachmentBounds` even for a paragraph carrying a head indent — an image
    /// inside one quote came back 310pt wide on a 310pt container, starting 8pt LEFT of the indented
    /// column edge and overhanging its right edge by 8 (the shape's centred alignment splitting the
    /// 16pt overflow). So the slot is measured against the line MINUS the indent; it is not carried
    /// for equality alone. Part of `isEqual`, like the bleed.
    public let horizontalIndent: CGFloat

    private static let spacerImage: UIImage =
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }

    public init(shape: MediaShape, horizontalBleed: CGFloat, horizontalIndent: CGFloat = 0) {
        self.shape = shape
        self.horizontalBleed = horizontalBleed
        self.horizontalIndent = horizontalIndent
        super.init(data: nil, ofType: nil)
        self.image = Self.spacerImage
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// P1 answered "full fragment", so the indent is the attachment's to remove: the proposed
    /// fragment is the whole container and the column the atom may occupy is that much narrower.
    public func slot(forLineWidth lineWidth: CGFloat) -> CGSize {
        let line = max(lineWidth - horizontalIndent, 1)
        let canvasWidth = line + horizontalBleed * 2
        var size = MediaSlotGeometry.slotSize(items: shape.items, displayMode: shape.displayMode,
                                              displayWidth: shape.displayWidth, maxWidth: canvasWidth)
        size.width = min(size.width, line)
        // **Snapped to the device pixel grid.** The slot is an aspect-ratio computation, so it is an
        // arbitrary fraction (measured 171.2412 tall for a 1000x500 image on this column) — and an
        // atom is a LINE, whose height therefore pushed every block below it onto a fractional
        // origin, which is what puts their selection rects across a pixel. Snapping here rather than
        // in `MediaSlotGeometry` keeps the legacy canvas's media geometry byte-unchanged; the two
        // now differ by at most half a pixel, which is invisible and is not the bleed lockstep that
        // file's header is about.
        //
        // ONE definition for both consumers: the line box (`box(forLineWidth:)`) and the hosted
        // view's frame both come through here, so they cannot disagree about the snapped size.
        //
        return CGSize(width: max(EngineBlockSpacing.snappedToWholePoints(size.width), 1),
                      height: max(EngineBlockSpacing.snappedToWholePoints(size.height), 1))
    }

    /// **The atom declares its own descent, so its LINE BOX is exactly its slot.**
    ///
    /// TextKit sizes a line as `max(ascent) + max(descent)` over its runs. With the bounds at
    /// origin `.zero` the atom is all ascent, so the line came out as the slot PLUS the atom font's
    /// descent — measured: a 171.0 slot on the 1pt `mediaAtomFont` (descender -0.2412) gave a
    /// 171.2412 line, which put every block below the medium onto a fractional origin and their
    /// selection rects across a pixel.
    ///
    /// Dropping the bounds by that descent makes the atom's own descent cover the font's, so the
    /// line is `(h - d) + d = h` — the slot, snapped, on the grid. The atom does not MOVE: its top
    /// is `lineTop + (lineAscent - atomAscent)`, and both shrink by `d` together. The alternative —
    /// padding the slot so `slot + d` lands on the grid — aligns the same line but leaves the image
    /// VIEW on a fractional height, which is a blurred edge to fix a rhythm.
    private var atomDescent: CGFloat { -EngineDocumentBridge.mediaAtomFont.descender }

    /// Whether the slot spans the line it is on — the indented one inside a quote.
    public func fillsLine(ofWidth lineWidth: CGFloat) -> Bool {
        slot(forLineWidth: lineWidth).width >= max(lineWidth - horizontalIndent, 1) - 0.5
    }

    private func box(forLineWidth lineWidth: CGFloat) -> CGRect {
        CGRect(origin: CGPoint(x: 0, y: -atomDescent), size: slot(forLineWidth: lineWidth))
    }

    public override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: NSTextLocation,
                                          textContainer: NSTextContainer?, proposedLineFragment: CGRect,
                                          position: CGPoint) -> CGRect {
        box(forLineWidth: proposedLineFragment.width)
    }

    public override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect,
                                          glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        box(forLineWidth: lineFrag.width)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MediaTextAttachment else { return false }
        return other.shape == shape && other.horizontalBleed == horizontalBleed
            && other.horizontalIndent == horizontalIndent
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(shape.id.rawValue)
        hasher.combine(shape.items.map(\.mediaID))
        hasher.combine(shape.displayMode.rawValue)
        hasher.combine(horizontalIndent)
        return hasher.finalize()
    }
}
#endif

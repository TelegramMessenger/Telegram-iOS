#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// The attachment character a button row is on the engine's axis — the sibling of
/// `MediaTextAttachment`, built to the same rules.
///
/// It reserves the slot and draws nothing: the hosted `RichTextButtonRowView` is positioned over the
/// frame TextKit gives it (`+ButtonRows.swift`), exactly as a media atom's and an emoji's are. The
/// 1×1 spacer image is what makes TextKit call `attachmentBounds` at all — an image-less attachment
/// can lay out zero-width.
///
/// The bounds are DYNAMIC: packed from the proposed line fragment on every layout, so a width change
/// (rotation, the composer growing) re-packs with no document edit. There is no analogue of media's
/// `horizontalBleed` — legacy packs a row into the content column at every depth.
///
/// Value-equal on purpose, for ONE consumer: the document setter's differing-span diff, which
/// compares rendered blocks with `NSAttributedString.isEqual`. A pointer-unequal atom would read as
/// changed on every set.
@available(iOS 18.4, *)
public final class ButtonRowTextAttachment: NSTextAttachment {
    public let shape: ButtonRowShape
    /// The head indent of the atom's line inside a container. Probe P1 (measured 2026-09-05)
    /// established that TextKit 2 proposes the WHOLE container width to `attachmentBounds` even for
    /// a paragraph carrying a head indent, so the column the row may occupy is that much narrower
    /// and the attachment must subtract it itself.
    public let horizontalIndent: CGFloat
    /// Whether the row reserves width for its "…" control. Part of the MEASUREMENT, not only the
    /// drawing, so a composer row (no control, no reserve) matches the sent message exactly.
    public let showsMenuAffordance: Bool

    private let mapper: AttributedStringMapper

    private static let spacerImage: UIImage =
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }

    public init(shape: ButtonRowShape, horizontalIndent: CGFloat,
                showsMenuAffordance: Bool, mapper: AttributedStringMapper) {
        self.shape = shape
        self.horizontalIndent = horizontalIndent
        self.showsMenuAffordance = showsMenuAffordance
        self.mapper = mapper
        super.init(data: nil, ofType: nil)
        self.image = Self.spacerImage
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// The slot for a proposed line width. P1 answered "full fragment", so the indent is the
    /// attachment's to remove.
    public func slot(forLineWidth lineWidth: CGFloat) -> CGSize {
        let line = max(lineWidth - horizontalIndent, 1)
        return CGSize(width: line,
                      height: richTextButtonRowHeight(buttons: shape.buttons, alignment: shape.alignment,
                                                      width: line, mapper: mapper,
                                                      showsMenuAffordance: showsMenuAffordance))
    }

    private func box(proposedLineFragment: CGRect) -> CGRect {
        let size = slot(forLineWidth: proposedLineFragment.width)
        return CGRect(origin: .zero, size: size)
    }

    public override func attachmentBounds(for attributes: [NSAttributedString.Key: Any],
                                          location: NSTextLocation, textContainer: NSTextContainer?,
                                          proposedLineFragment: CGRect, position: CGPoint) -> CGRect {
        box(proposedLineFragment: proposedLineFragment)
    }

    public override func attachmentBounds(for textContainer: NSTextContainer?,
                                          proposedLineFragment lineFrag: CGRect,
                                          glyphPosition position: CGPoint,
                                          characterIndex charIndex: Int) -> CGRect {
        box(proposedLineFragment: lineFrag)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ButtonRowTextAttachment else { return false }
        return other.shape == shape
            && other.horizontalIndent == horizontalIndent
            && other.showsMenuAffordance == showsMenuAffordance
    }
    public override var hash: Int { shape.id.rawValue.hashValue }
}
#endif

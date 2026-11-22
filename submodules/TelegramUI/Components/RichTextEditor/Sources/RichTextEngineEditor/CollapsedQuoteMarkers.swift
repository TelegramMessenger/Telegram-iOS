#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The attachment a non-text block is in a folded quote's preview: one SF Symbol saying what is
/// there. A separate class so the preview can tell its own markers from a custom emoji's
/// `EmojiTextAttachment`, which it hosts a view over instead.
@available(iOS 18.4, *)
public final class CollapsedQuoteMarkerAttachment: NSTextAttachment {
    public let symbolName: String
    public init(symbolName: String, image: UIImage) {
        self.symbolName = symbolName
        super.init(data: nil, ofType: nil)
        self.image = image
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}

/// What a folded quote says about the blocks it holds that have no text of their own.
///
/// A preview that silently dropped a photo would read as content loss — the quote looks shorter than
/// it is. A SYMBOL rather than a word because this package is host-agnostic: a word would need a new
/// host-supplied string surface (the `RichTextEditorPlaceholders` pattern) and would eat real preview
/// width, where three lines is only ~150 characters.
///
/// **A marker costs width, never a LINE.** It is inline, so it cannot change the line count the
/// three-line cap measures — which is what keeps `CollapsedQuoteGeometry.maxPreviewLines` meaning the
/// same thing here, in the V2 renderer and in `InteractiveTextComponent`.
@available(iOS 18.4, *)
public enum CollapsedQuoteMarkers {

    /// nil for a block that contributes its own text; that block is quoted, not marked.
    public static func symbolName(for block: Block) -> String? {
        switch block {
        case let .media(media):
            // An album takes its FIRST item's symbol: the marker says a photo is there, not how
            // many. `items.first` is also what `MediaShape.isCaptionless` keys on.
            switch media.items.first?.kind {
            case .video: return "video"
            case .audio: return "waveform"
            case .document: return "doc"
            case .image, .location, nil: return "photo"
            }
        case .table: return "tablecells"
        case .buttonRow: return "rectangle.and.hand.point.up.left"
        case .paragraph, .code, .pullQuote, .blockQuote, .details: return nil
        }
    }

    /// One marker, tinted with the preview's own foreground and sized to the preview's font, so it
    /// sits on the text's line rather than inflating it.
    ///
    /// Returns an EMPTY string when the block has no symbol or the symbol does not resolve, so a
    /// caller can append unconditionally: a marker is a hint, and a missing one must never cost the
    /// preview its text.
    public static func marker(for block: Block,
                              attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        guard let name = symbolName(for: block) else { return NSAttributedString() }
        let font = (attributes[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 15)
        let colour = (attributes[.foregroundColor] as? UIColor) ?? .label
        let configuration = UIImage.SymbolConfiguration(pointSize: font.pointSize * 0.9, weight: .regular)
        guard let image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(colour, renderingMode: .alwaysOriginal) else {
            return NSAttributedString()
        }
        let attachment = CollapsedQuoteMarkerAttachment(symbolName: name, image: image)
        let marker = NSMutableAttributedString(attachment: attachment)
        // The neighbours' attributes, so the symbol rides the text's own line box rather than
        // inflating it — the same reason the media and button atoms pin `.font` beside `.attachment`.
        marker.addAttributes(attributes, range: NSRange(location: 0, length: marker.length))
        return marker
    }
}
#endif

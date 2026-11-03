#if canImport(UIKit)
import UIKit

/// Per-host geometry for media blocks (image / video / location / audio). Every field defaults to the
/// editor's built-in (reference-design) look, so a host that never sets `RichTextEditorView.mediaBlockStyle`
/// is unchanged. The chat composer sets `horizontalBleed: 0` so media insets exactly like the text
/// paragraphs; the document / article editor keeps the default edge-to-edge bleed.
///
/// A growable value set (parallel to `QuoteStyle`): more knobs may be added over time.
@available(iOS 13.0, *)
public struct MediaBlockStyle: Equatable {
    /// How far a top-level media block extends BEYOND the text content strip on each side, in points.
    /// The media frame is positioned on the text strip (left/width from layout) and then bled out by this
    /// amount on each side. The default (16, == `CanvasMetrics.pageMargin`) makes a full-page-document
    /// image run edge-to-edge to the canvas edge; a compact host (the chat composer) sets 0 so media
    /// insets exactly like the text paragraphs (left/right). → `MediaBlockBox.horizontalBleed`.
    public var horizontalBleed: CGFloat

    public init(horizontalBleed: CGFloat = 16) {
        self.horizontalBleed = horizontalBleed
    }

    /// The editor's built-in document look: media bleeds across the page margin to the canvas edge.
    public static let `default` = MediaBlockStyle()
}
#endif

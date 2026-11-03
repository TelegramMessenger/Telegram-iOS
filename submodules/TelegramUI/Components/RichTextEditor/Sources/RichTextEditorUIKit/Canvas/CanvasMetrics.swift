#if canImport(UIKit)
import CoreGraphics

/// Document-level layout metrics shared across block types.
@available(iOS 13.0, *)
enum CanvasMetrics {
    /// Horizontal page margin: text/tables inset by this; images bleed past it to the canvas edge.
    static let pageMargin: CGFloat = 16
}
#endif

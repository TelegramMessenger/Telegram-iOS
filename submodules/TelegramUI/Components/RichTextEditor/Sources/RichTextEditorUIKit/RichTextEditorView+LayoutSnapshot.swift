#if canImport(UIKit)
import UIKit

/// A measurement of what the editor laid out, for cross-renderer parity testing.
@available(iOS 13.0, *)
public struct RichTextLayoutSnapshot: Equatable {
    /// Canvas-coordinate frame of each top-level block, in document order.
    public let blockFrames: [CGRect]
    /// Canvas-coordinate origin of each top-level block's TEXT, in document order. This is the
    /// directly comparable quantity against the renderer, whose laid-out items are flat render items
    /// (`.text`, `.listMarker`, bars) rather than per-block boxes — and it is what a reader sees,
    /// independent of how either side apportions inter-block space into insets.
    public let textOrigins: [CGPoint]
    /// The root stack's laid-out height (excludes the canvas's own content margins).
    public let contentHeight: CGFloat

    public init(blockFrames: [CGRect], textOrigins: [CGPoint], contentHeight: CGFloat) {
        self.blockFrames = blockFrames
        self.textOrigins = textOrigins
        self.contentHeight = contentHeight
    }
}

#if DEBUG
@available(iOS 13.0, *)
public extension RichTextEditorView {
    /// The laid-out geometry of the current document, for asserting parity against the InstantPage V2
    /// renderer (`RichTextV2FrameParityTests`).
    ///
    /// DEBUG-only and deliberately narrow: it exposes MEASUREMENTS, not internals, so
    /// `DocumentCanvasView` and its `UITextInput` witnesses stay internal — a public type conforming to
    /// public `UITextInput` would force every witness public. Call after `update(size:insets:)`.
    func layoutSnapshot() -> RichTextLayoutSnapshot {
        return RichTextLayoutSnapshot(blockFrames: canvas.root.boxes.map { $0.frame },
                                      textOrigins: canvas.root.boxes.map { $0.textOrigin },
                                      contentHeight: canvas.root.contentHeight)
    }
}
#endif
#endif

#if canImport(UIKit)
import UIKit

/// Per-host geometry for pull-quote blocks. Every field defaults to the built-in look, so a host that never sets
/// `RichTextEditorView.pullQuoteStyle` is unchanged. Consolidates the constants introduced across the render tasks.
@available(iOS 13.0, *)
public struct PullQuoteStyle: Equatable {
    /// Interior horizontal padding: text→pill-edge on each side (points). Also the pill's horizontal breathing room.
    public var horizontalPadding: CGFloat
    /// Interior TOP padding (points): pill top edge → first text line. Manual (default 0). The corner marks
    /// inset the content HORIZONTALLY and never overlap it vertically, so no vertical clearance is needed here.
    public var topInset: CGFloat
    /// Interior BOTTOM padding (points): last text line → pill bottom edge. Manual (default 0).
    public var bottomInset: CGFloat
    /// Pill corner radius (points).
    public var cornerRadius: CGFloat
    /// Pill fill opacity (0…1).
    public var fillAlpha: CGFloat
    /// Inset of each corner mark from the pill's corner (points).
    public var markInset: CGFloat
    /// Minimum pill width (points) — the floor for a short/empty pull quote so the corner marks + placeholder fit.
    public var minWidth: CGFloat
    /// Vertical gap (points) between the pull text's last line and the author line.
    public var authorSpacing: CGFloat

    public init(horizontalPadding: CGFloat = 30, topInset: CGFloat = 8.0, bottomInset: CGFloat = 8.0,
                cornerRadius: CGFloat = 6.0, fillAlpha: CGFloat = 0.10,
                markInset: CGFloat = 6, minWidth: CGFloat = 0, authorSpacing: CGFloat = 1) {
        self.horizontalPadding = horizontalPadding
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.cornerRadius = cornerRadius
        self.fillAlpha = fillAlpha
        self.markInset = markInset
        self.minWidth = minWidth
        self.authorSpacing = authorSpacing
    }

    public static let `default` = PullQuoteStyle()
}
#endif

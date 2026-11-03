#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The per-item descriptor the editor hands the media-view provider for each medium in a container.
@available(iOS 13.0, *)
public struct MediaProviderItem {
    public let mediaID: String
    public let kind: MediaKind
    public let naturalSize: CGSize
    /// Telegram-style spoiler flag for this medium — drives the non-revealable dust cover the host draws
    /// over the cell in the editor authoring preview. No default: every construction site must thread it.
    public let isSpoiler: Bool
    public init(mediaID: String, kind: MediaKind, naturalSize: CGSize, isSpoiler: Bool) {
        self.mediaID = mediaID
        self.kind = kind
        self.naturalSize = naturalSize
        self.isSpoiler = isSpoiler
    }
}

/// A host-supplied view that renders one attached medium (image/video). The editor creates it once
/// per media occurrence (via the registered provider), owns/positions/culls it, and calls
/// `update(size:)` on every layout pass with the current display rect; resize in place and keep it
/// cheap (idempotent) — so a heavy backing (e.g. an `InstantPageImageNode`) is resized in place
/// rather than rebuilt. The view is non-interactive from the editor's perspective; it lays itself
/// out against its own `bounds`.
@available(iOS 13.0, *)
public protocol RichTextMediaItemView: UIView {
    func update(size: CGSize)

    /// Set by the editor when it binds this view: fired when one of the view's interactive controls (the
    /// more button; the "+" button later) is tapped, with the control kind, the tapped item's index within
    /// the container (`nil` = the whole block, e.g. the more menu), the tapped control's view, and its rect
    /// in that view. Views with no controls (audio/location) leave it unused.
    var onControlTapped: ((RichTextMediaControlKind, _ itemIndex: Int?, _ anchorView: UIView, _ sourceRect: CGRect) -> Void)? { get set }
}
#endif

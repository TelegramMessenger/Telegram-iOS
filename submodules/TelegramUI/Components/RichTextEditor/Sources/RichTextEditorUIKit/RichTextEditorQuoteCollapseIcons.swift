#if canImport(UIKit)
import UIKit

/// Host-injected icons for the quote collapse/expand affordance. Both are required (non-optional): the
/// editor package ships no fallback, so a host that wants the affordance MUST supply both. The chat
/// composer and the article editor pass `Media Gallery/Minimize` / `Media Gallery/Fullscreen`.
@available(iOS 13.0, *)
public struct RichTextEditorQuoteCollapseIcons: Equatable {
    /// Shown on a tall EXPANDED quote run — tap to collapse.
    public var collapse: UIImage
    /// Shown on a COLLAPSED quote — tap to expand.
    public var expand: UIImage
    public init(collapse: UIImage, expand: UIImage) {
        self.collapse = collapse
        self.expand = expand
    }
}
#endif

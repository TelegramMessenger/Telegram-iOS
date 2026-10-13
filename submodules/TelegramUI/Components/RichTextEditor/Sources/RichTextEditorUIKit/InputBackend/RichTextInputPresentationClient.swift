#if canImport(UIKit)
import UIKit

/// Telegram owns all visible selection presentation. The backend may drive state but cannot add,
/// remove, reparent, or mutate Telegram's caret, selection wash, handles, table chrome, or custom
/// loupe visuals directly.
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputPresentationClient: AnyObject {
    /// Stable for the backend lifetime. It gives UIKit interaction machinery a host and
    /// coordinate-conversion surface; it does not grant drawing authority to UIKit. The container is
    /// supplied by Telegram, not created by the backend.
    var interactionContainerView: UIView { get }

    var visibleBounds: CGRect { get }

    /// Idempotent. Equal snapshots cannot restart caret blinking, recreate handles, or disrupt
    /// scroll-host identity.
    func apply(_ snapshot: RichTextInputPresentationSnapshot)

    func invalidate(
        _ invalidation: RichTextInputPresentationInvalidation
    )

    func requestReveal(
        _ target: RichTextInputRevealTarget,
        animated: Bool
    )

    func dismissEditMenu(
        reason: RichTextInputEditMenuDismissReason
    )

    func tearDownPresentation()
}
#endif

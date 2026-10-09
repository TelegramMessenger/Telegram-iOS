import Foundation
import UIKit
import Display
import ContextUI
import TelegramPresentationData

/// Presents an owner-built media context menu as a Telegram `ContextController`, anchored to the tapped
/// control's view. Shared by both editor hosts (chat composer + attachment screen); only the ContextController
/// anchoring/presentation boilerplate is shared — the `items` are owner-specific. Mirrors
/// `RichTextActionContextReferenceSource` (the attachment screen's action menu): the ContextController
/// references `anchorView` **directly** and snapshots it for the transition — it does NOT reparent it or add
/// subviews to it. (Unlike `presentTableStructuralMenu`, which must synthesize a transient anchor view because
/// a drawn table handle has no real view at its rect; `anchorView` here IS the tapped control — the glass
/// "more" button — so adding a transient subview would trip `GlassBackgroundContainerView.didAddSubview`.)
@available(iOS 13.0, *)
public func presentMediaControlMenu(
    anchorView: UIView,
    items: [ContextMenuItem],
    presentationData: PresentationData,
    present: (ViewController) -> Void
) {
    let controller = makeContextController(
        presentationData: presentationData,
        source: .reference(MediaControlMenuReferenceSource(sourceView: anchorView)),
        items: .single(ContextController.Items(content: .list(items))),
        gesture: nil
    )
    present(controller)
}

/// Anchors a `ContextController` to the tapped control's view (referenced directly, not reparented).
@available(iOS 13.0, *)
private final class MediaControlMenuReferenceSource: ContextReferenceContentSource {
    private let sourceView: UIView
    init(sourceView: UIView) { self.sourceView = sourceView }
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView,
            contentAreaInScreenSpace: mainWindowScreenBounds,
            insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0), actionsPosition: .bottom)
    }
}

import Foundation
import UIKit
import Display

/// Stands in for the chat's context menu controller (`setContextMenuControllerProvider`), which a text selection
/// presents for its actions (Copy, Select All): it keeps the actions for the harness to show as buttons
/// (`harness.menu.<title>`), and tells the harness when it is dismissed. It is never presented itself.
public final class WidgetHarnessContextMenuController: ViewController, ContextMenuController {
    public let actions: [ContextMenuAction]
    public var centerHorizontally = false
    public var dismissed: (() -> Void)?
    public var dismissOnTap: ((UIView, CGPoint) -> Bool)?
    /// Set by the harness when it shows the actions.
    public var onDismiss: (() -> Void)?

    public init(actions: [ContextMenuAction]) {
        self.actions = actions
        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder: NSCoder) {
        preconditionFailure()
    }

    /// An action's title, as the harness names its button.
    public static func title(of action: ContextMenuAction) -> String {
        switch action.content {
        case let .text(title, _):
            return title
        case let .textWithIcon(title, _):
            return title
        case let .textWithSubtitleAndIcon(title, _, _):
            return title
        case .icon:
            return "icon"
        }
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        let onDismiss = self.onDismiss
        self.onDismiss = nil
        onDismiss?()
        self.dismissed?()
        completion?()
    }
}

import Foundation

/// SDK v1 §5.2 (V2b plan, Task 8): one widget link dialog at a time across the app; an action that arrives while one is
/// shown is dropped. Each request is told, through `displayUpdated`, the dialog it shows (its controller) and nil when
/// it goes; a late report from an earlier dialog does not touch the current one. The dialog is held weakly, so one
/// that goes without a report (it was never presented, or a dismissal path that does not call back) stops blocking
/// once it is released. Main thread only.
public final class MessageWidgetLinkDialog {
    public static let shared = MessageWidgetLinkDialog()

    /// The request whose dialog is shown now, and that dialog.
    private var shown: Int?
    private weak var shownDialog: AnyObject?
    private var nextRequest = 0

    public init() {
    }

    /// Runs `open` and answers true, unless a widget's dialog is shown: then it answers false and runs nothing.
    @discardableResult
    public func request(_ open: (_ displayUpdated: @escaping (AnyObject?) -> Void) -> Void) -> Bool {
        if self.shown != nil && self.shownDialog != nil {
            return false
        }
        self.shown = nil
        self.nextRequest += 1
        let request = self.nextRequest
        open({ [weak self] dialog in
            guard let self else {
                return
            }
            if let dialog {
                self.shown = request
                self.shownDialog = dialog
            } else if self.shown == request {
                self.shown = nil
                self.shownDialog = nil
            }
        })
        return true
    }
}

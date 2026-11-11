import Foundation

/// Whether the app is active, for every message widget at once: a widget runs its timers and frames only while
/// it is, as an app in the background stays alive during a call or audio playback. The host app feeds it from one
/// place (its own active-state signal), so the module never reads `UIApplication`. Active until told otherwise.
/// Main thread only.
public final class MessageWidgetApplicationState {
    public static let shared = MessageWidgetApplicationState()

    static let didChangeNotification = Notification.Name("MessageWidgetApplicationStateDidChange")

    public var isActive: Bool = true {
        didSet {
            assert(Thread.isMainThread, "MessageWidgetApplicationState is main-thread only")
            if oldValue != self.isActive {
                NotificationCenter.default.post(name: MessageWidgetApplicationState.didChangeNotification, object: self)
            }
        }
    }
}

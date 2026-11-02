import Foundation

/// Tells widget bubbles that whether a widget may run can have changed: the server's kill switch
/// (`MessageWidgetKillSwitch`, which posts it when it flips). A bubble decides in its layout pass, and a bubble
/// whose widget never changes size is not laid out again by itself, so each one observes this and asks for its own
/// relayout when the answer differs from its last pass: switching widgets off stops the running ones in an open chat,
/// and switching them on replaces the pills.
public enum MessageWidgetAvailability {
    public static let didChangeNotification = Notification.Name("MessageWidgetAvailabilityDidChange")

    /// Posts `didChangeNotification` on the main queue: at once on main, otherwise asynchronously.
    public static func noteChange() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: MessageWidgetAvailability.didChangeNotification, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: MessageWidgetAvailability.didChangeNotification, object: nil)
            }
        }
    }
}

import Foundation

/// Whether the server has switched message widgets off (`ios_killswitch_disable_message_widgets` in the app
/// configuration). The host app sets it each time an account's app configuration arrives, so the bubble resolver and
/// every layout pass read one flag, on any thread, instead of looking the key up in the app configuration, which is
/// expensive. With several accounts the configuration that arrived last decides, as for the other process-wide
/// switches set there. Off until told otherwise. A flip posts `MessageWidgetAvailability`'s change, so a widget
/// already running in an open chat stops at once.
public enum MessageWidgetKillSwitch {
    public static let appConfigurationKey = "ios_killswitch_disable_message_widgets"

    private static let lock = NSLock()
    private static var engaged = false

    public static var isEngaged: Bool {
        get {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            return self.engaged
        }
        set {
            self.lock.lock()
            let changed = self.engaged != newValue
            self.engaged = newValue
            self.lock.unlock()
            if changed {
                MessageWidgetAvailability.noteChange()
            }
        }
    }
}

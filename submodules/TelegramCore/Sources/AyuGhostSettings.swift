import Foundation

/// Shared preference storage for AyuGram Ghost Mode and Anti-Delete.
///
/// This file only stores settings. The corresponding network and message
/// handling code must read these flags before the related operations are sent
/// or messages are removed. Until those integration points are implemented,
/// changing a flag here does not enable the feature by itself.
public enum AyuGhostSettings {
    private enum Key {
        static let hideTyping = "ayu.ghost.hideTyping"
        static let hideOnline = "ayu.ghost.hideOnline"
        static let hideRead = "ayu.ghost.hideRead"
        static let saveDeleted = "ayu.antidelete.saveDeleted"
        static let deletedRetentionDays = "ayu.antidelete.retentionDays"
    }

    private static let defaults = UserDefaults.standard

    /// Preference for suppressing outgoing typing and input-activity updates.
    /// Requires a check in the network activity handler.
    public static var hideTyping: Bool {
        get { return defaults.bool(forKey: Key.hideTyping) }
        set { defaults.set(newValue, forKey: Key.hideTyping) }
    }

    /// Preference for controlling outgoing online-presence updates.
    /// Requires integration with the account-presence network handler.
    public static var hideOnline: Bool {
        get { return defaults.bool(forKey: Key.hideOnline) }
        set { defaults.set(newValue, forKey: Key.hideOnline) }
    }

    /// Preference for suppressing outgoing read acknowledgements.
    /// Requires integration with message read-history handling.
    public static var hideRead: Bool {
        get { return defaults.bool(forKey: Key.hideRead) }
        set { defaults.set(newValue, forKey: Key.hideRead) }
    }

    /// Whether incoming messages should be copied to a separate store before
    /// deletion updates are applied. Requires Anti-Delete storage integration.
    public static var saveDeleted: Bool {
        get { return defaults.bool(forKey: Key.saveDeleted) }
        set { defaults.set(newValue, forKey: Key.saveDeleted) }
    }

    /// Retention period for saved deleted messages; 0 means no automatic expiry.
    public static var deletedRetentionDays: Int {
        get { return defaults.integer(forKey: Key.deletedRetentionDays) }
        set { defaults.set(newValue, forKey: Key.deletedRetentionDays) }
    }

    /// Convenience switch for the three Ghost Mode preferences.
    public static var ghostModeEnabled: Bool {
        get { return hideTyping && hideOnline && hideRead }
        set {
            hideTyping = newValue
            hideOnline = newValue
            hideRead = newValue
        }
    }
}

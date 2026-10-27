import Foundation

/// Client-side options of the "Twelve" settings screen (Settings ▸ Настройки Twelve).
///
/// Values live in the app's standard `UserDefaults`, so they are global for every account and are read
/// synchronously from any thread (rendering code reads `disableFakeGlass` on every layout pass, network
/// code reads the ghost-mode flags right before a request). Extensions see the defaults (everything off).
public final class TwelveSettings {
    public enum Key: String, CaseIterable {
        /// Draw a plain blur instead of the custom "fake" glass (the one drawn below iOS 26 or with the
        /// fake glass debug switch). Native iOS 26 liquid glass is untouched.
        case disableFakeGlass = "twelve.disableFakeGlass"
        /// Do not request sponsored messages, sponsored search peers or the proxy promo chat.
        case hideAds = "twelve.hideAds"
        /// Keep messages that others delete and mark them as deleted.
        case saveDeletedMessages = "twelve.saveDeletedMessages"
        /// Keep the previous text of edited messages.
        case saveEditHistory = "twelve.saveEditHistory"
        /// Ghost mode: never report "online".
        case ghostOnline = "twelve.ghostOnline"
        /// Ghost mode: never send typing and other input activities.
        case ghostTyping = "twelve.ghostTyping"
        /// Ghost mode: do not send read receipts.
        case ghostRead = "twelve.ghostRead"
        /// Ghost mode: view stories without being counted as a viewer.
        case ghostStories = "twelve.ghostStories"
    }
    
    public static let didChangeNotification = Notification.Name("TwelveSettingsDidChange")
    
    private static let lock = NSLock()
    private static var cache: [Key: Bool] = [:]
    
    public static func value(_ key: Key) -> Bool {
        lock.lock()
        if let value = cache[key] {
            lock.unlock()
            return value
        }
        let value = UserDefaults.standard.bool(forKey: key.rawValue)
        cache[key] = value
        lock.unlock()
        return value
    }
    
    public static func set(_ key: Key, value: Bool) {
        lock.lock()
        cache[key] = value
        UserDefaults.standard.set(value, forKey: key.rawValue)
        lock.unlock()
        NotificationCenter.default.post(name: didChangeNotification, object: nil, userInfo: ["key": key.rawValue])
    }
    
    public static var disableFakeGlass: Bool {
        return value(.disableFakeGlass)
    }
    public static var hideAds: Bool {
        return value(.hideAds)
    }
    public static var saveDeletedMessages: Bool {
        return value(.saveDeletedMessages)
    }
    public static var saveEditHistory: Bool {
        return value(.saveEditHistory)
    }
    public static var ghostOnline: Bool {
        return value(.ghostOnline)
    }
    public static var ghostTyping: Bool {
        return value(.ghostTyping)
    }
    public static var ghostRead: Bool {
        return value(.ghostRead)
    }
    public static var ghostStories: Bool {
        return value(.ghostStories)
    }
}

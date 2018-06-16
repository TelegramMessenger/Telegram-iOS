import Foundation
import Postbox
import SwiftSignalKit

public enum TotalUnreadCountDisplayStyle: Int32 {
    case filtered = 0
    case raw = 1
}

public struct InAppNotificationSettings: PreferencesEntry, Equatable {
    public let playSounds: Bool
    public let vibrate: Bool
    public let displayPreviews: Bool
    public let totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle
    
    public static var defaultSettings: InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: true, vibrate: false, displayPreviews: true, totalUnreadCountDisplayStyle: .filtered)
    }
    
    init(playSounds: Bool, vibrate: Bool, displayPreviews: Bool, totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle) {
        self.playSounds = playSounds
        self.vibrate = vibrate
        self.displayPreviews = displayPreviews
        self.totalUnreadCountDisplayStyle = totalUnreadCountDisplayStyle
    }
    
    public init(decoder: PostboxDecoder) {
        self.playSounds = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.vibrate = decoder.decodeInt32ForKey("v", orElse: 0) != 0
        self.displayPreviews = decoder.decodeInt32ForKey("p", orElse: 0) != 0
        self.totalUnreadCountDisplayStyle = TotalUnreadCountDisplayStyle(rawValue: decoder.decodeInt32ForKey("tds", orElse: 0)) ?? .filtered
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.playSounds ? 1 : 0, forKey: "s")
        encoder.encodeInt32(self.vibrate ? 1 : 0, forKey: "v")
        encoder.encodeInt32(self.displayPreviews ? 1 : 0, forKey: "p")
        encoder.encodeInt32(self.totalUnreadCountDisplayStyle.rawValue, forKey: "tds")
    }
    
    func withUpdatedPlaySounds(_ playSounds: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: playSounds, vibrate: self.vibrate, displayPreviews: self.displayPreviews, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle)
    }
    
    func withUpdatedVibrate(_ vibrate: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: self.playSounds, vibrate: vibrate, displayPreviews: self.displayPreviews, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle)
    }
    
    func withUpdatedDisplayPreviews(_ displayPreviews: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: self.playSounds, vibrate: self.vibrate, displayPreviews: displayPreviews, totalUnreadCountDisplayStyle: self.totalUnreadCountDisplayStyle)
    }
    
    func withUpdatedTotalUnreadCountDisplayStyle(_ totalUnreadCountDisplayStyle: TotalUnreadCountDisplayStyle) -> InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: self.playSounds, vibrate: self.vibrate, displayPreviews: self.displayPreviews, totalUnreadCountDisplayStyle: totalUnreadCountDisplayStyle)
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? InAppNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: InAppNotificationSettings, rhs: InAppNotificationSettings) -> Bool {
        if lhs.playSounds != rhs.playSounds {
            return false
        }
        if lhs.vibrate != rhs.vibrate {
            return false
        }
        if lhs.displayPreviews != rhs.displayPreviews {
            return false
        }
        if lhs.totalUnreadCountDisplayStyle != rhs.totalUnreadCountDisplayStyle {
            return false
        }
        return true
    }
}

func updateInAppNotificationSettingsInteractively(postbox: Postbox, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.inAppNotificationSettings, { entry in
            let currentSettings: InAppNotificationSettings
            if let entry = entry as? InAppNotificationSettings {
                currentSettings = entry
            } else {
                currentSettings = InAppNotificationSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

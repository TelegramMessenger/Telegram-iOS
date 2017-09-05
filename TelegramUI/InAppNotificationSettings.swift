import Foundation
import Postbox
import SwiftSignalKit

struct InAppNotificationSettings: PreferencesEntry, Equatable {
    let playSounds: Bool
    let vibrate: Bool
    let displayPreviews: Bool
    
    static var defaultSettings: InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: true, vibrate: false, displayPreviews: true)
    }
    
    init(playSounds: Bool, vibrate: Bool, displayPreviews: Bool) {
        self.playSounds = playSounds
        self.vibrate = vibrate
        self.displayPreviews = displayPreviews
    }
    
    init(decoder: PostboxDecoder) {
        self.playSounds = decoder.decodeInt32ForKey("s", orElse: 0) != 0
        self.vibrate = decoder.decodeInt32ForKey("v", orElse: 0) != 0
        self.displayPreviews = decoder.decodeInt32ForKey("p", orElse: 0) != 0
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.playSounds ? 1 : 0, forKey: "s")
        encoder.encodeInt32(self.vibrate ? 1 : 0, forKey: "v")
        encoder.encodeInt32(self.displayPreviews ? 1 : 0, forKey: "p")
    }
    
    func withUpdatedPlaySounds(_ playSounds: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: playSounds, vibrate: self.vibrate, displayPreviews: self.displayPreviews)
    }
    
    func withUpdatedVibrate(_ vibrate: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: self.playSounds, vibrate: vibrate, displayPreviews: self.displayPreviews)
    }
    
    func withUpdatedDisplayPreviews(_ displayPreviews: Bool) -> InAppNotificationSettings {
        return InAppNotificationSettings(playSounds: self.playSounds, vibrate: self.vibrate, displayPreviews: displayPreviews)
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? InAppNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    static func ==(lhs: InAppNotificationSettings, rhs: InAppNotificationSettings) -> Bool {
        if lhs.playSounds != rhs.playSounds {
            return false
        }
        if lhs.vibrate != rhs.vibrate {
            return false
        }
        if lhs.displayPreviews != rhs.displayPreviews {
            return false
        }
        return true
    }
}

func updateInAppNotificationSettingsInteractively(postbox: Postbox, _ f: @escaping (InAppNotificationSettings) -> InAppNotificationSettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.inAppNotificationSettings, { entry in
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

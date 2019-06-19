import Foundation
import Postbox
import SwiftSignalKit

public struct MediaInputSettings: PreferencesEntry, Equatable {
    public let enableRaiseToSpeak: Bool
    
    public static var defaultSettings: MediaInputSettings {
        return MediaInputSettings(enableRaiseToSpeak: true)
    }
    
    public init(enableRaiseToSpeak: Bool) {
        self.enableRaiseToSpeak = enableRaiseToSpeak
    }
    
    public init(decoder: PostboxDecoder) {
        self.enableRaiseToSpeak = decoder.decodeInt32ForKey("enableRaiseToSpeak", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enableRaiseToSpeak ? 1 : 0, forKey: "enableRaiseToSpeak")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? MediaInputSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: MediaInputSettings, rhs: MediaInputSettings) -> Bool {
        return lhs.enableRaiseToSpeak == rhs.enableRaiseToSpeak
    }
    
    public func withUpdatedEnableRaiseToSpeak(_ enableRaiseToSpeak: Bool) -> MediaInputSettings {
        return MediaInputSettings(enableRaiseToSpeak: enableRaiseToSpeak)
    }
}

public func updateMediaInputSettingsInteractively(accountManager: AccountManager, _ f: @escaping (MediaInputSettings) -> MediaInputSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.mediaInputSettings, { entry in
            let currentSettings: MediaInputSettings
            if let entry = entry as? MediaInputSettings {
                currentSettings = entry
            } else {
                currentSettings = MediaInputSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

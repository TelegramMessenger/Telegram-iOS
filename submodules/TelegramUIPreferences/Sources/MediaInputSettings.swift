import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct MediaInputSettings: Codable, Equatable {
    public let enableRaiseToSpeak: Bool
    
    public static var defaultSettings: MediaInputSettings {
        return MediaInputSettings(enableRaiseToSpeak: true)
    }
    
    public init(enableRaiseToSpeak: Bool) {
        self.enableRaiseToSpeak = enableRaiseToSpeak
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.enableRaiseToSpeak = (try container.decode(Int32.self, forKey: "enableRaiseToSpeak")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.enableRaiseToSpeak ? 1 : 0) as Int32, forKey: "enableRaiseToSpeak")
    }
    
    public static func ==(lhs: MediaInputSettings, rhs: MediaInputSettings) -> Bool {
        return lhs.enableRaiseToSpeak == rhs.enableRaiseToSpeak
    }
    
    public func withUpdatedEnableRaiseToSpeak(_ enableRaiseToSpeak: Bool) -> MediaInputSettings {
        return MediaInputSettings(enableRaiseToSpeak: enableRaiseToSpeak)
    }
}

public func updateMediaInputSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (MediaInputSettings) -> MediaInputSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.mediaInputSettings, { entry in
            let currentSettings: MediaInputSettings
            if let entry = entry?.get(MediaInputSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = MediaInputSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

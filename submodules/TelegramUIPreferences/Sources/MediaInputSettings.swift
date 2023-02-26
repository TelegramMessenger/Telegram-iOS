import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct MediaInputSettings: Codable, Equatable {
    public let enableRaiseToSpeak: Bool
    public let pauseMusicOnRecording: Bool
    
    public static var defaultSettings: MediaInputSettings {
        return MediaInputSettings(enableRaiseToSpeak: true, pauseMusicOnRecording: true)
    }
    
    public init(enableRaiseToSpeak: Bool, pauseMusicOnRecording: Bool) {
        self.enableRaiseToSpeak = enableRaiseToSpeak
        self.pauseMusicOnRecording = pauseMusicOnRecording
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.enableRaiseToSpeak = (try container.decode(Int32.self, forKey: "enableRaiseToSpeak")) != 0
        self.pauseMusicOnRecording = (try container.decodeIfPresent(Int32.self, forKey: "pauseMusicOnRecording_v2") ?? 1) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.enableRaiseToSpeak ? 1 : 0) as Int32, forKey: "enableRaiseToSpeak")
        try container.encode((self.pauseMusicOnRecording ? 1 : 0) as Int32, forKey: "pauseMusicOnRecording_v2")
    }
    
    public static func ==(lhs: MediaInputSettings, rhs: MediaInputSettings) -> Bool {
        return lhs.enableRaiseToSpeak == rhs.enableRaiseToSpeak && lhs.pauseMusicOnRecording == rhs.pauseMusicOnRecording
    }
    
    public func withUpdatedEnableRaiseToSpeak(_ enableRaiseToSpeak: Bool) -> MediaInputSettings {
        return MediaInputSettings(enableRaiseToSpeak: enableRaiseToSpeak, pauseMusicOnRecording: self.pauseMusicOnRecording)
    }
    
    public func withUpdatedPauseMusicOnRecording(_ pauseMusicOnRecording: Bool) -> MediaInputSettings {
        return MediaInputSettings(enableRaiseToSpeak: self.enableRaiseToSpeak, pauseMusicOnRecording: pauseMusicOnRecording)
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

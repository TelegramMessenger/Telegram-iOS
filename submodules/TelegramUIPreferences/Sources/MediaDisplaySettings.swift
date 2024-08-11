import Foundation
import TelegramCore
import SwiftSignalKit

public struct MediaDisplaySettings: Codable, Equatable {
    public let showNextMediaOnTap: Bool
    public let showSensitiveContent: Bool
    
    public static var defaultSettings: MediaDisplaySettings {
        return MediaDisplaySettings(showNextMediaOnTap: true, showSensitiveContent: false)
    }
    
    public init(showNextMediaOnTap: Bool, showSensitiveContent: Bool) {
        self.showNextMediaOnTap = showNextMediaOnTap
        self.showSensitiveContent = showSensitiveContent
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.showNextMediaOnTap = (try container.decode(Int32.self, forKey: "showNextMediaOnTap")) != 0
        self.showSensitiveContent = (try container.decode(Int32.self, forKey: "showSensitiveContent")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.showNextMediaOnTap ? 1 : 0) as Int32, forKey: "showNextMediaOnTap")
        try container.encode((self.showSensitiveContent ? 1 : 0) as Int32, forKey: "showSensitiveContent")
    }
    
    public static func ==(lhs: MediaDisplaySettings, rhs: MediaDisplaySettings) -> Bool {
        return lhs.showNextMediaOnTap == rhs.showNextMediaOnTap && lhs.showSensitiveContent == rhs.showSensitiveContent
    }
    
    public func withUpdatedShowNextMediaOnTap(_ showNextMediaOnTap: Bool) -> MediaDisplaySettings {
        return MediaDisplaySettings(showNextMediaOnTap: showNextMediaOnTap, showSensitiveContent: self.showSensitiveContent)
    }
    
    public func withUpdatedShowSensitiveContent(_ showSensitiveContent: Bool) -> MediaDisplaySettings {
        return MediaDisplaySettings(showNextMediaOnTap: self.showNextMediaOnTap, showSensitiveContent: showSensitiveContent)
    }
}

public func updateMediaDisplaySettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (MediaDisplaySettings) -> MediaDisplaySettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.mediaDisplaySettings, { entry in
            let currentSettings: MediaDisplaySettings
            if let entry = entry?.get(MediaDisplaySettings.self) {
                currentSettings = entry
            } else {
                currentSettings = MediaDisplaySettings.defaultSettings
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}

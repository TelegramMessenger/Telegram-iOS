import Foundation
import TelegramCore
import SwiftSignalKit

public struct MediaDisplaySettings: Codable, Equatable {
    public let showNextMediaOnTap: Bool
    
    public static var defaultSettings: MediaDisplaySettings {
        return MediaDisplaySettings(showNextMediaOnTap: true)
    }
    
    public init(showNextMediaOnTap: Bool) {
        self.showNextMediaOnTap = showNextMediaOnTap
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.showNextMediaOnTap = (try container.decode(Int32.self, forKey: "showNextMediaOnTap")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.showNextMediaOnTap ? 1 : 0) as Int32, forKey: "showNextMediaOnTap")
    }
    
    public static func ==(lhs: MediaDisplaySettings, rhs: MediaDisplaySettings) -> Bool {
        return lhs.showNextMediaOnTap == rhs.showNextMediaOnTap
    }
    
    public func withUpdatedShowNextMediaOnTap(_ showNextMediaOnTap: Bool) -> MediaDisplaySettings {
        return MediaDisplaySettings(showNextMediaOnTap: showNextMediaOnTap)
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

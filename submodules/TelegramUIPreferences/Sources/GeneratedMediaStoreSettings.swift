import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct GeneratedMediaStoreSettings: Codable, Equatable {
    public let storeEditedPhotos: Bool
    public let storeCapturedMedia: Bool
    
    public static var defaultSettings: GeneratedMediaStoreSettings {
        return GeneratedMediaStoreSettings(storeEditedPhotos: true, storeCapturedMedia: true)
    }
    
    public init(storeEditedPhotos: Bool, storeCapturedMedia: Bool) {
        self.storeEditedPhotos = storeEditedPhotos
        self.storeCapturedMedia = storeCapturedMedia
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.storeEditedPhotos = (try container.decode(Int32.self, forKey: "eph")) != 0
        self.storeCapturedMedia = (try container.decode(Int32.self, forKey: "cpm")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.storeEditedPhotos ? 1 : 0) as Int32, forKey: "eph")
        try container.encode((self.storeCapturedMedia ? 1 : 0) as Int32, forKey: "cpm")
    }
    
    public static func ==(lhs: GeneratedMediaStoreSettings, rhs: GeneratedMediaStoreSettings) -> Bool {
        return lhs.storeEditedPhotos == rhs.storeEditedPhotos && lhs.storeCapturedMedia == rhs.storeCapturedMedia
    }
    
    public func withUpdatedStoreEditedPhotos(_ storeEditedPhotos: Bool) -> GeneratedMediaStoreSettings {
        return GeneratedMediaStoreSettings(storeEditedPhotos: storeEditedPhotos, storeCapturedMedia: self.storeCapturedMedia)
    }
}

public func updateGeneratedMediaStoreSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (GeneratedMediaStoreSettings) -> GeneratedMediaStoreSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings, { entry in
            let currentSettings: GeneratedMediaStoreSettings
            if let entry = entry?.get(GeneratedMediaStoreSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = GeneratedMediaStoreSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

import Foundation
import Postbox
import SwiftSignalKit

public struct GeneratedMediaStoreSettings: PreferencesEntry, Equatable {
    public let storeEditedPhotos: Bool
    public let storeCapturedMedia: Bool
    
    public static var defaultSettings: GeneratedMediaStoreSettings {
        return GeneratedMediaStoreSettings(storeEditedPhotos: true, storeCapturedMedia: true)
    }
    
    public init(storeEditedPhotos: Bool, storeCapturedMedia: Bool) {
        self.storeEditedPhotos = storeEditedPhotos
        self.storeCapturedMedia = storeCapturedMedia
    }
    
    public init(decoder: PostboxDecoder) {
        self.storeEditedPhotos = decoder.decodeInt32ForKey("eph", orElse: 0) != 0
        self.storeCapturedMedia = decoder.decodeInt32ForKey("cpm", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.storeEditedPhotos ? 1 : 0, forKey: "eph")
        encoder.encodeInt32(self.storeCapturedMedia ? 1 : 0, forKey: "cpm")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? GeneratedMediaStoreSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: GeneratedMediaStoreSettings, rhs: GeneratedMediaStoreSettings) -> Bool {
        return lhs.storeEditedPhotos == rhs.storeEditedPhotos && lhs.storeCapturedMedia == rhs.storeCapturedMedia
    }
    
    public func withUpdatedStoreEditedPhotos(_ storeEditedPhotos: Bool) -> GeneratedMediaStoreSettings {
        return GeneratedMediaStoreSettings(storeEditedPhotos: storeEditedPhotos, storeCapturedMedia: self.storeCapturedMedia)
    }
}

public func updateGeneratedMediaStoreSettingsInteractively(accountManager: AccountManager, _ f: @escaping (GeneratedMediaStoreSettings) -> GeneratedMediaStoreSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings, { entry in
            let currentSettings: GeneratedMediaStoreSettings
            if let entry = entry as? GeneratedMediaStoreSettings {
                currentSettings = entry
            } else {
                currentSettings = GeneratedMediaStoreSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

import Foundation
import Postbox
import SwiftSignalKit


public func updateCacheStorageSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (CacheStorageSettings) -> CacheStorageSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(SharedDataKeys.cacheStorageSettings, { entry in
            let currentSettings: CacheStorageSettings
            if let entry = entry?.get(CacheStorageSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = CacheStorageSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

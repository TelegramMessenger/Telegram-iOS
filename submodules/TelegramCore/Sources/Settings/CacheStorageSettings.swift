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

public func updateAccountSpecificCacheStorageSettingsInteractively(postbox: Postbox, _ f: @escaping (AccountSpecificCacheStorageSettings) -> AccountSpecificCacheStorageSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.accountSpecificCacheStorageSettings, { entry in
            let currentSettings: AccountSpecificCacheStorageSettings
            if let entry = entry?.get(AccountSpecificCacheStorageSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = AccountSpecificCacheStorageSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

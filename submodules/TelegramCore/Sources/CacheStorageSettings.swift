import Foundation
import Postbox
import SwiftSignalKit

import SyncCore

public func updateCacheStorageSettingsInteractively(accountManager: AccountManager, _ f: @escaping (CacheStorageSettings) -> CacheStorageSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(SharedDataKeys.cacheStorageSettings, { entry in
            let currentSettings: CacheStorageSettings
            if let entry = entry as? CacheStorageSettings {
                currentSettings = entry
            } else {
                currentSettings = CacheStorageSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

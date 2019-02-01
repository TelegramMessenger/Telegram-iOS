import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit

private enum LegacyPreferencesKeyValues: Int32 {
    case cacheStorageSettings = 1
    case localizationSettings = 2
    case proxySettings = 5
    
    var key: ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: self.rawValue)
        return key
    }
}

private enum UpgradedSharedDataKeyValues: Int32 {
    case cacheStorageSettings = 2
    case localizationSettings = 3
    case proxySettings = 4
    
    var key: ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: self.rawValue)
        return key
    }
}

private enum LegacyApplicationSpecificPreferencesKeyValues: Int32 {
    case inAppNotificationSettings = 0
    case presentationPasscodeSettings = 1
    case automaticMediaDownloadSettings = 2
    case generatedMediaStoreSettings = 3
    case voiceCallSettings = 4
    case presentationThemeSettings = 5
    case instantPagePresentationSettings = 6
    case callListSettings = 7
    case experimentalSettings = 8
    case musicPlaybackSettings = 9
    case mediaInputSettings = 10
    case experimentalUISettings = 11
    case contactSynchronizationSettings = 12
    case stickerSettings = 13
    case watchPresetSettings = 14
    case webSearchSettings = 15
    case voipDerivedState = 16
    
    var key: ValueBoxKey {
        return applicationSpecificPreferencesKey(self.rawValue)
    }
}

private enum UpgradedApplicationSpecificSharedDataKeyValues: Int32 {
    case inAppNotificationSettings = 0
    case presentationPasscodeSettings = 1
    case automaticMediaDownloadSettings = 2
    case generatedMediaStoreSettings = 3
    case voiceCallSettings = 4
    case presentationThemeSettings = 5
    case instantPagePresentationSettings = 6
    case callListSettings = 7
    case experimentalSettings = 8
    case musicPlaybackSettings = 9
    case mediaInputSettings = 10
    case experimentalUISettings = 11
    case stickerSettings = 12
    case watchPresetSettings = 13
    case webSearchSettings = 14
    case contactSynchronizationSettings = 15
    
    var key: ValueBoxKey {
        return applicationSpecificSharedDataKey(self.rawValue)
    }
}

private let preferencesKeyMapping: [LegacyPreferencesKeyValues: UpgradedSharedDataKeyValues] = [
    .cacheStorageSettings: .cacheStorageSettings,
    .localizationSettings: .localizationSettings,
    .proxySettings: .proxySettings
]

private let applicationSpecificPreferencesKeyMapping: [LegacyApplicationSpecificPreferencesKeyValues: UpgradedApplicationSpecificSharedDataKeyValues] = [
    .inAppNotificationSettings: .inAppNotificationSettings,
    .presentationPasscodeSettings: .presentationPasscodeSettings,
    .automaticMediaDownloadSettings: .automaticMediaDownloadSettings,
    .generatedMediaStoreSettings: .generatedMediaStoreSettings,
    .voiceCallSettings: .voiceCallSettings,
    .presentationThemeSettings: .presentationThemeSettings,
    .instantPagePresentationSettings: .instantPagePresentationSettings,
    .callListSettings: .callListSettings,
    .experimentalSettings: .experimentalSettings,
    .musicPlaybackSettings: .musicPlaybackSettings,
    .mediaInputSettings: .mediaInputSettings,
    .experimentalUISettings: .experimentalUISettings,
    .stickerSettings: .stickerSettings,
    .watchPresetSettings: .watchPresetSettings,
    .webSearchSettings: .webSearchSettings,
    .contactSynchronizationSettings: .contactSynchronizationSettings
]

public func upgradedAccounts(accountManager: AccountManager, rootPath: String) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> (Int32, AccountRecordId?) in
        return (transaction.getVersion(), transaction.getCurrent()?.0)
    }
    |> mapToSignal { version, currentId -> Signal<Void, NoError> in
        if version == 0 {
            if let currentId = currentId {
                return accountPreferenceEntries(rootPath: rootPath, id: currentId, keys: Set(preferencesKeyMapping.keys.map({ $0.key }) + applicationSpecificPreferencesKeyMapping.keys.map({ $0.key })))
                |> mapToSignal { values -> Signal<Void, NoError> in
                    return accountManager.transaction { transaction -> Void in
                        for (key, value) in values {
                            var upgradedKey: ValueBoxKey?
                            for (k, v) in preferencesKeyMapping {
                                if k.key == key {
                                    upgradedKey = v.key
                                    break
                                }
                            }
                            for (k, v) in applicationSpecificPreferencesKeyMapping {
                                if k.key == key {
                                    upgradedKey = v.key
                                    break
                                }
                            }
                            if let upgradedKey = upgradedKey {
                                transaction.updateSharedData(upgradedKey, { _ in
                                    return value
                                })
                            }
                        }
                        
                        transaction.setVersion(1)
                    }
                }
            } else {
                return accountManager.transaction { transaction -> Void in
                    transaction.setVersion(1)
                }
            }
        } else {
            return .complete()
        }
    }
}

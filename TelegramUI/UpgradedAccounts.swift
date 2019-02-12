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

public func upgradedAccounts(accountManager: AccountManager, rootPath: String) -> Signal<Never, NoError> {
    return accountManager.transaction { transaction -> (Int32, AccountRecordId?) in
        return (transaction.getVersion(), transaction.getCurrent()?.0)
    }
    |> mapToSignal { version, currentId -> Signal<Never, NoError> in
        var signal: Signal<Never, NoError> = .complete()
        if version < 1 {
            if let currentId = currentId {
                let upgradePreferences = accountPreferenceEntries(rootPath: rootPath, id: currentId, keys: Set(preferencesKeyMapping.keys.map({ $0.key }) + applicationSpecificPreferencesKeyMapping.keys.map({ $0.key })))
                |> mapToSignal { path, values -> Signal<Void, NoError> in
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
                        
                        if let value = values[LegacyApplicationSpecificPreferencesKeyValues.presentationThemeSettings.key] as? PresentationThemeSettings {
                            let mediaBox = MediaBox(basePath: path + "/postbox/media")
                            let wallpapers = [value.chatWallpaper] + Array(value.themeSpecificChatWallpapers.values)
                            for wallpaper in wallpapers {
                                switch wallpaper {
                                    case let .file(file):
                                        if let path = mediaBox.completedResourcePath(file.file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                                            accountManager.mediaBox.storeResourceData(file.file.resource.id, data: data)
                                            let _ = accountManager.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 720.0, height: 720.0), mode: .aspectFit), complete: true, fetch: true).start()
                                            if file.isPattern {
                                                if let color = file.settings.color, let intensity = file.settings.intensity {
                                                    let _ = accountManager.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedPatternWallpaperRepresentation(color: color, intensity: intensity), complete: true, fetch: true).start()
                                                }
                                            } else {
                                                if file.settings.blur {
                                                    let _ = accountManager.mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true).start()
                                                }
                                            }
                                        }
                                    case let .image(representations, _):
                                        for representation in representations {
                                            let resource = representation.resource
                                            if let path = mediaBox.completedResourcePath(resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                                                accountManager.mediaBox.storeResourceData(resource.id, data: data)
                                                let _ = mediaBox.cachedResourceRepresentation(resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 720.0, height: 720.0), mode: .aspectFit), complete: true, fetch: true).start()
                                            }
                                        }
                                    default:
                                        break
                                }
                            }
                        }
                        
                        transaction.setVersion(1)
                    }
                }
                |> ignoreValues
                signal = signal |> then(upgradePreferences)
            } else {
                let upgradePreferences = accountManager.transaction { transaction -> Void in
                    transaction.setVersion(1)
                }
                |> ignoreValues
                signal = signal |> then(upgradePreferences)
            }
        }
        if version < 2 {
            if let currentId = currentId {
                let upgradeNotices = accountNoticeEntries(rootPath: rootPath, id: currentId)
                |> mapToSignal { path, values -> Signal<Void, NoError> in
                    return accountManager.transaction { transaction -> Void in
                        for (key, value) in values {
                            transaction.setNotice(NoticeEntryKey(namespace: ValueBoxKey(length: 0), key: key), value)
                        }
                        
                        transaction.setVersion(2)
                    }
                }
                |> ignoreValues
                signal = signal |> then(upgradeNotices)
            } else {
                let upgradeNotices = accountManager.transaction { transaction -> Void in
                    transaction.setVersion(2)
                }
                |> ignoreValues
                signal = signal |> then(upgradeNotices)
            }
            
            let upgradeSortOrder = accountManager.transaction { transaction -> Void in
                var index: Int32 = 0
                for record in transaction.getRecords() {
                    transaction.updateRecord(record.id, { _ in
                        return AccountRecord(id: record.id, attributes: record.attributes + [AccountSortOrderAttribute(order: index)], temporarySessionId: record.temporarySessionId)
                    })
                    index += 1
                }
            }
            |> ignoreValues
            signal = signal |> then(upgradeSortOrder)
        }
        return signal
    }
}

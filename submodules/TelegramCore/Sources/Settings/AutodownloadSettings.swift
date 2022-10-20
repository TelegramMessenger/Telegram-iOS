import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


public func updateAutodownloadSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (AutodownloadSettings) -> AutodownloadSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(SharedDataKeys.autodownloadSettings, { entry in
            let currentSettings: AutodownloadSettings
            if let entry = entry?.get(AutodownloadSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = AutodownloadSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

extension AutodownloadPresetSettings {
    init(apiAutodownloadSettings: Api.AutoDownloadSettings) {
        switch apiAutodownloadSettings {
        case let .autoDownloadSettings(flags, photoSizeMax, videoSizeMax, fileSizeMax, videoUploadMaxbitrate):
            self.init(disabled: (flags & (1 << 0)) != 0, photoSizeMax: Int64(photoSizeMax), videoSizeMax: videoSizeMax, fileSizeMax: fileSizeMax, preloadLargeVideo: (flags & (1 << 1)) != 0, lessDataForPhoneCalls: (flags & (1 << 3)) != 0, videoUploadMaxbitrate: videoUploadMaxbitrate)
        }
    }
}

extension AutodownloadSettings {
    init(apiAutodownloadSettings: Api.account.AutoDownloadSettings) {
        switch apiAutodownloadSettings {
            case let .autoDownloadSettings(low, medium, high):
                self.init(lowPreset: AutodownloadPresetSettings(apiAutodownloadSettings: low), mediumPreset: AutodownloadPresetSettings(apiAutodownloadSettings: medium), highPreset: AutodownloadPresetSettings(apiAutodownloadSettings: high))
        }
    }
}

func apiAutodownloadPresetSettings(_ autodownloadPresetSettings: AutodownloadPresetSettings) -> Api.AutoDownloadSettings {
    var flags: Int32 = 0
    if autodownloadPresetSettings.disabled {
        flags |= (1 << 0)
    }
    if autodownloadPresetSettings.preloadLargeVideo {
        flags |= (1 << 1)
    }
    if autodownloadPresetSettings.lessDataForPhoneCalls {
        flags |= (1 << 3)
    }
    return .autoDownloadSettings(flags: flags, photoSizeMax: Int32(autodownloadPresetSettings.photoSizeMax), videoSizeMax: autodownloadPresetSettings.videoSizeMax, fileSizeMax: autodownloadPresetSettings.fileSizeMax, videoUploadMaxbitrate: autodownloadPresetSettings.videoUploadMaxbitrate)
}


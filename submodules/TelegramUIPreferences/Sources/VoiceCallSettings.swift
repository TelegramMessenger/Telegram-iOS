import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

public func effectiveDataSaving(for settings: VoiceCallSettings?, autodownloadSettings: AutodownloadSettings) -> VoiceCallDataSaving {
    if let settings = settings {
        if case .default = settings.dataSaving {
            switch (autodownloadSettings.mediumPreset.lessDataForPhoneCalls, autodownloadSettings.highPreset.lessDataForPhoneCalls) {
                case (true, true):
                    return .always
                case (true, false):
                    return .cellular
                default:
                    return .never
            }
        } else {
            return settings.dataSaving
        }
    } else {
        return .never
    }
}

public enum VoiceCallDataSaving: Int32 {
    case never
    case cellular
    case always
    case `default`
}

public struct VoiceCallSettings: PreferencesEntry, Equatable {
    public var dataSaving: VoiceCallDataSaving
    public var enableSystemIntegration: Bool
    
    public static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(dataSaving: .default, enableSystemIntegration: true)
    }
    
    public init(dataSaving: VoiceCallDataSaving, enableSystemIntegration: Bool) {
        self.dataSaving = dataSaving
        self.enableSystemIntegration = enableSystemIntegration
    }
    
    public init(decoder: PostboxDecoder) {
        self.dataSaving = VoiceCallDataSaving(rawValue: decoder.decodeInt32ForKey("ds", orElse: 0))!
        self.enableSystemIntegration = decoder.decodeInt32ForKey("enableSystemIntegration", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.dataSaving.rawValue, forKey: "ds")
        encoder.encodeInt32(self.enableSystemIntegration ? 1 : 0, forKey: "enableSystemIntegration")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? VoiceCallSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: VoiceCallSettings, rhs: VoiceCallSettings) -> Bool {
        if lhs.dataSaving != rhs.dataSaving {
            return false
        }
        if lhs.enableSystemIntegration != rhs.enableSystemIntegration {
            return false
        }
        return true
    }
}

public func updateVoiceCallSettingsSettingsInteractively(accountManager: AccountManager, _ f: @escaping (VoiceCallSettings) -> VoiceCallSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.voiceCallSettings, { entry in
            let currentSettings: VoiceCallSettings
            if let entry = entry as? VoiceCallSettings {
                currentSettings = entry
            } else {
                currentSettings = VoiceCallSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

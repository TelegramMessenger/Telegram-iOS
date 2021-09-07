import Foundation
import Postbox
import TelegramCore
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

public struct VoiceCallSettings: Codable, Equatable {
    public var dataSaving: VoiceCallDataSaving
    public var enableSystemIntegration: Bool
    
    public static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(dataSaving: .default, enableSystemIntegration: true)
    }
    
    public init(dataSaving: VoiceCallDataSaving, enableSystemIntegration: Bool) {
        self.dataSaving = dataSaving
        self.enableSystemIntegration = enableSystemIntegration
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.dataSaving = VoiceCallDataSaving(rawValue: try container.decode(Int32.self, forKey: "ds")) ?? .default
        self.enableSystemIntegration = (try container.decode(Int32.self, forKey: "enableSystemIntegration")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.dataSaving.rawValue, forKey: "ds")
        try container.encode((self.enableSystemIntegration ? 1 : 0) as Int32, forKey: "enableSystemIntegration")
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

public func updateVoiceCallSettingsSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (VoiceCallSettings) -> VoiceCallSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.voiceCallSettings, { entry in
            let currentSettings: VoiceCallSettings
            if let entry = entry?.get(VoiceCallSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = VoiceCallSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

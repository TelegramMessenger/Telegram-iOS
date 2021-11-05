import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct WatchPresetSettings: Codable, Equatable {
    public var customPresets: [String : String]
    
    public static var defaultSettings: WatchPresetSettings {
        return WatchPresetSettings(presets: [:])
    }

    public init(presets: [String : String]) {
        self.customPresets = presets
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        let keys = try container.decode([String].self, forKey: "presetKeys")
        let values = try container.decode([String].self, forKey: "presetValues")
        if keys.count == values.count {
            var presets: [String : String] = [:]
            for i in 0 ..< keys.count {
                presets[keys[i]] = values[i]
            }
            self.customPresets = presets
        } else {
            self.customPresets = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        let keys = self.customPresets.keys.sorted()
        let values = keys.reduce([String]()) { (values, index) in
            var values = values
            if let value = self.customPresets[index] {
                values.append(value)
            }
            return values
        }
        try container.encode(keys, forKey: "presetKeys")
        try container.encode(values, forKey: "presetValues")
    }
    
    public static func ==(lhs: WatchPresetSettings, rhs: WatchPresetSettings) -> Bool {
        return lhs.customPresets == rhs.customPresets
    }
}

public func updateWatchPresetSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (WatchPresetSettings) -> WatchPresetSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.watchPresetSettings, { entry in
            let currentSettings: WatchPresetSettings
            if let entry = entry?.get(WatchPresetSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = WatchPresetSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

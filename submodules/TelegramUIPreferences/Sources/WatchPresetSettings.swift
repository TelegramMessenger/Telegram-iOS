import Foundation
import Postbox
import SwiftSignalKit

public struct WatchPresetSettings: PreferencesEntry, Equatable {
    public var customPresets: [String : String]
    
    public static var defaultSettings: WatchPresetSettings {
        return WatchPresetSettings(presets: [:])
    }

    public init(presets: [String : String]) {
        self.customPresets = presets
    }
    
    public init(decoder: PostboxDecoder) {
        let keys = decoder.decodeStringArrayForKey("presetKeys")
        let values = decoder.decodeStringArrayForKey("presetValues")
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
    
    public func encode(_ encoder: PostboxEncoder) {
        let keys = self.customPresets.keys.sorted()
        let values = keys.reduce([String]()) { (values, index) in
            var values = values
            if let value = self.customPresets[index] {
                values.append(value)
            }
            return values
        }
        encoder.encodeStringArray(keys, forKey: "presetKeys")
        encoder.encodeStringArray(values, forKey: "presetValues")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? WatchPresetSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: WatchPresetSettings, rhs: WatchPresetSettings) -> Bool {
        return lhs.customPresets == rhs.customPresets
    }
}

public func updateWatchPresetSettingsInteractively(accountManager: AccountManager, _ f: @escaping (WatchPresetSettings) -> WatchPresetSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.watchPresetSettings, { entry in
            let currentSettings: WatchPresetSettings
            if let entry = entry as? WatchPresetSettings {
                currentSettings = entry
            } else {
                currentSettings = WatchPresetSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

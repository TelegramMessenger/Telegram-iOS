import Foundation
import Postbox
import SwiftSignalKit

public enum VoiceCallDataSaving: Int32 {
    case never
    case cellular
    case always
}

public struct VoiceCallSettings: PreferencesEntry, Equatable {
    public let dataSaving: VoiceCallDataSaving
    
    public static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(dataSaving: .never)
    }
    
    init(dataSaving: VoiceCallDataSaving) {
        self.dataSaving = dataSaving
    }
    
    public init(decoder: Decoder) {
        self.dataSaving = VoiceCallDataSaving(rawValue: (decoder.decodeInt32ForKey("ds") as Int32))!
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.dataSaving.rawValue, forKey: "ds")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? VoiceCallSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: VoiceCallSettings, rhs: VoiceCallSettings) -> Bool {
        return lhs.dataSaving == rhs.dataSaving
    }
    
    func withUpdatedDataSaving(_ dataSaving: VoiceCallDataSaving) -> VoiceCallSettings {
        return VoiceCallSettings(dataSaving: dataSaving)
    }
}

func updateVoiceCallSettingsSettingsInteractively(postbox: Postbox, _ f: @escaping (VoiceCallSettings) -> VoiceCallSettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.voiceCallSettings, { entry in
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

import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum VoiceCallDataSaving: Int32 {
    case never
    case cellular
    case always
}

public struct VoiceCallSettings: PreferencesEntry, Equatable {
    public var dataSaving: VoiceCallDataSaving
    public var p2pMode: VoiceCallP2PMode?
    public var enableSystemIntegration: Bool
    
    public static var defaultSettings: VoiceCallSettings {
        return VoiceCallSettings(dataSaving: .never, p2pMode: nil, enableSystemIntegration: true)
    }
    
    init(dataSaving: VoiceCallDataSaving, p2pMode: VoiceCallP2PMode?, enableSystemIntegration: Bool) {
        self.dataSaving = dataSaving
        self.p2pMode = p2pMode
        self.enableSystemIntegration = enableSystemIntegration
    }
    
    public init(decoder: PostboxDecoder) {
        self.dataSaving = VoiceCallDataSaving(rawValue: decoder.decodeInt32ForKey("ds", orElse: 0))!
        if let value = decoder.decodeOptionalInt32ForKey("p2pMode") {
            self.p2pMode = VoiceCallP2PMode(rawValue: value) ?? .contacts
        } else {
            self.p2pMode = nil
        }
        self.enableSystemIntegration = decoder.decodeInt32ForKey("enableSystemIntegration", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.dataSaving.rawValue, forKey: "ds")
        if let p2pMode = self.p2pMode {
            encoder.encodeInt32(p2pMode.rawValue, forKey: "p2pMode")
        } else {
            encoder.encodeNil(forKey: "p2pMode")
        }
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
        if lhs.p2pMode != rhs.p2pMode {
            return false
        }
        if lhs.enableSystemIntegration != rhs.enableSystemIntegration {
            return false
        }
        return true
    }
}

func updateVoiceCallSettingsSettingsInteractively(postbox: Postbox, _ f: @escaping (VoiceCallSettings) -> VoiceCallSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.voiceCallSettings, { entry in
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

import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum MusicPlaybackSettingsOrder: Int32 {
    case regular = 0
    case reversed = 1
    case random = 2
}

public enum MusicPlaybackSettingsLooping: Int32 {
    case none = 0
    case item = 1
    case all = 2
}

public enum AudioPlaybackRate: Equatable {
    case x0_5
    case x1
    case x1_5
    case x2
    case x4
    case x8
    case x16
    case custom(Int32)
    
    public var isPreset: Bool {
        switch self {
        case .x1, .x1_5, .x2:
            return true
        default:
            return false
        }
    }
    
    public var doubleValue: Double {
        return Double(self.rawValue) / 1000.0
    }
    
    public var rawValue: Int32 {
        switch self {
        case .x0_5:
            return 500
        case .x1:
            return 1000
        case .x1_5:
            return 1500
        case .x2:
            return 2000
        case .x4:
            return 4000
        case .x8:
            return 8000
        case .x16:
            return 16000
        case let .custom(value):
            return value
        }
    }

    public init(_ value: Double) {
        self.init(rawValue: Int32(value * 1000.0))
    }
    
    public init(rawValue: Int32) {
        switch rawValue {
        case 500:
            self = .x0_5
        case 1000:
            self = .x1
        case 1500:
            self = .x1_5
        case 2000:
            self = .x2
        case 4000:
            self = .x4
        case 8000:
            self = .x8
        case 16000:
            self = .x16
        default:
            self = .custom(rawValue)
        }
    }
    
    public var stringValue: String {
        var stringValue = String(format: "%.1fx", self.doubleValue)
        if stringValue.hasSuffix(".0x") {
            stringValue = stringValue.replacingOccurrences(of: ".0x", with: "x")
        }
        return stringValue
    }
}

public struct MusicPlaybackSettings: Codable, Equatable {
    public var order: MusicPlaybackSettingsOrder
    public var looping: MusicPlaybackSettingsLooping
    public var voicePlaybackRate: AudioPlaybackRate
    
    public static var defaultSettings: MusicPlaybackSettings {
        return MusicPlaybackSettings(order: .regular, looping: .none, voicePlaybackRate: .x1)
    }
    
    public init(order: MusicPlaybackSettingsOrder, looping: MusicPlaybackSettingsLooping, voicePlaybackRate: AudioPlaybackRate) {
        self.order = order
        self.looping = looping
        self.voicePlaybackRate = voicePlaybackRate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.order = MusicPlaybackSettingsOrder(rawValue: try container.decode(Int32.self, forKey: "order")) ?? .regular
        self.looping = MusicPlaybackSettingsLooping(rawValue: try container.decode(Int32.self, forKey: "looping")) ?? .none
        self.voicePlaybackRate = AudioPlaybackRate(rawValue: try container.decodeIfPresent(Int32.self, forKey: "voicePlaybackRate") ?? AudioPlaybackRate.x1.rawValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.order.rawValue, forKey: "order")
        try container.encode(self.looping.rawValue, forKey: "looping")
        try container.encode(self.voicePlaybackRate.rawValue, forKey: "voicePlaybackRate")
    }
    
    public static func ==(lhs: MusicPlaybackSettings, rhs: MusicPlaybackSettings) -> Bool {
        return lhs.order == rhs.order && lhs.looping == rhs.looping && lhs.voicePlaybackRate == rhs.voicePlaybackRate
    }
    
    public func withUpdatedOrder(_ order: MusicPlaybackSettingsOrder) -> MusicPlaybackSettings {
        return MusicPlaybackSettings(order: order, looping: self.looping, voicePlaybackRate: self.voicePlaybackRate)
    }
    
    public func withUpdatedLooping(_ looping: MusicPlaybackSettingsLooping) -> MusicPlaybackSettings {
        return MusicPlaybackSettings(order: self.order, looping: looping, voicePlaybackRate: self.voicePlaybackRate)
    }
    
    public func withUpdatedVoicePlaybackRate(_ voicePlaybackRate: AudioPlaybackRate) -> MusicPlaybackSettings {
        return MusicPlaybackSettings(order: self.order, looping: self.looping, voicePlaybackRate: voicePlaybackRate)
    }
}

public func updateMusicPlaybackSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (MusicPlaybackSettings) -> MusicPlaybackSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings, { entry in
            let currentSettings: MusicPlaybackSettings
            if let entry = entry?.get(MusicPlaybackSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = MusicPlaybackSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

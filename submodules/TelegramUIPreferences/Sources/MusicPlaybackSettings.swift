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

public enum AudioPlaybackRate: Int32 {
    case x0_5 = 500
    case x1 = 1000
    case x1_5 = 1500
    case x2 = 2000
    case x4 = 4000
    case x8 = 8000
    case x16 = 16000
    
    public var doubleValue: Double {
        return Double(self.rawValue) / 1000.0
    }

    public init(_ value: Double) {
        if let resolved = AudioPlaybackRate(rawValue: Int32(value * 1000.0)) {
            self = resolved
        } else {
            self = .x1
        }
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
        self.voicePlaybackRate = AudioPlaybackRate(rawValue: try container.decodeIfPresent(Int32.self, forKey: "voicePlaybackRate") ?? AudioPlaybackRate.x1.rawValue) ?? .x1
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

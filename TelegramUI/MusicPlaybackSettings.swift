import Foundation
import Postbox
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

public struct MusicPlaybackSettings: PreferencesEntry, Equatable {
    public let order: MusicPlaybackSettingsOrder
    public let looping: MusicPlaybackSettingsLooping
    
    public static var defaultSettings: MusicPlaybackSettings {
        return MusicPlaybackSettings(order: .regular, looping: .none)
    }
    
    public init(order: MusicPlaybackSettingsOrder, looping: MusicPlaybackSettingsLooping) {
        self.order = order
        self.looping = looping
    }
    
    public init(decoder: PostboxDecoder) {
        self.order = MusicPlaybackSettingsOrder(rawValue: decoder.decodeInt32ForKey("order", orElse: 0)) ?? .regular
        self.looping = MusicPlaybackSettingsLooping(rawValue: decoder.decodeInt32ForKey("looping", orElse: 0)) ?? .none
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.order.rawValue, forKey: "order")
        encoder.encodeInt32(self.looping.rawValue, forKey: "looping")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? MusicPlaybackSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: MusicPlaybackSettings, rhs: MusicPlaybackSettings) -> Bool {
        return lhs.order == rhs.order && lhs.looping == rhs.looping
    }
    
    func withUpdatedOrder(_ order: MusicPlaybackSettingsOrder) -> MusicPlaybackSettings {
        return MusicPlaybackSettings(order: order, looping: self.looping)
    }
    
    func withUpdatedLooping(_ looping: MusicPlaybackSettingsLooping) -> MusicPlaybackSettings {
        return MusicPlaybackSettings(order: self.order, looping: looping)
    }
}

func updateMusicPlaybackSettingsInteractively(postbox: Postbox, _ f: @escaping (MusicPlaybackSettings) -> MusicPlaybackSettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.musicPlaybackSettings, { entry in
            let currentSettings: MusicPlaybackSettings
            if let entry = entry as? MusicPlaybackSettings {
                currentSettings = entry
            } else {
                currentSettings = MusicPlaybackSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}

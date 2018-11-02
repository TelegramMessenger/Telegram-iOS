import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct MessageNotificationSettings: PostboxCoding, Equatable {
    public let enabled: Bool
    public let displayPreviews: Bool
    public let sound: PeerMessageSound
    
    public static var defaultSettings: MessageNotificationSettings {
        return MessageNotificationSettings(enabled: true, displayPreviews: true, sound: .bundledModern(id: 0))
    }
    
    public init(enabled: Bool, displayPreviews: Bool, sound: PeerMessageSound) {
        self.enabled = enabled
        self.displayPreviews = displayPreviews
        self.sound = sound
    }
    
    public init(decoder: PostboxDecoder) {
        self.enabled = decoder.decodeInt32ForKey("e", orElse: 0) != 0
        self.displayPreviews = decoder.decodeInt32ForKey("p", orElse: 0) != 0
        self.sound = PeerMessageSound.decodeInline(decoder)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enabled ? 1 : 0, forKey: "e")
        encoder.encodeInt32(self.displayPreviews ? 1 : 0, forKey: "p")
        self.sound.encodeInline(encoder)
    }
    
    public func withUpdatedEnabled(_ enabled: Bool) -> MessageNotificationSettings {
        return MessageNotificationSettings(enabled: enabled, displayPreviews: self.displayPreviews, sound: self.sound)
    }
    
    public func withUpdatedDisplayPreviews(_ displayPreviews: Bool) -> MessageNotificationSettings {
        return MessageNotificationSettings(enabled: self.enabled, displayPreviews: displayPreviews, sound: self.sound)
    }
    
    public func withUpdatedSound(_ sound: PeerMessageSound) -> MessageNotificationSettings {
        return MessageNotificationSettings(enabled: self.enabled, displayPreviews: self.displayPreviews, sound: sound)
    }
    
    public static func ==(lhs: MessageNotificationSettings, rhs: MessageNotificationSettings) -> Bool {
        if lhs.enabled != rhs.enabled {
            return false
        }
        if lhs.displayPreviews != rhs.displayPreviews {
            return false
        }
        if lhs.sound != rhs.sound {
            return false
        }
        return true
    }
}

public struct GlobalNotificationSettingsSet: PostboxCoding, Equatable {
    public let privateChats: MessageNotificationSettings
    public let groupChats: MessageNotificationSettings
    public let channels: MessageNotificationSettings
    
    public static var defaultSettings: GlobalNotificationSettingsSet {
        return GlobalNotificationSettingsSet(privateChats: MessageNotificationSettings.defaultSettings, groupChats: .defaultSettings, channels: .defaultSettings)
    }
    
    public init(privateChats: MessageNotificationSettings, groupChats: MessageNotificationSettings, channels: MessageNotificationSettings) {
        self.privateChats = privateChats
        self.groupChats = groupChats
        self.channels = channels
    }
    
    public init(decoder: PostboxDecoder) {
        self.privateChats = decoder.decodeObjectForKey("p", decoder: { MessageNotificationSettings(decoder: $0) }) as! MessageNotificationSettings
        self.groupChats = decoder.decodeObjectForKey("g", decoder: { MessageNotificationSettings(decoder: $0) }) as! MessageNotificationSettings
        self.channels = (decoder.decodeObjectForKey("c", decoder: { MessageNotificationSettings(decoder: $0) }) as? MessageNotificationSettings) ?? MessageNotificationSettings.defaultSettings
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.privateChats, forKey: "p")
        encoder.encodeObject(self.groupChats, forKey: "g")
        encoder.encodeObject(self.channels, forKey: "c")
    }
    
    public func withUpdatedPrivateChats(_ f: (MessageNotificationSettings) -> MessageNotificationSettings) -> GlobalNotificationSettingsSet {
        return GlobalNotificationSettingsSet(privateChats: f(self.privateChats), groupChats: self.groupChats, channels: self.channels)
    }
    
    public func withUpdatedGroupChats(_ f: (MessageNotificationSettings) -> MessageNotificationSettings) -> GlobalNotificationSettingsSet {
        return GlobalNotificationSettingsSet(privateChats: self.privateChats, groupChats: f(self.groupChats), channels: self.channels)
    }
    
    public func withUpdatedChannels(_ f: (MessageNotificationSettings) -> MessageNotificationSettings) -> GlobalNotificationSettingsSet {
        return GlobalNotificationSettingsSet(privateChats: self.privateChats, groupChats: self.groupChats, channels: f(self.channels))
    }
    
    public static func ==(lhs: GlobalNotificationSettingsSet, rhs: GlobalNotificationSettingsSet) -> Bool {
        if lhs.privateChats != rhs.privateChats {
            return false
        }
        if lhs.groupChats != rhs.groupChats {
            return false
        }
        if lhs.channels != rhs.channels {
            return false
        }
        return true
    }
}

public struct GlobalNotificationSettings: PreferencesEntry, Equatable {
    let toBeSynchronized: GlobalNotificationSettingsSet?
    let remote: GlobalNotificationSettingsSet
    
    public static var defaultSettings: GlobalNotificationSettings = GlobalNotificationSettings(toBeSynchronized: nil, remote: GlobalNotificationSettingsSet.defaultSettings)
    
    public var effective: GlobalNotificationSettingsSet {
        if let toBeSynchronized = self.toBeSynchronized {
            return toBeSynchronized
        } else {
            return self.remote
        }
    }
    
    init(toBeSynchronized: GlobalNotificationSettingsSet?, remote: GlobalNotificationSettingsSet) {
        self.toBeSynchronized = toBeSynchronized
        self.remote = remote
    }
    
    public init(decoder: PostboxDecoder) {
        self.toBeSynchronized = decoder.decodeObjectForKey("s", decoder: { GlobalNotificationSettingsSet(decoder: $0) }) as? GlobalNotificationSettingsSet
        self.remote = decoder.decodeObjectForKey("r", decoder: { GlobalNotificationSettingsSet(decoder: $0) }) as! GlobalNotificationSettingsSet
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let toBeSynchronized = self.toBeSynchronized {
            encoder.encodeObject(toBeSynchronized, forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
        encoder.encodeObject(self.remote, forKey: "r")
    }
    
    public static func ==(lhs: GlobalNotificationSettings, rhs: GlobalNotificationSettings) -> Bool {
        if lhs.toBeSynchronized != rhs.toBeSynchronized {
            return false
        }
        if lhs.remote != rhs.remote {
            return false
        }
        return true
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? GlobalNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
}

extension MessageNotificationSettings {
    init(apiSettings: Api.PeerNotifySettings) {
        switch apiSettings {
            case .peerNotifySettingsEmpty:
                self = .defaultSettings
            case let .peerNotifySettings(_, showPreviews, _, muteUntil, sound):
                let displayPreviews: Bool
                if let showPreviews = showPreviews, case .boolFalse = showPreviews {
                    displayPreviews = false
                } else {
                    displayPreviews = true
                }
                self = MessageNotificationSettings(enabled: muteUntil == 0, displayPreviews: displayPreviews, sound: PeerMessageSound(apiSound: sound ?? "2"))
        }
    }
}

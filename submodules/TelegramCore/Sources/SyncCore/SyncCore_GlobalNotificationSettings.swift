import Postbox

public struct MessageNotificationSettings: Codable {
    public var enabled: Bool
    public var displayPreviews: Bool
    public var sound: PeerMessageSound
    
    public static var defaultSettings: MessageNotificationSettings {
        return MessageNotificationSettings(enabled: true, displayPreviews: true, sound: .bundledModern(id: 0))
    }
    
    public init(enabled: Bool, displayPreviews: Bool, sound: PeerMessageSound) {
        self.enabled = enabled
        self.displayPreviews = displayPreviews
        self.sound = sound
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.enabled = ((try? container.decode(Int32.self, forKey: "e")) ?? 0) != 0
        self.displayPreviews = ((try? container.decode(Int32.self, forKey: "p")) ?? 0) != 0

        self.sound = PeerMessageSound.decodeInline(container)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enabled ? 1 : 0, forKey: "e")
        encoder.encodeInt32(self.displayPreviews ? 1 : 0, forKey: "p")
        self.sound.encodeInline(encoder)
    }
}

public struct GlobalNotificationSettingsSet: Codable {
    public var privateChats: MessageNotificationSettings
    public var groupChats: MessageNotificationSettings
    public var channels: MessageNotificationSettings
    public var contactsJoined: Bool
    
    public static var defaultSettings: GlobalNotificationSettingsSet {
        return GlobalNotificationSettingsSet(privateChats: MessageNotificationSettings.defaultSettings, groupChats: .defaultSettings, channels: .defaultSettings, contactsJoined: true)
    }
    
    public init(privateChats: MessageNotificationSettings, groupChats: MessageNotificationSettings, channels: MessageNotificationSettings, contactsJoined: Bool) {
        self.privateChats = privateChats
        self.groupChats = groupChats
        self.channels = channels
        self.contactsJoined = contactsJoined
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.privateChats = decoder.decodeObjectForKey("p", decoder: { MessageNotificationSettings(decoder: $0) }) as! MessageNotificationSettings
        self.groupChats = decoder.decodeObjectForKey("g", decoder: { MessageNotificationSettings(decoder: $0) }) as! MessageNotificationSettings
        self.channels = (decoder.decodeObjectForKey("c", decoder: { MessageNotificationSettings(decoder: $0) }) as? MessageNotificationSettings) ?? MessageNotificationSettings.defaultSettings
        self.contactsJoined = decoder.decodeInt32ForKey("contactsJoined", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.privateChats, forKey: "p")
        encoder.encodeObject(self.groupChats, forKey: "g")
        encoder.encodeObject(self.channels, forKey: "c")
        encoder.encodeInt32(self.contactsJoined ? 1 : 0, forKey: "contactsJoined")
    }
}

public struct GlobalNotificationSettings: Codable {
    public var toBeSynchronized: GlobalNotificationSettingsSet?
    public var remote: GlobalNotificationSettingsSet
    
    public static var defaultSettings: GlobalNotificationSettings = GlobalNotificationSettings(toBeSynchronized: nil, remote: GlobalNotificationSettingsSet.defaultSettings)
    
    public var effective: GlobalNotificationSettingsSet {
        if let toBeSynchronized = self.toBeSynchronized {
            return toBeSynchronized
        } else {
            return self.remote
        }
    }

    public var postboxAccessor: PostboxGlobalNotificationSettings {
        return PostboxGlobalNotificationSettings(
            defaultIncludePeer: { peer in
                return self.defaultIncludePeer(peer: peer)
            }
        )
    }
    
    private func defaultIncludePeer(peer: Peer) -> Bool {
        let settings = self.effective
        if peer is TelegramUser || peer is TelegramSecretChat {
            return settings.privateChats.enabled
        } else if peer is TelegramGroup {
            return settings.groupChats.enabled
        } else if let channel = peer as? TelegramChannel {
            switch channel.info {
            case .group:
                return settings.groupChats.enabled
            case .broadcast:
                return settings.channels.enabled
            }
        } else {
            return false
        }
    }
    
    /*public func isEqualInDefaultPeerInclusion(other: PostboxGlobalNotificationSettings) -> Bool {
        guard let other = other as? GlobalNotificationSettings else {
            return false
        }
        let settings = self.effective
        let otherSettings = other.effective
        
        if settings.privateChats.enabled != otherSettings.privateChats.enabled {
            return false
        }
        if settings.groupChats.enabled != otherSettings.groupChats.enabled {
            return false
        }
        if settings.channels.enabled != otherSettings.channels.enabled {
            return false
        }
        
        return true
    }*/
    
    public init(toBeSynchronized: GlobalNotificationSettingsSet?, remote: GlobalNotificationSettingsSet) {
        self.toBeSynchronized = toBeSynchronized
        self.remote = remote
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.toBeSynchronized = decoder.decodeObjectForKey("s", decoder: { GlobalNotificationSettingsSet(decoder: $0) }) as? GlobalNotificationSettingsSet
        self.remote = decoder.decodeObjectForKey("r", decoder: { GlobalNotificationSettingsSet(decoder: $0) }) as! GlobalNotificationSettingsSet
    }
    
    public func encode(to encoder: Encoder) throws {
        if let toBeSynchronized = self.toBeSynchronized {
            encoder.encodeObject(toBeSynchronized, forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
        encoder.encodeObject(self.remote, forKey: "r")
    }
}

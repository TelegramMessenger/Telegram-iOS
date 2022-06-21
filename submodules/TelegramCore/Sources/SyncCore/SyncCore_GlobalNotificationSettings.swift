import Postbox

public struct MessageNotificationSettings: Codable, Equatable {
    public var enabled: Bool
    public var displayPreviews: Bool
    public var sound: PeerMessageSound
    
    public static var defaultSettings: MessageNotificationSettings {
        return MessageNotificationSettings(enabled: true, displayPreviews: true, sound: defaultCloudPeerNotificationSound)
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

        self.sound = try PeerMessageSound.decodeInline(container)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.enabled ? 1 : 0) as Int32, forKey: "e")
        try container.encode((self.displayPreviews ? 1 : 0) as Int32, forKey: "p")
        try self.sound.encodeInline(&container)
    }
}

public struct GlobalNotificationSettingsSet: Codable, Equatable {
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

        self.privateChats = try container.decode(MessageNotificationSettings.self, forKey: "p")
        self.groupChats = try container.decode(MessageNotificationSettings.self, forKey: "g")
        self.channels = try container.decode(MessageNotificationSettings.self, forKey: "c")

        self.contactsJoined = (try container.decode(Int32.self, forKey: "contactsJoined")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.privateChats, forKey: "p")
        try container.encode(self.groupChats, forKey: "g")
        try container.encode(self.channels, forKey: "c")
        try container.encode((self.contactsJoined ? 1 : 0) as Int32, forKey: "contactsJoined")
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
    
    func defaultIncludePeer(peer: Peer) -> Bool {
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

        self.toBeSynchronized = try container.decodeIfPresent(GlobalNotificationSettingsSet.self, forKey: "s")
        self.remote = try container.decode(GlobalNotificationSettingsSet.self, forKey: "r")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.toBeSynchronized, forKey: "s")
        try container.encode(self.remote, forKey: "r")
    }
}

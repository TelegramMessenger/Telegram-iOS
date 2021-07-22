import Foundation
import Postbox

public final class TelegramSecretChat: Peer, Equatable {
    public let id: PeerId
    public let regularPeerId: PeerId
    public let accessHash: Int64
    public let creationDate: Int32
    public let role: SecretChatRole
    public let embeddedState: SecretChatEmbeddedPeerState
    public let messageAutoremoveTimeout: Int32?
    
    public var indexName: PeerIndexNameRepresentation {
        return .title(title: "", addressName: nil)
    }
    
    public let associatedPeerId: PeerId?
    public let notificationSettingsPeerId: PeerId?
    
    public init(id: PeerId, creationDate: Int32, regularPeerId: PeerId, accessHash: Int64, role: SecretChatRole, embeddedState: SecretChatEmbeddedPeerState, messageAutoremoveTimeout: Int32?) {
        self.id = id
        self.regularPeerId = regularPeerId
        self.accessHash = accessHash
        self.creationDate = creationDate
        self.role = role
        self.embeddedState = embeddedState
        self.associatedPeerId = regularPeerId
        self.notificationSettingsPeerId = regularPeerId
        self.messageAutoremoveTimeout = messageAutoremoveTimeout
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i", orElse: 0))
        self.regularPeerId = PeerId(decoder.decodeInt64ForKey("r", orElse: 0))
        self.notificationSettingsPeerId = self.regularPeerId
        self.accessHash = decoder.decodeInt64ForKey("h", orElse: 0)
        self.creationDate = decoder.decodeInt32ForKey("d", orElse: 0)
        self.role = SecretChatRole(rawValue: decoder.decodeInt32ForKey("o", orElse: 0))!
        self.embeddedState = SecretChatEmbeddedPeerState(rawValue: decoder.decodeInt32ForKey("s", orElse: 0))!
        self.associatedPeerId = self.regularPeerId
        self.messageAutoremoveTimeout = decoder.decodeOptionalInt32ForKey("at")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id.toInt64(), forKey: "i")
        encoder.encodeInt64(self.regularPeerId.toInt64(), forKey: "r")
        encoder.encodeInt64(self.accessHash, forKey: "h")
        encoder.encodeInt32(self.creationDate, forKey: "d")
        encoder.encodeInt32(self.role.rawValue, forKey: "o")
        encoder.encodeInt32(self.embeddedState.rawValue, forKey: "s")
        if let messageAutoremoveTimeout = self.messageAutoremoveTimeout {
            encoder.encodeInt32(messageAutoremoveTimeout, forKey: "at")
        } else {
            encoder.encodeNil(forKey: "at")
        }
    }
    
    public func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramSecretChat {
            return self == other
        } else {
            return false
        }
    }

    public static func ==(lhs: TelegramSecretChat, rhs: TelegramSecretChat) -> Bool {
        return lhs.id == rhs.id && lhs.regularPeerId == rhs.regularPeerId && lhs.accessHash == rhs.accessHash && lhs.embeddedState == rhs.embeddedState && lhs.messageAutoremoveTimeout == rhs.messageAutoremoveTimeout && lhs.creationDate == rhs.creationDate && lhs.role == rhs.role
    }
    
    public func withUpdatedEmbeddedState(_ embeddedState: SecretChatEmbeddedPeerState) -> TelegramSecretChat {
        return TelegramSecretChat(id: self.id, creationDate: self.creationDate, regularPeerId: self.regularPeerId, accessHash: self.accessHash, role: self.role, embeddedState: embeddedState, messageAutoremoveTimeout: self.messageAutoremoveTimeout)
    }
    
    public func withUpdatedMessageAutoremoveTimeout(_ messageAutoremoveTimeout: Int32?) -> TelegramSecretChat {
        return TelegramSecretChat(id: self.id, creationDate: self.creationDate, regularPeerId: self.regularPeerId, accessHash: self.accessHash, role: self.role, embeddedState: self.embeddedState, messageAutoremoveTimeout: messageAutoremoveTimeout)
    }
}

public final class CachedSecretChatData: CachedPeerData {
    public let peerIds: Set<PeerId> = Set()
    public let messageIds: Set<MessageId> = Set()
    public let associatedHistoryMessageId: MessageId? = nil

    public let peerStatusSettings: PeerStatusSettings?
    
    public init(peerStatusSettings: PeerStatusSettings?) {
        self.peerStatusSettings = peerStatusSettings
    }
    
    public init(decoder: PostboxDecoder) {
        if let legacyValue = decoder.decodeOptionalInt32ForKey("pcs") {
            self.peerStatusSettings = PeerStatusSettings(flags: PeerStatusSettings.Flags(rawValue: legacyValue), geoDistance: nil)
        } else if let peerStatusSettings = decoder.decodeObjectForKey("pss", decoder: { PeerStatusSettings(decoder: $0) }) as? PeerStatusSettings {
            self.peerStatusSettings = peerStatusSettings
        } else {
            self.peerStatusSettings = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let peerStatusSettings = self.peerStatusSettings {
            encoder.encodeObject(peerStatusSettings, forKey: "pss")
        } else {
            encoder.encodeNil(forKey: "pss")
        }
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        if let to = to as? CachedSecretChatData {
            return self.peerStatusSettings == to.peerStatusSettings
        } else {
            return false
        }
    }
    
    public func withUpdatedPeerStatusSettings(_ peerStatusSettings: PeerStatusSettings) -> CachedSecretChatData {
        return CachedSecretChatData(peerStatusSettings: peerStatusSettings)
    }
}

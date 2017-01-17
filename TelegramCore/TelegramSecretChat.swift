import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class TelegramSecretChat: Peer {
    public let id: PeerId
    public let regularPeerId: PeerId
    public let accessHash: Int64
    public let embeddedState: SecretChatEmbeddedPeerState
    public let messageAutoremoveTimeout: Int32?
    
    public var indexName: PeerIndexNameRepresentation {
        return .title(title: "", addressName: nil)
    }
    
    public let associatedPeerIds: [PeerId]?
    
    init(id: PeerId, regularPeerId: PeerId, accessHash: Int64, embeddedState: SecretChatEmbeddedPeerState, messageAutoremoveTimeout: Int32?) {
        self.id = id
        self.regularPeerId = regularPeerId
        self.accessHash = accessHash
        self.embeddedState = embeddedState
        self.associatedPeerIds = [regularPeerId]
        self.messageAutoremoveTimeout = messageAutoremoveTimeout
    }
    
    public init(decoder: Decoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i"))
        self.regularPeerId = PeerId(decoder.decodeInt64ForKey("r"))
        self.accessHash = decoder.decodeInt64ForKey("h")
        self.embeddedState = SecretChatEmbeddedPeerState(rawValue: decoder.decodeInt32ForKey("s"))!
        self.associatedPeerIds = [self.regularPeerId]
        self.messageAutoremoveTimeout = decoder.decodeInt32ForKey("at")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.id.toInt64(), forKey: "i")
        encoder.encodeInt64(self.regularPeerId.toInt64(), forKey: "r")
        encoder.encodeInt64(self.accessHash, forKey: "h")
        encoder.encodeInt32(self.embeddedState.rawValue, forKey: "s")
        if let messageAutoremoveTimeout = self.messageAutoremoveTimeout {
            encoder.encodeInt32(messageAutoremoveTimeout, forKey: "at")
        } else {
            encoder.encodeNil(forKey: "at")
        }
    }
    
    public func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramSecretChat {
            return self.id == other.id && self.regularPeerId == other.regularPeerId && self.accessHash == other.accessHash && self.embeddedState == other.embeddedState && self.messageAutoremoveTimeout == other.messageAutoremoveTimeout
        } else {
            return false
        }
    }
    
    func withUpdatedEmbeddedState(_ embeddedState: SecretChatEmbeddedPeerState) -> TelegramSecretChat {
        return TelegramSecretChat(id: self.id, regularPeerId: self.regularPeerId, accessHash: self.accessHash, embeddedState: embeddedState, messageAutoremoveTimeout: self.messageAutoremoveTimeout)
    }
    
    func withUpdatedMessageAutoremoveTimeout(_ messageAutoremoveTimeout: Int32?) -> TelegramSecretChat {
        return TelegramSecretChat(id: self.id, regularPeerId: self.regularPeerId, accessHash: self.accessHash, embeddedState: self.embeddedState, messageAutoremoveTimeout: messageAutoremoveTimeout)
    }
}

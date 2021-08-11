import Postbox

public final class TelegramMediaContact: Media {
    public let id: MediaId? = nil
    public let firstName: String
    public let lastName: String
    public let phoneNumber: String
    public let peerId: PeerId?
    public let vCardData: String?
    
    public let peerIds: [PeerId]
    
    public init(firstName: String, lastName: String, phoneNumber: String, peerId: PeerId?, vCardData: String?) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.peerId = peerId
        self.vCardData = vCardData
        if let peerId = peerId {
            self.peerIds = [peerId]
        } else {
            self.peerIds = []
        }
    }
    
    public init(decoder: PostboxDecoder) {
        self.firstName = decoder.decodeStringForKey("n.f", orElse: "")
        self.lastName = decoder.decodeStringForKey("n.l", orElse: "")
        self.phoneNumber = decoder.decodeStringForKey("pn", orElse: "")
        if let peerIdValue = decoder.decodeOptionalInt64ForKey("p") {
            self.peerId = PeerId(peerIdValue)
            self.peerIds = [PeerId(peerIdValue)]
        } else {
            self.peerId = nil
            self.peerIds = []
        }
        self.vCardData = decoder.decodeOptionalStringForKey("vc")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.firstName, forKey: "n.f")
        encoder.encodeString(self.lastName, forKey: "n.l")
        encoder.encodeString(self.phoneNumber, forKey: "pn")
        if let peerId = self.peerId {
            encoder.encodeInt64(peerId.toInt64(), forKey: "p")
        }
        if let vCardData = self.vCardData {
            encoder.encodeString(vCardData, forKey: "vc")
        } else {
            encoder.encodeNil(forKey: "vc")
        }
    }
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaContact {
            if self.id == other.id && self.firstName == other.firstName && self.lastName == other.lastName && self.phoneNumber == other.phoneNumber && self.peerId == other.peerId && self.vCardData == other.vCardData && self.peerIds == other.peerIds {
                return true
            }
        }
        return false
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
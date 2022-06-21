import Foundation
import Postbox

public class InlineBotMessageAttribute: MessageAttribute {
    public let peerId: PeerId?
    public let title: String?
    
    public var associatedPeerIds: [PeerId] {
        if let peerId = self.peerId {
            return [peerId]
        } else {
            return []
        }
    }
    
    public init(peerId: PeerId?, title: String?) {
        self.peerId = peerId
        self.title = title
    }
    
    required public init(decoder: PostboxDecoder) {
        if let peerId = decoder.decodeOptionalInt64ForKey("i") {
            self.peerId = PeerId(peerId)
        } else {
            self.peerId = nil
        }
        self.title = decoder.decodeOptionalStringForKey("t")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let peerId = self.peerId {
            encoder.encodeInt64(peerId.toInt64(), forKey: "i")
        } else {
            encoder.encodeNil(forKey: "i")
        }
        if let title = self.title {
            encoder.encodeString(title, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
    }
}

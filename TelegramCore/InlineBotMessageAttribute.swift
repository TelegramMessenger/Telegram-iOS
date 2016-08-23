import Foundation
import Postbox

public class InlineBotMessageAttribute: MessageAttribute {
    public let peerId: PeerId
    
    public var associatedPeerIds: [PeerId] {
        return [self.peerId]
    }
    
    init(peerId: PeerId) {
        self.peerId = peerId
    }
    
    required public init(decoder: Decoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("i"))
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "i")
    }
}

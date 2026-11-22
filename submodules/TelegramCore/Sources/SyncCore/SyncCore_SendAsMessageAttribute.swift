import Foundation
import Postbox
        
public class SendAsMessageAttribute: MessageAttribute {
    public let peerId: PeerId
    
    public init(peerId: PeerId) {
        self.peerId = peerId
    }
    
    required public init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "peerId")
    }
}

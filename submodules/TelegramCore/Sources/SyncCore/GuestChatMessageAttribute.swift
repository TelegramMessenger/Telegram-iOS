import Foundation
import Postbox

public class GuestChatMessageAttribute: MessageAttribute {
    public let peerId: EnginePeer.Id
    
    public var associatedPeerIds: [PeerId] {
        return [self.peerId]
    }
    
    public init(peerId: EnginePeer.Id) {
        self.peerId = peerId
    }
    
    required public init(decoder: PostboxDecoder) {
        self.peerId = EnginePeer.Id(decoder.decodeInt64ForKey("p", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "p")
    }
}

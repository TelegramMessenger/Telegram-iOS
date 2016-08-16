import Foundation
import Postbox

class InlineBotMessageAttribute: MessageAttribute {
    let peerId: PeerId
    
    var associatedPeerIds: [PeerId] {
        return [self.peerId]
    }
    
    init(peerId: PeerId) {
        self.peerId = peerId
    }
    
    required init(decoder: Decoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("i"))
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "i")
    }
}

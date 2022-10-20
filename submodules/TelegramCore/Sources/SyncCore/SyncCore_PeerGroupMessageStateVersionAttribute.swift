import Foundation
import Postbox

public class PeerGroupMessageStateVersionAttribute: MessageAttribute {
    public let stateIndex: Int32
    
    public init(stateIndex: Int32) {
        self.stateIndex = stateIndex
    }
    
    required public init(decoder: PostboxDecoder) {
        self.stateIndex = decoder.decodeInt32ForKey("p", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.stateIndex, forKey: "p")
    }
}


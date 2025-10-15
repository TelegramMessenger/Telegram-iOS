import Foundation
import Postbox

public class ConsumablePersonalMentionMessageAttribute: MessageAttribute {
    public let consumed: Bool
    public let pending: Bool
    
    public init(consumed: Bool, pending: Bool) {
        self.consumed = consumed
        self.pending = pending
    }
    
    required public init(decoder: PostboxDecoder) {
        self.consumed = decoder.decodeInt32ForKey("c", orElse: 0) != 0
        self.pending = decoder.decodeInt32ForKey("p", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.consumed ? 1 : 0, forKey: "c")
        encoder.encodeInt32(self.pending ? 1 : 0, forKey: "p")
    }
}

import Foundation
import Postbox

public class ConsumableContentMessageAttribute: MessageAttribute {
    public let consumed: Bool
    
    public init(consumed: Bool) {
        self.consumed = consumed
    }
    
    required public init(decoder: PostboxDecoder) {
        self.consumed = decoder.decodeInt32ForKey("c", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.consumed ? 1 : 0, forKey: "c")
    }
}

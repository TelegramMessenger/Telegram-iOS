import Foundation
import Postbox

public class EffectMessageAttribute: MessageAttribute {
    public let id: Int64
    
    public init(id: Int64) {
        self.id = id
    }
    
    required public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("id", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "id")
    }
}

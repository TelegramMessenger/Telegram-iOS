import Foundation
import Postbox

public class ReplyThreadMessageAttribute: MessageAttribute {
    public let count: Int32
    
    public init(count: Int32) {
        self.count = count
    }
    
    required public init(decoder: PostboxDecoder) {
        self.count = decoder.decodeInt32ForKey("c", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.count, forKey: "c")
    }
}

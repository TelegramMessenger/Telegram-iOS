import Foundation
import Postbox

public class ForwardCountMessageAttribute: MessageAttribute {
    public let count: Int
    
    public var associatedMessageIds: [MessageId] = []
    
    public init(count: Int) {
        self.count = count
    }
    
    required public init(decoder: PostboxDecoder) {
        self.count = Int(decoder.decodeInt32ForKey("c", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.count), forKey: "c")
    }
}

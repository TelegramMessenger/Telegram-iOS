import Foundation
import Postbox
        
public class PendingProcessingMessageAttribute: MessageAttribute {
    public let approximateCompletionTime: Int32
    
    public init(approximateCompletionTime: Int32) {
        self.approximateCompletionTime = approximateCompletionTime
    }
    
    required public init(decoder: PostboxDecoder) {
        self.approximateCompletionTime = decoder.decodeInt32ForKey("et", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.approximateCompletionTime, forKey: "et")
    }
}

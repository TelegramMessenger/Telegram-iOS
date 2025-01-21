import Foundation
import Postbox
        
public class ForwardVideoTimestampAttribute: MessageAttribute {
    public let timestamp: Int32
    
    public init(timestamp: Int32) {
        self.timestamp = timestamp
    }
    
    required public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt32ForKey("timestamp", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timestamp, forKey: "timestamp")
    }
}

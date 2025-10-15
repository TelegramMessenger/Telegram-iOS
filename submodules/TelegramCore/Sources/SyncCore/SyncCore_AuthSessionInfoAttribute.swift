import Foundation
import Postbox

public class AuthSessionInfoAttribute: MessageAttribute {
    public var associatedMessageIds: [MessageId] = []
    
    public let hash: Int64
    public let timestamp: Int32
    
    public init(hash: Int64, timestamp: Int32) {
        self.hash = hash
        self.timestamp = timestamp
    }
    
    required public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
        self.hash = decoder.decodeInt64ForKey("s", orElse: 0)

    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timestamp, forKey: "t")
        encoder.encodeInt64(self.hash, forKey: "s")

    }
}

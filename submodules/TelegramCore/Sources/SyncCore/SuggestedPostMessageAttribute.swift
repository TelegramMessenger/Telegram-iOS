import Foundation
import Postbox
import TelegramApi

public final class OutgoingSuggestedPostMessageAttribute: Equatable, MessageAttribute {
    public let price: StarsAmount
    public let timestamp: Int32?
    
    public init(price: StarsAmount, timestamp: Int32?) {
        self.price = price
        self.timestamp = timestamp
    }
    
    required public init(decoder: PostboxDecoder) {
        self.price = decoder.decodeCodable(StarsAmount.self, forKey: "s") ?? StarsAmount(value: 0, nanos: 0)
        self.timestamp = decoder.decodeOptionalInt32ForKey("t")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeCodable(self.price, forKey: "s")
        if let timestamp = self.timestamp {
            encoder.encodeInt32(timestamp, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
    }
    
    public static func ==(lhs: OutgoingSuggestedPostMessageAttribute, rhs: OutgoingSuggestedPostMessageAttribute) -> Bool {
        if lhs.price != rhs.price {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        return true
    }
}

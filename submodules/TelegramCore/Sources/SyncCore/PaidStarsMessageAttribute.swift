import Foundation
import Postbox
import TelegramApi

public final class PaidStarsMessageAttribute: Equatable, MessageAttribute {
    public let stars: StarsAmount
    public let postponeSending: Bool
    
    public init(stars: StarsAmount, postponeSending: Bool) {
        self.stars = stars
        self.postponeSending = postponeSending
    }
    
    required public init(decoder: PostboxDecoder) {
        self.stars = decoder.decodeCodable(StarsAmount.self, forKey: "s") ?? StarsAmount(value: 0, nanos: 0)
        self.postponeSending = decoder.decodeBoolForKey("ps", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeCodable(self.stars, forKey: "s")
        encoder.encodeBool(self.postponeSending, forKey: "ps")
    }
    
    public static func ==(lhs: PaidStarsMessageAttribute, rhs: PaidStarsMessageAttribute) -> Bool {
        return lhs.stars == rhs.stars && lhs.postponeSending == rhs.postponeSending
    }
}

import Foundation
import Postbox
import TelegramApi

public final class PaidStarsMessageAttribute: Equatable, MessageAttribute {
    public let stars: StarsAmount
    
    public init(stars: StarsAmount) {
        self.stars = stars
    }
    
    required public init(decoder: PostboxDecoder) {
        self.stars = decoder.decodeCodable(StarsAmount.self, forKey: "s") ?? StarsAmount(value: 0, nanos: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeCodable(self.stars, forKey: "s")
    }
    
    public static func ==(lhs: PaidStarsMessageAttribute, rhs: PaidStarsMessageAttribute) -> Bool {
        return lhs.stars == rhs.stars
    }
}

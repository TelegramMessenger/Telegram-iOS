import Foundation
import Postbox
import TelegramApi

public final class ScheduledRepeatAttribute: Equatable, MessageAttribute {
    public let repeatPeriod: Int32
    
    public init(repeatPeriod: Int32) {
        self.repeatPeriod = repeatPeriod
    }
    
    required public init(decoder: PostboxDecoder) {
        self.repeatPeriod = decoder.decodeInt32ForKey("rp", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.repeatPeriod, forKey: "rp")
    }
    
    public static func ==(lhs: ScheduledRepeatAttribute, rhs: ScheduledRepeatAttribute) -> Bool {
        return lhs.repeatPeriod == rhs.repeatPeriod
    }
}

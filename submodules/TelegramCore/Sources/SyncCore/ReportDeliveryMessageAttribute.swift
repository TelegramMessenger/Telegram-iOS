import Foundation
import Postbox
import TelegramApi

public final class ReportDeliveryMessageAttribute: Equatable, MessageAttribute {
    public let untilDate: Int32
    
    public init(untilDate: Int32, isReported: Bool) {
        self.untilDate = untilDate
    }
    
    required public init(decoder: PostboxDecoder) {
        self.untilDate = decoder.decodeInt32ForKey("d", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.untilDate, forKey: "d")
    }
    
    public static func ==(lhs: ReportDeliveryMessageAttribute, rhs: ReportDeliveryMessageAttribute) -> Bool {
        return lhs.untilDate == rhs.untilDate
    }
}

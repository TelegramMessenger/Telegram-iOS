import Foundation
import Postbox
import TelegramApi

public final class ReportDeliveryMessageAttribute: Equatable, MessageAttribute {
    public let untilDate: Int32
    public let isReported: Bool
    
    public init(untilDate: Int32, isReported: Bool) {
        self.untilDate = untilDate
        self.isReported = isReported
    }
    
    required public init(decoder: PostboxDecoder) {
        self.untilDate = decoder.decodeInt32ForKey("d", orElse: 0)
        self.isReported = decoder.decodeBoolForKey("r", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.untilDate, forKey: "d")
        encoder.encodeBool(self.isReported, forKey: "r")
    }
    
    public static func ==(lhs: ReportDeliveryMessageAttribute, rhs: ReportDeliveryMessageAttribute) -> Bool {
        return lhs.untilDate == rhs.untilDate && lhs.isReported == rhs.isReported
    }
}

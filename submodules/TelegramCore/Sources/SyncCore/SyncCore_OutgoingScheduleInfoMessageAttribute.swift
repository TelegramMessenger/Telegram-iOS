import Foundation
import Postbox

public let scheduleWhenOnlineTimestamp: Int32 = 0x7ffffffe

public class OutgoingScheduleInfoMessageAttribute: MessageAttribute {
    public let scheduleTime: Int32
    
    public init(scheduleTime: Int32) {
        self.scheduleTime = scheduleTime
    }
    
    required public init(decoder: PostboxDecoder) {
        self.scheduleTime = decoder.decodeInt32ForKey("t", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(scheduleTime, forKey: "t")
    }
    
    public func withUpdatedScheduleTime(_ scheduleTime: Int32) -> OutgoingScheduleInfoMessageAttribute {
        return OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime)
    }
}

public extension Message {
    var scheduleTime: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                return attribute.scheduleTime
            }
        }
        return nil
    }
}

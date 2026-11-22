import Foundation
import Postbox

public let scheduleWhenOnlineTimestamp: Int32 = 0x7ffffffe

public class OutgoingScheduleInfoMessageAttribute: MessageAttribute {
    public let scheduleTime: Int32
    public let repeatPeriod: Int32?
    
    public init(scheduleTime: Int32, repeatPeriod: Int32?) {
        self.scheduleTime = scheduleTime
        self.repeatPeriod = repeatPeriod
    }
    
    required public init(decoder: PostboxDecoder) {
        self.scheduleTime = decoder.decodeInt32ForKey("t", orElse: 0)
        self.repeatPeriod = decoder.decodeOptionalInt32ForKey("rp")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.scheduleTime, forKey: "t")
        if let repeatPeriod = self.repeatPeriod {
            encoder.encodeInt32(repeatPeriod, forKey: "rp")
        } else {
            encoder.encodeNil(forKey: "rp")
        }
    }
    
    public func withUpdatedScheduleTime(_ scheduleTime: Int32) -> OutgoingScheduleInfoMessageAttribute {
        return OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime, repeatPeriod: self.repeatPeriod)
    }
    
    public func withUpdatedRepeatPeriod(_ repeatPeriod: Int32?) -> OutgoingScheduleInfoMessageAttribute {
        return OutgoingScheduleInfoMessageAttribute(scheduleTime: self.scheduleTime, repeatPeriod: repeatPeriod)
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
    
    var scheduleRepeatPeriod: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                return attribute.repeatPeriod
            } else if let attribute = attribute as? ScheduledRepeatAttribute {
                return attribute.repeatPeriod
            }
        }
        return nil
    }
}

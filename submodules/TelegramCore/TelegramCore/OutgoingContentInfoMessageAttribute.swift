import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct OutgoingContentInfoFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let disableLinkPreviews = OutgoingContentInfoFlags(rawValue: 1 << 0)
}

public class OutgoingContentInfoMessageAttribute: MessageAttribute {
    public let flags: OutgoingContentInfoFlags
    public let scheduleTime: Int32?
    
    public init(flags: OutgoingContentInfoFlags, scheduleTime: Int32?) {
        self.flags = flags
        self.scheduleTime = scheduleTime
    }
    
    required public init(decoder: PostboxDecoder) {
        self.flags = OutgoingContentInfoFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.scheduleTime = decoder.decodeOptionalInt32ForKey("t")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        if let scheduleTime = self.scheduleTime {
            encoder.encodeInt32(scheduleTime, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
    }
    
    public func withUpdatedFlags(_ flags: OutgoingContentInfoFlags) -> OutgoingContentInfoMessageAttribute {
        return OutgoingContentInfoMessageAttribute(flags: flags, scheduleTime: self.scheduleTime)
    }
    
    public func withUpdatedScheduleTime(_ scheduleTime: Int32?) -> OutgoingContentInfoMessageAttribute {
        return OutgoingContentInfoMessageAttribute(flags: self.flags, scheduleTime: scheduleTime)
    }
}

public extension Message {
    var scheduleTime: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? OutgoingContentInfoMessageAttribute, let scheduleTime = attribute.scheduleTime {
                return scheduleTime
            }
        }
        return nil
    }
}

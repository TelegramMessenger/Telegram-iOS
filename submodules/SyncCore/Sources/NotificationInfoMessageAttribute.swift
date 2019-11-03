import Foundation
import Postbox

public struct NotificationInfoMessageAttributeFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let muted = NotificationInfoMessageAttributeFlags(rawValue: 1)
    public static let personal = NotificationInfoMessageAttributeFlags(rawValue: 2)

}

public class NotificationInfoMessageAttribute: MessageAttribute {
    public let flags: NotificationInfoMessageAttributeFlags
    
    public init(flags: NotificationInfoMessageAttributeFlags) {
        self.flags = flags
    }
    
    required public init(decoder: PostboxDecoder) {
        self.flags = NotificationInfoMessageAttributeFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
    }
}

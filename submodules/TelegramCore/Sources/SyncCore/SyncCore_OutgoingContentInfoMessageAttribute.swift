import Foundation
import Postbox

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
    
    public init(flags: OutgoingContentInfoFlags) {
        self.flags = flags
    }
    
    required public init(decoder: PostboxDecoder) {
        self.flags = OutgoingContentInfoFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
    }
    
    public func withUpdatedFlags(_ flags: OutgoingContentInfoFlags) -> OutgoingContentInfoMessageAttribute {
        return OutgoingContentInfoMessageAttribute(flags: flags)
    }
}

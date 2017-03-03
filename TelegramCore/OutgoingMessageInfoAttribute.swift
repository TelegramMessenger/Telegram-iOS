import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct OutgoingMessageInfoFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static var transformedMedia = OutgoingMessageInfoFlags(rawValue: 1 << 0)
}

public class OutgoingMessageInfoAttribute: MessageAttribute {
    public let uniqueId: Int64
    public let flags: OutgoingMessageInfoFlags
    
    init(uniqueId: Int64, flags: OutgoingMessageInfoFlags) {
        self.uniqueId = uniqueId
        self.flags = flags
    }
    
    required public init(decoder: Decoder) {
        self.uniqueId = decoder.decodeInt64ForKey("u")
        self.flags = OutgoingMessageInfoFlags(rawValue: decoder.decodeInt32ForKey("f"))
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.uniqueId, forKey: "u")
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
    }
    
    public func withUpdatedFlags(_ flags: OutgoingMessageInfoFlags) -> OutgoingMessageInfoAttribute {
        return OutgoingMessageInfoAttribute(uniqueId: self.uniqueId, flags: flags)
    }
}

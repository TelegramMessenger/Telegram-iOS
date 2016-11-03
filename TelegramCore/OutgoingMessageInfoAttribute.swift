import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class OutgoingMessageInfoAttribute: MessageAttribute {
    public let uniqueId: Int64
    
    init(uniqueId: Int64) {
        self.uniqueId = uniqueId
    }
    
    required public init(decoder: Decoder) {
        self.uniqueId = decoder.decodeInt64ForKey("u")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.uniqueId, forKey: "u")
    }
}

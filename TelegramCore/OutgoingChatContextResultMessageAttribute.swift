import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class OutgoingChatContextResultMessageAttribute: MessageAttribute {
    public let queryId: Int64
    public let id: String
    
    init(queryId: Int64, id: String) {
        self.queryId = queryId
        self.id = id
    }
    
    required public init(decoder: Decoder) {
        self.queryId = decoder.decodeInt64ForKey("q")
        self.id = decoder.decodeStringForKey("i")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.queryId, forKey: "q")
        encoder.encodeString(self.id, forKey: "i")
    }
}

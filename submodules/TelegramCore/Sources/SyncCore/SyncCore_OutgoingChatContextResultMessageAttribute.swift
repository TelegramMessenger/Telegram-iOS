import Foundation
import Postbox

public class OutgoingChatContextResultMessageAttribute: MessageAttribute {
    public let queryId: Int64
    public let id: String
    public let hideVia: Bool
    
    public init(queryId: Int64, id: String, hideVia: Bool) {
        self.queryId = queryId
        self.id = id
        self.hideVia = hideVia
    }
    
    required public init(decoder: PostboxDecoder) {
        self.queryId = decoder.decodeInt64ForKey("q", orElse: 0)
        self.id = decoder.decodeStringForKey("i", orElse: "")
        self.hideVia = decoder.decodeBoolForKey("v", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.queryId, forKey: "q")
        encoder.encodeString(self.id, forKey: "i")
        encoder.encodeBool(self.hideVia, forKey: "v")
    }
}

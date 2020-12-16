import Foundation
import Postbox

public class EmojiSearchQueryMessageAttribute: MessageAttribute {
    public let query: String
    
    public var associatedMessageIds: [MessageId] = []
    
    public init(query: String) {
        self.query = query
    }
    
    required public init(decoder: PostboxDecoder) {
        self.query = decoder.decodeStringForKey("q", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.query, forKey: "q")
    }
}

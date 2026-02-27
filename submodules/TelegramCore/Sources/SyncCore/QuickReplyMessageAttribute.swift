import Foundation
import Postbox
import TelegramApi

public final class OutgoingQuickReplyMessageAttribute: Equatable, MessageAttribute {
    public let shortcut: String
    
    public init(shortcut: String) {
        self.shortcut = shortcut
    }
    
    required public init(decoder: PostboxDecoder) {
        self.shortcut = decoder.decodeStringForKey("s", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.shortcut, forKey: "s")
    }
    
    public static func ==(lhs: OutgoingQuickReplyMessageAttribute, rhs: OutgoingQuickReplyMessageAttribute) -> Bool {
        return true
    }
}

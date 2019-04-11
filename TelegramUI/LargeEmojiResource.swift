import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox

public struct LargeEmojiResourceId: MediaResourceId {
    public let emoji: String
    public let fontSize: CGFloat
    
    public var uniqueId: String {
        return "large-emoji-\(emoji)-\(fontSize)"
    }
    
    public var hashValue: Int {
        return self.emoji.hashValue &* 31 &+ self.fontSize.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LargeEmojiResourceId {
            return self.emoji == to.emoji && self.fontSize == to.fontSize
        } else {
            return false
        }
    }
}

public class LargeEmojiResource: TelegramMediaResource {
    public let emoji: String
    public let fontSize: CGFloat
    
    public init(emoji: String, fontSize: CGFloat) {
        self.emoji = emoji
        self.fontSize = fontSize
    }
    
    public required init(decoder: PostboxDecoder) {
        self.emoji = decoder.decodeStringForKey("e", orElse: "")
        self.fontSize = CGFloat(decoder.decodeDoubleForKey("s", orElse: 0.0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.emoji, forKey: "e")
        encoder.encodeDouble(Double(self.fontSize), forKey: "s")
    }
    
    public var id: MediaResourceId {
        return LargeEmojiResourceId(emoji: self.emoji, fontSize: self.fontSize)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LargeEmojiResource {
            return self.emoji == to.emoji && self.fontSize == to.fontSize
        } else {
            return false
        }
    }
}

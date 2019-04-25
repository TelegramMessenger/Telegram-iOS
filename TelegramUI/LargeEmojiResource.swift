import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox

public struct EmojiThumbnailResourceId: MediaResourceId {
    public let emoji: String
    
    public var uniqueId: String {
        return "emoji-thumb-\(self.emoji)"
    }
    
    public var hashValue: Int {
        return self.emoji.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? EmojiThumbnailResourceId {
            return self.emoji == to.emoji
        } else {
            return false
        }
    }
}

public class EmojiThumbnailResource: TelegramMediaResource {
    public let emoji: String
    
    public init(emoji: String) {
        self.emoji = emoji
    }
    
    public required init(decoder: PostboxDecoder) {
        self.emoji = decoder.decodeStringForKey("e", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.emoji, forKey: "e")
    }
    
    public var id: MediaResourceId {
        return EmojiThumbnailResourceId(emoji: self.emoji)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? EmojiThumbnailResource {
            return self.emoji == to.emoji
        } else {
            return false
        }
    }
}

public struct EmojiSpriteResourceId: MediaResourceId {
    public let packId: UInt8
    public let stickerId: UInt8
    
    public var uniqueId: String {
        return "emoji-sprite-\(self.packId)-\(self.stickerId)"
    }
    
    public var hashValue: Int {
        return self.packId.hashValue &* 31 &+ self.stickerId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? EmojiSpriteResourceId {
            return self.packId == to.packId && self.stickerId == to.stickerId
        } else {
            return false
        }
    }
}

public class EmojiSpriteResource: TelegramMediaResource {
    public let packId: UInt8
    public let stickerId: UInt8
    
    public init(packId: UInt8, stickerId: UInt8) {
        self.packId = packId
        self.stickerId = stickerId
    }
    
    public required init(decoder: PostboxDecoder) {
        self.packId = UInt8(decoder.decodeInt32ForKey("p", orElse: 0))
        self.stickerId = UInt8(decoder.decodeInt32ForKey("s", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.packId), forKey: "p")
        encoder.encodeInt32(Int32(self.stickerId), forKey: "s")
    }
    
    public var id: MediaResourceId {
        return EmojiSpriteResourceId(packId: self.packId, stickerId: self.stickerId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? EmojiSpriteResource {
            return self.packId == to.packId && self.stickerId == to.stickerId
        } else {
            return false
        }
    }
}

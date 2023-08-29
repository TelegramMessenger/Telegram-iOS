import Postbox

public final class TelegramMediaStory: Media, Equatable {
    public var id: MediaId? {
        return nil
    }
    public let peerIds: [PeerId]

    public let storyId: StoryId
    public let isMention: Bool
    
    public var storyIds: [StoryId] {
        return [self.storyId]
    }
    
    public init(storyId: StoryId, isMention: Bool) {
        self.storyId = storyId
        self.isMention = isMention

        self.peerIds = [self.storyId.peerId]
    }
    
    public init(decoder: PostboxDecoder) {
        self.storyId = StoryId(peerId: PeerId(decoder.decodeInt64ForKey("pid", orElse: 0)), id: decoder.decodeInt32ForKey("sid", orElse: 0))
        self.isMention = decoder.decodeBoolForKey("mns", orElse: false)
        
        self.peerIds = [self.storyId.peerId]
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.storyId.peerId.toInt64(), forKey: "pid")
        encoder.encodeInt32(self.storyId.id, forKey: "sid")
        encoder.encodeBool(self.isMention, forKey: "mns")
    }
    
    public func isLikelyToBeUpdated() -> Bool {
        return false
    }
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaStory, self.storyId == other.storyId {
            return self == other
        }
        return false
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
    
    public static func ==(lhs: TelegramMediaStory, rhs: TelegramMediaStory) -> Bool {
        if lhs.storyId != rhs.storyId {
            return false
        }
        if lhs.isMention != rhs.isMention {
            return false
        }
        
        return true
    }
}

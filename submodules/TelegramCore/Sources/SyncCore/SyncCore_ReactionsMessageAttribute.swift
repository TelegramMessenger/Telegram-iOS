import Postbox

public struct MessageReaction: Equatable, PostboxCoding {
    public var value: String
    public var count: Int32
    public var isSelected: Bool
    
    public init(value: String, count: Int32, isSelected: Bool) {
        self.value = value
        self.count = count
        self.isSelected = isSelected
    }
    
    public init(decoder: PostboxDecoder) {
        self.value = decoder.decodeStringForKey("v", orElse: "")
        self.count = decoder.decodeInt32ForKey("c", orElse: 0)
        self.isSelected = decoder.decodeInt32ForKey("s", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.value, forKey: "v")
        encoder.encodeInt32(self.count, forKey: "c")
        encoder.encodeInt32(self.isSelected ? 1 : 0, forKey: "s")
    }
}

public final class ReactionsMessageAttribute: MessageAttribute {
    public let reactions: [MessageReaction]
    
    public init(reactions: [MessageReaction]) {
        self.reactions = reactions
    }
    
    required public init(decoder: PostboxDecoder) {
        self.reactions = decoder.decodeObjectArrayWithDecoderForKey("r")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.reactions, forKey: "r")
    }
}

public final class PendingReactionsMessageAttribute: MessageAttribute {
    public let value: String?
    
    public init(value: String?) {
        self.value = value
    }
    
    required public init(decoder: PostboxDecoder) {
        self.value = decoder.decodeOptionalStringForKey("v")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let value = self.value {
            encoder.encodeString(value, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
    }
}

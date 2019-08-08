import Foundation
#if os(macOS)
import PostboxMac
import TelegramApiMac
#else
import Postbox
import TelegramApi
#endif

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

public class ReactionsMessageAttribute: MessageAttribute {
    public let reactions: [MessageReaction]
    
    init(reactions: [MessageReaction]) {
        self.reactions = reactions
    }
    
    required public init(decoder: PostboxDecoder) {
        self.reactions = decoder.decodeObjectArrayWithDecoderForKey("r")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.reactions, forKey: "r")
    }
    
    func withUpdatedResults(_ reactions: Api.MessageReactions) -> ReactionsMessageAttribute {
        switch reactions {
        case let .messageReactions(flags, results):
            let min = (flags & (1 << 0)) != 0
            var reactions = results.map { result -> MessageReaction in
                switch result {
                case let .reactionCount(flags, reaction, count):
                    return MessageReaction(value: reaction, count: count, isSelected: (flags & (1 << 0)) != 0)
                }
            }
            if min {
                var currentSelectedReaction: String?
                for reaction in self.reactions {
                    if reaction.isSelected {
                        currentSelectedReaction = reaction.value
                        break
                    }
                }
                if let currentSelectedReaction = currentSelectedReaction {
                    for i in 0 ..< reactions.count {
                        if reactions[i].value == currentSelectedReaction {
                            reactions[i].isSelected = true
                        }
                    }
                }
            }
            return ReactionsMessageAttribute(reactions: reactions)
        }
    }
}

extension ReactionsMessageAttribute {
    convenience init(apiReactions: Api.MessageReactions) {
        switch apiReactions {
        case let .messageReactions(_, results):
            self.init(reactions: results.map { result in
                switch result {
                case let .reactionCount(flags, reaction, count):
                    return MessageReaction(value: reaction, count: count, isSelected: (flags & (1 << 0)) != 0)
                }
            })
        }
    }
}

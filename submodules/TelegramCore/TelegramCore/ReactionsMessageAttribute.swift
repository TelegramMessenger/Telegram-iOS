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

public final class ReactionsMessageAttribute: MessageAttribute {
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

public func mergedMessageReactions(attributes: [MessageAttribute]) -> ReactionsMessageAttribute? {
    var current: ReactionsMessageAttribute?
    var pending: PendingReactionsMessageAttribute?
    for attribute in attributes {
        if let attribute = attribute as? ReactionsMessageAttribute {
            current = attribute
        } else if let attribute = attribute as? PendingReactionsMessageAttribute {
            pending = attribute
        }
    }
    
    if let pending = pending {
        var reactions = current?.reactions ?? []
        for value in pending.values {
            var found = false
            for i in 0 ..< reactions.count {
                if reactions[i].value == value {
                    found = true
                    if !reactions[i].isSelected {
                        reactions[i].isSelected = true
                        reactions[i].count += 1
                    }
                }
            }
            if !found {
                reactions.append(MessageReaction(value: value, count: 1, isSelected: true))
            }
        }
        for i in (0 ..< reactions.count).reversed() {
            if reactions[i].isSelected, !pending.values.contains(reactions[i].value) {
                if reactions[i].count == 1 {
                    reactions.remove(at: i)
                } else {
                    reactions[i].isSelected = false
                    reactions[i].count -= 1
                }
            }
        }
        if !reactions.isEmpty {
            return ReactionsMessageAttribute(reactions: reactions)
        } else {
            return nil
        }
    } else if let current = current {
        return current
    } else {
        return nil
    }
}

public final class PendingReactionsMessageAttribute: MessageAttribute {
    public let values: [String]
    
    init(values: [String]) {
        self.values = values
    }
    
    required public init(decoder: PostboxDecoder) {
        self.values = decoder.decodeStringArrayForKey("v")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(self.values, forKey: "v")
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

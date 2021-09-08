import Foundation
import Postbox
import TelegramApi


/*extension ReactionsMessageAttribute {
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
}*/

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
        if let value = pending.value {
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
            if reactions[i].isSelected, pending.value != reactions[i].value {
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

/*extension ReactionsMessageAttribute {
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
*/

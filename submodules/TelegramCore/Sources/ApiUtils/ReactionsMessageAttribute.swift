import Foundation
import Postbox
import TelegramApi

extension ReactionsMessageAttribute {
    func withUpdatedResults(_ reactions: Api.MessageReactions) -> ReactionsMessageAttribute {
        switch reactions {
        case let .messageReactions(flags, results, recentReactions):
            let min = (flags & (1 << 0)) != 0
            let canViewList = (flags & (1 << 2)) != 0
            var reactions = results.compactMap { result -> MessageReaction? in
                switch result {
                case let .reactionCount(_, chosenOrder, reaction, count):
                    if let reaction = MessageReaction.Reaction(apiReaction: reaction) {
                        return MessageReaction(value: reaction, count: count, chosenOrder: chosenOrder.flatMap(Int.init))
                    } else {
                        return nil
                    }
                }
            }
            let parsedRecentReactions: [ReactionsMessageAttribute.RecentPeer]
            if let recentReactions = recentReactions {
                parsedRecentReactions = recentReactions.compactMap { recentReaction -> ReactionsMessageAttribute.RecentPeer? in
                    switch recentReaction {
                    case let .messagePeerReaction(flags, peerId, reaction):
                        let isLarge = (flags & (1 << 0)) != 0
                        let isUnseen = (flags & (1 << 1)) != 0
                        if let reaction = MessageReaction.Reaction(apiReaction: reaction) {
                            return ReactionsMessageAttribute.RecentPeer(value: reaction, isLarge: isLarge, isUnseen: isUnseen, peerId: peerId.peerId)
                        } else {
                            return nil
                        }
                    }
                }
            } else {
                parsedRecentReactions = []
            }
            
            if min {
                var currentSelectedReactions: [MessageReaction.Reaction: Int] = [:]
                for reaction in self.reactions {
                    if let chosenOrder = reaction.chosenOrder {
                        currentSelectedReactions[reaction.value] = chosenOrder
                        break
                    }
                }
                if !currentSelectedReactions.isEmpty {
                    for i in 0 ..< reactions.count {
                        if let chosenOrder = currentSelectedReactions[reactions[i].value] {
                            reactions[i].chosenOrder = chosenOrder
                        }
                    }
                }
            }
            return ReactionsMessageAttribute(canViewList: canViewList, reactions: reactions, recentPeers: parsedRecentReactions)
        }
    }
}

public func mergedMessageReactionsAndPeers(accountPeer: EnginePeer?, message: Message) -> (reactions: [MessageReaction], peers: [(MessageReaction.Reaction, EnginePeer)]) {
    guard let attribute = mergedMessageReactions(attributes: message.attributes) else {
        return ([], [])
    }
    
    var recentPeers: [(MessageReaction.Reaction, EnginePeer)] = []
    
    if message.id.peerId.namespace == Namespaces.Peer.CloudUser {
        for reaction in attribute.reactions {
            var selfCount: Int32 = 0
            if reaction.isSelected {
                selfCount += 1
                if let accountPeer = accountPeer {
                    recentPeers.append((reaction.value, accountPeer))
                }
            }
            if reaction.count >= selfCount + 1 {
                if let peer = message.peers[message.id.peerId] {
                    recentPeers.append((reaction.value, EnginePeer(peer)))
                }
            }
        }
    } else {
        recentPeers = attribute.recentPeers.compactMap { recentPeer -> (MessageReaction.Reaction, EnginePeer)? in
            if let peer = message.peers[recentPeer.peerId] {
                return (recentPeer.value, EnginePeer(peer))
            } else {
                return nil
            }
        }
        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            recentPeers.removeAll()
        }
    }
    
    return (attribute.reactions, recentPeers)
}

private func mergeReactions(reactions: [MessageReaction], recentPeers: [ReactionsMessageAttribute.RecentPeer], pending: [PendingReactionsMessageAttribute.PendingReaction], accountPeerId: PeerId) -> ([MessageReaction], [ReactionsMessageAttribute.RecentPeer]) {
    var result = reactions
    var recentPeers = recentPeers
    
    var pendingIndex: Int = Int(Int32.max - 100)
    for pendingReaction in pending {
        if let index = result.firstIndex(where: { $0.value == pendingReaction.value }) {
            var merged = result[index]
            if merged.chosenOrder == nil {
                merged.chosenOrder = pendingIndex
                pendingIndex += 1
                merged.count += 1
            }
            result[index] = merged
        } else {
            result.append(MessageReaction(value: pendingReaction.value, count: 1, chosenOrder: pendingIndex))
            pendingIndex += 1
        }
        
        if let index = recentPeers.firstIndex(where: { $0.value == pendingReaction.value && $0.peerId == accountPeerId }) {
            recentPeers.remove(at: index)
        }
        recentPeers.append(ReactionsMessageAttribute.RecentPeer(value: pendingReaction.value, isLarge: false, isUnseen: false, peerId: accountPeerId))
    }
    
    for i in (0 ..< result.count).reversed() {
        if result[i].chosenOrder != nil {
            if !pending.contains(where: { $0.value == result[i].value }) {
                if let index = recentPeers.firstIndex(where: { $0.value == result[i].value && $0.peerId == accountPeerId }) {
                    recentPeers.remove(at: index)
                }
                
                if result[i].count <= 1 {
                    result.remove(at: i)
                } else {
                    result[i].count -= 1
                    result[i].chosenOrder = nil
                }
            }
        }
    }
    
    if recentPeers.count > 3 {
        recentPeers.removeFirst(recentPeers.count - 3)
    }
    
    return (result, recentPeers)
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
    
    if let pending = pending, let accountPeerId = pending.accountPeerId {
        var reactions = current?.reactions ?? []
        var recentPeers = current?.recentPeers ?? []
        
        let (updatedReactions, updatedRecentPeers) = mergeReactions(reactions: reactions, recentPeers: recentPeers, pending: pending.reactions, accountPeerId: accountPeerId)
        reactions = updatedReactions
        recentPeers = updatedRecentPeers
        
        if !reactions.isEmpty {
            return ReactionsMessageAttribute(canViewList: current?.canViewList ?? false, reactions: reactions, recentPeers: recentPeers)
        } else {
            return nil
        }
    } else if let current = current {
        return current
    } else {
        return nil
    }
}

extension ReactionsMessageAttribute {
    convenience init(apiReactions: Api.MessageReactions) {
        switch apiReactions {
        case let .messageReactions(flags, results, recentReactions):
            let canViewList = (flags & (1 << 2)) != 0
            let parsedRecentReactions: [ReactionsMessageAttribute.RecentPeer]
            if let recentReactions = recentReactions {
                parsedRecentReactions = recentReactions.compactMap { recentReaction -> ReactionsMessageAttribute.RecentPeer? in
                    switch recentReaction {
                    case let .messagePeerReaction(flags, peerId, reaction):
                        let isLarge = (flags & (1 << 0)) != 0
                        let isUnseen = (flags & (1 << 1)) != 0
                        if let reaction = MessageReaction.Reaction(apiReaction: reaction) {
                            return ReactionsMessageAttribute.RecentPeer(value: reaction, isLarge: isLarge, isUnseen: isUnseen, peerId: peerId.peerId)
                        } else {
                            return nil
                        }
                    }
                }
            } else {
                parsedRecentReactions = []
            }
            
            self.init(
                canViewList: canViewList,
                reactions: results.compactMap { result -> MessageReaction? in
                    switch result {
                    case let .reactionCount(_, chosenOrder, reaction, count):
                        if let reaction = MessageReaction.Reaction(apiReaction: reaction) {
                            return MessageReaction(value: reaction, count: count, chosenOrder: chosenOrder.flatMap(Int.init))
                        } else {
                            return nil
                        }
                    }
                },
                recentPeers: parsedRecentReactions
            )
        }
    }
}

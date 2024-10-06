import Foundation
import Postbox
import TelegramApi

extension ReactionsMessageAttribute {
    func withUpdatedResults(_ reactions: Api.MessageReactions) -> ReactionsMessageAttribute {
        switch reactions {
        case let .messageReactions(flags, results, recentReactions, topReactors):
            let min = (flags & (1 << 0)) != 0
            let canViewList = (flags & (1 << 2)) != 0
            let isTags = (flags & (1 << 3)) != 0
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
                    case let .messagePeerReaction(flags, peerId, date, reaction):
                        let isLarge = (flags & (1 << 0)) != 0
                        let isUnseen = (flags & (1 << 1)) != 0
                        let isMy = (flags & (1 << 2)) != 0
                        if let reaction = MessageReaction.Reaction(apiReaction: reaction) {
                            return ReactionsMessageAttribute.RecentPeer(value: reaction, isLarge: isLarge, isUnseen: isUnseen, isMy: isMy, peerId: peerId.peerId, timestamp: date)
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
            
            var topPeers: [ReactionsMessageAttribute.TopPeer] = []
            if let topReactors {
                for item in topReactors {
                    switch item {
                    case let .messageReactor(flags, peerId, count):
                        topPeers.append(ReactionsMessageAttribute.TopPeer(
                            peerId: peerId?.peerId,
                            count: count,
                            isTop: (flags & (1 << 0)) != 0,
                            isMy: (flags & (1 << 1)) != 0,
                            isAnonymous: (flags & (1 << 2)) != 0
                        ))
                    }
                }
            }
            
            return ReactionsMessageAttribute(canViewList: canViewList, isTags: isTags, reactions: reactions, recentPeers: parsedRecentReactions, topPeers: topPeers)
        }
    }
}

public func mergedMessageReactionsAndPeers(accountPeerId: EnginePeer.Id, accountPeer: EnginePeer?, message: Message) -> (reactions: [MessageReaction], peers: [(MessageReaction.Reaction, EnginePeer)]) {
    guard let attribute = mergedMessageReactions(attributes: message.attributes, isTags: message.areReactionsTags(accountPeerId: accountPeerId)) else {
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
    
    let reactions = attribute.reactions
    
    return (reactions, recentPeers)
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
        
        let pendingReactionSendAsPeerId = pendingReaction.sendAsPeerId ?? accountPeerId
        
        if let index = recentPeers.firstIndex(where: {
            $0.value == pendingReaction.value && ($0.peerId == pendingReactionSendAsPeerId || $0.isMy)
        }) {
            recentPeers.remove(at: index)
        }
        recentPeers.append(ReactionsMessageAttribute.RecentPeer(value: pendingReaction.value, isLarge: false, isUnseen: false, isMy: true, peerId: pendingReactionSendAsPeerId, timestamp: Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)))
    }
    
    for i in (0 ..< result.count).reversed() {
        if result[i].chosenOrder != nil {
            if !pending.contains(where: { $0.value == result[i].value }), result[i].value != .stars {
                if let index = recentPeers.firstIndex(where: { $0.value == result[i].value && ($0.peerId == accountPeerId || $0.isMy) }) {
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

public func mergedMessageReactions(attributes: [MessageAttribute], isTags: Bool) -> ReactionsMessageAttribute? {
    var current: ReactionsMessageAttribute?
    var pending: PendingReactionsMessageAttribute?
    var pendingStars: PendingStarsReactionsMessageAttribute?
    for attribute in attributes {
        if let attribute = attribute as? ReactionsMessageAttribute {
            current = attribute
        } else if let attribute = attribute as? PendingReactionsMessageAttribute {
            pending = attribute
        } else if let attribute = attribute as? PendingStarsReactionsMessageAttribute {
            pendingStars = attribute
        }
    }
    
    let result: ReactionsMessageAttribute?
    if let pending = pending, let accountPeerId = pending.accountPeerId {
        var reactions = current?.reactions ?? []
        var recentPeers = current?.recentPeers ?? []
        
        let (updatedReactions, updatedRecentPeers) = mergeReactions(reactions: reactions, recentPeers: recentPeers, pending: pending.reactions, accountPeerId: accountPeerId)
        reactions = updatedReactions
        recentPeers = updatedRecentPeers
        
        if !reactions.isEmpty {
            result = ReactionsMessageAttribute(canViewList: current?.canViewList ?? false, isTags: current?.isTags ?? isTags, reactions: reactions, recentPeers: recentPeers, topPeers: current?.topPeers ?? [])
        } else {
            result = nil
        }
    } else if let current {
        result = current
    } else {
        result = nil
    }
    
    if let pendingStars {
        if let result {
            var reactions = result.reactions
            var updatedCount: Int32 = pendingStars.count
            if let index = reactions.firstIndex(where: { $0.value == .stars }) {
                updatedCount += reactions[index].count
                reactions.remove(at: index)
            }
            var topPeers = result.topPeers
            if let index = topPeers.firstIndex(where: { $0.isMy }) {
                topPeers[index].count += pendingStars.count
            } else {
                topPeers.append(ReactionsMessageAttribute.TopPeer(peerId: pendingStars.accountPeerId, count: pendingStars.count, isTop: false, isMy: true, isAnonymous: pendingStars.isAnonymous))
            }
            reactions.insert(MessageReaction(value: .stars, count: updatedCount, chosenOrder: -1), at: 0)
            return ReactionsMessageAttribute(canViewList: current?.canViewList ?? false, isTags: current?.isTags ?? isTags, reactions: reactions, recentPeers: result.recentPeers, topPeers: topPeers)
        } else {
            return ReactionsMessageAttribute(canViewList: current?.canViewList ?? false, isTags: current?.isTags ?? isTags, reactions: [MessageReaction(value: .stars, count: pendingStars.count, chosenOrder: -1)], recentPeers: [], topPeers: [ReactionsMessageAttribute.TopPeer(peerId: pendingStars.accountPeerId, count: pendingStars.count, isTop: false, isMy: true, isAnonymous: pendingStars.isAnonymous)])
        }
    } else {
        return result
    }
}

extension ReactionsMessageAttribute {
    convenience init(apiReactions: Api.MessageReactions) {
        switch apiReactions {
        case let .messageReactions(flags, results, recentReactions, topReactors):
            let canViewList = (flags & (1 << 2)) != 0
            let isTags = (flags & (1 << 3)) != 0
            let parsedRecentReactions: [ReactionsMessageAttribute.RecentPeer]
            if let recentReactions = recentReactions {
                parsedRecentReactions = recentReactions.compactMap { recentReaction -> ReactionsMessageAttribute.RecentPeer? in
                    switch recentReaction {
                    case let .messagePeerReaction(flags, peerId, date, reaction):
                        let isLarge = (flags & (1 << 0)) != 0
                        let isUnseen = (flags & (1 << 1)) != 0
                        let isMy = (flags & (1 << 2)) != 0
                        if let reaction = MessageReaction.Reaction(apiReaction: reaction) {
                            return ReactionsMessageAttribute.RecentPeer(value: reaction, isLarge: isLarge, isUnseen: isUnseen, isMy: isMy, peerId: peerId.peerId, timestamp: date)
                        } else {
                            return nil
                        }
                    }
                }
            } else {
                parsedRecentReactions = []
            }
            
            var topPeers: [ReactionsMessageAttribute.TopPeer] = []
            if let topReactors {
                for item in topReactors {
                    switch item {
                    case let .messageReactor(flags, peerId, count):
                        topPeers.append(ReactionsMessageAttribute.TopPeer(
                            peerId: peerId?.peerId,
                            count: count,
                            isTop: (flags & (1 << 0)) != 0,
                            isMy: (flags & (1 << 1)) != 0,
                            isAnonymous: (flags & (1 << 2)) != 0
                        ))
                    }
                }
            }
            
            self.init(
                canViewList: canViewList,
                isTags: isTags,
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
                recentPeers: parsedRecentReactions,
                topPeers: topPeers
            )
        }
    }
}

import Foundation
import Postbox
import TelegramApi

extension ReactionsMessageAttribute {
    func withUpdatedResults(_ reactions: Api.MessageReactions) -> ReactionsMessageAttribute {
        switch reactions {
        case let .messageReactions(flags, results, recentReactions):
            let min = (flags & (1 << 0)) != 0
            let canViewList = (flags & (1 << 2)) != 0
            var reactions = results.map { result -> MessageReaction in
                switch result {
                case let .reactionCount(flags, reaction, count):
                    return MessageReaction(value: reaction, count: count, isSelected: (flags & (1 << 0)) != 0)
                }
            }
            let parsedRecentReactions: [ReactionsMessageAttribute.RecentPeer]
            if let recentReactions = recentReactions {
                parsedRecentReactions = recentReactions.map { recentReaction -> ReactionsMessageAttribute.RecentPeer in
                    switch recentReaction {
                    case let .messagePeerReaction(flags, peerId, reaction):
                        let isLarge = (flags & (1 << 0)) != 0
                        let isUnseen = (flags & (1 << 1)) != 0
                        return ReactionsMessageAttribute.RecentPeer(value: reaction, isLarge: isLarge, isUnseen: isUnseen, peerId: peerId.peerId)
                    }
                }
            } else {
                parsedRecentReactions = []
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
            return ReactionsMessageAttribute(canViewList: canViewList, reactions: reactions, recentPeers: parsedRecentReactions)
        }
    }
}

public func mergedMessageReactionsAndPeers(message: Message) -> (reactions: [MessageReaction], peers: [(String, EnginePeer)]) {
    guard let attribute = mergedMessageReactions(attributes: message.attributes) else {
        return ([], [])
    }
    
    var recentPeers = attribute.recentPeers.compactMap { recentPeer -> (String, EnginePeer)? in
        if let peer = message.peers[recentPeer.peerId] {
            return (recentPeer.value, EnginePeer(peer))
        } else {
            return nil
        }
    }
    if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
        recentPeers.removeAll()
    }
    
    return (attribute.reactions, recentPeers)
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
        var recentPeers = current?.recentPeers ?? []
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
        if let accountPeerId = pending.accountPeerId {
            for i in 0 ..< recentPeers.count {
                if recentPeers[i].peerId == accountPeerId {
                    recentPeers.remove(at: i)
                    break
                }
            }
            if let value = pending.value {
                recentPeers.append(ReactionsMessageAttribute.RecentPeer(value: value, isLarge: false, isUnseen: false, peerId: accountPeerId))
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
                parsedRecentReactions = recentReactions.map { recentReaction -> ReactionsMessageAttribute.RecentPeer in
                    switch recentReaction {
                    case let .messagePeerReaction(flags, peerId, reaction):
                        let isLarge = (flags & (1 << 0)) != 0
                        let isUnseen = (flags & (1 << 1)) != 0
                        return ReactionsMessageAttribute.RecentPeer(value: reaction, isLarge: isLarge, isUnseen: isUnseen, peerId: peerId.peerId)
                    }
                }
            } else {
                parsedRecentReactions = []
            }
            
            self.init(
                canViewList: canViewList,
                reactions: results.map { result in
                    switch result {
                    case let .reactionCount(flags, reaction, count):
                        return MessageReaction(value: reaction, count: count, isSelected: (flags & (1 << 0)) != 0)
                    }
                },
                recentPeers: parsedRecentReactions
            )
        }
    }
}

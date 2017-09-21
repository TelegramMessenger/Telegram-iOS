import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func recentPeers(account: Account) -> Signal<[Peer], NoError> {
    let cachedPeers = account.postbox.recentPeers()
        |> take(1)
    
    let remotePeers = account.network.request(Api.functions.contacts.getTopPeers(flags: 1 << 0, offset: 0, limit: 16, hash: 0))
        |> retryRequest
        |> map { result -> ([Peer], [PeerId: PeerPresence])? in
            switch result {
                case let .topPeers(_, _, users):
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: PeerPresence] = [:]
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        if let presence = TelegramUserPresence(apiUser: user) {
                            peerPresences[telegramUser.id] = presence
                        }
                    }
                    return (peers, peerPresences)
                case .topPeersNotModified:
                    break
            }
            return ([], [:])
        }
    
    let updatedRemotePeers = remotePeers
        |> mapToSignal { peersAndPresences -> Signal<[Peer], NoError> in
            if let (peers, peerPresences) = peersAndPresences {
                return account.postbox.modify { modifier -> [Peer] in
                    updatePeers(modifier: modifier, peers: peers, update: { return $1 })
                    modifier.updatePeerPresences(peerPresences)
                    modifier.replaceRecentPeerIds(peers.map({ $0.id }))
                    return peers
                }
            } else {
                return .complete()
            }
        }
    return cachedPeers |> then(updatedRemotePeers |> filter({ !$0.isEmpty }))
}

public func removeRecentPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        var peerIds = modifier.getRecentPeerIds()
        if let index = peerIds.index(of: peerId) {
            peerIds.remove(at: index)
            modifier.replaceRecentPeerIds(peerIds)
        }
        if let peer = modifier.getPeer(peerId), let apiPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.contacts.resetTopPeerRating(category: .topPeerCategoryCorrespondents, peer: apiPeer))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                }
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return .complete()
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func managedRecentlyUsedInlineBots(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let remotePeers = network.request(Api.functions.contacts.getTopPeers(flags: 1 << 2, offset: 0, limit: 16, hash: 0))
        |> retryRequest
        |> map { result -> ([Peer], [PeerId: PeerPresence], [(PeerId, Double)])? in
            switch result {
                case let .topPeers(categories, _, users):
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: PeerPresence] = [:]
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        if let presence = TelegramUserPresence(apiUser: user) {
                            peerPresences[telegramUser.id] = presence
                        }
                    }
                    var peersWithRating: [(PeerId, Double)] = []
                    for category in categories {
                        switch category {
                            case let .topPeerCategoryPeers(_, _, topPeers):
                                for topPeer in topPeers {
                                    switch topPeer {
                                        case let .topPeer(apiPeer, rating):
                                            peersWithRating.append((apiPeer.peerId, rating))
                                    }
                                }
                        }
                    }
                    return (peers, peerPresences, peersWithRating)
                case .topPeersNotModified:
                    break
            }
            return ([], [:], [])
    }
    
    let updatedRemotePeers = remotePeers
        |> mapToSignal { peersAndPresences -> Signal<Void, NoError> in
            if let (peers, peerPresences, peersWithRating) = peersAndPresences {
                return postbox.modify { modifier -> Void in
                    updatePeers(modifier: modifier, peers: peers, update: { return $1 })
                    modifier.updatePeerPresences(peerPresences)
                    
                    let sortedPeersWithRating = peersWithRating.sorted(by: { $0.1 > $1.1 })
                    
                    modifier.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, items: sortedPeersWithRating.map { (peerId, rating) in
                        return OrderedItemListEntry(id: RecentPeerItemId(peerId).rawValue, contents: RecentPeerItem(rating: rating))
                    })
                }
            } else {
                return .complete()
            }
    }
    
    return updatedRemotePeers
}

public func addRecentlyUsedInlineBot(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        var maxRating = 1.0
        for entry in modifier.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots) {
            if let contents = entry.contents as? RecentPeerItem {
                maxRating = max(maxRating, contents.rating)
            }
        }
        modifier.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, item: OrderedItemListEntry(id: RecentPeerItemId(peerId).rawValue, contents: RecentPeerItem(rating: maxRating)), removeTailIfCountExceeds: 20)
    }
}

public func recentlyUsedInlineBots(postbox: Postbox) -> Signal<[(Peer, Double)], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentInlineBots)])
        |> take(1)
        |> mapToSignal { view -> Signal<[(Peer, Double)], NoError> in
            return postbox.modify { modifier -> [(Peer, Double)] in
                var peers: [(Peer, Double)] = []
                if let view = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentInlineBots)] as? OrderedItemListView {
                    for item in view.items {
                        let peerId = RecentPeerItemId(item.id).peerId
                        if let peer = modifier.getPeer(peerId), let contents = item.contents as? RecentPeerItem {
                            peers.append((peer, contents.rating))
                        }
                    }
                }
                return peers
            }
    }
}


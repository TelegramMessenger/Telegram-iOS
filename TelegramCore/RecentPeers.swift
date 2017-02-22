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

public func managedRecentlyUsedInlineBots(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let remotePeers = network.request(Api.functions.contacts.getTopPeers(flags: 1 << 2, offset: 0, limit: 16, hash: 0))
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
        |> mapToSignal { peersAndPresences -> Signal<Void, NoError> in
            if let (peers, peerPresences) = peersAndPresences {
                return postbox.modify { modifier -> Void in
                    updatePeers(modifier: modifier, peers: peers, update: { return $1 })
                    modifier.updatePeerPresences(peerPresences)
                    modifier.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, items: peers.map { peer in
                        return OrderedItemListEntry(id: RecentPeerItemId(peer.id).rawValue, contents: RecentPeerItem())
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
        modifier.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, item: OrderedItemListEntry(id: RecentPeerItemId(peerId).rawValue, contents: RecentPeerItem()), removeTailIfCountExceeds: 20)
    }
}

public func recentlyUsedInlineBots(postbox: Postbox) -> Signal<[Peer], NoError> {
    return postbox.orderedItemListView(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots)
        |> take(1)
        |> mapToSignal { view -> Signal<[Peer], NoError> in
            return postbox.modify { modifier -> [Peer] in
                var peers: [Peer] = []
                for item in view.items {
                    let peerId = RecentPeerItemId(item.id).peerId
                    if let peer = modifier.getPeer(peerId) {
                        peers.append(peer)
                    }
                }
                return peers
            }
    }
}


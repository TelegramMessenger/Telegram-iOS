import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


public enum RecentPeers {
    case peers([Peer])
    case disabled
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 1, highWaterItemCount: 1)

private func cachedRecentPeersEntryId() -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: 101, key: CachedRecentPeers.cacheKey())
}

func _internal_recentPeers(account: Account) -> Signal<RecentPeers, NoError> {
    let key = PostboxViewKey.cachedItem(cachedRecentPeersEntryId())
    return account.postbox.combinedView(keys: [key])
    |> mapToSignal { views -> Signal<RecentPeers, NoError> in
        if let value = (views.views[key] as? CachedItemView)?.value as? CachedRecentPeers {
            if value.enabled {
                return account.postbox.multiplePeersView(value.ids)
                |> map { view -> RecentPeers in
                    var peers: [Peer] = []
                    for id in value.ids {
                        if let peer = view.peers[id], id != account.peerId {
                            peers.append(peer)
                        }
                    }
                    return .peers(peers)
                }
            } else {
                return .single(.disabled)
            }
        } else {
            return .single(.peers([]))
        }
    }
}

public func _internal_getRecentPeers(transaction: Transaction) -> [PeerId] {
    guard let entry = transaction.retrieveItemCacheEntry(id: cachedRecentPeersEntryId()) as? CachedRecentPeers else {
        return []
    }
    return entry.ids
}

func _internal_managedUpdatedRecentPeers(accountPeerId: PeerId, postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let key = PostboxViewKey.cachedItem(cachedRecentPeersEntryId())
    let peersEnabled = postbox.combinedView(keys: [key])
    |> map { views -> Bool in
        if let value = (views.views[key] as? CachedItemView)?.value as? CachedRecentPeers {
            return value.enabled
        } else {
            return true
        }
    }
    |> distinctUntilChanged
    
    let updateOnce =
        network.request(Api.functions.contacts.getTopPeers(flags: 1 << 0, offset: 0, limit: 50, hash: 0))
    |> `catch` { _ -> Signal<Api.contacts.TopPeers, NoError> in
        return .complete()
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> Void in
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
                    updatePeers(transaction: transaction, peers: peers, update: { return $1 })
                    
                    updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                
                    transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: CachedRecentPeers(enabled: true, ids: peers.map { $0.id }), collectionSpec: collectionSpec)
                case .topPeersNotModified:
                    break
                case .topPeersDisabled:
                    transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: CachedRecentPeers(enabled: false, ids: []), collectionSpec: collectionSpec)
            }
        }
    }
    
    return peersEnabled |> mapToSignal { _ -> Signal<Void, NoError> in
        return updateOnce
    }
}

func _internal_removeRecentPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        guard let entry = transaction.retrieveItemCacheEntry(id: cachedRecentPeersEntryId()) as? CachedRecentPeers else {
            return .complete()
        }
        
        if let index = entry.ids.firstIndex(of: peerId) {
            var updatedIds = entry.ids
            updatedIds.remove(at: index)
            transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: CachedRecentPeers(enabled: entry.enabled, ids: updatedIds), collectionSpec: collectionSpec)
        }
        if let peer = transaction.getPeer(peerId), let apiPeer = apiInputPeer(peer) {
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

func _internal_updateRecentPeersEnabled(postbox: Postbox, network: Network, enabled: Bool) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var currentValue = true
        if let entry = transaction.retrieveItemCacheEntry(id: cachedRecentPeersEntryId()) as? CachedRecentPeers {
            currentValue = entry.enabled
        }
        
        if currentValue == enabled {
            return .complete()
        }
        
        return network.request(Api.functions.contacts.toggleTopPeers(enabled: enabled ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                if !enabled {
                    transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: CachedRecentPeers(enabled: false, ids: []), collectionSpec: collectionSpec)
                } else {
                    let entry = transaction.retrieveItemCacheEntry(id: cachedRecentPeersEntryId()) as? CachedRecentPeers
                    transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: CachedRecentPeers(enabled: true, ids: entry?.ids ?? []), collectionSpec: collectionSpec)
                }
            }
        }
    } |> switchToLatest
}

func _internal_managedRecentlyUsedInlineBots(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Void, NoError> {
    let remotePeers = network.request(Api.functions.contacts.getTopPeers(flags: 1 << 2, offset: 0, limit: 16, hash: 0))
        |> retryRequest
        |> map { result -> ([Peer], [PeerId: PeerPresence], [(PeerId, Double)])? in
            switch result {
                case .topPeersDisabled:
                    break
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
                return postbox.transaction { transaction -> Void in
                    updatePeers(transaction: transaction, peers: peers, update: { return $1 })
                    
                    updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                    
                    let sortedPeersWithRating = peersWithRating.sorted(by: { $0.1 > $1.1 })
                    
                    transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, items: sortedPeersWithRating.map { (peerId, rating) in
                        return OrderedItemListEntry(id: RecentPeerItemId(peerId).rawValue, contents: RecentPeerItem(rating: rating))
                    })
                }
            } else {
                return .complete()
            }
    }
    
    return updatedRemotePeers
}

func _internal_addRecentlyUsedInlineBot(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var maxRating = 1.0
        for entry in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots) {
            if let contents = entry.contents as? RecentPeerItem {
                maxRating = max(maxRating, contents.rating)
            }
        }
        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, item: OrderedItemListEntry(id: RecentPeerItemId(peerId).rawValue, contents: RecentPeerItem(rating: maxRating)), removeTailIfCountExceeds: 20)
    }
}

func _internal_recentlyUsedInlineBots(postbox: Postbox) -> Signal<[(Peer, Double)], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentInlineBots)])
        |> take(1)
        |> mapToSignal { view -> Signal<[(Peer, Double)], NoError> in
            return postbox.transaction { transaction -> [(Peer, Double)] in
                var peers: [(Peer, Double)] = []
                if let view = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentInlineBots)] as? OrderedItemListView {
                    for item in view.items {
                        let peerId = RecentPeerItemId(item.id).peerId
                        if let peer = transaction.getPeer(peerId), let contents = item.contents as? RecentPeerItem {
                            peers.append((peer, contents.rating))
                        }
                    }
                }
                return peers
            }
    }
}

func _internal_removeRecentlyUsedInlineBot(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, itemId: RecentPeerItemId(peerId).rawValue)
        
        if let peer = transaction.getPeer(peerId), let apiPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.contacts.resetTopPeerRating(category: .topPeerCategoryBotsInline, peer: apiPeer))
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

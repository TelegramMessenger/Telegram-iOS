import Foundation
import Postbox
import SwiftSignalKit


func _internal_addRecentlySearchedPeer(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let entry = CodableEntry(RecentPeerItem(rating: 0.0)) {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, item: OrderedItemListEntry(id: RecentPeerItemId(peerId).rawValue, contents: entry), removeTailIfCountExceeds: 20)
        }
    }
}

func _internal_removeRecentlySearchedPeer(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, itemId: RecentPeerItemId(peerId).rawValue)
    }
}

func _internal_clearRecentlySearchedPeers(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, items: [])
    }
}

public struct RecentlySearchedPeerSubpeerSummary: Equatable {
    public let count: Int
}

public struct RecentlySearchedPeer: Equatable {
    public let peer: RenderedPeer
    public let presence: TelegramUserPresence?
    public let notificationSettings: TelegramPeerNotificationSettings?
    public let unreadCount: Int32
    public let subpeerSummary: RecentlySearchedPeerSubpeerSummary?
}

func _internal_recentlySearchedPeers(postbox: Postbox) -> Signal<[RecentlySearchedPeer], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.RecentlySearchedPeerIds)])
    |> mapToSignal { view -> Signal<[RecentlySearchedPeer], NoError> in
        var peerIds: [PeerId] = []
        if let view = view.views[.orderedItemList(id: Namespaces.OrderedItemList.RecentlySearchedPeerIds)] as? OrderedItemListView {
            for item in view.items {
                let peerId = RecentPeerItemId(item.id).peerId
                peerIds.append(peerId)
            }
        }
        var keys: [PostboxViewKey] = []
        let unreadCountsKey: PostboxViewKey = .unreadCounts(items: peerIds.map(UnreadMessageCountsItem.peer))
        keys.append(unreadCountsKey)
        keys.append(contentsOf: peerIds.map({ .peer(peerId: $0, components: .all) }))
        
        return postbox.combinedView(keys: keys)
        |> map { view -> [RecentlySearchedPeer] in
            var result: [RecentlySearchedPeer] = []
            var unreadCounts: [PeerId: Int32] = [:]
            if let unreadCountsView = view.views[unreadCountsKey] as? UnreadMessageCountsView {
                for entry in unreadCountsView.entries {
                    if case let .peer(peerId, state) = entry {
                        unreadCounts[peerId] = state?.count ?? 0
                    }
                }
            }
            
            for peerId in peerIds {
                if let peerView = view.views[.peer(peerId: peerId, components: .all)] as? PeerView {
                    var presence: TelegramUserPresence?
                    var unreadCount = unreadCounts[peerId] ?? 0
                    if let peer = peerView.peers[peerId] {
                        if let associatedPeerId = peer.associatedPeerId {
                            presence = peerView.peerPresences[associatedPeerId] as? TelegramUserPresence
                        } else {
                            presence = peerView.peerPresences[peerId] as? TelegramUserPresence
                        }
                        
                        if let channel = peer as? TelegramChannel {
                            if case .member = channel.participationStatus {
                            } else {
                                unreadCount = 0
                            }
                        }
                    }
                    
                    var subpeerSummary: RecentlySearchedPeerSubpeerSummary?
                    if let cachedData = peerView.cachedData as? CachedChannelData {
                        let count: Int32 = cachedData.participantsSummary.memberCount ?? 0
                        subpeerSummary = RecentlySearchedPeerSubpeerSummary(count: Int(count))
                    }
                    
                    result.append(RecentlySearchedPeer(peer: RenderedPeer(peerId: peerId, peers: SimpleDictionary(peerView.peers)), presence: presence, notificationSettings: peerView.notificationSettings as? TelegramPeerNotificationSettings, unreadCount: unreadCount, subpeerSummary: subpeerSummary))
                }
            }
            
            return result
        }
    }
}

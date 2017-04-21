import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func addRecentlySearchedPeer(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, item: OrderedItemListEntry(id: RecentPeerItemId(peerId).rawValue, contents: RecentPeerItem()), removeTailIfCountExceeds: 20)
    }
}

public func removeRecentlySearchedPeer(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, itemId: RecentPeerItemId(peerId).rawValue)
    }
}

public func recentlySearchedPeers(postbox: Postbox) -> Signal<[Peer], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.RecentlySearchedPeerIds)])
        //|> take(1)
        |> mapToSignal { view -> Signal<[Peer], NoError> in
            return postbox.modify { modifier -> [Peer] in
                var peers: [Peer] = []
                if let view = view.views[.orderedItemList(id: Namespaces.OrderedItemList.RecentlySearchedPeerIds)] as? OrderedItemListView {
                    for item in view.items {
                        let peerId = RecentPeerItemId(item.id).peerId
                        if let peer = modifier.getPeer(peerId) {
                            peers.append(peer)
                        }
                    }
                }
                return peers
            }
        }
}

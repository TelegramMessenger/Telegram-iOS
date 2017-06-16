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

public func recentlySearchedPeers(postbox: Postbox) -> Signal<[RenderedPeer], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.RecentlySearchedPeerIds)])
        |> mapToSignal { view -> Signal<[RenderedPeer], NoError> in
            return postbox.modify { modifier -> [RenderedPeer] in
                var result: [RenderedPeer] = []
                if let view = view.views[.orderedItemList(id: Namespaces.OrderedItemList.RecentlySearchedPeerIds)] as? OrderedItemListView {
                    for item in view.items {
                        let peerId = RecentPeerItemId(item.id).peerId
                        if let peer = modifier.getPeer(peerId) {
                            var peers = SimpleDictionary<PeerId, Peer>()
                            peers[peer.id] = peer
                            if let associatedPeerId = peer.associatedPeerId {
                                if let associatedPeer = modifier.getPeer(associatedPeerId) {
                                    peers[associatedPeer.id] = associatedPeer
                                }
                            }
                            result.append(RenderedPeer(peerId: peer.id, peers: peers))
                        }
                    }
                }
                return result
            }
        }
}

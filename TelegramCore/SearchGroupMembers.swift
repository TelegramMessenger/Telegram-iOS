import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func searchGroupMembers(postbox: Postbox, network: Network, peerId: PeerId, query: String) -> Signal<[Peer], NoError> {
    if peerId.namespace == Namespaces.Peer.CloudChannel && !query.isEmpty {
        return channelMembers(postbox: postbox, network: network, peerId: peerId, filter: .search(query))
            |> map { participants -> [Peer] in
                return participants.map { $0.peer }
            }
    } else {
        return peerParticipants(postbox: postbox, id: peerId)
            |> map { peers -> [Peer] in
                let normalizedQuery = query.lowercased()
                
                return peers.filter { peer in
                    if peer.indexName.matchesByTokens(normalizedQuery) {
                        return true
                    }
                    if let addressName = peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                        return true
                    }
                    return false
                }
            }
    }
}

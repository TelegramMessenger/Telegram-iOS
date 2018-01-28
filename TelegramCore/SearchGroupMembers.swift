import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private func searchLocalGroupMembers(postbox: Postbox, peerId: PeerId, query: String) -> Signal<[Peer], NoError> {
    return peerParticipants(postbox: postbox, id: peerId)
    |> map { peers -> [Peer] in
        let normalizedQuery = query.lowercased()
        
        if normalizedQuery.isEmpty {
            return peers
        }
        
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

public func searchGroupMembers(postbox: Postbox, network: Network, peerId: PeerId, query: String) -> Signal<[Peer], NoError> {
    if peerId.namespace == Namespaces.Peer.CloudChannel && !query.isEmpty {
        return searchLocalGroupMembers(postbox: postbox, peerId: peerId, query: query)
        |> mapToSignal { local -> Signal<[Peer], NoError> in
            return .single(local)
            |> then(channelMembers(postbox: postbox, network: network, peerId: peerId, filter: .search(query))
            |> map { participants -> [Peer] in
                var result: [Peer] = local
                let existingIds = Set(local.map { $0.id })
                let filtered = participants.map({ $0.peer }).filter({ !existingIds.contains($0.id) })
                result.append(contentsOf: filtered)
                return result
            })
        }
    } else {
        return searchLocalGroupMembers(postbox: postbox, peerId: peerId, query: query)
    }
}

import Foundation
import Postbox
import SwiftSignalKit

import SyncCore

private func searchLocalGroupMembers(postbox: Postbox, peerId: PeerId, query: String) -> Signal<[Peer], NoError> {
    return peerParticipants(postbox: postbox, id: peerId)
    |> map { peers -> [Peer] in
        let normalizedQuery = query.lowercased()
        
        if normalizedQuery.isEmpty {
            return peers
        }
        
        return peers.filter { peer in
            if peer.debugDisplayTitle.isEmpty {
                return false
            }
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

public func searchGroupMembers(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, query: String) -> Signal<[Peer], NoError> {
    if peerId.namespace == Namespaces.Peer.CloudChannel && !query.isEmpty {
        return searchLocalGroupMembers(postbox: postbox, peerId: peerId, query: query)
        |> mapToSignal { local -> Signal<[Peer], NoError> in
            let localResult: Signal<[Peer], NoError>
            if local.isEmpty {
                localResult = .complete()
            } else {
                localResult = .single(local)
            }
            return localResult
            |> then(
                channelMembers(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, category: .recent(.search(query)))
                |> map { participants -> [Peer] in
                    var result: [Peer] = local
                    let existingIds = Set(local.map { $0.id })
                    let filtered: [Peer]
                    if let participants = participants {
                        filtered = participants.map({ $0.peer }).filter({ peer in
                            if existingIds.contains(peer.id) {
                                return false
                            }
                            if peer.debugDisplayTitle.isEmpty {
                                return false
                            }
                            return true
                        })
                    } else {
                        filtered = []
                    }
                    result.append(contentsOf: filtered)
                    return result
                }
            )
        }
    } else {
        return searchLocalGroupMembers(postbox: postbox, peerId: peerId, query: query)
    }
}

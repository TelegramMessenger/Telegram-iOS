import Foundation
import Postbox
import SwiftSignalKit

import SyncCore

private struct PeerParticipants: Equatable {
    let peers: [Peer]
    
    static func ==(lhs: PeerParticipants, rhs: PeerParticipants) -> Bool {
        if lhs.peers.count != rhs.peers.count {
            return false
        }
        for i in 0 ..< lhs.peers.count {
            if !lhs.peers[i].isEqual(rhs.peers[i]) {
                return false
            }
        }
        return true
    }
}

public func peerParticipants(postbox: Postbox, id: PeerId) -> Signal<[Peer], NoError> {
    return postbox.peerView(id: id) |> map { view -> PeerParticipants in
        if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
            var peers: [Peer] = []
            for participant in participants.participants {
                if let peer = view.peers[participant.peerId] {
                    peers.append(peer)
                }
            }
            return PeerParticipants(peers: peers)
        } else {
            return PeerParticipants(peers: [])
        }
    }
    |> distinctUntilChanged |> map { participants in
        return participants.peers
    }
}

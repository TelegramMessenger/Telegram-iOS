import Foundation
import Postbox
import SwiftSignalKit

func recentPeers(account: Account) -> Signal<[Peer], NoError> {
    let cachedPeers = account.postbox.recentPeers()
        |> take(1)
    
    let remotePeers = account.network.request(Api.functions.contacts.getTopPeers(flags: 1 << 0, offset: 0, limit: 16, hash: 0))
        |> retryRequest
        |> map { result -> [Peer]? in
            switch result {
                case let .topPeers(_, _, users):
                    var peers: [Peer] = []
                    for user in users {
                        peers.append(TelegramUser.init(user: user))
                    }
                    return peers
                case .topPeersNotModified:
                    break
            }
            return []
        }
    
    let updatedRemotePeers = remotePeers
        |> mapToSignal { peers -> Signal<[Peer], NoError> in
            if let peers = peers {
                return account.postbox.modify { modifier -> [Peer] in
                    modifier.updatePeers(peers, update: { return $1 })
                    modifier.replaceRecentPeerIds(peers.map({ $0.id }))
                    return peers
                }
            } else {
                return .complete()
            }
        }
    return cachedPeers |> then(updatedRemotePeers) |> filter({ !$0.isEmpty })
}

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
                    modifier.updatePeers(peers, update: { return $1 })
                    modifier.updatePeerPresences(peerPresences)
                    modifier.replaceRecentPeerIds(peers.map({ $0.id }))
                    return peers
                }
            } else {
                return .complete()
            }
        }
    return cachedPeers |> then(updatedRemotePeers) |> filter({ !$0.isEmpty })
}

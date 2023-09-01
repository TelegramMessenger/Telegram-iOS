import Postbox
import TelegramApi
import SwiftSignalKit


public func actualizedPeer(accountPeerId: PeerId, postbox: Postbox, network: Network, peer: Peer) -> Signal<Peer, NoError> {
    return postbox.transaction { transaction -> Signal<Peer, NoError> in
        var signal: Signal<Peer, NoError>
        var actualizeChannel: Api.InputChannel?
        if let currentPeer = transaction.getPeer(peer.id) {
            signal = .single(currentPeer)
            if let currentPeer = currentPeer as? TelegramChannel {
                switch currentPeer.participationStatus {
                    case .left, .kicked:
                        actualizeChannel = apiInputChannel(currentPeer)
                    default:
                        break
                }
            }
        } else {
            signal = .single(peer)
            if let peer = peer as? TelegramChannel {
                actualizeChannel = apiInputChannel(peer)
            }
        }
        if let actualizeChannel = actualizeChannel {
            let remote = network.request(Api.functions.channels.getChannels(id: [actualizeChannel]))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Peer, NoError> in
                    return postbox.transaction { transaction -> Signal<Peer, NoError> in
                        var parsedPeers: AccumulatedPeers?
                        if let result = result {
                            let chats: [Api.Chat]
                            switch result {
                            case let .chats(apiChats):
                                chats = apiChats
                            case let .chatsSlice(_, apiChats):
                                chats = apiChats
                            }
                            let parsedPeersValue = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
                            if parsedPeersValue.allIds.contains(peer.id) {
                                parsedPeers = parsedPeersValue
                            }
                        }
                        if let parsedPeers = parsedPeers {
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                            if let peer = transaction.getPeer(peer.id) {
                                return .single(peer)
                            }
                        }
                        return .complete()
                    }
                    |> switchToLatest
                }
            signal = signal |> then(remote)
        }
        
        let updatedView: Signal<Peer, NoError> = postbox.combinedView(keys: [.peer(peerId: peer.id, components: .all)])
            |> mapToSignal { view -> Signal<Peer, NoError> in
                if let peerView = view.views[.peer(peerId: peer.id, components: .all)] as? PeerView, let peer = peerView.peers[peerView.peerId] {
                    return .single(peer)
                }
                return .complete()
            }
        
        return (signal |> then(updatedView)) |> distinctUntilChanged(isEqual: { $0.isEqual($1) })
    } |> switchToLatest
}


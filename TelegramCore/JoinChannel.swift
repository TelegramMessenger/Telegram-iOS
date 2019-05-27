import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func joinChannel(account: Account, peerId: PeerId) -> Signal<RenderedChannelParticipant?, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> take(1)
    |> mapToSignal { peer -> Signal<RenderedChannelParticipant?, NoError> in
        if let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.joinChannel(channel: inputChannel))
            |> retryRequest
            |> mapToSignal { updates -> Signal<RenderedChannelParticipant?, NoError> in
                account.stateManager.addUpdates(updates)
                
                return account.network.request(Api.functions.channels.getParticipant(channel: inputChannel, userId: .inputUserSelf))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.channels.ChannelParticipant?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<RenderedChannelParticipant?, NoError> in
                    guard let result = result else {
                        return .single(nil)
                    }
                    return account.postbox.transaction { transaction -> RenderedChannelParticipant? in
                        var peers: [PeerId: Peer] = [:]
                        var presences: [PeerId: PeerPresence] = [:]
                        guard let peer = transaction.getPeer(account.peerId) else {
                            return nil
                        }
                        peers[account.peerId] = peer
                        if let presence = transaction.getPeerPresence(peerId: account.peerId) {
                            presences[account.peerId] = presence
                        }
                        let updatedParticipant: ChannelParticipant
                        switch result {
                            case let .channelParticipant(participant, _):
                                updatedParticipant = ChannelParticipant(apiParticipant: participant)
                        }
                        if case let .member(_, _, maybeAdminInfo, _) = updatedParticipant {
                            if let adminInfo = maybeAdminInfo {
                                if let peer = transaction.getPeer(adminInfo.promotedBy) {
                                    peers[peer.id] = peer
                                }
                            }
                        }
                        return RenderedChannelParticipant(participant: updatedParticipant, peer: peer, peers: peers, presences: presences)
                    }
                }
                
                return .complete()
            }
        } else {
            return .complete()
        }
    }
}

import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

import SyncCore

public enum JoinChannelError {
    case generic
    case tooMuchJoined
}

public func joinChannel(account: Account, peerId: PeerId) -> Signal<RenderedChannelParticipant?, JoinChannelError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> take(1)
    |> castError(JoinChannelError.self)
    |> mapToSignal { peer -> Signal<RenderedChannelParticipant?, JoinChannelError> in
        if let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.joinChannel(channel: inputChannel))
            |> mapError { error -> JoinChannelError in
                if error.errorDescription == "CHANNELS_TOO_MUCH" {
                    return .tooMuchJoined
                } else {
                    return .generic
                }
            }
            |> mapToSignal { updates -> Signal<RenderedChannelParticipant?, JoinChannelError> in
                account.stateManager.addUpdates(updates)
                
                return account.network.request(Api.functions.channels.getParticipant(channel: inputChannel, userId: .inputUserSelf))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.channels.ChannelParticipant?, JoinChannelError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<RenderedChannelParticipant?, JoinChannelError> in
                    guard let result = result else {
                        return .fail(.generic)
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
                        if case let .member(_, _, maybeAdminInfo, _, _) = updatedParticipant {
                            if let adminInfo = maybeAdminInfo {
                                if let peer = transaction.getPeer(adminInfo.promotedBy) {
                                    peers[peer.id] = peer
                                }
                            }
                        }
                        return RenderedChannelParticipant(participant: updatedParticipant, peer: peer, peers: peers, presences: presences)
                    }
                    |> castError(JoinChannelError.self)
                }
            }
        } else {
            return .fail(.generic)
        }
    }
}

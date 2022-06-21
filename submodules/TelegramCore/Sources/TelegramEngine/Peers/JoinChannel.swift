import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit
import MtProtoKit


public enum JoinChannelError {
    case generic
    case tooMuchJoined
    case tooMuchUsers
    case inviteRequestSent
}

func _internal_joinChannel(account: Account, peerId: PeerId, hash: String?) -> Signal<RenderedChannelParticipant?, JoinChannelError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> take(1)
    |> castError(JoinChannelError.self)
    |> mapToSignal { peer -> Signal<RenderedChannelParticipant?, JoinChannelError> in
        if let inputChannel = apiInputChannel(peer) {
            let request: Signal<Api.Updates, MTRpcError>
            if let hash = hash {
                request = account.network.request(Api.functions.messages.importChatInvite(hash: hash))
            } else {
                request = account.network.request(Api.functions.channels.joinChannel(channel: inputChannel))
            }
            return request
            |> mapError { error -> JoinChannelError in
                switch error.errorDescription {
                    case "CHANNELS_TOO_MUCH":
                        return .tooMuchJoined
                    case "USERS_TOO_MUCH":
                        return .tooMuchUsers
                    case "INVITE_REQUEST_SENT":
                        return .inviteRequestSent
                    default:
                        return .generic
                }
            }
            |> mapToSignal { updates -> Signal<RenderedChannelParticipant?, JoinChannelError> in
                account.stateManager.addUpdates(updates)
                
                return account.network.request(Api.functions.channels.getParticipant(channel: inputChannel, participant: .inputPeerSelf))
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
                            case let .channelParticipant(participant, _, _):
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

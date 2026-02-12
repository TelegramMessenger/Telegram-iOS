import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum UpdateChatRankError {
    case generic
    case changeForbidden
    case chatAdminRequired
    case chatCreatorRequired
    case notParticipant
}

func _internal_updateChatRank(account: Account, peerId: PeerId, userId: PeerId, rank: String?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, UpdateChatRankError> {
    return account.postbox.transaction { transaction -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, UpdateChatRankError> in
        if let user = transaction.getPeer(userId), let inputUser = apiInputPeer(user), let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.editChatParticipantRank(peer: inputPeer, participant: inputUser, rank: rank ?? ""))
            |> mapError { error -> UpdateChatRankError in
                if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                    return .chatAdminRequired
                } else if error.errorDescription == "CHAT_CREATOR_REQUIRED" {
                    return .chatCreatorRequired
                } else if error.errorDescription == "USER_NOT_PARTICIPANT" {
                    return .notParticipant
                } else if error.errorDescription == "RANK_CHANGE_FORBIDDEN" {
                    return .changeForbidden
                } else {
                    return .generic
                }
            }
            |> mapToSignal { updates -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, UpdateChatRankError> in
                account.stateManager.addUpdates(updates)
                
                if peerId.namespace == Namespaces.Peer.CloudGroup {
                    return account.postbox.transaction { transaction -> (ChannelParticipant?, RenderedChannelParticipant)? in
                        transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, current in
                            if let current = current as? CachedGroupData, let participants = current.participants {
                                var updatedParticipants = participants.participants
                                if let index = updatedParticipants.firstIndex(where: { $0.peerId == userId }) {
                                    updatedParticipants[index] = updatedParticipants[index].withUpdated(rank: rank)
                                }
                                return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version + 2))
                            } else {
                                return current
                            }
                        })
                        return nil
                    }
                    |> castError(UpdateChatRankError.self)
                } else {
                    let participant: ChannelParticipant = .member(id: userId, invitedAt: Int32(Date().timeIntervalSince1970), adminInfo: nil, banInfo: nil, rank: rank, subscriptionUntilDate: nil)
                    let timestamp = Int32(Date().timeIntervalSince1970)
                    return .single((participant, RenderedChannelParticipant(participant: participant, peer: user, presences: [userId: TelegramUserPresence(status: .present(until: timestamp + 60), lastActivity: timestamp)])))
                }
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> UpdateChatRankError in }
    |> switchToLatest
}



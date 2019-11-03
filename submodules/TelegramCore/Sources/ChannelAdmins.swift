import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public func channelAdmins(account: Account, peerId: PeerId) -> Signal<[RenderedChannelParticipant], NoError> {
    return account.postbox.transaction { transaction -> Signal<[RenderedChannelParticipant], NoError> in
        if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsAdmins, offset: 0, limit: 100, hash: 0))
                |> retryRequest
                |> mapToSignal { result -> Signal<[RenderedChannelParticipant], NoError> in
                    switch result {
                        case let .channelParticipants(count, participants, users):
                            var items: [RenderedChannelParticipant] = []
                            
                            var peers: [PeerId: Peer] = [:]
                            var presences:[PeerId: PeerPresence] = [:]
                            for user in users {
                                let peer = TelegramUser(user: user)
                                peers[peer.id] = peer
                                if let presence = TelegramUserPresence(apiUser: user) {
                                    presences[peer.id] = presence
                                }
                            }
                            
                            for participant in CachedChannelParticipants(apiParticipants: participants).participants {
                                if let peer = peers[participant.peerId] {
                                    items.append(RenderedChannelParticipant(participant: participant, peer: peer, peers: peers, presences: presences))
                                }
                                
                            }
                        
                            return account.postbox.transaction { transaction -> [RenderedChannelParticipant] in
                                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                    if let cachedData = cachedData as? CachedChannelData {
                                        return cachedData.withUpdatedParticipantsSummary(cachedData.participantsSummary.withUpdatedAdminCount(count))
                                    } else {
                                        return cachedData
                                    }
                                })
                                return items
                            }
                        case .channelParticipantsNotModified:
                            return .single([])
                    }
                }
        } else {
            return .single([])
        }
    } |> switchToLatest
}

public func channelAdminIds(postbox: Postbox, network: Network, peerId: PeerId, hash: Int32) -> Signal<[PeerId], NoError> {
    return postbox.transaction { transaction in
        if let peer = transaction.getPeer(peerId) as? TelegramChannel, case .group = peer.info, let apiChannel = apiInputChannel(peer) {
            let api = Api.functions.channels.getParticipants(channel: apiChannel, filter: .channelParticipantsAdmins, offset: 0, limit: 100, hash: hash)
            return network.request(api) |> retryRequest |> mapToSignal { result in
                switch result {
                case let .channelParticipants(_, participants, users):
                    let users = users.filter({ user in
                        return participants.contains(where: { participant in
                            switch participant {
                            case let .channelParticipantAdmin(_, userId, _, _, _, _, _):
                                return user.peerId.id == userId
                            case let .channelParticipantCreator(_, userId, _):
                                return user.peerId.id == userId
                            default:
                                return false
                            }
                        })
                    })
                    return .single(users.map({TelegramUser(user: $0).id}))
                    default:
                        return .complete()
                }
            }
        }
        return .complete()
    } |> switchToLatest
}

import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public func channelBlacklist(account: Account, peerId: PeerId) -> Signal<[RenderedChannelParticipant], NoError> {
    return account.postbox.modify { modifier -> Signal<[RenderedChannelParticipant], NoError> in
        if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsKicked(q: ""), offset: 0, limit: 100))
                |> retryRequest
                |> map { result -> [RenderedChannelParticipant] in
                    var items: [RenderedChannelParticipant] = []
                    switch result {
                        case let .channelParticipants(_, participants, users):
                            var peers: [PeerId: Peer] = [:]
                            var status:[PeerId: PeerPresence] = [:]
                            for user in users {
                                let peer = TelegramUser(user: user)
                                peers[peer.id] = peer
                                if let presence = TelegramUserPresence(apiUser: user) {
                                    status[peer.id] = presence
                                }
                            }
                            
                            for participant in CachedChannelParticipants(apiParticipants: participants).participants {
                                if let peer = peers[participant.peerId] {
                                    items.append(RenderedChannelParticipant(participant: participant, peer: peer, status: status[peer.id]))
                                }
                                
                            }
                    }
                    return items
            }
        } else {
            return .single([])
        }
    } |> switchToLatest
}

public func removeChannelBlacklistedPeer(account: Account, peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer), let memberPeer = modifier.getPeer(memberId), let inputUser = apiInputUser(memberPeer) {
            return account.network.request(Api.functions.channels.kickFromChannel(channel: inputChannel, userId: inputUser, kicked: .boolFalse))
                |> retryRequest
                |> mapToSignal { result -> Signal<Void, NoError> in
                    account.stateManager.addUpdates(result)
                    return account.postbox.modify { modifier -> Void in
                        modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                            if let cachedData = cachedData as? CachedChannelData, let bannedCount = cachedData.participantsSummary.bannedCount {
                                return cachedData.withUpdatedParticipantsSummary(cachedData.participantsSummary.withUpdatedBannedCount(max(bannedCount - 1, 0)))
                            } else {
                                return cachedData
                            }
                        })
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

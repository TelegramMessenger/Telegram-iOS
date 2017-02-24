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

public func channelMembers(account: Account, peerId: PeerId) -> Signal<[RenderedChannelParticipant], NoError> {
    return account.postbox.modify { modifier -> Signal<[RenderedChannelParticipant], NoError> in
        if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsRecent, offset: 0, limit: 100))
                |> retryRequest
                |> map { result -> [RenderedChannelParticipant] in
                    var items: [RenderedChannelParticipant] = []
                    switch result {
                    case let .channelParticipants(_, participants, users):
                        var peers: [PeerId: Peer] = [:]
                        for user in users {
                            let peer = TelegramUser(user: user)
                            peers[peer.id] = peer
                        }
                        
                        for participant in CachedChannelParticipants(apiParticipants: participants).participants {
                            if let peer = peers[participant.peerId] {
                                items.append(RenderedChannelParticipant(participant: participant, peer: peer))
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

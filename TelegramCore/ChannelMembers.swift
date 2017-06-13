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

public enum ChannelMembersFilter {
    case none
    case search(String)
}

public func channelMembers(account: Account, peerId: PeerId, filter: ChannelMembersFilter = .none) -> Signal<[RenderedChannelParticipant], NoError> {
    return account.postbox.modify { modifier -> Signal<[RenderedChannelParticipant], NoError> in
        if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            let apiFilter: Api.ChannelParticipantsFilter
            switch filter {
                case .none:
                    apiFilter = .channelParticipantsRecent
                case let .search(query):
                    apiFilter = .channelParticipantsSearch(q: query)
            }
            return account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: apiFilter, offset: 0, limit: 100))
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
                                items.append(RenderedChannelParticipant(participant: participant, peer: peer, peers: peers))
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

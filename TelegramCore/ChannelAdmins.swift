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

public struct RenderedChannelParticipant: Equatable {
    public let participant: ChannelParticipant
    public let peer: Peer
    
    public init(participant: ChannelParticipant, peer: Peer) {
        self.participant = participant
        self.peer = peer
    }
    
    public static func ==(lhs: RenderedChannelParticipant, rhs: RenderedChannelParticipant) -> Bool {
        return lhs.participant == rhs.participant && lhs.peer.isEqual(rhs.peer)
    }
}

public func channelAdmins(account: Account, peerId: PeerId) -> Signal<[RenderedChannelParticipant], NoError> {
    return account.postbox.modify { modifier -> Signal<[RenderedChannelParticipant], NoError> in
        if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsAdmins, offset: 0, limit: 100))
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

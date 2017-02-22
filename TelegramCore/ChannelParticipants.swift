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

func updateChannelParticipantsSummary(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            let admins = account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsAdmins, offset: 0, limit: 0))
            let members = account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsRecent, offset: 0, limit: 0))
            let banned = account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsKicked, offset: 0, limit: 0))
            return combineLatest(admins, members, banned)
                |> mapToSignal { admins, members, banned -> Signal<Void, MTRpcError> in
                    return account.postbox.modify { modifier -> Void in
                        modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let current = current as? CachedChannelData {
                                let adminCount: Int32
                                switch admins {
                                    case let .channelParticipants(count, _, _):
                                        adminCount = count
                                }
                                let memberCount: Int32
                                switch members {
                                    case let .channelParticipants(count, _, _):
                                        memberCount = count
                                }
                                let bannedCount: Int32
                                switch banned {
                                    case let .channelParticipants(count, _, _):
                                        bannedCount = count
                                }
                                return current.withUpdatedParticipantsSummary(CachedChannelParticipantsSummary(memberCount: memberCount, adminCount: adminCount, bannedCount: bannedCount))
                            }
                            return current
                        })
                    } |> mapError { _ -> MTRpcError in return MTRpcError(errorCode: 0, errorDescription: "") }
                }
                |> `catch` { _ -> Signal<Void, NoError> in
                    return .complete()
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

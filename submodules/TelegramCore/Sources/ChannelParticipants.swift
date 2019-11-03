import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public struct RenderedChannelParticipant: Equatable {
    public let participant: ChannelParticipant
    public let peer: Peer
    public let peers: [PeerId: Peer]
    public let presences: [PeerId: PeerPresence]
    
    public init(participant: ChannelParticipant, peer: Peer, peers: [PeerId: Peer] = [:], presences: [PeerId: PeerPresence] = [:]) {
        self.participant = participant
        self.peer = peer
        self.peers = peers
        self.presences = presences
    }
    
    public static func ==(lhs: RenderedChannelParticipant, rhs: RenderedChannelParticipant) -> Bool {
        return lhs.participant == rhs.participant && lhs.peer.isEqual(rhs.peer)
    }
}

func updateChannelParticipantsSummary(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            let admins = account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsAdmins, offset: 0, limit: 0, hash: 0))
            let members = account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsRecent, offset: 0, limit: 0, hash: 0))
            let banned = account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsBanned(q: ""), offset: 0, limit: 0, hash: 0))
            let kicked = account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsKicked(q: ""), offset: 0, limit: 0, hash: 0))
            return combineLatest(admins, members, banned, kicked)
            |> mapToSignal { admins, members, banned, kicked -> Signal<Void, MTRpcError> in
                return account.postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        if let current = current as? CachedChannelData {
                            let adminCount: Int32
                            switch admins {
                                case let .channelParticipants(count, _, _):
                                    adminCount = count
                                case .channelParticipantsNotModified:
                                    assertionFailure()
                                    adminCount = 0
                            }
                            let memberCount: Int32
                            switch members {
                                case let .channelParticipants(count, _, _):
                                    memberCount = count
                                case .channelParticipantsNotModified:
                                    assertionFailure()
                                    memberCount = 0
                            }
                            let bannedCount: Int32
                            switch banned {
                                case let .channelParticipants(count, _, _):
                                    bannedCount = count
                                case .channelParticipantsNotModified:
                                    assertionFailure()
                                    bannedCount = 0
                            }
                            let kickedCount: Int32
                            switch kicked {
                                case let .channelParticipants(count, _, _):
                                    kickedCount = count
                                case .channelParticipantsNotModified:
                                    assertionFailure()
                                    kickedCount = 0
                            }
                            return current.withUpdatedParticipantsSummary(CachedChannelParticipantsSummary(memberCount: memberCount, adminCount: adminCount, bannedCount: bannedCount, kickedCount: kickedCount))
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

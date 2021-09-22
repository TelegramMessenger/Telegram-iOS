import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum ChannelMembersCategoryFilter {
    case all
    case search(String)
}

public enum ChannelMembersCategory {
    case recent(ChannelMembersCategoryFilter)
    case admins
    case contacts(ChannelMembersCategoryFilter)
    case bots(ChannelMembersCategoryFilter)
    case restricted(ChannelMembersCategoryFilter)
    case banned(ChannelMembersCategoryFilter)
    case mentions(threadId: MessageId?, filter: ChannelMembersCategoryFilter)
}

func _internal_channelMembers(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, category: ChannelMembersCategory = .recent(.all), offset: Int32 = 0, limit: Int32 = 64, hash: Int64 = 0) -> Signal<[RenderedChannelParticipant]?, NoError> {
    return postbox.transaction { transaction -> Signal<[RenderedChannelParticipant]?, NoError> in
        if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            let apiFilter: Api.ChannelParticipantsFilter
            switch category {
                case let .recent(filter):
                    switch filter {
                        case .all:
                            apiFilter = .channelParticipantsRecent
                        case let .search(query):
                            apiFilter = .channelParticipantsSearch(q: query)
                    }
                case let .mentions(threadId, filter):
                    switch filter {
                        case .all:
                            var flags: Int32 = 0
                            if threadId != nil {
                                flags |= 1 << 1
                            }
                            apiFilter = .channelParticipantsMentions(flags: flags, q: nil, topMsgId: threadId?.id)
                        case let .search(query):
                            var flags: Int32 = 0
                            if threadId != nil {
                                flags |= 1 << 1
                            }
                            if !query.isEmpty {
                                flags |= 1 << 0
                            }
                            apiFilter = .channelParticipantsMentions(flags: flags, q: query.isEmpty ? nil : query, topMsgId: threadId?.id)
                    }
                case .admins:
                    apiFilter = .channelParticipantsAdmins
                case let .contacts(filter):
                    switch filter {
                        case .all:
                            apiFilter = .channelParticipantsContacts(q: "")
                        case let .search(query):
                            apiFilter = .channelParticipantsContacts(q: query)
                    }
                case .bots:
                    apiFilter = .channelParticipantsBots
                case let .restricted(filter):
                    switch filter {
                        case .all:
                            apiFilter = .channelParticipantsBanned(q: "")
                        case let .search(query):
                            apiFilter = .channelParticipantsBanned(q: query)
                    }
                case let .banned(filter):
                    switch filter {
                        case .all:
                            apiFilter = .channelParticipantsKicked(q: "")
                        case let .search(query):
                            apiFilter = .channelParticipantsKicked(q: query)
                    }
            }
            return network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: apiFilter, offset: offset, limit: limit, hash: hash))
                |> retryRequest
                |> mapToSignal { result -> Signal<[RenderedChannelParticipant]?, NoError> in
                    return postbox.transaction { transaction -> [RenderedChannelParticipant]? in
                        var items: [RenderedChannelParticipant] = []
                        switch result {
                            case let .channelParticipants(_, participants, chats, users):
                                var peers: [PeerId: Peer] = [:]
                                var presences: [PeerId: PeerPresence] = [:]
                                for user in users {
                                    let peer = TelegramUser(user: user)
                                    peers[peer.id] = peer
                                    if let presence = TelegramUserPresence(apiUser: user) {
                                        presences[peer.id] = presence
                                    }
                                }
                                for chat in chats {
                                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                        peers[groupOrChannel.id] = groupOrChannel
                                    }
                                }
                                updatePeers(transaction: transaction, peers: Array(peers.values), update: { _, updated in
                                    return updated
                                })
                                updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: presences)
                                
                                for participant in CachedChannelParticipants(apiParticipants: participants).participants {
                                    if let peer = peers[participant.peerId] {
                                        items.append(RenderedChannelParticipant(participant: participant, peer: peer, peers: peers, presences: presences))
                                    }
                                }
                            case .channelParticipantsNotModified:
                                return nil
                        }
                        return items
                    }
            }
        } else {
            return .single([])
        }
    } |> switchToLatest
}

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

private enum ChannelBlacklistFilter {
    case restricted
    case banned
}

private func fetchChannelBlacklist(account: Account, peerId: PeerId, filter: ChannelBlacklistFilter) -> Signal<[RenderedChannelParticipant], NoError> {
    return account.postbox.transaction { transaction -> Signal<[RenderedChannelParticipant], NoError> in
        if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            let apiFilter: Api.ChannelParticipantsFilter
            switch filter {
                case .restricted:
                    apiFilter = .channelParticipantsBanned(q: "")
                case .banned:
                    apiFilter = .channelParticipantsKicked(q: "")
            }
            return account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: apiFilter, offset: 0, limit: 100, hash: 0))
                |> retryRequest
                |> map { result -> [RenderedChannelParticipant] in
                    var items: [RenderedChannelParticipant] = []
                    switch result {
                        case let .channelParticipants(_, participants, users):
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
                        case .channelParticipantsNotModified:
                            assertionFailure()
                            break
                    }
                    return items
            }
        } else {
            return .single([])
        }
    } |> switchToLatest
}

public struct ChannelBlacklist {
    public let banned: [RenderedChannelParticipant]
    public let restricted: [RenderedChannelParticipant]
    
    public init(banned: [RenderedChannelParticipant], restricted: [RenderedChannelParticipant]) {
        self.banned = banned
        self.restricted = restricted
    }
    
    public var isEmpty: Bool {
        return banned.isEmpty && restricted.isEmpty
    }
    
    public func withRemovedPeerId(_ memberId:PeerId) -> ChannelBlacklist {
        var updatedRestricted = restricted
        var updatedBanned = banned

        for i in 0 ..< updatedBanned.count {
            if updatedBanned[i].peer.id == memberId {
                updatedBanned.remove(at: i)
                break
            }
        }
        for i in 0 ..< updatedRestricted.count {
            if updatedRestricted[i].peer.id == memberId {
                updatedRestricted.remove(at: i)
                break
            }
        }
        return ChannelBlacklist(banned: updatedBanned, restricted: updatedRestricted)
    }
    
    public func withRemovedParticipant(_ participant:RenderedChannelParticipant) -> ChannelBlacklist {
        let updated = self.withRemovedPeerId(participant.participant.peerId)
        var updatedRestricted = updated.restricted
        var updatedBanned = updated.banned
        
        if case .member(_, _, _, let maybeBanInfo) = participant.participant, let banInfo = maybeBanInfo {
            if banInfo.rights.flags.contains(.banReadMessages) {
                updatedBanned.insert(participant, at: 0)
            } else {
                if !banInfo.rights.flags.isEmpty {
                    updatedRestricted.insert(participant, at: 0)
                }
            }
        }
    
        
        return ChannelBlacklist(banned: updatedBanned, restricted: updatedRestricted)
    }
}

public func channelBlacklistParticipants(account: Account, peerId: PeerId) -> Signal<ChannelBlacklist, NoError> {
    return combineLatest(fetchChannelBlacklist(account: account, peerId: peerId, filter: .restricted), fetchChannelBlacklist(account: account, peerId: peerId, filter: .banned))
        |> map { restricted, banned in
            var r: [RenderedChannelParticipant] = []
            var b: [RenderedChannelParticipant] = []
            var peerIds = Set<PeerId>()
            for participant in restricted {
                if !peerIds.contains(participant.peer.id) {
                    peerIds.insert(participant.peer.id)
                    r.append(participant)
                }
            }
            for participant in banned {
                if !peerIds.contains(participant.peer.id) {
                    peerIds.insert(participant.peer.id)
                    b.append(participant)
                }
            }
            return ChannelBlacklist(banned: b, restricted: r)
        }
}

public func updateChannelMemberBannedRights(account: Account, peerId: PeerId, memberId: PeerId, rights: TelegramChannelBannedRights?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant), NoError> {
    return fetchChannelParticipant(account: account, peerId: peerId, participantId: memberId)
    |> mapToSignal { currentParticipant -> Signal<(ChannelParticipant?, RenderedChannelParticipant), NoError> in
        return account.postbox.transaction { transaction -> Signal<(ChannelParticipant?, RenderedChannelParticipant), NoError> in
            if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer), let _ = transaction.getPeer(account.peerId), let memberPeer = transaction.getPeer(memberId), let inputUser = apiInputUser(memberPeer) {
                let updatedParticipant: ChannelParticipant
                if let currentParticipant = currentParticipant, case let .member(_, invitedAt, _, currentBanInfo) = currentParticipant {
                    let banInfo: ChannelParticipantBannedInfo?
                    if let rights = rights, !rights.flags.isEmpty {
                        banInfo = ChannelParticipantBannedInfo(rights: rights, restrictedBy: currentBanInfo?.restrictedBy ?? account.peerId, isMember: currentBanInfo?.isMember ?? true)
                    } else {
                        banInfo = nil
                    }
                    updatedParticipant = ChannelParticipant.member(id: memberId, invitedAt: invitedAt, adminInfo: nil, banInfo: banInfo)
                } else {
                    let banInfo: ChannelParticipantBannedInfo?
                    if let rights = rights, !rights.flags.isEmpty {
                        banInfo = ChannelParticipantBannedInfo(rights: rights, restrictedBy: account.peerId, isMember: false)
                    } else {
                        banInfo = nil
                    }
                    updatedParticipant = ChannelParticipant.member(id: memberId, invitedAt: Int32(Date().timeIntervalSince1970), adminInfo: nil, banInfo: banInfo)
                }
                
                let effectiveRights: TelegramChannelBannedRights = rights ?? TelegramChannelBannedRights(flags: [], untilDate: 0)
                
                return account.network.request(Api.functions.channels.editBanned(channel: inputChannel, userId: inputUser, bannedRights: effectiveRights.apiBannedRights))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<(ChannelParticipant?, RenderedChannelParticipant), NoError> in
                        account.stateManager.addUpdates(result)
                        
                        return account.postbox.transaction { transaction -> (ChannelParticipant?, RenderedChannelParticipant) in
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                if let cachedData = cachedData as? CachedChannelData {
                                    var updatedData = cachedData
                                    var wasKicked = false
                                    var wasBanned = false
                                    var wasMember = false
                                    var wasAdmin = false
                                    if let currentParticipant = currentParticipant {
                                        switch currentParticipant {
                                            case .creator:
                                                break
                                            case let .member(_, _, adminInfo, banInfo):
                                                if let adminInfo = adminInfo {
                                                    wasAdmin = true
                                                }
                                                if let banInfo = banInfo {
                                                    if banInfo.rights.flags.contains(.banReadMessages) {
                                                        wasKicked = true
                                                    } else if !banInfo.rights.flags.isEmpty {
                                                        wasBanned = true
                                                    }
                                                }
                                                wasMember = true
                                        }
                                    }
                                    
                                    
                                    var isKicked = false
                                    var isBanned = false
                                    if effectiveRights.flags.contains(.banReadMessages) {
                                        isKicked = true
                                    } else if !effectiveRights.flags.isEmpty {
                                        isBanned = true
                                    }
                                    
                                    let isMember = !wasKicked && !effectiveRights.flags.contains(.banReadMessages)
                                    
                                    if isKicked != wasKicked {
                                        if let kickedCount = updatedData.participantsSummary.kickedCount {
                                            updatedData = updatedData.withUpdatedParticipantsSummary(updatedData.participantsSummary.withUpdatedKickedCount(max(0, kickedCount + (isKicked ? 1 : -1))))
                                        }
                                    }
                                    
                                    if isBanned != wasBanned {
                                        if let bannedCount = updatedData.participantsSummary.bannedCount {
                                            updatedData = updatedData.withUpdatedParticipantsSummary(updatedData.participantsSummary.withUpdatedBannedCount(max(0, bannedCount + (isBanned ? 1 : -1))))
                                        }
                                    }
                                    
                                    if wasAdmin {
                                        if let adminCount = updatedData.participantsSummary.adminCount {
                                            updatedData = updatedData.withUpdatedParticipantsSummary(updatedData.participantsSummary.withUpdatedAdminCount(max(0, adminCount - 1)))
                                        }
                                    }
                                    
                                    if isMember != wasMember {
                                        if let memberCount = updatedData.participantsSummary.memberCount {
                                            updatedData = updatedData.withUpdatedParticipantsSummary(updatedData.participantsSummary.withUpdatedMemberCount(max(0, memberCount + (isMember ? 1 : -1))))
                                        }
                                        
                                        if !isMember, let topParticipants = updatedData.topParticipants {
                                            var updatedParticipants = topParticipants.participants
                                            if let index = updatedParticipants.index(where: { $0.peerId == memberId }) {
                                                updatedParticipants.remove(at: index)
                                                
                                                updatedData = updatedData.withUpdatedTopParticipants(CachedChannelParticipants(participants: updatedParticipants))
                                            }
                                        }
                                    }
                                    
                                    return updatedData
                                } else {
                                    return cachedData
                                }
                            })
                            var peers: [PeerId: Peer] = [:]
                            var presences: [PeerId: PeerPresence] = [:]
                            peers[memberPeer.id] = memberPeer
                            if let presence = transaction.getPeerPresence(peerId: memberPeer.id) {
                                presences[memberPeer.id] = presence
                            }
                            if case let .member(_, _, _, maybeBanInfo) = updatedParticipant, let banInfo = maybeBanInfo {
                                if let peer = transaction.getPeer(banInfo.restrictedBy) {
                                    peers[peer.id] = peer
                                }
                            }
                            return (currentParticipant, RenderedChannelParticipant(participant: updatedParticipant, peer: memberPeer, peers: peers, presences: presences))
                        }
                    }
            } else {
                return .complete()
            }
        }
        |> switchToLatest
    }
}

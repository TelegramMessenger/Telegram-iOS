import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

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
        
        if case let .member(_, _, _, maybeBanInfo, _) = participant.participant, let banInfo = maybeBanInfo {
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

public func updateChannelMemberBannedRights(account: Account, peerId: PeerId, memberId: PeerId, rights: TelegramChatBannedRights?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> {
    return fetchChannelParticipant(account: account, peerId: peerId, participantId: memberId)
    |> mapToSignal { currentParticipant -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> in
        return account.postbox.transaction { transaction -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> in
            if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer), let _ = transaction.getPeer(account.peerId), let memberPeer = transaction.getPeer(memberId), let inputUser = apiInputUser(memberPeer) {
                let updatedParticipant: ChannelParticipant
                if let currentParticipant = currentParticipant, case let .member(_, invitedAt, _, currentBanInfo, _) = currentParticipant {
                    let banInfo: ChannelParticipantBannedInfo?
                    if let rights = rights, !rights.flags.isEmpty {
                        banInfo = ChannelParticipantBannedInfo(rights: rights, restrictedBy: currentBanInfo?.restrictedBy ?? account.peerId, timestamp: currentBanInfo?.timestamp ?? Int32(Date().timeIntervalSince1970), isMember: currentBanInfo?.isMember ?? true)
                    } else {
                        banInfo = nil
                    }
                    updatedParticipant = ChannelParticipant.member(id: memberId, invitedAt: invitedAt, adminInfo: nil, banInfo: banInfo, rank: nil)
                } else {
                    let banInfo: ChannelParticipantBannedInfo?
                    if let rights = rights, !rights.flags.isEmpty {
                        banInfo = ChannelParticipantBannedInfo(rights: rights, restrictedBy: account.peerId, timestamp: Int32(Date().timeIntervalSince1970), isMember: false)
                    } else {
                        banInfo = nil
                    }
                    updatedParticipant = ChannelParticipant.member(id: memberId, invitedAt: Int32(Date().timeIntervalSince1970), adminInfo: nil, banInfo: banInfo, rank: nil)
                }
                
                return account.network.request(Api.functions.channels.editBanned(channel: inputChannel, userId: inputUser, bannedRights: rights?.apiBannedRights ?? Api.ChatBannedRights.chatBannedRights(flags: 0, untilDate: 0)))
                |> retryRequest
                |> mapToSignal { result -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> in
                    account.stateManager.addUpdates(result)
                    
                    var wasKicked = false
                    var wasBanned = false
                    var wasMember = false
                    var wasAdmin = false
                    if let currentParticipant = currentParticipant {
                        switch currentParticipant {
                            case .creator:
                                break
                            case let .member(_, _, adminInfo, banInfo, _):
                                if let _ = adminInfo {
                                    wasAdmin = true
                                }
                                if let banInfo = banInfo, !banInfo.rights.flags.isEmpty {
                                    if banInfo.rights.flags.contains(.banReadMessages) {
                                        wasKicked = true
                                    } else {
                                        wasBanned = true
                                        wasMember = true
                                    }
                                } else {
                                    wasMember = true
                                }
                        }
                    }
                    
                    var isKicked = false
                    var isBanned = false
                    if let rights = rights, !rights.flags.isEmpty {
                        if rights.flags.contains(.banReadMessages) {
                            isKicked = true
                        } else {
                            isBanned = true
                        }
                    }
                    
                    let isMember = !wasKicked && !isKicked
                    
                    return account.postbox.transaction { transaction -> (ChannelParticipant?, RenderedChannelParticipant?, Bool) in
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                            if let cachedData = cachedData as? CachedChannelData {
                                var updatedData = cachedData
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
                        if case let .member(_, _, _, maybeBanInfo, _) = updatedParticipant, let banInfo = maybeBanInfo {
                            if let peer = transaction.getPeer(banInfo.restrictedBy) {
                                peers[peer.id] = peer
                            }
                        }
                        
                        return (currentParticipant, RenderedChannelParticipant(participant: updatedParticipant, peer: memberPeer, peers: peers, presences: presences), isMember)
                    }
                }
            } else {
                return .complete()
            }
        }
        |> switchToLatest
    }
}

public func updateDefaultChannelMemberBannedRights(account: Account, peerId: PeerId, rights: TelegramChatBannedRights) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Never, NoError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer), let _ = transaction.getPeer(account.peerId) else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.editChatDefaultBannedRights(peer: inputPeer, bannedRights: rights.apiBannedRights))
        |> retryRequest
        |> mapToSignal { result -> Signal<Never, NoError> in
            account.stateManager.addUpdates(result)
            return account.postbox.transaction { transaction -> Void in
                guard let peer = transaction.getPeer(peerId) else {
                    return
                }
                if let peer = peer as? TelegramGroup {
                    updatePeers(transaction: transaction, peers: [peer.updateDefaultBannedRights(rights, version: peer.version)], update: { _, updated in
                        return updated
                    })
                } else if let peer = peer as? TelegramChannel {
                    updatePeers(transaction: transaction, peers: [peer.withUpdatedDefaultBannedRights(rights)], update: { _, updated in
                        return updated
                    })
                }
            }
            |> ignoreValues
        }
    }
    |> switchToLatest
}


import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_updateChannelMemberBannedRights(account: Account, peerId: PeerId, memberId: PeerId, rights: TelegramChatBannedRights?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> {
    return _internal_fetchChannelParticipant(account: account, peerId: peerId, participantId: memberId)
    |> mapToSignal { currentParticipant -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> in
        return account.postbox.transaction { transaction -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> in
            if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer), let _ = transaction.getPeer(account.peerId), let memberPeer = transaction.getPeer(memberId), let inputPeer = apiInputPeer(memberPeer) {
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

                let apiRights: Api.ChatBannedRights
                if let rights = rights, !rights.flags.isEmpty {
                    apiRights = rights.apiBannedRights
                } else {
                    apiRights = .chatBannedRights(flags: 0, untilDate: 0)
                }
                
                return account.network.request(Api.functions.channels.editBanned(channel: inputChannel, participant: inputPeer, bannedRights: apiRights))
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
                                
                                if let memberPeer = memberPeer as? TelegramUser, let _ = memberPeer.botInfo {
                                    if isMember != wasMember {
                                        if isMember {
//                                            var updatedBotInfos = updatedData.botInfos
//                                            if updatedBotInfos.firstIndex(where: { $0.peerId == memberPeer.id }) == nil {
//                                                updatedBotInfos.append(CachedPeerBotInfo(peerId: memberPeer.id, botInfo: ))
//                                            }
//                                            updatedData = updatedData.withUpdatedBotInfos(updatedBotInfos)
                                        } else {
                                            let filteredBotInfos = updatedData.botInfos.filter { $0.peerId != memberPeer.id }
                                            updatedData = updatedData.withUpdatedBotInfos(filteredBotInfos)
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

func _internal_updateDefaultChannelMemberBannedRights(account: Account, peerId: PeerId, rights: TelegramChatBannedRights) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Never, NoError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer), let _ = transaction.getPeer(account.peerId) else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.editChatDefaultBannedRights(peer: inputPeer, bannedRights: rights.apiBannedRights))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result = result else {
                return .complete()
            }
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


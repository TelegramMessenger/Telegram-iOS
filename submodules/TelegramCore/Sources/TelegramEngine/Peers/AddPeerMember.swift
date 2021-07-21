import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum AddGroupMemberError {
    case generic
    case groupFull
    case privacy
    case notMutualContact
    case tooManyChannels
}

func _internal_addGroupMember(account: Account, peerId: PeerId, memberId: PeerId) -> Signal<Void, AddGroupMemberError> {
    return account.postbox.transaction { transaction -> Signal<Void, AddGroupMemberError> in
        if let peer = transaction.getPeer(peerId), let memberPeer = transaction.getPeer(memberId), let inputUser = apiInputUser(memberPeer) {
            if let group = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.addChatUser(chatId: group.id.id._internalGetInt64Value(), userId: inputUser, fwdLimit: 100))
                |> mapError { error -> AddGroupMemberError in
                    switch error.errorDescription {
                    case "USERS_TOO_MUCH":
                        return .groupFull
                    case "USER_PRIVACY_RESTRICTED":
                        return .privacy
                    case "USER_CHANNELS_TOO_MUCH":
                        return .tooManyChannels
                    case "USER_NOT_MUTUAL_CONTACT":
                        return .notMutualContact
                    default:
                        return .generic
                    }
                }
                |> mapToSignal { result -> Signal<Void, AddGroupMemberError> in
                    account.stateManager.addUpdates(result)
                    return account.postbox.transaction { transaction -> Void in
                        if let message = result.messages.first, let timestamp = message.timestamp {
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                if let cachedData = cachedData as? CachedGroupData, let participants = cachedData.participants {
                                    var updatedParticipants = participants.participants
                                    var found = false
                                    for participant in participants.participants {
                                        if participant.peerId == memberId {
                                            found = true
                                            break
                                        }
                                    }
                                    if !found {
                                        updatedParticipants.append(.member(id: memberId, invitedBy: account.peerId, invitedAt: timestamp))
                                    }
                                    return cachedData.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
                                } else {
                                    return cachedData
                                }
                            })
                        }
                    }
                    |> mapError { _ -> AddGroupMemberError in }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> AddGroupMemberError in } |> switchToLatest
}

public enum AddChannelMemberError {
    case generic
    case restricted
    case notMutualContact
    case limitExceeded
    case tooMuchJoined
    case bot(PeerId)
    case botDoesntSupportGroups
    case tooMuchBots
}

func _internal_addChannelMember(account: Account, peerId: PeerId, memberId: PeerId) -> Signal<(ChannelParticipant?, RenderedChannelParticipant), AddChannelMemberError> {
    return _internal_fetchChannelParticipant(account: account, peerId: peerId, participantId: memberId)
    |> mapError { error -> AddChannelMemberError in
    }
    |> mapToSignal { currentParticipant -> Signal<(ChannelParticipant?, RenderedChannelParticipant), AddChannelMemberError> in
        return account.postbox.transaction { transaction -> Signal<(ChannelParticipant?, RenderedChannelParticipant), AddChannelMemberError> in
            if let peer = transaction.getPeer(peerId), let memberPeer = transaction.getPeer(memberId), let inputUser = apiInputUser(memberPeer) {
                if let channel = peer as? TelegramChannel, let inputChannel = apiInputChannel(channel) {
                    let updatedParticipant: ChannelParticipant
                    if let currentParticipant = currentParticipant, case let .member(_, invitedAt, adminInfo, _, rank) = currentParticipant {
                        updatedParticipant = ChannelParticipant.member(id: memberId, invitedAt: invitedAt, adminInfo: adminInfo, banInfo: nil, rank: rank)
                    } else {
                        updatedParticipant = ChannelParticipant.member(id: memberId, invitedAt: Int32(Date().timeIntervalSince1970), adminInfo: nil, banInfo: nil, rank: nil)
                    }
                    return account.network.request(Api.functions.channels.inviteToChannel(channel: inputChannel, users: [inputUser]))
                    |> map { [$0] }
                    |> `catch` { error -> Signal<[Api.Updates], AddChannelMemberError> in
                        switch error.errorDescription {
                            case "USER_CHANNELS_TOO_MUCH":
                                return .fail(.tooMuchJoined)
                            case "USERS_TOO_MUCH":
                                return .fail(.limitExceeded)
                            case "USER_PRIVACY_RESTRICTED":
                                return .fail(.restricted)
                            case "USER_NOT_MUTUAL_CONTACT":
                                return .fail(.notMutualContact)
                            case "USER_BOT":
                                return .fail(.bot(memberId))
                            case "BOT_GROUPS_BLOCKED":
                                return .fail(.botDoesntSupportGroups)
                            case "BOTS_TOO_MUCH":
                                return .fail(.tooMuchBots)
                            default:
                                return .fail(.generic)
                        }
                    }
                    |> mapToSignal { result -> Signal<(ChannelParticipant?, RenderedChannelParticipant), AddChannelMemberError> in
                        for updates in result {
                            account.stateManager.addUpdates(updates)
                        }
                        return account.postbox.transaction { transaction -> (ChannelParticipant?, RenderedChannelParticipant) in
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                if let cachedData = cachedData as? CachedChannelData, let memberCount = cachedData.participantsSummary.memberCount, let kickedCount = cachedData.participantsSummary.kickedCount {
                                    var updatedMemberCount = memberCount
                                    var updatedKickedCount = kickedCount
                                    var wasMember = false
                                    var wasBanned = false
                                    if let currentParticipant = currentParticipant {
                                        switch currentParticipant {
                                            case .creator:
                                                break
                                            case let .member(_, _, _, banInfo, _):
                                                if let banInfo = banInfo {
                                                    wasBanned = true
                                                    wasMember = !banInfo.rights.flags.contains(.banReadMessages)
                                                } else {
                                                    wasMember = true
                                                }
                                        }
                                    }
                                    if !wasMember {
                                        updatedMemberCount = updatedMemberCount + 1
                                    }
                                    if wasBanned {
                                        updatedKickedCount = max(0, updatedKickedCount - 1)
                                    }
                                    
                                    return cachedData.withUpdatedParticipantsSummary(cachedData.participantsSummary.withUpdatedMemberCount(updatedMemberCount).withUpdatedKickedCount(updatedKickedCount))
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
                            if case let .member(_, _, maybeAdminInfo, _, _) = updatedParticipant {
                                if let adminInfo = maybeAdminInfo {
                                    if let peer = transaction.getPeer(adminInfo.promotedBy) {
                                        peers[peer.id] = peer
                                    }
                                }
                            }
                            return (currentParticipant, RenderedChannelParticipant(participant: updatedParticipant, peer: memberPeer, peers: peers, presences: presences))
                        }
                        |> mapError { _ -> AddChannelMemberError in }
                    }
                } else {
                    return .fail(.generic)
                }
            } else {
                return .fail(.generic)
            }
        }
        |> mapError { _ -> AddChannelMemberError in }
        |> switchToLatest
    }
}

func _internal_addChannelMembers(account: Account, peerId: PeerId, memberIds: [PeerId]) -> Signal<Void, AddChannelMemberError> {
    let signal = account.postbox.transaction { transaction -> Signal<Void, AddChannelMemberError> in
        var memberPeerIds: [PeerId:Peer] = [:]
        var inputUsers: [Api.InputUser] = []
        for memberId in memberIds {
            if let peer = transaction.getPeer(memberId) {
                memberPeerIds[peerId] = peer
                if let inputUser = apiInputUser(peer) {
                    inputUsers.append(inputUser)
                }
            }
        }
        
        if let peer = transaction.getPeer(peerId), let channel = peer as? TelegramChannel, let inputChannel = apiInputChannel(channel) {
            let signal = account.network.request(Api.functions.channels.inviteToChannel(channel: inputChannel, users: inputUsers))
            |> mapError { error -> AddChannelMemberError in
                switch error.errorDescription {
                   case "CHANNELS_TOO_MUCH":
                        return .tooMuchJoined
                    case "USER_PRIVACY_RESTRICTED":
                        return .restricted
                    case "USER_NOT_MUTUAL_CONTACT":
                        return .notMutualContact
                    case "USERS_TOO_MUCH":
                        return .limitExceeded
                    default:
                        return .generic
                }
            }
            |> map { result in
                account.stateManager.addUpdates(result)
                account.viewTracker.forceUpdateCachedPeerData(peerId: peerId)
            }

            return signal
        } else {
            return .single(Void())
        }
        
    }
    |> castError(AddChannelMemberError.self)
    
    return signal
    |> switchToLatest
}

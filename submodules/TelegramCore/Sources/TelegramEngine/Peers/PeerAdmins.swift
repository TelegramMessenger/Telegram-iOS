import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum RemoveGroupAdminError {
    case generic
}

func _internal_removeGroupAdmin(account: Account, peerId: PeerId, adminId: PeerId) -> Signal<Void, RemoveGroupAdminError> {
    return account.postbox.transaction { transaction -> Signal<Void, RemoveGroupAdminError> in
        if let peer = transaction.getPeer(peerId), let adminPeer = transaction.getPeer(adminId), let inputUser = apiInputUser(adminPeer) {
            if let group = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.editChatAdmin(chatId: group.id.id._internalGetInt64Value(), userId: inputUser, isAdmin: .boolFalse))
                    |> mapError { _ -> RemoveGroupAdminError in return .generic }
                    |> mapToSignal { result -> Signal<Void, RemoveGroupAdminError> in
                        return account.postbox.transaction { transaction -> Void in
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                if let current = current as? CachedGroupData, let participants = current.participants {
                                    var updatedParticipants = participants.participants
                                    if case .boolTrue = result {
                                        for i in 0 ..< updatedParticipants.count {
                                            if updatedParticipants[i].peerId == adminId {
                                                switch updatedParticipants[i] {
                                                    case let .admin(id, invitedBy, invitedAt):
                                                        updatedParticipants[i] = .member(id: id, invitedBy: invitedBy, invitedAt: invitedAt)
                                                    default:
                                                        break
                                                }
                                                break
                                            }
                                        }
                                    }
                                    return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
                                } else {
                                    return current
                                }
                            })
                        } |> mapError { _ -> RemoveGroupAdminError in }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> RemoveGroupAdminError in }
    |> switchToLatest
}

public enum AddGroupAdminError {
    case generic
    case addMemberError(AddGroupMemberError)
    case adminsTooMuch
}

func _internal_addGroupAdmin(account: Account, peerId: PeerId, adminId: PeerId) -> Signal<Void, AddGroupAdminError> {
    return account.postbox.transaction { transaction -> Signal<Void, AddGroupAdminError> in
        if let peer = transaction.getPeer(peerId), let adminPeer = transaction.getPeer(adminId), let inputUser = apiInputUser(adminPeer) {
            if let group = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.editChatAdmin(chatId: group.id.id._internalGetInt64Value(), userId: inputUser, isAdmin: .boolTrue))
                |> `catch` { error -> Signal<Api.Bool, AddGroupAdminError> in
                    if error.errorDescription == "USER_NOT_PARTICIPANT" {
                        return _internal_addGroupMember(account: account, peerId: peerId, memberId: adminId)
                        |> mapError { error -> AddGroupAdminError in
                            return .addMemberError(error)
                        }
                        |> mapToSignal { _ -> Signal<Api.Bool, AddGroupAdminError> in
                            return .complete()
                        }
                        |> then(
                            account.network.request(Api.functions.messages.editChatAdmin(chatId: group.id.id._internalGetInt64Value(), userId: inputUser, isAdmin: .boolTrue))
                            |> mapError { error -> AddGroupAdminError in
                                return .generic
                            }
                        )
                    } else if error.errorDescription == "USER_PRIVACY_RESTRICTED" {
                        return .fail(.addMemberError(.privacy))
                    } else if error.errorDescription == "ADMINS_TOO_MUCH" {
                        return .fail(.adminsTooMuch)
                    }
                    return .fail(.generic)
                }
                |> mapToSignal { result -> Signal<Void, AddGroupAdminError> in
                    return account.postbox.transaction { transaction -> Void in
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let current = current as? CachedGroupData, let participants = current.participants {
                                var updatedParticipants = participants.participants
                                if case .boolTrue = result {
                                    for i in 0 ..< updatedParticipants.count {
                                        if updatedParticipants[i].peerId == adminId {
                                            switch updatedParticipants[i] {
                                                case let .member(id, invitedBy, invitedAt):
                                                    updatedParticipants[i] = .admin(id: id, invitedBy: invitedBy, invitedAt: invitedAt)
                                                default:
                                                    break
                                            }
                                            break
                                        }
                                    }
                                }
                                return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
                            } else {
                                return current
                            }
                        })
                    } |> mapError { _ -> AddGroupAdminError in }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> AddGroupAdminError in }
    |> switchToLatest
}

public enum UpdateChannelAdminRightsError {
    case generic
    case addMemberError(AddChannelMemberError)
    case adminsTooMuch
}

func _internal_fetchChannelParticipant(account: Account, peerId: PeerId, participantId: PeerId) -> Signal<ChannelParticipant?, NoError> {
    return account.postbox.transaction { transaction -> Signal<ChannelParticipant?, NoError> in
        if let peer = transaction.getPeer(peerId), let adminPeer = transaction.getPeer(participantId), let inputPeer = apiInputPeer(adminPeer) {
            if let channel = peer as? TelegramChannel, let inputChannel = apiInputChannel(channel) {
                return account.network.request(Api.functions.channels.getParticipant(channel: inputChannel, participant: inputPeer))
                |> map { result -> ChannelParticipant? in
                    switch result {
                        case let .channelParticipant(participant, _, _):
                            return ChannelParticipant(apiParticipant: participant)
                    }
                }
                |> `catch` { _ -> Signal<ChannelParticipant?, NoError> in
                    return .single(nil)
                }
            } else {
                return .single(nil)
            }
        } else {
            return .single(nil)
        }
    } |> switchToLatest
}

func _internal_updateChannelAdminRights(account: Account, peerId: PeerId, adminId: PeerId, rights: TelegramChatAdminRights?, rank: String?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant), UpdateChannelAdminRightsError> {
    return _internal_fetchChannelParticipant(account: account, peerId: peerId, participantId: adminId)
    |> mapError { error -> UpdateChannelAdminRightsError in
    }
    |> mapToSignal { currentParticipant -> Signal<(ChannelParticipant?, RenderedChannelParticipant), UpdateChannelAdminRightsError> in
        return account.postbox.transaction { transaction -> Signal<(ChannelParticipant?, RenderedChannelParticipant), UpdateChannelAdminRightsError> in
            if let peer = transaction.getPeer(peerId), let adminPeer = transaction.getPeer(adminId), let inputUser = apiInputUser(adminPeer) {
                if let channel = peer as? TelegramChannel, let inputChannel = apiInputChannel(channel) {
                    let updatedParticipant: ChannelParticipant
                    if let currentParticipant = currentParticipant, case let .member(_, invitedAt, currentAdminInfo, _, _) = currentParticipant {
                        let adminInfo: ChannelParticipantAdminInfo?
                        if let rights = rights {
                            adminInfo = ChannelParticipantAdminInfo(rights: rights, promotedBy: currentAdminInfo?.promotedBy ?? account.peerId, canBeEditedByAccountPeer: true)
                        } else {
                            adminInfo = nil
                        }
                        updatedParticipant = .member(id: adminId, invitedAt: invitedAt, adminInfo: adminInfo, banInfo: nil, rank: rank)
                    } else if let currentParticipant = currentParticipant, case .creator = currentParticipant {
                        let adminInfo: ChannelParticipantAdminInfo?
                        if let rights = rights {
                            adminInfo = ChannelParticipantAdminInfo(rights: rights, promotedBy: account.peerId, canBeEditedByAccountPeer: true)
                        } else {
                            adminInfo = nil
                        }
                        updatedParticipant = .creator(id: adminId, adminInfo: adminInfo, rank: rank)
                    } else {
                        let adminInfo: ChannelParticipantAdminInfo?
                        if let rights = rights {
                            adminInfo = ChannelParticipantAdminInfo(rights: rights, promotedBy: account.peerId, canBeEditedByAccountPeer: true)
                        } else {
                            adminInfo = nil
                        }
                        updatedParticipant = .member(id: adminId, invitedAt: Int32(Date().timeIntervalSince1970), adminInfo: adminInfo, banInfo: nil, rank: rank)
                    }
                    return account.network.request(Api.functions.channels.editAdmin(channel: inputChannel, userId: inputUser, adminRights: rights?.apiAdminRights ?? .chatAdminRights(flags: 0), rank: rank ?? ""))
                    |> map { [$0] }
                    |> `catch` { error -> Signal<[Api.Updates], UpdateChannelAdminRightsError> in
                        if error.errorDescription == "USER_NOT_PARTICIPANT" {
                            return _internal_addChannelMember(account: account, peerId: peerId, memberId: adminId)
                            |> map { _ -> [Api.Updates] in
                                return []
                            }
                            |> mapError { error -> UpdateChannelAdminRightsError in
                                return .addMemberError(error)
                            }
                            |> then(
                                account.network.request(Api.functions.channels.editAdmin(channel: inputChannel, userId: inputUser, adminRights: rights?.apiAdminRights ?? .chatAdminRights(flags: 0), rank: rank ?? ""))
                                |> mapError { error -> UpdateChannelAdminRightsError in
                                    return .generic
                                }
                                |> map { [$0] }
                            )
                        } else if error.errorDescription == "USER_NOT_MUTUAL_CONTACT" {
                            return .fail(.addMemberError(.notMutualContact))
                        } else if error.errorDescription == "USER_PRIVACY_RESTRICTED" {
                            return .fail(.addMemberError(.restricted))
                        } else if error.errorDescription == "USER_CHANNELS_TOO_MUCH" {
                            return .fail(.addMemberError(.tooMuchJoined))
                        } else if error.errorDescription == "ADMINS_TOO_MUCH" {
                            return .fail(.adminsTooMuch)
                        }
                        return .fail(.generic)
                    }
                    |> mapToSignal { result -> Signal<(ChannelParticipant?, RenderedChannelParticipant), UpdateChannelAdminRightsError> in
                        for updates in result {
                            account.stateManager.addUpdates(updates)
                        }
                        return account.postbox.transaction { transaction -> (ChannelParticipant?, RenderedChannelParticipant) in
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                if let cachedData = cachedData as? CachedChannelData, let adminCount = cachedData.participantsSummary.adminCount {
                                    var updatedAdminCount = adminCount
                                    var wasAdmin = false
                                    if let currentParticipant = currentParticipant {
                                        switch currentParticipant {
                                            case .creator:
                                                wasAdmin = true
                                            case let .member(_, _, adminInfo, _, _):
                                                if let _ = adminInfo {
                                                    wasAdmin = true
                                                }
                                        }
                                    }
                                    if wasAdmin && rights == nil {
                                        updatedAdminCount = max(1, adminCount - 1)
                                    } else if !wasAdmin && rights != nil {
                                        updatedAdminCount = adminCount + 1
                                    }
                                    
                                    return cachedData.withUpdatedParticipantsSummary(cachedData.participantsSummary.withUpdatedAdminCount(updatedAdminCount))
                                } else {
                                    return cachedData
                                }
                            })
                            var peers: [PeerId: Peer] = [:]
                            var presences: [PeerId: PeerPresence] = [:]
                            peers[adminPeer.id] = adminPeer
                            if let presence = transaction.getPeerPresence(peerId: adminPeer.id) {
                                presences[adminPeer.id] = presence
                            }
                            if case let .member(_, _, maybeAdminInfo, _, _) = updatedParticipant, let adminInfo = maybeAdminInfo {
                                if let peer = transaction.getPeer(adminInfo.promotedBy) {
                                    peers[peer.id] = peer
                                }
                            }
                            return (currentParticipant, RenderedChannelParticipant(participant: updatedParticipant, peer: adminPeer, peers: peers, presences: presences))
                        } |> mapError { _ -> UpdateChannelAdminRightsError in }
                    }
                } else {
                    return .fail(.generic)
                }
            } else {
                return .fail(.generic)
            }
        }
        |> mapError { _ -> UpdateChannelAdminRightsError in }
        |> switchToLatest
    }
}

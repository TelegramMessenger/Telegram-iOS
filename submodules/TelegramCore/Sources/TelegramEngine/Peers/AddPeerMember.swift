import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum AddGroupMemberError {
    case generic
    case groupFull
    case privacy(TelegramInvitePeersResult?)
    case notMutualContact
    case tooManyChannels
}

public final class TelegramForbiddenInvitePeer: Equatable {
    public let peer: EnginePeer
    public let canInviteWithPremium: Bool
    public let premiumRequiredToContact: Bool
    
    public init(peer: EnginePeer, canInviteWithPremium: Bool, premiumRequiredToContact: Bool) {
        self.peer = peer
        self.canInviteWithPremium = canInviteWithPremium
        self.premiumRequiredToContact = premiumRequiredToContact
    }
    
    public static func ==(lhs: TelegramForbiddenInvitePeer, rhs: TelegramForbiddenInvitePeer) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.canInviteWithPremium != rhs.canInviteWithPremium {
            return false
        }
        if lhs.premiumRequiredToContact != rhs.premiumRequiredToContact {
            return false
        }
        return true
    }
}

public final class TelegramInvitePeersResult {
    public let forbiddenPeers: [TelegramForbiddenInvitePeer]
    
    public init(forbiddenPeers: [TelegramForbiddenInvitePeer]) {
        self.forbiddenPeers = forbiddenPeers
    }
}

func _internal_addGroupMember(account: Account, peerId: PeerId, memberId: PeerId) -> Signal<Void, AddGroupMemberError> {
    return account.postbox.transaction { transaction -> Signal<Void, AddGroupMemberError> in
        if let peer = transaction.getPeer(peerId), let memberPeer = transaction.getPeer(memberId), let inputUser = apiInputUser(memberPeer) {
            if let group = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.addChatUser(chatId: group.id.id._internalGetInt64Value(), userId: inputUser, fwdLimit: 100))
                |> `catch` { error -> Signal<Api.messages.InvitedUsers, AddGroupMemberError> in
                    switch error.errorDescription {
                    case "USERS_TOO_MUCH":
                        return .fail(.groupFull)
                    case "USER_PRIVACY_RESTRICTED":
                        return .fail(.privacy(nil))
                    case "USER_CHANNELS_TOO_MUCH":
                        return .fail(.tooManyChannels)
                    case "USER_NOT_MUTUAL_CONTACT":
                        return .fail(.privacy(nil))
                    default:
                        return .fail(.generic)
                    }
                }
                |> mapToSignal { result -> Signal<Void, AddGroupMemberError> in
                    let updatesValue: Api.Updates
                    let missingInviteesValue: [Api.MissingInvitee]
                    switch result {
                    case let .invitedUsers(invitedUsersData):
                        let (updates, missingInvitees) = (invitedUsersData.updates, invitedUsersData.missingInvitees)
                        updatesValue = updates
                        missingInviteesValue = missingInvitees
                    }
                    
                    account.stateManager.addUpdates(updatesValue)
                    
                    return account.postbox.transaction { transaction -> TelegramInvitePeersResult in
                        if let message = updatesValue.messages.first, let timestamp = message.timestamp {
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
                                        updatedParticipants.append(.member(id: memberId, invitedBy: account.peerId, invitedAt: timestamp, rank: nil))
                                    }
                                    return cachedData.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
                                } else {
                                    return cachedData
                                }
                            })
                        }
                                                
                        let result = TelegramInvitePeersResult(forbiddenPeers: missingInviteesValue.compactMap { invitee -> TelegramForbiddenInvitePeer? in
                            switch invitee {
                            case let .missingInvitee(missingInviteeData):
                                let (flags, userId) = (missingInviteeData.flags, missingInviteeData.userId)
                                guard let peer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))) else {
                                    return nil
                                }
                                return TelegramForbiddenInvitePeer(
                                    peer: EnginePeer(peer),
                                    canInviteWithPremium: (flags & (1 << 0)) != 0,
                                    premiumRequiredToContact: (flags & (1 << 1)) != 0
                                )
                            }
                        })
                        
                        let _ = _internal_updateIsPremiumRequiredToContact(account: account, peerIds: result.forbiddenPeers.map { $0.peer.id }).startStandalone()
                        
                        return result
                    }
                    |> mapError { _ -> AddGroupMemberError in }
                    |> mapToSignal { result -> Signal<Void, AddGroupMemberError> in
                        if result.forbiddenPeers.isEmpty {
                            return .single(Void())
                        } else {
                            return .fail(.privacy(result))
                        }
                    }
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
    case restricted(TelegramForbiddenInvitePeer?)
    case notMutualContact
    case limitExceeded
    case tooMuchJoined
    case bot(PeerId)
    case botDoesntSupportGroups
    case tooMuchBots
    case kicked
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
                    if let currentParticipant = currentParticipant, case let .member(_, invitedAt, adminInfo, _, rank, subscriptionUntilDate) = currentParticipant {
                        updatedParticipant = ChannelParticipant.member(id: memberId, invitedAt: invitedAt, adminInfo: adminInfo, banInfo: nil, rank: rank, subscriptionUntilDate: subscriptionUntilDate)
                    } else {
                        updatedParticipant = ChannelParticipant.member(id: memberId, invitedAt: Int32(Date().timeIntervalSince1970), adminInfo: nil, banInfo: nil, rank: nil, subscriptionUntilDate: nil)
                    }
                    return account.network.request(Api.functions.channels.inviteToChannel(channel: inputChannel, users: [inputUser]))
                    |> `catch` { error -> Signal<Api.messages.InvitedUsers, AddChannelMemberError> in
                        switch error.errorDescription {
                            case "USER_CHANNELS_TOO_MUCH":
                                return .fail(.tooMuchJoined)
                            case "USERS_TOO_MUCH":
                                return .fail(.limitExceeded)
                            case "USER_PRIVACY_RESTRICTED":
                                return .fail(.restricted(nil))
                            case "USER_NOT_MUTUAL_CONTACT":
                                return .fail(.notMutualContact)
                            case "USER_BOT":
                                return .fail(.bot(memberId))
                            case "BOT_GROUPS_BLOCKED":
                                return .fail(.botDoesntSupportGroups)
                            case "BOTS_TOO_MUCH":
                                return .fail(.tooMuchBots)
                            case "USER_KICKED":
                                return .fail(.kicked)
                            default:
                                return .fail(.generic)
                        }
                    }
                    |> mapToSignal { result -> Signal<(ChannelParticipant?, RenderedChannelParticipant), AddChannelMemberError> in
                        let updatesValue: Api.Updates
                        switch result {
                        case let .invitedUsers(invitedUsersData):
                            let (updates, missingInvitees) = (invitedUsersData.updates, invitedUsersData.missingInvitees)
                            if case let .missingInvitee(missingInviteeData) = missingInvitees.first {
                                let flags = missingInviteeData.flags
                                let _ = _internal_updateIsPremiumRequiredToContact(account: account, peerIds: [memberPeer.id]).startStandalone()

                                return .fail(.restricted(TelegramForbiddenInvitePeer(
                                    peer: EnginePeer(memberPeer),
                                    canInviteWithPremium: (flags & (1 << 0)) != 0,
                                    premiumRequiredToContact: (flags & (1 << 1)) != 0
                                )))
                            }

                            updatesValue = updates
                        }
                        
                        account.stateManager.addUpdates(updatesValue)
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
                                            case let .member(_, _, _, banInfo, _, _):
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
                            if case let .member(_, _, maybeAdminInfo, _, _, _) = updatedParticipant {
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

func _internal_addChannelMembers(account: Account, peerId: PeerId, memberIds: [PeerId]) -> Signal<TelegramInvitePeersResult, AddChannelMemberError> {
    let signal = account.postbox.transaction { transaction -> Signal<TelegramInvitePeersResult, AddChannelMemberError> in
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
            let signal: Signal<TelegramInvitePeersResult, AddChannelMemberError> = account.network.request(Api.functions.channels.inviteToChannel(channel: inputChannel, users: inputUsers))
            |> mapError { error -> AddChannelMemberError in
                switch error.errorDescription {
                   case "CHANNELS_TOO_MUCH":
                        return .tooMuchJoined
                    case "USER_PRIVACY_RESTRICTED":
                        return .restricted(nil)
                    case "USER_NOT_MUTUAL_CONTACT":
                        return .notMutualContact
                    case "USERS_TOO_MUCH":
                        return .limitExceeded
                    case "USER_KICKED":
                        return .kicked
                    default:
                        return .generic
                }
            }
            |> mapToQueue { result -> Signal<TelegramInvitePeersResult, AddChannelMemberError> in
                let updatesValue: Api.Updates
                let missingInviteesValue: [Api.MissingInvitee]
                switch result {
                case let .invitedUsers(invitedUsersData):
                    let (updates, missingInvitees) = (invitedUsersData.updates, invitedUsersData.missingInvitees)
                    updatesValue = updates
                    missingInviteesValue = missingInvitees
                }
                
                account.stateManager.addUpdates(updatesValue)
                account.viewTracker.forceUpdateCachedPeerData(peerId: peerId)
                
                return account.postbox.transaction { transaction -> TelegramInvitePeersResult in
                    let result = TelegramInvitePeersResult(forbiddenPeers: missingInviteesValue.compactMap { invitee -> TelegramForbiddenInvitePeer? in
                        switch invitee {
                        case let .missingInvitee(missingInviteeData):
                            let (flags, userId) = (missingInviteeData.flags, missingInviteeData.userId)
                            guard let peer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))) else {
                                return nil
                            }
                            return TelegramForbiddenInvitePeer(
                                peer: EnginePeer(peer),
                                canInviteWithPremium: (flags & (1 << 0)) != 0,
                                premiumRequiredToContact: (flags & (1 << 1)) != 0
                            )
                        }
                    })
                    let _ = _internal_updateIsPremiumRequiredToContact(account: account, peerIds: result.forbiddenPeers.map { $0.peer.id }).startStandalone()
                    return result
                }
                |> castError(AddChannelMemberError.self)
            }

            return signal
        } else {
            return .fail(.generic)
        }
        
    }
    |> castError(AddChannelMemberError.self)
    
    return signal
    |> switchToLatest
}


public enum SendBotRequestedPeerError {
    case generic
}

func _internal_sendBotRequestedPeer(account: Account, peerId: PeerId, messageId: MessageId?, requestId: String?, buttonId: Int32, requestedPeerIds: [PeerId]) -> Signal<Void, SendBotRequestedPeerError> {
    return account.postbox.transaction { transaction -> Signal<Void, SendBotRequestedPeerError> in
        if let peer = transaction.getPeer(peerId) {
            var inputRequestedPeers: [Api.InputPeer] = []
            for requestedPeerId in requestedPeerIds {
                if let requestedPeer = transaction.getPeer(requestedPeerId), let inputRequestedPeer = apiInputPeer(requestedPeer) {
                    inputRequestedPeers.append(inputRequestedPeer)
                }
            }
            if let inputPeer = apiInputPeer(peer), !inputRequestedPeers.isEmpty {
                var flags: Int32 = 0
                var msgId: Int32?
                if let messageId = messageId {
                    flags |= (1 << 0)
                    msgId = messageId.id
                }
                if let _ = requestId {
                    flags |= (1 << 1)
                }
                let signal = account.network.request(Api.functions.messages.sendBotRequestedPeer(flags: flags, peer: inputPeer, msgId: msgId, webappReqId: requestId, buttonId: buttonId, requestedPeers: inputRequestedPeers))
                |> mapError { error -> SendBotRequestedPeerError in
                    return .generic
                }
                |> map { result in
                    account.stateManager.addUpdates(result)
                }
                return signal
            }
        }
        return .single(Void())
    }
    |> castError(SendBotRequestedPeerError.self)
    |> switchToLatest
}

public enum CreateBotError {
    case generic
    case occupied
    case limitExceeded
}

func _internal_createBot(account: Account, name: String, username: String, managerPeerId: PeerId, viaDeeplink: Bool) -> Signal<EnginePeer, CreateBotError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        if let peer = transaction.getPeer(managerPeerId) {
            return apiInputUser(peer)
        }
        return nil
    }
    |> castError(CreateBotError.self)
    |> mapToSignal { inputUser -> Signal<EnginePeer, CreateBotError> in
        guard let inputUser = inputUser else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        if viaDeeplink {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.bots.createBot(flags: flags, name: name, username: username, managerId: inputUser))
        |> mapError { error -> CreateBotError in
            if error.errorDescription == "USERNAME_OCCUPIED" {
                return .occupied
            } else if error.errorDescription == "BOT_CREATE_LIMIT_EXCEEDED" {
                return .limitExceeded
            } else {
                return .generic
            }
        }
        |> mapToSignal { apiUser -> Signal<EnginePeer, CreateBotError> in
            return account.postbox.transaction { transaction -> EnginePeer in
                let user = TelegramUser(user: apiUser)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(transaction: transaction, chats: [], users: [apiUser]))
                return EnginePeer(user)
            }
            |> castError(CreateBotError.self)
        }
    }
}

public enum GetRequestedWebViewButtonError {
    case generic
}

func _internal_getRequestedWebViewButton(account: Account, botId: PeerId, requestId: String) -> Signal<ReplyMarkupButton, GetRequestedWebViewButtonError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        if let peer = transaction.getPeer(botId) {
            return apiInputUser(peer)
        }
        return nil
    }
    |> castError(GetRequestedWebViewButtonError.self)
    |> mapToSignal { inputUser -> Signal<ReplyMarkupButton, GetRequestedWebViewButtonError> in
        guard let inputUser = inputUser else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.bots.getRequestedWebViewButton(bot: inputUser, webappReqId: requestId))
        |> mapError { _ -> GetRequestedWebViewButtonError in
            return .generic
        }
        |> map { apiButton -> ReplyMarkupButton in
            return ReplyMarkupButton(apiButton: apiButton)
        }
    }
}

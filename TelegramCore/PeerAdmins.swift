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

public enum GroupManagementType {
    case restrictedToAdmins
    case unrestricted
}

public func updateGroupManagementType(account: Account, peerId: PeerId, type: GroupManagementType) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId) {
            if let channel = peer as? TelegramChannel, let inputChannel = apiInputChannel(channel) {
                return account.network.request(Api.functions.channels.toggleInvites(channel: inputChannel, enabled: type == .unrestricted ? .boolTrue : .boolFalse))
                    |> map { Optional($0) }
                    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        if let result = result {
                            account.stateManager.addUpdates(result)
                        }
                        return .complete()
                    }
            } else if let group = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.toggleChatAdmins(chatId: group.id.id, enabled: type == .restrictedToAdmins ? .boolTrue : .boolFalse))
                    |> map { Optional($0) }
                    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        if let result = result {
                            account.stateManager.addUpdates(result)
                        }
                        return .complete()
                    }
            } else {
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public enum RemovePeerAdminError {
    case generic
}

public func removePeerAdmin(account: Account, peerId: PeerId, adminId: PeerId) -> Signal<Void, RemovePeerAdminError> {
    return account.postbox.modify { modifier -> Signal<Void, RemovePeerAdminError> in
        if let peer = modifier.getPeer(peerId), let adminPeer = modifier.getPeer(adminId), let inputUser = apiInputUser(adminPeer) {
            if let channel = peer as? TelegramChannel, let inputChannel = apiInputChannel(channel) {
                return account.network.request(Api.functions.channels.editAdmin(channel: inputChannel, userId: inputUser, role: .channelRoleEmpty))
                    |> mapError { _ -> RemovePeerAdminError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, RemovePeerAdminError> in
                        account.stateManager.addUpdates(result)
                        return account.postbox.modify { moifier -> Void in
                            modifier.updatePeerCachedData(peerIds: [peerId], update: { _, current in
                                if let current = current as? CachedChannelData, let adminCount = current.participantsSummary.adminCount {
                                    return current.withUpdatedParticipantsSummary(current.participantsSummary.withUpdatedAdminCount(max(1, adminCount - 1)))
                                } else {
                                    return current
                                }
                            })
                        } |> mapError { _ -> RemovePeerAdminError in return .generic }
                    }
            } else if let group = peer as? TelegramGroup {
                return .fail(.generic)
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> RemovePeerAdminError in return .generic } |> switchToLatest
}

public enum AddPeerAdminError {
    case generic
    case addMemberError(AddPeerMemberError)
}

public func addPeerAdmin(account: Account, peerId: PeerId, adminId: PeerId) -> Signal<Void, AddPeerAdminError> {
    return account.postbox.modify { modifier -> Signal<Void, AddPeerAdminError> in
        if let peer = modifier.getPeer(peerId), let adminPeer = modifier.getPeer(adminId), let inputUser = apiInputUser(adminPeer) {
            if let channel = peer as? TelegramChannel, let inputChannel = apiInputChannel(channel) {
                return account.network.request(Api.functions.channels.editAdmin(channel: inputChannel, userId: inputUser, role: .channelRoleModerator))
                    |> map { [$0] }
                    |> `catch` { error -> Signal<[Api.Updates], AddPeerAdminError> in
                        if error.errorDescription == "USER_NOT_PARTICIPANT" {
                            return addPeerMember(account: account, peerId: peerId, memberId: adminId)
                                |> map { _ -> [Api.Updates] in
                                    return []
                                }
                                |> mapError { error -> AddPeerAdminError in
                                    return .addMemberError(error)
                                }
                                |> then(account.network.request(Api.functions.channels.editAdmin(channel: inputChannel, userId: inputUser, role: .channelRoleModerator))
                                    |> mapError { error -> AddPeerAdminError in
                                        return .generic
                                    }
                                    |> map { [$0] })
                        }
                        return .fail(.generic)
                    }
                    |> mapToSignal { result -> Signal<Void, AddPeerAdminError> in
                        for updates in result {
                            account.stateManager.addUpdates(updates)
                        }
                        return account.postbox.modify { modifier -> Void in
                            modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                if let cachedData = cachedData as? CachedChannelData {
                                    var updatedAdminCount: Int32?
                                    if let adminCount = cachedData.participantsSummary.adminCount {
                                        updatedAdminCount = adminCount + 1
                                    }
                                    return cachedData.withUpdatedParticipantsSummary(cachedData.participantsSummary.withUpdatedAdminCount(updatedAdminCount))
                                } else {
                                    return cachedData
                                }
                            })
                        } |> mapError { _ -> AddPeerAdminError in return .generic }
                    }
            } else if let group = peer as? TelegramGroup {
                return .fail(.generic)
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
        } |> mapError { _ -> AddPeerAdminError in return .generic } |> switchToLatest
}



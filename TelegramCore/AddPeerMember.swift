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

public enum AddPeerMemberError {
    case generic
}

public func addPeerMember(account: Account, peerId: PeerId, memberId: PeerId) -> Signal<Void, AddPeerMemberError> {
    return account.postbox.modify { modifier -> Signal<Void, AddPeerMemberError> in
        if let peer = modifier.getPeer(peerId), let memberPeer = modifier.getPeer(memberId), let inputUser = apiInputUser(memberPeer) {
            if let group = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.addChatUser(chatId: group.id.id, userId: inputUser, fwdLimit: 100))
                    |> mapError { error -> AddPeerMemberError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, AddPeerMemberError> in
                        account.stateManager.addUpdates(result)
                        return account.postbox.modify { modifier -> Void in
                            if let message = result.messages.first, let timestamp = message.timestamp {
                                modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
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
                                        return CachedGroupData(participants: CachedGroupParticipants(participants: updatedParticipants, version: participants.version), exportedInvitation: cachedData.exportedInvitation, botInfos: cachedData.botInfos)
                                    } else {
                                        return cachedData
                                    }
                                })
                            }
                        } |> mapError { _ -> AddPeerMemberError in return .generic }
                    }
            } else if let channel = peer as? TelegramChannel, let inputChannel = apiInputChannel(channel) {
                return account.network.request(Api.functions.channels.inviteToChannel(channel: inputChannel, users: [inputUser]))
                    |> mapError { error -> AddPeerMemberError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, AddPeerMemberError> in
                        account.stateManager.addUpdates(result)
                        return account.postbox.modify { modifier -> Void in
                            modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                if let cachedData = cachedData as? CachedChannelData, let participants = cachedData.topParticipants {
                                    var updatedParticipants = participants.participants
                                    var found = false
                                    for participant in participants.participants {
                                        if participant.peerId == memberId {
                                            found = true
                                            break
                                        }
                                    }
                                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                    if !found {
                                        updatedParticipants.insert(.member(id: memberId, invitedAt: timestamp), at: 0)
                                    }
                                    return cachedData.withUpdatedTopParticipants(CachedChannelParticipants(participants: updatedParticipants))
                                } else {
                                    return cachedData
                                }
                            })
                        } |> mapError { _ -> AddPeerMemberError in return .generic }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> AddPeerMemberError in return .generic } |> switchToLatest
}

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

public func removePeerMember(account: Account, peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId), let memberPeer = modifier.getPeer(memberId), let inputUser = apiInputUser(memberPeer) {
            if let group = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.deleteChatUser(chatId: group.id.id, userId: inputUser))
                    |> mapError { error -> Void in
                        return Void()
                    }
                    |> `catch` { _ -> Signal<Api.Updates, NoError> in
                        return .complete()
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        account.stateManager.addUpdates(result)
                        
                        return account.postbox.modify { modifier -> Void in
                            modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                if let cachedData = cachedData as? CachedGroupData, let participants = cachedData.participants {
                                    var updatedParticipants = participants.participants
                                    for i in 0 ..< participants.participants.count {
                                        if participants.participants[i].peerId == memberId {
                                            updatedParticipants.remove(at: i)
                                            break
                                        }
                                    }
                                    return CachedGroupData(participants: CachedGroupParticipants(participants: updatedParticipants, version: participants.version), exportedInvitation: cachedData.exportedInvitation, botInfos: cachedData.botInfos)
                                } else {
                                    return cachedData
                                }
                            })
                        }
                }
            } else if let channel = peer as? TelegramChannel, let inputChannel = apiInputChannel(channel) {
                return account.network.request(Api.functions.channels.kickFromChannel(channel: inputChannel, userId: inputUser, kicked: .boolTrue))
                    |> mapError { error -> Void in
                        return Void()
                    }
                    |> `catch` { _ -> Signal<Api.Updates, NoError> in
                        return .complete()
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        account.stateManager.addUpdates(result)
                        
                        return account.postbox.modify { modifier -> Void in
                            modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                                if let cachedData = cachedData as? CachedChannelData, let participants = cachedData.topParticipants {
                                    var updatedParticipants = participants.participants
                                    for i in 0 ..< participants.participants.count {
                                        if participants.participants[i].peerId == memberId {
                                            updatedParticipants.remove(at: i)
                                            break
                                        }
                                    }
                                    return cachedData.withUpdatedTopParticipants(CachedChannelParticipants(participants: updatedParticipants))
                                } else {
                                    return cachedData
                                }
                            })
                        }
                    }
            } else {
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Peers and their cached data: users, basic groups and their participants, channels, secret chats.
extension UpdateInterpreter {
    mutating func applyChannel(_ updateChannelData: Api.Update.Cons_updateChannel) {
        updatedState.addExternallyUpdatedPeerId(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateChannelData.channelId)))
    }
    
    mutating func applyChat(_ updateChatData: Api.Update.Cons_updateChat) {
        updatedState.addExternallyUpdatedPeerId(PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(updateChatData.chatId)))
    }
    
    mutating func applyChatParticipants(_ updateChatParticipantsData: Api.Update.Cons_updateChatParticipants) {
        let groupPeerId: PeerId
        switch updateChatParticipantsData.participants {
            case let .chatParticipants(chatParticipantsData):
                let chatId = chatParticipantsData.chatId
                groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
            case let .chatParticipantsForbidden(chatParticipantsForbiddenData):
                let chatId = chatParticipantsForbiddenData.chatId
                groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
        }
        updatedState.updateCachedPeerData(groupPeerId, { current in
            let previous: CachedGroupData
            if let current = current as? CachedGroupData {
                previous = current
            } else {
                previous = CachedGroupData()
            }
            return previous.withUpdatedParticipants(CachedGroupParticipants(apiParticipants: updateChatParticipantsData.participants))
        })
    }
    
    mutating func applyChatParticipantAdd(_ updateChatParticipantAddData: Api.Update.Cons_updateChatParticipantAdd) {
        let (chatId, userId, inviterId, date) = (updateChatParticipantAddData.chatId, updateChatParticipantAddData.userId, updateChatParticipantAddData.inviterId, updateChatParticipantAddData.date)
        let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
        let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
        let inviterPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId))
        updatedState.updateCachedPeerData(groupPeerId, { current in
            if let current = current as? CachedGroupData, let participants = current.participants {
                var updatedParticipants = participants.participants
                if updatedParticipants.firstIndex(where: { $0.peerId == userPeerId }) == nil {
                    updatedParticipants.append(.member(id: userPeerId, invitedBy: inviterPeerId, invitedAt: date, rank: nil))
                }
                return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
            } else {
                return current
            }
        })
    }
    
    mutating func applyChatParticipantDelete(_ updateChatParticipantDeleteData: Api.Update.Cons_updateChatParticipantDelete) {
        let (chatId, userId) = (updateChatParticipantDeleteData.chatId, updateChatParticipantDeleteData.userId)
        let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
        let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
        updatedState.updateCachedPeerData(groupPeerId, { current in
            if let current = current as? CachedGroupData, let participants = current.participants {
                var updatedParticipants = participants.participants
                if let index = updatedParticipants.firstIndex(where: { $0.peerId == userPeerId }) {
                    updatedParticipants.remove(at: index)
                }
                return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
            } else {
                return current
            }
        })
    }
    
    mutating func applyChatParticipantAdmin(_ updateChatParticipantAdminData: Api.Update.Cons_updateChatParticipantAdmin) {
        let (chatId, userId, isAdmin) = (updateChatParticipantAdminData.chatId, updateChatParticipantAdminData.userId, updateChatParticipantAdminData.isAdmin)
        let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
        let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
        updatedState.updateCachedPeerData(groupPeerId, { current in
            if let current = current as? CachedGroupData, let participants = current.participants {
                var updatedParticipants = participants.participants
                if let index = updatedParticipants.firstIndex(where: { $0.peerId == userPeerId }) {
                    if isAdmin == .boolTrue {
                        if case let .member(id, invitedBy, invitedAt, rank) = updatedParticipants[index] {
                            updatedParticipants[index] = .admin(id: id, invitedBy: invitedBy, invitedAt: invitedAt, rank: rank)
                        }
                    } else {
                        if case let .admin(id, invitedBy, invitedAt, rank) = updatedParticipants[index] {
                            updatedParticipants[index] = .member(id: id, invitedBy: invitedBy, invitedAt: invitedAt, rank: rank)
                        }
                    }
                }
                return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
            } else {
                return current
            }
        })
    }
    
    mutating func applyChatParticipantRank(_ updateChatParticipantRankData: Api.Update.Cons_updateChatParticipantRank) {
        let (chatId, userId, rank) = (updateChatParticipantRankData.chatId, updateChatParticipantRankData.userId, updateChatParticipantRankData.rank)
        let groupPeerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
        let userPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
        updatedState.updateCachedPeerData(groupPeerId, { current in
            if let current = current as? CachedGroupData, let participants = current.participants {
                var updatedParticipants = participants.participants
                if let index = updatedParticipants.firstIndex(where: { $0.peerId == userPeerId }) {
                    updatedParticipants[index] = updatedParticipants[index].withUpdated(rank: rank)
                }
                return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version))
            } else {
                return current
            }
        })
    }
    
    mutating func applyChatDefaultBannedRights(_ updateChatDefaultBannedRightsData: Api.Update.Cons_updateChatDefaultBannedRights) {
        let (peer, defaultBannedRights, version) = (updateChatDefaultBannedRightsData.peer, updateChatDefaultBannedRightsData.defaultBannedRights, updateChatDefaultBannedRightsData.version)
        updatedState.updatePeer(peer.peerId, { peer in
            if let group = peer as? TelegramGroup {//, group.version == version - 1 {
                return group.updateDefaultBannedRights(TelegramChatBannedRights(apiBannedRights: defaultBannedRights), version: max(group.version, Int(version)))
            } else if let channel = peer as? TelegramChannel {//, group.version == version - 1 {
                return channel.withUpdatedDefaultBannedRights(TelegramChatBannedRights(apiBannedRights: defaultBannedRights))
            } else if let community = peer as? TelegramCommunity {
                return community.withUpdatedDefaultBannedRights(TelegramChatBannedRights(apiBannedRights: defaultBannedRights))
            } else {
                return peer
            }
        })
    }
    
    mutating func applyPeerBlocked(_ updatePeerBlockedData: Api.Update.Cons_updatePeerBlocked) {
        let userPeerId = updatePeerBlockedData.peerId.peerId
        updatedState.updateCachedPeerData(userPeerId, { current in
            let previous: CachedUserData
            if let current = current as? CachedUserData {
                previous = current
            } else {
                previous = CachedUserData()
            }
            var userFlags = previous.flags
            if (updatePeerBlockedData.flags & (1 << 1)) != 0 {
                userFlags.insert(.isBlockedFromStories)
            } else {
                userFlags.remove(.isBlockedFromStories)
            }
            return previous.withUpdatedIsBlocked((updatePeerBlockedData.flags & (1 << 0)) != 0).withUpdatedFlags(userFlags)
        })
    }
    
    mutating func applyUserStatus(_ updateUserStatusData: Api.Update.Cons_updateUserStatus) {
        updatedState.mergePeerPresences([PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(updateUserStatusData.userId)): updateUserStatusData.status], explicit: true)
    }
    
    mutating func applyUserName(_ updateUserNameData: Api.Update.Cons_updateUserName) {
        let (userId, usernames) = (updateUserNameData.userId, updateUserNameData.usernames)
        //TODO add contact checking for apply first and last name
        updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), { peer in
            if let user = peer as? TelegramUser {
                return user.withUpdatedUsernames(usernames.map { TelegramPeerUsername(apiUsername: $0) })
            } else {
                return peer
            }
        })
    }
    
    mutating func applyUserPhone(_ updateUserPhoneData: Api.Update.Cons_updateUserPhone) {
        updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(updateUserPhoneData.userId)), { peer in
            if let user = peer as? TelegramUser {
                return user.withUpdatedPhone(updateUserPhoneData.phone.isEmpty ? nil : updateUserPhoneData.phone)
            } else {
                return peer
            }
        })
    }
    
    mutating func applyUserEmojiStatus(_ updateUserEmojiStatusData: Api.Update.Cons_updateUserEmojiStatus) {
        updatedState.updatePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(updateUserEmojiStatusData.userId)), { peer in
            if let user = peer as? TelegramUser {
                return user.withUpdatedEmojiStatus(PeerEmojiStatus(apiStatus: updateUserEmojiStatusData.emojiStatus))
            } else {
                return peer
            }
        })
    }
    
    mutating func applyPeerSettings(_ updatePeerSettingsData: Api.Update.Cons_updatePeerSettings) {
        let (peer, settings) = (updatePeerSettingsData.peer, updatePeerSettingsData.settings)
        let peerStatusSettings = PeerStatusSettings(apiSettings: settings)
        updatedState.updateCachedPeerData(peer.peerId, { current in
            if peer.peerId.namespace == Namespaces.Peer.CloudUser {
                let previous: CachedUserData
                if let current = current as? CachedUserData {
                    previous = current
                } else {
                    previous = CachedUserData()
                }
                return previous.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else if peer.peerId.namespace == Namespaces.Peer.CloudGroup {
                let previous: CachedGroupData
                if let current = current as? CachedGroupData {
                    previous = current
                } else {
                    previous = CachedGroupData()
                }
                return previous.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else if peer.peerId.namespace == Namespaces.Peer.CloudChannel {
                let previous: CachedChannelData
                if let current = current as? CachedChannelData {
                    previous = current
                } else {
                    previous = CachedChannelData()
                }
                return previous.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else {
                return current
            }
        })
    }
    
    mutating func applyEncryption(_ updateEncryptionData: Api.Update.Cons_updateEncryption) {
        updatedState.updateSecretChat(chat: updateEncryptionData.chat, timestamp: updateEncryptionData.date)
    }
    
    mutating func applyPeerHistoryTTL(_ updatePeerHistoryTTLData: Api.Update.Cons_updatePeerHistoryTTL) {
        updatedState.updateAutoremoveTimeout(peer: updatePeerHistoryTTLData.peer, value: CachedPeerAutoremoveTimeout.Value(updatePeerHistoryTTLData.ttlPeriod))
    }
    
    mutating func applyPendingJoinRequests(_ updatePendingJoinRequestsData: Api.Update.Cons_updatePendingJoinRequests) {
        let (peer, requestsPending) = (updatePendingJoinRequestsData.peer, updatePendingJoinRequestsData.requestsPending)
        updatedState.updateCachedPeerData(peer.peerId, { current in
            if peer.peerId.namespace == Namespaces.Peer.CloudGroup {
                let previous: CachedGroupData
                if let current = current as? CachedGroupData {
                    previous = current
                } else {
                    previous = CachedGroupData()
                }
                return previous.withUpdatedInviteRequestsPending(requestsPending)
            } else if peer.peerId.namespace == Namespaces.Peer.CloudChannel {
                let previous: CachedChannelData
                if let current = current as? CachedChannelData {
                    previous = current
                } else {
                    previous = CachedChannelData()
                }
                return previous.withUpdatedInviteRequestsPending(requestsPending)
            } else {
                return current
            }
        })
    }
    
    mutating func applyPeerWallpaper(_ updatePeerWallpaperData: Api.Update.Cons_updatePeerWallpaper) {
        updatedState.updateWallpaper(peerId: updatePeerWallpaperData.peer.peerId, wallpaper: updatePeerWallpaperData.wallpaper.flatMap { TelegramWallpaper(apiWallpaper: $0) })
    }
}

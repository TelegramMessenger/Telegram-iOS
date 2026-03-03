import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum UpdateChatRankError {
    case generic
    case changeForbidden
    case chatAdminRequired
    case chatCreatorRequired
    case notParticipant
}

func _internal_updateChatRank(account: Account, peerId: PeerId, userId: PeerId, messageId: MessageId?, rank: String?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, UpdateChatRankError> {
    return account.postbox.transaction { transaction -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, UpdateChatRankError> in
        if let user = transaction.getPeer(userId), let inputUser = apiInputPeer(user), let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let currentParticipant: Signal<ChannelParticipant?, NoError>
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                currentParticipant = _internal_fetchChannelParticipant(account: account, peerId: peerId, participantId: userId)
            } else {
                currentParticipant = .single(nil)
            }
            return currentParticipant
            |> castError(UpdateChatRankError.self)
            |> mapToSignal { currentParticipant in
                return account.network.request(Api.functions.messages.editChatParticipantRank(peer: inputPeer, participant: inputUser, rank: rank ?? ""))
                |> mapError { error -> UpdateChatRankError in
                    if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                        return .chatAdminRequired
                    } else if error.errorDescription == "CHAT_CREATOR_REQUIRED" {
                        return .chatCreatorRequired
                    } else if error.errorDescription == "USER_NOT_PARTICIPANT" {
                        return .notParticipant
                    } else if error.errorDescription == "RANK_CHANGE_FORBIDDEN" {
                        return .changeForbidden
                    } else {
                        return .generic
                    }
                }
                |> mapToSignal { updates -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, UpdateChatRankError> in
                    account.stateManager.addUpdates(updates)
                    
                    return account.postbox.transaction { transaction -> (ChannelParticipant?, RenderedChannelParticipant)? in
                        if peerId.namespace == Namespaces.Peer.CloudGroup {
                            transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, current in
                                if let current = current as? CachedGroupData, let participants = current.participants {
                                    var updatedParticipants = participants.participants
                                    if let index = updatedParticipants.firstIndex(where: { $0.peerId == userId }) {
                                        updatedParticipants[index] = updatedParticipants[index].withUpdated(rank: rank)
                                    }
                                    return current.withUpdatedParticipants(CachedGroupParticipants(participants: updatedParticipants, version: participants.version + 2))
                                } else {
                                    return current
                                }
                            })
                            return nil
                        } else {
                            let updatedParticipant = currentParticipant?.withUpdated(rank: rank) ?? .member(id: userId, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: rank, subscriptionUntilDate: nil)
                            var peers: [PeerId: Peer] = [:]
                            var presences: [PeerId: PeerPresence] = [:]
                            peers[user.id] = user
                            if let presence = transaction.getPeerPresence(peerId: user.id) {
                                presences[user.id] = presence
                            }
                            if case let .member(_, _, maybeAdminInfo, _, _, _) = updatedParticipant, let adminInfo = maybeAdminInfo {
                                if let peer = transaction.getPeer(adminInfo.promotedBy) {
                                    peers[peer.id] = peer
                                }
                            }
                            let historyView = transaction.getMessagesHistoryViewState(input: .single(peerId: peerId, threadId: nil), ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 50, clipHoles: true, anchor: .upperBound, namespaces: .just(Set([Namespaces.Message.Cloud])))
                            var messageIds: [MessageId] = []
                            if let messageId {
                                messageIds.append(messageId)
                            }
                            for entry in historyView.entries {
                                if entry.message.id != messageId, let author = entry.message.author, author.id == userId {
                                    messageIds.append(entry.message.id)
                                }
                            }
                            for messageId in messageIds {
                                transaction.updateMessage(messageId, update: { currentMessage in
                                    var storeForwardInfo: StoreMessageForwardInfo?
                                    if let forwardInfo = currentMessage.forwardInfo {
                                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                                    }
                                    var attributes = currentMessage.attributes
                                    attributes.removeAll(where: { $0 is ParticipantRankMessageAttribute })
                                    if let rank, !rank.isEmpty {
                                        attributes.append(ParticipantRankMessageAttribute(rank: rank))
                                    }
                                    return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                })
                            }
                            return (currentParticipant, RenderedChannelParticipant(participant: updatedParticipant, peer: user, peers: peers, presences: presences))
                        }
                    }
                    |> castError(UpdateChatRankError.self)
                }
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> UpdateChatRankError in }
    |> switchToLatest
}



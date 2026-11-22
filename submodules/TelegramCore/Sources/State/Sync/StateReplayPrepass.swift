import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// What `replayFinalState` reads, and writes, before it applies any operation of a final state (`prepare`), in this
/// order: it stores the pre-cached stories, reads where each previous-state hole starts, scans the final state's
/// operations (as built, not batched) for the incoming messages, the read maxima and the conference invitations, asks
/// Postbox which of the incoming and was-scheduled messages are not stored yet, and resolves the pending wallet
/// transfers the final state's outgoing ids map. `ReplayContext` starts from these values.
struct ReplayPrepass {
    /// The latest message time of each author of an incoming, non-automatic message added at the top of its history.
    let peerActivityTimestamps: [PeerId: Int32]
    /// Where each previous-state hole starts: one above the channel's `synchronizedUntilMessageId` (cloud namespace)
    /// or else above the stored top message, 1 when there is neither. Read after the pre-cached stories are stored.
    let holesFromPreviousStateMessageIds: [MessageId]
    /// Each peer's highest cloud read-inbox id over the `.ReadInbox`, `.ResetIncomingReadState` and `.ResetReadState`,
    /// without those the replay skips for a channel the account is not a member of (`cloudReadInboxMarks`).
    let readInboxCloudMessageIds: [PeerId: Int32]
    /// The incoming private-chat messages added at the top of their history that carry a conference-call invitation.
    let addedConferenceInvitationMessagesIds: [MessageId]
    /// The scheduled messages, now sent, added at the top of their history and not stored before the replay.
    let wasScheduledMessageIds: [MessageId]
    /// The incoming messages added at the top of their history and not stored before the replay.
    let addedIncomingMessageIds: [MessageId]
    /// The pending wallet transfers whose message id the final state's outgoing ids resolve.
    let mappedWalletMessageIds: [MessageId]

    static func prepare(transaction: Transaction, finalState: AccountFinalState) -> ReplayPrepass {
        var peerActivityTimestamps: [PeerId: Int32] = [:]

        var holesFromPreviousStateMessageIds: [MessageId] = []

        for (id, story) in finalState.state.preCachedStories {
            if let storyItem = Stories.StoredItem(apiStoryItem: story, peerId: id.peerId, transaction: transaction) {
                if let entry = CodableEntry(storyItem) {
                    transaction.setStory(id: id, value: entry)
                }
            } else {
                transaction.setStory(id: id, value: CodableEntry(data: Data()))
            }
        }

        for (peerId, namespaces) in finalState.state.namespacesWithHolesFromPreviousState {
            for namespace in namespaces {
                var topId: Int32?
                if namespace == Namespaces.Message.Cloud, let channelState = transaction.getPeerChatState(peerId) as? ChannelState {
                    if let synchronizedUntilMessageId = channelState.synchronizedUntilMessageId {
                        topId = synchronizedUntilMessageId
                    }
                }
                if topId == nil {
                    topId = transaction.getTopPeerMessageId(peerId: peerId, namespace: namespace)?.id
                }

                if let id = topId {
                    holesFromPreviousStateMessageIds.append(MessageId(peerId: peerId, namespace: namespace, id: id + 1))
                } else {
                    holesFromPreviousStateMessageIds.append(MessageId(peerId: peerId, namespace: namespace, id: 1))
                }
            }
        }

        var wasOperationScheduledMessageIds: [MessageId] = []

        // Judged by each peer as this batch leaves it, the way the replay below judges it when it applies the
        // operation: a channel joined earlier in the batch counts.
        let readInboxCloudMessageIds = cloudReadInboxMarks(finalState.state.operations, getPeer: { finalState.state.peers[$0] ?? transaction.getPeer($0) })

        var addedOperationIncomingMessageIds: [MessageId] = []
        var addedConferenceInvitationMessagesIds: [MessageId] = []

        for operation in finalState.state.operations {
            switch operation {
            case let .AddMessages(messages, location):
                if case .UpperHistoryBlock = location {
                    for message in messages {
                        if case let .Id(id) = message.id {
                            if message.flags.contains(.Incoming) {
                                addedOperationIncomingMessageIds.append(id)
                                if let authorId = message.authorId {
                                    var isAutomatic = false
                                    for attribute in message.attributes {
                                        if let attribute = attribute as? NotificationInfoMessageAttribute {
                                            if attribute.flags.contains(.automaticMessage) {
                                                isAutomatic = true
                                            }
                                        }
                                    }
                                    if !isAutomatic {
                                        recordPeerActivityTimestamp(peerId: authorId, timestamp: message.timestamp, into: &peerActivityTimestamps)
                                    }
                                }

                                if id.namespace == Namespaces.Message.Cloud && id.peerId.namespace == Namespaces.Peer.CloudUser {
                                    inner: for media in message.media {
                                        if let action = media as? TelegramMediaAction, case .conferenceCall = action.action {
                                            addedConferenceInvitationMessagesIds.append(id)
                                            break inner
                                        }
                                    }
                                }
                            }
                            if message.flags.contains(.WasScheduled) {
                                wasOperationScheduledMessageIds.append(id)
                            }
                        }
                    }
                }
            default:
                break
            }
        }
        var wasScheduledMessageIds:[MessageId] = []
        var addedIncomingMessageIds: [MessageId] = []

        if !wasOperationScheduledMessageIds.isEmpty {
            let existingIds = transaction.filterStoredMessageIds(Set(wasOperationScheduledMessageIds))
            for id in wasOperationScheduledMessageIds {
                if !existingIds.contains(id) {
                    wasScheduledMessageIds.append(id)
                }
            }
        }
        if !addedOperationIncomingMessageIds.isEmpty {
            let existingIds = transaction.filterStoredMessageIds(Set(addedOperationIncomingMessageIds))
            for id in addedOperationIncomingMessageIds {
                if !existingIds.contains(id) {
                    addedIncomingMessageIds.append(id)
                }
            }
        }

        let mappedWalletMessageIds = applyWalletTransferMessageIds(transaction: transaction, mappings: finalState.state.updatedOutgoingUniqueMessageIds)

        return ReplayPrepass(peerActivityTimestamps: peerActivityTimestamps, holesFromPreviousStateMessageIds: holesFromPreviousStateMessageIds, readInboxCloudMessageIds: readInboxCloudMessageIds, addedConferenceInvitationMessagesIds: addedConferenceInvitationMessagesIds, wasScheduledMessageIds: wasScheduledMessageIds, addedIncomingMessageIds: addedIncomingMessageIds, mappedWalletMessageIds: mappedWalletMessageIds)
    }
}

/// The highest incoming read mark each peer's cloud messages get in `operations`, for counting new messages
/// in forum topics. Operations the replay skips for a channel the account is not a member of
/// (`readStateOperationTargetsNonMember`) are left out.
func cloudReadInboxMarks(_ operations: [AccountStateMutationOperation], getPeer: (PeerId) -> Peer?) -> [PeerId: Int32] {
    var marks: [PeerId: Int32] = [:]
    for operation in operations {
        let peerId: PeerId
        let mark: Int32
        switch operation {
        case let .ReadInbox(messageId):
            guard messageId.namespace == Namespaces.Message.Cloud else {
                continue
            }
            peerId = messageId.peerId
            mark = messageId.id
        case let .ResetIncomingReadState(_, peerIdValue, namespace, maxIncomingReadId, _, _):
            guard namespace == Namespaces.Message.Cloud else {
                continue
            }
            peerId = peerIdValue
            mark = maxIncomingReadId
        case let .ResetReadState(peerIdValue, namespace, maxIncomingReadId, _, _, _, _):
            guard namespace == Namespaces.Message.Cloud else {
                continue
            }
            peerId = peerIdValue
            mark = maxIncomingReadId
        default:
            continue
        }
        if readStateOperationTargetsNonMember(operation, getPeer: getPeer) {
            continue
        }
        if let current = marks[peerId], current >= mark {
            continue
        }
        marks[peerId] = mark
    }
    return marks
}

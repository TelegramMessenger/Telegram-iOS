import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Calls and group calls.
extension ReplayContext {
    func applyUpdateCall(_ call: Api.PhoneCall) {
        updatedCalls.append(call)
    }
    
    func applyAddCallSignalingData(_ callId: Int64, _ data: Data) {
        addedCallSignalingData.append((callId, data))
    }
    
    func applyUpdateGroupCallParticipants(_ callId: Int64, _ participants: [Api.GroupCallParticipant], _ version: Int32) {
        updatedGroupCallParticipants.append((
            callId,
            .state(update: GroupCallParticipantsContext.Update.StateUpdate(participants: participants, version: version))
        ))
    }
    
    func applyUpdateGroupCallMessage(_ callId: Int64, _ authorId: PeerId, _ isFromAdmin: Bool, _ messageId: Int32, _ text: Api.TextWithEntities, _ date: Int32, _ paidMessageStars: Int64?) {
        switch text {
        case let .textWithEntities(textWithEntitiesData):
            let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
            groupCallMessageUpdates.append(GroupCallMessageUpdate(callId: callId, update: .newPlaintextMessage(authorId: authorId, isFromAdmin: isFromAdmin, messageId: messageId, text: text, entities: messageTextEntitiesFromApiEntities(entities), timestamp: date, paidMessageStars: paidMessageStars)))
        }
    }
    
    func applyUpdateGroupCallOpaqueMessage(_ callId: Int64, _ authorId: PeerId, _ data: Data) {
        groupCallMessageUpdates.append(GroupCallMessageUpdate(callId: callId, update: .newOpaqueMessage(authorId: authorId, data: data)))
    }
    
    func applyUpdateGroupCall(_ peerId: PeerId?, _ call: Api.GroupCall) {
        switch call {
        case .groupCall:
            if let info = GroupCallInfo(call) {
                if let peerId {
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        if let current = current as? CachedChannelData {
                            return current.withUpdatedActiveCall(CachedChannelData.ActiveCall(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: info.scheduleTimestamp, subscribedToScheduled: info.subscribedToScheduled, isStream: info.isStream))
                        } else if let current = current as? CachedGroupData {
                            return current.withUpdatedActiveCall(CachedChannelData.ActiveCall(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: info.scheduleTimestamp, subscribedToScheduled: info.subscribedToScheduled, isStream: info.isStream))
                        } else {
                            return current
                        }
                    })
                }

                switch call {
                case let .groupCall(groupCallData):
                    let (flags, participantsCount, title, recordStartDate, scheduleDate, sendPaidMessagesStars) = (groupCallData.flags, groupCallData.participantsCount, groupCallData.title, groupCallData.recordStartDate, groupCallData.scheduleDate, groupCallData.sendPaidMessagesStars)
                    let isMin = (flags & (1 << 19)) != 0
                    let isMuted = (flags & (1 << 1)) != 0
                    let canChange = (flags & (1 << 2)) != 0
                    let isVideoEnabled = (flags & (1 << 9)) != 0
                    let defaultParticipantsAreMuted = GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: isMuted, canChange: canChange)
                    let messagesEnabled = (flags & (1 << 17)) != 0
                    let canChangeMessagesEnabled = (flags & (1 << 18)) != 0
                    let messagesAreEnabled = GroupCallParticipantsContext.State.MessagesAreEnabled(isEnabled: messagesEnabled, canChange: canChangeMessagesEnabled, sendPaidMessagesStars: sendPaidMessagesStars)
                    updatedGroupCallParticipants.append((
                        info.id,
                        .call(isTerminated: false, defaultParticipantsAreMuted: defaultParticipantsAreMuted, messagesAreEnabled: messagesAreEnabled, title: title, recordingStartTimestamp: recordStartDate, scheduleTimestamp: scheduleDate, isVideoEnabled: isVideoEnabled, participantCount: Int(participantsCount), isMin: isMin)
                    ))
                default:
                    break
                }
            }
        case let .groupCallDiscarded(groupCallDiscardedData):
            let callId = groupCallDiscardedData.id
            updatedGroupCallParticipants.append((
                callId,
                .call(isTerminated: true, defaultParticipantsAreMuted: GroupCallParticipantsContext.State.DefaultParticipantsAreMuted(isMuted: false, canChange: false), messagesAreEnabled: GroupCallParticipantsContext.State.MessagesAreEnabled(isEnabled: false, canChange: false, sendPaidMessagesStars: nil), title: nil, recordingStartTimestamp: nil, scheduleTimestamp: nil, isVideoEnabled: false, participantCount: nil, isMin: false)
            ))

            if let peerId {
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    if let current = current as? CachedChannelData {
                        if let activeCall = current.activeCall, activeCall.id == callId {
                            return current.withUpdatedActiveCall(nil)
                        } else {
                            return current
                        }
                    } else if let current = current as? CachedGroupData {
                        if let activeCall = current.activeCall, activeCall.id == callId {
                            return current.withUpdatedActiveCall(nil)
                        } else {
                            return current
                        }
                    } else {
                        return current
                    }
                })
            }
        }
    }
    
    func applyUpdateGroupCallChainBlocks(_ id: Int64, _ subChainId: Int32, _ blocks: [Data], _ nextOffset: Int32) {
        updatedGroupCallParticipants.append((
            id,
            .conferenceChainBlocks(subChainId: Int(subChainId), blocks: blocks, nextOffset: Int(nextOffset))
        ))
    }
}

import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Calls and group calls.
extension UpdateInterpreter {
    mutating func applyPhoneCall(_ updatePhoneCallData: Api.Update.Cons_updatePhoneCall) {
        updatedState.addUpdateCall(updatePhoneCallData.phoneCall)
    }
    
    mutating func applyPhoneCallSignalingData(_ updatePhoneCallSignalingData: Api.Update.Cons_updatePhoneCallSignalingData) {
        updatedState.addCallSignalingData(callId: updatePhoneCallSignalingData.phoneCallId, data: updatePhoneCallSignalingData.data.makeData())
    }
    
    mutating func applyGroupCallParticipants(_ updateGroupCallParticipantsData: Api.Update.Cons_updateGroupCallParticipants) {
        let (call, participants, version) = (updateGroupCallParticipantsData.call, updateGroupCallParticipantsData.participants, updateGroupCallParticipantsData.version)
        switch call {
        case let .inputGroupCall(inputGroupCallData):
            let (id, accessHash) = (inputGroupCallData.id, inputGroupCallData.accessHash)
            updatedState.updateGroupCallParticipants(id: id, accessHash: accessHash, participants: participants, version: version)
        case .inputGroupCallSlug, .inputGroupCallInviteMessage:
            break
        }
    }
    
    mutating func applyGroupCall(_ updateGroupCallData: Api.Update.Cons_updateGroupCall) {
        updatedState.updateGroupCall(peerId: updateGroupCallData.peer?.peerId, call: updateGroupCallData.call)
    }
    
    mutating func applyGroupCallChainBlocks(_ updateGroupCallChainBlocksData: Api.Update.Cons_updateGroupCallChainBlocks) {
        let (call, subChainId, blocks, nextOffset) = (updateGroupCallChainBlocksData.call, updateGroupCallChainBlocksData.subChainId, updateGroupCallChainBlocksData.blocks, updateGroupCallChainBlocksData.nextOffset)
        if case let .inputGroupCall(inputGroupCallData) = call {
            let (id, accessHash) = (inputGroupCallData.id, inputGroupCallData.accessHash)
            updatedState.updateGroupCallChainBlocks(id: id, accessHash: accessHash, subChainId: subChainId, blocks: blocks.map { $0.makeData() }, nextOffset: nextOffset)
        }
    }
    
    mutating func applyGroupCallMessage(_ updateGroupCallMessageData: Api.Update.Cons_updateGroupCallMessage) {
        let (call, message) = (updateGroupCallMessageData.call, updateGroupCallMessageData.message)
        if case let .inputGroupCall(inputGroupCallData) = call {
            let id = inputGroupCallData.id
            switch message {
            case let .groupCallMessage(groupCallMessageData):
                let (flags, messageId, fromId, date, message, paidMessageStars) = (groupCallMessageData.flags, groupCallMessageData.id, groupCallMessageData.fromId, groupCallMessageData.date, groupCallMessageData.message, groupCallMessageData.paidMessageStars)
                updatedState.updateGroupCallMessage(id: id, authorId: fromId.peerId, isFromAdmin: (flags & (1 << 1)) != 0, messageId: messageId, text: message, date: date, paidMessageStars: paidMessageStars)
            }
        }
    }
    
    mutating func applyGroupCallEncryptedMessage(_ updateGroupCallEncryptedMessageData: Api.Update.Cons_updateGroupCallEncryptedMessage) {
        let (call, fromId, encryptedMessage) = (updateGroupCallEncryptedMessageData.call, updateGroupCallEncryptedMessageData.fromId, updateGroupCallEncryptedMessageData.encryptedMessage)
        if case let .inputGroupCall(inputGroupCallData) = call {
            let id = inputGroupCallData.id
            updatedState.updateGroupCallOpaqueMessage(id: id, authorId: fromId.peerId, data: encryptedMessage.makeData())
        }
    }
}

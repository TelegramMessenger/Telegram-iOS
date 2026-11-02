import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Typing activity and live typing drafts, kept only from a dated batch that is less than 60 s old by
/// `serverTime` (a difference has no date).
extension UpdateInterpreter {
    enum TypingDraftText {
        case plain(Api.TextWithEntities)
        case rich(Api.RichMessage)
    }
    
    mutating func applyUserTyping(_ updateUserTypingData: Api.Update.Cons_updateUserTyping) {
        let (userId, topMsgId, type) = (updateUserTypingData.userId, updateUserTypingData.topMsgId, updateUserTypingData.action)
        let threadId = topMsgId.flatMap { Int64($0) }

        if let date = updatesDate, date + 60 > serverTime {
            var typingDraftData: (randomId: Int64, canStop: Bool, keepOnStop: Bool, text: TypingDraftText)?

            if case let .sendMessageTextDraftAction(sendMessageTextDraftActionData) = type {
                typingDraftData = (
                    sendMessageTextDraftActionData.randomId,
                    (sendMessageTextDraftActionData.flags & (1 << 0)) != 0,
                    (sendMessageTextDraftActionData.flags & (1 << 1)) != 0,
                    .plain(sendMessageTextDraftActionData.text)
                )
            } else if case let .sendMessageRichMessageDraftAction(sendMessageRichMessageDraftActionData) = type {
                typingDraftData = (
                    sendMessageRichMessageDraftActionData.randomId,
                    (sendMessageRichMessageDraftActionData.flags & (1 << 0)) != 0,
                    (sendMessageRichMessageDraftActionData.flags & (1 << 1)) != 0,
                    .rich(sendMessageRichMessageDraftActionData.richMessage)
                )
            }
            if case let .sendMessageStopDraftAction(sendMessageStopDraftActionData) = type {
                updatedState.addPeerLiveTypingDraftStop(peerAndThreadId: PeerAndThreadId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), threadId: threadId), randomId: sendMessageStopDraftActionData.randomId, timestamp: date)
            } else if let typingDraftData {
                switch typingDraftData.text {
                case let .plain(plain):
                    if case let .textWithEntities(textWithEntitiesData) = plain {
                        updatedState.addPeerLiveTypingDraftUpdate(peerAndThreadId: PeerAndThreadId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), threadId: threadId), id: typingDraftData.randomId, timestamp: date, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), canStop: typingDraftData.canStop, keepOnStop: typingDraftData.keepOnStop, content: .plain(text: textWithEntitiesData.text, entities: messageTextEntitiesFromApiEntities(textWithEntitiesData.entities)))
                    }
                case let .rich(richMessage):
                    let parsedRichMessage = RichTextMessageAttribute(apiRichMessage: richMessage)
                    updatedState.addPeerLiveTypingDraftUpdate(peerAndThreadId: PeerAndThreadId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), threadId: threadId), id: typingDraftData.randomId, timestamp: date, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), canStop: typingDraftData.canStop, keepOnStop: typingDraftData.keepOnStop, content: .rich(parsedRichMessage))
                }
            } else {
                let activity = PeerInputActivity(apiType: type, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), timestamp: date)
                var category: PeerActivitySpace.Category = .global
                if case .speakingInGroupCall = activity {
                    category = .voiceChat
                }

                updatedState.addPeerInputActivity(chatPeerId: PeerActivitySpace(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), category: category), peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), activity: activity)
            }
        }
    }
    
    mutating func applyChatUserTyping(_ updateChatUserTyping: Api.Update.Cons_updateChatUserTyping) {
        let (chatId, userId, type) = (updateChatUserTyping.chatId, updateChatUserTyping.fromId, updateChatUserTyping.action)
        if let date = updatesDate, date + 60 > serverTime {
            let activity = PeerInputActivity(apiType: type, peerId: nil, timestamp: date)
            var category: PeerActivitySpace.Category = .global
            if case .speakingInGroupCall = activity {
                category = .voiceChat
            }

            updatedState.addPeerInputActivity(chatPeerId: PeerActivitySpace(peerId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)), category: category), peerId: userId.peerId, activity: activity)
        }
    }
    
    mutating func applyChannelUserTyping(_ updateChannelUserTypingData: Api.Update.Cons_updateChannelUserTyping) {
        let (channelId, topMsgId, userId, type) = (updateChannelUserTypingData.channelId, updateChannelUserTypingData.topMsgId, updateChannelUserTypingData.fromId, updateChannelUserTypingData.action)
        if let date = updatesDate, date + 60 > serverTime {
            let channelPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
            let threadId = topMsgId.flatMap { Int64($0) }

            if case let .sendMessageStopDraftAction(sendMessageStopDraftActionData) = type {
                updatedState.addPeerLiveTypingDraftStop(peerAndThreadId: PeerAndThreadId(peerId: channelPeerId, threadId: threadId), randomId: sendMessageStopDraftActionData.randomId, timestamp: date)
            } else if case let .sendMessageTextDraftAction(sendMessageTextDraftActionData) = type {
                let (randomId, text) = (sendMessageTextDraftActionData.randomId, sendMessageTextDraftActionData.text)
                let canStop = (sendMessageTextDraftActionData.flags & (1 << 0)) != 0
                let keepOnStop = (sendMessageTextDraftActionData.flags & (1 << 1)) != 0
                switch text {
                case let .textWithEntities(textWithEntitiesData):
                    let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                    updatedState.addPeerLiveTypingDraftUpdate(peerAndThreadId: PeerAndThreadId(peerId: channelPeerId, threadId: threadId), id: randomId, timestamp: date, peerId: userId.peerId, canStop: canStop, keepOnStop: keepOnStop, content: .plain(text: text, entities: messageTextEntitiesFromApiEntities(entities)))
                }
            } else if case let .sendMessageRichMessageDraftAction(sendMessageRichMessageDraftActionData) = type {
                let parsedRichMessage = RichTextMessageAttribute(apiRichMessage: sendMessageRichMessageDraftActionData.richMessage)
                updatedState.addPeerLiveTypingDraftUpdate(peerAndThreadId: PeerAndThreadId(peerId: channelPeerId, threadId: threadId), id: sendMessageRichMessageDraftActionData.randomId, timestamp: date, peerId: userId.peerId, canStop: (sendMessageRichMessageDraftActionData.flags & (1 << 0)) != 0, keepOnStop: (sendMessageRichMessageDraftActionData.flags & (1 << 1)) != 0, content: .rich(parsedRichMessage))
            } else {
                let activity = PeerInputActivity(apiType: type, peerId: nil, timestamp: date)
                var category: PeerActivitySpace.Category = .global
                if case .speakingInGroupCall = activity {
                    category = .voiceChat
                } else if let threadId = threadId {
                    category = .thread(threadId)
                }

                updatedState.addPeerInputActivity(chatPeerId: PeerActivitySpace(peerId: channelPeerId, category: category), peerId: userId.peerId, activity: activity)
            }
        }
    }
    
    mutating func applyEncryptedChatTyping(_ updateEncryptedChatTypingData: Api.Update.Cons_updateEncryptedChatTyping) {
        if let date = updatesDate, date + 60 > serverTime {
            updatedState.addPeerInputActivity(chatPeerId: PeerActivitySpace(peerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(updateEncryptedChatTypingData.chatId))), category: .global), peerId: nil, activity: .typingText)
        }
    }
}

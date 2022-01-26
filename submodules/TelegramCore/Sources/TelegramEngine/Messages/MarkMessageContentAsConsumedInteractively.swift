import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

func _internal_markMessageContentAsConsumedInteractively(postbox: Postbox, messageId: MessageId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let message = transaction.getMessage(messageId), message.flags.contains(.Incoming) {
            var updateMessage = false
            var updatedAttributes = message.attributes
            
            for i in 0 ..< updatedAttributes.count {
                if let attribute = updatedAttributes[i] as? ConsumableContentMessageAttribute {
                    if !attribute.consumed {
                        updatedAttributes[i] = ConsumableContentMessageAttribute(consumed: true)
                        updateMessage = true
                        
                        if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                            if let state = transaction.getPeerChatState(message.id.peerId) as? SecretChatState {
                                var layer: SecretChatLayer?
                                switch state.embeddedState {
                                    case .terminated, .handshake:
                                        break
                                    case .basicLayer:
                                        layer = .layer8
                                    case let .sequenceBasedLayer(sequenceState):
                                        layer = sequenceState.layerNegotiationState.activeLayer.secretChatLayer
                                }
                                if let layer = layer {
                                    var globallyUniqueIds: [Int64] = []
                                    if let globallyUniqueId = message.globallyUniqueId {
                                        globallyUniqueIds.append(globallyUniqueId)
                                        let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: message.id.peerId, operation: SecretChatOutgoingOperationContents.readMessagesContent(layer: layer, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), globallyUniqueIds: globallyUniqueIds), state: state)
                                        if updatedState != state {
                                            transaction.setPeerChatState(message.id.peerId, state: updatedState)
                                        }
                                    }
                                }
                            }
                        } else {
                            addSynchronizeConsumeMessageContentsOperation(transaction: transaction, messageIds: [message.id])
                        }
                    }
                } else if let attribute = updatedAttributes[i] as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed {
                    transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: messageId, action: ConsumePersonalMessageAction())
                    updatedAttributes[i] = ConsumablePersonalMentionMessageAttribute(consumed: attribute.consumed, pending: true)
                }
            }
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            for i in 0 ..< updatedAttributes.count {
                if let attribute = updatedAttributes[i] as? AutoremoveTimeoutMessageAttribute {
                    if attribute.countdownBeginTime == nil || attribute.countdownBeginTime == 0 {
                        var timeout = attribute.timeout
                        if let duration = message.secretMediaDuration {
                            timeout = max(timeout, duration)
                        }
                        updatedAttributes[i] = AutoremoveTimeoutMessageAttribute(timeout: timeout, countdownBeginTime: timestamp)
                        updateMessage = true
                        
                        if messageId.peerId.namespace == Namespaces.Peer.SecretChat {
                            var layer: SecretChatLayer?
                            let state = transaction.getPeerChatState(message.id.peerId) as? SecretChatState
                            if let state = state {
                                switch state.embeddedState {
                                    case .terminated, .handshake:
                                        break
                                    case .basicLayer:
                                        layer = .layer8
                                    case let .sequenceBasedLayer(sequenceState):
                                        layer = sequenceState.layerNegotiationState.activeLayer.secretChatLayer
                                }
                            }
                            
                            if let state = state, let layer = layer, let globallyUniqueId = message.globallyUniqueId {
                                let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: messageId.peerId, operation: .readMessagesContent(layer: layer, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), globallyUniqueIds: [globallyUniqueId]), state: state)
                                if updatedState != state {
                                    transaction.setPeerChatState(messageId.peerId, state: updatedState)
                                }
                            }
                        }
                    }
                } else if let attribute = updatedAttributes[i] as? AutoclearTimeoutMessageAttribute {
                    if attribute.countdownBeginTime == nil || attribute.countdownBeginTime == 0 {
                        var timeout = attribute.timeout
                        if let duration = message.secretMediaDuration {
                            timeout = max(timeout, duration)
                        }
                        updatedAttributes[i] = AutoclearTimeoutMessageAttribute(timeout: timeout, countdownBeginTime: timestamp)
                        updateMessage = true
                        
                        if messageId.peerId.namespace == Namespaces.Peer.SecretChat {
                            var layer: SecretChatLayer?
                            let state = transaction.getPeerChatState(message.id.peerId) as? SecretChatState
                            if let state = state {
                                switch state.embeddedState {
                                    case .terminated, .handshake:
                                        break
                                    case .basicLayer:
                                        layer = .layer8
                                    case let .sequenceBasedLayer(sequenceState):
                                        layer = sequenceState.layerNegotiationState.activeLayer.secretChatLayer
                                }
                            }
                            
                            if let state = state, let layer = layer, let globallyUniqueId = message.globallyUniqueId {
                                let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: messageId.peerId, operation: .readMessagesContent(layer: layer, actionGloballyUniqueId: Int64.random(in: Int64.min ... Int64.max), globallyUniqueIds: [globallyUniqueId]), state: state)
                                if updatedState != state {
                                    transaction.setPeerChatState(messageId.peerId, state: updatedState)
                                }
                            }
                        }
                    }
                }
            }
            
            if updateMessage {
                transaction.updateMessage(message.id, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
                })
            }
        }
    }
}

func _internal_markReactionsAsSeenInteractively(postbox: Postbox, messageId: MessageId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let message = transaction.getMessage(messageId), message.tags.contains(.unseenReaction) {
            var updateMessage = false
            var updatedAttributes = message.attributes
            
            for i in 0 ..< updatedAttributes.count {
                if let attribute = updatedAttributes[i] as? ReactionsMessageAttribute, attribute.hasUnseen {
                    updatedAttributes[i] = attribute.withAllSeen()
                    updateMessage = true
                    
                    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                    } else {
                        transaction.setPendingMessageAction(type: .readReaction, id: messageId, action: ReadReactionAction())
                    }
                }
            }
            
            if updateMessage {
                transaction.updateMessage(message.id, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    var tags = currentMessage.tags
                    tags.remove(.unseenReaction)
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: currentMessage.media))
                })
            }
        }
    }
}

func markMessageContentAsConsumedRemotely(transaction: Transaction, messageId: MessageId) {
    if let message = transaction.getMessage(messageId) {
        var updateMessage = false
        var updatedAttributes = message.attributes
        var updatedMedia = message.media
        var updatedTags = message.tags
        
        for i in 0 ..< updatedAttributes.count {
            if let attribute = updatedAttributes[i] as? ConsumableContentMessageAttribute {
                if !attribute.consumed {
                    updatedAttributes[i] = ConsumableContentMessageAttribute(consumed: true)
                    updateMessage = true
                }
            } else if let attribute = updatedAttributes[i] as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed {
                if attribute.pending {
                    transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: messageId, action: nil)
                }
                updatedAttributes[i] = ConsumablePersonalMentionMessageAttribute(consumed: true, pending: false)
                updatedTags.remove(.unseenPersonalMessage)
                updateMessage = true
            }
        }
        
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        for i in 0 ..< updatedAttributes.count {
            if let attribute = updatedAttributes[i] as? AutoremoveTimeoutMessageAttribute {
                if (attribute.countdownBeginTime == nil || attribute.countdownBeginTime == 0) && message.containsSecretMedia {
                    updatedAttributes[i] = AutoremoveTimeoutMessageAttribute(timeout: attribute.timeout, countdownBeginTime: timestamp)
                    updateMessage = true
                    
                    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                    } else {
                        for i in 0 ..< updatedMedia.count {
                            if let _ = updatedMedia[i] as? TelegramMediaImage {
                                updatedMedia[i] = TelegramMediaExpiredContent(data: .image)
                            } else if let _ = updatedMedia[i] as? TelegramMediaFile {
                                updatedMedia[i] = TelegramMediaExpiredContent(data: .file)
                            }
                        }
                    }
                }
            } else if let attribute = updatedAttributes[i] as? AutoclearTimeoutMessageAttribute {
                if (attribute.countdownBeginTime == nil || attribute.countdownBeginTime == 0) && message.containsSecretMedia {
                    updatedAttributes[i] = AutoclearTimeoutMessageAttribute(timeout: attribute.timeout, countdownBeginTime: timestamp)
                    updateMessage = true
                    
                    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                    } else {
                        for i in 0 ..< updatedMedia.count {
                            if let _ = updatedMedia[i] as? TelegramMediaImage {
                                updatedMedia[i] = TelegramMediaExpiredContent(data: .image)
                            } else if let _ = updatedMedia[i] as? TelegramMediaFile {
                                updatedMedia[i] = TelegramMediaExpiredContent(data: .file)
                            }
                        }
                    }
                }
            }
        }
        
        if updateMessage {
            transaction.updateMessage(message.id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: updatedAttributes, media: updatedMedia))
            })
        }
    }
}


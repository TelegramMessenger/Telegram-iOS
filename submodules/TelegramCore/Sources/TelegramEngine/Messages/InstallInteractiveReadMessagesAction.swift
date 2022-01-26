import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


func _internal_installInteractiveReadMessagesAction(postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId) -> Disposable {
    return postbox.installStoreMessageAction(peerId: peerId, { messages, transaction in
        var consumeMessageIds: [MessageId] = []
        var readReactionIds: [MessageId] = []
        
        var readMessageIndexByNamespace: [MessageId.Namespace: MessageIndex] = [:]
        
        for message in messages {
            if case let .Id(id) = message.id {
                var hasUnconsumedMention = false
                var hasUnconsumedContent = false
                var hasUnseenReactions = false
                
                if message.tags.contains(.unseenPersonalMessage) {
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed, !attribute.pending {
                            hasUnconsumedMention = true
                        } else if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                            hasUnconsumedContent = true
                        } else if let attribute = attribute as? ReactionsMessageAttribute, attribute.hasUnseen {
                            hasUnseenReactions = true
                        }
                    }
                }
                
                if hasUnconsumedMention && !hasUnconsumedContent {
                    consumeMessageIds.append(id)
                }
                if hasUnseenReactions {
                    readReactionIds.append(id)
                }
                
                if !message.flags.intersection(.IsIncomingMask).isEmpty {
                    let index = MessageIndex(id: id, timestamp: message.timestamp)
                    let current = readMessageIndexByNamespace[id.namespace]
                    if current == nil || current! < index {
                        readMessageIndexByNamespace[id.namespace] = index
                    }
                }
            }
        }
        
        for id in Set(consumeMessageIds + readReactionIds) {
            transaction.updateMessage(id, update: { currentMessage in
                var attributes = currentMessage.attributes
                if consumeMessageIds.contains(id) {
                    mentionsLoop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ConsumablePersonalMentionMessageAttribute {
                            attributes[j] = ConsumablePersonalMentionMessageAttribute(consumed: attribute.consumed, pending: true)
                            break mentionsLoop
                        }
                    }
                }
                if readReactionIds.contains(id) {
                    reactionsLoop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ReactionsMessageAttribute {
                            attributes[j] = attribute.withAllSeen()
                            break reactionsLoop
                        }
                    }
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
            
            if consumeMessageIds.contains(id) {
                transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: ConsumePersonalMessageAction())
            }
            if readReactionIds.contains(id) {
                transaction.setPendingMessageAction(type: .readReaction, id: id, action: ReadReactionAction())
            }
        }
        
        for (_, index) in readMessageIndexByNamespace {
            _internal_applyMaxReadIndexInteractively(transaction: transaction, stateManager: stateManager, index: index)
        }
    })
}

import Foundation
import Postbox
import TelegramApi

import SyncCore

func updateMessageMedia(transaction: Transaction, id: MediaId, media: Media?) {
    let updatedMessageIndices = transaction.updateMedia(id, update: media)
    for index in updatedMessageIndices {
        transaction.updateMessage(index.id, update: { currentMessage in
            var textEntities: [MessageTextEntity]?
            for attribute in currentMessage.attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    textEntities = attribute.entities
                    break
                }
            }
            let (tags, _) = tagsForStoreMessage(incoming: currentMessage.flags.contains(.Incoming), attributes: currentMessage.attributes, media: currentMessage.media, textEntities: textEntities)
            if tags == currentMessage.tags {
                return .skip
            }
            
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType)
            }
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
        })
    }
}

func updateMessageThreadStats(transaction: Transaction, threadMessageId: MessageId, difference: Int) {
    transaction.updateMessage(threadMessageId, update: { currentMessage in
        let countDifference = Int32(difference)
        
        var attributes = currentMessage.attributes
        var updated = false
        loop: for j in 0 ..< attributes.count {
            if let attribute = attributes[j] as? ReplyThreadMessageAttribute {
                attributes[j] = ReplyThreadMessageAttribute(count: max(0, attribute.count + countDifference))
                updated = true
                break loop
            }
        }
        if !updated {
            attributes.append(ReplyThreadMessageAttribute(count: max(0, countDifference)))
        }
        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
    })
}

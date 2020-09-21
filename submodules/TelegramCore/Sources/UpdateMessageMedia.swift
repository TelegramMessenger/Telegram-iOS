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

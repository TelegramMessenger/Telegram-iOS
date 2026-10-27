import Foundation
import Postbox
import TwelveSettings

/// While "Save deleted messages" (Настройки Pure) is on, the cloud messages the server deletes are kept and
/// marked with `TwelveDeletedMessageAttribute` instead of being removed. Returns the ids that still have to be
/// deleted for real. Deletions made on this device never reach here: they remove the message locally first.
func twelveKeepDeletedMessages(transaction: Transaction, ids: [MessageId]) -> [MessageId] {
    if !TwelveSettings.saveDeletedMessages {
        return ids
    }
    let timestamp = Int32(Date().timeIntervalSince1970)
    var remaining: [MessageId] = []
    for id in ids {
        guard id.namespace == Namespaces.Message.Cloud, let message = transaction.getMessage(id) else {
            remaining.append(id)
            continue
        }
        if message.twelveDeletedAttribute != nil {
            continue
        }
        transaction.updateMessage(id, update: { currentMessage in
            var attributes = currentMessage.attributes
            attributes.append(TwelveDeletedMessageAttribute(date: timestamp))
            return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
    }
    return remaining
}

/// The global-id form of `twelveKeepDeletedMessages` (private chats and basic groups).
func twelveKeepDeletedMessages(transaction: Transaction, globalIds: [Int32]) -> [Int32] {
    if !TwelveSettings.saveDeletedMessages {
        return globalIds
    }
    var remaining: [Int32] = []
    for globalId in globalIds {
        guard let id = transaction.messageIdsForGlobalIds([globalId]).first else {
            remaining.append(globalId)
            continue
        }
        if !twelveKeepDeletedMessages(transaction: transaction, ids: [id]).isEmpty {
            remaining.append(globalId)
        }
    }
    return remaining
}

/// Carries the edit history across a server update of a stored message and, while "Save edit history" is on,
/// records the previous text when it changed.
func twelveMergedEditHistory(previous previousMessage: Message, updatedText: String, updatedAttributes: [MessageAttribute]) -> [MessageAttribute] {
    var attributes = updatedAttributes
    var entries = previousMessage.twelveEditHistory
    if TwelveSettings.saveEditHistory, previousMessage.text != updatedText, !previousMessage.text.isEmpty {
        let date = previousMessage.editedTime ?? previousMessage.timestamp
        entries.append(TwelveEditHistoryMessageAttribute.Entry(text: previousMessage.text, date: date))
        if entries.count > 50 {
            entries.removeFirst(entries.count - 50)
        }
    }
    attributes.removeAll(where: { $0 is TwelveEditHistoryMessageAttribute || $0 is TwelveDeletedMessageAttribute })
    if !entries.isEmpty {
        attributes.append(TwelveEditHistoryMessageAttribute(entries: entries))
    }
    if let deletedAttribute = previousMessage.twelveDeletedAttribute {
        attributes.append(deletedAttribute)
    }
    return attributes
}

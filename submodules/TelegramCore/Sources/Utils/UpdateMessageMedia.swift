import Foundation
import Postbox
import TelegramApi


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
            let (tags, _) = tagsForStoreMessage(incoming: currentMessage.flags.contains(.Incoming), attributes: currentMessage.attributes, media: currentMessage.media, textEntities: textEntities, isPinned: currentMessage.tags.contains(.pinned))
            if tags == currentMessage.tags {
                return .skip
            }
            
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
        })
    }
}

struct ReplyThreadUserMessage {
    var id: PeerId
    var messageId: MessageId
    var isOutgoing: Bool
}

func updateMessageThreadStats(transaction: Transaction, threadMessageId: MessageId, removedCount: Int, addedMessagePeers: [ReplyThreadUserMessage]) {
    updateMessageThreadStatsInternal(transaction: transaction, threadMessageId: threadMessageId, removedCount: removedCount, addedMessagePeers: addedMessagePeers, allowChannel: false)
}
    
private func updateMessageThreadStatsInternal(transaction: Transaction, threadMessageId: MessageId, removedCount: Int, addedMessagePeers: [ReplyThreadUserMessage], allowChannel: Bool) {
    guard let channel = transaction.getPeer(threadMessageId.peerId) as? TelegramChannel else {
        return
    }
    var isGroup = true
    if case .broadcast = channel.info {
        isGroup = false
        if !allowChannel {
            return
        }
    }
    
    var channelThreadMessageId: MessageId?
    
    func mergeLatestUsers(current: [PeerId], added: [PeerId], isGroup: Bool, isEmpty: Bool) -> [PeerId] {
        if isEmpty {
            return []
        }
        if isGroup {
            return current
        }
        var current = current
        for i in 0 ..< min(3, added.count) {
            let peerId = added[added.count - 1 - i]
            if let index = current.firstIndex(of: peerId) {
                current.remove(at: index)
                current.insert(peerId, at: 0)
            } else {
                if current.count >= 3 {
                    current.removeLast()
                }
                current.insert(peerId, at: 0)
            }
        }
        return current
    }
    
    transaction.updateMessage(threadMessageId, update: { currentMessage in
        var attributes = currentMessage.attributes
        loop: for j in 0 ..< attributes.count {
            if let attribute = attributes[j] as? ReplyThreadMessageAttribute {
                var countDifference = -removedCount
                for addedMessage in addedMessagePeers {
                    if let maxMessageId = attribute.maxMessageId {
                        if addedMessage.messageId.id > maxMessageId {
                            countDifference += 1
                        }
                    } else {
                        countDifference += 1
                    }
                }
                
                let count = max(0, attribute.count + Int32(countDifference))
                var maxMessageId = attribute.maxMessageId
                var maxReadMessageId = attribute.maxReadMessageId
                if let maxAddedId = addedMessagePeers.map({ $0.messageId.id }).max() {
                    if let currentMaxMessageId = maxMessageId {
                        maxMessageId = max(currentMaxMessageId, maxAddedId)
                    } else {
                        maxMessageId = maxAddedId
                    }
                }
                if let maxAddedReadId = addedMessagePeers.filter({ $0.isOutgoing }).map({ $0.messageId.id }).max() {
                    if let currentMaxMessageId = maxReadMessageId {
                        maxReadMessageId = max(currentMaxMessageId, maxAddedReadId)
                    } else {
                        maxReadMessageId = maxAddedReadId
                    }
                }
                
                attributes[j] = ReplyThreadMessageAttribute(count: count, latestUsers: mergeLatestUsers(current: attribute.latestUsers, added: addedMessagePeers.map({ $0.id }), isGroup: isGroup, isEmpty: count == 0), commentsPeerId: attribute.commentsPeerId, maxMessageId: maxMessageId, maxReadMessageId: maxReadMessageId)
            } else if let attribute = attributes[j] as? SourceReferenceMessageAttribute {
                channelThreadMessageId = attribute.messageId
            }
        }
        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
    })
    
    if let channelThreadMessageId = channelThreadMessageId {
        updateMessageThreadStatsInternal(transaction: transaction, threadMessageId: channelThreadMessageId, removedCount: removedCount, addedMessagePeers: addedMessagePeers, allowChannel: true)
    }
}

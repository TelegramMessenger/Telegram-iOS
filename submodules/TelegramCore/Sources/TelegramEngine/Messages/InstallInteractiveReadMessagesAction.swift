import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

func _internal_installInteractiveReadMessagesAction(postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId, threadId: Int64?) -> Disposable {
    return postbox.installStoreMessageAction(peerId: peerId, { messages, transaction in
        var consumeMessageIds: [MessageId] = []
        var readReactionOrPollVotesIds: [MessageId] = []
        
        var readMessageIndexByNamespace: [MessageId.Namespace: MessageIndex] = [:]
        
        for message in messages {
            if case let .Id(id) = message.id {
                if threadId == nil || message.threadId == threadId {
                } else {
                    continue
                }
                
                var hasUnconsumedMention = false
                var hasUnconsumedContent = false
                var hasUnseenReactions = false
                var hasUnseenPollVotes = false
                
                if message.tags.contains(.unseenPersonalMessage) || message.tags.contains(.unseenReaction) || message.tags.contains(.unseenPollVote) {
                    for attribute in message.attributes {
                        if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed, !attribute.pending {
                            hasUnconsumedMention = true
                        } else if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                            hasUnconsumedContent = true
                        } else if let attribute = attribute as? ReactionsMessageAttribute, attribute.hasUnseen {
                            hasUnseenReactions = true
                        }
                    }
                    for media in message.media {
                        if let poll = media as? TelegramMediaPoll {
                            if poll.results.hasUnseenVotes == true {
                                hasUnseenPollVotes = true
                            }
                        }
                    }
                }
                
                if hasUnconsumedMention && !hasUnconsumedContent {
                    consumeMessageIds.append(id)
                }
                if hasUnseenReactions || hasUnseenPollVotes {
                    readReactionOrPollVotesIds.append(id)
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
        
        for id in Set(consumeMessageIds + readReactionOrPollVotesIds) {
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
                var tags = currentMessage.tags
                var media = currentMessage.media
                if readReactionOrPollVotesIds.contains(id) {
                    reactionsLoop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ReactionsMessageAttribute {
                            attributes[j] = attribute.withAllSeen()
                            break reactionsLoop
                        }
                    }
                    pollVoteLoop: for j in 0 ..< media.count {
                        if let poll = media[j] as? TelegramMediaPoll {
                            media[j] = poll.withoutUnreadResults()
                            break pollVoteLoop
                        }
                    }
                    tags.remove(.unseenReaction)
                    tags.remove(.unseenPollVote)
                }
                return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: media))
            })
            
            if consumeMessageIds.contains(id) {
                transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: ConsumePersonalMessageAction())
            }
            if readReactionOrPollVotesIds.contains(id) {
                transaction.setPendingMessageAction(type: .readReactionOrPollVote, id: id, action: ReadReactionAction())
            }
        }
        
        for (_, index) in readMessageIndexByNamespace {
            if let threadId {
                if var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                    if index.id.id >= data.maxIncomingReadId {
                        if let count = transaction.getThreadMessageCount(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, fromIdExclusive: data.maxIncomingReadId, toIndex: index) {
                            data.incomingUnreadCount = max(0, data.incomingUnreadCount - Int32(count))
                            data.maxIncomingReadId = index.id.id
                        }
                        
                        if let topMessageIndex = transaction.getMessageHistoryThreadTopMessage(peerId: peerId, threadId: threadId, namespaces: Set([Namespaces.Message.Cloud])) {
                            if index.id.id >= topMessageIndex.id.id {
                                let containingHole = transaction.getThreadIndexHole(peerId: peerId, threadId: threadId, namespace: topMessageIndex.id.namespace, containing: topMessageIndex.id.id)
                                if let _ = containingHole[.everywhere] {
                                } else {
                                    data.incomingUnreadCount = 0
                                }
                            }
                        }
                        
                        data.maxKnownMessageId = max(data.maxKnownMessageId, index.id.id)
                        
                        if let entry = StoredMessageHistoryThreadInfo(data) {
                            transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
                        }
                    }
                }
            } else {
                _internal_applyMaxReadIndexInteractively(transaction: transaction, stateManager: stateManager, index: index)
            }
        }
    })
}

public struct VisibleMessageRange {
    public var lowerBound: MessageIndex
    public var upperBound: MessageIndex?
    
    public init(lowerBound: MessageIndex, upperBound: MessageIndex?) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
    
    fileprivate func contains(index: MessageIndex) -> Bool {
        if index < lowerBound {
            return false
        }
        if let upperBound = self.upperBound {
            if index > upperBound {
                return false
            }
        }
        return true
    }
}

private final class StoreOrUpdateMessageActionImpl: StoreOrUpdateMessageAction {
    private let getVisibleRange: () -> VisibleMessageRange?
    private let didReadReactionsInMessages: ([MessageId: [ReactionsMessageAttribute.RecentPeer]]) -> Void
    
    init(getVisibleRange: @escaping () -> VisibleMessageRange?, didReadReactionsInMessages: @escaping ([MessageId: [ReactionsMessageAttribute.RecentPeer]]) -> Void) {
        self.getVisibleRange = getVisibleRange
        self.didReadReactionsInMessages = didReadReactionsInMessages
    }
    
    func addOrUpdate(messages: [StoreMessage], transaction: Transaction) {
        var readReactionIds: [MessageId: [ReactionsMessageAttribute.RecentPeer]] = [:]
        var readPollVoteIds = Set<MessageId>()
        
        guard let visibleRange = self.getVisibleRange() else {
            return
        }
        
        for message in messages {
            guard let index = message.index else {
                continue
            }
            if !visibleRange.contains(index: index) {
                continue
            }
            
            if message.tags.contains(.unseenReaction) {
                inner: for attribute in message.attributes {
                    if let attribute = attribute as? ReactionsMessageAttribute, attribute.hasUnseen {
                        readReactionIds[index.id] = attribute.recentPeers
                        break inner
                    }
                }
            }
            if message.tags.contains(.unseenPollVote) {
                readPollVoteIds.insert(index.id)
            }
        }
        
        for id in Set(readReactionIds.keys).union(readPollVoteIds) {
            transaction.updateMessage(id, update: { currentMessage in
                var attributes = currentMessage.attributes
                var media = currentMessage.media
                reactionsLoop: for j in 0 ..< attributes.count {
                    if let attribute = attributes[j] as? ReactionsMessageAttribute {
                        attributes[j] = attribute.withAllSeen()
                        break reactionsLoop
                    }
                }
                pollVotesLoop: for j in 0 ..< media.count {
                    if let poll = media[j] as? TelegramMediaPoll {
                        media[j] = poll.withoutUnreadResults()
                        break pollVotesLoop
                    }
                }
                var tags = currentMessage.tags
                tags.remove(.unseenReaction)
                tags.remove(.unseenPollVote)
                return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: media))
            })
            transaction.setPendingMessageAction(type: .readReactionOrPollVote, id: id, action: ReadReactionAction())
        }
        
        self.didReadReactionsInMessages(readReactionIds)
    }
}

func _internal_installInteractiveReadReactionsAction(postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId, getVisibleRange: @escaping () -> VisibleMessageRange?, didReadReactionsInMessages: @escaping ([MessageId: [ReactionsMessageAttribute.RecentPeer]]) -> Void) -> Disposable {
    return postbox.installStoreOrUpdateMessageAction(peerId: peerId, action: StoreOrUpdateMessageActionImpl(getVisibleRange: getVisibleRange, didReadReactionsInMessages: didReadReactionsInMessages))
}

import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

private final class ChannelStateValidationBatch {
    private let disposable: Disposable
    let invalidatedPts: Int32
    
    var cancelledMessageIds = Set<MessageId>()
    
    init(disposable: Disposable, invalidatedPts: Int32) {
        self.disposable = disposable
        self.invalidatedPts = invalidatedPts
    }
    
    deinit {
        disposable.dispose()
    }
}

private final class ChannelStateValidationContext {
    var batchReferences: [MessageId: ChannelStateValidationBatch] = [:]
}

final class HistoryViewChannelStateValidationContexts {
    private let queue: Queue
    private let postbox: Postbox
    private let network: Network
    
    private var contexts: [Int32: ChannelStateValidationContext] = [:]
    
    init(queue: Queue, postbox: Postbox, network: Network) {
        self.queue = queue
        self.postbox = postbox
        self.network = network
    }
    
    func updateView(id: Int32, view: MessageHistoryView?) {
        assert(self.queue.isCurrent())
        if let view = view {
            var channelState: ChannelState?
            for entry in view.additionalData {
                if case let .peerChatState(_, chatState) = entry {
                    if let chatState = chatState as? ChannelState {
                        channelState = chatState
                    }
                    break
                }
            }
            
            if let invalidatedPts = channelState?.invalidatedPts {
                var invalidatedMessageIds: [MessageId] = []
                var minValidatedPts: Int32?
                
                for entry in view.entries {
                    switch entry {
                        case let .MessageEntry(message, _, _, _):
                            if message.id.namespace == Namespaces.Message.Cloud {
                                var messagePts: Int32?
                                inner: for attribute in message.attributes {
                                    if let attribute = attribute as? ChannelMessageStateVersionAttribute {
                                        messagePts = attribute.pts
                                        break inner
                                    }
                                }
                                if let messagePts = messagePts {
                                    if messagePts < invalidatedPts {
                                        if minValidatedPts == nil || minValidatedPts! > messagePts {
                                            minValidatedPts = messagePts
                                        }
                                        invalidatedMessageIds.append(message.id)
                                    }
                                } else {
                                    invalidatedMessageIds.append(message.id)
                                }
                            }
                        default:
                            break
                    }
                }
                
                if !invalidatedMessageIds.isEmpty {
                    let context: ChannelStateValidationContext
                    if let current = self.contexts[id] {
                        context = current
                    } else {
                        context = ChannelStateValidationContext()
                        self.contexts[id] = context
                    }
                    var messageIdsForBatch: [MessageId] = []
                    for messageId in invalidatedMessageIds {
                        if let batch = context.batchReferences[messageId] {
                            if batch.invalidatedPts < invalidatedPts {
                                batch.cancelledMessageIds.insert(messageId)
                                messageIdsForBatch.append(messageId)
                            }
                        } else {
                            messageIdsForBatch.append(messageId)
                        }
                    }
                    if !messageIdsForBatch.isEmpty {
                        let disposable = MetaDisposable()
                        let batch = ChannelStateValidationBatch(disposable: disposable, invalidatedPts: invalidatedPts)
                        for messageId in messageIdsForBatch {
                            context.batchReferences[messageId] = batch
                        }
                        
                        disposable.set((validateBatch(postbox: self.postbox, network: self.network, messageIds: messageIdsForBatch, minValidatedPts: minValidatedPts)
                            |> deliverOn(self.queue)).start(completed: { [weak self, weak batch] in
                            if let strongSelf = self, let context = strongSelf.contexts[id], let batch = batch {
                                var completedMessageIds: [MessageId] = []
                                for (messageId, messageBatch) in context.batchReferences {
                                    if messageBatch === batch {
                                        completedMessageIds.append(messageId)
                                    }
                                }
                                for messageId in completedMessageIds {
                                    context.batchReferences.removeValue(forKey: messageId)
                                }
                            }
                        }))
                    }
                }
                
                if let context = self.contexts[id] {
                    let messageIds = Set(invalidatedMessageIds)
                    var removeIds: [MessageId] = []
                    
                    for batchMessageId in context.batchReferences.keys {
                        if !messageIds.contains(batchMessageId) {
                            removeIds.append(batchMessageId)
                        }
                    }
                    
                    for messageId in removeIds {
                        context.batchReferences.removeValue(forKey: messageId)
                    }
                }
            }
        } else if self.contexts[id] != nil {
            self.contexts.removeValue(forKey: id)
        }
    }
}

private func validateBatch(postbox: Postbox, network: Network, messageIds: [MessageId], minValidatedPts: Int32?) -> Signal<Void, NoError> {
    guard let peerId = messageIds.first?.peerId else {
        return .never()
    }
    return postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            var ranges: [Api.MessageRange] = []
            var currentRange: (Int32, Int32)?
            for id in messageIds.sorted() {
                if let (minId, maxId) = currentRange {
                    if maxId == id.id - 1 {
                        currentRange = (minId, id.id)
                    } else {
                        ranges.append(Api.MessageRange.messageRange(minId: minId - 1, maxId: maxId + 1))
                        currentRange = (id.id, id.id)
                    }
                } else {
                    currentRange = (id.id, id.id)
                }
            }
            if let (minId, maxId) = currentRange {
                ranges.append(Api.MessageRange.messageRange(minId: minId, maxId: maxId))
            }
            return network.request(Api.functions.updates.getChannelDifference(flags: 0, channel: inputChannel, filter: .channelMessagesFilter(flags: 1 << 1, ranges: ranges), pts: minValidatedPts ?? 1, limit: 100))
                |> `catch` { _ -> Signal<Api.updates.ChannelDifference, NoError> in
                    return .never()
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return postbox.modify { modifier -> Void in
                        let finalPts: Int32
                        var deletedMessageIds: [MessageId] = []
                        var updatedMessages: [MessageId: StoreMessage] = [:]
                        
                        var apiChats: [Api.Chat] = []
                        var apiUsers: [Api.User] = []
                        
                        switch result {
                            case let .channelDifference(_, pts, _, newMessages, otherUpdates, chats, users):
                                finalPts = pts
                                apiChats = chats
                                apiUsers = users
                                
                                for message in newMessages {
                                    if let message = StoreMessage(apiMessage: message), case let .Id(id) = message.id {
                                        updatedMessages[id] = message
                                    }
                                }
                                for update in otherUpdates {
                                    switch update {
                                        case let .updateDeleteChannelMessages(_, messages, _, _):
                                            for messageId in messages {
                                                deletedMessageIds.append(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageId))
                                            }
                                        case let .updateNewChannelMessage(message, _, _):
                                            if let message = StoreMessage(apiMessage: message), case let .Id(id) = message.id {
                                                updatedMessages[id] = message
                                            }
                                        case let .updateEditChannelMessage(message, _, _):
                                            if let message = StoreMessage(apiMessage: message), case let .Id(id) = message.id {
                                                updatedMessages[id] = message
                                            }
                                        default:
                                            break
                                    }
                                }
                            case let .channelDifferenceEmpty(_, pts, _):
                                finalPts = pts
                            case let .channelDifferenceTooLong(_, pts, _, _, _, _, _, _, _, _, _):
                                finalPts = pts
                        }
                        
                        var peers: [Peer] = []
                        var peerPresences: [PeerId: PeerPresence] = [:]
                        for chat in apiChats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(groupOrChannel)
                            }
                        }
                        for user in apiUsers {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            if let presence = TelegramUserPresence(apiUser: user) {
                                peerPresences[telegramUser.id] = presence
                            }
                        }
                        
                        updatePeers(modifier: modifier, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        modifier.updatePeerPresences(peerPresences)
                        
                        if !deletedMessageIds.isEmpty {
                            modifier.deleteMessages(deletedMessageIds)
                        }
                        
                        for (messageId, message) in updatedMessages {
                            modifier.updateMessage(messageId, update: { _ in
                                var attributes = message.attributes
                                for j in 0 ..< attributes.count {
                                    if let _ = attributes[j] as? ChannelMessageStateVersionAttribute {
                                        attributes.remove(at: j)
                                        break
                                    }
                                }
                                attributes.append(ChannelMessageStateVersionAttribute(pts: finalPts))
                                return .update(StoreMessage(id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributes: attributes, media: message.media))
                            })
                        }
                        
                        for messageId in messageIds {
                            if updatedMessages[messageId] == nil {
                                modifier.updateMessage(messageId, update: { currentMessage in
                                    var storeForwardInfo: StoreMessageForwardInfo?
                                    if let forwardInfo = currentMessage.forwardInfo {
                                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                                    }
                                    var attributes = currentMessage.attributes
                                    for j in 0 ..< attributes.count {
                                        if let _ = attributes[j] as? ChannelMessageStateVersionAttribute {
                                            attributes.remove(at: j)
                                            break
                                        }
                                    }
                                    attributes.append(ChannelMessageStateVersionAttribute(pts: finalPts))
                                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                })
                            }
                        }
                    }
                }
        } else {
            return .never()
        }
    } |> switchToLatest
}

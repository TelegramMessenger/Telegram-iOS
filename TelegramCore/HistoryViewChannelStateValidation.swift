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
        if let view = view, view.tagMask == nil {
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
                var rangesToInvalidate: [[MessageId]] = []
                let addToRange: (MessageId, inout [[MessageId]]) -> Void = { id, ranges in
                    if ranges.isEmpty {
                        ranges = [[id]]
                    } else {
                        ranges[rangesToInvalidate.count - 1].append(id)
                    }
                }
                
                let addRangeBreak: (inout [[MessageId]]) -> Void = { ranges in
                    if ranges.last?.count != 0 {
                        ranges.append([])
                    }
                }
                
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
                                var requiresValidation = false
                                if let messagePts = messagePts {
                                    if messagePts < invalidatedPts {
                                        requiresValidation = true
                                    }
                                } else {
                                    requiresValidation = true
                                }
                                
                                if requiresValidation {
                                    addToRange(message.id, &rangesToInvalidate)
                                } else {
                                    addRangeBreak(&rangesToInvalidate)
                                }
                            }
                        case let .HoleEntry(hole, _):
                            if hole.maxIndex.id.namespace == Namespaces.Message.Cloud {
                                addRangeBreak(&rangesToInvalidate)
                            }
                    }
                }
                
                if !rangesToInvalidate.isEmpty && rangesToInvalidate[rangesToInvalidate.count - 1].isEmpty {
                    rangesToInvalidate.removeLast()
                }
                
                var invalidatedMessageIds = Set<MessageId>()
                
                if !rangesToInvalidate.isEmpty {
                    let context: ChannelStateValidationContext
                    if let current = self.contexts[id] {
                        context = current
                    } else {
                        context = ChannelStateValidationContext()
                        self.contexts[id] = context
                    }
                    
                    var addedRanges: [[MessageId]] = []
                    for messages in rangesToInvalidate {
                        for id in messages {
                            if context.batchReferences[id] != nil {
                                addRangeBreak(&addedRanges)
                            } else {
                                addToRange(id, &addedRanges)
                            }
                        }
                    }
                    
                    if !addedRanges.isEmpty && addedRanges[rangesToInvalidate.count - 1].isEmpty {
                        addedRanges.removeLast()
                    }
                    
                    for messages in addedRanges {
                        let disposable = MetaDisposable()
                        let batch = ChannelStateValidationBatch(disposable: disposable, invalidatedPts: invalidatedPts)
                        for messageId in messages {
                            context.batchReferences[messageId] = batch
                        }
                        
                        disposable.set((validateBatch(postbox: self.postbox, network: self.network, messageIds: messages)
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
                    
                    /*var messageIdsForBatch: [MessageId] = []
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
                    }*/
                }
                
                if let context = self.contexts[id] {
                    var removeIds: [MessageId] = []
                    
                    for batchMessageId in context.batchReferences.keys {
                        if !invalidatedMessageIds.contains(batchMessageId) {
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

private func hashForMessages(_ messages: [Message]) -> Int32 {
    var acc: UInt32 = 0
    
    for message in messages {
        acc = (acc &* 20261) &+ message.id.id
        var timestamp = message.timestamp
        inner: for attribute in message.attributes {
            if let attribute = attribute as? EditedMessageAttribute {
                timestamp = attribute.date
                break inner
            }
        }
        acc = (acc &* 20261) &+ timestamp
    }
    return Int32(bitPattern: acc & UInt32(0x7FFFFFFF))
}

private func validateBatch(postbox: Postbox, network: Network, messageIds: [MessageId]) -> Signal<Void, NoError> {
    guard let peerId = messageIds.first?.peerId else {
        return .never()
    }
    return postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var messages: [Message] = []
            for messageId in messageIds {
                if let message = modifier.getMessage(messageId) {
                    messages.append(message)
                }
            }
            let hash = hashForMessages(messages)
            return network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: messageIds[messageIds.count - 1].id, offsetDate: 0, addOffset: 0, limit: 100, maxId: messageIds[messageIds.cout - 1].id, minId: messageIds[0].id, hash: hash))
            |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Void, NoError> in
                return postbox.modify { modifier -> Void in
                    if let result = result {
                        switch result {
                            case .messagesNotModified:
                                break
                            
                        }
                    }
                }
            }
        } else {
            return .never()
        }
    } |> switchToLatest
}

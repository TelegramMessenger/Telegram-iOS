import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public struct PendingMessageStatus: Equatable {
    public let progress: Float
    
    public static func ==(lhs: PendingMessageStatus, rhs: PendingMessageStatus) -> Bool {
        return lhs.progress.isEqual(to: rhs.progress)
    }
}

private final class PendingMessageContext {
    var disposable: Disposable?
    var status: PendingMessageStatus?
    var statusSubscribers = Bag<(PendingMessageStatus?) -> Void>()
}

private enum PendingMessageResult {
    case progress(Float)
}

private final class PendingMessageRequestDependencyTag: NetworkRequestDependencyTag {
    let messageId: MessageId
    
    init(messageId: MessageId) {
        self.messageId = messageId
    }
    
    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool {
        if let other = other as? PendingMessageRequestDependencyTag, self.messageId.peerId == other.messageId.peerId && self.messageId.namespace == other.messageId.namespace {
            return self.messageId.id > other.messageId.id
        }
        return false
    }
}

private func sendMessageContent(network: Network, postbox: Postbox, stateManager: StateManager, message: Message, content: PendingMessageUploadedContent) -> Signal<Void, NoError> {
    let peer = postbox.loadedPeerWithId(message.id.peerId)
        |> take(1)
        
    return peer
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputPeer = apiInputPeer(peer) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                
                var replyMessageId: Int32?
                for attribute in message.attributes {
                    if let replyAttribute = attribute as? ReplyMessageAttribute {
                        replyMessageId = replyAttribute.messageId.id
                        break
                    }
                }
                
                var flags: Int32 = 0
                if let replyMessageId = replyMessageId {
                    flags |= Int32(1 << 0)
                }
                
                let dependencyTag = PendingMessageRequestDependencyTag(messageId: message.id)
                
                var sendMessageRequest: Signal<Api.Updates, NoError>
                switch content {
                    case let .text(text):
                        sendMessageRequest = network.request(Api.functions.messages.sendMessage(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, message: message.text, randomId: randomId, replyMarkup: nil, entities: nil), tag: dependencyTag)
                            |> mapError { _ -> NoError in
                                return NoError()
                            }
                    case let .media(inputMedia):
                        sendMessageRequest = network.request(Api.functions.messages.sendMedia(flags: 0, peer: inputPeer, replyToMsgId: replyMessageId, media: inputMedia, randomId: randomId, replyMarkup: nil), tag: dependencyTag)
                            |> mapError { _ -> NoError in
                                return NoError()
                            }
                }
                
                return sendMessageRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return applySentMessage(postbox: postbox, stateManager: stateManager, message: message, result: result)
                    }
                    |> `catch` { _ -> Signal<Void, NoError> in
                        let modify = postbox.modify { modifier -> Void in
                            modifier.updateMessage(message.id, update: { currentMessage in
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                                }
                                return StoreMessage(id: message.id, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media)
                            })
                        }
                        
                        return modify
                    }
            } else {
                return .complete()
            }
        }
}

private func applySentMessage(postbox: Postbox, stateManager: StateManager, message: Message, result: Api.Updates) -> Signal<Void, NoError> {
    let messageId = result.rawMessageIds.first
    let apiMessage = result.messages.first
    
    return postbox.modify { modifier -> Void in
        var updatedTimestamp: Int32?
        if let apiMessage = apiMessage {
            switch apiMessage {
                case let .message(_, _, _, _, _, _, _, date, _, _, _, _, _, _):
                    updatedTimestamp = date
                case .messageEmpty:
                    break
                case let .messageService(_, _, _, _, _, date, _):
                    updatedTimestamp = date
            }
        } else {
            switch result {
                case let .updateShortSentMessage(_, _, _, _, date, _, _):
                    updatedTimestamp = date
                default:
                    break
            }
        }

        modifier.updateMessage(message.id, update: { currentMessage in
            let updatedId: MessageId
            if let messageId = messageId {
                updatedId = MessageId(peerId: currentMessage.id.peerId, namespace: Namespaces.Message.Cloud, id: messageId)
            } else {
                updatedId = currentMessage.id
            }
            
            let media: [Media]
            let attributes: [MessageAttribute]
            let text: String
            if let apiMessage = apiMessage, let updatedMessage = StoreMessage(apiMessage: apiMessage) {
                media = updatedMessage.media
                attributes = updatedMessage.attributes
                text = updatedMessage.text
            } else if case let .updateShortSentMessage(_, _, _, _, _, apiMedia, entities) = result {
                let (_, mediaValue) = textAndMediaFromApiMedia(apiMedia)
                if let mediaValue = mediaValue {
                    media = [mediaValue]
                } else {
                    media = []
                }
                
                var updatedAttributes: [MessageAttribute] = currentMessage.attributes
                if let entities = entities, !entities.isEmpty {
                    for i in 0 ..< updatedAttributes.count {
                        if updatedAttributes[i] is TextEntitiesMessageAttribute {
                            updatedAttributes.remove(at: i)
                            break
                        }
                    }
                    updatedAttributes.append(TextEntitiesMessageAttribute(entities: messageTextEntitiesFromApiEntities(entities)))
                }
                attributes = updatedAttributes
                text = currentMessage.text
            } else {
                media = currentMessage.media
                attributes = currentMessage.attributes
                text = currentMessage.text
            }
            
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
            }
            
            if let fromMedia = currentMessage.media.first, let toMedia = media.first {
                applyMediaResourceChanges(from: fromMedia, to: toMedia, postbox: postbox)
            }
            
            return StoreMessage(id: updatedId, timestamp: updatedTimestamp ?? currentMessage.timestamp, flags: [], tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: text, attributes: attributes, media: media)
        })
        if let updatedTimestamp = updatedTimestamp {
            modifier.offsetPendingMessagesTimestamps(lowerBound: message.id, timestamp: updatedTimestamp)
        }
    } |> afterDisposed {
        stateManager.addUpdates(result)
    }
}

private func applyMediaResourceChanges(from: Media, to: Media, postbox: Postbox) {
    if let fromImage = from as? TelegramMediaImage, let toImage = to as? TelegramMediaImage {
        if let fromLargestRepresentation = largestImageRepresentation(fromImage.representations), let toLargestRepresentation = largestImageRepresentation(toImage.representations) {
            postbox.mediaBox.moveResourceData(from: fromLargestRepresentation.resource.id, to: toLargestRepresentation.resource.id)
        }
    }
}

public final class PendingMessageManager {
    private let network: Network
    private let postbox: Postbox
    private let stateManager: StateManager
    
    private let queue = Queue()
    
    private var messageContexts: [MessageId: PendingMessageContext] = [:]
    private var pendingMessageIds = Set<MessageId>()
    
    init(network: Network, postbox: Postbox, stateManager: StateManager) {
        self.network = network
        self.postbox = postbox
        self.stateManager = stateManager
    }
    
    func updatePendingMessageIds(_ messageIds: Set<MessageId>) {
        self.queue.async {
            let addedMessageIds = messageIds.subtracting(self.pendingMessageIds)
            let removedMessageIds = self.pendingMessageIds.subtracting(messageIds)
            
            for id in removedMessageIds {
                if let context = self.messageContexts[id] {
                    context.disposable?.dispose()
                    context.disposable = nil
                    if context.statusSubscribers.isEmpty {
                        self.messageContexts.removeValue(forKey: id)
                    }
                }
            }
            
            if !addedMessageIds.isEmpty {
                for id in addedMessageIds {
                    self.beginSendingMessage(id)
                }
            }
            
            self.pendingMessageIds = messageIds
        }
    }
    
    public func pendingMessageStatus(_ id: MessageId) -> Signal<PendingMessageStatus?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.async {
                let messageContext: PendingMessageContext
                if let current = self.messageContexts[id] {
                    messageContext = current
                } else {
                    messageContext = PendingMessageContext()
                    self.messageContexts[id] = messageContext
                }
                
                let index = messageContext.statusSubscribers.add({ status in
                    subscriber.putNext(status)
                })
                
                subscriber.putNext(messageContext.status)
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        if let current = self.messageContexts[id] {
                            current.statusSubscribers.remove(index)
                            if current.statusSubscribers.isEmpty && current.disposable == nil {
                                self.messageContexts.removeValue(forKey: id)
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
    }
    
    private func beginSendingMessage(_ id: MessageId) {
        assert(self.queue.isCurrent())
        
        let messageContext: PendingMessageContext
        if let current = self.messageContexts[id] {
            messageContext = current
        } else {
            messageContext = PendingMessageContext()
            self.messageContexts[id] = messageContext
        }
        
        assert(messageContext.disposable == nil)
        
        let status = PendingMessageStatus(progress: 0.0)
        if status != messageContext.status {
            messageContext.status = status
            for subscriber in messageContext.statusSubscribers.copyItems() {
                subscriber(status)
            }
        }
        
        let uploadedContent = self.postbox.messageAtId(id)
            |> take(1)
            |> mapToSignal { [weak self] message -> Signal<PendingMessageUploadedContentResult, NoError> in
                if let strongSelf = self, let message = message {
                    return uploadedMessageContent(network: strongSelf.network, postbox: strongSelf.postbox, message: message)
                } else {
                    return .complete()
                }
            }
        
        let peer = self.postbox.loadedPeerWithId(id.peerId)
            |> take(1)
        
        let sendMessage = uploadedContent
            |> mapToSignal { [weak self] contentResult -> Signal<PendingMessageResult, NoError> in
                if let strongSelf = self {
                    switch contentResult {
                        case let .progress(progress):
                            return .single(.progress(progress))
                        case let .content(message, content):
                            return sendMessageContent(network: strongSelf.network, postbox: strongSelf.postbox, stateManager: strongSelf.stateManager, message: message, content: content)
                                |> map { next -> PendingMessageResult in
                                    return .progress(1.0)
                                }
                    }
                } else {
                    return .complete()
                }
            }
        
        messageContext.disposable = (sendMessage |> deliverOn(self.queue)).start(next: { [weak self] next in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                
                switch next {
                    case let .progress(progress):
                        if let current = strongSelf.messageContexts[id] {
                            let status = PendingMessageStatus(progress: progress)
                            current.status = status
                            for subscriber in current.statusSubscribers.copyItems() {
                                subscriber(status)
                            }
                        }
                }
            }
        }, error: { [weak self] error in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                if let current = strongSelf.messageContexts[id] {
                    current.disposable = nil
                    for subscriber in current.statusSubscribers.copyItems() {
                        subscriber(nil)
                    }
                    if current.statusSubscribers.isEmpty {
                        strongSelf.messageContexts.removeValue(forKey: id)
                    }
                }
            }
        }, completed: { [weak self] in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                if let current = strongSelf.messageContexts[id] {
                    current.disposable = nil
                    for subscriber in current.statusSubscribers.copyItems() {
                        subscriber(nil)
                    }
                    if current.statusSubscribers.isEmpty {
                        strongSelf.messageContexts.removeValue(forKey: id)
                    }
                }
            }
        })
    }
}

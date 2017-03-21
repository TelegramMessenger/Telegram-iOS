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

private enum PendingMessageState {
    case none
    case waitingForUploadToStart(Signal<PendingMessageUploadedContentResult, NoError>)
    case uploading
    case sending
}

private final class PendingMessageContext {
    var state: PendingMessageState = .none
    let disposable = MetaDisposable()
    var status: PendingMessageStatus?
    var statusSubscribers = Bag<(PendingMessageStatus?) -> Void>()
}

private final class PeerPendingMessagesSummaryContext {
    var messageDeliveredSubscribers = Bag<(Void) -> Void>()
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

public final class PendingMessageManager {
    private let network: Network
    private let postbox: Postbox
    private let stateManager: AccountStateManager
    
    private let queue = Queue()
    
    private var messageContexts: [MessageId: PendingMessageContext] = [:]
    private var pendingMessageIds = Set<MessageId>()
    private let beginSendingMessagesDisposables = DisposableSet()
    
    private var peerSummaryContexts: [PeerId: PeerPendingMessagesSummaryContext] = [:]
    
    var transformOutgoingMessageMedia: TransformOutgoingMessageMedia?
    
    init(network: Network, postbox: Postbox, stateManager: AccountStateManager) {
        self.network = network
        self.postbox = postbox
        self.stateManager = stateManager
    }
    
    deinit {
        self.beginSendingMessagesDisposables.dispose()
    }
    
    func updatePendingMessageIds(_ messageIds: Set<MessageId>) {
        self.queue.async {
            let addedMessageIds = messageIds.subtracting(self.pendingMessageIds)
            let removedMessageIds = self.pendingMessageIds.subtracting(messageIds)
            
            var updateUploadingPeerIds = Set<PeerId>()
            for id in removedMessageIds {
                if let context = self.messageContexts[id] {
                    context.state = .none
                    updateUploadingPeerIds.insert(id.peerId)
                    context.disposable.dispose()
                    if context.statusSubscribers.isEmpty {
                        self.messageContexts.removeValue(forKey: id)
                    }
                }
            }
            
            if !addedMessageIds.isEmpty {
                self.beginSendingMessages(Array(addedMessageIds).sorted())
            }
            
            self.pendingMessageIds = messageIds
            
            if !updateUploadingPeerIds.isEmpty {
                for peerId in updateUploadingPeerIds {
                    self.updateWaitingUploads(peerId: peerId)
                }
            }
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
                            if case .none = current.status, current.statusSubscribers.isEmpty {
                                self.messageContexts.removeValue(forKey: id)
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
    }
    
    private func canBeginUploadingMessage(id: MessageId) -> Bool {
        assert(self.queue.isCurrent())
        
        let messageIdsForPeer: [MessageId] = self.messageContexts.keys.filter({ $0.peerId == id.peerId }).sorted()
        for contextId in messageIdsForPeer {
            if contextId < id {
                let context = self.messageContexts[contextId]!
                if case .uploading = context.state {
                    return false
                }
            } else {
                break
            }
        }
        
        return true
    }
    
    private func beginSendingMessages(_ ids: [MessageId]) {
        assert(self.queue.isCurrent())
        
        for id in ids {
            let messageContext: PendingMessageContext
            if let current = self.messageContexts[id] {
                messageContext = current
            } else {
                messageContext = PendingMessageContext()
                self.messageContexts[id] = messageContext
            }
            
            let status = PendingMessageStatus(progress: 0.0)
            if status != messageContext.status {
                messageContext.status = status
                for subscriber in messageContext.statusSubscribers.copyItems() {
                    subscriber(status)
                }
            }
        }
        
        let disposable = MetaDisposable()
        let messages = self.postbox.messagesAtIds(ids)
            |> deliverOn(self.queue)
            |> afterDisposed { [weak self, weak disposable] in
                if let strongSelf = self, let strongDisposable = disposable {
                    strongSelf.beginSendingMessagesDisposables.remove(strongDisposable)
                }
            }
        self.beginSendingMessagesDisposables.add(disposable)
        disposable.set(messages.start(next: { [weak self] messages in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                
                for message in messages.sorted(by: { $0.id < $1.id }) {
                    guard let messageContext = strongSelf.messageContexts[message.id] else {
                        continue
                    }
                    
                    if message.flags.contains(.Sending) {
                        continue
                    }
                    
                    let contentToUpload = messageContentToUpload(network: strongSelf.network, postbox: strongSelf.postbox, transformOutgoingMessageMedia: strongSelf.transformOutgoingMessageMedia, message: message)
                    
                    switch contentToUpload {
                        case let .ready(message, content):
                            strongSelf.beginSendingMessage(messageContext: messageContext, message: message, content: content)
                        case let .upload(uploadSignal):
                            if strongSelf.canBeginUploadingMessage(id: message.id) {
                                strongSelf.beginUploadingMessage(messageContext: messageContext, id: message.id, uploadSignal: uploadSignal)
                            } else {
                                messageContext.state = .waitingForUploadToStart(uploadSignal)
                            }
                    }
                    
                    /*let uploadedContent = uploadedMessageContent(network: strongSelf.network, postbox: strongSelf.postbox, transformOutgoingMessageMedia: strongSelf.transformOutgoingMessageMedia, message: message)
                    
                    let sendMessage = uploadedContent
                        |> mapToSignal { contentResult -> Signal<PendingMessageResult, NoError> in
                            if let strongSelf = self {
                                switch contentResult {
                                    case let .progress(progress):
                                        return .single(.progress(progress))
                                    case let .content(message, content):
                                        return strongSelf.sendMessageContent(network: strongSelf.network, postbox: strongSelf.postbox, stateManager: strongSelf.stateManager, message: message, content: content)
                                            |> map { next -> PendingMessageResult in
                                                return .progress(1.0)
                                            }
                                }
                            } else {
                                return .complete()
                            }
                    }
                    
                    messageContext.disposable.set((sendMessage |> deliverOn(strongSelf.queue) |> afterDisposed {
                        if let strongSelf = self {
                            assert(strongSelf.queue.isCurrent())
                            if let current = strongSelf.messageContexts[message.id] {
                                for subscriber in current.statusSubscribers.copyItems() {
                                    subscriber(nil)
                                }
                                if current.statusSubscribers.isEmpty {
                                    strongSelf.messageContexts.removeValue(forKey: message.id)
                                }
                            }
                        }
                    }).start(next: { next in
                        if let strongSelf = self {
                            assert(strongSelf.queue.isCurrent())
                            
                            switch next {
                                case let .progress(progress):
                                    if let current = strongSelf.messageContexts[message.id] {
                                        let status = PendingMessageStatus(progress: progress)
                                        current.status = status
                                        for subscriber in current.statusSubscribers.copyItems() {
                                            subscriber(status)
                                        }
                                    }
                            }
                        }
                    }))*/
                }
            }
        }))
    }
    
    private func beginSendingMessage(messageContext: PendingMessageContext, message: Message, content: PendingMessageUploadedContent) {
        messageContext.state = .sending
        let sendMessage: Signal<PendingMessageResult, NoError> = self.sendMessageContent(network: self.network, postbox: self.postbox, stateManager: self.stateManager, message: message, content: content)
            |> map { next -> PendingMessageResult in
                return .progress(1.0)
            }
        messageContext.disposable.set((sendMessage |> deliverOn(self.queue) |> afterDisposed { [weak self] in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                if let current = strongSelf.messageContexts[message.id] {
                    current.status = .none
                    for subscriber in current.statusSubscribers.copyItems() {
                        subscriber(nil)
                    }
                    if current.statusSubscribers.isEmpty {
                        strongSelf.messageContexts.removeValue(forKey: message.id)
                    }
                }
            }
        }).start(next: { [weak self] next in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                
                switch next {
                case let .progress(progress):
                    if let current = strongSelf.messageContexts[message.id] {
                        let status = PendingMessageStatus(progress: progress)
                        current.status = status
                        for subscriber in current.statusSubscribers.copyItems() {
                            subscriber(status)
                        }
                    }
                }
            }
        }))
    }
    
    private func beginUploadingMessage(messageContext: PendingMessageContext, id: MessageId, uploadSignal: Signal<PendingMessageUploadedContentResult, NoError>) {
        messageContext.state = .uploading
        
        messageContext.disposable.set((uploadSignal |> deliverOn(self.queue)).start(next: { [weak self] next in
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
                    case let .content(message, content):
                        if let current = strongSelf.messageContexts[id] {
                            strongSelf.beginSendingMessage(messageContext: current, message: message, content: content)
                            strongSelf.updateWaitingUploads(peerId: id.peerId)
                        }
                }
            }
        }))
    }
    
    private func updateWaitingUploads(peerId: PeerId) {
        assert(self.queue.isCurrent())
        
        let messageIdsForPeer: [MessageId] = self.messageContexts.keys.filter({ $0.peerId == peerId }).sorted()
        loop: for contextId in messageIdsForPeer {
            let context = self.messageContexts[contextId]!
            if case let .waitingForUploadToStart(uploadSignal) = context.state {
                if self.canBeginUploadingMessage(id: contextId) {
                    context.state = .uploading
                    context.disposable.set((uploadSignal |> deliverOn(self.queue)).start(next: { [weak self] next in
                        if let strongSelf = self {
                            assert(strongSelf.queue.isCurrent())
                            
                            switch next {
                                case let .progress(progress):
                                    if let current = strongSelf.messageContexts[contextId] {
                                        let status = PendingMessageStatus(progress: progress)
                                        current.status = status
                                        for subscriber in current.statusSubscribers.copyItems() {
                                            subscriber(status)
                                        }
                                    }
                                case let .content(message, content):
                                    if let current = strongSelf.messageContexts[message.id] {
                                        current.state = .sending
                                        
                                        current.disposable.set((strongSelf.sendMessageContent(network: strongSelf.network, postbox: strongSelf.postbox, stateManager: strongSelf.stateManager, message: message, content: content)
                                            |> map { next -> PendingMessageResult in
                                                return .progress(1.0)
                                            } |> deliverOn(strongSelf.queue)).start(next: { next in
                                                if let strongSelf = self {
                                                    assert(strongSelf.queue.isCurrent())
                                                    
                                                    switch next {
                                                        case let .progress(progress):
                                                            if let current = strongSelf.messageContexts[message.id] {
                                                                let status = PendingMessageStatus(progress: progress)
                                                                current.status = status
                                                                for subscriber in current.statusSubscribers.copyItems() {
                                                                    subscriber(status)
                                                                }
                                                            }
                                                    }
                                                }
                                            }))
                                    }
                            }
                        }
                    }))
                }
                break loop
            }
        }
    }
    
    private func sendMessageContent(network: Network, postbox: Postbox, stateManager: AccountStateManager, message: Message, content: PendingMessageUploadedContent) -> Signal<Void, NoError> {
        return postbox.modify { [weak self] modifier -> Signal<Void, NoError> in
            if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                var secretFile: SecretChatOutgoingFile?
                switch content {
                    case let .secretMedia(file, size, key):
                        if let fileReference = SecretChatOutgoingFileReference(file) {
                            secretFile = SecretChatOutgoingFile(reference: fileReference, size: size, key: key)
                        }
                    default:
                        break
                }
                
                var layer: SecretChatLayer?
                let state = modifier.getPeerChatState(message.id.peerId) as? SecretChatState
                if let state = state {
                    switch state.embeddedState {
                        case .terminated, .handshake:
                            break
                        case .basicLayer:
                            layer = .layer8
                        case let .sequenceBasedLayer(sequenceState):
                            layer = SecretChatLayer(rawValue: sequenceState.layerNegotiationState.activeLayer)
                    }
                }
                
                if let state = state, let layer = layer {
                    var sentAsAction = false
                    for media in message.media {
                        if let media = media as? TelegramMediaAction {
                            if case let .messageAutoremoveTimeoutUpdated(value) = media.action {
                                sentAsAction = true
                                let updatedState = addSecretChatOutgoingOperation(modifier: modifier, peerId: message.id.peerId, operation: .setMessageAutoremoveTimeout(layer: layer, actionGloballyUniqueId: message.globallyUniqueId!, timeout: value, messageId: message.id), state: state)
                                if updatedState != state {
                                    modifier.setPeerChatState(message.id.peerId, state: updatedState)
                                }
                                modifier.updateMessage(message.id, update: { currentMessage in
                                    var flags = StoreMessageFlags(message.flags)
                                    if !flags.contains(.Failed) {
                                        flags.insert(.Sending)
                                    }
                                    var storeForwardInfo: StoreMessageForwardInfo?
                                    if let forwardInfo = currentMessage.forwardInfo {
                                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                                    }
                                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: flags, tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                                })
                            }
                            break
                        }
                    }
                    
                    if !sentAsAction {
                        let updatedState = addSecretChatOutgoingOperation(modifier: modifier, peerId: message.id.peerId, operation: .sendMessage(layer: layer, id: message.id, file: secretFile), state: state)
                        if updatedState != state {
                            modifier.setPeerChatState(message.id.peerId, state: updatedState)
                        }
                        modifier.updateMessage(message.id, update: { currentMessage in
                            var flags = StoreMessageFlags(message.flags)
                            if !flags.contains(.Failed) {
                                flags.insert(.Sending)
                            }
                            var storeForwardInfo: StoreMessageForwardInfo?
                            if let forwardInfo = currentMessage.forwardInfo {
                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                            }
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: flags, tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                        })
                    }
                } else {
                    modifier.updateMessage(message.id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                        }
                        return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                    })
                }
                return .complete()
            } else if let peer = modifier.getPeer(message.id.peerId), let inputPeer = apiInputPeer(peer) {
                var uniqueId: Int64 = 0
                var forwardSourceInfoAttribute: ForwardSourceInfoAttribute?
                var messageEntities: [Api.MessageEntity]?
                var replyMessageId: Int32?
                
                var flags: Int32 = 0
                
                for attribute in message.attributes {
                    if let replyAttribute = attribute as? ReplyMessageAttribute {
                        replyMessageId = replyAttribute.messageId.id
                    } else if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                        uniqueId = outgoingInfo.uniqueId
                    } else if let attribute = attribute as? ForwardSourceInfoAttribute {
                        forwardSourceInfoAttribute = attribute
                    } else if let attribute = attribute as? TextEntitiesMessageAttribute {
                        messageEntities = apiTextAttributeEntities(attribute, associatedPeers: message.peers)
                    } else if let attribute = attribute as? OutgoingContentInfoMessageAttribute {
                        if attribute.flags.contains(.disableLinkPreviews) {
                            flags |= Int32(1 << 1)
                        }
                    }
                }
                
                if let _ = replyMessageId {
                    flags |= Int32(1 << 0)
                }
                if let _ = messageEntities {
                    flags |= Int32(1 << 3)
                }
                
                let dependencyTag = PendingMessageRequestDependencyTag(messageId: message.id)
                
                let sendMessageRequest: Signal<Api.Updates, NoError>
                switch content {
                    case .text:
                        sendMessageRequest = network.request(Api.functions.messages.sendMessage(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, message: message.text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities), tag: dependencyTag)
                            |> mapError { _ -> NoError in
                                return NoError()
                            }
                    case let .media(inputMedia):
                        sendMessageRequest = network.request(Api.functions.messages.sendMedia(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, media: inputMedia, randomId: uniqueId, replyMarkup: nil), tag: dependencyTag)
                            |> mapError { _ -> NoError in
                                return NoError()
                            }
                    case let .forward(sourceInfo):
                        if let forwardSourceInfoAttribute = forwardSourceInfoAttribute, let sourcePeer = modifier.getPeer(forwardSourceInfoAttribute.messageId.peerId), let sourceInputPeer = apiInputPeer(sourcePeer) {
                            sendMessageRequest = network.request(Api.functions.messages.forwardMessages(flags: 0, fromPeer: sourceInputPeer, id: [sourceInfo.messageId.id], randomId: [uniqueId], toPeer: inputPeer), tag: dependencyTag)
                                |> mapError { _ -> NoError in
                                    return NoError()
                                }
                        } else {
                            sendMessageRequest = .fail(NoError())
                        }
                    case let .chatContextResult(chatContextResult):
                        sendMessageRequest = network.request(Api.functions.messages.sendInlineBotResult(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, randomId: uniqueId, queryId: chatContextResult.queryId, id: chatContextResult.id))
                            |> mapError { _ -> NoError in
                                return NoError()
                            }
                    case .secretMedia:
                        assertionFailure()
                        sendMessageRequest = .fail(NoError())
                }
                
                return sendMessageRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        if let strongSelf = self {
                            return strongSelf.applySentMessage(postbox: postbox, stateManager: stateManager, message: message, result: result)
                        } else {
                            return .never()
                        }
                    }
                    |> `catch` { _ -> Signal<Void, NoError> in
                        let modify = postbox.modify { modifier -> Void in
                            modifier.updateMessage(message.id, update: { currentMessage in
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                                }
                                return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                            })
                        }
                        
                        return modify
                }
            } else {
                return postbox.modify { modifier -> Void in
                    modifier.updateMessage(message.id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                        }
                        return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                    })
                }
            }
        } |> switchToLatest
    }
    
    private func applySentMessage(postbox: Postbox, stateManager: AccountStateManager, message: Message, result: Api.Updates) -> Signal<Void, NoError> {
        return applyUpdateMessage(postbox: postbox, stateManager: stateManager, message: message, result: result) |> afterDisposed { [weak self] in
            if let strongSelf = self {
                strongSelf.queue.async {
                    if let context = strongSelf.peerSummaryContexts[message.id.peerId] {
                        for subscriber in context.messageDeliveredSubscribers.copyItems() {
                            subscriber(Void())
                        }
                    }
                }
            }
        }
    }
    
    public func deliveredMessageEvents(peerId: PeerId) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.async {
                let summaryContext: PeerPendingMessagesSummaryContext
                if let current = self.peerSummaryContexts[peerId] {
                    summaryContext = current
                } else {
                    summaryContext = PeerPendingMessagesSummaryContext()
                    self.peerSummaryContexts[peerId] = summaryContext
                }
                
                let index = summaryContext.messageDeliveredSubscribers.add({ _ in
                    subscriber.putNext(true)
                })
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        if let current = self.peerSummaryContexts[peerId] {
                            current.messageDeliveredSubscribers.remove(index)
                            if current.messageDeliveredSubscribers.isEmpty {
                                self.peerSummaryContexts.removeValue(forKey: peerId)
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
    }
}

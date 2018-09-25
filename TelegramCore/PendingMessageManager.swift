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

public struct PendingMessageStatus: Equatable {
    public let isRunning: Bool
    public let progress: Float
    
    public static func ==(lhs: PendingMessageStatus, rhs: PendingMessageStatus) -> Bool {
        return lhs.isRunning == rhs.isRunning && lhs.progress.isEqual(to: rhs.progress)
    }
}

private enum PendingMessageState {
    case none
    case waitingForUploadToStart(groupId: Int64?, upload: Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>)
    case uploading(groupId: Int64?)
    case waitingToBeSent(groupId: Int64?, content: PendingMessageUploadedContentAndReuploadInfo)
    case sending(groupId: Int64?)
    
    var groupId: Int64? {
        switch self {
            case .none:
                return nil
            case let .waitingForUploadToStart(groupId, _):
                return groupId
            case let .uploading(groupId):
                return groupId
            case let .waitingToBeSent(groupId, _):
                return groupId
            case let .sending(groupId):
                return groupId
        }
    }
}

private final class PendingMessageContext {
    var state: PendingMessageState = .none
    let uploadDisposable = MetaDisposable()
    let sendDisposable = MetaDisposable()
    var activityType: PeerInputActivity? = nil
    var contentType: PendingMessageUploadedContentType? = nil
    let activityDisposable = MetaDisposable()
    var status: PendingMessageStatus?
    var statusSubscribers = Bag<(PendingMessageStatus?) -> Void>()
    var forcedReuploadOnce: Bool = false
}

private final class PeerPendingMessagesSummaryContext {
    var messageDeliveredSubscribers = Bag<() -> Void>()
}

private enum PendingMessageResult {
    case progress(Float)
}

private func uploadActivityTypeForMessage(_ message: Message) -> PeerInputActivity? {
    for media in message.media {
        if let _ = media as? TelegramMediaImage {
            return .uploadingPhoto(progress: 0)
        } else if let file = media as? TelegramMediaFile {
            if file.isInstantVideo {
                return .uploadingInstantVideo(progress: 0)
            } else if file.isVideo && !file.isAnimated {
                return .uploadingVideo(progress: 0)
            } else if !file.isSticker && !file.isVoice && !file.isAnimated {
                return .uploadingFile(progress: 0)
            }
        }
    }
    return nil
}

private func failMessages(postbox: Postbox, ids: [MessageId]) -> Signal<Void, NoError> {
    let modify = postbox.transaction { transaction -> Void in
        for id in ids {
            transaction.updateMessage(id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                }
                return .update(StoreMessage(id: id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
            })
        }
    }
    
    return modify
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
    private let accountPeerId: PeerId
    private let auxiliaryMethods: AccountAuxiliaryMethods
    private let stateManager: AccountStateManager
    private let localInputActivityManager: PeerInputActivityManager
    private let messageMediaPreuploadManager: MessageMediaPreuploadManager
    private let revalidationContext: MediaReferenceRevalidationContext
    
    private let queue = Queue()
    
    private let _hasPendingMessages = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var hasPendingMessages: Signal<Bool, NoError> {
        return self._hasPendingMessages.get()
    }
    
    private var messageContexts: [MessageId: PendingMessageContext] = [:]
    private var pendingMessageIds = Set<MessageId>()
    private let beginSendingMessagesDisposables = DisposableSet()
    
    private var peerSummaryContexts: [PeerId: PeerPendingMessagesSummaryContext] = [:]
    
    var transformOutgoingMessageMedia: TransformOutgoingMessageMedia?
    
    init(network: Network, postbox: Postbox, accountPeerId: PeerId, auxiliaryMethods: AccountAuxiliaryMethods, stateManager: AccountStateManager, localInputActivityManager: PeerInputActivityManager, messageMediaPreuploadManager: MessageMediaPreuploadManager, revalidationContext: MediaReferenceRevalidationContext) {
        self.network = network
        self.postbox = postbox
        self.accountPeerId = accountPeerId
        self.auxiliaryMethods = auxiliaryMethods
        self.stateManager = stateManager
        self.localInputActivityManager = localInputActivityManager
        self.messageMediaPreuploadManager = messageMediaPreuploadManager
        self.revalidationContext = revalidationContext
    }
    
    deinit {
        self.beginSendingMessagesDisposables.dispose()
    }
    
    func updatePendingMessageIds(_ messageIds: Set<MessageId>) {
        self.queue.async {
            let addedMessageIds = messageIds.subtracting(self.pendingMessageIds)
            let removedMessageIds = self.pendingMessageIds.subtracting(messageIds)
            
            var updateUploadingPeerIds = Set<PeerId>()
            var updateUploadingGroupIds = Set<Int64>()
            for id in removedMessageIds {
                if let context = self.messageContexts[id] {
                    if let groupId = context.state.groupId {
                        updateUploadingGroupIds.insert(groupId)
                    }
                    context.state = .none
                    updateUploadingPeerIds.insert(id.peerId)
                    context.sendDisposable.dispose()
                    context.uploadDisposable.dispose()
                    context.activityDisposable.dispose()
                    
                    if context.status != nil {
                        context.status = nil
                        for subscriber in context.statusSubscribers.copyItems() {
                            subscriber(nil)
                        }
                    }
                    
                    if context.statusSubscribers.isEmpty {
                        self.messageContexts.removeValue(forKey: id)
                    }
                }
            }
            
            if !addedMessageIds.isEmpty {
                self.beginSendingMessages(Array(addedMessageIds).sorted())
            }
            
            self.pendingMessageIds = messageIds
            
            for peerId in updateUploadingPeerIds {
                self.updateWaitingUploads(peerId: peerId)
            }
            
            for groupId in updateUploadingGroupIds {
                self.beginSendingGroupIfPossible(groupId: groupId)
            }
            
            self._hasPendingMessages.set(!self.pendingMessageIds.isEmpty)
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
    
    private func canBeginUploadingMessage(id: MessageId, type: PendingMessageUploadedContentType) -> Bool {
        assert(self.queue.isCurrent())
        
        if case .text = type {
            return true
        }
        
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
        
        for id in ids.sorted() {
            let messageContext: PendingMessageContext
            if let current = self.messageContexts[id] {
                messageContext = current
            } else {
                messageContext = PendingMessageContext()
                self.messageContexts[id] = messageContext
            }
            
            let status = PendingMessageStatus(isRunning: false, progress: 0.0)
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
                
                for message in messages.filter({ !$0.flags.contains(.Sending) }).sorted(by: { $0.id < $1.id }) {
                    guard let messageContext = strongSelf.messageContexts[message.id] else {
                        continue
                    }
                    
                    messageContext.activityType = uploadActivityTypeForMessage(message)
                    
                    let (contentUploadSignal, contentType) = messageContentToUpload(network: strongSelf.network, postbox: strongSelf.postbox, auxiliaryMethods: strongSelf.auxiliaryMethods, transformOutgoingMessageMedia: strongSelf.transformOutgoingMessageMedia, messageMediaPreuploadManager: strongSelf.messageMediaPreuploadManager, revalidationContext: strongSelf.revalidationContext, forceReupload:  messageContext.forcedReuploadOnce, message: message)
                    messageContext.contentType = contentType
                    
                    if strongSelf.canBeginUploadingMessage(id: message.id, type: contentType) {
                        strongSelf.beginUploadingMessage(messageContext: messageContext, id: message.id, groupId: message.groupingKey, uploadSignal: contentUploadSignal)
                    } else {
                        messageContext.state = .waitingForUploadToStart(groupId: message.groupingKey, upload: contentUploadSignal)
                    }
                }
            }
        }))
    }
    
    private func beginSendingMessage(messageContext: PendingMessageContext, messageId: MessageId, groupId: Int64?, content: PendingMessageUploadedContentAndReuploadInfo) {
        if let groupId = groupId {
            messageContext.state = .waitingToBeSent(groupId: groupId, content: content)
        } else {
            self.commitSendingSingleMessage(messageContext: messageContext, messageId: messageId, content: content)
        }
    }
    
    private func beginSendingGroupIfPossible(groupId: Int64) {
        if let data = self.dataForPendingMessageGroup(groupId) {
            self.commitSendingMessageGroup(groupId: groupId, messages: data)
        }
    }
    
    private func dataForPendingMessageGroup(_ groupId: Int64) -> [(messageContext: PendingMessageContext, messageId: MessageId, content: PendingMessageUploadedContentAndReuploadInfo)]? {
        var result: [(messageContext: PendingMessageContext, messageId: MessageId, content: PendingMessageUploadedContentAndReuploadInfo)] = []
        
        loop: for (id, context) in self.messageContexts {
            switch context.state {
                case .none:
                    continue loop
                case let .waitingForUploadToStart(contextGroupId, _):
                    if contextGroupId == groupId {
                        return nil
                    }
                case let .uploading(contextGroupId):
                    if contextGroupId == groupId {
                        return nil
                    }
                case let .waitingToBeSent(contextGroupId, content):
                    if contextGroupId == groupId {
                        result.append((context, id, content))
                    }
                case let .sending(contextGroupId):
                    if contextGroupId == groupId {
                        return nil
                    }
            }
        }
        
        if result.isEmpty {
            return nil
        } else {
            return result
        }
    }
    
    private func commitSendingMessageGroup(groupId: Int64, messages: [(messageContext: PendingMessageContext, messageId: MessageId, content: PendingMessageUploadedContentAndReuploadInfo)]) {
        for (context, _, _) in messages {
            context.state = .sending(groupId: groupId)
        }
        let sendMessage: Signal<PendingMessageResult, NoError> = self.sendGroupMessagesContent(network: self.network, postbox: self.postbox, stateManager: self.stateManager, group: messages.map { ($0.1, $0.2) })
        |> map { next -> PendingMessageResult in
            return .progress(1.0)
        }
        messages[0].0.sendDisposable.set((sendMessage
        |> deliverOn(self.queue)
        |> afterDisposed { [weak self] in
            /*if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                for (_, id, _) in messages {
                    if let current = strongSelf.messageContexts[id] {
                        current.status = .none
                        for subscriber in current.statusSubscribers.copyItems() {
                            subscriber(nil)
                        }
                        if current.statusSubscribers.isEmpty {
                            strongSelf.messageContexts.removeValue(forKey: id)
                        }
                    }
                }
            }*/
        }).start())
    }
    
    private func commitSendingSingleMessage(messageContext: PendingMessageContext, messageId: MessageId, content: PendingMessageUploadedContentAndReuploadInfo) {
        messageContext.state = .sending(groupId: nil)
        let sendMessage: Signal<PendingMessageResult, NoError> = self.sendMessageContent(network: self.network, postbox: self.postbox, stateManager: self.stateManager, messageId: messageId, content: content)
        |> map { next -> PendingMessageResult in
            return .progress(1.0)
        }
        messageContext.sendDisposable.set((sendMessage
        |> deliverOn(self.queue)
        |> afterDisposed { [weak self] in
            /*if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                if let current = strongSelf.messageContexts[messageId] {
                    current.status = .none
                    for subscriber in current.statusSubscribers.copyItems() {
                        subscriber(nil)
                    }
                    if current.statusSubscribers.isEmpty {
                        strongSelf.messageContexts.removeValue(forKey: messageId)
                    }
                }
            }*/
        }).start(next: { [weak self] next in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                
                switch next {
                    case let .progress(progress):
                        if let current = strongSelf.messageContexts[messageId] {
                            let status = PendingMessageStatus(isRunning: true, progress: progress)
                            current.status = status
                            for subscriber in current.statusSubscribers.copyItems() {
                                subscriber(status)
                            }
                        }
                }
            }
        }))
    }
    
    private func beginUploadingMessage(messageContext: PendingMessageContext, id: MessageId, groupId: Int64?, uploadSignal: Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>) {
        messageContext.state = .uploading(groupId: groupId)
        
        let status = PendingMessageStatus(isRunning: true, progress: 0.0)
        messageContext.status = status
        for subscriber in messageContext.statusSubscribers.copyItems() {
            subscriber(status)
        }
        self.addContextActivityIfNeeded(messageContext, peerId: id.peerId)
        
        let queue = self.queue
        
        messageContext.uploadDisposable.set((uploadSignal
        |> deliverOn(queue)
        |> `catch` { [weak self] _ -> Signal<PendingMessageUploadedContentResult, NoError> in
            if let strongSelf = self {
                let modify = strongSelf.postbox.transaction { transaction -> Void in
                    transaction.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                        }
                        return .update(StoreMessage(id: id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                    })
                }
                return modify
                |> mapToSignal { _ in
                    return .complete()
                }
            }
            return .complete()
        }
        |> mapToSignal { result -> Signal<PendingMessageUploadedContentResult, NoError> in
            if groupId != nil, case .content = result {
                return Signal { subscriber in
                    queue.justDispatch {
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                }
            } else {
                return .single(result)
            }
        }).start(next: { [weak self] next in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                
                switch next {
                    case let .progress(progress):
                        if let current = strongSelf.messageContexts[id] {
                            let status = PendingMessageStatus(isRunning: true, progress: progress)
                            current.status = status
                            for subscriber in current.statusSubscribers.copyItems() {
                                subscriber(status)
                            }
                        }
                    case let .content(content):
                        if let current = strongSelf.messageContexts[id] {
                            strongSelf.beginSendingMessage(messageContext: current, messageId: id, groupId: groupId, content: content)
                            strongSelf.updateWaitingUploads(peerId: id.peerId)
                            if let groupId = groupId {
                                strongSelf.beginSendingGroupIfPossible(groupId: groupId)
                            }
                        }
                }
            }
        }))
    }
    
    private func addContextActivityIfNeeded(_ context: PendingMessageContext, peerId: PeerId) {
        if let activityType = context.activityType {
            context.activityDisposable.set(self.localInputActivityManager.acquireActivity(chatPeerId: peerId, peerId: self.accountPeerId, activity: activityType))
        }
    }
    
    private func updateWaitingUploads(peerId: PeerId) {
        assert(self.queue.isCurrent())
        
        let messageIdsForPeer: [MessageId] = self.messageContexts.keys.filter({ $0.peerId == peerId }).sorted()
        loop: for contextId in messageIdsForPeer {
            let context = self.messageContexts[contextId]!
            if case let .waitingForUploadToStart(groupId, uploadSignal) = context.state {
                if self.canBeginUploadingMessage(id: contextId, type: context.contentType ?? .media) {
                    context.state = .uploading(groupId: groupId)
                    let status = PendingMessageStatus(isRunning: true, progress: 0.0)
                    context.status = status
                    for subscriber in context.statusSubscribers.copyItems() {
                        subscriber(status)
                    }
                    self.addContextActivityIfNeeded(context, peerId: peerId)
                    context.uploadDisposable.set((uploadSignal
                    |> deliverOn(self.queue)).start(next: { [weak self] next in
                        if let strongSelf = self {
                            assert(strongSelf.queue.isCurrent())
                            
                            switch next {
                                case let .progress(progress):
                                    if let current = strongSelf.messageContexts[contextId] {
                                        let status = PendingMessageStatus(isRunning: true, progress: progress)
                                        current.status = status
                                        for subscriber in current.statusSubscribers.copyItems() {
                                            subscriber(status)
                                        }
                                    }
                                case let .content(content):
                                    if let current = strongSelf.messageContexts[contextId] {
                                        strongSelf.beginSendingMessage(messageContext: current, messageId: contextId, groupId: groupId, content: content)
                                        if let groupId = groupId {
                                            strongSelf.beginSendingGroupIfPossible(groupId: groupId)
                                        }
                                        strongSelf.updateWaitingUploads(peerId: peerId)
                                    }
                            }
                        }
                    }))
                }
                break loop
            }
        }
    }
    
    private func sendGroupMessagesContent(network: Network, postbox: Postbox, stateManager: AccountStateManager, group: [(messageId: MessageId, content: PendingMessageUploadedContentAndReuploadInfo)]) -> Signal<Void, NoError> {
        let queue = self.queue
        return postbox.transaction { [weak self] transaction -> Signal<Void, NoError> in
            if group.isEmpty {
                return .complete()
            }
            
            let peerId = group[0].messageId.peerId
            
            var messages: [(Message, PendingMessageUploadedContentAndReuploadInfo)] = []
            for (id, content) in group {
                if let message = transaction.getMessage(id) {
                    messages.append((message, content))
                } else {
                    return failMessages(postbox: postbox, ids: group.map { $0.0 })
                }
            }
            
            messages.sort { MessageIndex($0.0) < MessageIndex($1.0) }
            
            if peerId.namespace == Namespaces.Peer.SecretChat {
                for (message, content) in messages {
                    PendingMessageManager.sendSecretMessageContent(transaction: transaction, message: message, content: content)
                }
                
                return .complete()
            } else if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                var isForward = false
                var replyMessageId: Int32?
                
                var flags: Int32 = 0
                
                for attribute in messages[0].0.attributes {
                    if let replyAttribute = attribute as? ReplyMessageAttribute {
                        replyMessageId = replyAttribute.messageId.id
                    } else if let _ = attribute as? ForwardSourceInfoAttribute {
                        isForward = true
                    } else if let attribute = attribute as? NotificationInfoMessageAttribute {
                        if attribute.flags.contains(.muted) {
                            flags |= Int32(1 << 5)
                        }
                    }
                }
                
                let sendMessageRequest: Signal<Api.Updates, MTRpcError>
                if isForward {
                    flags |= (1 << 9)
                    
                    var forwardIds: [(MessageId, Int64)] = []
                    for (message, content) in messages {
                        var uniqueId: Int64?
                        inner: for attribute in message.attributes {
                            if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                                uniqueId = outgoingInfo.uniqueId
                                break inner
                            }
                        }
                        
                        if let uniqueId = uniqueId {
                            switch content.content {
                                case let .forward(forwardAttribute):
                                    forwardIds.append((forwardAttribute.messageId, uniqueId))
                                default:
                                    assertionFailure()
                                    return .complete()
                            }
                        } else {
                            return .complete()
                        }
                    }
                    let forwardPeerIds = Set(forwardIds.map { $0.0.peerId })
                    if forwardPeerIds.count != 1 {
                        assertionFailure()
                        sendMessageRequest = .fail(MTRpcError(errorCode: 400, errorDescription: "Invalid forward peer ids"))
                    } else if let inputSourcePeerId = forwardPeerIds.first, let inputSourcePeer = transaction.getPeer(inputSourcePeerId).flatMap(apiInputPeer) {
                        let dependencyTag = PendingMessageRequestDependencyTag(messageId: messages[0].0.id)

                        sendMessageRequest = network.request(Api.functions.messages.forwardMessages(flags: flags, fromPeer: inputSourcePeer, id: forwardIds.map { $0.0.id }, randomId: forwardIds.map { $0.1 }, toPeer: inputPeer), tag: dependencyTag)
                    } else {
                        assertionFailure()
                        sendMessageRequest = .fail(MTRpcError(errorCode: 400, errorDescription: "Invalid forward source"))
                    }
                } else {
                    flags |= (1 << 7)
                    if let _ = replyMessageId {
                        flags |= Int32(1 << 0)
                    }
                    
                    var singleMedias: [Api.InputSingleMedia] = []
                    for (message, content) in messages {
                        var uniqueId: Int64?
                        inner: for attribute in message.attributes {
                            if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                                uniqueId = outgoingInfo.uniqueId
                                break inner
                            }
                        }
                        if let uniqueId = uniqueId {
                            switch content.content {
                                case let .media(inputMedia, text):
                                    var messageEntities: [Api.MessageEntity]?
                                    for attribute in message.attributes {
                                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                                            messageEntities = apiTextAttributeEntities(attribute, associatedPeers: message.peers)
                                        }
                                    }
                                    
                                    var singleFlags: Int32 = 0
                                    if let _ = messageEntities {
                                        singleFlags |= 1 << 0
                                    }
                                    
                                    singleMedias.append(.inputSingleMedia(flags: singleFlags, media: inputMedia, randomId: uniqueId, message: text, entities: messageEntities))
                                default:
                                    return failMessages(postbox: postbox, ids: group.map { $0.0 })
                            }
                        } else {
                            return failMessages(postbox: postbox, ids: group.map { $0.0 })
                        }
                    }
                    
                    sendMessageRequest = network.request(Api.functions.messages.sendMultiMedia(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, multiMedia: singleMedias))
                }
                
                return sendMessageRequest
                |> deliverOn(queue)
                |> mapToSignal { result -> Signal<Void, MTRpcError> in
                    if let strongSelf = self {
                        return strongSelf.applySentGroupMessages(postbox: postbox, stateManager: stateManager, messages: messages.map { $0.0 }, result: result)
                        |> mapError { _ -> MTRpcError in
                            return MTRpcError(errorCode: 400, errorDescription: "empty")
                        }
                    } else {
                        return .never()
                    }
                }
                |> `catch` { error -> Signal<Void, NoError> in
                    return deferred {
                        if error.errorDescription.hasPrefix("FILEREF_INVALID") || error.errorDescription.hasPrefix("FILE_REFERENCE_") {
                            if let strongSelf = self {
                                var allFoundAndValid = true
                                for (message, _) in messages {
                                    if let context = strongSelf.messageContexts[message.id] {
                                        if context.forcedReuploadOnce {
                                            allFoundAndValid = false
                                            break
                                        }
                                    } else {
                                        allFoundAndValid = false
                                        break
                                    }
                                }
                                
                                if allFoundAndValid {
                                    for (message, _) in messages {
                                        if let context = strongSelf.messageContexts[message.id] {
                                            context.forcedReuploadOnce = true
                                        }
                                    }
                                    
                                    strongSelf.beginSendingMessages(messages.map({ $0.0.id }))
                                    return .complete()
                                }
                            }
                        }
                        return failMessages(postbox: postbox, ids: group.map { $0.0 })
                    } |> runOn(queue)
                }
            } else {
                assertionFailure()
                return failMessages(postbox: postbox, ids: group.map { $0.0 })
            }
        }
        |> switchToLatest
    }
    
    private static func sendSecretMessageContent(transaction: Transaction, message: Message, content: PendingMessageUploadedContentAndReuploadInfo) {
        var secretFile: SecretChatOutgoingFile?
        switch content.content {
            case let .secretMedia(file, size, key):
                if let fileReference = SecretChatOutgoingFileReference(file) {
                    secretFile = SecretChatOutgoingFile(reference: fileReference, size: size, key: key)
                }
            default:
                break
        }
        
        var layer: SecretChatLayer?
        let state = transaction.getPeerChatState(message.id.peerId) as? SecretChatState
        if let state = state {
            switch state.embeddedState {
                case .terminated, .handshake:
                    break
                case .basicLayer:
                    layer = .layer8
                case let .sequenceBasedLayer(sequenceState):
                    layer = sequenceState.layerNegotiationState.activeLayer.secretChatLayer
            }
        }
        
        if let state = state, let layer = layer {
            var sentAsAction = false
            for media in message.media {
                if let media = media as? TelegramMediaAction {
                    if case let .messageAutoremoveTimeoutUpdated(value) = media.action {
                        sentAsAction = true
                        let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: message.id.peerId, operation: .setMessageAutoremoveTimeout(layer: layer, actionGloballyUniqueId: message.globallyUniqueId!, timeout: value, messageId: message.id), state: state)
                        if updatedState != state {
                            transaction.setPeerChatState(message.id.peerId, state: updatedState)
                        }
                    } else if case .historyScreenshot = media.action {
                        sentAsAction = true
                        let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: message.id.peerId, operation: .screenshotMessages(layer: layer, actionGloballyUniqueId: message.globallyUniqueId!, globallyUniqueIds: [], messageId: message.id), state: state)
                        if updatedState != state {
                            transaction.setPeerChatState(message.id.peerId, state: updatedState)
                        }
                    }
                    break
                }
            }
            
            if sentAsAction {
                transaction.updateMessage(message.id, update: { currentMessage in
                    var flags = StoreMessageFlags(message.flags)
                    if !flags.contains(.Failed) {
                        flags.insert(.Sending)
                    }
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: flags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                })
            } else {
                let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: message.id.peerId, operation: .sendMessage(layer: layer, id: message.id, file: secretFile), state: state)
                if updatedState != state {
                    transaction.setPeerChatState(message.id.peerId, state: updatedState)
                }
                transaction.updateMessage(message.id, update: { currentMessage in
                    var flags = StoreMessageFlags(message.flags)
                    if !flags.contains(.Failed) {
                        flags.insert(.Sending)
                    }
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: flags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                })
            }
        } else {
            transaction.updateMessage(message.id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                }
                return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
            })
        }
    }
    
    private func sendMessageContent(network: Network, postbox: Postbox, stateManager: AccountStateManager, messageId: MessageId, content: PendingMessageUploadedContentAndReuploadInfo) -> Signal<Void, NoError> {
        let queue = self.queue
        return postbox.transaction { [weak self] transaction -> Signal<Void, NoError> in
            guard let message = transaction.getMessage(messageId) else {
                return .complete()
            }
            
            if messageId.peerId.namespace == Namespaces.Peer.SecretChat {
                PendingMessageManager.sendSecretMessageContent(transaction: transaction, message: message, content: content)
                return .complete()
            } else if let peer = transaction.getPeer(messageId.peerId), let inputPeer = apiInputPeer(peer) {
                var uniqueId: Int64 = 0
                var forwardSourceInfoAttribute: ForwardSourceInfoAttribute?
                var messageEntities: [Api.MessageEntity]?
                var replyMessageId: Int32?
                
                var flags: Int32 = 0
                
                flags |= (1 << 7)
                
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
                    } else if let attribute = attribute as? NotificationInfoMessageAttribute {
                        if attribute.flags.contains(.muted) {
                            flags |= Int32(1 << 5)
                        }
                    }
                }
                
                if let _ = replyMessageId {
                    flags |= Int32(1 << 0)
                }
                if let _ = messageEntities {
                    flags |= Int32(1 << 3)
                }
                
                let dependencyTag = PendingMessageRequestDependencyTag(messageId: messageId)
                
                let sendMessageRequest: Signal<NetworkRequestResult<Api.Updates>, MTRpcError>
                switch content.content {
                    case .text:
                        sendMessageRequest = network.requestWithAcknowledgement(Api.functions.messages.sendMessage(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, message: message.text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities), tag: dependencyTag)
                    case let .media(inputMedia, text):
                        sendMessageRequest = network.request(Api.functions.messages.sendMedia(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, media: inputMedia, message: text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities), tag: dependencyTag)
                        |> map(NetworkRequestResult.result)
                    case let .forward(sourceInfo):
                        if let forwardSourceInfoAttribute = forwardSourceInfoAttribute, let sourcePeer = transaction.getPeer(forwardSourceInfoAttribute.messageId.peerId), let sourceInputPeer = apiInputPeer(sourcePeer) {
                            sendMessageRequest = network.request(Api.functions.messages.forwardMessages(flags: 0, fromPeer: sourceInputPeer, id: [sourceInfo.messageId.id], randomId: [uniqueId], toPeer: inputPeer), tag: dependencyTag)
                            |> map(NetworkRequestResult.result)
                        } else {
                            sendMessageRequest = .fail(MTRpcError(errorCode: 400, errorDescription: "internal"))
                        }
                    case let .chatContextResult(chatContextResult):
                        sendMessageRequest = network.request(Api.functions.messages.sendInlineBotResult(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, randomId: uniqueId, queryId: chatContextResult.queryId, id: chatContextResult.id))
                        |> map(NetworkRequestResult.result)
                    case .secretMedia:
                        assertionFailure()
                        sendMessageRequest = .fail(MTRpcError(errorCode: 400, errorDescription: "internal"))
                }
                
                return sendMessageRequest
                |> deliverOn(queue)
                |> mapToSignal { result -> Signal<Void, MTRpcError> in
                    guard let strongSelf = self else {
                        return .never()
                    }
                    switch result {
                        case .acknowledged:
                            return strongSelf.applyAcknowledgedMessage(postbox: postbox, message: message)
                            |> mapError { _ -> MTRpcError in
                                return MTRpcError(errorCode: 400, errorDescription: "internal")
                            }
                        case let .result(result):
                            return strongSelf.applySentMessage(postbox: postbox, stateManager: stateManager, message: message, result: result)
                            |> mapError { _ -> MTRpcError in
                                return MTRpcError(errorCode: 400, errorDescription: "internal")
                            }
                    }
                }
                |> `catch` { error -> Signal<Void, NoError> in
                    queue.async {
                        guard let strongSelf = self, let context = strongSelf.messageContexts[messageId] else {
                            return
                        }
                        if error.errorDescription.hasPrefix("FILEREF_INVALID") || error.errorDescription.hasPrefix("FILE_REFERENCE_") {
                            if !context.forcedReuploadOnce {
                                context.forcedReuploadOnce = true
                                strongSelf.beginSendingMessages([messageId])
                                return
                            }
                        }
                        let _ = (postbox.transaction { transaction -> Void in
                            transaction.updateMessage(message.id, update: { currentMessage in
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                                }
                                return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                            })
                        }).start()
                    }
                    
                    return .complete()
                }
            } else {
                return postbox.transaction { transaction -> Void in
                    transaction.updateMessage(message.id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                        }
                        return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                    })
                }
            }
        } |> switchToLatest
    }
    
    private func applyAcknowledgedMessage(postbox: Postbox, message: Message) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            transaction.updateMessage(message.id, update: { currentMessage in
                var attributes = message.attributes
                var found = false
                for i in 0 ..< attributes.count {
                    if let attribute = attributes[i] as? OutgoingMessageInfoAttribute {
                        attributes[i] = attribute.withUpdatedAcknowledged(true)
                        found = true
                        break
                    }
                }
                
                if !found {
                    return .skip
                }
                
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
        }
    }
    
    private func applySentMessage(postbox: Postbox, stateManager: AccountStateManager, message: Message, result: Api.Updates) -> Signal<Void, NoError> {
        return applyUpdateMessage(postbox: postbox, stateManager: stateManager, message: message, result: result) |> afterDisposed { [weak self] in
            if let strongSelf = self {
                strongSelf.queue.async {
                    if let context = strongSelf.peerSummaryContexts[message.id.peerId] {
                        for subscriber in context.messageDeliveredSubscribers.copyItems() {
                            subscriber()
                        }
                    }
                }
            }
        }
    }
    
    private func applySentGroupMessages(postbox: Postbox, stateManager: AccountStateManager, messages: [Message], result: Api.Updates) -> Signal<Void, NoError> {
        return applyUpdateGroupMessages(postbox: postbox, stateManager: stateManager, messages: messages, result: result)
        |> afterDisposed { [weak self] in
            if let strongSelf = self {
                strongSelf.queue.async {
                    if let peerId = messages.first?.id.peerId, let context = strongSelf.peerSummaryContexts[peerId] {
                        for subscriber in context.messageDeliveredSubscribers.copyItems() {
                            subscriber()
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
                
                let index = summaryContext.messageDeliveredSubscribers.add({
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

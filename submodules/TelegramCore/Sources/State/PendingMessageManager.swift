import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public struct PendingMessageStatus: Equatable {
    public struct Progress: Equatable {
        public let progress: Float
        public let mediaProgress: [MediaId: Float]
        
        public init(progress: Float, mediaProgress: [MediaId: Float] = [:]) {
            self.progress = progress
            self.mediaProgress = mediaProgress
        }
        
        init(_ contentProgress: PendingMessageUploadedContentProgress) {
            self.progress = contentProgress.progress
            self.mediaProgress = contentProgress.mediaProgress
        }
    }
    
    public let isRunning: Bool
    public let progress: Progress
}

private enum PendingMessageState {
    case none
    case collectingInfo(message: Message)
    case waitingForUploadToStart(groupId: Int64?, upload: Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>)
    case uploading(groupId: Int64?)
    case waitingToBeSent(groupId: Int64?, content: PendingMessageUploadedContentAndReuploadInfo)
    case sending(groupId: Int64?)
    
    var groupId: Int64? {
        switch self {
            case .none:
                return nil
            case let .collectingInfo(message):
                return message.groupingKey
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
    var threadId: Int64?
    var activityType: PeerInputActivity? = nil
    var contentType: PendingMessageUploadedContentType? = nil
    let activityDisposable = MetaDisposable()
    var status: PendingMessageStatus?
    var error: PendingMessageFailureReason?
    var statusSubscribers = Bag<(PendingMessageStatus?, PendingMessageFailureReason?) -> Void>()
    var forcedReuploadOnce: Bool = false
    let postponeDisposable = MetaDisposable()
    var postponeSending = false
}

public enum PendingMessageFailureReason {
    case flood
    case publicBan
    case mediaRestricted
    case slowmodeActive
    case tooMuchScheduled
    case voiceMessagesForbidden
    case sendingTooFast
    case nonPremiumMessagesForbidden
}

func sendMessageReasonForError(_ error: String) -> PendingMessageFailureReason? {
    if error.hasPrefix("PEER_FLOOD") {
        return .flood
    } else if error.hasPrefix("SENDING_TOO_FAST") {
        return .sendingTooFast
    } else if error.hasPrefix("USER_BANNED_IN_CHANNEL") {
        return .publicBan
    } else if error.hasPrefix("CHAT_SEND_") && error.hasSuffix("_FORBIDDEN") {
        return .mediaRestricted
    } else if error.hasPrefix("SLOWMODE_WAIT") {
        return .slowmodeActive
    } else if error.hasPrefix("SCHEDULE_TOO_MUCH") {
        return .tooMuchScheduled
    } else if error.hasPrefix("VOICE_MESSAGES_FORBIDDEN") {
        return .voiceMessagesForbidden
    } else if error.hasPrefix("PRIVACY_PREMIUM_REQUIRED") {
        return .nonPremiumMessagesForbidden
    } else {
        return nil
    }
}

public struct PeerPendingMessageDelivered {
    public var id: EngineMessage.Id
    public var isSilent: Bool
    public var isPendingProcessing: Bool
    
    public init(id: EngineMessage.Id, isSilent: Bool, isPendingProcessing: Bool) {
        self.id = id
        self.isSilent = isSilent
        self.isPendingProcessing = isPendingProcessing
    }
}

private final class PeerPendingMessagesSummaryContext {
    var messageDeliveredSubscribers = Bag<([PeerPendingMessageDelivered]) -> Void>()
    var messageFailedSubscribers = Bag<(PendingMessageFailureReason) -> Void>()
}

private enum PendingMessageResult {
    case progress(Float)
}

private func uploadActivityTypeForMessage(_ message: Message) -> PeerInputActivity? {
    guard message.forwardInfo == nil else {
        return nil
    }
    for media in message.media {
        if let _ = media as? TelegramMediaImage {
            return .uploadingPhoto(progress: 0)
        } else if let file = media as? TelegramMediaFile {
            if file.isInstantVideo {
                return .uploadingInstantVideo(progress: 0)
            } else if file.isVideo && !file.isAnimated && !file.isVideoEmoji && !file.isVideoSticker {
                return .uploadingVideo(progress: 0)
            } else if !file.isSticker && !file.isCustomEmoji && !file.isVoice && !file.isAnimated {
                return .uploadingFile(progress: 0)
            }
        }
    }
    return nil
}

private func shouldPassFetchProgressForMessage(_ message: Message) -> Bool {
    for media in message.media {
        if let file = media as? TelegramMediaFile, file.isVideo {
            return true
        }
    }
    return false
}

private func failMessages(postbox: Postbox, ids: [MessageId]) -> Signal<Void, NoError> {
    let modify = postbox.transaction { transaction -> Void in
        for id in ids {
            transaction.updateMessage(id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                return .update(StoreMessage(id: id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
            })
        }
    }
    
    return modify
}

final class PendingMessageRequestDependencyTag: NetworkRequestDependencyTag {
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

private final class CorrelationIdToSentMessageId {
    var mapping: [Int64: MessageId] = [:]
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
    
    private let _hasPendingMessages = ValuePromise<Set<PeerId>>(Set(), ignoreRepeated: true)
    public var hasPendingMessages: Signal<Set<PeerId>, NoError> {
        return self._hasPendingMessages.get()
    }
    
    private var messageContexts: [MessageId: PendingMessageContext] = [:]
    private var pendingMessageIds = Set<MessageId>()
    private let beginSendingMessagesDisposables = DisposableSet()
    
    private var peerSummaryContexts: [PeerId: PeerPendingMessagesSummaryContext] = [:]
    
    var transformOutgoingMessageMedia: TransformOutgoingMessageMedia?
    
    private let correlationIdToSentMessageId: Atomic<CorrelationIdToSentMessageId> = Atomic(value: CorrelationIdToSentMessageId())
    
    init(network: Network, postbox: Postbox, accountPeerId: PeerId, auxiliaryMethods: AccountAuxiliaryMethods, stateManager: AccountStateManager, localInputActivityManager: PeerInputActivityManager, messageMediaPreuploadManager: MessageMediaPreuploadManager, revalidationContext: MediaReferenceRevalidationContext) {
        Logger.shared.log("PendingMessageManager", "create instance")
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
        Logger.shared.log("PendingMessageManager", "update on postboxQueue: \(messageIds)")

        self.queue.async {
            Logger.shared.log("PendingMessageManager", "update: \(messageIds)")
            
            let addedMessageIds = messageIds.subtracting(self.pendingMessageIds)
            let removedMessageIds = self.pendingMessageIds.subtracting(messageIds)
            let removedSecretMessageIds = Set(removedMessageIds.filter({ $0.peerId.namespace == Namespaces.Peer.SecretChat }))
            
            if !removedMessageIds.isEmpty {
                Logger.shared.log("PendingMessageManager", "removed messages: \(removedMessageIds)")
            }
            
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
                    context.postponeDisposable.dispose()
                    
                    if context.status != nil {
                        context.status = nil
                        for subscriber in context.statusSubscribers.copyItems() {
                            subscriber(nil, context.error)
                        }
                    }
                    
                    if context.statusSubscribers.isEmpty {
                        self.messageContexts.removeValue(forKey: id)
                    }
                }
            }
            
            if !addedMessageIds.isEmpty {
                Logger.shared.log("PendingMessageManager", "added messages: \(addedMessageIds)")
                self.beginSendingMessages(Array(addedMessageIds).sorted())
            }
            
            self.pendingMessageIds = messageIds
            
            for peerId in updateUploadingPeerIds {
                self.updateWaitingUploads(peerId: peerId)
            }
            
            for groupId in updateUploadingGroupIds {
                self.beginSendingGroupIfPossible(groupId: groupId)
            }
            
            if !removedSecretMessageIds.isEmpty {
                let _ = (self.postbox.transaction { transaction -> [PeerId: [PeerPendingMessageDelivered]] in
                    var peerIdsWithDeliveredMessages: [PeerId: [PeerPendingMessageDelivered]] = [:]
                    for id in removedSecretMessageIds {
                        if let message = transaction.getMessage(id) {
                            if message.isSentOrAcknowledged {
                                var silent = false
                                if message.muted {
                                    silent = true
                                }
                                if peerIdsWithDeliveredMessages[id.peerId] == nil {
                                    peerIdsWithDeliveredMessages[id.peerId] = []
                                }
                                peerIdsWithDeliveredMessages[id.peerId]?.append(PeerPendingMessageDelivered(id: MessageId(peerId: id.peerId, namespace: Namespaces.Message.Cloud, id: id.id), isSilent: silent, isPendingProcessing: false))
                            }
                        }
                    }
                    return peerIdsWithDeliveredMessages
                }
                |> deliverOn(self.queue)).start(next: { [weak self] peerIdsWithDeliveredMessages in
                    guard let strongSelf = self else {
                        return
                    }
                    for (peerId, deliveredMessages) in peerIdsWithDeliveredMessages {
                        if let context = strongSelf.peerSummaryContexts[peerId] {
                            for subscriber in context.messageDeliveredSubscribers.copyItems() {
                                subscriber(deliveredMessages)
                            }
                        }
                    }
                })
            }
            
            var peersWithPendingMessages = Set<PeerId>()
            for id in self.pendingMessageIds {
                peersWithPendingMessages.insert(id.peerId)
            }
            
            Logger.shared.log("PendingMessageManager", "pending messages: \(self.pendingMessageIds)")
            
            self._hasPendingMessages.set(peersWithPendingMessages)
        }
    }
    
    public func pendingMessageStatus(_ id: MessageId) -> Signal<(PendingMessageStatus?, PendingMessageFailureReason?), NoError> {
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
                
                let index = messageContext.statusSubscribers.add({ status, error in
                    subscriber.putNext((status, error))
                })
                
                subscriber.putNext((messageContext.status, messageContext.error))
                
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
            
            let status = PendingMessageStatus(isRunning: false, progress: PendingMessageStatus.Progress(progress: 0.0))
            if status != messageContext.status {
                messageContext.status = status
                for subscriber in messageContext.statusSubscribers.copyItems() {
                    subscriber(messageContext.status, messageContext.error)
                }
            }
        }
        
        Logger.shared.log("PendingMessageManager", "begin sending: \(ids)")
        
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
                
                Logger.shared.log("PendingMessageManager", "begin sending, continued: \(ids)")
                
                Logger.shared.log("PendingMessageManager", "beginSendingMessages messages.count: \(messages.count)")

                
                for message in messages.filter({ !$0.flags.contains(.Sending) }).sorted(by: { $0.id < $1.id }) {
                    guard let messageContext = strongSelf.messageContexts[message.id] else {
                        continue
                    }
                                        
                    if message.author?.id == strongSelf.accountPeerId {
                        messageContext.activityType = uploadActivityTypeForMessage(message)
                    }
                    messageContext.threadId = message.threadId
                    strongSelf.collectUploadingInfo(messageContext: messageContext, message: message)
                }
                
                var messagesToUpload: [(PendingMessageContext, Message, PendingMessageUploadedContentType, Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>)] = []
                var messagesToForward: [PeerIdAndNamespace: [(PendingMessageContext, Message, ForwardSourceInfoAttribute)]] = [:]
                
                Logger.shared.log("PendingMessageManager", "beginSendingMessages messageContexts.count: \(strongSelf.messageContexts.count)")

                
                for (messageContext, _) in strongSelf.messageContexts.values.compactMap({ messageContext -> (PendingMessageContext, Message)? in
                    if case let .collectingInfo(message) = messageContext.state {
                        return (messageContext, message)
                    } else {
                        return nil
                    }
                }).sorted(by: { lhs, rhs in
                    return lhs.1.index < rhs.1.index
                }) {
                    if case let .collectingInfo(message) = messageContext.state {
                        let passFetchProgress = shouldPassFetchProgressForMessage(message)
                        let contentToUpload = messageContentToUpload(accountPeerId: strongSelf.accountPeerId, network: strongSelf.network, postbox: strongSelf.postbox, auxiliaryMethods: strongSelf.auxiliaryMethods, transformOutgoingMessageMedia: strongSelf.transformOutgoingMessageMedia, messageMediaPreuploadManager: strongSelf.messageMediaPreuploadManager, revalidationContext: strongSelf.revalidationContext, forceReupload: messageContext.forcedReuploadOnce, isGrouped: message.groupingKey != nil, passFetchProgress: passFetchProgress, message: message)
                        messageContext.contentType = contentToUpload.type
                        switch contentToUpload {
                        case let .immediate(result, type):
                            var isForward = false
                            switch result {
                            case let .content(content):
                                switch content.content {
                                case let .forward(forwardInfo):
                                    isForward = true
                                    let peerIdAndNamespace = PeerIdAndNamespace(peerId: message.id.peerId, namespace: message.id.namespace)
                                    if messagesToForward[peerIdAndNamespace] == nil {
                                        messagesToForward[peerIdAndNamespace] = []
                                    }
                                    messagesToForward[peerIdAndNamespace]!.append((messageContext, message, forwardInfo))
                                default:
                                    break
                                }
                            default:
                                break
                            }
                            if !isForward {
                                messagesToUpload.append((messageContext, message, type, .single(result)))
                            }
                        case let .signal(signal, type):
                            messagesToUpload.append((messageContext, message, type, signal))
                        }
                    }
                }
                
                Logger.shared.log("PendingMessageManager", "beginSendingMessages messagesToUpload.count: \(messagesToUpload.count)")

                
                for (messageContext, message, type, contentUploadSignal) in messagesToUpload {
                    if let paidStarsAttribute = message.paidStarsAttribute, paidStarsAttribute.postponeSending {
                        strongSelf.beginWaitingForPostponedMessageCommit(messageContext: messageContext, id: message.id)
                    }
                    if strongSelf.canBeginUploadingMessage(id: message.id, type: type), !messageContext.postponeSending {
                        strongSelf.beginUploadingMessage(messageContext: messageContext, id: message.id, threadId: message.threadId, groupId: message.groupingKey, uploadSignal: contentUploadSignal)
                    } else {
                        messageContext.state = .waitingForUploadToStart(groupId: message.groupingKey, upload: contentUploadSignal)
                    }
                }
                
                Logger.shared.log("PendingMessageManager", "beginSendingMessages messagesToForward.count: \(messagesToForward.count)")
                
                let forwardGroupLimit = 100
                for (_, ungroupedMessages) in messagesToForward {
                    var messageGroups: [[(PendingMessageContext, Message, ForwardSourceInfoAttribute)]] = []
                    
                    for message in ungroupedMessages {
                        if messageGroups.isEmpty || messageGroups[messageGroups.count - 1].isEmpty {
                            messageGroups.append([message])
                        } else {
                            if messageGroups[messageGroups.count - 1][0].1.groupingKey == message.1.groupingKey {
                                messageGroups[messageGroups.count - 1].append(message)
                            } else {
                                messageGroups.append([message])
                            }
                        }
                    }
                    
                    var countedMessageGroups: [[(PendingMessageContext, Message, ForwardSourceInfoAttribute)]] = []
                    while !messageGroups.isEmpty {
                        guard let messageGroup = messageGroups.first else {
                            break
                        }
                        
                        messageGroups.removeFirst()
                        
                        if messageGroup.isEmpty {
                            continue
                        }
                        if countedMessageGroups.isEmpty {
                            countedMessageGroups.append([])
                        } else if countedMessageGroups[countedMessageGroups.count - 1].count >= forwardGroupLimit {
                            countedMessageGroups.append([])
                        }
                        
                        if countedMessageGroups[countedMessageGroups.count - 1].isEmpty {
                            let fittingFreeMessageCount = min(forwardGroupLimit, messageGroup.count)
                            countedMessageGroups[countedMessageGroups.count - 1].append(contentsOf: messageGroup[0 ..< fittingFreeMessageCount])
                            if fittingFreeMessageCount < messageGroup.count {
                                messageGroups.insert(Array(messageGroup[fittingFreeMessageCount ..< messageGroup.count]), at: 0)
                            }
                        } else if countedMessageGroups[countedMessageGroups.count - 1].count + messageGroup.count <= forwardGroupLimit {
                            countedMessageGroups[countedMessageGroups.count - 1].append(contentsOf: messageGroup)
                        } else {
                            if countedMessageGroups[countedMessageGroups.count - 1][0].1.groupingKey == nil && messageGroup[0].1.groupingKey == nil {
                                let fittingFreeMessageCount = forwardGroupLimit - countedMessageGroups[countedMessageGroups.count - 1].count
                                countedMessageGroups[countedMessageGroups.count - 1].append(contentsOf: messageGroup[0 ..< fittingFreeMessageCount])
                                messageGroups.insert(Array(messageGroup[fittingFreeMessageCount ..< messageGroup.count]), at: 0)
                            } else {
                                countedMessageGroups.append([])
                            }
                        }
                    }
                    
                    for messages in countedMessageGroups {
                        if messages.isEmpty {
                            continue
                        }
                        
                        for (context, _, _) in messages {
                            context.state = .sending(groupId: nil)
                        }
                        
                        let sendMessage: Signal<PendingMessageResult, NoError> = strongSelf.sendGroupMessagesContent(network: strongSelf.network, postbox: strongSelf.postbox, stateManager: strongSelf.stateManager, accountPeerId: strongSelf.accountPeerId, group: messages.map { data in
                            let (_, message, forwardInfo) = data
                            return (message.id, PendingMessageUploadedContentAndReuploadInfo(content: .forward(forwardInfo), reuploadInfo: nil, cacheReferenceKey: nil))
                        })
                        |> map { next -> PendingMessageResult in
                            return .progress(1.0)
                        }
                        messages[0].0.sendDisposable.set((sendMessage
                        |> deliverOn(strongSelf.queue)).start())
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
                case let .collectingInfo(message):
                    if message.groupingKey == groupId {
                        return nil
                    }
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
        let sendMessage: Signal<PendingMessageResult, NoError> = self.sendGroupMessagesContent(network: self.network, postbox: self.postbox, stateManager: self.stateManager, accountPeerId: self.accountPeerId, group: messages.map { ($0.1, $0.2) })
        |> map { next -> PendingMessageResult in
            return .progress(1.0)
        }
        messages[0].0.sendDisposable.set((sendMessage
        |> deliverOn(self.queue)).start())
    }
    
    private func commitSendingSingleMessage(messageContext: PendingMessageContext, messageId: MessageId, content: PendingMessageUploadedContentAndReuploadInfo) {
        messageContext.state = .sending(groupId: nil)
        let sendMessage: Signal<PendingMessageResult, NoError> = self.sendMessageContent(network: self.network, postbox: self.postbox, stateManager: self.stateManager, accountPeerId: self.accountPeerId, messageId: messageId, content: content)
        |> map { next -> PendingMessageResult in
            return .progress(1.0)
        }
        messageContext.sendDisposable.set((sendMessage
        |> deliverOn(self.queue)).start(next: { [weak self] next in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                
                switch next {
                    case let .progress(progress):
                        if let current = strongSelf.messageContexts[messageId] {
                            let status = PendingMessageStatus(isRunning: true, progress: PendingMessageStatus.Progress(progress: progress))
                            current.status = status
                            for subscriber in current.statusSubscribers.copyItems() {
                                subscriber(current.status, current.error)
                            }
                        }
                }
            }
        }))
    }
    
    private func collectUploadingInfo(messageContext: PendingMessageContext, message: Message) {
        messageContext.state = .collectingInfo(message: message)
    }
    
    private func beginWaitingForPostponedMessageCommit(messageContext: PendingMessageContext, id: MessageId) {
        messageContext.postponeSending = true
        
        let signal: Signal<Void, NoError> = self.postbox.transaction { transaction -> Void in
            transaction.setPendingMessageAction(type: .sendPostponedPaidMessage, id: id, action: PostponeSendPaidMessageAction(randomId: Int64.random(in: Int64.min ... Int64.max)))
        }
        |> mapToSignal { _ in
            return self.stateManager.commitSendPendingPaidMessage
            |> filter {
                $0 == id
            }
            |> take(1)
            |> map { _ in
                Void()
            }
        }
        |> deliverOn(self.queue)
        
        messageContext.postponeDisposable.set(signal.start(next: { [weak self] _ in
            guard let self else {
                return
            }
            messageContext.postponeSending = false
            self.updateWaitingUploads(peerId: id.peerId)
        }))
    }
    
    private func beginUploadingMessage(messageContext: PendingMessageContext, id: MessageId, threadId: Int64?, groupId: Int64?, uploadSignal: Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>) {
        messageContext.state = .uploading(groupId: groupId)
        
        let status = PendingMessageStatus(isRunning: true, progress: PendingMessageStatus.Progress(progress: 0.0))
        messageContext.status = status
        for subscriber in messageContext.statusSubscribers.copyItems() {
            subscriber(messageContext.status, messageContext.error)
        }
        let activityCategory: PeerActivitySpace.Category
        if let threadId = threadId {
            activityCategory = .thread(threadId)
        } else {
            activityCategory = .global
        }
        self.addContextActivityIfNeeded(messageContext, peerId: PeerActivitySpace(peerId: id.peerId, category: activityCategory))
        
        let queue = self.queue
        
        messageContext.uploadDisposable.set((uploadSignal
        |> deliverOn(queue)
        |> `catch` { [weak self] _ -> Signal<PendingMessageUploadedContentResult, NoError> in
            if let strongSelf = self {
                let modify = strongSelf.postbox.transaction { transaction -> Void in
                    transaction.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                        }
                        return .update(StoreMessage(id: id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                    })
                }
                return modify
                |> mapToSignal { _ in
                    return .complete()
                }
            }
            return .complete()
        }
        |> deliverOn(queue)).start(next: { [weak self] next in
            if let strongSelf = self {
                assert(strongSelf.queue.isCurrent())
                
                switch next {
                    case let .progress(progress):
                        if let current = strongSelf.messageContexts[id] {
                            let status = PendingMessageStatus(isRunning: true, progress: PendingMessageStatus.Progress(progress))
                            current.status = status
                            for subscriber in current.statusSubscribers.copyItems() {
                                subscriber(current.status, current.error)
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
    
    private func addContextActivityIfNeeded(_ context: PendingMessageContext, peerId: PeerActivitySpace) {
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
                if self.canBeginUploadingMessage(id: contextId, type: context.contentType ?? .media), !context.postponeSending {
                    context.state = .uploading(groupId: groupId)
                    let status = PendingMessageStatus(isRunning: true, progress: PendingMessageStatus.Progress(progress: 0.0))
                    context.status = status
                    for subscriber in context.statusSubscribers.copyItems() {
                        subscriber(context.status, context.error)
                    }
                    
                    let activityCategory: PeerActivitySpace.Category
                    if let threadId = context.threadId {
                        activityCategory = .thread(threadId)
                    } else {
                        activityCategory = .global
                    }
                    
                    self.addContextActivityIfNeeded(context, peerId: PeerActivitySpace(peerId: peerId, category: activityCategory))
                    context.uploadDisposable.set((uploadSignal
                    |> deliverOn(self.queue)).start(next: { [weak self] next in
                        if let strongSelf = self {
                            assert(strongSelf.queue.isCurrent())
                            
                            switch next {
                                case let .progress(progress):
                                    if let current = strongSelf.messageContexts[contextId] {
                                        let status = PendingMessageStatus(isRunning: true, progress: PendingMessageStatus.Progress(progress))
                                        current.status = status
                                        for subscriber in current.statusSubscribers.copyItems() {
                                            subscriber(context.status, context.error)
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
    
    private func sendGroupMessagesContent(network: Network, postbox: Postbox, stateManager: AccountStateManager, accountPeerId: PeerId, group: [(messageId: MessageId, content: PendingMessageUploadedContentAndReuploadInfo)]) -> Signal<Void, NoError> {
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
            
            messages.sort { $0.0.index < $1.0.index }
            
            if peerId.namespace == Namespaces.Peer.SecretChat {
                for (message, content) in messages {
                    PendingMessageManager.sendSecretMessageContent(transaction: transaction, message: message, content: content)
                }
                
                return .complete()
            } else if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                var isForward = false
                var hideSendersNames = false
                var hideCaptions = false
                var replyMessageId: Int32?
                var replyPeerId: PeerId?
                var replyQuote: EngineMessageReplyQuote?
                var replyToStoryId: StoryId?
                var scheduleTime: Int32?
                var videoTimestamp: Int32?
                var sendAsPeerId: PeerId?
                var quickReply: OutgoingQuickReplyMessageAttribute?
                var messageEffect: EffectMessageAttribute?
                var allowPaidStars: Int64?
                var suggestedPost: Api.SuggestedPost?
                
                var flags: Int32 = 0
                
                for attribute in messages[0].0.attributes {
                    if let replyAttribute = attribute as? ReplyMessageAttribute {
                        replyMessageId = replyAttribute.messageId.id
                        if peerId != replyAttribute.messageId.peerId {
                            replyPeerId = replyAttribute.messageId.peerId
                        }
                        if replyAttribute.isQuote {
                            replyQuote = replyAttribute.quote
                        }
                    } else if let attribute = attribute as? ReplyStoryAttribute {
                        replyToStoryId = attribute.storyId
                    } else if let _ = attribute as? ForwardSourceInfoAttribute {
                        isForward = true
                    } else if let attribute = attribute as? NotificationInfoMessageAttribute {
                        if attribute.flags.contains(.muted) {
                            flags |= Int32(1 << 5)
                        }
                    } else if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                        flags |= Int32(1 << 10)
                        scheduleTime = attribute.scheduleTime
                    } else if let attribute = attribute as? ForwardOptionsMessageAttribute {
                        hideSendersNames = attribute.hideNames
                        hideCaptions = attribute.hideCaptions
                    } else if let attribute = attribute as? SendAsMessageAttribute {
                        sendAsPeerId = attribute.peerId
                    } else if let attribute = attribute as? OutgoingQuickReplyMessageAttribute {
                        quickReply = attribute
                    } else if let attribute = attribute as? EffectMessageAttribute {
                        messageEffect = attribute
                    } else if let _ = attribute as? InvertMediaMessageAttribute {
                        flags |= Int32(1 << 16)
                    } else if let attribute = attribute as? ForwardVideoTimestampAttribute {
                        videoTimestamp = attribute.timestamp
                    } else if let attribute = attribute as? PaidStarsMessageAttribute {
                        allowPaidStars = attribute.stars.value * Int64(messages.count)
                    } else if let attribute = attribute as? SuggestedPostMessageAttribute {
                        suggestedPost = attribute.apiSuggestedPost(fixMinTime: Int32(Date().timeIntervalSince1970 + 10))
                    }
                }
                                
                let sendMessageRequest: Signal<Api.Updates, MTRpcError>
                if isForward {
                    if messages.contains(where: { $0.0.groupingKey != nil }) {
                        flags |= (1 << 8)
                    }
                    if hideSendersNames {
                        flags |= (1 << 11)
                    }
                    if hideCaptions {
                        flags |= (1 << 12)
                    }
                    if videoTimestamp != nil {
                        flags |= Int32(1 << 20)
                    }
                    
                    var sendAsInputPeer: Api.InputPeer?
                    if let sendAsPeerId = sendAsPeerId, let sendAsPeer = transaction.getPeer(sendAsPeerId), let inputPeer = apiInputPeerOrSelf(sendAsPeer, accountPeerId: accountPeerId) {
                        sendAsInputPeer = inputPeer
                        flags |= (1 << 13)
                    }

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
                    
                    var topMsgId: Int32?
                    var monoforumPeerId: Api.InputPeer?
                    if let threadId = messages[0].0.threadId {
                        if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                            if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = transaction.getPeer(linkedMonoforumId) as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                monoforumPeerId = transaction.getPeer(PeerId(threadId)).flatMap(apiInputPeer)
                            }
                        } else {
                            flags |= Int32(1 << 9)
                            topMsgId = Int32(clamping: threadId)
                        }
                    }
                    
                    var quickReplyShortcut: Api.InputQuickReplyShortcut?
                    if let quickReply {
                        if let threadId = messages[0].0.threadId {
                            quickReplyShortcut = .inputQuickReplyShortcutId(shortcutId: Int32(clamping: threadId))
                        } else {
                            quickReplyShortcut = .inputQuickReplyShortcut(shortcut: quickReply.shortcut)
                        }
                        flags |= 1 << 17
                    }
                    
                    if let _ = allowPaidStars {
                        flags |= 1 << 21
                    }
                    
                    var replyTo: Api.InputReplyTo?
                    if let monoforumPeerId {
                        replyTo = .inputReplyToMonoForum(monoforumPeerId: monoforumPeerId)
                        flags |= 1 << 22
                    }
                    
                    if suggestedPost != nil {
                        flags |= 1 << 23
                    }
                    
                    let forwardPeerIds = Set(forwardIds.map { $0.0.peerId })
                    if forwardPeerIds.count != 1 {
                        assertionFailure()
                        sendMessageRequest = .fail(MTRpcError(errorCode: 400, errorDescription: "Invalid forward peer ids"))
                    } else if let inputSourcePeerId = forwardPeerIds.first, let inputSourcePeer = transaction.getPeer(inputSourcePeerId).flatMap(apiInputPeer) {
                        let dependencyTag = PendingMessageRequestDependencyTag(messageId: messages[0].0.id)

                        sendMessageRequest = network.request(Api.functions.messages.forwardMessages(flags: flags, fromPeer: inputSourcePeer, id: forwardIds.map { $0.0.id }, randomId: forwardIds.map { $0.1 }, toPeer: inputPeer, topMsgId: topMsgId, replyTo: replyTo, scheduleDate: scheduleTime, sendAs: sendAsInputPeer, quickReplyShortcut: quickReplyShortcut, videoTimestamp: videoTimestamp, allowPaidStars: allowPaidStars, suggestedPost: suggestedPost), tag: dependencyTag)
                    } else {
                        assertionFailure()
                        sendMessageRequest = .fail(MTRpcError(errorCode: 400, errorDescription: "Invalid forward source"))
                    }
                } else {
                    flags |= (1 << 7)
                    
                    var sendAsInputPeer: Api.InputPeer?
                    if let sendAsPeerId = sendAsPeerId, let sendAsPeer = transaction.getPeer(sendAsPeerId), let inputPeer = apiInputPeerOrSelf(sendAsPeer, accountPeerId: accountPeerId) {
                        sendAsInputPeer = inputPeer
                        flags |= (1 << 13)
                    }
                    
                    var bubbleUpEmojiOrStickersets = false
                    
                    var singleMedias: [Api.InputSingleMedia] = []
                    for (message, content) in messages {
                        var uniqueId: Int64?
                        inner: for attribute in message.attributes {
                            if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                                uniqueId = outgoingInfo.uniqueId
                                if !outgoingInfo.bubbleUpEmojiOrStickersets.isEmpty {
                                    bubbleUpEmojiOrStickersets = true
                                }
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
                    
                    if bubbleUpEmojiOrStickersets {
                        flags |= Int32(1 << 15)
                    }
                    
                    var topMsgId: Int32?
                    var monoforumPeerId: Api.InputPeer?
                    if let threadId = messages[0].0.threadId {
                        if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                            if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = transaction.getPeer(linkedMonoforumId) as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                monoforumPeerId = transaction.getPeer(PeerId(threadId)).flatMap(apiInputPeer)
                            }
                        } else {
                            flags |= Int32(1 << 9)
                            topMsgId = Int32(clamping: threadId)
                        }
                    }
                    
                    var replyTo: Api.InputReplyTo?
                    if let replyMessageId = replyMessageId {
                        flags |= 1 << 0
                        
                        var replyFlags: Int32 = 0
                        if topMsgId != nil {
                            replyFlags |= 1 << 0
                        } else if monoforumPeerId != nil {
                            replyFlags |= 1 << 5
                        }
                        
                        var replyToPeerId: Api.InputPeer?
                        if let replyPeerId = replyPeerId {
                            replyToPeerId = transaction.getPeer(replyPeerId).flatMap(apiInputPeer)
                        }
                        if replyToPeerId != nil {
                            replyFlags |= 1 << 1
                        }
                        
                        var quoteText: String?
                        var quoteEntities: [Api.MessageEntity]?
                        var quoteOffset: Int32?
                        if let replyQuote = replyQuote {
                            replyFlags |= 1 << 2
                            quoteText = replyQuote.text
                            quoteOffset = replyQuote.offset.flatMap { Int32.init(clamping: $0) }
                            
                            if !replyQuote.entities.isEmpty {
                                replyFlags |= 1 << 3
                                var associatedPeers = SimpleDictionary<PeerId, Peer>()
                                for entity in replyQuote.entities {
                                    for associatedPeerId in entity.associatedPeerIds {
                                        if associatedPeers[associatedPeerId] == nil {
                                            if let associatedPeer = transaction.getPeer(associatedPeerId) {
                                                associatedPeers[associatedPeerId] = associatedPeer
                                            }
                                        }
                                    }
                                }
                                quoteEntities = apiEntitiesFromMessageTextEntities(replyQuote.entities, associatedPeers: associatedPeers)
                            }
                            
                            if quoteOffset != nil {
                                replyFlags |= 1 << 4
                            }
                        }
                        
                        replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: topMsgId, replyToPeerId: replyToPeerId, quoteText: quoteText, quoteEntities: quoteEntities, quoteOffset: quoteOffset, monoforumPeerId: monoforumPeerId)
                    } else if let replyToStoryId {
                        if let inputPeer = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputPeer) {
                            flags |= 1 << 0
                            replyTo = .inputReplyToStory(peer: inputPeer, storyId: replyToStoryId.id)
                        }
                    } else if let monoforumPeerId {
                        flags |= 1 << 0
                        replyTo = .inputReplyToMonoForum(monoforumPeerId: monoforumPeerId)
                    }
                    
                    var quickReplyShortcut: Api.InputQuickReplyShortcut?
                    if let quickReply {
                        if let threadId = messages[0].0.threadId {
                            quickReplyShortcut = .inputQuickReplyShortcutId(shortcutId: Int32(clamping: threadId))
                        } else {
                            quickReplyShortcut = .inputQuickReplyShortcut(shortcut: quickReply.shortcut)
                        }
                        flags |= 1 << 17
                    }
                    
                    var messageEffectId: Int64?
                    if let messageEffect {
                        flags |= 1 << 18
                        messageEffectId = messageEffect.id
                    }
                    
                    if let _ = allowPaidStars {
                        flags |= 1 << 21
                    }
                    
                    sendMessageRequest = network.request(Api.functions.messages.sendMultiMedia(flags: flags, peer: inputPeer, replyTo: replyTo, multiMedia: singleMedias, scheduleDate: scheduleTime, sendAs: sendAsInputPeer, quickReplyShortcut: quickReplyShortcut, effect: messageEffectId, allowPaidStars: allowPaidStars))
                }
                
                return sendMessageRequest
                |> deliverOn(queue)
                |> mapToSignal { result -> Signal<Void, MTRpcError> in
                    if let strongSelf = self {
                        return strongSelf.applySentGroupMessages(postbox: postbox, stateManager: stateManager, messages: messages.map { $0.0 }, result: result)
                        |> mapError { _ -> MTRpcError in
                        }
                    } else {
                        return .never()
                    }
                }
                |> `catch` { error -> Signal<Void, NoError> in
                    return deferred {
                        if let strongSelf = self {
                            let errorText: String = error.errorDescription
                            
                            if errorText.hasPrefix("FILEREF_INVALID") || errorText.hasPrefix("FILE_REFERENCE_") {
                                var selectiveIndices: [Int]?
                                if errorText.hasPrefix("FILE_REFERENCE_") && errorText.hasSuffix("_EXPIRED") {
                                    if let value = Int(errorText[errorText.index(errorText.startIndex, offsetBy: "FILE_REFERENCE_".count)..<errorText.index(errorText.endIndex, offsetBy: -"_EXPIRED".count)]) {
                                        selectiveIndices = [value]
                                    }
                                }
                                
                                if let selectiveIndices {
                                    var allFoundAndValid = true
                                    for i in 0 ..< messages.count {
                                        let message = messages[i].0
                                        if let context = strongSelf.messageContexts[message.id] {
                                            if selectiveIndices.contains(i) {
                                                if context.forcedReuploadOnce {
                                                    allFoundAndValid = false
                                                    break
                                                }
                                            }
                                        }
                                    }
                                    
                                    if allFoundAndValid {
                                        for i in 0 ..< messages.count {
                                            let message = messages[i].0
                                            if selectiveIndices.contains(i) {
                                                if let context = strongSelf.messageContexts[message.id] {
                                                    context.forcedReuploadOnce = true
                                                }
                                            }
                                        }
                                        
                                        strongSelf.beginSendingMessages(messages.map({ $0.0.id }))
                                        return .complete()
                                    }
                                } else {
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
                            } else if let failureReason = sendMessageReasonForError(error.errorDescription), let message = messages.first?.0 {
                                for (message, _) in messages {
                                    if let context = strongSelf.messageContexts[message.id] {
                                        context.error = failureReason
                                        for f in context.statusSubscribers.copyItems() {
                                            f(context.status, context.error)
                                        }
                                    }
                                }
                                
                                if let context = strongSelf.peerSummaryContexts[message.id.peerId] {
                                    for subscriber in context.messageFailedSubscribers.copyItems() {
                                        subscriber(failureReason)
                                    }
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
    
    static func sendSecretMessageContent(transaction: Transaction, message: Message, content: PendingMessageUploadedContentAndReuploadInfo) {
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
                    if case let .messageAutoremoveTimeoutUpdated(value, _) = media.action {
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
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: flags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
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
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: flags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                })
            }
        } else {
            transaction.updateMessage(message.id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
            })
        }
    }
    
    private func sendMessageContent(network: Network, postbox: Postbox, stateManager: AccountStateManager, accountPeerId: PeerId, messageId: MessageId, content: PendingMessageUploadedContentAndReuploadInfo) -> Signal<Void, NoError> {
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
                var replyPeerId: PeerId?
                var replyQuote: EngineMessageReplyQuote?
                var replyToStoryId: StoryId?
                var scheduleTime: Int32?
                var videoTimestamp: Int32?
                var sendAsPeerId: PeerId?
                var bubbleUpEmojiOrStickersets = false
                var quickReply: OutgoingQuickReplyMessageAttribute?
                var messageEffect: EffectMessageAttribute?
                var allowPaidStars: Int64?
                var suggestedPost: Api.SuggestedPost?
                
                var flags: Int32 = 0
                
                var topMsgId: Int32?
                var monoforumPeerId: Api.InputPeer?
                if let threadId = message.threadId {
                    if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                        if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = transaction.getPeer(linkedMonoforumId) as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                            monoforumPeerId = transaction.getPeer(PeerId(threadId)).flatMap(apiInputPeer)
                        }
                    } else {
                        topMsgId = Int32(clamping: threadId)
                    }
                }
        
                for attribute in message.attributes {
                    if let replyAttribute = attribute as? ReplyMessageAttribute {
                        replyMessageId = replyAttribute.messageId.id
                        if peer.id != replyAttribute.messageId.peerId {
                            replyPeerId = replyAttribute.messageId.peerId
                        }
                        if replyAttribute.isQuote {
                            replyQuote = replyAttribute.quote
                        }
                    } else if let attribute = attribute as? ReplyStoryAttribute {
                        replyToStoryId = attribute.storyId
                    } else if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                        uniqueId = outgoingInfo.uniqueId
                        bubbleUpEmojiOrStickersets = !outgoingInfo.bubbleUpEmojiOrStickersets.isEmpty
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
                    } else if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                        flags |= Int32(1 << 10)
                        scheduleTime = attribute.scheduleTime
                    } else if let attribute = attribute as? SendAsMessageAttribute {
                        sendAsPeerId = attribute.peerId
                    } else if let attribute = attribute as? OutgoingQuickReplyMessageAttribute {
                        quickReply = attribute
                    } else if let attribute = attribute as? EffectMessageAttribute {
                        messageEffect = attribute
                    } else if let attribute = attribute as? ForwardVideoTimestampAttribute {
                        videoTimestamp = attribute.timestamp
                    } else if let attribute = attribute as? PaidStarsMessageAttribute {
                        allowPaidStars = attribute.stars.value
                    } else if let attribute = attribute as? SuggestedPostMessageAttribute {
                        suggestedPost = attribute.apiSuggestedPost(fixMinTime: Int32(Date().timeIntervalSince1970 + 10))
                    }
                }
                
                if case .forward = content.content {
                } else {
                    flags |= (1 << 7)
                    
                    if let _ = replyMessageId {
                        flags |= Int32(1 << 0)
                    }
                    if let _ = messageEntities {
                        flags |= Int32(1 << 3)
                    }
                }
                
                var sendAsInputPeer: Api.InputPeer?
                if let sendAsPeerId = sendAsPeerId, let sendAsPeer = transaction.getPeer(sendAsPeerId), let inputPeer = apiInputPeerOrSelf(sendAsPeer, accountPeerId: accountPeerId) {
                    sendAsInputPeer = inputPeer
                    flags |= (1 << 13)
                }
                
                let dependencyTag = PendingMessageRequestDependencyTag(messageId: messageId)
                
                let sendMessageRequest: Signal<NetworkRequestResult<Api.Updates>, MTRpcError>
                switch content.content {
                    case .text:
                        if bubbleUpEmojiOrStickersets {
                            flags |= Int32(1 << 15)
                        }
                    
                        var replyTo: Api.InputReplyTo?
                        if let replyMessageId = replyMessageId {
                            flags |= 1 << 0
                            
                            var replyFlags: Int32 = 0
                            if topMsgId != nil {
                                replyFlags |= 1 << 0
                            } else if monoforumPeerId != nil {
                                replyFlags |= 1 << 5
                            }
                            
                            var replyToPeerId: Api.InputPeer?
                            if let replyPeerId = replyPeerId {
                                replyToPeerId = transaction.getPeer(replyPeerId).flatMap(apiInputPeer)
                            }
                            if replyToPeerId != nil {
                                replyFlags |= 1 << 1
                            }
                            
                            var quoteText: String?
                            var quoteEntities: [Api.MessageEntity]?
                            var quoteOffset: Int32?
                            if let replyQuote = replyQuote {
                                replyFlags |= 1 << 2
                                quoteText = replyQuote.text
                                quoteOffset = replyQuote.offset.flatMap { Int32.init(clamping: $0) }
                                
                                if !replyQuote.entities.isEmpty {
                                    replyFlags |= 1 << 3
                                    var associatedPeers = SimpleDictionary<PeerId, Peer>()
                                    for entity in replyQuote.entities {
                                        for associatedPeerId in entity.associatedPeerIds {
                                            if associatedPeers[associatedPeerId] == nil {
                                                if let associatedPeer = transaction.getPeer(associatedPeerId) {
                                                    associatedPeers[associatedPeerId] = associatedPeer
                                                }
                                            }
                                        }
                                    }
                                    quoteEntities = apiEntitiesFromMessageTextEntities(replyQuote.entities, associatedPeers: associatedPeers)
                                }
                                
                                if quoteOffset != nil {
                                    replyFlags |= 1 << 4
                                }
                            }
                            
                            
                            
                            replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: topMsgId, replyToPeerId: replyToPeerId, quoteText: quoteText, quoteEntities: quoteEntities, quoteOffset: quoteOffset, monoforumPeerId: monoforumPeerId)
                        } else if let replyToStoryId = replyToStoryId {
                            if let inputPeer = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputPeer) {
                                flags |= 1 << 0
                                replyTo = .inputReplyToStory(peer: inputPeer, storyId: replyToStoryId.id)
                            }
                        } else if let monoforumPeerId {
                            flags |= 1 << 0
                            replyTo = .inputReplyToMonoForum(monoforumPeerId: monoforumPeerId)
                        }
                        if let attribute = message.webpagePreviewAttribute {
                            if attribute.leadingPreview {
                                flags |= 1 << 16
                            }
                        }
                        if message.invertMedia {
                            flags |= 1 << 16
                        }
                    
                        var quickReplyShortcut: Api.InputQuickReplyShortcut?
                        if let quickReply {
                            if let threadId = message.threadId {
                                quickReplyShortcut = .inputQuickReplyShortcutId(shortcutId: Int32(clamping: threadId))
                            } else {
                                quickReplyShortcut = .inputQuickReplyShortcut(shortcut: quickReply.shortcut)
                            }
                            flags |= 1 << 17
                        }
                    
                        var messageEffectId: Int64?
                        if let messageEffect {
                            flags |= 1 << 18
                            messageEffectId = messageEffect.id
                        }
                    
                        if let _ = allowPaidStars {
                            flags |= 1 << 21
                        }
                        if let _ = suggestedPost {
                            flags |= 1 << 22
                        }
                    
                        sendMessageRequest = network.requestWithAdditionalInfo(Api.functions.messages.sendMessage(flags: flags, peer: inputPeer, replyTo: replyTo, message: message.text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities, scheduleDate: scheduleTime, sendAs: sendAsInputPeer, quickReplyShortcut: quickReplyShortcut, effect: messageEffectId, allowPaidStars: allowPaidStars, suggestedPost: suggestedPost), info: .acknowledgement, tag: dependencyTag)
                    case let .media(inputMedia, text):
                        if bubbleUpEmojiOrStickersets {
                            flags |= Int32(1 << 15)
                        }
                    
                        var replyTo: Api.InputReplyTo?
                        if let replyMessageId = replyMessageId {
                            flags |= 1 << 0
                            
                            var replyFlags: Int32 = 0
                            if topMsgId != nil {
                                replyFlags |= 1 << 0
                            } else if monoforumPeerId != nil {
                                replyFlags |= 1 << 5
                            }
                            
                            var replyToPeerId: Api.InputPeer?
                            if let replyPeerId = replyPeerId {
                                replyToPeerId = transaction.getPeer(replyPeerId).flatMap(apiInputPeer)
                            }
                            if replyToPeerId != nil {
                                replyFlags |= 1 << 1
                            }
                            
                            var quoteText: String?
                            var quoteEntities: [Api.MessageEntity]?
                            var quoteOffset: Int32?
                            if let replyQuote = replyQuote {
                                replyFlags |= 1 << 2
                                quoteText = replyQuote.text
                                
                                quoteOffset = replyQuote.offset.flatMap { Int32.init(clamping: $0) }
                                if quoteOffset != nil {
                                    replyFlags |= 1 << 4
                                }
                                
                                if !replyQuote.entities.isEmpty {
                                    replyFlags |= 1 << 3
                                    var associatedPeers = SimpleDictionary<PeerId, Peer>()
                                    for entity in replyQuote.entities {
                                        for associatedPeerId in entity.associatedPeerIds {
                                            if associatedPeers[associatedPeerId] == nil {
                                                if let associatedPeer = transaction.getPeer(associatedPeerId) {
                                                    associatedPeers[associatedPeerId] = associatedPeer
                                                }
                                            }
                                        }
                                    }
                                    quoteEntities = apiEntitiesFromMessageTextEntities(replyQuote.entities, associatedPeers: associatedPeers)
                                }
                            }
                            
                            replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: topMsgId, replyToPeerId: replyToPeerId, quoteText: quoteText, quoteEntities: quoteEntities, quoteOffset: quoteOffset, monoforumPeerId: monoforumPeerId)
                        } else if let replyToStoryId = replyToStoryId {
                            if let inputPeer = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputPeer) {
                                flags |= 1 << 0
                                replyTo = .inputReplyToStory(peer: inputPeer, storyId: replyToStoryId.id)
                            }
                        } else if let monoforumPeerId {
                            flags |= 1 << 0
                            replyTo = .inputReplyToMonoForum(monoforumPeerId: monoforumPeerId)
                        }
                    
                        if let attribute = message.webpagePreviewAttribute {
                            if attribute.leadingPreview {
                                flags |= 1 << 16
                            }
                        }
                        if message.invertMedia {
                            flags |= 1 << 16
                        }
                    
                        var quickReplyShortcut: Api.InputQuickReplyShortcut?
                        if let quickReply {
                            if let threadId = message.threadId {
                                quickReplyShortcut = .inputQuickReplyShortcutId(shortcutId: Int32(clamping: threadId))
                            } else {
                                quickReplyShortcut = .inputQuickReplyShortcut(shortcut: quickReply.shortcut)
                            }
                            flags |= 1 << 17
                        }
                    
                        var messageEffectId: Int64?
                        if let messageEffect {
                            flags |= 1 << 18
                            messageEffectId = messageEffect.id
                        }
                        
                        if let _ = allowPaidStars {
                            flags |= 1 << 21
                        }
                        if let _ = suggestedPost {
                            flags |= 1 << 22
                        }
                    
                        sendMessageRequest = network.request(Api.functions.messages.sendMedia(flags: flags, peer: inputPeer, replyTo: replyTo, media: inputMedia, message: text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities, scheduleDate: scheduleTime, sendAs: sendAsInputPeer, quickReplyShortcut: quickReplyShortcut, effect: messageEffectId, allowPaidStars: allowPaidStars, suggestedPost: suggestedPost), tag: dependencyTag)
                        |> map(NetworkRequestResult.result)
                    case let .forward(sourceInfo):
                        var topMsgId: Int32?
                        var monoforumPeerId: Api.InputPeer?
                        if let threadId = message.threadId {
                            if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                                if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = transaction.getPeer(linkedMonoforumId) as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                    monoforumPeerId = transaction.getPeer(PeerId(threadId)).flatMap(apiInputPeer)
                                }
                            } else {
                                flags |= Int32(1 << 9)
                                topMsgId = Int32(clamping: threadId)
                            }
                        }
                    
                        var quickReplyShortcut: Api.InputQuickReplyShortcut?
                        if let quickReply {
                            if let threadId = message.threadId {
                                quickReplyShortcut = .inputQuickReplyShortcutId(shortcutId: Int32(clamping: threadId))
                            } else {
                                quickReplyShortcut = .inputQuickReplyShortcut(shortcut: quickReply.shortcut)
                            }
                            flags |= 1 << 17
                        }
                    
                        if videoTimestamp != nil {
                            flags |= 1 << 20
                        }
                    
                        if let _ = allowPaidStars {
                            flags |= 1 << 21
                        }
                    
                        var replyTo: Api.InputReplyTo?
                        if let monoforumPeerId {
                            replyTo = .inputReplyToMonoForum(monoforumPeerId: monoforumPeerId)
                            flags |= 1 << 22
                        }
                    
                        if suggestedPost != nil {
                            flags |= 1 << 23
                        }
                    
                        if let forwardSourceInfoAttribute = forwardSourceInfoAttribute, let sourcePeer = transaction.getPeer(forwardSourceInfoAttribute.messageId.peerId), let sourceInputPeer = apiInputPeer(sourcePeer) {
                            sendMessageRequest = network.request(Api.functions.messages.forwardMessages(flags: flags, fromPeer: sourceInputPeer, id: [sourceInfo.messageId.id], randomId: [uniqueId], toPeer: inputPeer, topMsgId: topMsgId, replyTo: replyTo, scheduleDate: scheduleTime, sendAs: sendAsInputPeer, quickReplyShortcut: quickReplyShortcut, videoTimestamp: videoTimestamp, allowPaidStars: allowPaidStars, suggestedPost: suggestedPost), tag: dependencyTag)
                            |> map(NetworkRequestResult.result)
                        } else {
                            sendMessageRequest = .fail(MTRpcError(errorCode: 400, errorDescription: "internal"))
                        }
                    case let .chatContextResult(chatContextResult):
                        if chatContextResult.hideVia {
                            flags |= Int32(1 << 11)
                        }
                    
                        var replyTo: Api.InputReplyTo?
                        if let replyMessageId = replyMessageId {
                            flags |= 1 << 0
                            
                            var replyFlags: Int32 = 0
                            if topMsgId != nil {
                                replyFlags |= 1 << 0
                            } else if monoforumPeerId != nil {
                                replyFlags |= 1 << 5
                            }
                            
                            var replyToPeerId: Api.InputPeer?
                            if let replyPeerId = replyPeerId {
                                replyToPeerId = transaction.getPeer(replyPeerId).flatMap(apiInputPeer)
                            }
                            if replyToPeerId != nil {
                                replyFlags |= 1 << 1
                            }
                            
                            var quoteText: String?
                            var quoteEntities: [Api.MessageEntity]?
                            var quoteOffset: Int32?
                            if let replyQuote = replyQuote {
                                replyFlags |= 1 << 2
                                quoteText = replyQuote.text
                                
                                quoteOffset = replyQuote.offset.flatMap { Int32.init(clamping: $0) }
                                if quoteOffset != nil {
                                    replyFlags |= 1 << 4
                                }
                                
                                if !replyQuote.entities.isEmpty {
                                    replyFlags |= 1 << 3
                                    var associatedPeers = SimpleDictionary<PeerId, Peer>()
                                    for entity in replyQuote.entities {
                                        for associatedPeerId in entity.associatedPeerIds {
                                            if associatedPeers[associatedPeerId] == nil {
                                                if let associatedPeer = transaction.getPeer(associatedPeerId) {
                                                    associatedPeers[associatedPeerId] = associatedPeer
                                                }
                                            }
                                        }
                                    }
                                    quoteEntities = apiEntitiesFromMessageTextEntities(replyQuote.entities, associatedPeers: associatedPeers)
                                }
                            }
                            
                            replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: message.threadId.flatMap(Int32.init(clamping:)), replyToPeerId: replyToPeerId, quoteText: quoteText, quoteEntities: quoteEntities, quoteOffset: quoteOffset, monoforumPeerId: monoforumPeerId)
                        } else if let replyToStoryId = replyToStoryId {
                            if let inputPeer = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputPeer) {
                                flags |= 1 << 0
                                replyTo = .inputReplyToStory(peer: inputPeer, storyId: replyToStoryId.id)
                            }
                        } else if let monoforumPeerId {
                            flags |= 1 << 0
                            replyTo = .inputReplyToMonoForum(monoforumPeerId: monoforumPeerId)
                        }
                    
                        var quickReplyShortcut: Api.InputQuickReplyShortcut?
                        if let quickReply {
                            if let threadId = message.threadId {
                                quickReplyShortcut = .inputQuickReplyShortcutId(shortcutId: Int32(clamping: threadId))
                            } else {
                                quickReplyShortcut = .inputQuickReplyShortcut(shortcut: quickReply.shortcut)
                            }
                            flags |= 1 << 17
                        }
                    
                        if let _ = allowPaidStars {
                            flags |= 1 << 21
                        }
                    
                        sendMessageRequest = network.request(Api.functions.messages.sendInlineBotResult(flags: flags, peer: inputPeer, replyTo: replyTo, randomId: uniqueId, queryId: chatContextResult.queryId, id: chatContextResult.id, scheduleDate: scheduleTime, sendAs: sendAsInputPeer, quickReplyShortcut: quickReplyShortcut, allowPaidStars: allowPaidStars))
                        |> map(NetworkRequestResult.result)
                    case .messageScreenshot:
                        let replyTo: Api.InputReplyTo
                    
                        if let replyMessageId = replyMessageId {
                            let replyFlags: Int32 = 0
                            replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: nil, replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, monoforumPeerId: nil)
                        } else if let replyToStoryId = replyToStoryId {
                            if let inputPeer = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputPeer) {
                                flags |= 1 << 0
                                replyTo = .inputReplyToStory(peer: inputPeer, storyId: replyToStoryId.id)
                            } else {
                                let replyFlags: Int32 = 0
                                replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: 0, topMsgId: nil, replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, monoforumPeerId: monoforumPeerId)
                            }
                        } else {
                            let replyFlags: Int32 = 0
                            replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: 0, topMsgId: nil, replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, monoforumPeerId: monoforumPeerId)
                        }
                    
                        sendMessageRequest = network.request(Api.functions.messages.sendScreenshotNotification(peer: inputPeer, replyTo: replyTo, randomId: uniqueId))
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
                        case .progress:
                            return .complete()
                        case .acknowledged:
                            return strongSelf.applyAcknowledgedMessage(postbox: postbox, message: message)
                            |> mapError { _ -> MTRpcError in
                            }
                        case let .result(result):
                            return strongSelf.applySentMessage(postbox: postbox, stateManager: stateManager, message: message, content: content, result: result)
                            |> mapError { _ -> MTRpcError in
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
                        } else if let failureReason = sendMessageReasonForError(error.errorDescription) {
                            if let context = strongSelf.messageContexts[message.id] {
                                context.error = failureReason
                                for f in context.statusSubscribers.copyItems() {
                                    f(context.status, context.error)
                                }
                            }
                            
                            if let context = strongSelf.peerSummaryContexts[message.id.peerId] {
                                for subscriber in context.messageFailedSubscribers.copyItems() {
                                    subscriber(failureReason)
                                }
                            }
                        }
                        let _ = (postbox.transaction { transaction -> Void in
                            transaction.updateMessage(message.id, update: { currentMessage in
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                                }
                                return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
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
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                        }
                        return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
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
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
        }
    }
    
    private func applySentMessage(postbox: Postbox, stateManager: AccountStateManager, message: Message, content: PendingMessageUploadedContentAndReuploadInfo, result: Api.Updates) -> Signal<Void, NoError> {
        if let channel = message.peers[message.id.peerId] as? TelegramChannel, channel.isMonoForum {
            for attribute in message.attributes {
                if let attribute = attribute as? PaidStarsMessageAttribute {
                    stateManager.starsContext?.add(balance: StarsAmount(value: -attribute.stars.value, nanos: (attribute.stars.value == 0 && attribute.stars.nanos != 0 ? -1 : 1) * attribute.stars.nanos))
                    break
                }
            }
        }
        
        var apiMessage: Api.Message?
        for resultMessage in result.messages {
            let targetNamespace: MessageId.Namespace
            if Namespaces.Message.allScheduled.contains(message.id.namespace) {
                targetNamespace = Namespaces.Message.ScheduledCloud
            } else if Namespaces.Message.allQuickReply.contains(message.id.namespace) {
                targetNamespace = Namespaces.Message.QuickReplyCloud
            } else {
                targetNamespace = Namespaces.Message.Cloud
            }
                
            if let id = resultMessage.id(namespace: targetNamespace) {
                if id.peerId == message.id.peerId {
                    apiMessage = resultMessage
                    break
                }
            }
        }
        
        if message.id.namespace == Namespaces.Message.QuickReplyLocal {
        } else if let apiMessage {
            var isScheduled = false
            if message.scheduleTime != nil && message.scheduleTime == apiMessage.timestamp {
                isScheduled = true
            }
            if case let .message(_, flags2, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = apiMessage {
                if (flags2 & (1 << 4)) != 0 {
                    isScheduled = true
                }
            }
            if let id = apiMessage.id(namespace: isScheduled ? Namespaces.Message.ScheduledCloud : Namespaces.Message.Cloud) {
                if let attribute = message.attributes.first(where: { $0 is OutgoingMessageInfoAttribute }) as? OutgoingMessageInfoAttribute, let correlationId = attribute.correlationId {
                    self.correlationIdToSentMessageId.with { value in
                        value.mapping[correlationId] = id
                    }
                }
            }
        }
        
        let queue = self.queue
        return applyUpdateMessage(postbox: postbox, stateManager: stateManager, message: message, cacheReferenceKey: content.cacheReferenceKey, result: result, accountPeerId: self.accountPeerId, pendingMessageEvent: { [weak self] pendingMessageDelivered in
            queue.async {
                if let strongSelf = self {
                    if let context = strongSelf.peerSummaryContexts[message.id.peerId] {
                        for subscriber in context.messageDeliveredSubscribers.copyItems() {
                            subscriber([pendingMessageDelivered])
                        }
                    }
                }
            }
        })
    }
    
    private func applySentGroupMessages(postbox: Postbox, stateManager: AccountStateManager, messages: [Message], result: Api.Updates) -> Signal<Void, NoError> {
        var namespace = Namespaces.Message.Cloud
        if let message = messages.first {
            if let channel = message.peers[message.id.peerId] as? TelegramChannel, channel.isMonoForum {
                for attribute in message.attributes {
                    if let attribute = attribute as? PaidStarsMessageAttribute {
                        stateManager.starsContext?.add(balance: StarsAmount(value: -attribute.stars.value, nanos: (attribute.stars.value == 0 && attribute.stars.nanos != 0 ? -1 : 1) * attribute.stars.nanos))
                        break
                    }
                }
            }
            
            if message.id.namespace == Namespaces.Message.QuickReplyLocal {
                namespace = Namespaces.Message.QuickReplyCloud
            } else if let apiMessage = result.messages.first, message.scheduleTime != nil && message.scheduleTime == apiMessage.timestamp {
                namespace = Namespaces.Message.ScheduledCloud
            } else if let apiMessage = result.messages.first, case let .message(_, flags2, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = apiMessage, (flags2 & (1 << 4)) != 0 {
                namespace = Namespaces.Message.ScheduledCloud
            }
        }
        
        if messages.count == result.messages.count {
            for i in 0 ..< messages.count {
                let message = messages[i]
                let apiMessage = result.messages[i]
                if let id = apiMessage.id(namespace: namespace) {
                    if let attribute = message.attributes.first(where: { $0 is OutgoingMessageInfoAttribute }) as? OutgoingMessageInfoAttribute, let correlationId = attribute.correlationId {
                        self.correlationIdToSentMessageId.with { value in
                            value.mapping[correlationId] = id
                        }
                    }
                }
            }
        }
        let queue = self.queue
        
        return applyUpdateGroupMessages(postbox: postbox, stateManager: stateManager, messages: messages, result: result, pendingMessageEvents: { [weak self] pendingMessagesDelivered in
            queue.async {
                if let strongSelf = self {
                    if let message = messages.first, let context = strongSelf.peerSummaryContexts[message.id.peerId], !pendingMessagesDelivered.isEmpty {
                        for subscriber in context.messageDeliveredSubscribers.copyItems() {
                            subscriber(pendingMessagesDelivered)
                        }
                    }
                }
            }
        })
    }
    
    public func deliveredMessageEvents(peerId: PeerId) -> Signal<[PeerPendingMessageDelivered], NoError> {
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
                
                let index = summaryContext.messageDeliveredSubscribers.add({ event in
                    subscriber.putNext(event)
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
    
    public func failedMessageEvents(peerId: PeerId) -> Signal<PendingMessageFailureReason, NoError> {
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
                
                let index = summaryContext.messageFailedSubscribers.add({ reason in
                    subscriber.putNext(reason)
                })
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        if let current = self.peerSummaryContexts[peerId] {
                            current.messageFailedSubscribers.remove(index)
                            if current.messageFailedSubscribers.isEmpty {
                                self.peerSummaryContexts.removeValue(forKey: peerId)
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
    }
    
    public func synchronouslyLookupCorrelationId(correlationId: Int64) -> MessageId? {
        return self.correlationIdToSentMessageId.with { $0.mapping[correlationId] }
    }
}

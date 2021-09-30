import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

private struct DiscussionMessage {
    var messageId: MessageId
    var channelMessageId: MessageId?
    var isChannelPost: Bool
    var maxMessage: MessageId?
    var maxReadIncomingMessageId: MessageId?
    var maxReadOutgoingMessageId: MessageId?
    var unreadCount: Int
}

private class ReplyThreadHistoryContextImpl {
    private let queue: Queue
    private let account: Account
    private let messageId: MessageId
    
    private var currentHole: (MessageHistoryHolesViewEntry, Disposable)?
    
    struct State: Equatable {
        var messageId: MessageId
        var holeIndices: [MessageId.Namespace: IndexSet]
        var maxReadIncomingMessageId: MessageId?
        var maxReadOutgoingMessageId: MessageId?
    }
    
    let state = Promise<State>()
    private var stateValue: State? {
        didSet {
            if let stateValue = self.stateValue {
                if stateValue != oldValue {
                    self.state.set(.single(stateValue))
                }
            }
        }
    }
    
    let maxReadOutgoingMessageId = Promise<MessageId?>()
    private var maxReadOutgoingMessageIdValue: MessageId? {
        didSet {
            if self.maxReadOutgoingMessageIdValue != oldValue {
                self.maxReadOutgoingMessageId.set(.single(self.maxReadOutgoingMessageIdValue))
            }
        }
    }

    private var maxReadIncomingMessageIdValue: MessageId?

    let unreadCount = Promise<Int>()
    private var unreadCountValue: Int = 0 {
        didSet {
            if self.unreadCountValue != oldValue {
                self.unreadCount.set(.single(self.unreadCountValue))
            }
        }
    }
    
    private var initialStateDisposable: Disposable?
    private var holesDisposable: Disposable?
    private var readStateDisposable: Disposable?
    private var updateInitialStateDisposable: Disposable?
    private let readDisposable = MetaDisposable()
    
    init(queue: Queue, account: Account, data: ChatReplyThreadMessage) {
        self.queue = queue
        self.account = account
        self.messageId = data.messageId
        
        self.maxReadOutgoingMessageIdValue = data.maxReadOutgoingMessageId
        self.maxReadOutgoingMessageId.set(.single(self.maxReadOutgoingMessageIdValue))

        self.maxReadIncomingMessageIdValue = data.maxReadIncomingMessageId

        self.unreadCountValue = data.unreadCount
        self.unreadCount.set(.single(self.unreadCountValue))
        
        self.initialStateDisposable = (account.postbox.transaction { transaction -> State in
            var indices = transaction.getThreadIndexHoles(peerId: data.messageId.peerId, threadId: makeMessageThreadId(data.messageId), namespace: Namespaces.Message.Cloud)
            indices.subtract(data.initialFilledHoles)
            
            let isParticipant = transaction.getPeerChatListIndex(data.messageId.peerId) != nil
            if isParticipant {
                let historyHoles = transaction.getHoles(peerId: data.messageId.peerId, namespace: Namespaces.Message.Cloud)
                indices.formIntersection(historyHoles)
            }
            
            if let maxMessageId = data.maxMessage {
                indices.remove(integersIn: Int(maxMessageId.id + 1) ..< Int(Int32.max))
            } else {
                indices.removeAll()
            }
            
            return State(messageId: data.messageId, holeIndices: [Namespaces.Message.Cloud: indices], maxReadIncomingMessageId: data.maxReadIncomingMessageId, maxReadOutgoingMessageId: data.maxReadOutgoingMessageId)
        }
        |> deliverOn(self.queue)).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.stateValue = state
            strongSelf.state.set(.single(state))
        })
        
        let threadId = makeMessageThreadId(messageId)
        
        self.holesDisposable = (account.postbox.messageHistoryHolesView()
        |> map { view -> MessageHistoryHolesViewEntry? in
            for entry in view.entries {
                switch entry.hole {
                case let .peer(hole):
                    if hole.threadId == threadId {
                        return entry
                    }
                }
            }
            return nil
        }
        |> distinctUntilChanged
        |> deliverOn(self.queue)).start(next: { [weak self] entry in
            guard let strongSelf = self else {
                return
            }
            strongSelf.setCurrentHole(entry: entry)
        })
        
        self.readStateDisposable = (account.stateManager.threadReadStateUpdates
        |> deliverOn(self.queue)).start(next: { [weak self] (_, outgoing) in
            guard let strongSelf = self else {
                return
            }
            if let value = outgoing[data.messageId] {
                strongSelf.maxReadOutgoingMessageIdValue = MessageId(peerId: data.messageId.peerId, namespace: Namespaces.Message.Cloud, id: value)
            }
        })
        
        let updateInitialState: Signal<DiscussionMessage, FetchChannelReplyThreadMessageError> = account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(data.messageId.peerId).flatMap(apiInputPeer)
        }
        |> castError(FetchChannelReplyThreadMessageError.self)
        |> mapToSignal { inputPeer -> Signal<DiscussionMessage, FetchChannelReplyThreadMessageError> in
            guard let inputPeer = inputPeer else {
                return .fail(.generic)
            }
            
            return account.network.request(Api.functions.messages.getDiscussionMessage(peer: inputPeer, msgId: data.messageId.id))
            |> mapError { _ -> FetchChannelReplyThreadMessageError in
                return .generic
            }
            |> mapToSignal { discussionMessage -> Signal<DiscussionMessage, FetchChannelReplyThreadMessageError> in
                return account.postbox.transaction { transaction -> Signal<DiscussionMessage, FetchChannelReplyThreadMessageError> in
                    switch discussionMessage {
                    case let .discussionMessage(_, messages, maxId, readInboxMaxId, readOutboxMaxId, unreadCount, chats, users):
                        let parsedMessages = messages.compactMap { message -> StoreMessage? in
                            StoreMessage(apiMessage: message)
                        }
                        
                        guard let topMessage = parsedMessages.last, let parsedIndex = topMessage.index else {
                            return .fail(.generic)
                        }
                        
                        var channelMessageId: MessageId?
                        var replyThreadAttribute: ReplyThreadMessageAttribute?
                        for attribute in topMessage.attributes {
                            if let attribute = attribute as? SourceReferenceMessageAttribute {
                                channelMessageId = attribute.messageId
                            } else if let attribute = attribute as? ReplyThreadMessageAttribute {
                                replyThreadAttribute = attribute
                            }
                        }
                        
                        var peers: [Peer] = []
                        var peerPresences: [PeerId: PeerPresence] = [:]
                        
                        for chat in chats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(groupOrChannel)
                            }
                        }
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            if let presence = TelegramUserPresence(apiUser: user) {
                                peerPresences[telegramUser.id] = presence
                            }
                        }
                        
                        let _ = transaction.addMessages(parsedMessages, location: .Random)
                        
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        
                        updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                        
                        let resolvedMaxMessage: MessageId?
                        if let maxId = maxId {
                            resolvedMaxMessage = MessageId(
                                peerId: parsedIndex.id.peerId,
                                namespace: Namespaces.Message.Cloud,
                                id: maxId
                            )
                        } else {
                            resolvedMaxMessage = nil
                        }
                        
                        var isChannelPost = false
                        for attribute in topMessage.attributes {
                            if let _ = attribute as? SourceReferenceMessageAttribute {
                                isChannelPost = true
                                break
                            }
                        }
                        
                        let maxReadIncomingMessageId = readInboxMaxId.flatMap { readMaxId in
                            MessageId(peerId: parsedIndex.id.peerId, namespace: Namespaces.Message.Cloud, id: readMaxId)
                        }
                        
                        if let channelMessageId = channelMessageId, let replyThreadAttribute = replyThreadAttribute {
                            account.viewTracker.updateReplyInfoForMessageId(channelMessageId, info: AccountViewTracker.UpdatedMessageReplyInfo(
                                timestamp: Int32(CFAbsoluteTimeGetCurrent()),
                                commentsPeerId: parsedIndex.id.peerId,
                                maxReadIncomingMessageId: maxReadIncomingMessageId,
                                maxMessageId: resolvedMaxMessage
                            ))
                            
                            transaction.updateMessage(channelMessageId, update: { currentMessage in
                                var attributes = currentMessage.attributes
                                loop: for j in 0 ..< attributes.count {
                                    if let attribute = attributes[j] as? ReplyThreadMessageAttribute {
                                        attributes[j] = ReplyThreadMessageAttribute(
                                            count: replyThreadAttribute.count,
                                            latestUsers: attribute.latestUsers,
                                            commentsPeerId: attribute.commentsPeerId,
                                            maxMessageId: replyThreadAttribute.maxMessageId,
                                            maxReadMessageId: replyThreadAttribute.maxReadMessageId
                                        )
                                    }
                                }
                                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                            })
                        }
                        
                        return .single(DiscussionMessage(
                            messageId: parsedIndex.id,
                            channelMessageId: channelMessageId,
                            isChannelPost: isChannelPost,
                            maxMessage: resolvedMaxMessage,
                            maxReadIncomingMessageId: maxReadIncomingMessageId,
                            maxReadOutgoingMessageId: readOutboxMaxId.flatMap { readMaxId in
                                MessageId(peerId: parsedIndex.id.peerId, namespace: Namespaces.Message.Cloud, id: readMaxId)
                            },
                            unreadCount: Int(unreadCount)
                        ))
                    }
                }
                |> castError(FetchChannelReplyThreadMessageError.self)
                |> switchToLatest
            }
        }
        
        self.updateInitialStateDisposable = (updateInitialState
        |> deliverOnMainQueue).start(next: { [weak self] updatedData in
            guard let strongSelf = self else {
                return
            }
            if let maxReadOutgoingMessageId = updatedData.maxReadOutgoingMessageId {
                if let current = strongSelf.maxReadOutgoingMessageIdValue {
                    if maxReadOutgoingMessageId > current {
                        strongSelf.maxReadOutgoingMessageIdValue = maxReadOutgoingMessageId
                    }
                } else {
                    strongSelf.maxReadOutgoingMessageIdValue = maxReadOutgoingMessageId
                }
            }
        })
    }
    
    deinit {
        self.initialStateDisposable?.dispose()
        self.holesDisposable?.dispose()
        self.readDisposable.dispose()
        self.updateInitialStateDisposable?.dispose()
    }
    
    func setCurrentHole(entry: MessageHistoryHolesViewEntry?) {
        if self.currentHole?.0 != entry {
            self.currentHole?.1.dispose()
            if let entry = entry {
                self.currentHole = (entry, self.fetchHole(entry: entry).start(next: { [weak self] removedHoleIndices in
                    guard let strongSelf = self, let removedHoleIndices = removedHoleIndices else {
                        return
                    }
                    if var currentHoles = strongSelf.stateValue?.holeIndices[Namespaces.Message.Cloud] {
                        currentHoles.subtract(removedHoleIndices.removedIndices)
                        strongSelf.stateValue?.holeIndices[Namespaces.Message.Cloud] = currentHoles
                    }
                }))
            } else {
                self.currentHole = nil
            }
        }
    }
    
    private func fetchHole(entry: MessageHistoryHolesViewEntry) -> Signal<FetchMessageHistoryHoleResult?, NoError> {
        switch entry.hole {
        case let .peer(hole):
            let fetchCount = min(entry.count, 100)
            return fetchMessageHistoryHole(accountPeerId: self.account.peerId, source: .network(self.account.network), postbox: self.account.postbox, peerInput: .direct(peerId: hole.peerId, threadId: hole.threadId), namespace: hole.namespace, direction: entry.direction, space: entry.space, count: fetchCount)
        }
    }
    
    func applyMaxReadIndex(messageIndex: MessageIndex) {
        let messageId = self.messageId
        
        if messageIndex.id.namespace != messageId.namespace {
            return
        }

        guard let _ = self.stateValue else {
            return
        }

        let fromIdExclusive: Int32?
        let toIndex = messageIndex
        if let maxReadIncomingMessageId = self.maxReadIncomingMessageIdValue {
            fromIdExclusive = maxReadIncomingMessageId.id
        } else {
            fromIdExclusive = nil
        }
        self.maxReadIncomingMessageIdValue = messageIndex.id

        let account = self.account
        
        let _ = (self.account.postbox.transaction { transaction -> (Api.InputPeer?, MessageId?, Int?) in
            if let message = transaction.getMessage(messageId) {
                for attribute in message.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        if let sourceMessage = transaction.getMessage(attribute.messageId) {
                            account.viewTracker.applyMaxReadIncomingMessageIdForReplyInfo(id: attribute.messageId, maxReadIncomingMessageId: messageIndex.id)
                            
                            var updatedAttribute: ReplyThreadMessageAttribute?
                            for i in 0 ..< sourceMessage.attributes.count {
                                if let attribute = sourceMessage.attributes[i] as? ReplyThreadMessageAttribute {
                                    if let maxReadMessageId = attribute.maxReadMessageId {
                                        if maxReadMessageId < messageIndex.id.id {
                                            updatedAttribute = ReplyThreadMessageAttribute(count: attribute.count, latestUsers: attribute.latestUsers, commentsPeerId: attribute.commentsPeerId, maxMessageId: attribute.maxMessageId, maxReadMessageId: messageIndex.id.id)
                                        }
                                    } else {
                                        updatedAttribute = ReplyThreadMessageAttribute(count: attribute.count, latestUsers: attribute.latestUsers, commentsPeerId: attribute.commentsPeerId, maxMessageId: attribute.maxMessageId, maxReadMessageId: messageIndex.id.id)
                                    }
                                    break
                                }
                            }
                            if let updatedAttribute = updatedAttribute {
                                transaction.updateMessage(sourceMessage.id, update: { currentMessage in
                                    var attributes = currentMessage.attributes
                                    loop: for j in 0 ..< attributes.count {
                                        if let _ = attributes[j] as? ReplyThreadMessageAttribute {
                                            attributes[j] = updatedAttribute
                                        }
                                    }
                                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                })
                            }
                        }
                        break
                    }
                }
            }

            let inputPeer = transaction.getPeer(messageIndex.id.peerId).flatMap(apiInputPeer)
            let readCount = transaction.getThreadMessageCount(peerId: messageId.peerId, threadId: makeMessageThreadId(messageId), namespace: messageId.namespace, fromIdExclusive: fromIdExclusive, toIndex: toIndex)
            let topMessageId = transaction.getMessagesWithThreadId(peerId: messageId.peerId, namespace: messageId.namespace, threadId: makeMessageThreadId(messageId), from: MessageIndex.upperBound(peerId: messageId.peerId, namespace: messageId.namespace), includeFrom: false, to: MessageIndex.lowerBound(peerId: messageId.peerId, namespace: messageId.namespace), limit: 1).first?.id
            
            return (inputPeer, topMessageId, readCount)
        }
        |> deliverOnMainQueue).start(next: { [weak self] inputPeer, topMessageId, readCount in
            guard let strongSelf = self else {
                return
            }

            guard let inputPeer = inputPeer else {
                return
            }

            var revalidate = false

            var unreadCountValue = strongSelf.unreadCountValue
            if let readCount = readCount {
                unreadCountValue = max(0, unreadCountValue - Int(readCount))
            } else {
                revalidate = true
            }

            if let topMessageId = topMessageId {
                if topMessageId.id <= messageIndex.id.id {
                    unreadCountValue = 0
                }
            }

            strongSelf.unreadCountValue = unreadCountValue

            if let state = strongSelf.stateValue {
                if let indices = state.holeIndices[messageIndex.id.namespace] {
                    let fromIdInt: Int
                    if let fromIdExclusive = fromIdExclusive {
                        fromIdInt = Int(fromIdExclusive + 1)
                    } else {
                        fromIdInt = 1
                    }
                    let toIdInt = Int(toIndex.id.id)
                    if fromIdInt <= toIdInt, indices.intersects(integersIn: fromIdInt ..< toIdInt) {
                        revalidate = true
                    }
                }
            }

            var signal = strongSelf.account.network.request(Api.functions.messages.readDiscussion(peer: inputPeer, msgId: messageId.id, readMaxId: messageIndex.id.id))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
            if revalidate {
                let validateSignal = strongSelf.account.network.request(Api.functions.messages.getDiscussionMessage(peer: inputPeer, msgId: messageId.id))
                |> map { result -> (MessageId?, Int) in
                    switch result {
                    case let .discussionMessage(_, _, _, readInboxMaxId, _, unreadCount, _, _):
                        return (readInboxMaxId.flatMap({ MessageId(peerId: messageId.peerId, namespace: messageId.namespace, id: $0) }), Int(unreadCount))
                    }
                }
                |> `catch` { _ -> Signal<(MessageId?, Int)?, NoError> in
                    return .single(nil)
                }
                |> afterNext { result in
                    guard let (incomingMesageId, count) = result else {
                        return
                    }
                    Queue.mainQueue().async {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.maxReadIncomingMessageIdValue = incomingMesageId
                        strongSelf.unreadCountValue = count
                    }
                }
                |> ignoreValues
                signal = signal
                |> then(validateSignal)
            }
            strongSelf.readDisposable.set(signal.start())
        })
    }
}

public class ReplyThreadHistoryContext {
    fileprivate final class GuardReference {
        private let deallocated: () -> Void
        
        init(deallocated: @escaping () -> Void) {
            self.deallocated = deallocated
        }
        
        deinit {
            self.deallocated()
        }
    }
    
    private let queue = Queue()
    private let impl: QueueLocalObject<ReplyThreadHistoryContextImpl>
    
    public var state: Signal<MessageHistoryViewExternalInput, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                let stateDisposable = impl.state.get().start(next: { state in
                    subscriber.putNext(MessageHistoryViewExternalInput(
                        peerId: state.messageId.peerId,
                        threadId: makeMessageThreadId(state.messageId),
                        maxReadIncomingMessageId: state.maxReadIncomingMessageId,
                        maxReadOutgoingMessageId: state.maxReadOutgoingMessageId,
                        holes: state.holeIndices
                    ))
                })
                disposable.set(stateDisposable)
            }
            
            return disposable
        }
    }
    
    public var maxReadOutgoingMessageId: Signal<MessageId?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                disposable.set(impl.maxReadOutgoingMessageId.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            
            return disposable
        }
    }

    public var unreadCount: Signal<Int, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()

            self.impl.with { impl in
                disposable.set(impl.unreadCount.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }

            return disposable
        }
    }
    
    public init(account: Account, peerId: PeerId, data: ChatReplyThreadMessage) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ReplyThreadHistoryContextImpl(queue: queue, account: account, data: data)
        })
    }
    
    public func applyMaxReadIndex(messageIndex: MessageIndex) {
        self.impl.with { impl in
            impl.applyMaxReadIndex(messageIndex: messageIndex)
        }
    }
}

public struct ChatReplyThreadMessage: Equatable {
    public enum Anchor: Equatable {
        case automatic
        case lowerBoundMessage(MessageIndex)
    }
    
    public var messageId: MessageId
    public var channelMessageId: MessageId?
    public var isChannelPost: Bool
    public var maxMessage: MessageId?
    public var maxReadIncomingMessageId: MessageId?
    public var maxReadOutgoingMessageId: MessageId?
    public var unreadCount: Int
    public var initialFilledHoles: IndexSet
    public var initialAnchor: Anchor
    public var isNotAvailable: Bool
    
    fileprivate init(messageId: MessageId, channelMessageId: MessageId?, isChannelPost: Bool, maxMessage: MessageId?, maxReadIncomingMessageId: MessageId?, maxReadOutgoingMessageId: MessageId?, unreadCount: Int, initialFilledHoles: IndexSet, initialAnchor: Anchor, isNotAvailable: Bool) {
        self.messageId = messageId
        self.channelMessageId = channelMessageId
        self.isChannelPost = isChannelPost
        self.maxMessage = maxMessage
        self.maxReadIncomingMessageId = maxReadIncomingMessageId
        self.maxReadOutgoingMessageId = maxReadOutgoingMessageId
        self.unreadCount = unreadCount
        self.initialFilledHoles = initialFilledHoles
        self.initialAnchor = initialAnchor
        self.isNotAvailable = isNotAvailable
    }
}

public enum FetchChannelReplyThreadMessageError {
    case generic
}

func _internal_fetchChannelReplyThreadMessage(account: Account, messageId: MessageId, atMessageId: MessageId?) -> Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> castError(FetchChannelReplyThreadMessageError.self)
    |> mapToSignal { inputPeer -> Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        
        let replyInfo = Promise<AccountViewTracker.UpdatedMessageReplyInfo?>()
        replyInfo.set(.single(nil))
        
        let remoteDiscussionMessageSignal: Signal<DiscussionMessage?, NoError> = account.network.request(Api.functions.messages.getDiscussionMessage(peer: inputPeer, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.DiscussionMessage?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { discussionMessage -> Signal<DiscussionMessage?, NoError> in
            guard let discussionMessage = discussionMessage else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> DiscussionMessage? in
                switch discussionMessage {
                case let .discussionMessage(_, messages, maxId, readInboxMaxId, readOutboxMaxId, unreadCount, chats, users):
                    let parsedMessages = messages.compactMap { message -> StoreMessage? in
                        StoreMessage(apiMessage: message)
                    }
                    
                    guard let topMessage = parsedMessages.last, let parsedIndex = topMessage.index else {
                        return nil
                    }
                    
                    var channelMessageId: MessageId?
                    for attribute in topMessage.attributes {
                        if let attribute = attribute as? SourceReferenceMessageAttribute {
                            channelMessageId = attribute.messageId
                            break
                        }
                    }
                    
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: PeerPresence] = [:]
                    
                    for chat in chats {
                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                            peers.append(groupOrChannel)
                        }
                    }
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        if let presence = TelegramUserPresence(apiUser: user) {
                            peerPresences[telegramUser.id] = presence
                        }
                    }
                    
                    let _ = transaction.addMessages(parsedMessages, location: .Random)
                    
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                        return updated
                    })
                    
                    updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                    
                    let resolvedMaxMessage: MessageId?
                    if let maxId = maxId {
                        resolvedMaxMessage = MessageId(
                            peerId: parsedIndex.id.peerId,
                            namespace: Namespaces.Message.Cloud,
                            id: maxId
                        )
                    } else {
                        resolvedMaxMessage = nil
                    }
                    
                    var isChannelPost = false
                    for attribute in topMessage.attributes {
                        if let _ = attribute as? SourceReferenceMessageAttribute {
                            isChannelPost = true
                            break
                        }
                    }
                    
                    return DiscussionMessage(
                        messageId: parsedIndex.id,
                        channelMessageId: channelMessageId,
                        isChannelPost: isChannelPost,
                        maxMessage: resolvedMaxMessage,
                        maxReadIncomingMessageId: readInboxMaxId.flatMap { readMaxId in
                            MessageId(peerId: parsedIndex.id.peerId, namespace: Namespaces.Message.Cloud, id: readMaxId)
                        },
                        maxReadOutgoingMessageId: readOutboxMaxId.flatMap { readMaxId in
                            MessageId(peerId: parsedIndex.id.peerId, namespace: Namespaces.Message.Cloud, id: readMaxId)
                        },
                        unreadCount: Int(unreadCount)
                    )
                }
            }
        }
        let discussionMessageSignal = (replyInfo.get()
        |> take(1)
        |> mapToSignal { replyInfo -> Signal<DiscussionMessage?, NoError> in
            guard let replyInfo = replyInfo else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> DiscussionMessage? in
                var foundDiscussionMessageId: MessageId?
                transaction.scanMessageAttributes(peerId: replyInfo.commentsPeerId, namespace: Namespaces.Message.Cloud, limit: 1000, { id, attributes in
                    for attribute in attributes {
                        if let attribute = attribute as? SourceReferenceMessageAttribute {
                            if attribute.messageId == messageId {
                                foundDiscussionMessageId = id
                                return true
                            }
                        }
                    }
                    if foundDiscussionMessageId != nil {
                        return false
                    }
                    return true
                })
                guard let discussionMessageId = foundDiscussionMessageId else {
                    return nil
                }
                
                return DiscussionMessage(
                    messageId: discussionMessageId,
                    channelMessageId: messageId,
                    isChannelPost: true,
                    maxMessage: replyInfo.maxMessageId,
                    maxReadIncomingMessageId: replyInfo.maxReadIncomingMessageId,
                    maxReadOutgoingMessageId: nil,
                    unreadCount: 0
                )
            }
        })
        |> mapToSignal { result -> Signal<DiscussionMessage?, NoError> in
            if let result = result {
                return .single(result)
            } else {
                return remoteDiscussionMessageSignal
            }
        }
        let discussionMessage = Promise<DiscussionMessage?>()
        discussionMessage.set(discussionMessageSignal)
        
        enum Anchor {
            case message(MessageId)
            case lowerBound
            case upperBound
        }
        
        let preloadedHistoryPosition: Signal<(FetchMessageHistoryHoleThreadInput, PeerId, MessageId?, Anchor, MessageId?), FetchChannelReplyThreadMessageError> = replyInfo.get()
        |> take(1)
        |> castError(FetchChannelReplyThreadMessageError.self)
        |> mapToSignal { replyInfo -> Signal<(FetchMessageHistoryHoleThreadInput, PeerId, MessageId?, Anchor, MessageId?), FetchChannelReplyThreadMessageError> in
            if let replyInfo = replyInfo {
                return account.postbox.transaction { transaction -> (FetchMessageHistoryHoleThreadInput, PeerId, MessageId?, Anchor, MessageId?) in
                    var threadInput: FetchMessageHistoryHoleThreadInput = .threadFromChannel(channelMessageId: messageId)
                    var threadMessageId: MessageId?
                    transaction.scanMessageAttributes(peerId: replyInfo.commentsPeerId, namespace: Namespaces.Message.Cloud, limit: 1000, { id, attributes in
                        for attribute in attributes {
                            if let attribute = attribute as? SourceReferenceMessageAttribute {
                                if attribute.messageId == messageId {
                                    threadMessageId = id
                                    threadInput = .direct(peerId: id.peerId, threadId: makeMessageThreadId(id))
                                    return false
                                }
                            }
                        }
                        return true
                    })
                    let anchor: Anchor
                    if let atMessageId = atMessageId {
                        anchor = .message(atMessageId)
                    } else if let maxReadIncomingMessageId = replyInfo.maxReadIncomingMessageId {
                        anchor = .message(maxReadIncomingMessageId)
                    } else {
                        anchor = .lowerBound
                    }
                    return (threadInput, replyInfo.commentsPeerId, threadMessageId, anchor, replyInfo.maxMessageId)
                }
                |> castError(FetchChannelReplyThreadMessageError.self)
            } else {
                return discussionMessage.get()
                |> take(1)
                |> castError(FetchChannelReplyThreadMessageError.self)
                |> mapToSignal { discussionMessage -> Signal<(FetchMessageHistoryHoleThreadInput, PeerId, MessageId?, Anchor, MessageId?), FetchChannelReplyThreadMessageError> in
                    guard let discussionMessage = discussionMessage else {
                        return .fail(.generic)
                    }
                    
                    let topMessageId = discussionMessage.messageId
                    let commentsPeerId = topMessageId.peerId
                    let anchor: Anchor
                    if let atMessageId = atMessageId {
                        anchor = .message(atMessageId)
                    } else if let maxReadIncomingMessageId = discussionMessage.maxReadIncomingMessageId {
                        anchor = .message(maxReadIncomingMessageId)
                    } else {
                        anchor = .lowerBound
                    }
                    return .single((.direct(peerId: commentsPeerId, threadId: makeMessageThreadId(topMessageId)), commentsPeerId, discussionMessage.messageId, anchor, discussionMessage.maxMessage))
                }
            }
        }
        
        let preloadedHistory = preloadedHistoryPosition
        |> mapToSignal { peerInput, commentsPeerId, threadMessageId, anchor, maxMessageId -> Signal<(FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor), FetchChannelReplyThreadMessageError> in
            guard let maxMessageId = maxMessageId else {
                return .single((FetchMessageHistoryHoleResult(removedIndices: IndexSet(integersIn: 1 ..< Int(Int32.max - 1)), strictRemovedIndices: IndexSet(), actualPeerId: nil, actualThreadId: nil), .automatic))
            }
            return account.postbox.transaction { transaction -> Signal<(FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor), FetchChannelReplyThreadMessageError> in
                if let threadMessageId = threadMessageId {
                    var holes = transaction.getThreadIndexHoles(peerId: threadMessageId.peerId, threadId: makeMessageThreadId(threadMessageId), namespace: Namespaces.Message.Cloud)
                    holes.remove(integersIn: Int(maxMessageId.id + 1) ..< Int(Int32.max))
                    
                    let isParticipant = transaction.getPeerChatListIndex(commentsPeerId) != nil
                    if isParticipant {
                        let historyHoles = transaction.getHoles(peerId: commentsPeerId, namespace: Namespaces.Message.Cloud)
                        holes.formIntersection(historyHoles)
                    }
                    
                    let inputAnchor: HistoryViewInputAnchor
                    switch anchor {
                    case .lowerBound:
                        inputAnchor = .lowerBound
                    case .upperBound:
                        inputAnchor = .upperBound
                    case let .message(id):
                        inputAnchor = .message(id)
                    }
                    
                    let testView = transaction.getMessagesHistoryViewState(
                        input: .external(MessageHistoryViewExternalInput(
                            peerId: commentsPeerId,
                            threadId: makeMessageThreadId(threadMessageId),
                            maxReadIncomingMessageId: nil,
                            maxReadOutgoingMessageId: nil,
                            holes: [
                                Namespaces.Message.Cloud: holes
                            ]
                        )),
                        count: 40,
                        clipHoles: true,
                        anchor: inputAnchor,
                        namespaces: .not(Namespaces.Message.allScheduled)
                    )
                    if !testView.isLoading {
                        let initialAnchor: ChatReplyThreadMessage.Anchor
                        switch anchor {
                        case .lowerBound:
                            if let entry = testView.entries.first {
                                initialAnchor = .lowerBoundMessage(entry.index)
                            } else {
                                initialAnchor = .automatic
                            }
                        case .upperBound:
                            initialAnchor = .automatic
                        case .message:
                            initialAnchor = .automatic
                        }
                        
                        return .single((FetchMessageHistoryHoleResult(removedIndices: IndexSet(), strictRemovedIndices: IndexSet(), actualPeerId: nil, actualThreadId: nil), initialAnchor))
                    }
                }
                
                let direction: MessageHistoryViewRelativeHoleDirection
                switch anchor {
                case .lowerBound:
                    direction = .range(start: MessageId(peerId: commentsPeerId, namespace: Namespaces.Message.Cloud, id: 1), end: MessageId(peerId: commentsPeerId, namespace: Namespaces.Message.Cloud, id: Int32.max - 1))
                case .upperBound:
                    direction = .range(start: MessageId(peerId: commentsPeerId, namespace: Namespaces.Message.Cloud, id: Int32.max - 1), end: MessageId(peerId: commentsPeerId, namespace: Namespaces.Message.Cloud, id: 1))
                case let .message(id):
                    direction = .aroundId(id)
                }
                return fetchMessageHistoryHole(accountPeerId: account.peerId, source: .network(account.network), postbox: account.postbox, peerInput: peerInput, namespace: Namespaces.Message.Cloud, direction: direction, space: .everywhere, count: 40)
                |> castError(FetchChannelReplyThreadMessageError.self)
                |> mapToSignal { result -> Signal<(FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor), FetchChannelReplyThreadMessageError> in
                    return account.postbox.transaction { transaction -> (FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor) in
                        guard let result = result else {
                            return (nil, .automatic)
                        }
                        let initialAnchor: ChatReplyThreadMessage.Anchor
                        switch anchor {
                        case .lowerBound:
                            if let actualPeerId = result.actualPeerId, let actualThreadId = result.actualThreadId {
                                if let firstMessage = transaction.getMessagesWithThreadId(peerId: actualPeerId, namespace: Namespaces.Message.Cloud, threadId: actualThreadId, from: MessageIndex.lowerBound(peerId: actualPeerId, namespace: Namespaces.Message.Cloud), includeFrom: false, to: MessageIndex.upperBound(peerId: actualPeerId, namespace: Namespaces.Message.Cloud), limit: 1).first {
                                    initialAnchor = .lowerBoundMessage(firstMessage.index)
                                } else {
                                    initialAnchor = .automatic
                                }
                            } else {
                                initialAnchor = .automatic
                            }
                        case .upperBound:
                            initialAnchor = .automatic
                        case .message:
                            initialAnchor = .automatic
                        }
                        return (result, initialAnchor)
                    }
                    |> castError(FetchChannelReplyThreadMessageError.self)
                }
            }
            |> castError(FetchChannelReplyThreadMessageError.self)
            |> switchToLatest
        }
        
        return combineLatest(
            discussionMessage.get()
            |> take(1)
            |> castError(FetchChannelReplyThreadMessageError.self),
            preloadedHistory
        )
        |> mapToSignal { discussionMessage, initialFilledHolesAndInitialAnchor -> Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError> in
            guard let discussionMessage = discussionMessage else {
                return .fail(.generic)
            }
            let (initialFilledHoles, initialAnchor) = initialFilledHolesAndInitialAnchor
            return account.postbox.transaction { transaction -> Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError> in
                if let initialFilledHoles = initialFilledHoles {
                    for range in initialFilledHoles.strictRemovedIndices.rangeView {
                        transaction.removeThreadIndexHole(peerId: discussionMessage.messageId.peerId, threadId: makeMessageThreadId(discussionMessage.messageId), namespace: Namespaces.Message.Cloud, space: .everywhere, range: Int32(range.lowerBound) ... Int32(range.upperBound))
                    }
                }
                
                return .single(ChatReplyThreadMessage(
                    messageId: discussionMessage.messageId,
                    channelMessageId: discussionMessage.channelMessageId,
                    isChannelPost: discussionMessage.isChannelPost,
                    maxMessage: discussionMessage.maxMessage,
                    maxReadIncomingMessageId: discussionMessage.maxReadIncomingMessageId,
                    maxReadOutgoingMessageId: discussionMessage.maxReadOutgoingMessageId,
                    unreadCount: discussionMessage.unreadCount,
                    initialFilledHoles: initialFilledHoles?.removedIndices ?? IndexSet(),
                    initialAnchor: initialAnchor,
                    isNotAvailable: initialFilledHoles == nil
                ))
            }
            |> castError(FetchChannelReplyThreadMessageError.self)
            |> switchToLatest
        }
    }
}

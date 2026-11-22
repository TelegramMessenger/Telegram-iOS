import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

private struct DiscussionMessage {
    var messageId: MessageId
    var channelMessageId: MessageId?
    var isChannelPost: Bool
    var isForumPost: Bool
    var isMonoforumPost: Bool
    var maxMessage: MessageId?
    var maxReadIncomingMessageId: MessageId?
    var maxReadOutgoingMessageId: MessageId?
    var unreadCount: Int
}

private class ReplyThreadHistoryContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    private let threadId: Int64
    
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
        self.peerId = data.peerId
        self.threadId = data.threadId
        
        let referencedMessageId = MessageId(peerId: data.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: data.threadId))
        
        self.maxReadOutgoingMessageIdValue = data.maxReadOutgoingMessageId
        self.maxReadOutgoingMessageId.set(.single(self.maxReadOutgoingMessageIdValue))

        self.maxReadIncomingMessageIdValue = data.maxReadIncomingMessageId

        self.unreadCountValue = data.unreadCount
        self.unreadCount.set(.single(self.unreadCountValue))
        
        self.initialStateDisposable = (account.postbox.transaction { transaction -> State in
            var indices = transaction.getThreadIndexHoles(peerId: data.peerId, threadId: data.threadId, namespace: Namespaces.Message.Cloud)
            indices.subtract(data.initialFilledHoles)
            
            if let maxMessageId = data.maxMessage {
                indices.remove(integersIn: Int(maxMessageId.id + 1) ..< Int(Int32.max))
            } else {
                indices.removeAll()
            }
            
            return State(messageId: referencedMessageId, holeIndices: [Namespaces.Message.Cloud: indices], maxReadIncomingMessageId: data.maxReadIncomingMessageId, maxReadOutgoingMessageId: data.maxReadOutgoingMessageId)
        }
        |> deliverOn(self.queue)).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.stateValue = state
            strongSelf.state.set(.single(state))
        })
        
        let threadId = self.threadId
        
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
            if let value = outgoing[PeerAndBoundThreadId(peerId: referencedMessageId.peerId, threadId: Int64(referencedMessageId.id))] {
                strongSelf.maxReadOutgoingMessageIdValue = MessageId(peerId: data.peerId, namespace: Namespaces.Message.Cloud, id: value)
            }
        })
        
        let updateInitialState: Signal<DiscussionMessage, FetchChannelReplyThreadMessageError> = account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(data.peerId)
        }
        |> castError(FetchChannelReplyThreadMessageError.self)
        |> mapToSignal { peer -> Signal<DiscussionMessage, FetchChannelReplyThreadMessageError> in
            guard let peer = peer else {
                return .fail(.generic)
            }
            guard let inputPeer = apiInputPeer(peer) else {
                return .fail(.generic)
            }

            return account.network.request(Api.functions.messages.getDiscussionMessage(peer: inputPeer, msgId: Int32(clamping: data.threadId)))
            |> beforeStarted {
                Logger.shared.log("ReplyThreadOpen", "context getDiscussionMessage sent peer=\(data.peerId.id._internalGetInt64Value()) msg=\(data.threadId)")
            }
            |> mapError { _ -> FetchChannelReplyThreadMessageError in
                return .generic
            }
            |> mapToSignal { result -> Signal<DiscussionMessage, FetchChannelReplyThreadMessageError> in
                return account.postbox.transaction { transaction -> DiscussionMessage? in
                    return applyDiscussionMessage(transaction: transaction, account: account, peer: peer, result: result, logPrefix: "context ")
                }
                |> castError(FetchChannelReplyThreadMessageError.self)
                |> mapToSignal { discussionMessage -> Signal<DiscussionMessage, FetchChannelReplyThreadMessageError> in
                    if let discussionMessage {
                        return .single(discussionMessage)
                    } else {
                        return .fail(.generic)
                    }
                }
            }
        }
        
        // The opener has usually just fetched this answer; both forms carry the same read state.
        if account.viewTracker.recentDiscussionMessageFetches.wasFetchedRecently(PeerAndBoundThreadId(peerId: data.peerId, threadId: data.threadId)) {
            Logger.shared.log("ReplyThreadOpen", "context getDiscussionMessage skipped peer=\(data.peerId.id._internalGetInt64Value()) msg=\(data.threadId)")
        } else {
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
    }
    
    deinit {
        self.initialStateDisposable?.dispose()
        self.holesDisposable?.dispose()
        self.readStateDisposable?.dispose()
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
            return fetchMessageHistoryHole(accountPeerId: self.account.peerId, source: .network(self.account.network), postbox: self.account.postbox, peerInput: .direct(peerId: hole.peerId, threadId: hole.threadId), namespace: hole.namespace, direction: entry.direction, space: entry.space, count: fetchCount, pendingReferences: self.account.viewTracker.pendingMessageReferences)
        }
    }
    
    func applyMaxReadIndex(messageIndex: MessageIndex) {
        let peerId = self.peerId
        let threadId = self.threadId
        
        if messageIndex.id.namespace != Namespaces.Message.Cloud {
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
        
        let _ = (self.account.postbox.transaction { transaction -> (Api.InputPeer?, Api.InputPeer?, MessageId?, Int?) in
            guard let peer = transaction.getPeer(peerId) else {
                return (nil, nil, nil, nil)
            }
            
            var markMainAsRead = false
            
            if var data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                if messageIndex.id.id >= data.maxIncomingReadId {
                    if let count = transaction.getThreadMessageCount(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, fromIdExclusive: data.maxIncomingReadId, toIndex: messageIndex) {
                        data.incomingUnreadCount = max(0, data.incomingUnreadCount - Int32(count))
                        data.maxIncomingReadId = messageIndex.id.id
                    }
                    
                    var newCountIsZero = false
                    if let topMessageIndex = transaction.getMessageHistoryThreadTopMessage(peerId: peerId, threadId: threadId, namespaces: Set([Namespaces.Message.Cloud])) {
                        if messageIndex.id.id >= topMessageIndex.id.id {
                            let containingHole = transaction.getThreadIndexHole(peerId: peerId, threadId: threadId, namespace: topMessageIndex.id.namespace, containing: topMessageIndex.id.id)
                            if let _ = containingHole[.everywhere] {
                            } else {
                                data.incomingUnreadCount = 0
                            }
                        }
                    }
                    newCountIsZero = data.incomingUnreadCount == 0
                    
                    if newCountIsZero, let peer = transaction.getPeer(peerId), peer.isForumOrMonoForum {
                        var allTopicsAreRead = true
                        for item in transaction.getMessageHistoryThreadIndex(peerId: peer.id, limit: 100) {
                            guard let data = transaction.getMessageHistoryThreadInfo(peerId: messageIndex.id.peerId, threadId: item.threadId)?.data.get(MessageHistoryThreadData.self) else {
                                continue
                            }
                            if data.incomingUnreadCount != 0 {
                                allTopicsAreRead = false
                                break
                            }
                        }
                        
                        if allTopicsAreRead {
                            markMainAsRead = true
                        }
                    }
                    
                    data.maxKnownMessageId = max(data.maxKnownMessageId, messageIndex.id.id)
                    
                    if let entry = StoredMessageHistoryThreadInfo(data) {
                        transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
                    }
                }
            }
            
            if markMainAsRead {
                _internal_applyMaxReadIndexInteractively(transaction: transaction, stateManager: account.stateManager, index: messageIndex)
            }
            
            var subPeerId: Api.InputPeer?
            if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                subPeerId = transaction.getPeer(PeerId(threadId)).flatMap(apiInputPeer)
            } else {
                let referencedMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))
                if let message = transaction.getMessage(referencedMessageId) {
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
                                        return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                    })
                                }
                            }
                            break
                        }
                    }
                }
            }

            let inputPeer = transaction.getPeer(messageIndex.id.peerId).flatMap(apiInputPeer)
            let readCount = transaction.getThreadMessageCount(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, fromIdExclusive: fromIdExclusive, toIndex: toIndex)
            let topMessageId = transaction.getMessagesWithThreadId(peerId: peerId, namespace: Namespaces.Message.Cloud, threadId: threadId, from: MessageIndex.upperBound(peerId: peerId, namespace: Namespaces.Message.Cloud), includeFrom: false, to: MessageIndex.lowerBound(peerId: peerId, namespace: Namespaces.Message.Cloud), limit: 1).first?.id
            
            return (inputPeer, subPeerId, topMessageId, readCount)
        }
        |> deliverOnMainQueue).start(next: { [weak self] inputPeer, subPeerId, topMessageId, readCount in
            guard let strongSelf = self else {
                return
            }
            guard let inputPeer else {
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

            if let subPeerId {
                let signal = strongSelf.account.network.request(Api.functions.messages.readSavedHistory(parentPeer: inputPeer, peer: subPeerId, maxId: messageIndex.id.id))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                }
                |> ignoreValues
                if revalidate {
                }
                strongSelf.readDisposable.set(signal.start())
            } else {
                var signal = strongSelf.account.network.request(Api.functions.messages.readDiscussion(peer: inputPeer, msgId: Int32(clamping: threadId), readMaxId: messageIndex.id.id))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                }
                |> ignoreValues
                if revalidate {
                    let validateSignal = strongSelf.account.network.request(Api.functions.messages.getDiscussionMessage(peer: inputPeer, msgId: Int32(clamping: threadId)))
                    |> map { result -> (MessageId?, Int) in
                        switch result {
                        case let .discussionMessage(discussionMessageData):
                            let (readInboxMaxId, unreadCount) = (discussionMessageData.readInboxMaxId, discussionMessageData.unreadCount)
                            return (readInboxMaxId.flatMap({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }), Int(unreadCount))
                        }
                    }
                    |> `catch` { _ -> Signal<(MessageId?, Int)?, NoError> in
                        return .single(nil)
                    }
                    |> afterNext { result in
                        guard let (incomingMessageId, count) = result else {
                            return
                        }
                        Queue.mainQueue().async {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.maxReadIncomingMessageIdValue = incomingMessageId
                            strongSelf.unreadCountValue = count
                        }
                    }
                    |> ignoreValues
                    signal = signal
                    |> then(validateSignal)
                }
                strongSelf.readDisposable.set(signal.start())
            }
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
                        content: .thread(peerId: state.messageId.peerId, id: Int64(state.messageId.id), holes: state.holeIndices),
                        maxReadIncomingMessageId: state.maxReadIncomingMessageId,
                        maxReadOutgoingMessageId: state.maxReadOutgoingMessageId
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
    
    public var peerId: PeerId
    public var threadId: Int64
    public var channelMessageId: MessageId?
    public var isChannelPost: Bool
    public var isForumPost: Bool
    public var isMonoforumPost: Bool
    public var maxMessage: MessageId?
    public var maxReadIncomingMessageId: MessageId?
    public var maxReadOutgoingMessageId: MessageId?
    public var unreadCount: Int
    public var initialFilledHoles: IndexSet
    public var initialAnchor: Anchor
    public var isNotAvailable: Bool
    
    public var effectiveMessageId: MessageId? {
        if self.peerId.namespace == Namespaces.Peer.CloudChannel || self.isForumPost {
            return MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: self.threadId))
        } else {
            return nil
        }
    }
    
    public init(peerId: PeerId, threadId: Int64, channelMessageId: MessageId?, isChannelPost: Bool, isForumPost: Bool, isMonoforumPost: Bool, maxMessage: MessageId?, maxReadIncomingMessageId: MessageId?, maxReadOutgoingMessageId: MessageId?, unreadCount: Int, initialFilledHoles: IndexSet, initialAnchor: Anchor, isNotAvailable: Bool) {
        self.peerId = peerId
        self.threadId = threadId
        self.channelMessageId = channelMessageId
        self.isChannelPost = isChannelPost
        self.isForumPost = isForumPost
        self.isMonoforumPost = isMonoforumPost
        self.maxMessage = maxMessage
        self.maxReadIncomingMessageId = maxReadIncomingMessageId
        self.maxReadOutgoingMessageId = maxReadOutgoingMessageId
        self.unreadCount = unreadCount
        self.initialFilledHoles = initialFilledHoles
        self.initialAnchor = initialAnchor
        self.isNotAvailable = isNotAvailable
    }
    
    public var normalized: ChatReplyThreadMessage {
        if self.isForumPost {
            return ChatReplyThreadMessage(peerId: self.peerId, threadId: self.threadId, channelMessageId: nil, isChannelPost: false, isForumPost: true, isMonoforumPost: self.isMonoforumPost, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false)
        } else {
            return self
        }
    }
}

public enum FetchChannelReplyThreadMessageError {
    case generic
}

/// Stores a `messages.getDiscussionMessage` answer and reads the thread it describes. When the
/// thread is a channel post's comments, the post's reply counters are refreshed from the answer.
private func applyDiscussionMessage(transaction: Transaction, account: Account, peer: Peer, result: Api.messages.DiscussionMessage, logPrefix: String) -> DiscussionMessage? {
    let accountPeerId = account.peerId
    switch result {
    case let .discussionMessage(discussionMessageData):
        let (messages, maxId, readInboxMaxId, readOutboxMaxId, unreadCount, chats, users) = (discussionMessageData.messages, discussionMessageData.maxId, discussionMessageData.readInboxMaxId, discussionMessageData.readOutboxMaxId, discussionMessageData.unreadCount, discussionMessageData.chats, discussionMessageData.users)
        let parsedMessages = messages.compactMap { message -> StoreMessage? in
            StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peer.isForumOrMonoForum)
        }

        guard let topMessage = parsedMessages.last, let parsedIndex = topMessage.index else {
            return nil
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

        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)

        let _ = transaction.addMessages(parsedMessages, location: .Random)

        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)

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
                return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
        }

        var isForumPost = false
        var isMonoforumPost = false
        if let channel = transaction.getPeer(parsedIndex.id.peerId) as? TelegramChannel {
            if channel.isForumOrMonoForum {
                isForumPost = true
            }
            if channel.isMonoForum {
                isMonoforumPost = true
            }
        } else if let user = transaction.getPeer(parsedIndex.id.peerId) as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasForum) {
            isForumPost = true
        }

        Logger.shared.log("ReplyThreadOpen", "\(logPrefix)getDiscussionMessage answered thread=\(parsedIndex.id.peerId.id._internalGetInt64Value())/\(parsedIndex.id.id) max=\(String(describing: maxId)) readIn=\(String(describing: readInboxMaxId)) readOut=\(String(describing: readOutboxMaxId)) unread=\(unreadCount)")

        return DiscussionMessage(
            messageId: parsedIndex.id,
            channelMessageId: channelMessageId,
            isChannelPost: channelMessageId != nil,
            isForumPost: isForumPost,
            isMonoforumPost: isMonoforumPost,
            maxMessage: resolvedMaxMessage,
            maxReadIncomingMessageId: maxReadIncomingMessageId,
            maxReadOutgoingMessageId: readOutboxMaxId.flatMap { readMaxId in
                MessageId(peerId: parsedIndex.id.peerId, namespace: Namespaces.Message.Cloud, id: readMaxId)
            },
            unreadCount: Int(unreadCount)
        )
    }
}

/// Whether the cache already holds a thread's window around `anchor`: the thread's holes, clipped
/// above its newest message and, for a group the account is in, to the group's own holes, read by a
/// 40-message view. `firstIndex` is the view's first entry (the open position for `.oldest`).
func replyThreadCachedWindow(transaction: Transaction, peerId: PeerId, threadId: Int64, maxMessageId: MessageId.Id, anchor: ReplyThreadFillAnchor) -> (isComplete: Bool, firstIndex: MessageIndex?) {
    var holes = transaction.getThreadIndexHoles(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud)
    holes.remove(integersIn: (Int(maxMessageId) + 1) ..< Int(Int32.max))

    let isParticipant = transaction.getPeerChatListIndex(peerId) != nil
    if isParticipant {
        let historyHoles = transaction.getHoles(peerId: peerId, namespace: Namespaces.Message.Cloud)
        holes.formIntersection(historyHoles)
    }

    let inputAnchor: HistoryViewInputAnchor
    switch anchor {
    case .oldest:
        inputAnchor = .lowerBound
    case let .around(id):
        inputAnchor = .message(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id))
    }

    let view = transaction.getMessagesHistoryViewState(
        input: .external(MessageHistoryViewExternalInput(
            content: .thread(
                peerId: peerId,
                id: threadId,
                holes: [
                    Namespaces.Message.Cloud: holes
                ]
            ),
            maxReadIncomingMessageId: nil,
            maxReadOutgoingMessageId: nil
        )),
        ignoreMessagesInTimestampRange: nil,
        ignoreMessageIds: Set(),
        count: 40,
        clipHoles: true,
        anchor: inputAnchor,
        namespaces: .not(Namespaces.Message.allNonRegular)
    )
    let isComplete = !view.isLoading || transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId) != nil
    return (isComplete, view.entries.first?.index)
}

/// The thread id of a channel post's comments, from the group's copy of the post. Every
/// getDiscussionMessage stores that copy; it is dated when the post was forwarded into the group,
/// moments after the post, and names the post in its SourceReferenceMessageAttribute. A comment of a
/// long thread opened at its oldest end may be the only other thing cached, and it is not the newest.
private func cachedDiscussionThreadId(transaction: Transaction, commentsPeerId: PeerId, post: Message) -> Int64? {
    let messages = transaction.getMessages(
        peerId: commentsPeerId,
        namespace: Namespaces.Message.Cloud,
        from: MessageIndex(id: MessageId(peerId: commentsPeerId, namespace: Namespaces.Message.Cloud, id: 0), timestamp: post.timestamp - 1),
        includeFrom: true,
        to: MessageIndex(id: MessageId(peerId: commentsPeerId, namespace: Namespaces.Message.Cloud, id: Int32.max), timestamp: post.timestamp + 60),
        limit: 20
    )
    for message in messages {
        for attribute in message.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute, attribute.messageId == post.id {
                return Int64(message.id.id)
            }
        }
    }
    return nil
}

private func replyThreadFillDirection(peerId: PeerId, anchor: ReplyThreadFillAnchor) -> MessageHistoryViewRelativeHoleDirection {
    switch anchor {
    case .oldest:
        return .range(start: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1), end: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32.max - 1))
    case let .around(id):
        return .aroundId(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id))
    }
}

/// The open position after a fill: the oldest comment for `.oldest`, else wherever the chat's own
/// anchoring puts it.
private func replyThreadInitialAnchor(transaction: Transaction, result: FetchMessageHistoryHoleResult, anchor: ReplyThreadFillAnchor) -> ChatReplyThreadMessage.Anchor {
    guard case .oldest = anchor, let actualPeerId = result.actualPeerId, let actualThreadId = result.actualThreadId else {
        return .automatic
    }
    if let firstMessage = transaction.getMessagesWithThreadId(peerId: actualPeerId, namespace: Namespaces.Message.Cloud, threadId: actualThreadId, from: MessageIndex.lowerBound(peerId: actualPeerId, namespace: Namespaces.Message.Cloud), includeFrom: false, to: MessageIndex.upperBound(peerId: actualPeerId, namespace: Namespaces.Message.Cloud), limit: 1).first {
        return .lowerBoundMessage(firstMessage.index)
    }
    return .automatic
}

private enum ReplyThreadParallelFill {
    case notSent
    case done(FetchMessageHistoryHoleResult?)
}

/// What a thread open knows before anything is sent (see `replyThreadOpenPlan`).
private struct ReplyThreadTimeZero {
    var plan: ReplyThreadOpenPlan
    var commentsPeerId: PeerId?
    var postIsMissing: Bool
}

private func replyThreadTimeZero(transaction: Transaction, peer: Peer, messageId: MessageId, atMessageId: MessageId.Id?) -> ReplyThreadTimeZero {
    // Rendered once: a long post is costly to render, and it is read three times below.
    let subjectMessage = transaction.getMessage(messageId)
    
    // What can be requested before getDiscussionMessage answers: a post's comments by the post
    // itself, a group thread by its id. Decided from the chat, never from the UI's isChannelPost.
    let chat: ReplyThreadSubjectChat
    if let channel = peer as? TelegramChannel {
        if case .broadcast = channel.info {
            chat = .broadcastChannel
        } else if !channel.isForumOrMonoForum {
            chat = .nonForumGroup
        } else {
            chat = .other
        }
    } else {
        chat = .other
    }
    let target = replyThreadFillTarget(chat: chat, messageId: messageId, subjectThreadId: subjectMessage?.threadId)
    var headMessageId: MessageId?
    var commentsPeerId: PeerId?
    var knownThreadId: Int64?
    switch target {
    case let .channelPost(postId):
        headMessageId = postId
    case let .groupThread(peerId, threadId):
        headMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))
        commentsPeerId = peerId
        knownThreadId = threadId
    case .none:
        break
    }

    var storedReplies: ReplyThreadStoredReplies?
    let headMessage = headMessageId == messageId ? subjectMessage : headMessageId.flatMap(transaction.getMessage)
    if let headMessage {
        for attribute in headMessage.attributes {
            if let attribute = attribute as? ReplyThreadMessageAttribute {
                storedReplies = ReplyThreadStoredReplies(maxMessageId: attribute.maxMessageId, maxReadMessageId: attribute.maxReadMessageId)
                if commentsPeerId == nil {
                    commentsPeerId = attribute.commentsPeerId
                }
            }
        }
    }

    // A post's thread id is known locally from a cached comment of it, or from the group's copy of the post.
    var cachedWindowIsComplete: Bool?
    var probedThreadId: Int64?
    let probeAnchor = replyThreadServerAnchor(linkedCommentId: atMessageId, readInboxMaxId: storedReplies?.maxReadMessageId)
    if let commentsPeerId, let maxMessageId = storedReplies?.maxMessageId {
        if knownThreadId == nil {
            var probeIds: [MessageId.Id] = []
            if case let .around(id) = probeAnchor {
                probeIds.append(id)
            }
            probeIds.append(maxMessageId)
            for id in probeIds {
                if let threadId = transaction.getMessage(MessageId(peerId: commentsPeerId, namespace: Namespaces.Message.Cloud, id: id))?.threadId {
                    knownThreadId = threadId
                    break
                }
            }
            if knownThreadId == nil, case .channelPost = target, let post = subjectMessage {
                knownThreadId = cachedDiscussionThreadId(transaction: transaction, commentsPeerId: commentsPeerId, post: post)
            }
        }
        probedThreadId = knownThreadId
        if let knownThreadId {
            cachedWindowIsComplete = replyThreadCachedWindow(transaction: transaction, peerId: commentsPeerId, threadId: knownThreadId, maxMessageId: maxMessageId, anchor: probeAnchor).isComplete
        }
    }

    let plan = replyThreadOpenPlan(target: target, storedReplies: storedReplies, linkedCommentId: atMessageId, cachedWindowIsComplete: cachedWindowIsComplete)
    let postIsMissing = target == .channelPost(messageId) && subjectMessage == nil
    Logger.shared.log("ReplyThreadOpen", "probe thread=\(String(describing: probedThreadId)) complete=\(String(describing: cachedWindowIsComplete))")
    return ReplyThreadTimeZero(plan: plan, commentsPeerId: commentsPeerId, postIsMissing: postIsMissing)
}

func _internal_fetchChannelReplyThreadMessage(account: Account, messageId: MessageId, atMessageId: MessageId.Id?) -> Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError> {
    let accountPeerId = account.peerId

    let emptyThreadResult = FetchMessageHistoryHoleResult(removedIndices: IndexSet(integersIn: 1 ..< Int(Int32.max - 1)), strictRemovedIndices: IndexSet(), actualPeerId: nil, actualThreadId: nil, ids: [])

    // Today's fill: the cached window first, then getReplies on the discussion group's thread.
    let sequentialFill: (DiscussionMessage, ReplyThreadFillAnchor) -> Signal<(FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor), FetchChannelReplyThreadMessageError> = { discussionMessage, anchor in
        guard let maxMessageId = discussionMessage.maxMessage else {
            return .single((emptyThreadResult, .automatic))
        }
        let commentsPeerId = discussionMessage.messageId.peerId
        let threadId = Int64(discussionMessage.messageId.id)
        return account.postbox.transaction { transaction -> Signal<(FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor), FetchChannelReplyThreadMessageError> in
            let window = replyThreadCachedWindow(transaction: transaction, peerId: commentsPeerId, threadId: threadId, maxMessageId: maxMessageId.id, anchor: anchor)
            if window.isComplete {
                let initialAnchor: ChatReplyThreadMessage.Anchor
                if case .oldest = anchor, let firstIndex = window.firstIndex {
                    initialAnchor = .lowerBoundMessage(firstIndex)
                } else {
                    initialAnchor = .automatic
                }
                return .single((FetchMessageHistoryHoleResult(removedIndices: IndexSet(), strictRemovedIndices: IndexSet(), actualPeerId: nil, actualThreadId: nil, ids: []), initialAnchor))
            }

            return fetchMessageHistoryHole(accountPeerId: accountPeerId, source: .network(account.network), postbox: account.postbox, peerInput: .direct(peerId: commentsPeerId, threadId: threadId), namespace: Namespaces.Message.Cloud, direction: replyThreadFillDirection(peerId: commentsPeerId, anchor: anchor), space: .everywhere, count: 40, pendingReferences: account.viewTracker.pendingMessageReferences)
            |> castError(FetchChannelReplyThreadMessageError.self)
            |> mapToSignal { result -> Signal<(FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor), FetchChannelReplyThreadMessageError> in
                return account.postbox.transaction { transaction -> (FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor) in
                    guard let result = result else {
                        return (nil, .automatic)
                    }
                    return (result, replyThreadInitialAnchor(transaction: transaction, result: result, anchor: anchor))
                }
                |> castError(FetchChannelReplyThreadMessageError.self)
            }
        }
        |> castError(FetchChannelReplyThreadMessageError.self)
        |> switchToLatest
    }

    return account.postbox.transaction { transaction -> (Peer, MessageHistoryThreadData?)? in
        guard let peer = transaction.getPeer(messageId.peerId) else {
            return nil
        }
        return (peer, transaction.getMessageHistoryThreadInfo(peerId: messageId.peerId, threadId: Int64(messageId.id))?.data.get(MessageHistoryThreadData.self))
    }
    |> castError(FetchChannelReplyThreadMessageError.self)
    |> mapToSignal { peerAndForumThreadData -> Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError> in
        guard let (peer, forumThreadData) = peerAndForumThreadData else {
            return .fail(.generic)
        }
        guard let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        
        let remoteDiscussionMessage: Signal<DiscussionMessage?, NoError> = account.network.request(Api.functions.messages.getDiscussionMessage(peer: inputPeer, msgId: messageId.id))
        |> beforeStarted {
            Logger.shared.log("ReplyThreadOpen", "getDiscussionMessage sent peer=\(messageId.peerId.id._internalGetInt64Value()) msg=\(messageId.id)")
        }
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.DiscussionMessage?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<DiscussionMessage?, NoError> in
            guard let result = result else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> DiscussionMessage? in
                let discussionMessage = applyDiscussionMessage(transaction: transaction, account: account, peer: peer, result: result, logPrefix: "")
                if let discussionMessage {
                    account.viewTracker.recentDiscussionMessageFetches.noteFetched(PeerAndBoundThreadId(peerId: discussionMessage.messageId.peerId, threadId: Int64(discussionMessage.messageId.id)))
                }
                return discussionMessage
            }
        }

        // getDiscussionMessage needs nothing the cache probe finds, so it goes out first; the probe
        // decides beside it whether getReplies goes out too.
        let discussionMessagePromise = Promise<DiscussionMessage?>()
        let timeZero: Signal<ReplyThreadTimeZero, NoError>
        if let threadData = forumThreadData {
            discussionMessagePromise.set(.single(DiscussionMessage(
                messageId: messageId,
                channelMessageId: nil,
                isChannelPost: false,
                isForumPost: true,
                isMonoforumPost: peer.isMonoForum,
                maxMessage: MessageId(peerId: messageId.peerId, namespace: messageId.namespace, id: threadData.maxKnownMessageId),
                maxReadIncomingMessageId: MessageId(peerId: messageId.peerId, namespace: messageId.namespace, id: threadData.maxIncomingReadId),
                maxReadOutgoingMessageId: MessageId(peerId: messageId.peerId, namespace: messageId.namespace, id: threadData.maxOutgoingReadId),
                unreadCount: Int(threadData.incomingUnreadCount)
            )))
            timeZero = .single(ReplyThreadTimeZero(plan: .sequential, commentsPeerId: nil, postIsMissing: false))
        } else {
            discussionMessagePromise.set(remoteDiscussionMessage)
            timeZero = account.postbox.transaction { transaction -> ReplyThreadTimeZero in
                return replyThreadTimeZero(transaction: transaction, peer: peer, messageId: messageId, atMessageId: atMessageId)
            }
        }
        
        return timeZero
        |> castError(FetchChannelReplyThreadMessageError.self)
        |> mapToSignal { timeZero -> Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError> in
            Logger.shared.log("ReplyThreadOpen", "plan=\(timeZero.plan) message=\(messageId) atMessage=\(String(describing: atMessageId))")
        
            let filledHistory: Signal<(DiscussionMessage, (FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor)), FetchChannelReplyThreadMessageError>
            switch timeZero.plan {
            case .sequential:
                filledHistory = discussionMessagePromise.get()
                |> take(1)
                |> castError(FetchChannelReplyThreadMessageError.self)
                |> mapToSignal { discussionMessage -> Signal<(DiscussionMessage, (FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor)), FetchChannelReplyThreadMessageError> in
                    guard let discussionMessage else {
                        return .fail(.generic)
                    }
                    let anchor = replyThreadServerAnchor(linkedCommentId: atMessageId, readInboxMaxId: discussionMessage.maxReadIncomingMessageId?.id)
                    return sequentialFill(discussionMessage, anchor)
                    |> map { filled in
                        return (discussionMessage, filled)
                    }
                }
            case .discussionOnly, .parallel:
                var fill: Signal<ReplyThreadParallelFill, NoError> = .single(.notSent)
                if case let .parallel(target, anchor) = timeZero.plan {
                    let peerInput: FetchMessageHistoryHoleThreadInput
                    switch target {
                    case let .channelPost(postId):
                        peerInput = .threadFromChannel(channelMessageId: postId)
                    case let .groupThread(peerId, threadId):
                        peerInput = .direct(peerId: peerId, threadId: threadId)
                    }
                    // A thread request reads only the ids of the direction's MessageIds.
                    fill = fetchMessageHistoryHole(accountPeerId: accountPeerId, source: .network(account.network), postbox: account.postbox, peerInput: peerInput, namespace: Namespaces.Message.Cloud, direction: replyThreadFillDirection(peerId: timeZero.commentsPeerId ?? messageId.peerId, anchor: anchor), space: .everywhere, count: 40, pendingReferences: account.viewTracker.pendingMessageReferences)
                    |> take(1)
                    |> map { result -> ReplyThreadParallelFill in
                        return .done(result)
                    }
                }

                // A link to a post that is not cached fetches the post in the same turn, so the chat's
                // preload finds it.
                var post: Signal<Void, NoError> = .single(Void())
                if timeZero.postIsMissing {
                    post = _internal_getMessagesLoadIfNecessary([messageId], postbox: account.postbox, network: account.network, accountPeerId: accountPeerId)
                    |> map { result -> Bool in
                        if case .result = result {
                            return true
                        } else {
                            return false
                        }
                    }
                    |> `catch` { _ -> Signal<Bool, NoError> in
                        return .single(true)
                    }
                    |> filter { $0 }
                    |> take(1)
                    |> map { _ -> Void in
                        return Void()
                    }
                }

                let plan = timeZero.plan
                filledHistory = combineLatest(discussionMessagePromise.get() |> take(1), fill, post)
                |> take(1)
                |> castError(FetchChannelReplyThreadMessageError.self)
                |> mapToSignal { discussionMessage, fill, _ -> Signal<(DiscussionMessage, (FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor)), FetchChannelReplyThreadMessageError> in
                    guard let discussionMessage else {
                        return .fail(.generic)
                    }
                    return account.postbox.transaction { transaction -> Signal<(DiscussionMessage, (FetchMessageHistoryHoleResult?, ChatReplyThreadMessage.Anchor)), FetchChannelReplyThreadMessageError> in
                        let commentsPeerId = discussionMessage.messageId.peerId
                        let threadId = Int64(discussionMessage.messageId.id)
                        let serverAnchor = replyThreadServerAnchor(linkedCommentId: atMessageId, readInboxMaxId: discussionMessage.maxReadIncomingMessageId?.id)

                        var acceptedResult: FetchMessageHistoryHoleResult?
                        let outcome: ReplyThreadFillOutcome
                        switch fill {
                        case .notSent:
                            outcome = .notSent
                        case let .done(result):
                            if let result, case let .parallel(target, usedAnchor) = plan {
                                let matchesServerThread = replyThreadFillMatchesServerThread(target: target, actualPeerId: result.actualPeerId, actualThreadId: result.actualThreadId, serverPeerId: commentsPeerId, serverThreadId: threadId)
                                outcome = .succeeded(usedAnchor: usedAnchor, matchesServerThread: matchesServerThread)
                                if matchesServerThread {
                                    // A `.threadFromChannel` fill could not close the holes itself (the thread
                                    // was unknown); close what a `.direct` fill of the same answer closes.
                                    for range in result.removedIndices.rangeView {
                                        transaction.removeHole(peerId: commentsPeerId, threadId: threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: Int32(range.lowerBound) ... Int32(range.upperBound - 1))
                                    }
                                    acceptedResult = result
                                }
                            } else {
                                outcome = .failed
                            }
                        }

                        let decision = replyThreadReconcile(serverHasComments: discussionMessage.maxMessage != nil, serverAnchor: serverAnchor, fill: outcome)
                        Logger.shared.log("ReplyThreadOpen", "reconcile=\(decision) fill=\(outcome)")
                        switch decision {
                        case .empty:
                            return .single((discussionMessage, (emptyThreadResult, .automatic)))
                        case .accept:
                            if let acceptedResult {
                                return .single((discussionMessage, (acceptedResult, replyThreadInitialAnchor(transaction: transaction, result: acceptedResult, anchor: serverAnchor))))
                            } else {
                                return sequentialFill(discussionMessage, serverAnchor)
                                |> map { filled in
                                    return (discussionMessage, filled)
                                }
                            }
                        case let .refill(anchor):
                            return sequentialFill(discussionMessage, anchor)
                            |> map { filled in
                                return (discussionMessage, filled)
                            }
                        }
                    }
                    |> castError(FetchChannelReplyThreadMessageError.self)
                    |> switchToLatest
                }
            }

            return filledHistory
            |> mapToSignal { discussionMessage, filled -> Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError> in
                let (initialFilledHoles, initialAnchor) = filled
                return account.postbox.transaction { transaction -> ChatReplyThreadMessage in
                    if let initialFilledHoles = initialFilledHoles {
                        for range in initialFilledHoles.strictRemovedIndices.rangeView {
                            transaction.removeHole(peerId: discussionMessage.messageId.peerId, threadId: Int64(discussionMessage.messageId.id), namespace: Namespaces.Message.Cloud, space: .everywhere, range: Int32(range.lowerBound) ... Int32(range.upperBound))
                        }
                    }

                    return ChatReplyThreadMessage(
                        peerId: discussionMessage.messageId.peerId,
                        threadId: Int64(discussionMessage.messageId.id),
                        channelMessageId: discussionMessage.channelMessageId,
                        isChannelPost: discussionMessage.isChannelPost,
                        isForumPost: discussionMessage.isForumPost,
                        isMonoforumPost: discussionMessage.isMonoforumPost,
                        maxMessage: discussionMessage.maxMessage,
                        maxReadIncomingMessageId: discussionMessage.maxReadIncomingMessageId,
                        maxReadOutgoingMessageId: discussionMessage.maxReadOutgoingMessageId,
                        unreadCount: discussionMessage.unreadCount,
                        initialFilledHoles: initialFilledHoles?.removedIndices ?? IndexSet(),
                        initialAnchor: initialAnchor,
                        isNotAvailable: initialFilledHoles == nil
                    )
                }
                |> castError(FetchChannelReplyThreadMessageError.self)
            }
        }
    }
}

import Foundation
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramApi

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
                self.maxReadOutgoingMessageId.set(.single(nil))
            }
        }
    }
    
    private var initialStateDisposable: Disposable?
    private var holesDisposable: Disposable?
    private var readStateDisposable: Disposable?
    private let readDisposable = MetaDisposable()
    
    init(queue: Queue, account: Account, messageId: MessageId, maxMessage: ChatReplyThreadMessage.MaxMessage, maxReadIncomingMessageId: MessageId?, maxReadOutgoingMessageId: MessageId?) {
        self.queue = queue
        self.account = account
        self.messageId = messageId
        
        self.maxReadOutgoingMessageIdValue = maxReadOutgoingMessageId
        self.maxReadOutgoingMessageId.set(.single(self.maxReadOutgoingMessageIdValue))
        
        self.initialStateDisposable = (account.postbox.transaction { transaction -> State in
            var indices = transaction.getThreadIndexHoles(peerId: messageId.peerId, threadId: makeMessageThreadId(messageId), namespace: Namespaces.Message.Cloud)
            switch maxMessage {
            case .unknown:
                indices.insert(integersIn: 1 ..< Int(Int32.max - 1))
            case let .known(maxMessageId):
                indices.insert(integersIn: 1 ..< Int(Int32.max - 1))
                /*if let maxMessageId = maxMessageId {
                    let topMessage = transaction.getMessagesWithThreadId(peerId: messageId.peerId, namespace: Namespaces.Message.Cloud, threadId: makeMessageThreadId(messageId), from: MessageIndex.upperBound(peerId: messageId.peerId, namespace: Namespaces.Message.Cloud), includeFrom: false, to: MessageIndex.lowerBound(peerId: messageId.peerId, namespace: Namespaces.Message.Cloud), limit: 1).first
                    if let topMessage = topMessage {
                        if maxMessageId.id < maxMessageId.id {
                            indices.insert(integersIn: Int(topMessage.id.id + 1) ..< Int(Int32.max - 1))
                        }
                    } else {
                        indices.insert(integersIn: 1 ..< Int(Int32.max - 1))
                    }
                } else {
                    indices = IndexSet()
                }*/
            }
            return State(messageId: messageId, holeIndices: [Namespaces.Message.Cloud: indices], maxReadIncomingMessageId: maxReadIncomingMessageId, maxReadOutgoingMessageId: maxReadOutgoingMessageId)
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
            if let value = outgoing[messageId] {
                strongSelf.maxReadOutgoingMessageIdValue = MessageId(peerId: messageId.peerId, namespace: Namespaces.Message.Cloud, id: value)
            }
        })
    }
    
    deinit {
        self.initialStateDisposable?.dispose()
        self.holesDisposable?.dispose()
        self.readDisposable.dispose()
    }
    
    func setCurrentHole(entry: MessageHistoryHolesViewEntry?) {
        if self.currentHole?.0 != entry {
            self.currentHole?.1.dispose()
            if let entry = entry {
                self.currentHole = (entry, self.fetchHole(entry: entry).start(next: { [weak self] removedHoleIndices in
                    guard let strongSelf = self else {
                        return
                    }
                    if var currentHoles = strongSelf.stateValue?.holeIndices[Namespaces.Message.Cloud] {
                        currentHoles.subtract(removedHoleIndices)
                        strongSelf.stateValue?.holeIndices[Namespaces.Message.Cloud] = currentHoles
                    }
                }))
            } else {
                self.currentHole = nil
            }
        }
    }
    
    private func fetchHole(entry: MessageHistoryHolesViewEntry) -> Signal<IndexSet, NoError> {
        switch entry.hole {
        case let .peer(hole):
            let fetchCount = min(entry.count, 100)
            return fetchMessageHistoryHole(accountPeerId: self.account.peerId, source: .network(self.account.network), postbox: self.account.postbox, peerId: hole.peerId, namespace: hole.namespace, direction: entry.direction, space: entry.space, threadId: hole.threadId.flatMap { makeThreadIdMessageId(peerId: self.messageId.peerId, threadId: $0) }, count: fetchCount)
        }
    }
    
    func applyMaxReadIndex(messageIndex: MessageIndex) {
        let account = self.account
        let messageId = self.messageId
        
        if messageIndex.id.namespace != messageId.namespace {
            return
        }
        
        let signal = self.account.postbox.transaction { transaction -> Api.InputPeer? in
            if let message = transaction.getMessage(messageId) {
                for attribute in message.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        if let sourceMessage = transaction.getMessage(attribute.messageId) {
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
            
            return transaction.getPeer(messageIndex.id.peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<Never, NoError> in
            guard let inputPeer = inputPeer else {
                return .complete()
            }
            return account.network.request(Api.functions.messages.readDiscussion(peer: inputPeer, msgId: messageId.id, readMaxId: messageIndex.id.id))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
        }
        self.readDisposable.set(signal.start())
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
    
    public init(account: Account, peerId: PeerId, threadMessageId: MessageId, maxMessage: ChatReplyThreadMessage.MaxMessage, maxReadIncomingMessageId: MessageId?, maxReadOutgoingMessageId: MessageId?) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ReplyThreadHistoryContextImpl(queue: queue, account: account, messageId: threadMessageId, maxMessage: maxMessage, maxReadIncomingMessageId: maxReadIncomingMessageId, maxReadOutgoingMessageId: maxReadOutgoingMessageId)
        })
    }
    
    public func applyMaxReadIndex(messageIndex: MessageIndex) {
        self.impl.with { impl in
            impl.applyMaxReadIndex(messageIndex: messageIndex)
        }
    }
}

public struct ChatReplyThreadMessage {
    public enum MaxMessage: Equatable {
        case unknown
        case known(MessageId?)
    }
    
    public var messageId: MessageId
    public var maxMessage: MaxMessage
    public var maxReadIncomingMessageId: MessageId?
    public var maxReadOutgoingMessageId: MessageId?
    
    public init(messageId: MessageId, maxMessage: MaxMessage, maxReadIncomingMessageId: MessageId?, maxReadOutgoingMessageId: MessageId?) {
        self.messageId = messageId
        self.maxMessage = maxMessage
        self.maxReadIncomingMessageId = maxReadIncomingMessageId
        self.maxReadOutgoingMessageId = maxReadOutgoingMessageId
    }
}

public func fetchChannelReplyThreadMessage(account: Account, messageId: MessageId) -> Signal<ChatReplyThreadMessage?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<ChatReplyThreadMessage?, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(nil)
        }
        let discussionMessage: Signal<Api.messages.DiscussionMessage?, NoError> = account.network.request(Api.functions.messages.getDiscussionMessage(peer: inputPeer, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.DiscussionMessage?, NoError> in
            return .single(nil)
        }
        
        return discussionMessage
        |> mapToSignal { discussionMessage -> Signal<ChatReplyThreadMessage?, NoError> in
            guard let discussionMessage = discussionMessage else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> ChatReplyThreadMessage? in
                switch discussionMessage {
                case let .discussionMessage(_, messages, maxId, readInboxMaxId, readOutboxMaxId, chats, users):
                    let parsedMessages = messages.compactMap { message -> StoreMessage? in
                        StoreMessage(apiMessage: message)
                    }
                    
                    guard let topMessage = parsedMessages.last, let parsedIndex = topMessage.index else {
                        return nil
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
                    
                    let resolvedMaxMessage: ChatReplyThreadMessage.MaxMessage
                    if let maxId = maxId {
                        resolvedMaxMessage = .known(MessageId(
                            peerId: parsedIndex.id.peerId,
                            namespace: Namespaces.Message.Cloud,
                            id: maxId
                        ))
                    } else {
                        resolvedMaxMessage = .known(nil)
                    }
                    
                    return ChatReplyThreadMessage(
                        messageId: parsedIndex.id,
                        maxMessage: resolvedMaxMessage,
                        maxReadIncomingMessageId: readInboxMaxId.flatMap { readMaxId in
                            MessageId(peerId: parsedIndex.id.peerId, namespace: Namespaces.Message.Cloud, id: readMaxId)
                        },
                        maxReadOutgoingMessageId: readOutboxMaxId.flatMap { readMaxId in
                            MessageId(peerId: parsedIndex.id.peerId, namespace: Namespaces.Message.Cloud, id: readMaxId)
                        }
                    )
                }
            }
        }
    }
}

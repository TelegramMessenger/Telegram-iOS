import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

private class FeedHistoryContextImpl {
    private let queue: Queue
    private let account: Account
    private let feedId: Int32
    private let userId: Int64
    
    private var currentHole: (MessageHistoryHolesViewEntry, Disposable)?
    
    struct State: Equatable {
        var messageIndices: [MessageIndex]
        var holeIndices: [MessageId.Namespace: IndexSet]
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
    
    init(queue: Queue, account: Account, feedId: Int32, userId: Int64) {
        self.queue = queue
        self.account = account
        self.feedId = feedId
        self.userId = userId
        
        self.maxReadOutgoingMessageIdValue = nil
        self.maxReadOutgoingMessageId.set(.single(self.maxReadOutgoingMessageIdValue))

        self.maxReadIncomingMessageIdValue = nil

        self.unreadCountValue = 0
        self.unreadCount.set(.single(self.unreadCountValue))
        
        self.initialStateDisposable = (account.postbox.transaction { transaction -> State in
            return State(messageIndices: [], holeIndices: [Namespaces.Message.Cloud: IndexSet(integersIn: 2 ... 2)])
        }
        |> deliverOn(self.queue)).start(next: { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            strongSelf.stateValue = state
            strongSelf.state.set(.single(state))
        })
        
        /*self.updateInitialStateDisposable = (account.network.request(Api.functions.feed.getFeed(flags: 0, filterId: self.feedId, offsetPosition: nil, addOffset: 0, limit: 100, maxPosition: nil, minPosition: nil, hash: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.feed.FeedMessages?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<[MessageIndex], NoError> in
            return account.postbox.transaction { transaction -> [MessageIndex] in
                guard let result = result else {
                    return []
                }
                
                let messages: [Api.Message]
                let chats: [Api.Chat]
                let users: [Api.User]
                
                switch result {
                case let .feedMessages(_, _, _, _, apiMessages, apiChats, apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case .feedMessagesNotModified:
                    messages = []
                    users = []
                    chats = []
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
                
                var storeMessages: [StoreMessage] = []
                
                for message in messages {
                    if let storeMessage = StoreMessage(apiMessage: message, namespace: Namespaces.Message.Cloud) {
                        storeMessages.append(storeMessage)
                    }
                }
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                
                let _ = transaction.addMessages(storeMessages, location: .Random)
                
                return storeMessages.compactMap({ message in
                    return message.index
                }).sorted()
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] indices in
            guard let strongSelf = self else {
                return
            }
            assert(indices.sorted() == indices)
            strongSelf.stateValue = State(messageIndices: indices, holeIndices: [:])
        })*/
        
        let userId = self.userId
        self.holesDisposable = (account.postbox.messageHistoryHolesView()
        |> map { view -> MessageHistoryHolesViewEntry? in
            for entry in view.entries {
                if entry.userId == userId {
                    return entry
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
        
        /*self.readStateDisposable = (account.stateManager.threadReadStateUpdates
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
        })*/
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
                self.currentHole = (entry, self.fetchHole(entry: entry).start(next: { [weak self] updatedState in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.currentHole = nil
                    strongSelf.stateValue = updatedState
                }))
            } else {
                self.currentHole = nil
            }
        }
    }
    
    private func fetchHole(entry: MessageHistoryHolesViewEntry) -> Signal<State, NoError> {
        //feed.getFeed flags:# filter_id:int offset_to_max_read:flags.3?true offset_position:flags.0?FeedPosition add_offset:int limit:int max_position:flags.1?FeedPosition min_position:flags.2?FeedPosition hash:long = messages.FeedMessages;
        return .complete()
//        let offsetPosition: Api.FeedPosition?
//        let addOffset: Int32 = 0
//
//        switch entry.direction {
//        case let .range(start, end):
//            if min(start.id, end.id) == 1 && max(start.id, end.id) == Int32.max - 1 {
//                offsetPosition = nil
//            } else {
//                return .never()
//            }
//        case let .aroundId(id):
//            let _ = id
//            return .never()
//        }
//
//        var flags: Int32 = 0
//        if let _ = offsetPosition {
//            flags |= 1 << 0
//        }
//
//        let account = self.account
//        let state = self.stateValue
//        return self.account.network.request(Api.functions.feed.getFeed(
//            flags: flags,
//            filterId: self.feedId,
//            offsetPosition: offsetPosition,
//            addOffset: addOffset,
//            limit: 100,
//            maxPosition: nil,
//            minPosition: nil,
//            hash: 0
//        ))
//        |> map(Optional.init)
//        |> `catch` { _ -> Signal<Api.feed.FeedMessages?, NoError> in
//            return .single(nil)
//        }
//        |> mapToSignal { result -> Signal<State, NoError> in
//            return account.postbox.transaction { transaction -> State in
//                guard let result = result else {
//                    var updatedState = state ?? State(messageIndices: [], holeIndices: [:])
//                    updatedState.holeIndices = [:]
//                    return updatedState
//                }
//
//                let messages: [Api.Message]
//                let chats: [Api.Chat]
//                let users: [Api.User]
//
//                switch result {
//                case let .feedMessages(_, _, _, _, apiMessages, apiChats, apiUsers):
//                    messages = apiMessages
//                    chats = apiChats
//                    users = apiUsers
//                case .feedMessagesNotModified:
//                    messages = []
//                    users = []
//                    chats = []
//                }
//
//                var peers: [Peer] = []
//                var peerPresences: [PeerId: PeerPresence] = [:]
//                for chat in chats {
//                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
//                        peers.append(groupOrChannel)
//                    }
//                }
//                for user in users {
//                    let telegramUser = TelegramUser(user: user)
//                    peers.append(telegramUser)
//                    if let presence = TelegramUserPresence(apiUser: user) {
//                        peerPresences[telegramUser.id] = presence
//                    }
//                }
//
//                var storeMessages: [StoreMessage] = []
//
//                for message in messages {
//                    if let storeMessage = StoreMessage(apiMessage: message, namespace: Namespaces.Message.Cloud) {
//                        storeMessages.append(storeMessage)
//                    }
//                }
//
//                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
//                    return updated
//                })
//                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
//
//                let _ = transaction.addMessages(storeMessages, location: .Random)
//
//                var updatedState = state ?? State(messageIndices: [], holeIndices: [:])
//                var currentSet = Set<MessageIndex>(updatedState.messageIndices)
//
//                for index in storeMessages.compactMap(\.index) {
//                    if !currentSet.contains(index) {
//                        currentSet.insert(index)
//                    }
//                    updatedState.messageIndices.append(index)
//                }
//
//                updatedState.messageIndices.sort()
//
//                updatedState.holeIndices = [:]
//                return updatedState
//            }
//        }
    }
    
    func applyMaxReadIndex(messageIndex: MessageIndex) {
    }
}

public class FeedHistoryContext {
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
    private let impl: QueueLocalObject<FeedHistoryContextImpl>
    
    private let userId: Int64 = Int64.random(in: 0 ..< Int64.max)
    
    public var state: Signal<MessageHistoryViewExternalInput, NoError> {
        let userId = self.userId
        
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                let stateDisposable = impl.state.get().start(next: { state in
                    subscriber.putNext(MessageHistoryViewExternalInput(
                        content: .messages(indices: state.messageIndices, holes: state.holeIndices, userId: userId),
                        maxReadIncomingMessageId: nil,
                        maxReadOutgoingMessageId: nil
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
    
    public init(account: Account, feedId: Int32) {
        let queue = self.queue
        let userId = self.userId
        self.impl = QueueLocalObject(queue: queue, generate: {
            return FeedHistoryContextImpl(queue: queue, account: account, feedId: feedId, userId: userId)
        })
    }
    
    public func applyMaxReadIndex(messageIndex: MessageIndex) {
        self.impl.with { impl in
            impl.applyMaxReadIndex(messageIndex: messageIndex)
        }
    }
}

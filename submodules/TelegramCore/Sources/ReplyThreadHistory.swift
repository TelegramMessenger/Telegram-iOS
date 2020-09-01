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
        var maxReadMessageId: MessageId?
    }
    
    let state = Promise<State>()
    private var stateValue: State {
        didSet {
            if self.stateValue != oldValue {
                self.state.set(.single(self.stateValue))
            }
        }
    }
    
    private var holesDisposable: Disposable?
    private let readDisposable = MetaDisposable()
    
    init(queue: Queue, account: Account, messageId: MessageId, maxReadMessageId: MessageId?) {
        self.queue = queue
        self.account = account
        self.messageId = messageId
        
        self.stateValue = State(messageId: self.messageId, holeIndices: [Namespaces.Message.Cloud: IndexSet(integersIn: 1 ..< Int(Int32.max))], maxReadMessageId: maxReadMessageId)
        self.state.set(.single(self.stateValue))
        
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
    }
    
    deinit {
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
                    if var currentHoles = strongSelf.stateValue.holeIndices[Namespaces.Message.Cloud] {
                        currentHoles.subtract(removedHoleIndices)
                        strongSelf.stateValue.holeIndices[Namespaces.Message.Cloud] = currentHoles
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
                        maxReadMessageId: state.maxReadMessageId,
                        holes: state.holeIndices
                    ))
                })
                disposable.set(stateDisposable)
            }
            
            return disposable
        }
    }
    
    public init(account: Account, peerId: PeerId, threadMessageId: MessageId, maxReadMessageId: MessageId?) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ReplyThreadHistoryContextImpl(queue: queue, account: account, messageId: threadMessageId, maxReadMessageId: maxReadMessageId)
        })
    }
    
    public func applyMaxReadIndex(messageIndex: MessageIndex) {
        self.impl.with { impl in
            impl.applyMaxReadIndex(messageIndex: messageIndex)
        }
    }
}

public struct ChatReplyThreadMessage {
    public var messageId: MessageId
    public var maxReadMessageId: MessageId?
    
    public init(messageId: MessageId, maxReadMessageId: MessageId?) {
        self.messageId = messageId
        self.maxReadMessageId = maxReadMessageId
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
        return account.network.request(Api.functions.messages.getDiscussionMessage(peer: inputPeer, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.DiscussionMessage?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<ChatReplyThreadMessage?, NoError> in
            guard let result = result else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> ChatReplyThreadMessage? in
                switch result {
                case let .discussionMessage(message, readMaxId, chats, users):
                    guard let parsedMessage = StoreMessage(apiMessage: message), let parsedIndex = parsedMessage.index else {
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
                    
                    let _ = transaction.addMessages([parsedMessage], location: .Random)
                    
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                        return updated
                    })
                    
                    updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                    
                    return ChatReplyThreadMessage(
                        messageId: parsedIndex.id,
                        maxReadMessageId: MessageId(peerId: parsedIndex.id.peerId, namespace: Namespaces.Message.Cloud, id: readMaxId)
                    )
                }
            }
        }
    }
}

import Foundation
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramApi

private class ReplyThreadHistoryContextImpl {
    private let queue: Queue
    private let account: Account
    private let messageId: MessageId
    
    private var currentHole: (MessageHistoryExternalHolesViewEntry, Disposable)?
    
    struct NamespaceState: Equatable {
        var sortedMessageIds: [MessageId]
        var holeIndices: IndexSet
    }
    
    struct State: Equatable {
        let messageId: MessageId
        let namespaces: [MessageId.Namespace]
        let namespaceStates: [MessageId.Namespace: NamespaceState]
    }
    
    let state = Promise<State>()
    private var stateValue: State {
        didSet {
            self.state.set(.single(self.stateValue))
        }
    }
    
    init(queue: Queue, account: Account, messageId: MessageId) {
        self.queue = queue
        self.account = account
        self.messageId = messageId
        
        self.stateValue = State(messageId: self.messageId, namespaces: [Namespaces.Message.Cloud, Namespaces.Message.Local], namespaceStates: [:])
        self.state.set(.single(self.stateValue))
        
        /*self.setCurrentHole(hole: MessageHistoryExternalHolesViewEntry(
            hole: .peer(MessageHistoryViewPeerHole(peerId: self.messageId.peerId, namespace: Namespaces.Message.Cloud, threadId: makeMessageThreadId(self.messageId))),
            direction: .range(start: MessageId(peerId: self.messageId.peerId, namespace: Namespaces.Message.Cloud, id: Int32.max - 1), end: MessageId(peerId: self.messageId.peerId, namespace: Namespaces.Message.Cloud, id: 1)),
            count: 100
        ))*/
    }
    
    func setCurrentHole(hole: MessageHistoryExternalHolesViewEntry?) {
        if self.currentHole?.0 != hole {
            self.currentHole?.1.dispose()
            if let hole = hole {
                self.currentHole = (hole, self.fetchHole(hole: hole).start())
            } else {
                self.currentHole = nil
            }
        }
    }
    
    private func fetchHole(hole: MessageHistoryExternalHolesViewEntry) -> Signal<Never, NoError> {
        let messageId = self.messageId
        let account = self.account
        return self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<Never, NoError> in
            guard let inputPeer = inputPeer else {
                return .complete()
            }
            return account.network.request(Api.functions.messages.getReplies(peer: inputPeer, msgId: messageId.id, offsetId: Int32.max - 1, addOffset: 0, limit: Int32(hole.count), maxId: Int32.max - 1, minId: 1, hash: 0))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                guard let result = result else {
                    return .complete()
                }
                return account.postbox.transaction { transaction -> Void in
                    switch result {
                    case .messages(let messages, let chats, let users), .messagesSlice(_, _, _, let messages, let chats, let users), .channelMessages(_, _, _, let messages, let chats, let users):
                        break
                    case .messagesNotModified:
                        break
                    }
                }
                |> ignoreValues
            }
        }
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
                        peerId: state.messageId.peerId, threadId: makeMessageThreadId(state.messageId), holes: [:]
                    ))
                })
                disposable.set(stateDisposable)
            }
            
            return disposable
        }
    }
    
    public init(account: Account, peerId: PeerId, threadMessageId: MessageId) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ReplyThreadHistoryContextImpl(queue: queue, account: account, messageId: threadMessageId)
        })
    }
}

public func fetchChannelReplyThreadMessage(account: Account, messageId: MessageId) -> Signal<MessageIndex?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<MessageIndex?, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(nil)
        }
        return account.network.request(Api.functions.messages.getDiscussionMessage(peer: inputPeer, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<MessageIndex?, NoError> in
            guard let result = result else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> MessageIndex? in
                switch result {
                case .messages(let messages, let chats, let users), .messagesSlice(_, _, _, let messages, let chats, let users), .channelMessages(_, _, _, let messages, let chats, let users):
                    guard let message = messages.first else {
                        return nil
                    }
                    guard let parsedMessage = StoreMessage(apiMessage: message) else {
                        return nil
                    }
                    return parsedMessage.index
                case .messagesNotModified:
                    return nil
                }
            }
        }
    }
}

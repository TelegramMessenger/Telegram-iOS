import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public enum MessageReactionListCategory: Hashable {
    case all
    case reaction(String)
}

public final class MessageReactionListCategoryItem: Equatable {
    public let peer: Peer
    public let reaction: String
    
    init(peer: Peer, reaction: String) {
        self.peer = peer
        self.reaction = reaction
    }
    
    public static func ==(lhs: MessageReactionListCategoryItem, rhs: MessageReactionListCategoryItem) -> Bool {
        if lhs.peer.id != rhs.peer.id {
            return false
        }
        if lhs.reaction != rhs.reaction {
            return false
        }
        return true
    }
}

public struct MessageReactionListCategoryState: Equatable {
    public var count: Int
    public var completed: Bool
    public var items: [MessageReactionListCategoryItem]
    public var loadingMore: Bool
    fileprivate var nextOffset: String?
}

private enum LoadReactionsError {
    case generic
}

private final class MessageReactionCategoryContext {
    private let postbox: Postbox
    private let network: Network
    private let messageId: MessageId
    private let category: MessageReactionListCategory
    private var state: MessageReactionListCategoryState
    var statePromise: ValuePromise<MessageReactionListCategoryState>
    
    private let loadingDisposable = MetaDisposable()
    
    init(postbox: Postbox, network: Network, messageId: MessageId, category: MessageReactionListCategory, initialState: MessageReactionListCategoryState) {
        self.postbox = postbox
        self.network = network
        self.messageId = messageId
        self.category = category
        self.state = initialState
        self.statePromise = ValuePromise(initialState)
    }
    
    deinit {
        self.loadingDisposable.dispose()
    }
    
    func loadMore() {
        if self.state.completed || self.state.loadingMore {
            return
        }
        self.state.loadingMore = true
        self.statePromise.set(self.state)
        
        /*var flags: Int32 = 0
        var reaction: String?
        switch self.category {
        case .all:
            break
        case let .reaction(value):
            flags |= 1 << 0
            reaction = value
        }
        let messageId = self.messageId
        let offset = self.state.nextOffset
        var request = self.postbox.transaction { transaction -> Api.InputPeer? in
            let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
            return inputPeer
        }
        |> castError(LoadReactionsError.self)
        |> mapToSignal { inputPeer -> Signal<Api.MessageReactionsList, LoadReactionsError> in
            guard let inputPeer = inputPeer else {
                return .fail(.generic)
            }
            return self.network.request(Api.functions.messages.getMessageReactionsList(flags: flags, peer: inputPeer, id: messageId.id, reaction: reaction, offset: offset, limit: 64))
            |> mapError { _ -> LoadReactionsError in
                return .generic
            }
        }
        //#if DEBUG
        request = request |> delay(1.0, queue: .mainQueue())
        //#endif
        self.loadingDisposable.set((request
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            let currentState = strongSelf.state
            let _ = (strongSelf.postbox.transaction { transaction -> MessageReactionListCategoryState in
                var mergedItems = currentState.items
                var currentIds = Set(mergedItems.lazy.map { $0.peer.id })
                switch result {
                case let .messageReactionsList(_, count, reactions, users, nextOffset):
                    var peers: [Peer] = []
                    for user in users {
                        let parsedUser = TelegramUser(user: user)
                        peers.append(parsedUser)
                    }
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated in updated })
                    for reaction in reactions {
                        switch reaction {
                        case let .messageUserReaction(userId, reaction):
                            if let peer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)) {
                                if !currentIds.contains(peer.id) {
                                    currentIds.insert(peer.id)
                                    mergedItems.append(MessageReactionListCategoryItem(peer: peer, reaction: reaction))
                                }
                            }
                        }
                    }
                    return MessageReactionListCategoryState(count: max(mergedItems.count, Int(count)), completed: nextOffset == nil, items: mergedItems, loadingMore: false, nextOffset: nextOffset)
                }
            }
            |> deliverOnMainQueue).start(next: { state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.state = state
                strongSelf.statePromise.set(state)
            })
        }, error: { _ in
            
        }))*/
    }
}

public struct MessageReactionListState: Equatable {
    public var states: [(MessageReactionListCategory, MessageReactionListCategoryState)]
    
    public static func ==(lhs: MessageReactionListState, rhs: MessageReactionListState) -> Bool {
        if lhs.states.count != rhs.states.count {
            return false
        }
        for i in 0 ..< lhs.states.count {
            if lhs.states[i].0 != rhs.states[i].0 {
                return false
            }
            if lhs.states[i].1 != rhs.states[i].1 {
                return false
            }
        }
        return true
    }
}

public final class MessageReactionListContext {
    private let postbox: Postbox
    private let network: Network
    
    private var categoryContexts: [MessageReactionListCategory: MessageReactionCategoryContext] = [:]
    
    private let _state = Promise<MessageReactionListState>()
    public var state: Signal<MessageReactionListState, NoError> {
        return self._state.get()
    }
    
    public init(postbox: Postbox, network: Network, messageId: MessageId, initialReactions: [MessageReaction]) {
        self.postbox = postbox
        self.network = network
        
        var allState = MessageReactionListCategoryState(count: 0, completed: false, items: [], loadingMore: false, nextOffset: nil)
        var signals: [Signal<(MessageReactionListCategory, MessageReactionListCategoryState), NoError>] = []
        for reaction in initialReactions {
            allState.count += Int(reaction.count)
            let context = MessageReactionCategoryContext(postbox: postbox, network: network, messageId: messageId, category: .reaction(reaction.value), initialState: MessageReactionListCategoryState(count: Int(reaction.count), completed: false, items: [], loadingMore: false, nextOffset: nil))
            signals.append(context.statePromise.get() |> map { value -> (MessageReactionListCategory, MessageReactionListCategoryState) in
                return (.reaction(reaction.value), value)
            })
            self.categoryContexts[.reaction(reaction.value)] = context
            context.loadMore()
        }
        let allContext = MessageReactionCategoryContext(postbox: postbox, network: network, messageId: messageId, category: .all, initialState: allState)
        signals.insert(allContext.statePromise.get() |> map { value -> (MessageReactionListCategory, MessageReactionListCategoryState) in
            return (.all, value)
        }, at: 0)
        self.categoryContexts[.all] = allContext
        
        self._state.set(combineLatest(queue: .mainQueue(), signals)
        |> map { states in
            return MessageReactionListState(states: states)
        })
        
        allContext.loadMore()
    }
    
    public func loadMore(category: MessageReactionListCategory) {
        self.categoryContexts[category]?.loadMore()
    }
}

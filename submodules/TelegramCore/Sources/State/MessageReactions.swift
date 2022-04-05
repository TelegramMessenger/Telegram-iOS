import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public func updateMessageReactionsInteractively(account: Account, messageId: MessageId, reaction: String?, isLarge: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        transaction.setPendingMessageAction(type: .updateReaction, id: messageId, action: UpdateMessageReactionsAction())
        transaction.updateMessage(messageId, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var attributes = currentMessage.attributes
            loop: for j in 0 ..< attributes.count {
                if let _ = attributes[j] as? PendingReactionsMessageAttribute {
                    attributes.remove(at: j)
                    break loop
                }
            }
            attributes.append(PendingReactionsMessageAttribute(accountPeerId: account.peerId, value: reaction, isLarge: isLarge))
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
    }
    |> ignoreValues
}

private enum RequestUpdateMessageReactionError {
    case generic
}

private func requestUpdateMessageReaction(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId) -> Signal<Never, RequestUpdateMessageReactionError> {
    return postbox.transaction { transaction -> (Peer, String?, Bool)? in
        guard let peer = transaction.getPeer(messageId.peerId) else {
            return nil
        }
        guard let message = transaction.getMessage(messageId) else {
            return nil
        }
        var value: String?
        var isLarge: Bool = false
        for attribute in message.attributes {
            if let attribute = attribute as? PendingReactionsMessageAttribute {
                value = attribute.value
                isLarge = attribute.isLarge
                break
            }
        }
        return (peer, value, isLarge)
    }
    |> castError(RequestUpdateMessageReactionError.self)
    |> mapToSignal { peerAndValue in
        guard let (peer, value, isLarge) = peerAndValue else {
            return .fail(.generic)
        }
        guard let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        if messageId.namespace != Namespaces.Message.Cloud {
            return .fail(.generic)
        }
        
        var flags: Int32 = 0
        if value != nil {
            flags |= 1 << 0
            if isLarge {
                flags |= 1 << 1
            }
        }
        
        let signal: Signal<Never, RequestUpdateMessageReactionError> = network.request(Api.functions.messages.sendReaction(flags: flags, peer: inputPeer, msgId: messageId.id, reaction: value))
        |> mapError { _ -> RequestUpdateMessageReactionError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, RequestUpdateMessageReactionError> in
            return postbox.transaction { transaction -> Void in
                transaction.setPendingMessageAction(type: .updateReaction, id: messageId, action: UpdateMessageReactionsAction())
                transaction.updateMessage(messageId, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    let reactions = mergedMessageReactions(attributes: currentMessage.attributes)
                    var attributes = currentMessage.attributes
                    for j in (0 ..< attributes.count).reversed() {
                        if attributes[j] is PendingReactionsMessageAttribute || attributes[j] is ReactionsMessageAttribute {
                            attributes.remove(at: j)
                        }
                    }
                    if let reactions = reactions {
                        attributes.append(reactions)
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
                stateManager.addUpdates(result)
            }
            |> castError(RequestUpdateMessageReactionError.self)
            |> ignoreValues
        }
        #if DEBUG
        return signal |> delay(0.1, queue: .mainQueue())
        #else
        return signal
        #endif
    }
}

private final class ManagedApplyPendingMessageReactionsActionsHelper {
    var operationDisposables: [MessageId: Disposable] = [:]
    
    func update(entries: [PendingMessageActionsEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PendingMessageActionsEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validIds = Set<MessageId>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.id.peerId) {
                hasRunningOperationForPeerId.insert(entry.id.peerId)
                validIds.insert(entry.id)
                
                if self.operationDisposables[entry.id] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.id] = disposable
                }
            }
        }
        
        var removeMergedIds: [MessageId] = []
        for (id, disposable) in self.operationDisposables {
            if !validIds.contains(id) {
                removeMergedIds.append(id)
                disposeOperations.append(disposable)
            }
        }
        
        for id in removeMergedIds {
            self.operationDisposables.removeValue(forKey: id)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenAction(postbox: Postbox, type: PendingMessageActionType, id: MessageId, _ f: @escaping (Transaction, PendingMessageActionsEntry?) -> Signal<Never, NoError>) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        var result: PendingMessageActionsEntry?
        
        if let action = transaction.getPendingMessageAction(type: type, id: id) as? UpdateMessageReactionsAction {
            result = PendingMessageActionsEntry(id: id, action: action)
        }
        
        return f(transaction, result)
    }
    |> switchToLatest
}

func managedApplyPendingMessageReactionsActions(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedApplyPendingMessageReactionsActionsHelper>(value: ManagedApplyPendingMessageReactionsActionsHelper())
        
        let actionsKey = PostboxViewKey.pendingMessageActions(type: .updateReaction)
        let disposable = postbox.combinedView(keys: [actionsKey]).start(next: { view in
            var entries: [PendingMessageActionsEntry] = []
            if let v = view.views[actionsKey] as? PendingMessageActionsView {
                entries = v.entries
            }
            
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) in
                return helper.update(entries: entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenAction(postbox: postbox, type: .updateReaction, id: entry.id, { transaction, entry -> Signal<Never, NoError> in
                    if let entry = entry {
                        if let _ = entry.action as? UpdateMessageReactionsAction {
                            return synchronizeMessageReactions(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, id: entry.id)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(
                    postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .updateReaction, id: entry.id, action: nil)
                    }
                    |> ignoreValues
                )
                
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

private func synchronizeMessageReactions(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Never, NoError> {
    return requestUpdateMessageReaction(postbox: postbox, network: network, stateManager: stateManager, messageId: id)
    |> `catch` { _ -> Signal<Never, NoError> in
        return postbox.transaction { transaction -> Void in
            transaction.setPendingMessageAction(type: .updateReaction, id: id, action: nil)
            transaction.updateMessage(id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                var attributes = currentMessage.attributes
                loop: for j in 0 ..< attributes.count {
                    if let _ = attributes[j] as? PendingReactionsMessageAttribute {
                        attributes.remove(at: j)
                        break loop
                    }
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
        }
        |> ignoreValues
    }
}

public extension EngineMessageReactionListContext.State {
    init(message: EngineMessage, reaction: String?) {
        var totalCount = 0
        var hasOutgoingReaction = false
        var items: [EngineMessageReactionListContext.Item] = []
        if let reactionsAttribute = message._asMessage().reactionsAttribute {
            for messageReaction in reactionsAttribute.reactions {
                if reaction == nil || messageReaction.value == reaction {
                    if messageReaction.isSelected {
                        hasOutgoingReaction = true
                    }
                    totalCount += Int(messageReaction.count)
                }
            }
            for recentPeer in reactionsAttribute.recentPeers {
                if let peer = message.peers[recentPeer.peerId] {
                    if reaction == nil || recentPeer.value == reaction {
                        items.append(EngineMessageReactionListContext.Item(peer: EnginePeer(peer), reaction: recentPeer.value))
                    }
                }
            }
        }
        if items.count != totalCount {
            items.removeAll()
        }
        self.init(
            hasOutgoingReaction: hasOutgoingReaction,
            totalCount: totalCount,
            items: items,
            canLoadMore: items.count != totalCount && totalCount != 0
        )
    }
}

public final class EngineMessageReactionListContext {
    public final class Item: Equatable {
        public let peer: EnginePeer
        public let reaction: String?
        
        public init(
            peer: EnginePeer,
            reaction: String?
        ) {
            self.peer = peer
            self.reaction = reaction
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.reaction != rhs.reaction {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public var hasOutgoingReaction: Bool
        public var totalCount: Int
        public var items: [Item]
        public var canLoadMore: Bool
        
        public init(
            hasOutgoingReaction: Bool,
            totalCount: Int,
            items: [Item],
            canLoadMore: Bool
        ) {
            self.hasOutgoingReaction = hasOutgoingReaction
            self.totalCount = totalCount
            self.items = items
            self.canLoadMore = canLoadMore
        }
    }
    
    private final class Impl {
        struct InternalState: Equatable {
            var hasOutgoingReaction: Bool
            var totalCount: Int
            var items: [Item]
            var canLoadMore: Bool
            var nextOffset: String?
        }
        
        let queue: Queue
        
        let account: Account
        let message: EngineMessage
        let reaction: String?
        
        let disposable = MetaDisposable()
        
        var state: InternalState
        let statePromise = Promise<InternalState>()
        
        var isLoadingMore: Bool = false
        
        init(queue: Queue, account: Account, message: EngineMessage, reaction: String?) {
            self.queue = queue
            self.account = account
            self.message = message
            self.reaction = reaction
            
            let initialState = EngineMessageReactionListContext.State(message: message, reaction: reaction)
            self.state = InternalState(hasOutgoingReaction: initialState.hasOutgoingReaction, totalCount: initialState.totalCount, items: initialState.items, canLoadMore: true, nextOffset: nil)
            
            if initialState.canLoadMore {
                self.loadMore()
            } else {
                self.statePromise.set(.single(self.state))
            }
        }
        
        deinit {
            assert(self.queue.isCurrent())
            
            self.disposable.dispose()
        }
        
        func loadMore() {
            if self.isLoadingMore {
                return
            }
            self.isLoadingMore = true
            
            let account = self.account
            let message = self.message
            let reaction = self.reaction
            let currentOffset = self.state.nextOffset
            let limit = self.state.items.isEmpty ? 50 : 100
            let signal: Signal<InternalState, NoError> = self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(message.id.peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<InternalState, NoError> in
                if message.id.namespace != Namespaces.Message.Cloud {
                    return .single(InternalState(hasOutgoingReaction: false, totalCount: 0, items: [], canLoadMore: false, nextOffset: nil))
                }
                guard let inputPeer = inputPeer else {
                    return .single(InternalState(hasOutgoingReaction: false, totalCount: 0, items: [], canLoadMore: false, nextOffset: nil))
                }
                var flags: Int32 = 0
                if reaction != nil {
                    flags |= 1 << 0
                }
                if currentOffset != nil {
                    flags |= 1 << 1
                }
                return account.network.request(Api.functions.messages.getMessageReactionsList(flags: flags, peer: inputPeer, id: message.id.id, reaction: reaction, offset: currentOffset, limit: Int32(limit)))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.MessageReactionsList?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<InternalState, NoError> in
                    return account.postbox.transaction { transaction -> InternalState in
                        switch result {
                        case let .messageReactionsList(_, count, reactions, chats, users, nextOffset):
                            var peers: [Peer] = []
                            var peerPresences: [PeerId: PeerPresence] = [:]
                            
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                                if let presence = TelegramUserPresence(apiUser: user) {
                                    peerPresences[telegramUser.id] = presence
                                }
                            }
                            for chat in chats {
                                if let peer = parseTelegramGroupOrChannel(chat: chat) {
                                    peers.append(peer)
                                }
                            }
                            
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                return updated
                            })
                            updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                            
                            var items: [EngineMessageReactionListContext.Item] = []
                            for reaction in reactions {
                                switch reaction {
                                case let .messagePeerReaction(_, peer, reaction):
                                    if let peer = transaction.getPeer(peer.peerId) {
                                        items.append(EngineMessageReactionListContext.Item(peer: EnginePeer(peer), reaction: reaction))
                                    }
                                }
                            }
                            
                            return InternalState(hasOutgoingReaction: false, totalCount: Int(count), items: items, canLoadMore: nextOffset != nil, nextOffset: nextOffset)
                        case .none:
                            return InternalState(hasOutgoingReaction: false, totalCount: 0, items: [], canLoadMore: false, nextOffset: nil)
                        }
                    }
                }
            }
            self.disposable.set((signal
            |> deliverOn(self.queue)).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                var existingPeerIds = Set<EnginePeer.Id>()
                for item in strongSelf.state.items {
                    existingPeerIds.insert(item.peer.id)
                }
                
                for item in state.items {
                    if existingPeerIds.contains(item.peer.id) {
                        continue
                    }
                    existingPeerIds.insert(item.peer.id)
                    strongSelf.state.items.append(item)
                }
                if state.canLoadMore {
                    strongSelf.state.totalCount = max(state.totalCount, strongSelf.state.items.count)
                } else {
                    strongSelf.state.totalCount = strongSelf.state.items.count
                }
                strongSelf.state.canLoadMore = state.canLoadMore
                strongSelf.state.nextOffset = state.nextOffset
                
                strongSelf.isLoadingMore = false
                strongSelf.statePromise.set(.single(strongSelf.state))
            }))
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.statePromise.get().start(next: { state in
                    subscriber.putNext(State(
                        hasOutgoingReaction: state.hasOutgoingReaction,
                        totalCount: state.totalCount,
                        items: state.items,
                        canLoadMore: state.canLoadMore
                    ))
                }))
            }
            return disposable
        }
    }
    
    init(account: Account, message: EngineMessage, reaction: String?) {
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, message: message, reaction: reaction)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}

public enum UpdatePeerAllowedReactionsError {
    case generic
}

func _internal_updatePeerAllowedReactions(account: Account, peerId: PeerId, allowedReactions: [String]) -> Signal<Never, UpdatePeerAllowedReactionsError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(UpdatePeerAllowedReactionsError.self)
    |> mapToSignal { inputPeer -> Signal<Never, UpdatePeerAllowedReactionsError> in
        guard let inputPeer = inputPeer else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.messages.setChatAvailableReactions(peer: inputPeer, availableReactions: allowedReactions))
        |> mapError { _ -> UpdatePeerAllowedReactionsError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, UpdatePeerAllowedReactionsError> in
            account.stateManager.addUpdates(result)
            
            return account.postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: [peerId], update: { _, current in
                    if let current = current as? CachedChannelData {
                        return current.withUpdatedAllowedReactions(allowedReactions)
                    } else if let current = current as? CachedGroupData {
                        return current.withUpdatedAllowedReactions(allowedReactions)
                    } else {
                        return current
                    }
                })
            }
            |> ignoreValues
            |> castError(UpdatePeerAllowedReactionsError.self)
        }
    }
}

func _internal_updateDefaultReaction(account: Account, reaction: String) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.messages.setDefaultReaction(reaction: reaction))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> ignoreValues
}

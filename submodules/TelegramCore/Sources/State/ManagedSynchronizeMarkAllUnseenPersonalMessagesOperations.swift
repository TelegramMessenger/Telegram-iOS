import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit

private final class ManagedSynchronizeMarkAllUnseenPersonalMessagesOperationsHelper {
    var operationDisposables: [Int32: Disposable] = [:]
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validMergedIndices = Set<Int32>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.peerId) {
                hasRunningOperationForPeerId.insert(entry.peerId)
                validMergedIndices.insert(entry.mergedIndex)
                
                if self.operationDisposables[entry.mergedIndex] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.mergedIndex] = disposable
                }
            }
        }
        
        var removeMergedIndices: [Int32] = []
        for (mergedIndex, disposable) in self.operationDisposables {
            if !validMergedIndices.contains(mergedIndex) {
                removeMergedIndices.append(mergedIndex)
                disposeOperations.append(disposable)
            }
        }
        
        for mergedIndex in removeMergedIndices {
            self.operationDisposables.removeValue(forKey: mergedIndex)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenOperation<T>(postbox: Postbox, peerId: PeerId, operationType: T.Type, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is T  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
    }
    |> switchToLatest
}

func managedSynchronizeMarkAllUnseenPersonalMessagesOperations(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let tag: PeerOperationLogTag = OperationLogTags.SynchronizeMarkAllUnseenPersonalMessages
        
        let helper = Atomic<ManagedSynchronizeMarkAllUnseenPersonalMessagesOperationsHelper>(value: ManagedSynchronizeMarkAllUnseenPersonalMessagesOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, operationType: SynchronizeMarkAllUnseenPersonalMessagesOperation.self, tag: tag, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeMarkAllUnseenPersonalMessagesOperation {
                            return synchronizeMarkAllUnseen(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, peerId: entry.peerId, operation: operation)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                    |> then(postbox.transaction { transaction -> Void in
                        let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
                    })
                
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

private enum GetUnseenIdsError {
    case done
    case error(MTRpcError)
}

private func synchronizeMarkAllUnseen(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, operation: SynchronizeMarkAllUnseenPersonalMessagesOperation) -> Signal<Void, NoError> {
    guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) else {
        return .complete()
    }
    let inputChannel = transaction.getPeer(peerId).flatMap(apiInputChannel)
    let limit: Int32 = 100
    let oneOperation: (Int32) -> Signal<Int32?, MTRpcError> = { maxId in
        return network.request(Api.functions.messages.getUnreadMentions(flags: 0, peer: inputPeer, topMsgId: nil, offsetId: maxId, addOffset: maxId == 0 ? 0 : -1, limit: limit, maxId: maxId == 0 ? 0 : (maxId + 1), minId: 1))
        |> mapToSignal { result -> Signal<[MessageId], MTRpcError> in
            switch result {
                case let .messages(messages, _, _):
                    return .single(messages.compactMap({ $0.id() }))
                case let .channelMessages(_, _, _, _, messages, _, _):
                    return .single(messages.compactMap({ $0.id() }))
                case .messagesNotModified:
                    return .single([])
                case let .messagesSlice(_, _, _, _, messages, _, _):
                    return .single(messages.compactMap({ $0.id() }))
            }
        }
        |> mapToSignal { ids -> Signal<Int32?, MTRpcError> in
            let filteredIds = ids.filter { $0.id <= operation.maxId }
            if filteredIds.isEmpty {
                return .single(ids.min()?.id)
            }
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                guard let inputChannel = inputChannel else {
                    return .single(nil)
                }
                return network.request(Api.functions.channels.readMessageContents(channel: inputChannel, id: filteredIds.map { $0.id }))
                |> map { result -> Int32? in
                    if ids.count < limit {
                        return nil
                    } else {
                        return ids.min()?.id
                    }
                }
            } else {
                return network.request(Api.functions.messages.readMessageContents(id: filteredIds.map { $0.id }))
                |> map { result -> Int32? in
                    switch result {
                        case let .affectedMessages(pts, ptsCount):
                            stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                    }
                    if ids.count < limit {
                        return nil
                    } else {
                        return ids.min()?.id
                    }
                }
            }
        }
    }
    let currentMaxId = Atomic<Int32>(value: 0)
    let loopOperations: Signal<Void, GetUnseenIdsError> = (
        (
            deferred {
                return oneOperation(currentMaxId.with { $0 })
            }
            |> `catch` { error -> Signal<Int32?, GetUnseenIdsError> in
                return .fail(.error(error))
            }
        )
        |> mapToSignal { resultId -> Signal<Void, GetUnseenIdsError> in
            if let resultId = resultId {
                let previous = currentMaxId.swap(resultId)
                if previous == resultId {
                    return .fail(.done)
                } else {
                    return .complete()
                }
            } else {
                return .fail(.done)
            }
        }
        |> `catch` { error -> Signal<Void, GetUnseenIdsError> in
            switch error {
                case .done, .error:
                    return .fail(error)
            }
        }
        |> restart
    )
    return loopOperations
    |> `catch` { _ -> Signal<Void, NoError> in
        return .complete()
    }
}

func markUnseenPersonalMessage(transaction: Transaction, id: MessageId, addSynchronizeAction: Bool) {
    if let message = transaction.getMessage(id) {
        var consume = false
        inner: for attribute in message.attributes {
            if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed, !attribute.pending {
                consume = true
                break inner
            }
        }
        if consume {
            transaction.updateMessage(id, update: { currentMessage in
                var attributes = currentMessage.attributes
                loop: for j in 0 ..< attributes.count {
                    if let attribute = attributes[j] as? ConsumablePersonalMentionMessageAttribute {
                        attributes[j] = ConsumablePersonalMentionMessageAttribute(consumed: attribute.consumed, pending: true)
                        break loop
                    }
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
            
            if addSynchronizeAction {
                transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: ConsumePersonalMessageAction())
            }
        }
    }
}

func managedSynchronizeMarkAllUnseenReactionsOperations(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let tag: PeerOperationLogTag = OperationLogTags.SynchronizeMarkAllUnseenReactions
        
        let helper = Atomic<ManagedSynchronizeMarkAllUnseenPersonalMessagesOperationsHelper>(value: ManagedSynchronizeMarkAllUnseenPersonalMessagesOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, operationType: SynchronizeMarkAllUnseenReactionsOperation.self, tag: tag, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeMarkAllUnseenReactionsOperation {
                            return synchronizeMarkAllUnseenReactions(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, peerId: entry.peerId, operation: operation)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                    |> then(postbox.transaction { transaction -> Void in
                        let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
                    })
                
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

private func synchronizeMarkAllUnseenReactions(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, operation: SynchronizeMarkAllUnseenReactionsOperation) -> Signal<Void, NoError> {
    guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) else {
        return .complete()
    }
    
    let signal = network.request(Api.functions.messages.readReactions(flags: 0, peer: inputPeer, topMsgId: nil))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.AffectedHistory?, Bool> in
        return .fail(true)
    }
    |> mapToSignal { result -> Signal<Void, Bool> in
        if let result = result {
            switch result {
            case let .affectedHistory(pts, ptsCount, offset):
                stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                if offset == 0 {
                    return .fail(true)
                } else {
                    return .complete()
                }
            }
        } else {
            return .fail(true)
        }
    }
    return (signal |> restart)
    |> `catch` { _ -> Signal<Void, NoError> in
        return .complete()
    }
}

func markUnseenReactionMessage(transaction: Transaction, id: MessageId, addSynchronizeAction: Bool) {
    if let message = transaction.getMessage(id) {
        var consume = false
        inner: for attribute in message.attributes {
            if let attribute = attribute as? ReactionsMessageAttribute, !attribute.hasUnseen {
                consume = true
                break inner
            }
        }
        if consume {
            transaction.updateMessage(id, update: { currentMessage in
                var attributes = currentMessage.attributes
                loop: for j in 0 ..< attributes.count {
                    if let attribute = attributes[j] as? ReactionsMessageAttribute {
                        attributes[j] = attribute.withAllSeen()
                        break loop
                    }
                }
                var tags = currentMessage.tags
                tags.remove(.unseenReaction)
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
            
            if addSynchronizeAction {
                transaction.setPendingMessageAction(type: .readReaction, id: id, action: ReadReactionAction())
            }
        }
    }
}

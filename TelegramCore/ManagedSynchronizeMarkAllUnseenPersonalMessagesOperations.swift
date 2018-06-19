import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
#else
import Postbox
import SwiftSignalKit
import MtProtoKitDynamic
#endif

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

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeMarkAllUnseenPersonalMessagesOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
        } |> switchToLatest
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
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
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
    let oneOperation: Signal<Bool, MTRpcError> =  network.request(Api.functions.messages.getUnreadMentions(peer: inputPeer, offsetId: 0, addOffset: 0, limit: 100, maxId: 0, minId: 0))
    |> mapToSignal { result -> Signal<[MessageId], MTRpcError> in
        switch result {
            case let .messages(messages, _, _):
                return .single(messages.compactMap({ $0.id }))
            case let .channelMessages(channelMessages):
                return .single(channelMessages.messages.compactMap({ $0.id }))
            case .messagesNotModified:
                return .single([])
            case let .messagesSlice(messagesSlice):
                return .single(messagesSlice.messages.compactMap({ $0.id }))
        }
    }
    |> mapToSignal { ids -> Signal<Bool, MTRpcError> in
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            guard let inputChannel = inputChannel else {
                return .single(true)
            }
            return network.request(Api.functions.channels.readMessageContents(channel: inputChannel, id: ids.map { $0.id }))
            |> mapToSignal { result -> Signal<Bool, MTRpcError> in
                return .single(true)
            }
        } else {
            return network.request(Api.functions.messages.readMessageContents(id: ids.map { $0.id }))
            |> mapToSignal { result -> Signal<Bool, MTRpcError> in
                switch result {
                    case let .affectedMessages(pts, ptsCount):
                        stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                }
                return .single(true)
            }
        }
    }
    let loopOperations: Signal<Void, GetUnseenIdsError> = (
        (oneOperation
            |> `catch` { error -> Signal<Bool, GetUnseenIdsError> in
                return .fail(.error(error))
            }
        )
        |> mapToSignal { result -> Signal<Void, GetUnseenIdsError> in
            if result {
                return .fail(.done)
            } else {
                return .complete()
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

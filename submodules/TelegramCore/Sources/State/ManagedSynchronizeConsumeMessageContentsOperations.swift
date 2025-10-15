import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


private final class ManagedSynchronizeConsumeMessageContentsOperationHelper {
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

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SynchronizeConsumeMessageContents, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeConsumeMessageContentsOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
    } |> switchToLatest
}

func managedSynchronizeConsumeMessageContentOperations(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedSynchronizeConsumeMessageContentsOperationHelper>(value: ManagedSynchronizeConsumeMessageContentsOperationHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: OperationLogTags.SynchronizeConsumeMessageContents, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeConsumeMessageContentsOperation {
                            return synchronizeConsumeMessageContents(transaction: transaction, network: network, stateManager: stateManager, peerId: entry.peerId, operation: operation)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                    |> then(postbox.transaction { transaction -> Void in
                        let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: OperationLogTags.SynchronizeConsumeMessageContents, tagLocalIndex: entry.tagLocalIndex)
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

private func synchronizeConsumeMessageContents(transaction: Transaction, network: Network, stateManager: AccountStateManager, peerId: PeerId, operation: SynchronizeConsumeMessageContentsOperation) -> Signal<Void, NoError> {
    if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
        return network.request(Api.functions.messages.readMessageContents(id: operation.messageIds.map { $0.id }))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Void, NoError> in
            if let result = result {
                switch result {
                    case let .affectedMessages(pts, ptsCount):
                        stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                }
            }
            return .complete()
        }
    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
        if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.readMessageContents(channel: inputChannel, id: operation.messageIds.map { $0.id }))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Void, NoError> in
                return .complete()
            }
        } else {
            return .complete()
        }
    } else {
        return .complete()
    }
}

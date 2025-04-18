import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


private final class ManagedSynchronizeGroupedPeersOperationsHelper {
    var operationDisposables: [Int32: Disposable] = [:]
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var validMergedIndices = Set<Int32>()
        for entry in entries {
            validMergedIndices.insert(entry.mergedIndex)
            
            if self.operationDisposables[entry.mergedIndex] == nil {
                let disposable = MetaDisposable()
                beginOperations.append((entry, disposable))
                self.operationDisposables[entry.mergedIndex] = disposable
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

private func withTakenOperations(postbox: Postbox, peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndices: [Int32], _ f: @escaping (Transaction, [PeerMergedOperationLogEntry]) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: [PeerMergedOperationLogEntry] = []
        for tagLocalIndex in tagLocalIndices {
            transaction.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
                if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeGroupedPeersOperation  {
                    result.append(entry.mergedEntry!)
                    return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
                } else {
                    return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
                }
            })
        }
        
        return f(transaction, result)
    }
    |> switchToLatest
}

func managedSynchronizeGroupedPeersOperations(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let tag: PeerOperationLogTag = OperationLogTags.SynchronizeGroupedPeers
        
        let helper = Atomic<ManagedSynchronizeGroupedPeersOperationsHelper>(value: ManagedSynchronizeGroupedPeersOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 100).start(next: { view in
            let (disposeOperations, sharedBeginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            var beginOperationsByPeerId: [PeerId: [(PeerMergedOperationLogEntry, MetaDisposable)]] = [:]
            for (entry, disposable) in sharedBeginOperations {
                if beginOperationsByPeerId[entry.peerId] == nil {
                    beginOperationsByPeerId[entry.peerId] = []
                }
                beginOperationsByPeerId[entry.peerId]?.append((entry, disposable))
            }
            
            if !beginOperationsByPeerId.isEmpty {
                for (peerId, peerOperations) in beginOperationsByPeerId {
                    let localIndices = Array(peerOperations.map({ $0.0.tagLocalIndex }))
                    let sharedDisposable = MetaDisposable()
                    for (_, disposable) in peerOperations {
                        disposable.set(sharedDisposable)
                    }
                    
                    let signal = withTakenOperations(postbox: postbox, peerId: peerId, tag: tag, tagLocalIndices: localIndices, { transaction, entries -> Signal<Void, NoError> in
                        if !entries.isEmpty {
                            let operations = entries.compactMap({ $0.contents as? SynchronizeGroupedPeersOperation })
                            if !operations.isEmpty {
                                return synchronizeGroupedPeers(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, operations: operations)
                            }
                        }
                        return .complete()
                    })
                    |> then(postbox.transaction { transaction -> Void in
                        for tagLocalIndex in localIndices {
                            let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex)
                        }
                    })
                    
                    sharedDisposable.set(signal.start())
                }
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

private func synchronizeGroupedPeers(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, operations: [SynchronizeGroupedPeersOperation]) -> Signal<Void, NoError> {
    if operations.isEmpty {
        return .complete()
    }
    var folderPeers: [Api.InputFolderPeer] = []
    for operation in operations {
        if let inputPeer = transaction.getPeer(operation.peerId).flatMap(apiInputPeer) {
            folderPeers.append(.inputFolderPeer(peer: inputPeer, folderId: operation.groupId.rawValue))
        }
    }
    if folderPeers.isEmpty {
        return .complete()
    }
    
    return network.request(Api.functions.folders.editPeerFolders(folderPeers: folderPeers))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { updates -> Signal<Void, NoError> in
        if let updates = updates {
            stateManager.addUpdates(updates)
        }
        return .complete()
    }
}


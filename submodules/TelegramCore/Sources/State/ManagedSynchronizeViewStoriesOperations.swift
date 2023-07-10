import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

private final class ManagedSynchronizeViewStoriesOperationsHelper {
    var operationDisposables: [PeerId: (Int32, Disposable)] = [:]
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var validPeerIds: [PeerId] = []
        for entry in entries {
            guard let operation = entry.contents as? SynchronizeViewStoriesOperation else {
                continue
            }
            validPeerIds.append(entry.peerId)
            var replace = true
            if let current = self.operationDisposables[entry.peerId] {
                if current.0 != operation.storyId {
                    disposeOperations.append(current.1)
                    replace = true
                }
            } else {
                replace = true
            }
            if replace {
                let disposable = MetaDisposable()
                self.operationDisposables[entry.peerId] = (operation.storyId, disposable)
                beginOperations.append((entry, disposable))
            }
        }
        
        var removedPeerIds: [PeerId] = []
        for (peerId, info) in self.operationDisposables {
            if !validPeerIds.contains(peerId) {
                removedPeerIds.append(peerId)
                disposeOperations.append(info.1)
            }
        }
        for peerId in removedPeerIds {
            self.operationDisposables.removeValue(forKey: peerId)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values.map(\.1))
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SynchronizeViewStories, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeViewStoriesOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
    } |> switchToLatest
}

func managedSynchronizeViewStoriesOperations(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedSynchronizeViewStoriesOperationsHelper>(value: ManagedSynchronizeViewStoriesOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: OperationLogTags.SynchronizeViewStories, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeViewStoriesOperation {
                            if let peer = transaction.getPeer(entry.peerId) {
                                return pushStoriesAreSeen(postbox: postbox, network: network, stateManager: stateManager, peer: peer, operation: operation)
                            } else {
                                return .complete()
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.transaction { transaction -> Void in
                    let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: OperationLogTags.SynchronizeViewStories, tagLocalIndex: entry.tagLocalIndex)
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

private func pushStoriesAreSeen(postbox: Postbox, network: Network, stateManager: AccountStateManager, peer: Peer, operation: SynchronizeViewStoriesOperation) -> Signal<Void, NoError> {
    guard let inputPeer = apiInputUser(peer) else {
        return .complete()
    }
    return network.request(Api.functions.stories.readStories(userId: inputPeer, maxId: operation.storyId))
    |> `catch` { _ -> Signal<[Int32], NoError> in
        return .single([])
    }
    |> map { _ -> Void in
        return Void()
    }
}

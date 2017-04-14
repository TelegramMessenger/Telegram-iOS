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

private final class ManagedSynchronizeSavedGifsOperationsHelper {
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

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: @escaping (Modifier, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        modifier.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeSavedGifsOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(modifier, result)
        } |> switchToLatest
}

func managedSynchronizeSavedGifsOperations(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return Signal { _ in
        let tag: PeerOperationLogTag = OperationLogTags.SynchronizeSavedGifs
        
        let helper = Atomic<ManagedSynchronizeSavedGifsOperationsHelper>(value: ManagedSynchronizeSavedGifsOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex, { modifier, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeSavedGifsOperation {
                            return synchronizeSavedGifs(modifier: modifier, postbox: postbox, network: network, operation: operation)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                    |> then(postbox.modify { modifier -> Void in
                        let _ = modifier.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
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

private func synchronizeSavedGifs(modifier: Modifier, postbox: Postbox, network: Network, operation: SynchronizeSavedGifsOperation) -> Signal<Void, NoError> {
    switch operation.content {
        case let .add(id, accessHash):
            return network.request(Api.functions.messages.saveGif(id: .inputDocument(id: id, accessHash: accessHash), unsave: .boolFalse))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                }
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return .complete()
                }
        case let .remove(id, accessHash):
            return network.request(Api.functions.messages.saveGif(id: .inputDocument(id: id, accessHash: accessHash), unsave: .boolTrue))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                }
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return .complete()
                }
        case .sync:
            return managedRecentGifs(postbox: postbox, network: network)
    }
}

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

private final class ManagedSynchronizeCloudPinnedChatsOperationsHelper {
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

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tagLocalIndex: Int32, _ f: @escaping (Modifier, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        modifier.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, let operation = entry.contents as? CloudChatRemoveMessagesOperation {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(modifier, result)
        } |> switchToLatest
}

func managedSynchronizeCloudPinnedChatsOperations(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic(value: ManagedSynchronizeCloudPinnedChatsOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: OperationLogTags.CloudChatRemoveMessages, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex, { modifier, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? CloudChatRemoveMessagesOperation {
                            if let peer = modifier.getPeer(entry.peerId) {
                                return removeMessages(postbox: postbox, network: network, stateManager: stateManager, peer: peer, operation: operation)
                            } else {
                                return .complete()
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                    |> then(postbox.modify { modifier -> Void in
                        modifier.operationLogRemoveEntry(peerId: entry.peerId, tag: OperationLogTags.CloudChatRemoveMessages, tagLocalIndex: entry.tagLocalIndex)
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
        }
    }
}

private func removeMessages(postbox: Postbox, network: Network, stateManager: AccountStateManager, peer: Peer, operation: CloudChatRemoveMessagesOperation) -> Signal<Void, NoError> {
    if peer.id.namespace == Namespaces.Peer.CloudChannel {
        if let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.deleteMessages(channel: inputChannel, id: operation.messageIds.map { $0.id }))
                |> map { result -> Api.messages.AffectedMessages? in
                    return result
                }
                |> `catch` { _ in
                    return .single(nil)
                }
                |> mapToSignal { _ in
                    return .complete()
            }
        } else {
            return .complete()
        }
    } else {
        return network.request(Api.functions.messages.deleteMessages(id: operation.messageIds.map { $0.id }))
            |> map { result -> Api.messages.AffectedMessages? in
                return result
            }
            |> `catch` { _ in
                return .single(nil)
            }
            |> mapToSignal { result in
                if let result = result {
                    switch result {
                    case let .affectedMessages(pts, ptsCount):
                        stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                    }
                }
                return .complete()
        }
    }
}

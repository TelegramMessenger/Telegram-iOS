import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


private final class ManagedSynchronizeChatInputStateOperationsHelper {
    var operationDisposables: [Int32: Disposable] = [:]
    
    private let hasRunningOperations: ValuePromise<Bool>
    
    init(hasRunningOperations: ValuePromise<Bool>) {
        self.hasRunningOperations = hasRunningOperations
    }
    
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
        
        self.hasRunningOperations.set(!self.operationDisposables.isEmpty)
        
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
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeChatInputStateOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
    } |> switchToLatest
}

func managedSynchronizeChatInputStateOperations(postbox: Postbox, network: Network) -> Signal<Bool, NoError> {
    return Signal { subscriber in
        let hasRunningOperations = ValuePromise<Bool>(false, ignoreRepeated: true)
        let tag: PeerOperationLogTag = OperationLogTags.SynchronizeChatInputStates
        
        let helper = Atomic<ManagedSynchronizeChatInputStateOperationsHelper>(value: ManagedSynchronizeChatInputStateOperationsHelper(hasRunningOperations: hasRunningOperations))
        
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
                        if let operation = entry.contents as? SynchronizeChatInputStateOperation {
                            return synchronizeChatInputState(transaction: transaction, postbox: postbox, network: network, peerId: entry.peerId, threadId: operation.threadId, operation: operation)
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
        
        let statusDisposable = hasRunningOperations.get().start(next: { value in
            subscriber.putNext(value)
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
            statusDisposable.dispose()
        }
    }
}

private func synchronizeChatInputState(transaction: Transaction, postbox: Postbox, network: Network, peerId: PeerId, threadId: Int64?, operation: SynchronizeChatInputStateOperation) -> Signal<Void, NoError> {
    var inputState: SynchronizeableChatInputState?
    let peerChatInterfaceState: StoredPeerChatInterfaceState?
    if let threadId = threadId {
        peerChatInterfaceState = transaction.getPeerChatThreadInterfaceState(peerId, threadId: threadId)
    } else {
        peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId)
    }
    
    if let peerChatInterfaceState = peerChatInterfaceState, let data = peerChatInterfaceState.data {
        inputState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState
    }

    if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
        var flags: Int32 = 0
        if let inputState = inputState {
            if inputState.replyToMessageId != nil {
                flags |= (1 << 0)
            }
            if !inputState.entities.isEmpty {
                flags |= (1 << 3)
            }
        }
        var topMsgId: Int32?
        if let threadId = threadId {
            flags |= (1 << 2)
            topMsgId = Int32(clamping: threadId)
        }
        return network.request(Api.functions.messages.saveDraft(flags: flags, replyToMsgId: inputState?.replyToMessageId?.id, topMsgId: topMsgId, peer: inputPeer, message: inputState?.text ?? "", entities: apiEntitiesFromMessageTextEntities(inputState?.entities ?? [], associatedPeers: SimpleDictionary())))
        |> delay(2.0, queue: Queue.concurrentDefaultQueue())
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    } else {
        return .complete()
    }
}

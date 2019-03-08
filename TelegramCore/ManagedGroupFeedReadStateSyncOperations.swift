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

/*private final class ManagedGroupFeedReadStateSyncOperationsHelper {
    var operationDisposables: [PeerGroupId: (GroupFeedReadStateSyncOperation, Disposable)] = [:]
    
    func update(entries: [PeerGroupId: GroupFeedReadStateSyncOperation]) -> (disposeOperations: [Disposable], beginOperations: [(PeerGroupId, GroupFeedReadStateSyncOperation, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerGroupId, GroupFeedReadStateSyncOperation, MetaDisposable)] = []
        
        var validIds = Set<PeerGroupId>()
        for (groupId, operation) in entries {
            validIds.insert(groupId)
            
            if let (currentOperation, currentDisposable) = self.operationDisposables[groupId] {
                if currentOperation != operation {
                    disposeOperations.append(currentDisposable)
                    
                    let disposable = MetaDisposable()
                    beginOperations.append((groupId, operation, disposable))
                    self.operationDisposables[groupId] = (operation, disposable)
                }
            } else {
                let disposable = MetaDisposable()
                beginOperations.append((groupId, operation, disposable))
                self.operationDisposables[groupId] = (operation, disposable)
            }
        }
        
        var removeIds: [PeerGroupId] = []
        for (id, operationAndDisposable) in self.operationDisposables {
            if !validIds.contains(id) {
                removeIds.append(id)
                disposeOperations.append(operationAndDisposable.1)
            }
        }
        
        for id in removeIds {
            self.operationDisposables.removeValue(forKey: id)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values).map { $0.1 }
        self.operationDisposables.removeAll()
        return disposables
    }
}

func managedGroupFeedReadStateSyncOperations(postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedGroupFeedReadStateSyncOperationsHelper>(value: ManagedGroupFeedReadStateSyncOperationsHelper())
        
        let disposable = postbox.combinedView(keys: [.groupFeedReadStateSyncOperations]).start(next: { view in
            var entries: [PeerGroupId: GroupFeedReadStateSyncOperation] = [:]
            if let v = view.views[.groupFeedReadStateSyncOperations] as? GroupFeedReadStateSyncOperationsView {
                entries = v.entries
            }
            
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerGroupId, GroupFeedReadStateSyncOperation, MetaDisposable)]) in
                return helper.update(entries: entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (groupId, operation, disposable) in beginOperations {
                let signal = performSyncOperation(postbox: postbox, network: network, accountPeerId: accountPeerId, stateManager: stateManager, groupId: groupId, operation: operation)
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

private func fetchReadStateNext(network: Network, groupId: PeerGroupId) -> Signal<GroupFeedReadState?, NoError> {
    /*feed*/
    return .single(nil)
    /*return network.request(Api.functions.messages.getPeerDialogs(peers: [.inputDialogPeerFeed(feedId: groupId.rawValue)]))
    |> retryRequest
    |> map { result -> GroupFeedReadState? in
        switch result {
            case let .peerDialogs(dialogs, messages, _, _, _):
                for dialog in dialogs {
                    if case let .dialogFeed(_, _, topMessage, feedId, _, resultMaxReadPosition, _, _) = dialog {
                        assert(feedId == groupId.rawValue)
                        if let resultMaxReadPosition = resultMaxReadPosition {
                            switch resultMaxReadPosition {
                                case let .feedPosition(date, peer, id):
                                    let index = MessageIndex(id: MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: id), timestamp: date).successor()
                                    return GroupFeedReadState(maxReadIndex: index)
                            }
                        } else {
                            for message in messages {
                                if let storeMessage = StoreMessage(apiMessage: message), let index = storeMessage.index, index.id.id == topMessage {
                                    return GroupFeedReadState(maxReadIndex: index)
                                }
                            }
                        }
                        break
                    }
                }
                return nil
        }       
    }*/
}

private func fetchReadState(network: Network, groupId: PeerGroupId) -> Signal<GroupFeedReadState?, NoError> {
    /*feed*/
    return .single(nil)
    /*return network.request(Api.functions.channels.getFeed(flags: 0, feedId: groupId.rawValue, offsetPosition: nil, addOffset: 0, limit: 1, maxPosition: nil, minPosition: nil, hash: 0))
        |> retryRequest
        |> map { result -> GroupFeedReadState? in
            switch result {
            case let .feedMessages(_, _, _, resultMaxReadPosition, messages, _, _):
                if let resultMaxReadPosition = resultMaxReadPosition {
                    switch resultMaxReadPosition {
                    case let .feedPosition(date, peer, id):
                        let index = MessageIndex(id: MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: id), timestamp: date).successor()
                        return GroupFeedReadState(maxReadIndex: index)
                    }
                } else {
                    var maxIndex: MessageIndex?
                    for message in messages {
                        if let storeMessage = StoreMessage(apiMessage: message), let messageIndex = storeMessage.index {
                            if maxIndex == nil || maxIndex! < messageIndex {
                                maxIndex = messageIndex
                            }
                        }
                    }
                    if let maxIndex = maxIndex {
                        return GroupFeedReadState(maxReadIndex: maxIndex)
                    } else {
                        return nil
                    }
                }
            case .feedMessagesNotModified:
                return nil
            }
    }*/
}

private func pushReadState(network: Network, accountPeerId: PeerId, groupId: PeerGroupId, state: GroupFeedReadState) -> Signal<Api.Updates?, NoError> {
    /*feed*/
    return .single(nil)
    /*let position: Api.FeedPosition = .feedPosition(date: state.maxReadIndex.timestamp, peer: groupBoundaryPeer(state.maxReadIndex.id.peerId, accountPeerId: accountPeerId), id: state.maxReadIndex.id.id)
    if GlobalTelegramCoreConfiguration.readMessages {
        return network.request(Api.functions.channels.readFeed(feedId: groupId.rawValue, maxPosition: position))
            |> retryRequest
            |> map(Optional.init)
    } else {
        return .single(nil)
    }*/
}

private func performSyncOperation(postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager, groupId: PeerGroupId, operation: GroupFeedReadStateSyncOperation) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> GroupFeedReadState? in
        return transaction.getGroupFeedReadState(groupId: groupId)
    } |> mapToSignal { currentState -> Signal<(GroupFeedReadState?, GroupFeedReadState?), NoError> in
        if operation.validate {
            return fetchReadState(network: network, groupId: groupId)
                |> map { (currentState, $0) }
        } else {
            return .single((currentState, nil))
        }
    } |> mapToSignal { currentState, remoteState -> Signal<Void, NoError> in
        if operation.push, let currentState = currentState {
            return pushReadState(network: network, accountPeerId: accountPeerId, groupId: groupId, state: currentState)
            |> mapToSignal { updates -> Signal<Void, NoError> in
                return postbox.transaction { transaction -> Void in
                    var resultingState: GroupFeedReadState
                    if let remoteState = remoteState, remoteState.maxReadIndex > currentState.maxReadIndex {
                        resultingState = remoteState
                    } else {
                        resultingState = currentState
                    }
                    transaction.applyGroupFeedReadMaxIndex(groupId: groupId, index: resultingState.maxReadIndex)
                    
                    if let updates = updates {
                        stateManager.addUpdates(updates)
                    }
                }
            }
        } else if operation.validate, let remoteState = remoteState {
            return postbox.transaction { transaction -> Void in
                transaction.applyGroupFeedReadMaxIndex(groupId: groupId, index: remoteState.maxReadIndex)
            }
        } else {
            return .complete()
        }
    }
}
*/

import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

private final class ManagedSynchronizePinnedChatsOperationsHelper {
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

private func withTakenOperation(postbox: Postbox, tag: PeerOperationLogTag, peerId: PeerId, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizePinnedChatsOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
        } |> switchToLatest
}

func managedSynchronizePinnedChatsOperations(postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager, tag: PeerOperationLogTag) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedSynchronizePinnedChatsOperationsHelper>(value: ManagedSynchronizePinnedChatsOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, tag: tag, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizePinnedChatsOperation {
                            if tag == OperationLogTags.SynchronizePinnedChats {
                                return synchronizePinnedChats(transaction: transaction, postbox: postbox, network: network, accountPeerId: accountPeerId, stateManager: stateManager, groupId: PeerGroupId(rawValue: Int32(entry.peerId.id._internalGetInt64Value())), operation: operation)
                            } else if tag == OperationLogTags.SynchronizePinnedSavedChats {
                                return synchronizePinnedSavedChats(transaction: transaction, postbox: postbox, network: network, accountPeerId: accountPeerId, stateManager: stateManager, operation: operation)
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.transaction { transaction -> Void in
                    let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
                })
                
                disposable.set((signal |> delay(2.0, queue: Queue.concurrentDefaultQueue())).start())
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

private func synchronizePinnedChats(transaction: Transaction, postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager, groupId: PeerGroupId, operation: SynchronizePinnedChatsOperation) -> Signal<Void, NoError> {
    let initialRemoteItemIds = operation.previousItemIds
    let initialRemoteItemIdsWithoutSecretChats = initialRemoteItemIds.filter { item in
        switch item {
            case let .peer(peerId):
                return peerId.namespace != Namespaces.Peer.SecretChat
        }
    }
    let localItemIds = transaction.getPinnedItemIds(groupId: groupId)
    let localItemIdsWithoutSecretChats = localItemIds.filter { item in
        switch item {
            case let .peer(peerId):
                return peerId.namespace != Namespaces.Peer.SecretChat
        }
    }
    
    return network.request(Api.functions.messages.getPinnedDialogs(folderId: groupId.rawValue))
    |> retryRequestIfNotFrozen
    |> mapToSignal { dialogs -> Signal<Void, NoError> in
        guard let dialogs else {
            return .complete()
        }
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            var storeMessages: [StoreMessage] = []
            var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
            var channelStates: [PeerId: Int32] = [:]
            var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
            var ttlPeriods: [PeerId: CachedPeerAutoremoveTimeout] = [:]
            
            var remoteItemIds: [PinnedItemId] = []
            
            let parsedPeers: AccumulatedPeers
            
            switch dialogs {
            case let .peerDialogs(dialogs, messages, chats, users, _):
                parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                
            loop: for dialog in dialogs {
                let apiPeer: Api.Peer
                let apiReadInboxMaxId: Int32
                let apiReadOutboxMaxId: Int32
                let apiTopMessage: Int32
                let apiUnreadCount: Int32
                let apiMarkedUnread: Bool
                var apiChannelPts: Int32?
                let apiTtlPeriod: Int32?
                let apiNotificationSettings: Api.PeerNotifySettings
                switch dialog {
                case let .dialog(flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, _, _, peerNotificationSettings, pts, _, _, ttlPeriod):
                    apiPeer = peer
                    apiTopMessage = topMessage
                    apiReadInboxMaxId = readInboxMaxId
                    apiReadOutboxMaxId = readOutboxMaxId
                    apiUnreadCount = unreadCount
                    apiMarkedUnread = (flags & (1 << 3)) != 0
                    apiNotificationSettings = peerNotificationSettings
                    apiChannelPts = pts
                    apiTtlPeriod = ttlPeriod
                case .dialogFolder:
                    //assertionFailure()
                    continue loop
                }
                
                let peerId: PeerId = apiPeer.peerId
                
                remoteItemIds.append(.peer(peerId))
                
                if readStates[peerId] == nil {
                    readStates[peerId] = [:]
                }
                readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount, markedUnread: apiMarkedUnread)
                
                if let apiChannelPts = apiChannelPts {
                    channelStates[peerId] = apiChannelPts
                }
                
                notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                
                ttlPeriods[peerId] = .known(apiTtlPeriod.flatMap(CachedPeerAutoremoveTimeout.Value.init(peerValue:)))
            }
                
                for message in messages {
                    var peerIsForum = false
                    if let peerId = message.peerId, let peer = parsedPeers.get(peerId), peer.isForumOrMonoForum {
                        peerIsForum = true
                    }
                    if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                        storeMessages.append(storeMessage)
                    }
                }
            }
            
            var resultingItemIds: [PinnedItemId]
            if initialRemoteItemIds == localItemIds {
                resultingItemIds = remoteItemIds
            } else {
                let locallyRemovedFromRemoteItemIds = Set(initialRemoteItemIdsWithoutSecretChats).subtracting(Set(localItemIdsWithoutSecretChats))
                let remotelyRemovedItemIds = Set(initialRemoteItemIdsWithoutSecretChats).subtracting(Set(remoteItemIds))
                
                resultingItemIds = localItemIds.filter { !remotelyRemovedItemIds.contains($0) }
                resultingItemIds.append(contentsOf: remoteItemIds.filter { !locallyRemovedFromRemoteItemIds.contains($0) && !resultingItemIds.contains($0) })
            }
            
            return postbox.transaction { transaction -> Signal<Void, NoError> in
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                
                transaction.setPinnedItemIds(groupId: groupId, itemIds: resultingItemIds)
                
                transaction.updateCurrentPeerNotificationSettings(notificationSettings)
                
                for (peerId, autoremoveValue) in ttlPeriods {
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        if peerId.namespace == Namespaces.Peer.CloudUser {
                            let current = (current as? CachedUserData) ?? CachedUserData()
                            return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                            let current = (current as? CachedChannelData) ?? CachedChannelData()
                            return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                            let current = (current as? CachedGroupData) ?? CachedGroupData()
                            return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                        } else {
                            return current
                        }
                    })
                }
                
                var allPeersWithMessages = Set<PeerId>()
                for message in storeMessages {
                    if !allPeersWithMessages.contains(message.id.peerId) {
                        allPeersWithMessages.insert(message.id.peerId)
                    }
                }
                let _ = transaction.addMessages(storeMessages, location: .UpperHistoryBlock)
                
                transaction.resetIncomingReadStates(readStates)
                
                for (peerId, pts) in channelStates {
                    if let _ = transaction.getPeerChatState(peerId) as? ChannelState {
                        // skip changing state
                    } else {
                        transaction.setPeerChatState(peerId, state: ChannelState(pts: pts, invalidatedPts: nil, synchronizedUntilMessageId: nil))
                    }
                }
                
                if remoteItemIds == resultingItemIds {
                    return .complete()
                } else {
                    var inputDialogPeers: [Api.InputDialogPeer] = []
                    for itemId in resultingItemIds {
                        switch itemId {
                            case let .peer(peerId):
                                if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                                    inputDialogPeers.append(Api.InputDialogPeer.inputDialogPeer(peer: inputPeer))
                                }
                        }
                    }
                    
                    return network.request(Api.functions.messages.reorderPinnedDialogs(flags: 1 << 0, folderId: groupId.rawValue, order: inputDialogPeers))
                    |> `catch` { _ -> Signal<Api.Bool, NoError> in
                        return .single(Api.Bool.boolFalse)
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return postbox.transaction { transaction -> Void in
                        }
                    }
                }
            }
            |> switchToLatest
        }
        |> switchToLatest
    }
}

private func synchronizePinnedSavedChats(transaction: Transaction, postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager, operation: SynchronizePinnedChatsOperation) -> Signal<Void, NoError> {
    return network.request(Api.functions.messages.getPinnedSavedDialogs())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.SavedDialogs?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { dialogs -> Signal<Void, NoError> in
        guard let dialogs = dialogs else {
            return .never()
        }
        
        let _ = dialogs
        
        /*return postbox.transaction { transaction -> Signal<Void, NoError> in
            var storeMessages: [StoreMessage] = []
            var remoteItemIds: [PeerId] = []
            
            let parsedPeers: AccumulatedPeers
            
            switch dialogs {
            case .savedDialogs(let dialogs, let messages, let chats, let users), .savedDialogs(_, let dialogs, let messages, let chats, let users):
                parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                
                loop: for dialog in dialogs {
                    switch dialog {
                    case let .savedDialog(_, peer, _):
                        remoteItemIds.append(peer.peerId)
                    }
                }
                
                for message in messages {
                    var peerIsForum = false
                    if let peerId = message.peerId, let peer = parsedPeers.get(peerId), peer.isForumOrMonoForum {
                        peerIsForum = true
                    }
                    if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                        storeMessages.append(storeMessage)
                    }
                }
            case .savedDialogsNotModified:
                parsedPeers = AccumulatedPeers(transaction: transaction, chats: [], users: [])
            }
            
            let resultingItemIds: [PeerId] = remoteItemIds
            
            return postbox.transaction { transaction -> Signal<Void, NoError> in
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                
                transaction.setPeerPinnedThreads(peerId: accountPeerId, threadIds: resultingItemIds.map { $0.toInt64() })
                
                let _ = transaction.addMessages(storeMessages, location: .UpperHistoryBlock)
                
                return .complete()
            }
            |> switchToLatest
        }
        |> switchToLatest*/
        
        return .complete()
    }
}

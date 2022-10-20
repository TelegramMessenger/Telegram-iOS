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

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: tagLocalIndex, { entry in
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

func managedSynchronizePinnedChatsOperations(postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedSynchronizePinnedChatsOperationsHelper>(value: ManagedSynchronizePinnedChatsOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: OperationLogTags.SynchronizePinnedChats, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizePinnedChatsOperation {
                            return synchronizePinnedChats(transaction: transaction, postbox: postbox, network: network, accountPeerId: accountPeerId, stateManager: stateManager, groupId: PeerGroupId(rawValue: Int32(entry.peerId.id._internalGetInt64Value())), operation: operation)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.transaction { transaction -> Void in
                    let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: entry.tagLocalIndex)
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
    |> retryRequest
    |> mapToSignal { dialogs -> Signal<Void, NoError> in
        var storeMessages: [StoreMessage] = []
        var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
        var channelStates: [PeerId: Int32] = [:]
        var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
        
        var remoteItemIds: [PinnedItemId] = []
        
        var peers: [Peer] = []
        var peerPresences: [PeerId: Api.User] = [:]
        
        switch dialogs {
            case let .peerDialogs(dialogs, messages, chats, users, _):
                for chat in chats {
                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                        peers.append(groupOrChannel)
                    }
                }
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    peerPresences[telegramUser.id] = user
                }
                
                loop: for dialog in dialogs {
                    let apiPeer: Api.Peer
                    let apiReadInboxMaxId: Int32
                    let apiReadOutboxMaxId: Int32
                    let apiTopMessage: Int32
                    let apiUnreadCount: Int32
                    let apiMarkedUnread: Bool
                    var apiChannelPts: Int32?
                    let apiNotificationSettings: Api.PeerNotifySettings
                    switch dialog {
                        case let .dialog(flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, _, _, peerNotificationSettings, pts, _, _):
                            apiPeer = peer
                            apiTopMessage = topMessage
                            apiReadInboxMaxId = readInboxMaxId
                            apiReadOutboxMaxId = readOutboxMaxId
                            apiUnreadCount = unreadCount
                            apiMarkedUnread = (flags & (1 << 3)) != 0
                            apiNotificationSettings = peerNotificationSettings
                            apiChannelPts = pts
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
                }
                
                for message in messages {
                    if let storeMessage = StoreMessage(apiMessage: message) {
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
            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                return updated
            })
            
            transaction.setPinnedItemIds(groupId: groupId, itemIds: resultingItemIds)
            
            updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
            
            transaction.updateCurrentPeerNotificationSettings(notificationSettings)
            
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
}

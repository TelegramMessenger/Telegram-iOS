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

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tagLocalIndex: Int32, _ f: @escaping (Modifier, PeerMergedOperationLogEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Signal<Void, NoError> in
        var result: PeerMergedOperationLogEntry?
        modifier.operationLogUpdateEntry(peerId: peerId, tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizePinnedChatsOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(modifier, result)
        } |> switchToLatest
}

func managedSynchronizePinnedChatsOperations(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
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
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tagLocalIndex: entry.tagLocalIndex, { modifier, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizePinnedChatsOperation {
                            return synchronizePinnedChats(modifier: modifier, postbox: postbox, network: network, stateManager: stateManager, operation: operation)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                    |> then(postbox.modify { modifier -> Void in
                        let _ = modifier.operationLogRemoveEntry(peerId: entry.peerId, tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: entry.tagLocalIndex)
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

private func synchronizePinnedChats(modifier: Modifier, postbox: Postbox, network: Network, stateManager: AccountStateManager, operation: SynchronizePinnedChatsOperation) -> Signal<Void, NoError> {
    let initialRemotePeerIds = operation.previousPeerIds
    let initialRemotePeerIdsWithoutSecretChats = initialRemotePeerIds.filter {
        $0.namespace != Namespaces.Peer.SecretChat
    }
    let localPeerIds = modifier.getPinnedPeerIds()
    let localPeerIdsWithoutSecretChats = localPeerIds.filter {
        $0.namespace != Namespaces.Peer.SecretChat
    }
    
    return network.request(Api.functions.messages.getPinnedDialogs())
        |> retryRequest
        |> mapToSignal { dialogs -> Signal<Void, NoError> in
            let dialogsChats: [Api.Chat]
            let dialogsUsers: [Api.User]
            
            var storeMessages: [StoreMessage] = []
            var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
            var chatStates: [PeerId: PeerChatState] = [:]
            var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
            
            var remotePeerIds: [PeerId] = []
            
            switch dialogs {
                case let .peerDialogs(dialogs, messages, chats, users, _):
                    dialogsChats = chats
                    dialogsUsers = users
                    
                    for dialog in dialogs {
                        let apiPeer: Api.Peer
                        let apiReadInboxMaxId: Int32
                        let apiReadOutboxMaxId: Int32
                        let apiTopMessage: Int32
                        let apiUnreadCount: Int32
                        var apiChannelPts: Int32?
                        let apiNotificationSettings: Api.PeerNotifySettings
                        switch dialog {
                            case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, peerNotificationSettings, pts, _):
                                apiPeer = peer
                                apiTopMessage = topMessage
                                apiReadInboxMaxId = readInboxMaxId
                                apiReadOutboxMaxId = readOutboxMaxId
                                apiUnreadCount = unreadCount
                                apiNotificationSettings = peerNotificationSettings
                                apiChannelPts = pts
                        }
                        
                        let peerId: PeerId
                        switch apiPeer {
                            case let .peerUser(userId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                            case let .peerChat(chatId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                            case let .peerChannel(channelId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        }
                        
                        remotePeerIds.append(peerId)
                        
                        if readStates[peerId] == nil {
                            readStates[peerId] = [:]
                        }
                        readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount)
                        
                        if let apiChannelPts = apiChannelPts {
                            chatStates[peerId] = ChannelState(pts: apiChannelPts, invalidatedPts: nil)
                        }
                        
                        notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                    }
                    
                    for message in messages {
                        if let storeMessage = StoreMessage(apiMessage: message) {
                            storeMessages.append(storeMessage)
                        }
                    }
            }
            
            var peers: [Peer] = []
            var peerPresences: [PeerId: PeerPresence] = [:]
            for chat in dialogsChats {
                if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                    peers.append(groupOrChannel)
                }
            }
            for user in dialogsUsers {
                let telegramUser = TelegramUser(user: user)
                peers.append(telegramUser)
                if let presence = TelegramUserPresence(apiUser: user) {
                    peerPresences[telegramUser.id] = presence
                }
            }
            
            let locallyRemovedFromRemotePeerIds = Set(initialRemotePeerIdsWithoutSecretChats).subtracting(Set(localPeerIdsWithoutSecretChats))
            let remotelyRemovedPeerIds = Set(initialRemotePeerIdsWithoutSecretChats).subtracting(Set(remotePeerIds))
            
            var resultingPeerIds = localPeerIds.filter { !remotelyRemovedPeerIds.contains($0) }
            resultingPeerIds.append(contentsOf: remotePeerIds.filter { !locallyRemovedFromRemotePeerIds.contains($0) && !resultingPeerIds.contains($0) })
            
            return postbox.modify { modifier -> Signal<Void, NoError> in
                updatePeers(modifier: modifier, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                
                modifier.setPinnedPeerIds(resultingPeerIds)
                
                modifier.updatePeerPresences(peerPresences)
                
                modifier.updateCurrentPeerNotificationSettings(notificationSettings)
                
                var allPeersWithMessages = Set<PeerId>()
                for message in storeMessages {
                    if !allPeersWithMessages.contains(message.id.peerId) {
                        allPeersWithMessages.insert(message.id.peerId)
                    }
                }
                let _ = modifier.addMessages(storeMessages, location: .UpperHistoryBlock)
                
                modifier.resetIncomingReadStates(readStates)
                
                for (peerId, chatState) in chatStates {
                    if let chatState = chatState as? ChannelState {
                        if let current = modifier.getPeerChatState(peerId) as? ChannelState {
                            // skip changing state
                        } else {
                            modifier.setPeerChatState(peerId, state: chatState)
                        }
                    } else {
                        modifier.setPeerChatState(peerId, state: chatState)
                    }
                }
                
                if remotePeerIds == resultingPeerIds {
                    return .complete()
                } else {
                    var inputPeers: [Api.InputPeer] = []
                    for peerId in resultingPeerIds {
                        if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                            inputPeers.append(inputPeer)
                        }
                    }
                    
                    return network.request(Api.functions.messages.reorderPinnedDialogs(flags: 1 << 0, order: inputPeers))
                        |> `catch` { _ -> Signal<Api.Bool, NoError> in
                            return .single(Api.Bool.boolFalse)
                        }
                        |> mapToSignal { result -> Signal<Void, NoError> in
                            return postbox.modify { modifier -> Void in
                            }
                        }
                }
            } |> switchToLatest
        }
}

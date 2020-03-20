import Foundation
import Postbox
import SwiftSignalKit
import SyncCore
import TelegramApi

private final class ManagedChatListHolesState {
    private var currentHole: (ChatListHolesEntry, Disposable)?
    private var currentPinnedIds: (Set<PeerId>, Disposable)?
    private var processedPinnedIds: Set<PeerId>?
    
    func clearDisposables() -> [Disposable] {
        if let (_, disposable) = self.currentHole {
            self.currentHole = nil
            return [disposable]
        } else {
            return []
        }
    }
    
    func update(entries: [ChatListHolesEntry], pinnedIds: Set<PeerId>) -> (removed: [Disposable], added: [ChatListHolesEntry: MetaDisposable], addedPinnedIds: (Set<PeerId>, MetaDisposable)?) {
        var removed: [Disposable] = []
        var added: [ChatListHolesEntry: MetaDisposable] = [:]
        var addedPinnedIds: (Set<PeerId>, MetaDisposable)?
        
        if self.processedPinnedIds == nil && !pinnedIds.isEmpty {
            self.processedPinnedIds = pinnedIds
            let disposable = MetaDisposable()
            self.currentPinnedIds = (pinnedIds, disposable)
            addedPinnedIds = (pinnedIds, disposable)
        }
        
        if let (entry, disposable) = self.currentHole {
            if !entries.contains(entry) {
                removed.append(disposable)
                self.currentHole = nil
            }
        }
        
        if self.currentHole == nil, let entry = entries.first {
            let disposable = MetaDisposable()
            self.currentHole = (entry, disposable)
            added[entry] = disposable
        }
        
        return (removed, added, addedPinnedIds)
    }
}

func managedChatListHoles(network: Network, postbox: Postbox, accountPeerId: PeerId) -> Signal<Void, NoError> {
    return Signal { _ in
        let state = Atomic(value: ManagedChatListHolesState())
        
        let topRootHoleKey: PostboxViewKey = .allChatListHoles(.root)
        let topArchiveHoleKey: PostboxViewKey = .allChatListHoles(Namespaces.PeerGroup.archive)
        let filtersKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.chatListFilters]))
        let combinedView = postbox.combinedView(keys: [topRootHoleKey, topArchiveHoleKey, filtersKey])
        
        let disposable = combineLatest(postbox.chatListHolesView(), combinedView).start(next: { view, combinedView in
            var entries = Array(view.entries).sorted(by: { lhs, rhs in
                return lhs.hole.index > rhs.hole.index
            })
            
            var pinnedIds = Set<PeerId>()
            
            if let preferencesView = combinedView.views[filtersKey] as? PreferencesView, let filtersState = preferencesView.values[PreferencesKeys.chatListFilters] as? ChatListFiltersState, !filtersState.filters.isEmpty {
                for filter in filtersState.filters {
                    pinnedIds.formUnion(filter.data.includePeers.pinnedPeers)
                }
                
                if let topRootHole = combinedView.views[topRootHoleKey] as? AllChatListHolesView, let hole = topRootHole.latestHole {
                    let entry = ChatListHolesEntry(groupId: .root, hole: hole)
                    if !entries.contains(entry) {
                        entries.append(entry)
                    }
                }
                if let topArchiveHole = combinedView.views[topArchiveHoleKey] as? AllChatListHolesView, let hole = topArchiveHole.latestHole {
                    if !view.entries.contains(ChatListHolesEntry(groupId: Namespaces.PeerGroup.archive, hole: hole)) {
                        let entry = ChatListHolesEntry(groupId: Namespaces.PeerGroup.archive, hole: hole)
                        if !entries.contains(entry) {
                            entries.append(entry)
                        }
                    }
                }
            }
            
            let (removed, added, addedPinnedIds) = state.with { state in
                return state.update(entries: entries, pinnedIds: pinnedIds)
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (entry, disposable) in added {
                disposable.set(fetchChatListHole(postbox: postbox, network: network, accountPeerId: accountPeerId, groupId: entry.groupId, hole: entry.hole).start())
            }
            
            if let (ids, disposable) = addedPinnedIds {
                let signal = postbox.transaction { transaction -> [Api.InputPeer] in
                    var peers: [Api.InputPeer] = []
                    for id in ids {
                        if let inputPeer = transaction.getPeer(id).flatMap(apiInputPeer) {
                            peers.append(inputPeer)
                        }
                    }
                    return peers
                }
                |> mapToSignal { inputPeers -> Signal<Never, NoError> in
                    return loadAndStorePeerChatInfos(accountPeerId: accountPeerId, postbox: postbox, network: network, peers: inputPeers)
                }
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
            for disposable in state.with({ state -> [Disposable] in
                state.clearDisposables()
            }) {
                disposable.dispose()
            }
        }
    }
}

private func loadAndStorePeerChatInfos(accountPeerId: PeerId, postbox: Postbox, network: Network, peers: [Api.InputPeer]) -> Signal<Never, NoError> {
    let signal = network.request(Api.functions.messages.getPeerDialogs(peers: peers.map(Api.InputDialogPeer.inputDialogPeer(peer:))))
    |> map(Optional.init)
        
    return signal
    |> `catch` { _ -> Signal<Api.messages.PeerDialogs?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        guard let result = result else {
            return .complete()
        }
        
        return postbox.transaction { transaction -> Void in
            var peers: [Peer] = []
            var peerPresences: [PeerId: PeerPresence] = [:]
            var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
            var channelStates: [PeerId: ChannelState] = [:]
            
            switch result {
            case let .peerDialogs(dialogs, messages, chats, users, _):
                for chat in chats {
                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                        peers.append(groupOrChannel)
                    }
                }
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    if let presence = TelegramUserPresence(apiUser: user) {
                        peerPresences[telegramUser.id] = presence
                    }
                }
                
                var topMessageIds = Set<MessageId>()
                
                for dialog in dialogs {
                    switch dialog {
                    case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, notifySettings, pts, _, folderId):
                        let peerId = peer.peerId
                        
                        if topMessage != 0 {
                            topMessageIds.insert(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: topMessage))
                        }
                        
                        var isExcludedFromChatList = false
                        for chat in chats {
                            if chat.peerId == peerId {
                                if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                    if let group = groupOrChannel as? TelegramGroup {
                                        if group.flags.contains(.deactivated) {
                                            isExcludedFromChatList = true
                                        } else {
                                            switch group.membership {
                                            case .Member:
                                                break
                                            default:
                                                isExcludedFromChatList = true
                                            }
                                        }
                                    } else if let channel = groupOrChannel as? TelegramChannel {
                                        switch channel.participationStatus {
                                        case .member:
                                            break
                                        default:
                                            isExcludedFromChatList = true
                                        }
                                    }
                                }
                                break
                            }
                        }
                        
                        if !isExcludedFromChatList {
                            let groupId = PeerGroupId(rawValue: folderId ?? 0)
                            let currentInclusion = transaction.getPeerChatListInclusion(peerId)
                            var currentPinningIndex: UInt16?
                            var currentMinTimestamp: Int32?
                            switch currentInclusion {
                                case let .ifHasMessagesOrOneOf(currentGroupId, pinningIndex, minTimestamp):
                                    if currentGroupId == groupId {
                                        currentPinningIndex = pinningIndex
                                    }
                                    currentMinTimestamp = minTimestamp
                                default:
                                    break
                            }
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: currentPinningIndex, minTimestamp: currentMinTimestamp))
                        }
                        
                        notificationSettings[peer.peerId] = TelegramPeerNotificationSettings(apiSettings: notifySettings)
                        
                        transaction.resetIncomingReadStates([peerId: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: readInboxMaxId, maxOutgoingReadId: readOutboxMaxId, maxKnownId: topMessage, count: unreadCount, markedUnread: false)]])
                        
                        transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, maxId: topMessage)
                        
                        if let pts = pts {
                            let channelState = ChannelState(pts: pts, invalidatedPts: pts)
                            transaction.setPeerChatState(peerId, state: channelState)
                            channelStates[peer.peerId] = channelState
                        }
                    case .dialogFolder:
                        assertionFailure()
                        break
                    }
                }
                
                var storeMessages: [StoreMessage] = []
                for message in messages {
                    if let storeMessage = StoreMessage(apiMessage: message) {
                        var updatedStoreMessage = storeMessage
                        if case let .Id(id) = storeMessage.id {
                            if let channelState = channelStates[id.peerId] {
                                var updatedAttributes = storeMessage.attributes
                                updatedAttributes.append(ChannelMessageStateVersionAttribute(pts: channelState.pts))
                                updatedStoreMessage = updatedStoreMessage.withUpdatedAttributes(updatedAttributes)
                            }
                        }
                        storeMessages.append(updatedStoreMessage)
                    }
                }
                
                for message in storeMessages {
                    if case let .Id(id) = message.id {
                        let _ = transaction.addMessages([message], location: topMessageIds.contains(id) ? .UpperHistoryBlock : .Random)
                    }
                }
            }
            
            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                return updated
            })
            
            updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
            
            transaction.updateCurrentPeerNotificationSettings(notificationSettings)
        }
        |> ignoreValues
    }
}

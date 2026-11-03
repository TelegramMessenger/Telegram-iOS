import Foundation
import UIKit
import Display
import SwiftSignalKit
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import TelegramUIPreferences
import TelegramCore

public func chatListFilterItems(context: AccountContext) -> Signal<(Int, [(ChatListFilter, Int, Bool)]), NoError> {
    // A folder never names a secret chat. ChatListFilterPredicate resolves a secret chat's identity
    // to its associated cloud user, so including or excluding the user silently does the same to the
    // secret chat; and a folder can pin one, which ChatListFilterIncludePeers deliberately keeps out
    // of `peers`. Neither shows up in the unread aggregates, so resolve the association first and
    // feed the secret chats through the same per-peer corrections.
    //
    // The association is sampled once per filter change rather than observed: a secret chat created
    // afterwards is not reflected in the badge until the filters change again or the app restarts.
    return context.engine.peers.updatedChatListFilters()
    |> distinctUntilChanged
    |> mapToSignal { filters -> Signal<([ChatListFilter], [EnginePeer.Id: [EnginePeer.Id]], [EnginePeer.Id: EnginePeer.Id]), NoError> in
        var folderPeerIds = Set<EnginePeer.Id>()
        for case let .filter(_, _, _, data) in filters {
            folderPeerIds.formUnion(data.includePeers.peers)
            folderPeerIds.formUnion(data.includePeers.pinnedPeers)
            folderPeerIds.formUnion(data.excludePeers)
        }
        return context.account.postbox.transaction { transaction -> ([ChatListFilter], [EnginePeer.Id: [EnginePeer.Id]], [EnginePeer.Id: EnginePeer.Id]) in
            var secretChatsByUserId: [EnginePeer.Id: [EnginePeer.Id]] = [:]
            var userIdBySecretChatId: [EnginePeer.Id: EnginePeer.Id] = [:]
            for peerId in folderPeerIds {
                if peerId.namespace == Namespaces.Peer.CloudUser {
                    let secretChatIds = transaction.getAssociatedPeerIds(peerId).filter { $0.namespace == Namespaces.Peer.SecretChat }
                    if !secretChatIds.isEmpty {
                        secretChatsByUserId[peerId] = secretChatIds.sorted()
                        for secretChatId in secretChatIds {
                            userIdBySecretChatId[secretChatId] = peerId
                        }
                    }
                } else if peerId.namespace == Namespaces.Peer.SecretChat {
                    if let associatedPeerId = transaction.getPeer(peerId)?.associatedPeerId {
                        userIdBySecretChatId[peerId] = associatedPeerId
                    }
                }
            }
            return (filters, secretChatsByUserId, userIdBySecretChatId)
        }
    }
    |> mapToSignal { filters, secretChatsByUserId, userIdBySecretChatId -> Signal<(Int, [(ChatListFilter, Int, Bool)]), NoError> in
        // Each folder peer followed by the secret chats it carries. A no-op, and allocation-free,
        // for an account with no secret chats in any folder.
        func expand(_ peerIds: [EnginePeer.Id]) -> [EnginePeer.Id] {
            if secretChatsByUserId.isEmpty {
                return peerIds
            }
            var result: [EnginePeer.Id] = []
            var seen = Set<EnginePeer.Id>()
            for peerId in peerIds {
                if seen.insert(peerId).inserted {
                    result.append(peerId)
                }
                for secretChatId in secretChatsByUserId[peerId] ?? [] {
                    if seen.insert(secretChatId).inserted {
                        result.append(secretChatId)
                    }
                }
            }
            return result
        }
        
        var unreadCountItems: [EngineRawUnreadMessageCountsItem] = []
        unreadCountItems.append(.totalInGroup(.root))
        var additionalPeerIds = Set<EnginePeer.Id>()
        var additionalGroupIds = Set<EnginePeerGroupId>()
        for case let .filter(_, _, _, data) in filters {
            additionalPeerIds.formUnion(expand(data.includePeers.peers))
            additionalPeerIds.formUnion(expand(data.includePeers.pinnedPeers))
            additionalPeerIds.formUnion(expand(data.excludePeers))
            if !data.excludeArchived {
                additionalGroupIds.insert(Namespaces.PeerGroup.archive)
            }
        }
        // A secret chat carries no notification settings of its own; they live on the cloud user,
        // so its basicPeer view has to be available even when the user is not a folder peer.
        additionalPeerIds.formUnion(userIdBySecretChatId.values)
        if !additionalPeerIds.isEmpty {
            for peerId in additionalPeerIds {
                unreadCountItems.append(.peer(id: peerId, handleThreads: true))
            }
        }
        for groupId in additionalGroupIds {
            unreadCountItems.append(.totalInGroup(groupId))
        }
        
        let globalNotificationsKey: EngineRawPostboxViewKey = .preferences(keys: Set([PreferencesKeys.globalNotifications]))
        let unreadKey: EngineRawPostboxViewKey = .unreadCounts(items: unreadCountItems)
        var keys: [EngineRawPostboxViewKey] = []
        keys.append(globalNotificationsKey)
        keys.append(unreadKey)
        for peerId in additionalPeerIds {
            keys.append(.basicPeer(peerId))
        }
        
        return context.account.postbox.combinedView(keys: keys)
        |> map { view -> (Int, [(ChatListFilter, Int, Bool)]) in
            guard let unreadCounts = view.views[unreadKey] as? EngineRawUnreadMessageCountsView else {
                return (0, [])
            }
            
            var globalNotificationSettings: GlobalNotificationSettingsSet
            if let settingsView = view.views[globalNotificationsKey] as? EngineRawPreferencesView, let settings = settingsView.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
                globalNotificationSettings = settings.effective
            } else {
                globalNotificationSettings = GlobalNotificationSettings.defaultSettings.effective
            }
            
            var result: [(ChatListFilter, Int, Bool)] = []
            
            var peerTagAndCount: [EnginePeer.Id: (EnginePeerSummaryCounterTags, Int, Bool, EnginePeerGroupId?, Bool)] = [:]
            
            var totalStates: [EnginePeerGroupId: EngineChatListTotalUnreadState] = [:]
            for entry in unreadCounts.entries {
                switch entry {
                case let .total(_, state):
                    totalStates[.root] = state
                case let .totalInGroup(groupId, state):
                    totalStates[groupId] = state
                case let .peer(peerId, state):
                    if let state = state, state.isUnread {
                        if let peerView = view.views[.basicPeer(peerId)] as? EngineRawBasicPeerView, let peer = peerView.peer {
                            // A secret chat carries neither contact status nor notification settings
                            // of its own; both live on the associated cloud user. ChatListIndexTable
                            // resolves them the same way when it files the chat into a counter
                            // bucket, and the correction below is only correct if it agrees.
                            let settingsView: EngineRawBasicPeerView
                            if let userId = userIdBySecretChatId[peerId], let userView = view.views[.basicPeer(userId)] as? EngineRawBasicPeerView {
                                settingsView = userView
                            } else {
                                settingsView = peerView
                            }
                            
                            let tag = context.account.postbox.seedConfiguration.peerSummaryCounterTags(peer, settingsView.isContact)
                            
                            var peerCount = Int(state.count)
                            if state.isUnread {
                                peerCount = max(1, peerCount)
                            }
                            
                            var isMuted = false
                            if let notificationSettings = settingsView.notificationSettings as? TelegramPeerNotificationSettings {
                                if case .muted = notificationSettings.muteState {
                                    isMuted = true
                                } else if case .default = notificationSettings.muteState {
                                    if let peer = settingsView.peer {
                                        if peer is TelegramUser {
                                            isMuted = !globalNotificationSettings.privateChats.enabled
                                        } else if peer is TelegramGroup {
                                            isMuted = !globalNotificationSettings.groupChats.enabled
                                        } else if let channel = peer as? TelegramChannel {
                                            switch channel.info {
                                            case .group:
                                                isMuted = !globalNotificationSettings.groupChats.enabled
                                            case .broadcast:
                                                isMuted = !globalNotificationSettings.channels.enabled
                                            }
                                        }
                                    }
                                }
                            }
                            if isMuted {
                                peerTagAndCount[peerId] = (tag, peerCount, false, peerView.groupId, true)
                            } else {
                                peerTagAndCount[peerId] = (tag, peerCount, true, peerView.groupId, false)
                            }
                        }
                    }
                }
            }
            
            let totalBadge = 0
            
            for filter in filters {
                var count = 0
                var unmutedUnreadCount = 0
                if case let .filter(_, _, _, data) = filter {
                    var tags: [EnginePeerSummaryCounterTags] = []
                    if data.categories.contains(.contacts) {
                        tags.append(.contact)
                    }
                    if data.categories.contains(.nonContacts) {
                        tags.append(.nonContact)
                    }
                    if data.categories.contains(.groups) {
                        tags.append(.group)
                    }
                    if data.categories.contains(.bots) {
                        tags.append(.bot)
                    }
                    if data.categories.contains(.channels) {
                        tags.append(.channel)
                    }
                    
                    if let totalState = totalStates[.root] {
                        for tag in tags {
                            if data.excludeMuted {
                                if let value = totalState.filteredCounters[tag] {
                                    if value.chatCount != 0 {
                                        count += Int(value.chatCount)
                                        unmutedUnreadCount += Int(value.chatCount)
                                    }
                                }
                            } else {
                                if let value = totalState.absoluteCounters[tag] {
                                    count += Int(value.chatCount)
                                }
                                if let value = totalState.filteredCounters[tag] {
                                    if value.chatCount != 0 {
                                        unmutedUnreadCount += Int(value.chatCount)
                                    }
                                }
                            }
                        }
                    }
                    if !data.excludeArchived {
                        if let totalState = totalStates[Namespaces.PeerGroup.archive] {
                            for tag in tags {
                                if data.excludeMuted {
                                    if let value = totalState.filteredCounters[tag] {
                                        if value.chatCount != 0 {
                                            count += Int(value.chatCount)
                                            unmutedUnreadCount += Int(value.chatCount)
                                        }
                                    }
                                } else {
                                    if let value = totalState.absoluteCounters[tag] {
                                        count += Int(value.chatCount)
                                    }
                                    if let value = totalState.filteredCounters[tag] {
                                        if value.chatCount != 0 {
                                            unmutedUnreadCount += Int(value.chatCount)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    for peerId in expand(data.includePeers.peers + data.includePeers.pinnedPeers) {
                        if let (tag, peerCount, hasUnmuted, groupIdValue, isMuted) = peerTagAndCount[peerId], peerCount != 0, let groupId = groupIdValue {
                            var matches = true
                            if tags.contains(tag) {
                                if isMuted && data.excludeMuted {
                                } else {
                                    matches = false
                                }
                            }
                            if matches {
                                let matchesGroup: Bool
                                switch groupId {
                                case .root:
                                    matchesGroup = true
                                case .group:
                                    if groupId == Namespaces.PeerGroup.archive {
                                        matchesGroup = !data.excludeArchived
                                    } else {
                                        matchesGroup = false
                                    }
                                }
                                if matchesGroup && peerCount != 0 {
                                    count += 1
                                    if hasUnmuted {
                                        unmutedUnreadCount += 1
                                    }
                                }
                            }
                        }
                    }
                    for peerId in expand(data.excludePeers) {
                        if let (tag, peerCount, _, groupIdValue, isMuted) = peerTagAndCount[peerId], peerCount != 0, let groupId = groupIdValue {
                            var matches = false
                            if tags.contains(tag) {
                                matches = true
                                if isMuted && data.excludeMuted {
                                    matches = false
                                }
                            }
                            
                            if matches {
                                let matchesGroup: Bool
                                switch groupId {
                                case .root:
                                    matchesGroup = true
                                case .group:
                                    if groupId == Namespaces.PeerGroup.archive {
                                        matchesGroup = !data.excludeArchived
                                    } else {
                                        matchesGroup = false
                                    }
                                }
                                if matchesGroup && peerCount != 0 {
                                    count -= 1
                                    if !isMuted {
                                        unmutedUnreadCount -= 1
                                    }
                                }
                            }
                        }
                    }
                }
                result.append((filter, max(0, count), unmutedUnreadCount > 0))
            }
            
            return (totalBadge, result)
        }
    }
}

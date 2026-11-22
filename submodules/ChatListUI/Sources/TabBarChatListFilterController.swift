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
    // The folder users' secret chats are observed (`associatedPeerIds`), so one created later is picked up in
    // the transaction that stores it. A secret chat a folder names keeps the user it was created with.
    return context.engine.peers.updatedChatListFilters()
    |> distinctUntilChanged
    |> mapToSignal { filters -> Signal<([ChatListFilter], ChatListFilterBadgeSecretChats), NoError> in
        var folderUserIds = Set<EnginePeer.Id>()
        var folderSecretChatIds = Set<EnginePeer.Id>()
        for case let .filter(_, _, _, data) in filters {
            for peerId in data.includePeers.peers + data.includePeers.pinnedPeers + data.excludePeers {
                if peerId.namespace == Namespaces.Peer.CloudUser {
                    folderUserIds.insert(peerId)
                } else if peerId.namespace == Namespaces.Peer.SecretChat {
                    folderSecretChatIds.insert(peerId)
                }
            }
        }
        let userIdsOfFolderSecretChats: Signal<[EnginePeer.Id: EnginePeer.Id], NoError> = context.account.postbox.transaction { transaction -> [EnginePeer.Id: EnginePeer.Id] in
            var result: [EnginePeer.Id: EnginePeer.Id] = [:]
            for peerId in folderSecretChatIds {
                if let associatedPeerId = transaction.getPeer(peerId)?.associatedPeerId {
                    result[peerId] = associatedPeerId
                }
            }
            return result
        }
        let associatedPeerIdsKey: EngineRawPostboxViewKey = .associatedPeerIds(peerIds: folderUserIds)
        let associatedPeerIds: Signal<[EnginePeer.Id: Set<EnginePeer.Id>], NoError> = context.account.postbox.combinedView(keys: [associatedPeerIdsKey])
        |> map { view -> [EnginePeer.Id: Set<EnginePeer.Id>] in
            return (view.views[associatedPeerIdsKey] as? EngineRawAssociatedPeerIdsView)?.associatedPeerIds ?? [:]
        }
        |> distinctUntilChanged
        return combineLatest(userIdsOfFolderSecretChats, associatedPeerIds)
        |> map { userIdsOfFolderSecretChats, associatedPeerIds -> ([ChatListFilter], ChatListFilterBadgeSecretChats) in
            return (filters, ChatListFilterBadgeSecretChats(userIds: folderUserIds, associatedPeerIds: associatedPeerIds, userIdsOfFolderSecretChats: userIdsOfFolderSecretChats))
        }
    }
    |> mapToSignal { filters, secretChats -> Signal<(Int, [(ChatListFilter, Int, Bool)]), NoError> in
        let secretChatsByUserId = secretChats.secretChatsByUserId
        let userIdBySecretChatId = secretChats.userIdBySecretChatId
        
        func expand(_ peerIds: [EnginePeer.Id]) -> [EnginePeer.Id] {
            return chatListFilterBadgePeerIds(peerIds, secretChatsByUserId: secretChatsByUserId)
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
        let associatedPeerIdsKey: EngineRawPostboxViewKey = .associatedPeerIds(peerIds: secretChats.userIds)
        var keys: [EngineRawPostboxViewKey] = []
        keys.append(globalNotificationsKey)
        keys.append(unreadKey)
        keys.append(associatedPeerIdsKey)
        for peerId in additionalPeerIds {
            keys.append(.basicPeer(peerId))
        }
        
        return context.account.postbox.combinedView(keys: keys)
        |> filter { view -> Bool in
            // In the transaction that stores a folder user's new secret chat, the totals can already count it while
            // these keys do not observe it yet. The stage above restarts this one with them; this value would be wrong.
            let associatedPeerIds = (view.views[associatedPeerIdsKey] as? EngineRawAssociatedPeerIdsView)?.associatedPeerIds ?? [:]
            return associatedPeerIds == secretChats.associatedPeerIds
        }
        |> map { view -> (Int, [(ChatListFilter, Int, Bool)]) in
            guard let unreadCounts = view.views[unreadKey] as? EngineRawUnreadMessageCountsView else {
                return (0, [])
            }
            
            let globalNotificationSettings: GlobalNotificationSettings
            if let settingsView = view.views[globalNotificationsKey] as? EngineRawPreferencesView, let settings = settingsView.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
                globalNotificationSettings = settings
            } else {
                globalNotificationSettings = GlobalNotificationSettings.defaultSettings
            }
            let globalNotificationSettingsAccessor = globalNotificationSettings.postboxAccessor
            
            var result: [(ChatListFilter, Int, Bool)] = []
            
            var unreadChats: [EnginePeer.Id: ChatListFilterBadgeChat] = [:]
            
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
                            
                            // Muted as the counters resolve it (`resolvedIsRemovedFromTotalUnreadCount`): the default
                            // comes from the chat's own kind, and a chat without settings takes the default.
                            let isMutedByDefault = !globalNotificationSettingsAccessor.defaultIncludePeer(peer)
                            let isMuted: Bool
                            if let notificationSettings = settingsView.notificationSettings as? TelegramPeerNotificationSettings {
                                isMuted = notificationSettings.isRemovedFromTotalUnreadCount(default: isMutedByDefault)
                            } else {
                                isMuted = isMutedByDefault
                            }
                            if let groupId = peerView.groupId {
                                unreadChats[peerId] = ChatListFilterBadgeChat(tag: tag, groupId: groupId, isMuted: isMuted)
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
                    let tags = chatListFilterBadgeCategoryTags(data.categories)
                    
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
                    let correction = chatListFilterBadgeCorrection(data: data, unreadChats: unreadChats, secretChatsByUserId: secretChatsByUserId, userIdBySecretChatId: userIdBySecretChatId)
                    count += correction.count
                    unmutedUnreadCount += correction.unmuted
                }
                result.append((filter, max(0, count), unmutedUnreadCount > 0))
            }
            
            return (totalBadge, result)
        }
    }
}

// Each folder peer followed by the secret chats it carries, each named once. The badge adds one per
// listed unread chat, so a duplicate counts a chat twice: a chat pinned in a folder is in both
// `includePeers.peers` and `includePeers.pinnedPeers`.
func chatListFilterBadgePeerIds(_ peerIds: [EnginePeer.Id], secretChatsByUserId: [EnginePeer.Id: [EnginePeer.Id]]) -> [EnginePeer.Id] {
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

/// The secret chats of the folders' users, and the user of each of those and of each secret chat the folders name.
struct ChatListFilterBadgeSecretChats: Equatable {
    /// The users the folders name, whose associated peers are observed.
    let userIds: Set<EnginePeer.Id>
    /// As the `associatedPeerIds` view of `userIds` reports them.
    let associatedPeerIds: [EnginePeer.Id: Set<EnginePeer.Id>]
    let secretChatsByUserId: [EnginePeer.Id: [EnginePeer.Id]]
    let userIdBySecretChatId: [EnginePeer.Id: EnginePeer.Id]
    
    init(userIds: Set<EnginePeer.Id>, associatedPeerIds: [EnginePeer.Id: Set<EnginePeer.Id>], userIdsOfFolderSecretChats: [EnginePeer.Id: EnginePeer.Id]) {
        self.userIds = userIds
        self.associatedPeerIds = associatedPeerIds
        var secretChatsByUserId: [EnginePeer.Id: [EnginePeer.Id]] = [:]
        var userIdBySecretChatId = userIdsOfFolderSecretChats
        for (userId, peerIds) in associatedPeerIds {
            let secretChatIds = peerIds.filter { $0.namespace == Namespaces.Peer.SecretChat }.sorted()
            if !secretChatIds.isEmpty {
                secretChatsByUserId[userId] = secretChatIds
                for secretChatId in secretChatIds {
                    userIdBySecretChatId[secretChatId] = userId
                }
            }
        }
        self.secretChatsByUserId = secretChatsByUserId
        self.userIdBySecretChatId = userIdBySecretChatId
    }
}

/// An unread chat as a folder's badge reads it.
struct ChatListFilterBadgeChat: Equatable {
    var tag: EnginePeerSummaryCounterTags
    var groupId: EnginePeerGroupId
    var isMuted: Bool
}

func chatListFilterBadgeCategoryTags(_ categories: ChatListFilterPeerCategories) -> [EnginePeerSummaryCounterTags] {
    var tags: [EnginePeerSummaryCounterTags] = []
    if categories.contains(.contacts) {
        tags.append(.contact)
    }
    if categories.contains(.nonContacts) {
        tags.append(.nonContact)
    }
    if categories.contains(.groups) {
        tags.append(.group)
    }
    if categories.contains(.bots) {
        tags.append(.bot)
    }
    if categories.contains(.channels) {
        tags.append(.channel)
    }
    return tags
}

/// What a folder's badge adds to its categories' unread totals for the chats the folder names, so that it counts
/// exactly the unread chats the folder's list shows (`count`), and of those the unmuted ones (`unmuted`).
///
/// The list's rules, which this mirrors (`chatListFilterPredicate`, `ChatListFilterPredicate.includes` and the pinned
/// space of a filtered `ChatListView`): a pinned chat is shown from any group whatever the folder excludes. Pinned chats
/// leave the folder's include and exclude lists, and every other chat is shown only from the groups the folder lists:
/// never when its identity is excluded, always when it is included, else by its category. A secret chat's identity is its
/// user's, but pinning is by the chat's own id. The totals count a chat when its group is listed and its category is in
/// the folder, and with Exclude Muted only when it is unmuted.
///
/// Two differences come from the totals and stay for chats the folder does not name: a community is counted as a
/// non-contact while the list files it under groups, and with Exclude Muted the list keeps a muted chat with an unseen
/// mention, which no total counts.
func chatListFilterBadgeCorrection(data: ChatListFilterData, unreadChats: [EnginePeer.Id: ChatListFilterBadgeChat], secretChatsByUserId: [EnginePeer.Id: [EnginePeer.Id]], userIdBySecretChatId: [EnginePeer.Id: EnginePeer.Id]) -> (count: Int, unmuted: Int) {
    let tags = chatListFilterBadgeCategoryTags(data.categories)
    let pinnedPeerIds = Set(data.includePeers.pinnedPeers)
    let includePeerIds = Set(data.includePeers.peers).subtracting(pinnedPeerIds)
    let excludePeerIds = Set(data.excludePeers).subtracting(pinnedPeerIds)
    
    var count = 0
    var unmuted = 0
    for peerId in chatListFilterBadgePeerIds(data.includePeers.peers + data.includePeers.pinnedPeers + data.excludePeers, secretChatsByUserId: secretChatsByUserId) {
        guard let chat = unreadChats[peerId] else {
            continue
        }
        let isGroupListed: Bool
        switch chat.groupId {
        case .root:
            isGroupListed = true
        case .group:
            isGroupListed = chat.groupId == Namespaces.PeerGroup.archive && !data.excludeArchived
        }
        let isInCategories = isGroupListed && tags.contains(chat.tag)
        let isCountedByTotals = isInCategories && !(chat.isMuted && data.excludeMuted)
        let isCountedByUnmutedTotals = isInCategories && !chat.isMuted
        
        let identity = userIdBySecretChatId[peerId] ?? peerId
        let isShown: Bool
        if pinnedPeerIds.contains(peerId) {
            isShown = true
        } else if !isGroupListed || excludePeerIds.contains(identity) {
            isShown = false
        } else if includePeerIds.contains(identity) {
            isShown = true
        } else {
            isShown = isCountedByTotals
        }
        
        count += (isShown ? 1 : 0) - (isCountedByTotals ? 1 : 0)
        unmuted += (isShown && !chat.isMuted ? 1 : 0) - (isCountedByUnmutedTotals ? 1 : 0)
    }
    return (count, unmuted)
}

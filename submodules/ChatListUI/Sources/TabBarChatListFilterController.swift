import Foundation
import UIKit
import Display
import SwiftSignalKit
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import SyncCore
import Postbox
import TelegramUIPreferences
import TelegramCore

func chatListFilterItems(context: AccountContext) -> Signal<(Int, [(ChatListFilter, Int, Bool)]), NoError> {
    return updatedChatListFilters(postbox: context.account.postbox)
    |> distinctUntilChanged
    |> mapToSignal { filters -> Signal<(Int, [(ChatListFilter, Int, Bool)]), NoError> in
        var unreadCountItems: [UnreadMessageCountsItem] = []
        unreadCountItems.append(.totalInGroup(.root))
        var additionalPeerIds = Set<PeerId>()
        var additionalGroupIds = Set<PeerGroupId>()
        for filter in filters {
            additionalPeerIds.formUnion(filter.data.includePeers)
            additionalPeerIds.formUnion(filter.data.excludePeers)
            if !filter.data.excludeArchived {
                additionalGroupIds.insert(Namespaces.PeerGroup.archive)
            }
        }
        if !additionalPeerIds.isEmpty {
            for peerId in additionalPeerIds {
                unreadCountItems.append(.peer(peerId))
            }
        }
        for groupId in additionalGroupIds {
            unreadCountItems.append(.totalInGroup(groupId))
        }
        let unreadKey: PostboxViewKey = .unreadCounts(items: unreadCountItems)
        var keys: [PostboxViewKey] = []
        keys.append(unreadKey)
        for peerId in additionalPeerIds {
            keys.append(.basicPeer(peerId))
        }
        
        return combineLatest(queue: context.account.postbox.queue,
            context.account.postbox.combinedView(keys: keys),
            Signal<Bool, NoError>.single(true)
        )
        |> map { view, _ -> (Int, [(ChatListFilter, Int, Bool)]) in
            guard let unreadCounts = view.views[unreadKey] as? UnreadMessageCountsView else {
                return (0, [])
            }
            
            var result: [(ChatListFilter, Int, Bool)] = []
            
            var peerTagAndCount: [PeerId: (PeerSummaryCounterTags, Int, Bool)] = [:]
            
            var totalStates: [PeerGroupId: ChatListTotalUnreadState] = [:]
            for entry in unreadCounts.entries {
                switch entry {
                case let .total(_, state):
                    totalStates[.root] = state
                case let .totalInGroup(groupId, state):
                    totalStates[groupId] = state
                case let .peer(peerId, state):
                    if let state = state, state.isUnread {
                        if let peerView = view.views[.basicPeer(peerId)] as? BasicPeerView, let peer = peerView.peer {
                            let tag = context.account.postbox.seedConfiguration.peerSummaryCounterTags(peer, peerView.isContact)
                            
                            var peerCount = Int(state.count)
                            if state.isUnread {
                                peerCount = max(1, peerCount)
                            }
                            
                            if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings, case .muted = notificationSettings.muteState {
                                peerTagAndCount[peerId] = (tag, peerCount, false)
                            } else {
                                peerTagAndCount[peerId] = (tag, peerCount, true)
                            }
                        }
                    }
                }
            }
            
            let totalBadge = 0
            
            for filter in filters {
                var tags: [PeerSummaryCounterTags] = []
                if filter.data.categories.contains(.contacts) {
                    tags.append(.contact)
                }
                if filter.data.categories.contains(.nonContacts) {
                    tags.append(.nonContact)
                }
                if filter.data.categories.contains(.groups) {
                    tags.append(.group)
                }
                if filter.data.categories.contains(.bots) {
                    tags.append(.bot)
                }
                if filter.data.categories.contains(.channels) {
                    tags.append(.channel)
                }
                
                var count = 0
                var hasUnmutedUnread = false
                if let totalState = totalStates[.root] {
                    for tag in tags {
                        if filter.data.excludeMuted {
                            if let value = totalState.filteredCounters[tag] {
                                if value.chatCount != 0 {
                                    count += Int(value.chatCount)
                                    hasUnmutedUnread = true
                                }
                            }
                        } else {
                            if let value = totalState.absoluteCounters[tag] {
                                count += Int(value.chatCount)
                            }
                            if let value = totalState.filteredCounters[tag] {
                                if value.chatCount != 0 {
                                    hasUnmutedUnread = true
                                }
                            }
                        }
                    }
                }
                if !filter.data.excludeArchived {
                    if let totalState = totalStates[Namespaces.PeerGroup.archive] {
                        for tag in tags {
                            if filter.data.excludeMuted {
                                if let value = totalState.filteredCounters[tag] {
                                    if value.chatCount != 0 {
                                        count += Int(value.chatCount)
                                        hasUnmutedUnread = true
                                    }
                                }
                            } else {
                                if let value = totalState.absoluteCounters[tag] {
                                    count += Int(value.chatCount)
                                }
                                if let value = totalState.filteredCounters[tag] {
                                    if value.chatCount != 0 {
                                        hasUnmutedUnread = true
                                    }
                                }
                            }
                        }
                    }
                }
                for peerId in filter.data.includePeers {
                    if let (tag, peerCount, hasUnmuted) = peerTagAndCount[peerId] {
                        if !tags.contains(tag) {
                            if peerCount != 0 {
                                count += 1
                                if hasUnmuted {
                                    hasUnmutedUnread = true
                                }
                            }
                        }
                    }
                }
                for peerId in filter.data.excludePeers {
                    if let (tag, peerCount, _) = peerTagAndCount[peerId] {
                        if tags.contains(tag) {
                            if peerCount != 0 {
                                count -= 1
                            }
                        }
                    }
                }
                result.append((filter, count, hasUnmutedUnread))
            }
            
            return (totalBadge, result)
        }
    }
}

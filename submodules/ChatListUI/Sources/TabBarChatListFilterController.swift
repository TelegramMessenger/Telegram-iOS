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

func chatListFilterItems(context: AccountContext) -> Signal<(Int, [(ChatListFilter, Int)]), NoError> {
    return updatedChatListFilters(postbox: context.account.postbox)
    |> distinctUntilChanged
    |> mapToSignal { filters -> Signal<(Int, [(ChatListFilter, Int)]), NoError> in
        var unreadCountItems: [UnreadMessageCountsItem] = []
        unreadCountItems.append(.total(nil))
        var additionalPeerIds = Set<PeerId>()
        for filter in filters {
            additionalPeerIds.formUnion(filter.data.includePeers)
        }
        if !additionalPeerIds.isEmpty {
            for peerId in additionalPeerIds {
                unreadCountItems.append(.peer(peerId))
            }
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
        |> map { view, _ -> (Int, [(ChatListFilter, Int)]) in
            guard let unreadCounts = view.views[unreadKey] as? UnreadMessageCountsView else {
                return (0, [])
            }
            
            var result: [(ChatListFilter, Int)] = []
            
            var peerTagAndCount: [PeerId: (PeerSummaryCounterTags, Int)] = [:]
            
            var totalState: ChatListTotalUnreadState?
            for entry in unreadCounts.entries {
                switch entry {
                case let .total(_, totalStateValue):
                    totalState = totalStateValue
                case let .totalInGroup(groupId, totalGroupState):
                    break
                case let .peer(peerId, state):
                    if let state = state, state.isUnread {
                        if let peerView = view.views[.basicPeer(peerId)] as? BasicPeerView, let peer = peerView.peer {
                            let tag = context.account.postbox.seedConfiguration.peerSummaryCounterTags(peer, peerView.isContact)
                            if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings, case .muted = notificationSettings.muteState {
                                peerTagAndCount[peerId] = (tag, 0)
                            } else {
                                var peerCount = Int(state.count)
                                if state.isUnread {
                                    peerCount = max(1, peerCount)
                                }
                                peerTagAndCount[peerId] = (tag, peerCount)
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
                if let totalState = totalState {
                    for tag in tags {
                        if let value = totalState.filteredCounters[tag] {
                            count += Int(value.chatCount)
                        }
                    }
                }
                for peerId in filter.data.includePeers {
                    if let (tag, peerCount) = peerTagAndCount[peerId] {
                        if !tags.contains(tag) {
                            if peerCount != 0 {
                                count += 1
                            }
                        }
                    }
                }
                result.append((filter, count))
            }
            
            return (totalBadge, result)
        }
    }
}

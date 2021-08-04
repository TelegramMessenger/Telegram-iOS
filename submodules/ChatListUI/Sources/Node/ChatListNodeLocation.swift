import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import TelegramUIPreferences

enum ChatListNodeLocation: Equatable {
    case initial(count: Int, filter: ChatListFilter?)
    case navigation(index: ChatListIndex, filter: ChatListFilter?)
    case scroll(index: ChatListIndex, sourceIndex: ChatListIndex, scrollPosition: ListViewScrollPosition, animated: Bool, filter: ChatListFilter?)
    
    var filter: ChatListFilter? {
        switch self {
        case let .initial(_, filter):
            return filter
        case let .navigation(_, filter):
            return filter
        case let .scroll(_, _, _, _, filter):
            return filter
        }
    }
}

struct ChatListNodeViewUpdate {
    let view: ChatListView
    let type: ViewUpdateType
    let scrollPosition: ChatListNodeViewScrollPosition?
}

public func chatListFilterPredicate(filter: ChatListFilterData) -> ChatListFilterPredicate {
    var includePeers = Set(filter.includePeers.peers)
    var excludePeers = Set(filter.excludePeers)
    
    if !filter.includePeers.pinnedPeers.isEmpty {
        includePeers.subtract(filter.includePeers.pinnedPeers)
        excludePeers.subtract(filter.includePeers.pinnedPeers)
    }
    
    var includeAdditionalPeerGroupIds: [PeerGroupId] = []
    if !filter.excludeArchived {
        includeAdditionalPeerGroupIds.append(Namespaces.PeerGroup.archive)
    }
    
    var messageTagSummary: ChatListMessageTagSummaryResultCalculation?
    if filter.excludeRead || filter.excludeMuted {
        messageTagSummary = ChatListMessageTagSummaryResultCalculation(addCount: ChatListMessageTagSummaryResultComponent(tag: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud), subtractCount: ChatListMessageTagActionsSummaryResultComponent(type: PendingMessageActionType.consumeUnseenPersonalMessage, namespace: Namespaces.Message.Cloud))
    }
    return ChatListFilterPredicate(includePeerIds: includePeers, excludePeerIds: excludePeers, pinnedPeerIds: filter.includePeers.pinnedPeers, messageTagSummary: messageTagSummary, includeAdditionalPeerGroupIds: includeAdditionalPeerGroupIds, include: { peer, isMuted, isUnread, isContact, messageTagSummaryResult in
        if filter.excludeRead {
            var effectiveUnread = isUnread
            if let messageTagSummaryResult = messageTagSummaryResult, messageTagSummaryResult {
                effectiveUnread = true
            }
            if !effectiveUnread {
                return false
            }
        }
        if filter.excludeMuted {
            if isMuted {
                if let messageTagSummaryResult = messageTagSummaryResult, messageTagSummaryResult {
                } else {
                    return false
                }
            }
        }
        if !filter.categories.contains(.contacts) && isContact {
            if let user = peer as? TelegramUser {
                if user.botInfo == nil {
                    return false
                }
            } else if let _ = peer as? TelegramSecretChat {
                return false
            }
        }
        if !filter.categories.contains(.nonContacts) && !isContact {
            if let user = peer as? TelegramUser {
                if user.botInfo == nil {
                    return false
                }
            } else if let _ = peer as? TelegramSecretChat {
                return false
            }
        }
        if !filter.categories.contains(.bots) {
            if let user = peer as? TelegramUser {
                if user.botInfo != nil {
                    return false
                }
            }
        }
        if !filter.categories.contains(.groups) {
            if let _ = peer as? TelegramGroup {
                return false
            } else if let channel = peer as? TelegramChannel {
                if case .group = channel.info {
                    return false
                }
            }
        }
        if !filter.categories.contains(.channels) {
            if let channel = peer as? TelegramChannel {
                if case .broadcast = channel.info {
                    return false
                }
            }
        }
        return true
    })
}

func chatListViewForLocation(groupId: PeerGroupId, location: ChatListNodeLocation, account: Account) -> Signal<ChatListNodeViewUpdate, NoError> {
    let filterPredicate: ChatListFilterPredicate? = (location.filter?.data).flatMap(chatListFilterPredicate)
    
    switch location {
        case let .initial(count, _):
            let signal: Signal<(ChatListView, ViewUpdateType), NoError>
            signal = account.viewTracker.tailChatListView(groupId: groupId, filterPredicate: filterPredicate, count: count)
            return signal
            |> map { view, updateType -> ChatListNodeViewUpdate in
                return ChatListNodeViewUpdate(view: view, type: updateType, scrollPosition: nil)
            }
        case let .navigation(index, _):
            var first = true
            return account.viewTracker.aroundChatListView(groupId: groupId, filterPredicate: filterPredicate, index: index, count: 80)
            |> map { view, updateType -> ChatListNodeViewUpdate in
                let genericType: ViewUpdateType
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return ChatListNodeViewUpdate(view: view, type: genericType, scrollPosition: nil)
            }
        case let .scroll(index, sourceIndex, scrollPosition, animated, _):
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
            let chatScrollPosition: ChatListNodeViewScrollPosition = .index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
            var first = true
            return account.viewTracker.aroundChatListView(groupId: groupId, filterPredicate: filterPredicate, index: index, count: 80)
            |> map { view, updateType -> ChatListNodeViewUpdate in
                let genericType: ViewUpdateType
                let scrollPosition: ChatListNodeViewScrollPosition? = first ? chatScrollPosition : nil
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return ChatListNodeViewUpdate(view: view, type: genericType, scrollPosition: scrollPosition)
            }
    }
}

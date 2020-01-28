import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display
import TelegramUIPreferences

enum ChatListNodeLocation: Equatable {
    case initial(count: Int, filter: ChatListFilterPreset?)
    case navigation(index: ChatListIndex, filter: ChatListFilterPreset?)
    case scroll(index: ChatListIndex, sourceIndex: ChatListIndex, scrollPosition: ListViewScrollPosition, animated: Bool, filter: ChatListFilterPreset?)
    
    var filter: ChatListFilterPreset? {
        switch self {
        case let .initial(initial):
            return initial.filter
        case let .navigation(navigation):
            return navigation.filter
        case let .scroll(scroll):
            return scroll.filter
        }
    }
}

struct ChatListNodeViewUpdate {
    let view: ChatListView
    let type: ViewUpdateType
    let scrollPosition: ChatListNodeViewScrollPosition?
}

func chatListViewForLocation(groupId: PeerGroupId, location: ChatListNodeLocation, account: Account) -> Signal<ChatListNodeViewUpdate, NoError> {
    let filterPredicate: ((Peer, PeerNotificationSettings?, Bool) -> Bool)?
    if let filter = location.filter {
        let includePeers = Set(filter.additionallyIncludePeers)
        filterPredicate = { peer, notificationSettings, isUnread in
            if includePeers.contains(peer.id) {
                return true
            }
            if !filter.includeCategories.contains(.read) {
                if !isUnread {
                    return false
                }
            }
            if !filter.includeCategories.contains(.muted) {
                if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                    if case .muted = notificationSettings.muteState {
                        return false
                    }
                } else {
                    return false
                }
            }
            if !filter.includeCategories.contains(.privateChats) {
                if let user = peer as? TelegramUser {
                    if user.botInfo == nil {
                        return false
                    }
                }
            }
            if !filter.includeCategories.contains(.secretChats) {
                if let _ = peer as? TelegramSecretChat {
                    return false
                }
            }
            if !filter.includeCategories.contains(.bots) {
                if let user = peer as? TelegramUser {
                    if user.botInfo != nil {
                        return false
                    }
                }
            }
            if !filter.includeCategories.contains(.privateGroups) {
                if let _ = peer as? TelegramGroup {
                    return false
                } else if let channel = peer as? TelegramChannel {
                    if case .group = channel.info {
                        if channel.username == nil {
                            return false
                        }
                    }
                }
            }
            if !filter.includeCategories.contains(.publicGroups) {
                if let channel = peer as? TelegramChannel {
                    if case .group = channel.info {
                        if channel.username != nil {
                            return false
                        }
                    }
                }
            }
            if !filter.includeCategories.contains(.channels) {
                if let channel = peer as? TelegramChannel {
                    if case .broadcast = channel.info {
                        return false
                    }
                }
            }
            return true
        }
    } else {
        filterPredicate = nil
    }
    
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

import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display

enum ChatListNodeLocation: Equatable {
    case initial(count: Int)
    case navigation(index: ChatListIndex)
    case scroll(index: ChatListIndex, sourceIndex: ChatListIndex, scrollPosition: ListViewScrollPosition, animated: Bool)
    
    static func ==(lhs: ChatListNodeLocation, rhs: ChatListNodeLocation) -> Bool {
        switch lhs {
            case let .navigation(index):
                switch rhs {
                    case .navigation(index):
                        return true
                    default:
                        return false
                }
            default:
                return false
        }
    }
}

struct ChatListNodeViewUpdate {
    let view: ChatListView
    let type: ViewUpdateType
    let scrollPosition: ChatListNodeViewScrollPosition?
}

struct ChatListNodeFilter: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let muted = ChatListNodeFilter(rawValue: 1 << 1)
    static let privateChats = ChatListNodeFilter(rawValue: 1 << 2)
    static let groups = ChatListNodeFilter(rawValue: 1 << 3)
    static let bots = ChatListNodeFilter(rawValue: 1 << 4)
    static let channels = ChatListNodeFilter(rawValue: 1 << 5)
    
    static let all: ChatListNodeFilter = [
        .muted,
        .privateChats,
        .groups,
        .bots,
        .channels
    ]
}

func chatListViewForLocation(groupId: PeerGroupId, filter: ChatListNodeFilter, location: ChatListNodeLocation, account: Account) -> Signal<ChatListNodeViewUpdate, NoError> {
    let filterPredicate: ((Peer, PeerNotificationSettings?) -> Bool)?
    if filter == .all {
        filterPredicate = nil
    } else {
        filterPredicate = { peer, notificationSettings in
            if !filter.contains(.muted) {
                if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                    if case .muted = notificationSettings.muteState {
                        return false
                    }
                } else {
                    return false
                }
            }
            if !filter.contains(.privateChats) {
                if let user = peer as? TelegramUser {
                    if user.botInfo == nil {
                        return false
                    }
                } else if let _ = peer as? TelegramSecretChat {
                    return false
                }
            }
            if !filter.contains(.bots) {
                if let user = peer as? TelegramUser {
                    if user.botInfo != nil {
                        return false
                    }
                }
            }
            if !filter.contains(.groups) {
                if let _ = peer as? TelegramGroup {
                    return false
                } else if let channel = peer as? TelegramChannel {
                    if case .group = channel.info {
                        return false
                    }
                }
            }
            if !filter.contains(.channels) {
                if let channel = peer as? TelegramChannel {
                    if case .broadcast = channel.info {
                        return false
                    }
                }
            }
            return true
        }
    }
    
    switch location {
        case let .initial(count):
            let signal: Signal<(ChatListView, ViewUpdateType), NoError>
            signal = account.viewTracker.tailChatListView(groupId: groupId, filterPredicate: filterPredicate, count: count)
            return signal
            |> map { view, updateType -> ChatListNodeViewUpdate in
                return ChatListNodeViewUpdate(view: view, type: updateType, scrollPosition: nil)
            }
        case let .navigation(index):
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
        case let .scroll(index, sourceIndex, scrollPosition, animated):
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

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

func chatListViewForLocation(groupId: PeerGroupId, location: ChatListNodeLocation, account: Account) -> Signal<ChatListNodeViewUpdate, NoError> {
    switch location {
        case let .initial(count):
            let signal: Signal<(ChatListView, ViewUpdateType), NoError>
            signal = account.viewTracker.tailChatListView(groupId: groupId, count: count)
            return signal
            |> map { view, updateType -> ChatListNodeViewUpdate in
                return ChatListNodeViewUpdate(view: view, type: updateType, scrollPosition: nil)
            }
        case let .navigation(index):
            var first = true
            return account.viewTracker.aroundChatListView(groupId: groupId, index: index, count: 80)
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
            return account.viewTracker.aroundChatListView(groupId: groupId, index: index, count: 80)
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

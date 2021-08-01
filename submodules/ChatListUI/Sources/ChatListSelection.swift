import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

enum ChatListSelectionReadOption: Equatable {
    case all(enabled: Bool)
    case selective(enabled: Bool)
}

struct ChatListSelectionOptions: Equatable {
    let read: ChatListSelectionReadOption
    let delete: Bool
}

func chatListSelectionOptions(context: AccountContext, peerIds: Set<PeerId>, filterId: Int32?) -> Signal<ChatListSelectionOptions, NoError> {
    if peerIds.isEmpty {
        if let filterId = filterId {
            return chatListFilterItems(context: context)
            |> map { filterItems -> ChatListSelectionOptions in
                for (filter, unreadCount, _) in filterItems.1 {
                    if filter.id == filterId {
                        return ChatListSelectionOptions(read: .all(enabled: unreadCount != 0), delete: false)
                    }
                }
                return ChatListSelectionOptions(read: .all(enabled: false), delete: false)
            }
            |> distinctUntilChanged
        } else {
            let key = PostboxViewKey.unreadCounts(items: [.total(nil)])
            return context.account.postbox.combinedView(keys: [key])
            |> map { view -> ChatListSelectionOptions in
                var hasUnread = false
                if let unreadCounts = view.views[key] as? UnreadMessageCountsView, let total = unreadCounts.total() {
                    for (_, counter) in total.1.absoluteCounters {
                        if counter.messageCount != 0 {
                            hasUnread = true
                            break
                        }
                    }
                }
                return ChatListSelectionOptions(read: .all(enabled: hasUnread), delete: false)
            }
            |> distinctUntilChanged
        }
    } else {
        let items: [UnreadMessageCountsItem] = peerIds.map(UnreadMessageCountsItem.peer)
        let key = PostboxViewKey.unreadCounts(items: items)
        return context.account.postbox.combinedView(keys: [key])
        |> map { view -> ChatListSelectionOptions in
            var hasUnread = false
            if let unreadCounts = view.views[key] as? UnreadMessageCountsView {
                loop: for entry in unreadCounts.entries {
                    switch entry {
                        case let .peer(_, state):
                            if let state = state, state.isUnread {
                                hasUnread = true
                                break loop
                            }
                        default:
                            break
                    }
                }
            }
            return ChatListSelectionOptions(read: .selective(enabled: hasUnread), delete: true)
        }
        |> distinctUntilChanged
    }
}

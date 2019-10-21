import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore

enum ChatListSelectionReadOption: Equatable {
    case all(enabled: Bool)
    case selective(enabled: Bool)
}

struct ChatListSelectionOptions: Equatable {
    let read: ChatListSelectionReadOption
    let delete: Bool
}

func chatListSelectionOptions(postbox: Postbox, peerIds: Set<PeerId>) -> Signal<ChatListSelectionOptions, NoError> {
    if peerIds.isEmpty {
        let key = PostboxViewKey.unreadCounts(items: [.total(nil)])
        return postbox.combinedView(keys: [key])
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
    } else {
        let items: [UnreadMessageCountsItem] = peerIds.map(UnreadMessageCountsItem.peer)
        let key = PostboxViewKey.unreadCounts(items: items)
        return postbox.combinedView(keys: [key])
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

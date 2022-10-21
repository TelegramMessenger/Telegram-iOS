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
            return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.TotalReadCounters())
            |> map { readCounters -> ChatListSelectionOptions in
                var hasUnread = false
                if readCounters.count(for: .filtered, in: .chats, with: .all) != 0 {
                    hasUnread = true
                }
                return ChatListSelectionOptions(read: .all(enabled: hasUnread), delete: false)
            }
            |> distinctUntilChanged
        }
    } else {
        return context.engine.data.subscribe(EngineDataList(
            peerIds.map(TelegramEngine.EngineData.Item.Messages.PeerReadCounters.init)
        ))
        |> map { readCounters -> ChatListSelectionOptions in
            var hasUnread = false
            for counters in readCounters {
                if counters.isUnread {
                    hasUnread = true
                    break
                }
            }
            return ChatListSelectionOptions(read: .selective(enabled: hasUnread), delete: true)
        }
        |> distinctUntilChanged
    }
}


func forumSelectionOptions(context: AccountContext, peerId: PeerId, threadIds: Set<Int64>, canDelete: Bool) -> Signal<ChatListSelectionOptions, NoError> {
    if threadIds.isEmpty {
        return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.PeerReadCounters(id: peerId))
        |> map { counters -> ChatListSelectionOptions in
            var hasUnread = false
            if counters.isUnread {
                hasUnread = true
            }
            return ChatListSelectionOptions(read: .all(enabled: hasUnread), delete: false)
        }
        |> distinctUntilChanged
    } else {
        return .single(ChatListSelectionOptions(read: .selective(enabled: false), delete: canDelete))
    }
}

import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import StoryContainerScreen

public enum StoryChatContent {
	/*public static func messages(
		context: AccountContext,
		messageId: EngineMessage.Id
	) -> Signal<StoryContentItemSlice, NoError> {
        return context.account.postbox.aroundIdMessageHistoryViewForLocation(
            .peer(peerId: messageId.peerId, threadId: nil),
            ignoreMessagesInTimestampRange: nil,
            count: 10,
            messageId: messageId,
            topTaggedMessageIdNamespaces: Set(),
            tagMask: .photoOrVideo,
            appendMessagesFromTheSameGroup: false,
            namespaces: .not(Set([Namespaces.Message.ScheduledCloud, Namespaces.Message.ScheduledLocal])),
            orderStatistics: .combinedLocation
        )
        |> map { view -> StoryContentItemSlice in
            var items: [StoryContentItem] = []
            var totalCount = 0
            for entry in view.0.entries {
                if let location = entry.location {
                    totalCount = location.count
                }
                
                var hasLike = false
                if let reactions = entry.message.effectiveReactions {
                    for reaction in reactions {
                        if !reaction.isSelected {
                            continue
                        }
                        if reaction.value == .builtin("❤") {
                            hasLike = true
                        }
                    }
                }
                
                var preload: Signal<Never, NoError>?
                preload = StoryMessageContentComponent.preload(context: context, message: EngineMessage(entry.message))
                
                items.append(StoryContentItem(
                    id: AnyHashable(entry.message.id),
                    position: entry.location?.index ?? 0,
                    component: AnyComponent(StoryMessageContentComponent(
                        context: context,
                        message: EngineMessage(entry.message)
                    )),
                    centerInfoComponent: AnyComponent(StoryAuthorInfoComponent(
                        context: context,
                        message: EngineMessage(entry.message)
                    )),
                    rightInfoComponent: entry.message.author.flatMap { author -> AnyComponent<Empty> in
                        return AnyComponent(StoryAvatarInfoComponent(
                            context: context,
                            peer: EnginePeer(author)
                        ))
                    },
                    targetMessageId: entry.message.id,
                    preload: preload,
                    hasLike: hasLike,
                    isMy: false//!entry.message.effectivelyIncoming(context.account.peerId)
                ))
            }
            return StoryContentItemSlice(
                id: AnyHashable(entry.)
                focusedItemId: AnyHashable(messageId),
                items: items,
                totalCount: totalCount,
                update: { _, itemId in
                    if let id = itemId.base as? EngineMessage.Id {
                        return StoryChatContent.messages(
                            context: context,
                            messageId: id
                        )
                    } else {
                        return StoryChatContent.messages(
                            context: context,
                            messageId: messageId
                        )
                    }
                }
            )
        }
	}*/
    
    public static func stories(context: AccountContext, storyList: StoryListContext, focusItem: Int64?) -> Signal<[StoryContentItemSlice], NoError> {
        return storyList.state
        |> map { state -> [StoryContentItemSlice] in
            var itemSlices: [StoryContentItemSlice] = []
            
            for itemSet in state.itemSets {
                var items: [StoryContentItem] = []
                
                for item in itemSet.items {
                    items.append(StoryContentItem(
                        id: AnyHashable(item.id),
                        position: items.count,
                        component: AnyComponent(StoryItemContentComponent(
                            context: context,
                            item: item
                        )),
                        centerInfoComponent: AnyComponent(StoryAuthorInfoComponent(
                            context: context,
                            peer: itemSet.peer,
                            timestamp: item.timestamp
                        )),
                        rightInfoComponent: itemSet.peer.flatMap { author -> AnyComponent<Empty> in
                            return AnyComponent(StoryAvatarInfoComponent(
                                context: context,
                                peer: author
                            ))
                        },
                        targetMessageId: nil,
                        preload: nil,
                        delete: { [weak storyList] in
                            storyList?.delete(id: item.id)
                        },
                        hasLike: false,
                        isMy: itemSet.peerId == context.account.peerId
                    ))
                }
                
                var sliceFocusedItemId: AnyHashable?
                if let focusItem, items.contains(where: { ($0.id.base as? Int64) == focusItem }) {
                    sliceFocusedItemId = AnyHashable(focusItem)
                }
                
                itemSlices.append(StoryContentItemSlice(
                    id: AnyHashable(itemSet.peerId),
                    focusedItemId: sliceFocusedItemId,
                    items: items,
                    totalCount: items.count,
                    update: { requestedItemSet, itemId in
                        var focusItem: Int64?
                        if let id = itemId.base as? Int64 {
                            focusItem = id
                        }
                        return StoryChatContent.stories(context: context, storyList: storyList, focusItem: focusItem)
                        |> mapToSignal { result -> Signal<StoryContentItemSlice, NoError> in
                            if let foundItemSet = result.first(where: { $0.id == requestedItemSet.id }) {
                                return .single(foundItemSet)
                            } else {
                                return .never()
                            }
                        }
                    }
                ))
            }
            
            return itemSlices
        }
    }
}

import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import StoryContainerScreen

public enum StoryChatContent {
    public static func stories(context: AccountContext, storyList: StoryListContext, focusItem: Int32?) -> Signal<[StoryContentItemSlice], NoError> {
        return storyList.state
        |> map { state -> [StoryContentItemSlice] in
            var itemSlices: [StoryContentItemSlice] = []
            
            for itemSet in state.itemSets {
                var items: [StoryContentItem] = []
                
                guard let peer = itemSet.peer else {
                    continue
                }
                let peerId = itemSet.peerId
                
                for item in itemSet.items {
                    items.append(StoryContentItem(
                        id: AnyHashable(item.id),
                        position: items.count,
                        component: AnyComponent(StoryItemContentComponent(
                            context: context,
                            peer: peer,
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
                        peerId: itemSet.peerId,
                        storyItem: item,
                        preload: nil,
                        delete: { [weak storyList] in
                            storyList?.delete(id: item.id)
                        },
                        markAsSeen: { [weak context] in
                            guard let context else {
                                return
                            }
                            let _ = context.engine.messages.markStoryAsSeen(peerId: peerId, id: item.id).start()
                        },
                        hasLike: false,
                        isMy: itemSet.peerId == context.account.peerId
                    ))
                }
                
                var sliceFocusedItemId: AnyHashable?
                if let focusItem, items.contains(where: { ($0.id.base as? Int32) == focusItem }) {
                    sliceFocusedItemId = AnyHashable(focusItem)
                } else {
                    if let id = itemSet.items.first(where: { $0.id > itemSet.maxReadId })?.id {
                        sliceFocusedItemId = AnyHashable(id)
                    }
                }
                
                itemSlices.append(StoryContentItemSlice(
                    id: AnyHashable(itemSet.peerId),
                    focusedItemId: sliceFocusedItemId,
                    items: items,
                    totalCount: items.count,
                    update: { requestedItemSet, itemId in
                        var focusItem: Int32?
                        if let id = itemId.base as? Int32 {
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

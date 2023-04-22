import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import StoryContainerScreen

public enum StoryChatContent {
	public static func messages(
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
                    hasLike: hasLike
                ))
            }
            return StoryContentItemSlice(
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
	}
}

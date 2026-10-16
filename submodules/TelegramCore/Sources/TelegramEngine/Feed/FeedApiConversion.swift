import Foundation
import Postbox
internal import TelegramApi

// The feed API is parked (layer 232): what converts a removed type is behind TELEGRAM_NEWS_FEED_API, the parsed
// shapes and forYouBatchElements stay compiled.

#if TELEGRAM_NEWS_FEED_API
private func apiFeedPeer(_ peerId: PeerId) -> Api.Peer {
    switch peerId.namespace {
    case Namespaces.Peer.CloudUser:
        return .peerUser(.init(userId: peerId.id._internalGetInt64Value()))
    case Namespaces.Peer.CloudGroup:
        return .peerChat(.init(chatId: peerId.id._internalGetInt64Value()))
    default:
        return .peerChannel(.init(channelId: peerId.id._internalGetInt64Value()))
    }
}

extension EngineFeedPosition {
    init(apiPosition: Api.FeedPosition) {
        switch apiPosition {
        case let .feedPosition(data):
            self.init(date: data.date, peerId: data.peer.peerId, id: data.id)
        }
    }

    var apiPosition: Api.FeedPosition {
        return .feedPosition(.init(date: self.date, peer: apiFeedPeer(self.peerId), id: self.id))
    }
}
#endif

struct ParsedFeedPage {
    let messages: [Api.Message]
    let chats: [Api.Chat]
    let users: [Api.User]
    let maxPosition: EngineFeedPosition?
    let minPosition: EngineFeedPosition?
    let readMaxPosition: EngineFeedPosition?
}

enum ParsedFeedMessages {
    case notModified
    case page(ParsedFeedPage)
}

#if TELEGRAM_NEWS_FEED_API
func parseFeedMessages(_ result: Api.feed.FeedMessages) -> ParsedFeedMessages {
    switch result {
    case .feedMessagesNotModified:
        return .notModified
    case let .feedMessages(data):
        return .page(ParsedFeedPage(
            messages: data.messages,
            chats: data.chats,
            users: data.users,
            maxPosition: data.maxPosition.flatMap(EngineFeedPosition.init(apiPosition:)),
            minPosition: data.minPosition.flatMap(EngineFeedPosition.init(apiPosition:)),
            readMaxPosition: data.readMaxPosition.flatMap(EngineFeedPosition.init(apiPosition:))
        ))
    }
}
#endif

enum ParsedForYouElement {
    case message(Api.Message)
    /// Messages the server hands out as one item: a whole album.
    case messageGroup([Api.Message])
    case interests
}

struct ParsedForYouFeed {
    let elements: [ParsedForYouElement]
    let chats: [Api.Chat]
    let users: [Api.User]
}

#if TELEGRAM_NEWS_FEED_API
func parseForYouFeed(_ result: Api.feed.ForYouFeed) -> ParsedForYouFeed {
    switch result {
    case let .forYouFeed(data):
        // The server only sends item types that exist in the client's layer.
        let elements = data.items.map { item -> ParsedForYouElement in
            switch item {
            case let .feedItemMessage(itemData):
                return .message(itemData.message)
            case let .feedItemMessageGroup(itemData):
                return .messageGroup(itemData.messages)
            case .feedItemInterestCategories:
                return .interests
            }
        }
        return ParsedForYouFeed(elements: elements, chats: data.chats, users: data.users)
    }
}
#endif

/// The batch in server order, as stored: a message that was not stored is left out, and a group keeps the
/// messages that were (none left drops it).
func forYouBatchElements(_ elements: [ParsedForYouElement], storedById: [MessageId: FeedPageMessage]) -> [ForYouBatchElement] {
    var batch: [ForYouBatchElement] = []
    for element in elements {
        switch element {
        case .interests:
            batch.append(.interests)
        case let .message(message):
            if let id = message.id(), let storedMessage = storedById[id] {
                batch.append(.message(storedMessage))
            }
        case let .messageGroup(messages):
            let storedMessages = messages.compactMap { message -> FeedPageMessage? in
                return message.id().flatMap { storedById[$0] }
            }
            if !storedMessages.isEmpty {
                batch.append(.group(storedMessages))
            }
        }
    }
    return batch
}

#if TELEGRAM_NEWS_FEED_API
/// nil for `interestCategoriesNotModified`.
func parseInterestCategories(_ result: Api.feed.InterestCategories) -> EngineInterestCategories? {
    switch result {
    case .interestCategoriesNotModified:
        return nil
    case let .interestCategories(data):
        let categories = data.categories.map { category -> EngineInterestCategory in
            switch category {
            case let .interestCategory(categoryData):
                return EngineInterestCategory(id: categoryData.id, title: categoryData.title, emoji: categoryData.emoji, emojiFileId: categoryData.emojiDocumentId)
            }
        }
        return EngineInterestCategories(categories: categories, selectedIds: data.selected)
    }
}
#endif

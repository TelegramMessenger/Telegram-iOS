import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

private func hashForIds(_ ids: [Int64]) -> Int64 {
    var acc: UInt64 = 0
    
    for id in ids {
        combineInt64Hash(&acc, with: UInt64(bitPattern: id))
    }
    return finalizeInt64Hash(acc)
}

private func managedRecentMedia(postbox: Postbox, network: Network, collectionId: Int32, extractItemId: @escaping (MemoryBuffer) -> Int64?, reverseHashOrder: Bool, forceFetch: Bool, fetch: @escaping (Int64) -> Signal<[OrderedItemListEntry]?, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var itemIds = transaction.getOrderedListItemIds(collectionId: collectionId).compactMap(extractItemId)
        if reverseHashOrder {
            itemIds.reverse()
        }
        return fetch(forceFetch ? 0 : hashForIds(itemIds))
            |> mapToSignal { sourceItems in
                var items: [OrderedItemListEntry] = []
                if let sourceItems = sourceItems {
                    var existingIds = Set<Data>()
                    for item in sourceItems {
                        let id = item.id.makeData()
                        if !existingIds.contains(id) {
                            existingIds.insert(id)
                            items.append(item)
                        }
                    }

                    return postbox.transaction { transaction -> Void in
                        transaction.replaceOrderedItemListItems(collectionId: collectionId, items: items)
                    }
                } else {
                    return .complete()
                }
            }
    } |> switchToLatest
}

func managedRecentStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentStickers, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getRecentStickers(flags: 0, hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
            switch result {
                case .recentStickersNotModified:
                    return .single(nil)
                case let .recentStickers(_, _, stickers, _):
                    var items: [OrderedItemListEntry] = []
                    for sticker in stickers {
                        if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                            if let entry = CodableEntry(RecentMediaItem(file)) {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                            }
                        }
                    }
                    return .single(items)
            }
        }
    })
}

func managedRecentGifs(postbox: Postbox, network: Network, forceFetch: Bool = false) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentGifs, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: forceFetch, fetch: { hash in
        return network.request(Api.functions.messages.getSavedGifs(hash: hash))
            |> retryRequest
            |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
                switch result {
                    case .savedGifsNotModified:
                        return .single(nil)
                    case let .savedGifs(_, gifs):
                        var items: [OrderedItemListEntry] = []
                        for gif in gifs {
                            if let file = telegramMediaFileFromApiDocument(gif), let id = file.id {
                                if let entry = CodableEntry(RecentMediaItem(file)) {
                                    items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                                }
                            }
                        }
                        return .single(items)
                }
        }
    })
}

func managedSavedStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudSavedStickers, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: true, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getFavedStickers(hash: hash))
            |> retryRequest
            |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
                switch result {
                    case .favedStickersNotModified:
                        return .single(nil)
                    case let .favedStickers(_, packs, stickers):
                        var fileStringRepresentations: [MediaId: [String]] = [:]
                        for pack in packs {
                            switch pack {
                                case let .stickerPack(text, fileIds):
                                    for fileId in fileIds {
                                        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                        if fileStringRepresentations[mediaId] == nil {
                                            fileStringRepresentations[mediaId] = [text]
                                        } else {
                                            fileStringRepresentations[mediaId]!.append(text)
                                        }
                                    }
                            }
                        }
                        
                        var items: [OrderedItemListEntry] = []
                        for sticker in stickers {
                            if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                                var stringRepresentations: [String] = []
                                if let representations = fileStringRepresentations[id] {
                                    stringRepresentations = representations
                                }
                                if let entry = CodableEntry(SavedStickerItem(file: file, stringRepresentations: stringRepresentations)) {
                                    items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                                }
                            }
                        }
                        return .single(items)
                }
        }
    })
}

func managedGreetingStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudGreetingStickers, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getStickers(emoticon: "👋⭐️", hash: 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
            switch result {
                case .stickersNotModified:
                    return .single(nil)
                case let .stickers(_, stickers):
                    var items: [OrderedItemListEntry] = []
                    for sticker in stickers {
                        if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                            if let entry = CodableEntry(RecentMediaItem(file)) {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                            }
                        }
                    }
                    return .single(items)
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedPremiumStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudPremiumStickers, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getStickers(emoticon: "⭐️⭐️", hash: 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
            switch result {
                case .stickersNotModified:
                    return .single(nil)
                case let .stickers(_, stickers):
                    var items: [OrderedItemListEntry] = []
                    for sticker in stickers {
                        if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                            if let entry = CodableEntry(RecentMediaItem(file)) {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                            }
                        }
                    }
                    return .single(items)
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedAllPremiumStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudAllPremiumStickers, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getStickers(emoticon: "📂⭐️", hash: 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
            switch result {
                case .stickersNotModified:
                    return .single(nil)
                case let .stickers(_, stickers):
                    var items: [OrderedItemListEntry] = []
                    for sticker in stickers {
                        if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                            if let entry = CodableEntry(RecentMediaItem(file)) {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                            }
                        }
                    }
                    return .single(items)
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedRecentStatusEmoji(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentStatusEmoji, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.account.getRecentEmojiStatuses(hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
            switch result {
            case .emojiStatusesNotModified:
                return .single(nil)
            case let .emojiStatuses(_, statuses):
                let parsedStatuses = statuses.compactMap(PeerEmojiStatus.init(apiStatus:))
                
                return _internal_resolveInlineStickers(postbox: postbox, network: network, fileIds: parsedStatuses.map(\.fileId))
                |> map { files -> [OrderedItemListEntry] in
                    var items: [OrderedItemListEntry] = []
                    for status in parsedStatuses {
                        guard let file = files[status.fileId] else {
                            continue
                        }
                        if let entry = CodableEntry(RecentMediaItem(file)) {
                            items.append(OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry))
                        }
                    }
                    return items
                }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedFeaturedStatusEmoji(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudFeaturedStatusEmoji, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.account.getDefaultEmojiStatuses(hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
            switch result {
            case .emojiStatusesNotModified:
                return .single(nil)
            case let .emojiStatuses(_, statuses):
                let parsedStatuses = statuses.compactMap(PeerEmojiStatus.init(apiStatus:))
                
                return _internal_resolveInlineStickers(postbox: postbox, network: network, fileIds: parsedStatuses.map(\.fileId))
                |> map { files -> [OrderedItemListEntry] in
                    var items: [OrderedItemListEntry] = []
                    for status in parsedStatuses {
                        guard let file = files[status.fileId] else {
                            continue
                        }
                        if let entry = CodableEntry(RecentMediaItem(file)) {
                            items.append(OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry))
                        }
                    }
                    return items
                }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedRecentReactions(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentReactions, extractItemId: { rawId in
        switch RecentReactionItemId(rawId).id {
        case .builtin:
            return 0
        case let .custom(fileId):
            return fileId.id
        }
    }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getRecentReactions(limit: 100, hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
            switch result {
            case .reactionsNotModified:
                return .single(nil)
            case let .reactions(_, reactions):
                let parsedReactions = reactions.compactMap(MessageReaction.Reaction.init(apiReaction:))
                
                return _internal_resolveInlineStickers(postbox: postbox, network: network, fileIds: parsedReactions.compactMap { reaction -> Int64? in
                    switch reaction {
                    case .builtin:
                        return nil
                    case let .custom(fileId):
                        return fileId
                    }
                })
                |> map { files -> [OrderedItemListEntry] in
                    var items: [OrderedItemListEntry] = []
                    for reaction in parsedReactions {
                        let item: RecentReactionItem
                        switch reaction {
                        case let .builtin(value):
                            item = RecentReactionItem(.builtin(value))
                        case let .custom(fileId):
                            guard let file = files[fileId] else {
                                continue
                            }
                            item = RecentReactionItem(.custom(file))
                        }
                        if let entry = CodableEntry(item) {
                            items.append(OrderedItemListEntry(id: item.id.rawValue, contents: entry))
                        }
                    }
                    return items
                }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedTopReactions(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudTopReactions, extractItemId: { rawId in
        switch RecentReactionItemId(rawId).id {
        case .builtin:
            return 0
        case let .custom(fileId):
            return fileId.id
        }
    }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getTopReactions(limit: 32, hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<[OrderedItemListEntry]?, NoError> in
            switch result {
            case .reactionsNotModified:
                return .single(nil)
            case let .reactions(_, reactions):
                let parsedReactions = reactions.compactMap(MessageReaction.Reaction.init(apiReaction:))
                
                return _internal_resolveInlineStickers(postbox: postbox, network: network, fileIds: parsedReactions.compactMap { reaction -> Int64? in
                    switch reaction {
                    case .builtin:
                        return nil
                    case let .custom(fileId):
                        return fileId
                    }
                })
                |> map { files -> [OrderedItemListEntry] in
                    var items: [OrderedItemListEntry] = []
                    for reaction in parsedReactions {
                        let item: RecentReactionItem
                        switch reaction {
                        case let .builtin(value):
                            item = RecentReactionItem(.builtin(value))
                        case let .custom(fileId):
                            guard let file = files[fileId] else {
                                continue
                            }
                            item = RecentReactionItem(.custom(file))
                        }
                        if let entry = CodableEntry(item) {
                            items.append(OrderedItemListEntry(id: item.id.rawValue, contents: entry))
                        }
                    }
                    return items
                }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

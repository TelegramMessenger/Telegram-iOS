import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit
import MtProtoKit

private func hashForIds(_ ids: [Int64]) -> Int64 {
    var acc: UInt64 = 0
    
    for id in ids {
        combineInt64Hash(&acc, with: UInt64(bitPattern: id))
    }
    return finalizeInt64Hash(acc)
}

final class CachedOrderedItemListHashes: Codable {
    public let hashes: [Int32: (Int64, Int64)]
    
    public init(hashes: [Int32: (Int64, Int64)]) {
        self.hashes = hashes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let keys = try container.decode([Int32].self, forKey: "keys")
        let localHashes = try container.decode([Int64].self, forKey: "localHashes")
        let remoteHashes = try container.decode([Int64].self, forKey: "remoteHashes")
        self.hashes = Dictionary(uniqueKeysWithValues: zip(keys, zip(localHashes, remoteHashes)))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.hashes.map { $0.key }, forKey: "keys")
        try container.encode(self.hashes.map { $0.value.0 }, forKey: "localHashes")
        try container.encode(self.hashes.map { $0.value.1 }, forKey: "remoteHashes")
    }
}

func getOrderedItemListHash(transaction: Transaction, collectionId: Int32) -> (Int64, Int64) {
    return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedOrderedItemListHashes, key: ValueBoxKey(length: 0)))?.get(CachedOrderedItemListHashes.self)?.hashes[collectionId] ?? (0, 0)
}

func setOrderedItemListHash(transaction: Transaction, collectionId: Int32, localHash: Int64, remoteHash: Int64) {
    var cachedOrderedItemListHashes = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedOrderedItemListHashes, key: ValueBoxKey(length: 0)))?.get(CachedOrderedItemListHashes.self)?.hashes ?? [:]
    
    cachedOrderedItemListHashes[collectionId] = (localHash, remoteHash)
    
    if let entry = CodableEntry(CachedOrderedItemListHashes(hashes: cachedOrderedItemListHashes)) {
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedOrderedItemListHashes, key: ValueBoxKey(length: 0)), entry: entry)
    }
}

private func managedRecentMedia(postbox: Postbox, network: Network, collectionId: Int32, extractItemId: @escaping (MemoryBuffer) -> Int64?, reverseHashOrder: Bool, forceFetch: Bool, fetch: @escaping (Int64) -> Signal<([OrderedItemListEntry]?, Int64), NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var itemIds = transaction.getOrderedListItemIds(collectionId: collectionId).compactMap(extractItemId)
        if reverseHashOrder {
            itemIds.reverse()
        }
        
        // for some collections hash is calculated identically on client and server
        // for others we save remote hash value for further requests
        // local hash is also saved in latter case to detect when collection have been updated locally
        let goodHashCollectionIds = [
            Namespaces.OrderedItemList.CloudGreetingStickers,
            Namespaces.OrderedItemList.CloudPremiumStickers,
            Namespaces.OrderedItemList.CloudAllPremiumStickers,
            Namespaces.OrderedItemList.CloudSavedStickers,
            Namespaces.OrderedItemList.CloudRecentStickers,
            Namespaces.OrderedItemList.CloudRecentGifs,
        ]
        
        let hash: Int64
        if goodHashCollectionIds.contains(collectionId) {
            hash = hashForIds(itemIds)
        } else {
            let (localHash, remoteHash) = getOrderedItemListHash(transaction: transaction, collectionId: collectionId)
            hash = hashForIds(itemIds) == localHash ? remoteHash : 0
        }
        
        return fetch(forceFetch ? 0 : hash)
            |> mapToSignal { sourceItems, fetchedHash in
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
                        
                        var itemIds = items.map({ $0.id }).compactMap(extractItemId)
                        if reverseHashOrder {
                            itemIds.reverse()
                        }
                        
                        if goodHashCollectionIds.contains(collectionId) {
                            assert(hashForIds(itemIds) == fetchedHash)
                        } else {
                            assert(hashForIds(itemIds) != fetchedHash || fetchedHash == 0)
                            setOrderedItemListHash(transaction: transaction, collectionId: collectionId, localHash: hashForIds(itemIds), remoteHash: fetchedHash)
                        }
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
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
                case .recentStickersNotModified:
                    return .single(nil)
                    |> map { ($0, 0) }
                case let .recentStickers(hash, _, stickers, _):
                    var items: [OrderedItemListEntry] = []
                    for sticker in stickers {
                        if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                            if let entry = CodableEntry(RecentMediaItem(file)) {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                            }
                        }
                    }
                    return .single(items)
                    |> map { ($0, hash) }
            }
        }
    })
}

func managedRecentGifs(postbox: Postbox, network: Network, forceFetch: Bool = false) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentGifs, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: forceFetch, fetch: { hash in
        return network.request(Api.functions.messages.getSavedGifs(hash: hash))
            |> retryRequest
            |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
                switch result {
                    case .savedGifsNotModified:
                        return .single(nil)
                        |> map { ($0, 0) }
                    case let .savedGifs(hash, gifs):
                        var items: [OrderedItemListEntry] = []
                        for gif in gifs {
                            if let file = telegramMediaFileFromApiDocument(gif), let id = file.id {
                                if let entry = CodableEntry(RecentMediaItem(file)) {
                                    items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                                }
                            }
                        }
                        return .single(items)
                        |> map { ($0, hash) }
                }
        }
    })
}

func managedSavedStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudSavedStickers, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: true, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getFavedStickers(hash: hash))
            |> retryRequest
            |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
                switch result {
                    case .favedStickersNotModified:
                        return .single(nil)
                        |> map { ($0, 0) }
                    case let .favedStickers(hash, packs, stickers):
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
                        |> map { ($0, hash) }
                }
        }
    })
}

func managedGreetingStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudGreetingStickers, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getStickers(emoticon: "👋⭐️", hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
                case .stickersNotModified:
                    return .single(nil)
                    |> map { ($0, 0) }
                case let .stickers(hash, stickers):
                    var items: [OrderedItemListEntry] = []
                    for sticker in stickers {
                        if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                            if let entry = CodableEntry(RecentMediaItem(file)) {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                            }
                        }
                    }
                    return .single(items)
                    |> map { ($0, hash) }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedPremiumStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudPremiumStickers, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getStickers(emoticon: "⭐️⭐️", hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
                case .stickersNotModified:
                    return .single(nil)
                    |> map { ($0, 0) }
                case let .stickers(hash, stickers):
                    var items: [OrderedItemListEntry] = []
                    for sticker in stickers {
                        if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                            if let entry = CodableEntry(RecentMediaItem(file)) {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                            }
                        }
                    }
                    return .single(items)
                    |> map { ($0, hash) }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedAllPremiumStickers(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudAllPremiumStickers, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.messages.getStickers(emoticon: "📂⭐️", hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
                case .stickersNotModified:
                    return .single(nil)
                    |> map { ($0, 0) }
                case let .stickers(hash, stickers):
                    var items: [OrderedItemListEntry] = []
                    for sticker in stickers {
                        if let file = telegramMediaFileFromApiDocument(sticker), let id = file.id {
                            if let entry = CodableEntry(RecentMediaItem(file)) {
                                items.append(OrderedItemListEntry(id: RecentMediaItemId(id).rawValue, contents: entry))
                            }
                        }
                    }
                    return .single(items)
                    |> map { ($0, hash) }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedRecentStatusEmoji(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudRecentStatusEmoji, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.account.getRecentEmojiStatuses(hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
            case .emojiStatusesNotModified:
                return .single(nil)
                |> map { ($0, 0) }
            case let .emojiStatuses(hash, statuses):
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
                |> map { ($0, hash) }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedFeaturedStatusEmoji(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudFeaturedStatusEmoji, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.account.getDefaultEmojiStatuses(hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
            case .emojiStatusesNotModified:
                return .single(nil)
                |> map { ($0, 0) }
            case let .emojiStatuses(hash, statuses):
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
                |> map { ($0, hash) }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedProfilePhotoEmoji(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudFeaturedProfilePhotoEmoji, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.account.getDefaultProfilePhotoEmojis(hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
            case .emojiListNotModified:
                return .single(nil)
                |> map { ($0, 0) }
            case let .emojiList(hash, documentIds):
                return _internal_resolveInlineStickers(postbox: postbox, network: network, fileIds: documentIds)
                |> map { files -> [OrderedItemListEntry] in
                    var items: [OrderedItemListEntry] = []
                    for fileId in documentIds {
                        guard let file = files[fileId] else {
                            continue
                        }
                        if let entry = CodableEntry(RecentMediaItem(file)) {
                            items.append(OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry))
                        }
                    }
                    return items
                }
                |> map { ($0, hash) }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedGroupPhotoEmoji(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = managedRecentMedia(postbox: postbox, network: network, collectionId: Namespaces.OrderedItemList.CloudFeaturedGroupPhotoEmoji, extractItemId: { RecentMediaItemId($0).mediaId.id }, reverseHashOrder: false, forceFetch: false, fetch: { hash in
        return network.request(Api.functions.account.getDefaultGroupPhotoEmojis(hash: hash))
        |> retryRequest
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
            case .emojiListNotModified:
                return .single(nil)
                |> map { ($0, 0) }
            case let .emojiList(hash, documentIds):
                return _internal_resolveInlineStickers(postbox: postbox, network: network, fileIds: documentIds)
                |> map { files -> [OrderedItemListEntry] in
                    var items: [OrderedItemListEntry] = []
                    for fileId in documentIds {
                        guard let file = files[fileId] else {
                            continue
                        }
                        if let entry = CodableEntry(RecentMediaItem(file)) {
                            items.append(OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry))
                        }
                    }
                    return items
                }
                |> map { ($0, hash) }
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
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
            case .reactionsNotModified:
                return .single(nil)
                |> map { ($0, 0) }
            case let .reactions(hash, reactions):
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
                |> map { ($0, hash) }
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
        |> mapToSignal { result -> Signal<([OrderedItemListEntry]?, Int64), NoError> in
            switch result {
            case .reactionsNotModified:
                return .single(nil)
                |> map { ($0, 0) }
            case let .reactions(hash, reactions):
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
                |> map { ($0, hash) }
            }
        }
    })
    return (poll |> then(.complete() |> suspendAwareDelay(3.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit

enum FeaturedStickerPacksCategory {
    case stickerPacks
    case emojiPacks
}

extension FeaturedStickerPacksCategory {
    var itemListNamespace: Int32 {
        switch self {
        case .stickerPacks:
            return Namespaces.OrderedItemList.CloudFeaturedStickerPacks
        case .emojiPacks:
            return Namespaces.OrderedItemList.CloudFeaturedEmojiPacks
        }
    }
    
    var collectionIdNamespace: Int32 {
        switch self {
        case .stickerPacks:
            return Namespaces.ItemCollection.CloudStickerPacks
        case .emojiPacks:
            return Namespaces.ItemCollection.CloudEmojiPacks
        }
    }
}

private func hashForIdsReverse(_ ids: [Int64]) -> Int64 {
    var acc: UInt64 = 0
    
    for id in ids {
        combineInt64Hash(&acc, with: UInt64(bitPattern: id))
    }
    return Int64(bitPattern: acc)
}

private func hashForIdsReverse(_ ids: [Int64], unreadIds: [Int64]) -> Int64 {
    var acc: UInt64 = 0
    
    for id in ids {
        combineInt64Hash(&acc, with: UInt64(bitPattern: id))
        if unreadIds.contains(id) {
            combineInt64Hash(&acc, with: 1 as UInt64)
        }
    }
    return Int64(bitPattern: acc)
}

func manageStickerPacks(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return (postbox.transaction { transaction -> Void in
        addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .stickers, content: .sync, noDelay: false)
        addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .masks, content: .sync, noDelay: false)
        addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .emoji, content: .sync, noDelay: false)
        addSynchronizeSavedGifsOperation(transaction: transaction, operation: .sync)
        addSynchronizeSavedStickersOperation(transaction: transaction, operation: .sync)
        addSynchronizeRecentlyUsedMediaOperation(transaction: transaction, category: .stickers, operation: .sync)
    } |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func resolveMissingStickerSets(network: Network, postbox: Postbox, stickerSets: [Api.StickerSetCovered], ignorePacksWithHashes: [Int64: Int32]) -> Signal<[Api.StickerSetCovered], NoError> {
    var missingSignals: [Signal<(Int, Api.StickerSetCovered)?, NoError>] = []
    for i in 0 ..< stickerSets.count {
        switch stickerSets[i] {
        case let .stickerSetNoCovered(value), let .stickerSetCovered(value, _):
            switch value {
            case let .stickerSet(_, _, id, accessHash, _, _, _, _, _, _, _, hash):
                if ignorePacksWithHashes[id] == hash {
                    continue
                }
                
                missingSignals.append(network.request(Api.functions.messages.getStickerSet(stickerset: .inputStickerSetID(id: id, accessHash: accessHash), hash: 0))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.StickerSet?, NoError> in
                    return .single(nil)
                }
                |> map { result -> (Int, Api.StickerSetCovered)? in
                    if let result = result {
                        switch result {
                        case let .stickerSet(set, packs, keywords, documents):
                            return (i, Api.StickerSetCovered.stickerSetFullCovered(set: set, packs: packs, keywords: keywords, documents: documents))
                        case .stickerSetNotModified:
                            return nil
                        }
                    } else {
                        return nil
                    }
                })
            }
        default:
            break
        }
    }
    
    return combineLatest(missingSignals)
    |> map { results -> [Api.StickerSetCovered] in
        var updatedSets = stickerSets
        for result in results {
            if let result = result {
                updatedSets[result.0] = result.1
            }
        }
        return updatedSets
    }
}

func updatedFeaturedStickerPacks(network: Network, postbox: Postbox, category: FeaturedStickerPacksCategory) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        let initialPacks = transaction.getOrderedListItems(collectionId: category.itemListNamespace)
        var initialPackMap: [Int64: FeaturedStickerPackItem] = [:]
        var unreadIds: [Int64] = []
        for entry in initialPacks {
            let item = entry.contents.get(FeaturedStickerPackItem.self)!
            initialPackMap[FeaturedStickerPackItemId(entry.id).packId] = item
            if item.unread {
                unreadIds.append(item.info.id.id)
            }
        }
        
        let initialPackIds = initialPacks.map {
            return FeaturedStickerPackItemId($0.id).packId
        }
        let initialHash: Int64 = hashForIdsReverse(initialPackIds, unreadIds: unreadIds)
        
        struct FeaturedListContent {
            var unreadIds: Set<Int64>
            var packs: [FeaturedStickerPackItem]
            var isPremium: Bool
        }
        enum FeaturedList {
            case notModified
            case content(FeaturedListContent)
        }
        let signal: Signal<FeaturedList, NoError>
        switch category {
        case .stickerPacks:
            signal = network.request(Api.functions.messages.getFeaturedStickers(hash: initialHash))
            |> mapToSignal { result -> Signal<FeaturedList, MTRpcError> in
                switch result {
                case .featuredStickersNotModified:
                    return .single(.notModified)
                case let .featuredStickers(flags, _, _, sets, unread):
                    return resolveMissingStickerSets(network: network, postbox: postbox, stickerSets: sets, ignorePacksWithHashes: initialPackMap.filter { $0.value.topItems.count > 1 }.mapValues({ item in
                        item.info.hash
                    }))
                    |> castError(MTRpcError.self)
                    |> map { sets -> FeaturedList in
                        let unreadIds = Set(unread)
                        var updatedPacks: [FeaturedStickerPackItem] = []
                        for set in sets {
                            var (info, items) = parsePreviewStickerSet(set, namespace: category.collectionIdNamespace)
                            if let previousPack = initialPackMap[info.id.id] {
                                if previousPack.info.hash == info.hash, previousPack.topItems.count > 1 {
                                    items = previousPack.topItems
                                } else {
                                    items = Array(items.prefix(5))
                                }
                            }
                            updatedPacks.append(FeaturedStickerPackItem(info: StickerPackCollectionInfo.Accessor(info), topItems: items, unread: unreadIds.contains(info.id.id)))
                        }
                        let isPremium = flags & (1 << 0) != 0
                        return .content(FeaturedListContent(
                            unreadIds: unreadIds,
                            packs: updatedPacks,
                            isPremium: isPremium
                        ))
                    }
                }
            }
            |> `catch` { _ -> Signal<FeaturedList, NoError> in
                return .single(.notModified)
            }
        case .emojiPacks:
            signal = network.request(Api.functions.messages.getFeaturedEmojiStickers(hash: initialHash))
            |> mapToSignal { result -> Signal<FeaturedList, MTRpcError> in
                switch result {
                case .featuredStickersNotModified:
                    return .single(.notModified)
                case let .featuredStickers(flags, _, _, sets, unread):
                    return resolveMissingStickerSets(network: network, postbox: postbox, stickerSets: sets, ignorePacksWithHashes: initialPackMap.mapValues({ item in
                        item.info.hash
                    }))
                    |> castError(MTRpcError.self)
                    |> map { sets -> FeaturedList in
                        let unreadIds = Set(unread)
                        var updatedPacks: [FeaturedStickerPackItem] = []
                        for set in sets {
                            var (info, items) = parsePreviewStickerSet(set, namespace: category.collectionIdNamespace)
                            if let previousPack = initialPackMap[info.id.id] {
                                if previousPack.info.hash == info.hash {
                                    items = previousPack.topItems
                                }
                            }
                            updatedPacks.append(FeaturedStickerPackItem(info: StickerPackCollectionInfo.Accessor(info), topItems: items, unread: unreadIds.contains(info.id.id)))
                        }
                        let isPremium = flags & (1 << 0) != 0
                        return .content(FeaturedListContent(
                            unreadIds: unreadIds,
                            packs: updatedPacks,
                            isPremium: isPremium
                        ))
                    }
                }
            }
            |> `catch` { _ -> Signal<FeaturedList, NoError> in
                return .single(.notModified)
            }
        }
        
        return signal
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                switch result {
                case .notModified:
                    break
                case let .content(content):
                    transaction.replaceOrderedItemListItems(collectionId: category.itemListNamespace, items: content.packs.compactMap { item -> OrderedItemListEntry? in
                        if let entry = CodableEntry(item) {
                            return OrderedItemListEntry(id: FeaturedStickerPackItemId(item.info.id.id).rawValue, contents: entry)
                        } else {
                            return nil
                        }
                    })
                    
                    if let entry = CodableEntry(FeaturedStickersConfiguration(isPremium: content.isPremium)) {
                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.featuredStickersConfiguration, key: ValueBoxKey(length: 0)), entry: entry)
                    }
                }
            }
        }
    }
    |> switchToLatest
}

public func requestOldFeaturedStickerPacks(network: Network, postbox: Postbox, offset: Int, limit: Int) -> Signal<[FeaturedStickerPackItem], NoError> {
    return network.request(Api.functions.messages.getOldFeaturedStickers(offset: Int32(offset), limit: Int32(limit), hash: 0))
    |> retryRequest
    |> map { result -> [FeaturedStickerPackItem] in
        switch result {
        case .featuredStickersNotModified:
            return []
        case let .featuredStickers(_, _, _, sets, unread):
            let unreadIds = Set(unread)
            var updatedPacks: [FeaturedStickerPackItem] = []
            for set in sets {
                let (info, items) = parsePreviewStickerSet(set, namespace: Namespaces.ItemCollection.CloudStickerPacks)
                updatedPacks.append(FeaturedStickerPackItem(info: StickerPackCollectionInfo.Accessor(info), topItems: items, unread: unreadIds.contains(info.id.id)))
            }
            return updatedPacks
        }
    }
}

public func preloadedFeaturedStickerSet(network: Network, postbox: Postbox, id: ItemCollectionId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let pack = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, itemId: FeaturedStickerPackItemId(id.id).rawValue)?.contents.get(FeaturedStickerPackItem.self) {
            if pack.topItems.count < 5 && pack.topItems.count < pack.info.count {
                return _internal_requestStickerSet(postbox: postbox, network: network, reference: .id(id: pack.info.id.id, accessHash: pack.info.accessHash))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<RequestStickerSetResult?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if let result = result {
                        return postbox.transaction { transaction -> Void in
                            if let pack = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, itemId: FeaturedStickerPackItemId(id.id).rawValue)?.contents.get(FeaturedStickerPackItem.self) {
                                var items = result.items.map({ $0 as? StickerPackItem }).compactMap({ $0 })
                                if items.count > 5 {
                                    items.removeSubrange(5 ..< items.count)
                                }
                                if let entry = CodableEntry(FeaturedStickerPackItem(info: pack.info, topItems: items, unread: pack.unread)) {
                                    transaction.updateOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, itemId: FeaturedStickerPackItemId(id.id).rawValue, item: entry)
                                }
                            }
                        }
                    } else {
                        return .complete()
                    }
                }
            }
        }
        return .complete()
    } |> switchToLatest
}

func parsePreviewStickerSet(_ set: Api.StickerSetCovered, namespace: ItemCollectionId.Namespace) -> (StickerPackCollectionInfo, [StickerPackItem]) {
    switch set {
    case let .stickerSetCovered(set, cover):
        let info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
        var items: [StickerPackItem] = []
        if let file = telegramMediaFileFromApiDocument(cover, altDocuments: []), let id = file.id {
            items.append(StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: id.id), file: file, indexKeys: []))
        }
        return (info, items)
    case let .stickerSetMultiCovered(set, covers):
        let info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
        var items: [StickerPackItem] = []
        for cover in covers {
            if let file = telegramMediaFileFromApiDocument(cover, altDocuments: []), let id = file.id {
                items.append(StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: id.id), file: file, indexKeys: []))
            }
        }
        return (info, items)
    case let .stickerSetFullCovered(set, packs, keywords, documents):
        var indexKeysByFile: [MediaId: [MemoryBuffer]] = [:]
        for pack in packs {
            switch pack {
            case let .stickerPack(text, fileIds):
                let key = ValueBoxKey(text).toMemoryBuffer()
                for fileId in fileIds {
                    let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                    if indexKeysByFile[mediaId] == nil {
                        indexKeysByFile[mediaId] = [key]
                    } else {
                        indexKeysByFile[mediaId]!.append(key)
                    }
                }
                break
            }
        }
        for keyword in keywords {
            switch keyword {
            case let .stickerKeyword(documentId, texts):
                for text in texts {
                    let key = ValueBoxKey(text).toMemoryBuffer()
                    let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: documentId)
                    if indexKeysByFile[mediaId] == nil {
                        indexKeysByFile[mediaId] = [key]
                    } else {
                        indexKeysByFile[mediaId]!.append(key)
                    }
                }
            }
        }
        
        let info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
        var items: [StickerPackItem] = []
        for document in documents {
            if let file = telegramMediaFileFromApiDocument(document, altDocuments: []), let id = file.id {
                let fileIndexKeys: [MemoryBuffer]
                if let indexKeys = indexKeysByFile[id] {
                    fileIndexKeys = indexKeys
                } else {
                    fileIndexKeys = []
                }
                items.append(StickerPackItem(index: ItemCollectionItemIndex(index: 0, id: id.id), file: file, indexKeys: fileIndexKeys))
            }
        }
        return (info, items)
    case let .stickerSetNoCovered(set):
        let info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)
        let items: [StickerPackItem] = []
        return (info, items)
    }
}

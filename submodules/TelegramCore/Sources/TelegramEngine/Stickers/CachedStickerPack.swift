import Foundation
import Postbox
import SwiftSignalKit
import MurMurHash32

public enum CachedStickerPackResult {
    case none
    case fetching
    case result(StickerPackCollectionInfo, [StickerPackItem], Bool)
}

func cacheStickerPack(transaction: Transaction, info: StickerPackCollectionInfo, items: [StickerPackItem], reference: StickerPackReference? = nil) {
    if let entry = CodableEntry(CachedStickerPack(info: info, items: items, hash: info.hash)) {
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(info.id)), entry: entry)
    }
    if let entry = CodableEntry(CachedStickerPack(info: info, items: items, hash: info.hash)) {
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(shortName: info.shortName.lowercased())), entry: entry)
    }
    
    if let reference = reference {
        var namespace: Int32?
        var id: ItemCollectionId.Id?
        switch reference {
            case .animatedEmoji:
                namespace = Namespaces.ItemCollection.CloudAnimatedEmoji
                id = 0
            case .animatedEmojiAnimations:
                namespace = Namespaces.ItemCollection.CloudAnimatedEmojiAnimations
                id = 0
            case let .dice(emoji):
                namespace = Namespaces.ItemCollection.CloudDice
                id = Int64(murMurHashString32(emoji))
            default:
                break
        }
        if let namespace = namespace, let id = id {
            if let entry = CodableEntry(CachedStickerPack(info: info, items: items, hash: info.hash)) {
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id))), entry: entry)
            }
        }
    }
}

func _internal_cachedStickerPack(postbox: Postbox, network: Network, reference: StickerPackReference, forceRemote: Bool) -> Signal<CachedStickerPackResult, NoError> {
    return postbox.transaction { transaction -> CachedStickerPackResult? in
        if let (info, items, local) = cachedStickerPack(transaction: transaction, reference: reference) {
            if local {
                return .result(info, items, true)
            }
        }
        return nil
    }
    |> mapToSignal { value -> Signal<CachedStickerPackResult, NoError> in
        if let value = value {
            return .single(value)
        } else {
            return postbox.transaction { transaction -> (CachedStickerPackResult, Bool, Int32?) in
                let namespace = Namespaces.ItemCollection.CloudStickerPacks
                var previousHash: Int32?
                switch reference {
                    case let .id(id, _):
                        if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id))))?.get(CachedStickerPack.self), let info = cached.info {
                            previousHash = cached.hash
                            let current: CachedStickerPackResult = .result(info, cached.items, false)
                            if cached.hash != info.hash {
                                return (current, true, previousHash)
                            } else {
                                return (current, false, previousHash)
                            }
                        } else {
                            return (.fetching, true, nil)
                        }
                    case let .name(shortName):
                        if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(shortName: shortName.lowercased())))?.get(CachedStickerPack.self), let info = cached.info {
                            previousHash = cached.hash
                            let current: CachedStickerPackResult = .result(info, cached.items, false)
                            if cached.hash != info.hash {
                                return (current, true, previousHash)
                            } else {
                                return (current, false, previousHash)
                            }
                        } else {
                            return (.fetching, true, nil)
                        }
                    case .animatedEmoji:
                        let namespace = Namespaces.ItemCollection.CloudAnimatedEmoji
                        let id: ItemCollectionId.Id = 0
                        if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id))))?.get(CachedStickerPack.self), let info = cached.info {
                            previousHash = cached.hash
                            let current: CachedStickerPackResult = .result(info, cached.items, false)
                            if cached.hash != info.hash {
                                return (current, true, previousHash)
                            } else {
                                return (current, false, previousHash)
                            }
                        } else {
                            return (.fetching, true, nil)
                        }
                    case let .dice(emoji):
                        let namespace = Namespaces.ItemCollection.CloudDice
                        let id: ItemCollectionId.Id = Int64(murMurHashString32(emoji))
                        if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id))))?.get(CachedStickerPack.self), let info = cached.info {
                            previousHash = cached.hash
                            let current: CachedStickerPackResult = .result(info, cached.items, false)
                            if cached.hash != info.hash {
                                return (current, true, previousHash)
                            } else {
                                return (current, false, previousHash)
                            }
                        } else {
                            return (.fetching, true, nil)
                        }
                    case .animatedEmojiAnimations:
                        let namespace = Namespaces.ItemCollection.CloudAnimatedEmojiAnimations
                        let id: ItemCollectionId.Id = 0
                        if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id))))?.get(CachedStickerPack.self), let info = cached.info {
                            previousHash = cached.hash
                            let current: CachedStickerPackResult = .result(info, cached.items, false)
                            if cached.hash != info.hash {
                                return (current, true, previousHash)
                            } else {
                                return (current, false, previousHash)
                            }
                        } else {
                            return (.fetching, true, nil)
                        }
                }
            }
            |> mapToSignal { result, loadRemote, previousHash in
                if loadRemote || forceRemote {
                    let appliedRemote = updatedRemoteStickerPack(postbox: postbox, network: network, reference: reference)
                    |> mapToSignal { result -> Signal<CachedStickerPackResult, NoError> in
                        if let result = result, result.0.hash == previousHash {
                            return .complete()
                        }
                        return postbox.transaction { transaction -> CachedStickerPackResult in
                            if let result = result {
                                cacheStickerPack(transaction: transaction, info: result.0, items: result.1, reference: reference)
                                let currentInfo = transaction.getItemCollectionInfo(collectionId: result.0.id) as? StickerPackCollectionInfo
                                return .result(result.0, result.1, currentInfo != nil)
                            } else {
                                return .none
                            }
                        }
                    }
                    return .single(result)
                    |> then(appliedRemote)
                } else {
                    return .single(result)
                }
            }
        }
    }
}
    
func cachedStickerPack(transaction: Transaction, reference: StickerPackReference) -> (StickerPackCollectionInfo, [StickerPackItem], Bool)? {
    let namespaces: [Int32] = [Namespaces.ItemCollection.CloudStickerPacks, Namespaces.ItemCollection.CloudMaskPacks]
    switch reference {
        case let .id(id, _):
            for namespace in namespaces {
                if let currentInfo = transaction.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: namespace, id: id)) as? StickerPackCollectionInfo {
                    let items = transaction.getItemCollectionItems(collectionId: ItemCollectionId(namespace: namespace, id: id))
                    if !items.isEmpty {
                        return (currentInfo, items.compactMap { $0 as? StickerPackItem }, true)
                    }
                }
                if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id))))?.get(CachedStickerPack.self), let info = cached.info {
                    return (info, cached.items, false)
                }
            }
        case let .name(shortName):
            for namespace in namespaces {
                for info in transaction.getItemCollectionsInfos(namespace: namespace) {
                    if let info = info.1 as? StickerPackCollectionInfo {
                        if info.shortName == shortName {
                            let items = transaction.getItemCollectionItems(collectionId: info.id)
                            if !items.isEmpty {
                                return (info, items.compactMap { $0 as? StickerPackItem }, true)
                            }
                        }
                    }
                }
            }
            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(shortName: shortName.lowercased())))?.get(CachedStickerPack.self), let info = cached.info {
                return (info, cached.items, false)
            }
        case .animatedEmoji:
            let namespace = Namespaces.ItemCollection.CloudAnimatedEmoji
            let id: ItemCollectionId.Id = 0
            if let currentInfo = transaction.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: namespace, id: id)) as? StickerPackCollectionInfo {
                let items = transaction.getItemCollectionItems(collectionId: ItemCollectionId(namespace: namespace, id: id))
                if !items.isEmpty {
                    return (currentInfo, items.compactMap { $0 as? StickerPackItem }, true)
                }
            }
            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id))))?.get(CachedStickerPack.self), let info = cached.info {
                return (info, cached.items, false)
            }
        case let .dice(emoji):
            let namespace = Namespaces.ItemCollection.CloudDice
            let id: ItemCollectionId.Id = Int64(murMurHashString32(emoji))
            if let currentInfo = transaction.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: namespace, id: id)) as? StickerPackCollectionInfo {
                let items = transaction.getItemCollectionItems(collectionId: ItemCollectionId(namespace: namespace, id: id))
                if !items.isEmpty {
                    return (currentInfo, items.compactMap { $0 as? StickerPackItem }, true)
                }
            }
            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id))))?.get(CachedStickerPack.self), let info = cached.info {
                return (info, cached.items, false)
            }
        case .animatedEmojiAnimations:
            let namespace = Namespaces.ItemCollection.CloudAnimatedEmojiAnimations
            let id: ItemCollectionId.Id = 0
            if let currentInfo = transaction.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: namespace, id: id)) as? StickerPackCollectionInfo {
                let items = transaction.getItemCollectionItems(collectionId: ItemCollectionId(namespace: namespace, id: id))
                if !items.isEmpty {
                    return (currentInfo, items.compactMap { $0 as? StickerPackItem }, true)
                }
            }
            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id))))?.get(CachedStickerPack.self), let info = cached.info {
                return (info, cached.items, false)
            }
    }
    return nil
}

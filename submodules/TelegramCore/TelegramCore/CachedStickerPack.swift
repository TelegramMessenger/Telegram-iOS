import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

final class CachedStickerPack: PostboxCoding {
    let info: StickerPackCollectionInfo?
    let items: [StickerPackItem]
    let hash: Int32
    
    init(info: StickerPackCollectionInfo?, items: [StickerPackItem], hash: Int32) {
        self.info = info
        self.items = items
        self.hash = hash
    }
    
    init(decoder: PostboxDecoder) {
        self.info = decoder.decodeObjectForKey("in", decoder: { StickerPackCollectionInfo(decoder: $0) }) as? StickerPackCollectionInfo
        self.items = decoder.decodeObjectArrayForKey("it").map { $0 as! StickerPackItem }
        self.hash = decoder.decodeInt32ForKey("h", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let info = self.info {
            encoder.encodeObject(info, forKey: "in")
        } else {
            encoder.encodeNil(forKey: "in")
        }
        encoder.encodeObjectArray(self.items, forKey: "it")
        encoder.encodeInt32(self.hash, forKey: "h")
    }
    
    static func cacheKey(_ id: ItemCollectionId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: id.namespace)
        key.setInt64(4, value: id.id)
        return key
    }
    
    static func cacheKey(shortName: String) -> ValueBoxKey {
        return ValueBoxKey(shortName)
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 100, highWaterItemCount: 200)

public enum CachedStickerPackResult {
    case none
    case fetching
    case result(StickerPackCollectionInfo, [ItemCollectionItem], Bool)
}

func cacheStickerPack(transaction: Transaction, info: StickerPackCollectionInfo, items: [ItemCollectionItem], reference: StickerPackReference? = nil) {
    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(info.id)), entry: CachedStickerPack(info: info, items: items.map { $0 as! StickerPackItem }, hash: info.hash), collectionSpec: collectionSpec)
    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(shortName: info.shortName)), entry: CachedStickerPack(info: info, items: items.map { $0 as! StickerPackItem }, hash: info.hash), collectionSpec: collectionSpec)
    
    if let reference = reference, case .animatedEmoji = reference {
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: Namespaces.ItemCollection.CloudAnimatedEmoji, id: 0))), entry: CachedStickerPack(info: info, items: items.map { $0 as! StickerPackItem }, hash: info.hash), collectionSpec: collectionSpec)
    }
}

public func cachedStickerPack(postbox: Postbox, network: Network, reference: StickerPackReference, forceRemote: Bool) -> Signal<CachedStickerPackResult, NoError> {
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
                        if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id)))) as? CachedStickerPack, let info = cached.info {
                            previousHash = cached.hash
                            let current: CachedStickerPackResult = .result(info, cached.items, false)
                            if cached.hash != info.hash {
                                return (current, true, previousHash)
                            } else {
                                return (current, true, previousHash)
                            }
                        } else {
                            return (.fetching, true, nil)
                        }
                    case let .name(shortName):
                        if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(shortName: shortName))) as? CachedStickerPack, let info = cached.info {
                            previousHash = cached.hash
                            let current: CachedStickerPackResult = .result(info, cached.items, false)
                            if cached.hash != info.hash {
                                return (current, true, previousHash)
                            } else {
                                return (current, true, previousHash)
                            }
                        } else {
                            return (.fetching, true, nil)
                        }
                    case .animatedEmoji:
                        let namespace = Namespaces.ItemCollection.CloudAnimatedEmoji
                        let id: ItemCollectionId.Id = 0
                        if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id)))) as? CachedStickerPack, let info = cached.info {
                            previousHash = cached.hash
                            let current: CachedStickerPackResult = .result(info, cached.items, false)
                            if cached.hash != info.hash {
                                return (current, true, previousHash)
                            } else {
                                return (current, true, previousHash)
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
    
func cachedStickerPack(transaction: Transaction, reference: StickerPackReference) -> (StickerPackCollectionInfo, [ItemCollectionItem], Bool)? {
    let namespace = Namespaces.ItemCollection.CloudStickerPacks
    switch reference {
        case let .id(id, _):
            if let currentInfo = transaction.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: namespace, id: id)) as? StickerPackCollectionInfo {
                let items = transaction.getItemCollectionItems(collectionId: ItemCollectionId(namespace: namespace, id: id))
                if !items.isEmpty {
                    return (currentInfo, items, true)
                }
            }
            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id)))) as? CachedStickerPack, let info = cached.info {
                return (info, cached.items, false)
            }
        case let .name(shortName):
            for info in transaction.getItemCollectionsInfos(namespace: namespace) {
                if let info = info.1 as? StickerPackCollectionInfo {
                    if info.shortName == shortName {
                        let items = transaction.getItemCollectionItems(collectionId: info.id)
                        if !items.isEmpty {
                            return (info, items, true)
                        }
                    }
                }
            }
            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(shortName: shortName))) as? CachedStickerPack, let info = cached.info {
                return (info, cached.items, false)
            }
        case .animatedEmoji:
            let namespace = Namespaces.ItemCollection.CloudAnimatedEmoji
            let id: ItemCollectionId.Id = 0
            if let currentInfo = transaction.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: namespace, id: id)) as? StickerPackCollectionInfo {
                let items = transaction.getItemCollectionItems(collectionId: ItemCollectionId(namespace: namespace, id: id))
                if !items.isEmpty {
                    return (currentInfo, items, true)
                }
            }
            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(ItemCollectionId(namespace: namespace, id: id)))) as? CachedStickerPack, let info = cached.info {
                return (info, cached.items, false)
            }
    }
    return nil
}

import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private final class CachedStickerPack: Coding {
    let items: [StickerPackItem]
    let hash: Int32
    
    init(items: [StickerPackItem], hash: Int32) {
        self.items = items
        self.hash = hash
    }
    
    init(decoder: Decoder) {
        self.items = decoder.decodeObjectArrayForKey("it").map { $0 as! StickerPackItem }
        self.hash = decoder.decodeInt32ForKey("h", orElse: 0)
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeObjectArray(self.items, forKey: "it")
        encoder.encodeInt32(self.hash, forKey: "h")
    }
    
    static func cacheKey(_ info: StickerPackCollectionInfo) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: info.id.namespace)
        key.setInt64(4, value: info.id.id)
        return key
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 100, highWaterItemCount: 200)

public func cachedStickerPack(postbox: Postbox, network: Network, info: StickerPackCollectionInfo) -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem])?, NoError> {
    return postbox.modify { modifier -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem])?, NoError> in
        if let currentInfo = modifier.getItemCollectionInfo(collectionId: info.id) as? StickerPackCollectionInfo {
            let items = modifier.getItemCollectionItems(collectionId: info.id)
            return .single((currentInfo, items))
        } else {
            let current: Signal<(StickerPackCollectionInfo, [ItemCollectionItem])?, NoError>
            var loadRemote = false
            
            if let cached = modifier.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(info))) as? CachedStickerPack {
                current = .single((info, cached.items))
                if cached.hash != info.hash {
                    loadRemote = true
                }
            } else {
                current = .complete()
                loadRemote = true
            }
            
            var signal = current
            if loadRemote {
                let appliedRemote = remoteStickerPack(network: network, reference: .id(id: info.id.id, accessHash: info.accessHash))
                    |> mapToSignal { result -> Signal<(StickerPackCollectionInfo, [ItemCollectionItem])?, NoError> in
                        return postbox.modify { modifier -> (StickerPackCollectionInfo, [ItemCollectionItem])? in
                            if let result = result {
                                modifier.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStickerPacks, key: CachedStickerPack.cacheKey(result.0)), entry: CachedStickerPack(items: result.1.map { $0 as! StickerPackItem }, hash: result.0.hash), collectionSpec: collectionSpec)
                            }
                            
                            return result
                        }
                    }
                
                signal = signal |> then(appliedRemote)
            }
            
            return signal
        }
    } |> switchToLatest
}

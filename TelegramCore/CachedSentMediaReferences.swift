import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private let cachedSentMediaCollectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 10000, highWaterItemCount: 20000)

enum CachedSentMediaReferenceKey {
    case image(hash: Data)
    case file(hash: Data)
    
    var key: ValueBoxKey {
        switch self {
            case let .image(hash):
                let result = ValueBoxKey(length: 1 + hash.count)
                result.setUInt8(0, value: 0)
                hash.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                    memcpy(result.memory.advanced(by: 1), bytes, hash.count)
                }
                return result
            case let .file(hash):
                let result = ValueBoxKey(length: 1 + hash.count)
                result.setUInt8(0, value: 1)
                hash.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                    memcpy(result.memory.advanced(by: 1), bytes, hash.count)
                }
                return result
        }
    }
}

func cachedSentMediaReference(postbox: Postbox, key: CachedSentMediaReferenceKey) -> Signal<Media?, NoError> {
    return postbox.modify { modifier -> Media? in
        return modifier.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedSentMediaReferences, key: key.key)) as? Media
    }
}

func storeCachedSentMediaReference(modifier: Modifier, key: CachedSentMediaReferenceKey, media: Media) {
    modifier.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedSentMediaReferences, key: key.key), entry: media, collectionSpec: cachedSentMediaCollectionSpec)
}

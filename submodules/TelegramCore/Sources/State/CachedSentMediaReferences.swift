import Foundation
import Postbox
import SwiftSignalKit

enum CachedSentMediaReferenceKey {
    case image(hash: Data)
    case file(hash: Data)
    
    var key: ValueBoxKey {
        switch self {
            case let .image(hash):
                let result = ValueBoxKey(length: 1 + hash.count)
                result.setUInt8(0, value: 0)
                hash.withUnsafeBytes { rawBytes -> Void in
                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)
                    memcpy(result.memory.advanced(by: 1), bytes, hash.count)
                }
                return result
            case let .file(hash):
                let result = ValueBoxKey(length: 1 + hash.count)
                result.setUInt8(0, value: 1)
                hash.withUnsafeBytes { rawBytes -> Void in
                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)
                    memcpy(result.memory.advanced(by: 1), bytes, hash.count)
                }
                return result
        }
    }
}

private struct CachedMediaReferenceEntry: Codable {
    var data: Data
}

func cachedSentMediaReference(postbox: Postbox, key: CachedSentMediaReferenceKey) -> Signal<Media?, NoError> {
    return postbox.transaction { transaction -> Media? in
        guard let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedSentMediaReferences, key: key.key))?.get(CachedMediaReferenceEntry.self) else {
            return nil
        }
        
        return PostboxDecoder(buffer: MemoryBuffer(data: entry.data)).decodeRootObject() as? Media
    }
}

func storeCachedSentMediaReference(transaction: Transaction, key: CachedSentMediaReferenceKey, media: Media) {
    let encoder = PostboxEncoder()
    encoder.encodeRootObject(media)
    let mediaData = encoder.makeData()
    
    guard let entry = CodableEntry(CachedMediaReferenceEntry(data: mediaData)) else {
        return
    }
    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedSentMediaReferences, key: key.key), entry: entry)
}

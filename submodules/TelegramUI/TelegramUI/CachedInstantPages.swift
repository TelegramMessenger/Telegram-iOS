import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences

final class CachedInstantPage: PostboxCoding {
    let webPage: TelegramMediaWebpage
    let timestamp: Int32
    
    init(webPage: TelegramMediaWebpage, timestamp: Int32) {
        self.webPage = webPage
        self.timestamp = timestamp
    }
    
    init(decoder: PostboxDecoder) {
        self.webPage = decoder.decodeObjectForKey("webpage", decoder: { TelegramMediaWebpage(decoder: $0) }) as! TelegramMediaWebpage
        self.timestamp = decoder.decodeInt32ForKey("timestamp", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.webPage, forKey: "webpage")
        encoder.encodeInt32(self.timestamp, forKey: "timestamp")
    }
}

func cachedInstantPage(postbox: Postbox, url: String) -> Signal<CachedInstantPage?, NoError> {
    return postbox.transaction { transaction -> CachedInstantPage? in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: Int64(bitPattern: url.persistentHashValue))
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedInstantPages, key: key)) as? CachedInstantPage {
            return entry
        } else {
            return nil
        }
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 5, highWaterItemCount: 10)

func updateCachedInstantPage(postbox: Postbox, url: String, webPage: TelegramMediaWebpage?) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: Int64(bitPattern: url.persistentHashValue))
        let id = ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedInstantPages, key: key)
        if let webPage = webPage {
            transaction.putItemCacheEntry(id: id, entry: CachedInstantPage(webPage: webPage, timestamp: Int32(CFAbsoluteTimeGetCurrent())), collectionSpec: collectionSpec)
        } else {
            transaction.removeItemCacheEntry(id: id)
        }
    }
}

import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

final class CachedInstantPage: PostboxCoding {
    let webPage: TelegramMediaWebpage
    
    init(webPage: TelegramMediaWebpage) {
        self.webPage = webPage
    }
    
    init(decoder: PostboxDecoder) {
        self.webPage = decoder.decodeObjectForKey("webpage", decoder: { TelegramMediaWebpage(decoder: $0) }) as! TelegramMediaWebpage
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.webPage, forKey: "webpage")
    }
}

func cachedInstantPage(postbox: Postbox, url: String) -> Signal<CachedInstantPage?, NoError> {
    return postbox.transaction { transaction -> CachedInstantPage? in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: Int64(url.hashValue))
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
        key.setInt64(0, value: Int64(url.hashValue))
        let id = ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedInstantPages, key: key)
        if let webPage = webPage {
            transaction.putItemCacheEntry(id: id, entry: CachedInstantPage(webPage: webPage), collectionSpec: collectionSpec)
        } else {
            transaction.removeItemCacheEntry(id: id)
        }
    }
}

import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramUIPreferences
import PersistentStringHash

public final class CachedInstantPage: PostboxCoding {
    public let webPage: TelegramMediaWebpage
    public let timestamp: Int32
    
    public init(webPage: TelegramMediaWebpage, timestamp: Int32) {
        self.webPage = webPage
        self.timestamp = timestamp
    }
    
    public init(decoder: PostboxDecoder) {
        self.webPage = decoder.decodeObjectForKey("webpage", decoder: { TelegramMediaWebpage(decoder: $0) }) as! TelegramMediaWebpage
        self.timestamp = decoder.decodeInt32ForKey("timestamp", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.webPage, forKey: "webpage")
        encoder.encodeInt32(self.timestamp, forKey: "timestamp")
    }
}

public func cachedInstantPage(postbox: Postbox, url: String) -> Signal<CachedInstantPage?, NoError> {
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

public func updateCachedInstantPage(postbox: Postbox, url: String, webPage: TelegramMediaWebpage?) -> Signal<Void, NoError> {
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

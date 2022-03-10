import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import PersistentStringHash

public final class CachedInstantPage: Codable {
    public let webPage: TelegramMediaWebpage
    public let timestamp: Int32
    
    public init(webPage: TelegramMediaWebpage, timestamp: Int32) {
        self.webPage = webPage
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        let webPageData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: "webpage")
        self.webPage = TelegramMediaWebpage(decoder: PostboxDecoder(buffer: MemoryBuffer(data: webPageData.data)))

        self.timestamp = try container.decode(Int32.self, forKey: "timestamp")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(PostboxEncoder().encodeObjectToRawData(self.webPage), forKey: "webpage")
        try container.encode(self.timestamp, forKey: "timestamp")
    }
}

public func cachedInstantPage(postbox: Postbox, url: String) -> Signal<CachedInstantPage?, NoError> {
    return postbox.transaction { transaction -> CachedInstantPage? in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: Int64(bitPattern: url.persistentHashValue))
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedInstantPages, key: key))?.get(CachedInstantPage.self) {
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
        if let webPage = webPage, let entry = CodableEntry(CachedInstantPage(webPage: webPage, timestamp: Int32(CFAbsoluteTimeGetCurrent()))) {
            transaction.putItemCacheEntry(id: id, entry: entry, collectionSpec: collectionSpec)
        } else {
            transaction.removeItemCacheEntry(id: id)
        }
    }
}

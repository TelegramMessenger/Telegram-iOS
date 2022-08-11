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

public func cachedInstantPage(engine: TelegramEngine, url: String) -> Signal<CachedInstantPage?, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: Int64(bitPattern: url.persistentHashValue))
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.cachedInstantPages, id: key))
    |> map { entry -> CachedInstantPage? in
        return entry?.get(CachedInstantPage.self)
    }
}

public func updateCachedInstantPage(engine: TelegramEngine, url: String, webPage: TelegramMediaWebpage?) -> Signal<Never, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: Int64(bitPattern: url.persistentHashValue))
    
    if let webPage = webPage {
        return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.cachedInstantPages, id: key, item: CachedInstantPage(webPage: webPage, timestamp: Int32(CFAbsoluteTimeGetCurrent())))
    } else {
        return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.cachedInstantPages, id: key)
    }
}

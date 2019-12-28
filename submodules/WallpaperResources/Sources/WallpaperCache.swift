import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramApi
import TelegramCore
import SyncCore
import TelegramUIPreferences
import PersistentStringHash

public final class CachedWallpaper: PostboxCoding {
    public let wallpaper: TelegramWallpaper
    
    public init(wallpaper: TelegramWallpaper) {
        self.wallpaper = wallpaper
    }
    
    public init(decoder: PostboxDecoder) {
        self.wallpaper = decoder.decodeObjectForKey("wallpaper", decoder: { TelegramWallpaper(decoder: $0) }) as! TelegramWallpaper
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.wallpaper, forKey: "wallpaper")
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 10000, highWaterItemCount: 20000)

public func cachedWallpaper(account: Account, slug: String, settings: WallpaperSettings?) -> Signal<CachedWallpaper?, NoError> {
    return account.postbox.transaction { transaction -> Signal<CachedWallpaper?, NoError> in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: Int64(bitPattern: slug.persistentHashValue))
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedWallpapers, key: key)) as? CachedWallpaper {
            if let settings = settings {
                return .single(CachedWallpaper(wallpaper: entry.wallpaper.withUpdatedSettings(settings)))
            } else {
                return .single(entry)
            }
        } else {
            return getWallpaper(network: account.network, slug: slug)
            |> map(Optional.init)
            |> `catch` { _ -> Signal<TelegramWallpaper?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { wallpaper -> Signal<CachedWallpaper?, NoError> in
                return account.postbox.transaction { transaction -> CachedWallpaper? in
                    let key = ValueBoxKey(length: 8)
                    key.setInt64(0, value: Int64(bitPattern: slug.persistentHashValue))
                    let id = ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedWallpapers, key: key)
                    if let wallpaper = wallpaper {
                        let entry = CachedWallpaper(wallpaper: wallpaper)
                        transaction.putItemCacheEntry(id: id, entry: entry, collectionSpec: collectionSpec)
                        if let settings = settings {
                            return CachedWallpaper(wallpaper: wallpaper.withUpdatedSettings(settings))
                        } else {
                            return CachedWallpaper(wallpaper: wallpaper)
                        }
                    } else {
                        transaction.removeItemCacheEntry(id: id)
                        return nil
                    }
                }
            }
        }
    } |> switchToLatest
}

public func updateCachedWallpaper(account: Account, wallpaper: TelegramWallpaper) {
    guard case let .file(file) = wallpaper, file.id != 0 else {
        return
    }
    let _ = (account.postbox.transaction { transaction in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: Int64(bitPattern: file.slug.persistentHashValue))
        let id = ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.cachedWallpapers, key: key)
        transaction.putItemCacheEntry(id: id, entry: CachedWallpaper(wallpaper: wallpaper), collectionSpec: collectionSpec)
    }).start()
}

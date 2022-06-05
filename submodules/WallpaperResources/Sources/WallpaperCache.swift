import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramApi
import TelegramCore
import TelegramUIPreferences
import PersistentStringHash

public final class CachedWallpaper: Codable {
    public let wallpaper: TelegramWallpaper
    
    public init(wallpaper: TelegramWallpaper) {
        self.wallpaper = wallpaper
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.wallpaper = (try container.decode(TelegramWallpaperNativeCodable.self, forKey: "wallpaper")).value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(TelegramWallpaperNativeCodable(self.wallpaper), forKey: "wallpaper")
    }
}

public func cachedWallpaper(account: Account, slug: String, settings: WallpaperSettings?, update: Bool = false) -> Signal<CachedWallpaper?, NoError> {
    let engine = TelegramEngine(account: account)
    
    let slugKey = ValueBoxKey(length: 8)
    slugKey.setInt64(0, value: Int64(bitPattern: slug.persistentHashValue))
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.cachedWallpapers, id: slugKey))
    |> mapToSignal { entry -> Signal<CachedWallpaper?, NoError> in
        if !update, let entry = entry?.get(CachedWallpaper.self) {
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
                let slugKey = ValueBoxKey(length: 8)
                slugKey.setInt64(0, value: Int64(bitPattern: slug.persistentHashValue))
                
                if var wallpaper = wallpaper {
                    switch wallpaper {
                    case let .file(file):
                        wallpaper = .file(TelegramWallpaper.File(id: file.id, accessHash: file.accessHash, isCreator: file.isCreator, isDefault: file.isDefault, isPattern: file.isPattern, isDark: file.isDark, slug: file.slug, file: file.file.withUpdatedResource(WallpaperDataResource(slug: slug)), settings: file.settings))
                    default:
                        break
                    }
                    
                    let result: CachedWallpaper
                    if let settings = settings {
                        result = CachedWallpaper(wallpaper: wallpaper.withUpdatedSettings(settings))
                    } else {
                        result = CachedWallpaper(wallpaper: wallpaper)
                    }
                    return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.cachedWallpapers, id: slugKey, item: CachedWallpaper(wallpaper: wallpaper))
                    |> map { _ -> CachedWallpaper? in }
                    |> then(.single(result))
                } else {
                    return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.cachedWallpapers, id: slugKey)
                    |> map { _ -> CachedWallpaper? in }
                    |> then(.single(nil))
                }
            }
        }
    }
}

public func updateCachedWallpaper(engine: TelegramEngine, wallpaper: TelegramWallpaper) {
    guard case let .file(file) = wallpaper, file.id != 0 else {
        return
    }
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: Int64(bitPattern: file.slug.persistentHashValue))
    
    let _ = engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.cachedWallpapers, id: key, item: CachedWallpaper(wallpaper: wallpaper)).start()
}

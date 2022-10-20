import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences

private struct WallpaperSearchRecentQueryItemId {
    public let rawValue: MemoryBuffer
    
    var value: String {
        return String(data: self.rawValue.makeData(), encoding: .utf8) ?? ""
    }
    
    init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
    }
    
    init?(_ value: String) {
        if let data = value.data(using: .utf8) {
            self.rawValue = MemoryBuffer(data: data)
        } else {
            return nil
        }
    }
}

public final class RecentWallpaperSearchQueryItem: Codable {
    public init() {
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public func encode(to encoder: Encoder) throws {
    }
}

func addRecentWallpaperSearchQuery(engine: TelegramEngine, string: String) -> Signal<Never, NoError> {
    if let itemId = WallpaperSearchRecentQueryItemId(string) {
        return engine.orderedLists.addOrMoveToFirstPosition(collectionId: ApplicationSpecificOrderedItemListCollectionId.wallpaperSearchRecentQueries, id: itemId.rawValue, item: RecentWallpaperSearchQueryItem(), removeTailIfCountExceeds: 100)
    } else {
        return .complete()
    }
}

func removeRecentWallpaperSearchQuery(engine: TelegramEngine, string: String) -> Signal<Never, NoError> {
    if let itemId = WallpaperSearchRecentQueryItemId(string) {
        return engine.orderedLists.removeItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.wallpaperSearchRecentQueries, id: itemId.rawValue)
    } else {
        return .complete()
    }
}

func clearRecentWallpaperSearchQueries(engine: TelegramEngine) -> Signal<Never, NoError> {
    return engine.orderedLists.clear(collectionId: ApplicationSpecificOrderedItemListCollectionId.wallpaperSearchRecentQueries)
}

func wallpaperSearchRecentQueries(engine: TelegramEngine) -> Signal<[String], NoError> {
    return engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.wallpaperSearchRecentQueries))
    |> map { items -> [String] in
        var result: [String] = []
        for item in items {
            let value = WallpaperSearchRecentQueryItemId(item.id).value
            result.append(value)
        }
        return result
    }
}

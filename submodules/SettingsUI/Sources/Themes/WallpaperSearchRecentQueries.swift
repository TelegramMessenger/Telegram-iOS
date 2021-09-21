import Foundation
import Postbox
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

func addRecentWallpaperSearchQuery(postbox: Postbox, string: String) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        if let itemId = WallpaperSearchRecentQueryItemId(string) {
            if let entry = CodableEntry(RecentWallpaperSearchQueryItem()) {
                transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.wallpaperSearchRecentQueries, item: OrderedItemListEntry(id: itemId.rawValue, contents: entry), removeTailIfCountExceeds: 100)
            }
        }
    }
}

func removeRecentWallpaperSearchQuery(postbox: Postbox, string: String) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let itemId = WallpaperSearchRecentQueryItemId(string) {
            transaction.removeOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.wallpaperSearchRecentQueries, itemId: itemId.rawValue)
        }
    }
}

func clearRecentWallpaperSearchQueries(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.replaceOrderedItemListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.wallpaperSearchRecentQueries, items: [])
    }
}

func wallpaperSearchRecentQueries(postbox: Postbox) -> Signal<[String], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: ApplicationSpecificOrderedItemListCollectionId.wallpaperSearchRecentQueries)])
        |> mapToSignal { view -> Signal<[String], NoError> in
            return postbox.transaction { transaction -> [String] in
                var result: [String] = []
                if let view = view.views[.orderedItemList(id: ApplicationSpecificOrderedItemListCollectionId.wallpaperSearchRecentQueries)] as? OrderedItemListView {
                    for item in view.items {
                        let value = WallpaperSearchRecentQueryItemId(item.id).value
                        result.append(value)
                    }
                }
                return result
            }
    }
}

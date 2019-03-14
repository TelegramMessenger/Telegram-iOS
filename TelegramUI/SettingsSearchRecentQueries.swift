import Foundation
import Postbox
import SwiftSignalKit

private struct SettingsSearchRecentQueryItemId {
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

final class RecentSettingsSearchQueryItem: OrderedItemListEntryContents {
    init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
}

func addRecentSettingsSearchItem(postbox: Postbox, item: SettingsSearchableItem) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
//        if let itemId = WallpaperSearchRecentQueryItemId(string) {
//            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, item: OrderedItemListEntry(id: itemId.rawValue, contents: RecentWallpaperSearchQueryItem()), removeTailIfCountExceeds: 100)
//        }
    }
}

func removeRecentSettingsSearchItem(postbox: Postbox, item: SettingsSearchableItem) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
//        if let itemId = WallpaperSearchRecentQueryItemId(string) {
//            transaction.removeOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, itemId: itemId.rawValue)
//        }
    }
}

func clearRecentSettingsSearchItems(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.replaceOrderedItemListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, items: [])
    }
}

func settingsSearchRecentQueries(postbox: Postbox) -> Signal<[String], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems)])
    |> mapToSignal { view -> Signal<[String], NoError> in
        return postbox.transaction { transaction -> [String] in
            var result: [String] = []
//            if let view = view.views[.orderedItemList(id: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems)] as? OrderedItemListView {
//                for item in view.items {
//                    let value = WallpaperSearchRecentQueryItemId(item.id).value
//                    result.append(value)
//                }
//            }
            return result
        }
    }
}

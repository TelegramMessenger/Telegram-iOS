import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences

private struct SettingsSearchRecentQueryItemId {
    public let rawValue: MemoryBuffer
    
    var value: Int64 {
        return self.rawValue.makeData().withUnsafeBytes { buffer -> Int64 in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: Int64.self) else {
                return 0
            }
            return bytes.pointee
        }
    }
    
    init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
    }
    
    init(_ value: Int64) {
        var value = value
        self.rawValue = MemoryBuffer(data: Data(bytes: &value, count: MemoryLayout.size(ofValue: value)))
    }
}

public final class RecentSettingsSearchQueryItem: Codable {
    public init() {
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public func encode(to encoder: Encoder) throws {
    }
}

func addRecentSettingsSearchItem(engine: TelegramEngine, item: SettingsSearchableItemId) {
    let itemId = SettingsSearchRecentQueryItemId(item.index)
    let _ = engine.orderedLists.addOrMoveToFirstPosition(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, id: itemId.rawValue, item: RecentSettingsSearchQueryItem(), removeTailIfCountExceeds: 100).start()
}

func removeRecentSettingsSearchItem(engine: TelegramEngine, item: SettingsSearchableItemId) {
    let itemId = SettingsSearchRecentQueryItemId(item.index)
    let _ = engine.orderedLists.removeItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, id: itemId.rawValue).start()
}

func clearRecentSettingsSearchItems(engine: TelegramEngine) {
    let _ = engine.orderedLists.clear(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems).start()
}

func settingsSearchRecentItems(postbox: Postbox) -> Signal<[SettingsSearchableItemId], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems)])
    |> map { view -> [SettingsSearchableItemId] in
        var result: [SettingsSearchableItemId] = []
        if let view = view.views[.orderedItemList(id: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems)] as? OrderedItemListView {
            for item in view.items {
                let index = SettingsSearchRecentQueryItemId(item.id).value
                if let itemId = SettingsSearchableItemId(index: index) {
                    result.append(itemId)
                }
            }
        }
        return result
    }
}

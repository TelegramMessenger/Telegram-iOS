import Foundation
import UIKit
import Postbox
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

func addRecentSettingsSearchItem(postbox: Postbox, item: SettingsSearchableItemId) {
    let _ = (postbox.transaction { transaction in
        let itemId = SettingsSearchRecentQueryItemId(item.index)
        if let entry = CodableEntry(RecentSettingsSearchQueryItem()) {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, item: OrderedItemListEntry(id: itemId.rawValue, contents: entry), removeTailIfCountExceeds: 100)
        }
    }).start()
}

func removeRecentSettingsSearchItem(postbox: Postbox, item: SettingsSearchableItemId) {
    let _ = (postbox.transaction { transaction -> Void in
        let itemId = SettingsSearchRecentQueryItemId(item.index)
        transaction.removeOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, itemId: itemId.rawValue)
    }).start()
}

func clearRecentSettingsSearchItems(postbox: Postbox) {
    let _ = (postbox.transaction { transaction -> Void in
        transaction.replaceOrderedItemListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, items: [])
    }).start()
}

func settingsSearchRecentItems(postbox: Postbox) -> Signal<[SettingsSearchableItemId], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems)])
    |> mapToSignal { view -> Signal<[SettingsSearchableItemId], NoError> in
        return postbox.transaction { transaction -> [SettingsSearchableItemId] in
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
}

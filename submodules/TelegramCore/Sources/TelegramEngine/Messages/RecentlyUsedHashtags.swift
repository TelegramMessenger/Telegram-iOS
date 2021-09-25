import Foundation
import Postbox
import SwiftSignalKit


private struct RecentHashtagItemId {
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

func addRecentlyUsedHashtag(transaction: Transaction, string: String) {
    if let itemId = RecentHashtagItemId(string) {
        if let entry = CodableEntry(RecentHashtagItem()) {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlyUsedHashtags, item: OrderedItemListEntry(id: itemId.rawValue, contents: entry), removeTailIfCountExceeds: 100)
        }
    }
}

func _internal_removeRecentlyUsedHashtag(postbox: Postbox, string: String) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let itemId = RecentHashtagItemId(string) {
            transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlyUsedHashtags, itemId: itemId.rawValue)
        }
    }
}

func _internal_recentlyUsedHashtags(postbox: Postbox) -> Signal<[String], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.RecentlyUsedHashtags)])
        |> mapToSignal { view -> Signal<[String], NoError> in
            return postbox.transaction { transaction -> [String] in
                var result: [String] = []
                if let view = view.views[.orderedItemList(id: Namespaces.OrderedItemList.RecentlyUsedHashtags)] as? OrderedItemListView {
                    for item in view.items {
                        let value = RecentHashtagItemId(item.id).value
                        result.append(value)
                    }
                }
                return result
            }
    }
}


import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import TelegramUIPreferences

private struct WebSearchRecentQueryItemId {
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

public final class RecentWebSearchQueryItem: Codable {
    init() {
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public func encode(to encoder: Encoder) throws {
    }
}

func addRecentWebSearchQuery(postbox: Postbox, string: String) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        if let itemId = WebSearchRecentQueryItemId(string) {
            if let entry = CodableEntry(RecentWebSearchQueryItem()) {
                transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.webSearchRecentQueries, item: OrderedItemListEntry(id: itemId.rawValue, contents: entry), removeTailIfCountExceeds: 100)
            }
        }
    }
}

func removeRecentWebSearchQuery(postbox: Postbox, string: String) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let itemId = WebSearchRecentQueryItemId(string) {
            transaction.removeOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.webSearchRecentQueries, itemId: itemId.rawValue)
        }
    }
}

func clearRecentWebSearchQueries(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.replaceOrderedItemListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.webSearchRecentQueries, items: [])
    }
}

func webSearchRecentQueries(postbox: Postbox) -> Signal<[String], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: ApplicationSpecificOrderedItemListCollectionId.webSearchRecentQueries)])
        |> mapToSignal { view -> Signal<[String], NoError> in
            return postbox.transaction { transaction -> [String] in
                var result: [String] = []
                if let view = view.views[.orderedItemList(id: ApplicationSpecificOrderedItemListCollectionId.webSearchRecentQueries)] as? OrderedItemListView {
                    for item in view.items {
                        let value = WebSearchRecentQueryItemId(item.id).value
                        result.append(value)
                    }
                }
                return result
            }
    }
}

import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class OrderedLists {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func addOrMoveToFirstPosition<T: Codable>(collectionId: Int32, id: MemoryBuffer, item: T, removeTailIfCountExceeds: Int?) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                if let entry = CodableEntry(item) {
                    transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: collectionId, item: OrderedItemListEntry(id: id, contents: entry), removeTailIfCountExceeds: removeTailIfCountExceeds)
                }
            }
            |> ignoreValues
        }
        
        public func clear(collectionId: Int32) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.replaceOrderedItemListItems(collectionId: collectionId, items: [])
            }
            |> ignoreValues
        }
        
        public func removeItem(collectionId: Int32, id: MemoryBuffer) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.removeOrderedItemListItem(collectionId: collectionId, itemId: id)
            }
            |> ignoreValues
        }
    }
}

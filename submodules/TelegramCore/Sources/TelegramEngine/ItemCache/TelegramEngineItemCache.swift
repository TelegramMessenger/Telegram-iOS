import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class ItemCache {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func put<T: Codable>(collectionId: Int8, id: ValueBoxKey, item: T) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                if let entry = CodableEntry(item) {
                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: collectionId, key: id), entry: entry)
                }
            }
            |> ignoreValues
        }
        
        public func remove(collectionId: Int8, id: ValueBoxKey) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.removeItemCacheEntry(id: ItemCacheEntryId(collectionId: collectionId, key: id))
            }
            |> ignoreValues
        }
        
        public func clear(collectionIds: [Int8]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for id in collectionIds {
                    transaction.clearItemCacheCollection(collectionId: id)
                }
            }
            |> ignoreValues
        }
    }
}

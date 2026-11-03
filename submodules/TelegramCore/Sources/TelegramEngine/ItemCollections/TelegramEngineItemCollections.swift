import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class ItemCollections {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func allItems(namespace: ItemCollectionId.Namespace) -> Signal<[EngineRawItemCollectionItem], NoError> {
            return self.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [namespace], aroundIndex: nil, count: 10000000)
            |> map { view -> [EngineRawItemCollectionItem] in
                return view.entries.map { $0.item }
            }
        }
    }
}

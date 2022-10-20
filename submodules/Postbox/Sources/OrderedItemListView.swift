import Foundation

final class MutableOrderedItemListView: MutablePostboxView {
    let collectionId: Int32
    var items: [OrderedItemListEntry]
    
    init(postbox: PostboxImpl, collectionId: Int32) {
        self.collectionId = collectionId
        self.items = postbox.orderedItemListTable.getItems(collectionId: collectionId)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if let operations = transaction.currentOrderedItemListOperations[self.collectionId] {
            for operation in operations {
                switch operation {
                    case let .replace(items):
                        self.items = items
                        updated = true
                    case let .addOrMoveToFirstPosition(item, maxCount):
                        if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                            self.items.remove(at: index)
                            self.items.insert(item, at: 0)
                        } else {
                            self.items.insert(item, at: 0)
                            if let maxCount = maxCount, self.items.count > maxCount {
                                self.items.removeLast()
                            }
                        }
                        updated = true
                    case let .remove(itemId):
                        inner: for i in 0 ..< self.items.count {
                            if self.items[i].id == itemId {
                                self.items.remove(at: i)
                                updated = true
                                break inner
                            }
                        }
                    case let .update(itemId, content):
                        inner: for i in 0 ..< self.items.count {
                            if self.items[i].id == itemId {
                                self.items[i] = OrderedItemListEntry(id: itemId, contents: content)
                                updated = true
                                break inner
                            }
                        }
                }
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return OrderedItemListView(self)
    }
}

public final class OrderedItemListView: PostboxView {
    public let collectionId: Int32
    public let items: [OrderedItemListEntry]
    
    init(_ view: MutableOrderedItemListView) {
        self.collectionId = view.collectionId
        self.items = view.items
    }
}

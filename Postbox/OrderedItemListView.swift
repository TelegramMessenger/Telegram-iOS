import Foundation

final class MutableOrderedItemListView {
    let collectionId: Int32
    var items: [OrderedItemListEntry]
    
    init(collectionId: Int32, getItems: (Int32) -> [OrderedItemListEntry]) {
        self.collectionId = collectionId
        self.items = getItems(collectionId)
    }
    
    func replay(operations: [Int32: [OrderedItemListOperation]]) -> Bool {
        var updated = false
        
        if let operations = operations[self.collectionId] {
            for operation in operations {
                switch operation {
                    case let .replace(items):
                        self.items = items
                        updated = true
                    case let .addOrMoveToFirstPosition(item, maxCount):
                        if let index = self.items.index(where: { $0.id == item.id }) {
                            self.items.remove(at: index)
                            self.items.insert(item, at: 0)
                        } else {
                            self.items.insert(item, at: 0)
                            if let maxCount = maxCount, self.items.count > maxCount {
                                self.items.removeLast()
                            }
                        }
                        updated = true
                }
            }
        }
        
        return updated
    }
}

public final class OrderedItemListView {
    public let collectionId: Int32
    public let items: [OrderedItemListEntry]
    
    init(_ view: MutableOrderedItemListView) {
        self.collectionId = view.collectionId
        self.items = view.items
    }
}

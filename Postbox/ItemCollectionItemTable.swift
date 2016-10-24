import Foundation

enum ItemCollectionOperation {
    case insertItem(ItemCollectionId, ItemCollectionItem)
    case removeItem(ItemCollectionId, ItemCollectionItemIndex.Id)
}

final class ItemCollectionItemTable: Table {
    private let sharedKey = ValueBoxKey(length: 4 + 8 + 4 + 8)
    
    private func key(collectionId: ItemCollectionId, index: ItemCollectionItemIndex) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: collectionId.namespace)
        self.sharedKey.setInt64(4, value: collectionId.id)
        self.sharedKey.setInt32(4 + 8, value: index.index)
        self.sharedKey.setInt64(4 + 8 + 4, value: index.id)
        return self.sharedKey
    }
    
    private func lowerBound(namespace: ItemCollectionId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: namespace)
        return key
    }
    
    private func upperBound(namespace: ItemCollectionId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: namespace)
        return key.successor
    }
    
    private func lowerBound(collectionId: ItemCollectionId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: collectionId.namespace)
        key.setInt64(4, value: collectionId.id)
        return key
    }
    
    private func upperBound(collectionId: ItemCollectionId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: collectionId.namespace)
        key.setInt64(4, value: collectionId.id)
        return key.successor
    }
    
    func lowerItems(collectionId: ItemCollectionId, itemIndex: ItemCollectionItemIndex, count: Int) -> [ItemCollectionItem] {
        var items: [ItemCollectionItem] = []
        self.valueBox.range(self.tableId, start: self.key(collectionId: collectionId, index: itemIndex), end: self.lowerBound(collectionId: collectionId), values: { _, value in
            if let item = Decoder(buffer: value).decodeRootObject() as? ItemCollectionItem {
                items.append(item)
            }
            return true
        }, limit: count)
        return items
    }
    
    func higherItems(collectionId: ItemCollectionId, itemIndex: ItemCollectionItemIndex, count: Int) -> [ItemCollectionItem] {
        var items: [ItemCollectionItem] = []
        self.valueBox.range(self.tableId, start: self.key(collectionId: collectionId, index: itemIndex), end: self.upperBound(collectionId: collectionId), values: { _, value in
            if let item = Decoder(buffer: value).decodeRootObject() as? ItemCollectionItem {
                items.append(item)
            }
            return true
        }, limit: count)
        return items
    }
    
    func getSummaryIndices(namespace: ItemCollectionId.Namespace) -> [ItemCollectionId: [ItemCollectionItemIndex]] {
        var summaryIndices: [ItemCollectionId: [ItemCollectionItemIndex]] = [:]
        self.valueBox.range(self.tableId, start: self.lowerBound(namespace: namespace), end: self.upperBound(namespace: namespace), keys: { key in
            let collectionId = ItemCollectionId(namespace: namespace, id: key.getInt64(4))
            let itemIndex = ItemCollectionItemIndex(index: key.getInt32(4 + 8), id: key.getInt64(4 + 8 + 4))
            if summaryIndices[collectionId] != nil {
                summaryIndices[collectionId]!.append(itemIndex)
            } else {
                summaryIndices[collectionId] = [itemIndex]
            }
            return true
        }, limit: 0)
        return summaryIndices
    }
    
    func getItems(namespace: ItemCollectionId.Namespace) -> [ItemCollectionId: [ItemCollectionItem]] {
        var items: [ItemCollectionId: [ItemCollectionItem]] = [:]
        self.valueBox.range(self.tableId, start: self.lowerBound(namespace: namespace), end: self.upperBound(namespace: namespace), values: { key, value in
            let collectionId = ItemCollectionId(namespace: namespace, id: key.getInt64(4))
            //let itemIndex = ItemCollectionItemIndex(index: key.getInt32(4 + 8), id: key.getInt64(4 + 8 + 4))
            if let item = Decoder(buffer: value).decodeRootObject() as? ItemCollectionItem {
                if items[collectionId] != nil {
                    items[collectionId]!.append(item)
                } else {
                    items[collectionId] = [item]
                }
            }
            return true
        }, limit: 0)
        return items
    }
    
    func replaceItems(collectionId: ItemCollectionId, items: [ItemCollectionItem]) {
        var currentIndices = Set<ItemCollectionItemIndex>()
        self.valueBox.range(self.tableId, start: self.lowerBound(collectionId: collectionId), end: self.upperBound(collectionId: collectionId), keys: { key in
            let itemIndex = ItemCollectionItemIndex(index: key.getInt32(4 + 8), id: key.getInt64(4 + 8 + 4))
            currentIndices.insert(itemIndex)
            return true
        }, limit: 0)
        
        var updatedIndices = Set(items.map({ $0.index }))
        var itemByIndex: [ItemCollectionItemIndex: ItemCollectionItem] = [:]
        for item in items {
            itemByIndex[item.index] = item
        }
        
        let addedIndices = updatedIndices.subtracting(currentIndices)
        let removedIndices = currentIndices.subtracting(updatedIndices)
        
        for index in removedIndices {
            self.valueBox.remove(self.tableId, key: self.key(collectionId: collectionId, index: index))
        }
        
        let sharedEncoder = Encoder()
        for index in addedIndices {
            let item = itemByIndex[index]!
            sharedEncoder.reset()
            sharedEncoder.encodeRootObject(item)
            self.valueBox.set(self.tableId, key: self.key(collectionId: collectionId, index: index), value: sharedEncoder.readBufferNoCopy())
        }
    }
    
    override func clearMemoryCache() {
        
    }
    
    override func beforeCommit() {
        
    }
}

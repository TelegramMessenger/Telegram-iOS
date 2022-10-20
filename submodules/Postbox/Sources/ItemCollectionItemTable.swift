import Foundation

enum ItemCollectionItemsOperation {
    case replaceItems
}

struct ItemCollectionItemReverseIndexReference: Equatable, Hashable, ReverseIndexReference {
    let collectionId: ItemCollectionId
    let itemIndex: ItemCollectionItemIndex
    
    static func <(lhs: ItemCollectionItemReverseIndexReference, rhs: ItemCollectionItemReverseIndexReference) -> Bool {
        if lhs.collectionId != rhs.collectionId {
            return lhs.collectionId < rhs.collectionId
        } else {
            return lhs.itemIndex < rhs.itemIndex
        }
    }
    
    static func decodeArray(_ buffer: MemoryBuffer) -> [ItemCollectionItemReverseIndexReference] {
        assert(buffer.length % (4 + 8 + 4 + 8) == 0)
        var references: [ItemCollectionItemReverseIndexReference] = []
        references.reserveCapacity(buffer.length % (4 + 8 + 4 + 8))
        withExtendedLifetime(buffer, {
            let readBuffer = ReadBuffer(memoryBufferNoCopy: buffer)
            for _ in 0 ..< buffer.length / (4 + 8 + 4 + 8) {
                var collectionIdNamespace: Int32 = 0
                var collectionIdId: Int64 = 0
                var indexIdIndex: Int32 = 0
                var indexIdId: Int64 = 0
                readBuffer.read(&collectionIdNamespace, offset: 0, length: 4)
                readBuffer.read(&collectionIdId, offset: 0, length: 8)
                readBuffer.read(&indexIdIndex, offset: 0, length: 4)
                readBuffer.read(&indexIdId, offset: 0, length: 8)
                references.append(ItemCollectionItemReverseIndexReference(collectionId: ItemCollectionId(namespace: collectionIdNamespace, id: collectionIdId), itemIndex: ItemCollectionItemIndex(index: indexIdIndex, id: indexIdId)))
            }
        })
        return references
    }
    
    static func encodeArray(_ array: [ItemCollectionItemReverseIndexReference]) -> MemoryBuffer {
        let buffer = WriteBuffer()
        for reference in array {
            var collectionIdNamespace: Int32 = reference.collectionId.namespace
            var collectionIdId: Int64 = reference.collectionId.id
            var indexIdIndex: Int32 = reference.itemIndex.index
            var indexIdId: Int64 = reference.itemIndex.id
            
            buffer.write(&collectionIdNamespace, offset: 0, length: 4)
            buffer.write(&collectionIdId, offset: 0, length: 8)
            buffer.write(&indexIdIndex, offset: 0, length: 4)
            buffer.write(&indexIdId, offset: 0, length: 8)
        }
        return buffer
    }
}

final class ItemCollectionItemTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let reverseIndexTable: ReverseIndexReferenceTable<ItemCollectionItemReverseIndexReference>
    
    private let sharedKey = ValueBoxKey(length: 4 + 8 + 4 + 8)
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, reverseIndexTable: ReverseIndexReferenceTable<ItemCollectionItemReverseIndexReference>) {
        self.reverseIndexTable = reverseIndexTable
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
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
        self.valueBox.range(self.table, start: self.key(collectionId: collectionId, index: itemIndex), end: self.lowerBound(collectionId: collectionId), values: { _, value in
            if let item = PostboxDecoder(buffer: value).decodeRootObject() as? ItemCollectionItem {
                items.append(item)
            } else {
                assertionFailure()
            }
            return true
        }, limit: count)
        return items
    }
    
    func itemCount(collectionId: ItemCollectionId) -> Int32 {
        var count: Int32 = 0
        self.valueBox.range(self.table, start: self.upperBound(collectionId: collectionId), end: self.lowerBound(collectionId: collectionId), keys: { key in
            let itemIndex = ItemCollectionItemIndex(index: key.getInt32(4 + 8), id: key.getInt64(4 + 8 + 4))
            count = itemIndex.index + 1
            return true
        }, limit: 1)
        return count
    }
    
    func higherItems(collectionId: ItemCollectionId, itemIndex: ItemCollectionItemIndex, count: Int) -> [ItemCollectionItem] {
        var items: [ItemCollectionItem] = []
        self.valueBox.range(self.table, start: self.key(collectionId: collectionId, index: itemIndex), end: self.upperBound(collectionId: collectionId), values: { _, value in
            if let item = PostboxDecoder(buffer: value).decodeRootObject() as? ItemCollectionItem {
                items.append(item)
            } else {
                assertionFailure()
            }
            return true
        }, limit: count)
        return items
    }
    
    func getItems(namespace: ItemCollectionId.Namespace) -> [ItemCollectionId: [ItemCollectionItem]] {
        var items: [ItemCollectionId: [ItemCollectionItem]] = [:]
        self.valueBox.range(self.table, start: self.lowerBound(namespace: namespace), end: self.upperBound(namespace: namespace), values: { key, value in
            let collectionId = ItemCollectionId(namespace: namespace, id: key.getInt64(4))
            //let itemIndex = ItemCollectionItemIndex(index: key.getInt32(4 + 8), id: key.getInt64(4 + 8 + 4))
            if let item = PostboxDecoder(buffer: value).decodeRootObject() as? ItemCollectionItem {
                if items[collectionId] != nil {
                    items[collectionId]!.append(item)
                } else {
                    items[collectionId] = [item]
                }
            } else {
                assertionFailure()
            }
            return true
        }, limit: 0)
        return items
    }
    
    func collectionItems(collectionId: ItemCollectionId) -> [ItemCollectionItem] {
        var items: [ItemCollectionItem] = []
        self.valueBox.range(self.table, start: self.lowerBound(collectionId: collectionId), end: self.upperBound(collectionId: collectionId), values: { key, value in
            //let itemIndex = ItemCollectionItemIndex(index: key.getInt32(4 + 8), id: key.getInt64(4 + 8 + 4))
            if let item = PostboxDecoder(buffer: value).decodeRootObject() as? ItemCollectionItem {
                items.append(item)
            } else {
                assertionFailure()
            }
            return true
        }, limit: 0)
        return items
    }
    
    func replaceItems(collectionId: ItemCollectionId, items: [ItemCollectionItem]) {
        let updatedIndices = Set(items.map({ $0.index }))
        var itemByIndex: [ItemCollectionItemIndex: ItemCollectionItem] = [:]
        for item in items {
            itemByIndex[item.index] = item
        }
        
        var currentIndices = Set<ItemCollectionItemIndex>()
        
        var removedIndexKeys: [ItemCollectionItemIndex: [MemoryBuffer]] = [:]
        
        self.valueBox.range(self.table, start: self.lowerBound(collectionId: collectionId), end: self.upperBound(collectionId: collectionId), values: { key, value in
            let itemIndex = ItemCollectionItemIndex(index: key.getInt32(4 + 8), id: key.getInt64(4 + 8 + 4))
            currentIndices.insert(itemIndex)
            
            if !updatedIndices.contains(itemIndex) {
                if let item = PostboxDecoder(buffer: value).decodeRootObject() as? ItemCollectionItem {
                    if !item.indexKeys.isEmpty {
                        removedIndexKeys[itemIndex] = item.indexKeys
                    }
                } else {
                    assertionFailure()
                }
            }
            return true
        }, limit: 0)
        
        let addedIndices = updatedIndices.subtracting(currentIndices)
        let removedIndices = currentIndices.subtracting(updatedIndices)
        
        for index in removedIndices {
            self.valueBox.remove(self.table, key: self.key(collectionId: collectionId, index: index), secure: false)
            if let indexKeys = removedIndexKeys[index] {
                self.reverseIndexTable.remove(namespace: ReverseIndexNamespace(collectionId.namespace), reference: ItemCollectionItemReverseIndexReference(collectionId: collectionId, itemIndex: index), tokens: indexKeys.map({ ValueBoxKey($0) }))
            }
        }
        
        let sharedEncoder = PostboxEncoder()
        for index in addedIndices {
            let item = itemByIndex[index]!
            sharedEncoder.reset()
            sharedEncoder.encodeRootObject(item)
            withExtendedLifetime(sharedEncoder, {
                self.valueBox.set(self.table, key: self.key(collectionId: collectionId, index: index), value: sharedEncoder.readBufferNoCopy())
            })
            if !item.indexKeys.isEmpty {
                self.reverseIndexTable.add(namespace: ReverseIndexNamespace(collectionId.namespace), reference: ItemCollectionItemReverseIndexReference(collectionId: collectionId, itemIndex: index), tokens: item.indexKeys.map({ ValueBoxKey($0) }))
            }
        }
    }
    
    func searchIndexedItems(namespace: ItemCollectionId.Namespace, query: ItemCollectionSearchQuery) -> [ItemCollectionId: [ItemCollectionItem]] {
        let references: [ItemCollectionItemReverseIndexReference]
        switch query {
            case let .exact(token):
                references = self.reverseIndexTable.exactReferences(namespace: ReverseIndexNamespace(namespace), token: token)
            case let .matching(tokens):
                references = Array(self.reverseIndexTable.matchingReferences(namespace: ReverseIndexNamespace(namespace), tokens: tokens))
            case let .any(tokens):
                references = Array(self.reverseIndexTable.matchingReferences(namespace: ReverseIndexNamespace(namespace), tokens: tokens, union: true))
        }
        var resultsByCollectionId: [ItemCollectionId: [(ItemCollectionItemIndex, ItemCollectionItem)]] = [:]
        for reference in references {
            if let value = self.valueBox.get(self.table, key: self.key(collectionId: reference.collectionId, index: reference.itemIndex)), let item = PostboxDecoder(buffer: value).decodeRootObject() as? ItemCollectionItem {
                if resultsByCollectionId[reference.collectionId] == nil {
                    resultsByCollectionId[reference.collectionId] = [(reference.itemIndex, item)]
                } else {
                    resultsByCollectionId[reference.collectionId]!.append((reference.itemIndex, item))
                }
            } else {
                assertionFailure()
            }
        }
        var results: [ItemCollectionId: [ItemCollectionItem]] = [:]
        for collectionId in resultsByCollectionId.keys {
            results[collectionId] = resultsByCollectionId[collectionId]!.sorted(by: { $0.0 < $1.0 }).map({ $0.1 })
        }
        return results
    }

    override func clearMemoryCache() {
        
    }
    
    override func beforeCommit() {
        
    }
}

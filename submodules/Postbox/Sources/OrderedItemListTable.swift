import Foundation

enum OrderedItemListOperation {
    case replace([OrderedItemListEntry])
    case addOrMoveToFirstPosition(OrderedItemListEntry, Int?)
    case remove(MemoryBuffer)
    case update(MemoryBuffer, CodableEntry)
}

private enum OrderedItemListKeyNamespace: UInt8 {
    case indexToId = 0
    case idToIndex = 1
}

final class OrderedItemListTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let indexTable: OrderedItemListIndexTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, indexTable: OrderedItemListIndexTable) {
        self.indexTable = indexTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func keyIndexToId(collectionId: Int32, itemIndex: UInt32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 4 + 4)
        key.setUInt8(0, value: OrderedItemListKeyNamespace.indexToId.rawValue)
        key.setInt32(1, value: collectionId)
        key.setUInt32(1 + 4, value: itemIndex)
        return key
    }

    private func keyIndexToIdLowerBound(collectionId: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 4 + 4)
        key.setUInt8(0, value: OrderedItemListKeyNamespace.indexToId.rawValue)
        key.setInt32(1, value: collectionId)
        return key
    }

    private func keyIndexToIdUpperBound(collectionId: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 4 + 4)
        key.setUInt8(0, value: OrderedItemListKeyNamespace.indexToId.rawValue)
        key.setInt32(1, value: collectionId)
        return key.successor
    }
    
    private func keyIdToIndex(collectionId: Int32, id: MemoryBuffer) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 4 + id.length)
        key.setUInt8(0, value: OrderedItemListKeyNamespace.idToIndex.rawValue)
        key.setInt32(1, value: collectionId)
        memcpy(key.memory.advanced(by: 1 + 4), id.memory, id.length)
        return key
    }

    private func keyIdToIndexLowerBound(collectionId: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 4)
        key.setUInt8(0, value: OrderedItemListKeyNamespace.idToIndex.rawValue)
        key.setInt32(1, value: collectionId)
        return key
    }

    private func keyIdToIndexUpperBound(collectionId: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 4)
        key.setUInt8(0, value: OrderedItemListKeyNamespace.idToIndex.rawValue)
        key.setInt32(1, value: collectionId)
        return key.successor
    }
    
    func getItemIds(collectionId: Int32) -> [MemoryBuffer] {
        var itemIds: [MemoryBuffer] = []
        self.valueBox.range(self.table, start: self.keyIndexToId(collectionId: collectionId, itemIndex: 0).predecessor, end: self.keyIndexToId(collectionId: collectionId, itemIndex: UInt32.max), values: { key, value in
            assert(key.getUInt8(0) == OrderedItemListKeyNamespace.indexToId.rawValue)
            itemIds.append(value)
            return true
        }, limit: 0)
        return itemIds
    }
    
    private func getIndex(collectionId: Int32, id: MemoryBuffer) -> UInt32? {
        if let value = self.valueBox.get(self.table, key: self.keyIdToIndex(collectionId: collectionId, id: id)) {
            var index: UInt32 = 0
            value.read(&index, offset: 0, length: 4)
            return index
        } else {
            return nil
        }
    }
    
    func getItems(collectionId: Int32) -> [OrderedItemListEntry] {
        var currentIds: [MemoryBuffer] = []
        self.valueBox.range(self.table, start: self.keyIndexToId(collectionId: collectionId, itemIndex: 0).predecessor, end: self.keyIndexToId(collectionId: collectionId, itemIndex: UInt32.max), values: { _, value in
            currentIds.append(value)
            return true
        }, limit: 0)
        var items: [OrderedItemListEntry] = []
        for id in currentIds {
            if let contents = self.indexTable.get(collectionId: collectionId, id: id) {
                items.append(OrderedItemListEntry(id: id, contents: contents))
            } else {
                assertionFailure()
            }
        }
        return items
    }
    
    func getItem(collectionId: Int32, itemId: MemoryBuffer) -> OrderedItemListEntry? {
        if let contents = self.indexTable.get(collectionId: collectionId, id: itemId) {
            return OrderedItemListEntry(id: itemId, contents: contents)
        } else {
            return nil
        }
    }
    
    func updateItem(collectionId: Int32, itemId: MemoryBuffer, item: CodableEntry, operations: inout [Int32: [OrderedItemListOperation]]) {
        if let _ = self.indexTable.get(collectionId: collectionId, id: itemId) {
            self.indexTable.set(collectionId: collectionId, id: itemId, content: item)
            if operations[collectionId] == nil {
                operations[collectionId] = []
            }
            operations[collectionId]!.append(.update(itemId, item))
        }
    }
    
    func replaceItems(collectionId: Int32, items: [OrderedItemListEntry], operations: inout [Int32: [OrderedItemListOperation]]) {
        if operations[collectionId] == nil {
            operations[collectionId] = [.replace(items)]
        } else {
            operations[collectionId]!.append(.replace(items))
        }
        
        var currentIds: [MemoryBuffer] = []
        var currentIndices: [UInt32] = []
        self.valueBox.range(self.table, start: self.keyIndexToId(collectionId: collectionId, itemIndex: 0).predecessor, end: self.keyIndexToId(collectionId: collectionId, itemIndex: UInt32.max), values: { key, value in
            currentIndices.append(key.getUInt32(1 + 4))
            currentIds.append(value)
            return true
        }, limit: 0)
        
        for index in currentIndices {
            self.valueBox.remove(self.table, key: self.keyIndexToId(collectionId: collectionId, itemIndex: index), secure: false)
        }
        for id in currentIds {
            self.valueBox.remove(self.table, key: self.keyIdToIndex(collectionId: collectionId, id: id), secure: false)
            self.indexTable.remove(collectionId: collectionId, id: id)
        }
        

        assert(Set(items.map({ $0.id.makeData() })).count == items.count)
        for i in 0 ..< items.count {
            self.valueBox.set(self.table, key: self.keyIndexToId(collectionId: collectionId, itemIndex: UInt32(i)), value: items[i].id)
            var indexValue: UInt32 = UInt32(i)
            self.valueBox.set(self.table, key: self.keyIdToIndex(collectionId: collectionId, id: items[i].id), value: MemoryBuffer(memory: &indexValue, capacity: 4, length: 4, freeWhenDone: false))
            self.indexTable.set(collectionId: collectionId, id: items[i].id, content: items[i].contents)
        }
        #if ((arch(i386) || arch(x86_64)) && os(iOS)) || DEBUG
            assert(self.testIntegrity(collectionId: collectionId))
        #endif
    }
    
    func addItemOrMoveToFirstPosition(collectionId: Int32, item: OrderedItemListEntry, removeTailIfCountExceeds: Int?, operations: inout [Int32: [OrderedItemListOperation]]) {
        if operations[collectionId] == nil {
            operations[collectionId] = [.addOrMoveToFirstPosition(item, removeTailIfCountExceeds)]
        } else {
            operations[collectionId]!.append(.addOrMoveToFirstPosition(item, removeTailIfCountExceeds))
        }
        
        if let index = self.getIndex(collectionId: collectionId, id: item.id), index == 0 {
            self.indexTable.set(collectionId: collectionId, id: item.id, content: item.contents)
            
            return
        }
        
        var orderedIds = self.getItemIds(collectionId: collectionId)
        
        let offsetUntilIndex: Int
        if let index = orderedIds.firstIndex(of: item.id) {
            offsetUntilIndex = index
            self.valueBox.remove(self.table, key: self.keyIndexToId(collectionId: collectionId, itemIndex: UInt32(index)), secure: false)
        } else {
            if let removeTailIfCountExceeds = removeTailIfCountExceeds, orderedIds.count + 1 > removeTailIfCountExceeds {
                self.indexTable.remove(collectionId: collectionId, id: orderedIds[orderedIds.count - 1])
                self.valueBox.remove(self.table, key: self.keyIdToIndex(collectionId: collectionId, id: orderedIds[orderedIds.count - 1]), secure: false)
                self.valueBox.remove(self.table, key: self.keyIndexToId(collectionId: collectionId, itemIndex: UInt32(orderedIds.count - 1)), secure: false)
                orderedIds.removeLast()
            }
            
            offsetUntilIndex = orderedIds.count
        }
        self.indexTable.set(collectionId: collectionId, id: item.id, content: item.contents)
        
        for i in 0 ..< offsetUntilIndex {
            var updatedIndex: UInt32 = UInt32(i + 1)
            self.valueBox.set(self.table, key: self.keyIdToIndex(collectionId: collectionId, id: orderedIds[i]), value: MemoryBuffer(memory: &updatedIndex, capacity: 4, length: 4, freeWhenDone: false))
            self.valueBox.set(self.table, key: self.keyIndexToId(collectionId: collectionId, itemIndex: updatedIndex), value: orderedIds[i])
        }
        
        self.valueBox.set(self.table, key: self.keyIndexToId(collectionId: collectionId, itemIndex: 0), value: item.id)
        var itemIndex: UInt32 = 0
        self.valueBox.set(self.table, key: self.keyIdToIndex(collectionId: collectionId, id: item.id), value: MemoryBuffer(memory: &itemIndex, capacity: 4, length: 4, freeWhenDone: false))
        #if ((arch(i386) || arch(x86_64)) && os(iOS)) || DEBUG
            assert(self.testIntegrity(collectionId: collectionId))
        #endif
    }
    
    func remove(collectionId: Int32, itemId: MemoryBuffer, operations: inout [Int32: [OrderedItemListOperation]]) {
        if let index = self.getIndex(collectionId: collectionId, id: itemId) {
            let orderedIds = self.getItemIds(collectionId: collectionId)
            
            if !orderedIds.isEmpty {
                self.valueBox.remove(self.table, key: self.keyIdToIndex(collectionId: collectionId, id: itemId), secure: false)
                self.valueBox.remove(self.table, key: self.keyIndexToId(collectionId: collectionId, itemIndex: index), secure: false)
                
                self.valueBox.remove(self.table, key: self.keyIdToIndex(collectionId: collectionId, id: orderedIds[orderedIds.count - 1]), secure: false)
                self.valueBox.remove(self.table, key: self.keyIndexToId(collectionId: collectionId, itemIndex: UInt32(orderedIds.count - 1)), secure: false)
                
                for i in (Int(index) + 1) ..< orderedIds.count {
                    var updatedIndex: UInt32 = UInt32(i - 1)
                    self.valueBox.set(self.table, key: self.keyIdToIndex(collectionId: collectionId, id: orderedIds[i]), value: MemoryBuffer(memory: &updatedIndex, capacity: 4, length: 4, freeWhenDone: false))
                    self.valueBox.set(self.table, key: self.keyIndexToId(collectionId: collectionId, itemIndex: updatedIndex), value: orderedIds[i])
                }
                
                if operations[collectionId] == nil {
                    operations[collectionId] = []
                }
                operations[collectionId]!.append(.remove(itemId))
            }
            self.indexTable.remove(collectionId: collectionId, id: itemId)
        }
        #if ((arch(i386) || arch(x86_64)) && os(iOS)) || DEBUG
        assert(self.testIntegrity(collectionId: collectionId))
        #endif
    }
    
    func testIntegrity(collectionId: Int32) -> Bool {
        let orderedIds = self.getItemIds(collectionId: collectionId).map { ValueBoxKey($0) }
        
        let existingIds = Set(orderedIds)
        let indexIds = Set(self.indexTable.getAllItemIds(collectionId: collectionId).map { ValueBoxKey($0) })
        if indexIds != existingIds {
            return false
        }
        
        var allIndexedKeys: [ValueBoxKey] = []
        var allIndices: [UInt32] = []
        self.valueBox.range(self.table, start: self.keyIdToIndex(collectionId: collectionId, id: MemoryBuffer()), end: self.keyIdToIndex(collectionId: collectionId + 1, id: MemoryBuffer()), values: { key, value in
            let id = MemoryBuffer(memory: malloc(key.length - 5)!, capacity: key.length - 5, length: key.length - 5, freeWhenDone: true)
            memcpy(id.memory, key.memory.advanced(by: 5), key.length - 5)
            allIndexedKeys.append(ValueBoxKey(id))
            var index: UInt32 = 0
            value.read(&index, offset: 0, length: 4)
            allIndices.append(index)
            return true
        }, limit: 0)
        
        if Set(allIndexedKeys) != existingIds {
            print("\(allIndexedKeys) != \(existingIds)")
            return false
        }
        
        if allIndices.sorted() != Array((0 ..< orderedIds.count).map { UInt32($0) }) {
            return false
        }
        
        return true
    }
}

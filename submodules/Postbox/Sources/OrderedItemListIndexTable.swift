import Foundation

final class OrderedItemListIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private func key(collectionId: Int32, id: MemoryBuffer) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + id.length)
        key.setInt32(0, value: collectionId)
        memcpy(key.memory.advanced(by: 4), id.memory, id.length)
        return key
    }
    
    func get(collectionId: Int32, id: MemoryBuffer) -> CodableEntry? {
        if let value = self.valueBox.get(self.table, key: self.key(collectionId: collectionId, id: id)) {
            return CodableEntry(data: value.makeData())
        } else {
            return nil
        }
    }
    
    func remove(collectionId: Int32, id: MemoryBuffer) {
        self.valueBox.remove(self.table, key: self.key(collectionId: collectionId, id: id), secure: false)
    }
    
    func set(collectionId: Int32, id: MemoryBuffer, content: CodableEntry) {
        self.valueBox.set(self.table, key: self.key(collectionId: collectionId, id: id), value: ReadBuffer(data: content.data))
    }
    
    func getAllItemIds(collectionId: Int32) -> [MemoryBuffer] {
        var result: [MemoryBuffer] = []
        self.valueBox.range(self.table, start: self.key(collectionId: collectionId, id: MemoryBuffer()), end: self.key(collectionId: collectionId + 1, id: MemoryBuffer()), keys: { key in
            let id = MemoryBuffer(memory: malloc(key.length - 4)!, capacity: key.length - 4, length: key.length - 4, freeWhenDone: true)
            memcpy(id.memory, key.memory.advanced(by: 4), key.length - 4)
            result.append(id)
            return true
        }, limit: 0)
        return result
    }
}

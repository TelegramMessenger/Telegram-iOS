import Foundation

final class MessageCustomTagIdTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let metadataTable: MessageHistoryMetadataTable
    
    private var cachedIds: [MemoryBuffer: Int32] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, metadataTable: MessageHistoryMetadataTable) {
        self.metadataTable = metadataTable
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    func get(tag: MemoryBuffer) -> Int32 {
        if let value = self.cachedIds[tag] {
            return value
        } else if let value = self.valueBox.get(self.table, key: ValueBoxKey(tag)) {
            assert(value.length == 4)
            var result: Int32 = 0
            value.read(&result, offset: 0, length: 4)
            self.cachedIds[tag] = result
            return result
        } else {
            let id = self.metadataTable.getNextCustomTagIdAndIncrement()
            
            if self.useCaches {
                self.cachedIds[tag] = id
            }
            
            var storeId: Int32 = id
            self.valueBox.set(self.table, key: ValueBoxKey(tag), value: MemoryBuffer(memory: &storeId, capacity: 4, length: 4, freeWhenDone: false))
            
            return id
        }
    }
    
    override func clearMemoryCache() {
        self.cachedIds.removeAll()
    }
    
    override func beforeCommit() {
    }
}

import Foundation

final class KeychainTable: Table {
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    private func key(_ string: String) -> ValueBoxKey {
        return ValueBoxKey(string)
    }
    
    func get(_ key: String) -> Data? {
        if let value = self.valueBox.get(self.tableId, key: self.key(key)) {
            return Data(bytes: UnsafePointer<UInt8>(value.memory), count: value.length)
        }
        return nil
    }
    
    func set(_ key: String, value: Data) {
        self.valueBox.set(self.tableId, key: self.key(key), value: MemoryBuffer(data: value))
    }
    
    func remove(_ key: String) {
        self.valueBox.remove(self.tableId, key: self.key(key))
    }
}

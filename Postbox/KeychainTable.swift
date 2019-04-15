import Foundation

final class KeychainTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private func key(_ string: String) -> ValueBoxKey {
        return ValueBoxKey(string)
    }
    
    func get(_ key: String) -> Data? {
        if let value = self.valueBox.get(self.table, key: self.key(key)) {
            return Data(bytes: value.memory.assumingMemoryBound(to: UInt8.self), count: value.length)
        }
        return nil
    }
    
    func set(_ key: String, value: Data) {
        self.valueBox.set(self.table, key: self.key(key), value: MemoryBuffer(data: value))
    }
    
    func remove(_ key: String) {
        self.valueBox.remove(self.table, key: self.key(key), secure: false)
    }
}

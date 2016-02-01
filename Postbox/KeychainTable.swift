import Foundation

final class KeychainTable {
    let valueBox: ValueBox
    let tableId: Int32
    
    init(valueBox: ValueBox, tableId: Int32) {
        self.valueBox = valueBox
        self.tableId = tableId
    }
    
    private func key(string: String) -> ValueBoxKey {
        return ValueBoxKey(string)
    }
    
    func get(key: String) -> NSData? {
        if let value = self.valueBox.get(self.tableId, key: self.key(key)) {
            return NSData(bytes: value.memory, length: value.length)
        }
        return nil
    }
    
    func set(key: String, value: NSData) {
        self.valueBox.set(self.tableId, key: self.key(key), value: MemoryBuffer(data: value))
    }
    
    func remove(key: String) {
        self.valueBox.remove(self.tableId, key: self.key(key))
    }
}

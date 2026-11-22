import Foundation

final class TimestampBasedMessageAttributesIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private func key(tag: UInt16, id: MessageId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 2 + 4 + 8 + 4)
        key.setUInt16(0, value: tag)
        key.setInt64(2, value: id.peerId.toInt64())
        key.setInt32(2 + 8, value: id.namespace)
        key.setInt32(2 + 8 + 4, value: id.id)
        return key
    }
    
    func set(tag: UInt16, id: MessageId, timestamp: Int32) {
        var timestampValue = timestamp
        self.valueBox.set(self.table, key: self.key(tag: tag, id: id), value: MemoryBuffer(memory: &timestampValue, capacity: 4, length: 4, freeWhenDone: false))
    }
    
    func get(tag: UInt16, id: MessageId) -> Int32? {
        if let value = self.valueBox.get(self.table, key: self.key(tag: tag, id: id)) {
            var timestampValue: Int32 = 0
            value.read(&timestampValue, offset: 0, length: 4)
            return timestampValue
        } else {
            return nil
        }
    }
    
    func remove(tag: UInt16, id: MessageId) {
        self.valueBox.remove(self.table, key: self.key(tag: tag, id: id), secure: false)
    }
}

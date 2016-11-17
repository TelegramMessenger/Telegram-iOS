import Foundation

class MessageOrderStatisticTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    /*private func update(peerId: PeerId, tagMask: MessageTags, id: Int32, count: Int) {
        let key = ValueBoxKey(length: 8 + 4 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setUInt32(8, value: tagMask.rawValue)
        
        var writeValue: Int32 = 0
        let buffer = MemoryBuffer(memory: &writeValue, capacity: 4, length: 4, freeWhenDone: false)
        var idx = id
        while (idx <= 1000000) {
            key.setInt32(8 + 4, value: idx)
            var value: Int32 = 0
            if let data = self.valueBox.get(self.table, key: key) {
                data.read(&value, offset: 0, length: 4)
            }
            if value == 0 {
                self.valueBox.remove(self.table, key: key)
            } else {
                writeValue = value
                self.valueBox.set(self.table, key: key, value: buffer)
            }
            idx += idx & -idx
        }
    }
    
    private func get(peerId: PeerId, tagMask: MessageTags, id: Int32) -> Int32 {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        
        var idx = id
        
        var sum: Int32 = 0
        while (idx > 0) {
            key.setInt32(8, value: idx)
            var value: Int32 = 0
            if let data = self.valueBox.get(self.table, key: key) {
                data.read(&value, offset: 0, length: 4)
            }
            sum += value
            idx -= idx & -idx
        }
        
        return sum
    }
    
    func set(_ id: MessageId, count: Int) {
        self.update(peerId: id.peerId, id: id.id, count: count)
    }
    
    func get(_ id: MessageId) -> Int32 {
        return self.get(peerId: id.peerId, id: id.id)
    }*/
}

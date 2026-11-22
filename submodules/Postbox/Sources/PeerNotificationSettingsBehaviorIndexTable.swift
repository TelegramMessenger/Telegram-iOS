import Foundation

final class PeerNotificationSettingsBehaviorIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: true)
    }
    
    private func key(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    func get(peerId: PeerId) -> Int32? {
        if let value = self.valueBox.get(self.table, key: self.key(peerId: peerId)) {
            var timestamp: Int32 = 0
            value.read(&timestamp, offset: 0, length: 4)
            return timestamp
        } else {
            return nil
        }
    }
    
    func set(peerId: PeerId, timestamp: Int32?) {
        if var timestamp = timestamp {
            self.valueBox.set(self.table, key: self.key(peerId: peerId), value: MemoryBuffer(memory: &timestamp, capacity: 4, length: 4, freeWhenDone: false))
        } else {
            self.valueBox.remove(self.table, key: self.key(peerId: peerId), secure: false)
        }
    }
}

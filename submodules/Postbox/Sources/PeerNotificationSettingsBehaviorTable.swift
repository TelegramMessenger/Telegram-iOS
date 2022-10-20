import Foundation

struct PeerNotificationSettingsBehaviorTimestamp {
    var value: Int32?
}

final class PeerNotificationSettingsBehaviorTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let indexTable: PeerNotificationSettingsBehaviorIndexTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, indexTable: PeerNotificationSettingsBehaviorIndexTable) {
        self.indexTable = indexTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(peerId: PeerId, timestamp: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: timestamp)
        key.setInt64(4, value: peerId.toInt64())
        return key
    }
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: 0)
        return key
    }
    
    private func upperBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        memset(key.memory, 0xff, key.length)
        return key
    }
    
    func getEarliest() -> (PeerId, Int32)? {
        var result: (PeerId, Int32)?
        self.valueBox.range(self.table, start: self.lowerBound(), end: self.upperBound(), keys: { key in
            result = (PeerId(key.getInt64(4)), key.getInt32(0))
            return false
        }, limit: 1)
        return result
    }
    
    func getEarlierThanOrEqualTo(timestamp: Int32) -> [PeerId] {
        var result: [PeerId] = []
        self.valueBox.range(self.table, start: self.lowerBound(), end: self.key(peerId: PeerId(0), timestamp: timestamp + 1), keys: { key in
            result.append(PeerId(key.getInt64(4)))
            return true
        }, limit: 0)
        return result
    }
    
    func set(peerId: PeerId, timestamp: Int32?, updatedTimestamps: inout [PeerId: PeerNotificationSettingsBehaviorTimestamp]) {
        let previousTimestamp = self.indexTable.get(peerId: peerId)
        if previousTimestamp == timestamp {
            return
        }
        
        if let previousTimestamp = previousTimestamp {
            self.valueBox.remove(self.table, key: self.key(peerId: peerId, timestamp: previousTimestamp), secure: false)
        }
        
        if let timestamp = timestamp {
            self.valueBox.set(self.table, key: self.key(peerId: peerId, timestamp: timestamp), value: MemoryBuffer())
        }
        self.indexTable.set(peerId: peerId, timestamp: timestamp)
        
        updatedTimestamps[peerId] = PeerNotificationSettingsBehaviorTimestamp(value: timestamp)
    }
}

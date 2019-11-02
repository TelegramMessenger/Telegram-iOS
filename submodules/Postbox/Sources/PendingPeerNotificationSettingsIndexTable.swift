import Foundation

final class PendingPeerNotificationSettingsIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private let sharedKey = ValueBoxKey(length: 8)
    private var updatedPeerIds: [PeerId: Bool] = [:]
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    private func get(peerId: PeerId) -> Bool {
        if let _ = self.valueBox.get(self.table, key: self.key(peerId)) {
            return true
        } else {
            return false
        }
    }
    
    func getAll() -> [PeerId] {
        var peerIds: [PeerId] = []
        self.valueBox.scanInt64(self.table, values: { key, _ in
            peerIds.append(PeerId(key))
            return true
        })
        return peerIds
    }
    
    func set(peerId: PeerId, pending: Bool) {
        if pending {
            self.valueBox.set(self.table, key: self.key(peerId), value: MemoryBuffer())
        } else {
            self.valueBox.remove(self.table, key: self.key(peerId), secure: false)
        }
    }
}

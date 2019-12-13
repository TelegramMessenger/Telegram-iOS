import Foundation

final class MessageHistoryFailedTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8 + 4 + 4)
    
    private(set) var updatedPeerIds = Set<PeerId>()
    
    private func key(_ id: MessageId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.peerId.toInt64())
        self.sharedKey.setInt32(8, value: id.namespace)
        self.sharedKey.setInt32(8 + 4, value: id.id)
        
        return self.sharedKey
    }
    
    private func lowerBound(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    private func upperBound(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key.successor
    }
    
    func add(_ id: MessageId) {
        self.valueBox.set(self.table, key: self.key(id), value: MemoryBuffer())
        self.updatedPeerIds.insert(id.peerId)
    }
    
    func remove(_ id: MessageId) {
        self.valueBox.remove(self.table, key: self.key(id), secure: false)
        self.updatedPeerIds.insert(id.peerId)
    }
    
    func contains(peerId: PeerId) -> Bool {
        var result = false
        self.valueBox.range(self.table, start: self.lowerBound(peerId: peerId), end: self.upperBound(peerId: peerId), keys: { _ in
            result = true
            return false
        }, limit: 1)
        return result
    }
    
    override func beforeCommit() {
        self.updatedPeerIds.removeAll()
    }
}


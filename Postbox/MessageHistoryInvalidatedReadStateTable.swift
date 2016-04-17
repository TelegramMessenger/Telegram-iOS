import Foundation

enum IntermediateMessageHistoryInvalidatedReadStateOperation {
    case Insert(PeerId)
    case Remove(PeerId)
}

final class MessageHistoryInvalidatedReadStateTable: Table {
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    private var updatedPeerIds: [PeerId: Bool] = [:]
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 1)
        key.setInt8(0, value: 0)
        return key
    }
    
    private func upperBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        memset(key.memory, 0xff, key.length)
        return key
    }
    
    func add(peerId: PeerId, inout operations: [IntermediateMessageHistoryInvalidatedReadStateOperation]) {
        if !self.valueBox.exists(self.tableId, key: self.key(peerId)) {
            self.valueBox.set(self.tableId, key: self.key(peerId), value: MemoryBuffer())
            operations.append(.Insert(peerId))
        }
    }
    
    func remove(peerId: PeerId, inout operations: [IntermediateMessageHistoryInvalidatedReadStateOperation]) {
        if self.valueBox.exists(self.tableId, key: self.key(peerId)) {
            self.valueBox.remove(self.tableId, key: self.key(peerId))
            operations.append(.Remove(peerId))
        }
    }
    
    func get() -> [PeerId] {
        var peerIds: [PeerId] = []
        self.valueBox.range(self.tableId, start: self.lowerBound(), end: self.upperBound(), keys: { key in
            peerIds.append(PeerId(key.getInt64(0)))
            return true
        }, limit: 0)
        return peerIds
    }
    
    override func beforeCommit() {
        let key = ValueBoxKey(length: 8)
        let buffer = MemoryBuffer()
        for (peerId, invalidated) in self.updatedPeerIds {
            key.setInt64(0, value: peerId.toInt64())
            if invalidated {
                self.valueBox.set(self.tableId, key: key, value: buffer)
            } else {
                self.valueBox.remove(self.tableId, key: key)
            }
        }
        self.updatedPeerIds.removeAll()
    }
}

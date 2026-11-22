import Foundation

enum IntermediateMessageHistoryUnsentOperation {
    case Insert(MessageId)
    case Remove(MessageId)
}

final class MessageHistoryUnsentTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 4 + 4 + 8)
    
    private func key(_ id: MessageId) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: id.namespace)
        self.sharedKey.setInt32(4, value: id.id)
        self.sharedKey.setInt64(4 + 4, value: id.peerId.toInt64())
        
        return self.sharedKey
    }
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 1)
        key.setInt8(0, value: 0)
        return key
    }
    
    private func upperBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 4 + 8)
        memset(key.memory, 0xff, key.length)
        return key
    }
    
    func add(_ id: MessageId, operations: inout [IntermediateMessageHistoryUnsentOperation]) {
        self.valueBox.set(self.table, key: self.key(id), value: MemoryBuffer())
        operations.append(.Insert(id))
    }
    
    func remove(_ id: MessageId, operations: inout [IntermediateMessageHistoryUnsentOperation]) {
        self.valueBox.remove(self.table, key: self.key(id), secure: false)
        operations.append(.Remove(id))
    }
    
    func get() -> [MessageId] {
        var ids: [MessageId] = []
        self.valueBox.range(self.table, start: self.lowerBound(), end: self.upperBound(), keys: { key in
            ids.append(MessageId(peerId: PeerId(key.getInt64(4 + 4)), namespace: key.getInt32(0), id: key.getInt32(4)))
            return true
        }, limit: 0)
        return ids
    }
    
    override func beforeCommit() {
        
    }
}

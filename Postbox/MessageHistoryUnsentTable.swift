import Foundation

enum IntermediateMessageHistoryUnsentOperation {
    case Insert(MessageIndex)
    case Remove(MessageIndex)
}

final class MessageHistoryUnsentTable: Table {
    private let sharedKey = ValueBoxKey(length: 4 + 4 + 4 + 8)
    
    private func key(_ index: MessageIndex) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: index.timestamp)
        self.sharedKey.setInt32(4, value: index.id.namespace)
        self.sharedKey.setInt32(4 + 4, value: index.id.id)
        self.sharedKey.setInt64(4 + 4 + 4, value: index.id.peerId.toInt64())
        
        return self.sharedKey
    }
    
    private func lowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 1)
        key.setInt8(0, value: 0)
        return key
    }
    
    private func upperBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 4 + 4 + 8)
        memset(key.memory, 0xff, key.length)
        return key
    }
    
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    func add(_ index: MessageIndex, operations: inout [IntermediateMessageHistoryUnsentOperation]) {
        self.valueBox.set(self.tableId, key: self.key(index), value: MemoryBuffer())
        operations.append(.Insert(index))
    }
    
    func remove(_ index: MessageIndex, operations: inout [IntermediateMessageHistoryUnsentOperation]) {
        self.valueBox.remove(self.tableId, key: self.key(index))
        operations.append(.Remove(index))
    }
    
    func get() -> [MessageIndex] {
        var indices: [MessageIndex] = []
        self.valueBox.range(self.tableId, start: self.lowerBound(), end: self.upperBound(), keys: { key in
            indices.append(MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4)), namespace: key.getInt32(4), id: key.getInt32(4 + 4)), timestamp: key.getInt32(0)))
            return true
        }, limit: 0)
        return indices
    }
    
    override func beforeCommit() {
        
    }
}

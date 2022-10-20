import Foundation

private func extractKey(_ key: ValueBoxKey) -> MessageIndex {
    return MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 8), id: key.getInt32(8 + 8 + 4 + 4)), timestamp: key.getInt32(8 + 8 + 4))
}

class MessageHistoryThreadsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4)
    
    override init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool) {
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(threadId: Int64, index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setInt64(8, value: threadId)
        key.setInt32(8 + 8, value: index.id.namespace)
        key.setInt32(8 + 8 + 4, value: index.timestamp)
        key.setInt32(8 + 8 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func lowerBound(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt64(8, value: threadId)
        key.setInt32(8 + 8, value: namespace)
        return key
    }
    
    private func upperBound(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        return self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace).successor
    }
    
    func add(threadId: Int64, index: MessageIndex) {
        self.valueBox.set(self.table, key: self.key(threadId: threadId, index: index, key: self.sharedKey), value: MemoryBuffer())
    }
    
    func remove(threadId: Int64, index: MessageIndex) {
        self.valueBox.remove(self.table, key: self.key(threadId: threadId, index: index, key: self.sharedKey), secure: false)
    }
    
    func earlierIndices(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(threadId: threadId, index: index).successor
            } else {
                key = self.key(threadId: threadId, index: index)
            }
        } else {
            key = self.upperBound(threadId: threadId, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func laterIndices(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, count: Int) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(threadId: threadId, index: index).predecessor
            } else {
                key = self.key(threadId: threadId, index: index)
            }
        } else {
            key = self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: self.upperBound(threadId: threadId, peerId: peerId, namespace: namespace), keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func getMessageCountInRange(threadId: Int64, peerId: PeerId, namespace: MessageId.Namespace, lowerBound: MessageIndex?, upperBound: MessageIndex?) -> Int {
        if let lowerBound = lowerBound {
            precondition(lowerBound.id.namespace == namespace)
        }
        if let upperBound = upperBound {
            precondition(upperBound.id.namespace == namespace)
        }
        var lowerBoundKey: ValueBoxKey
        if let lowerBound = lowerBound {
            lowerBoundKey = self.key(threadId: threadId, index: lowerBound)
            if lowerBound.timestamp > 1 {
                lowerBoundKey = lowerBoundKey.predecessor
            }
        } else {
            lowerBoundKey = self.lowerBound(threadId: threadId, peerId: peerId, namespace: namespace)
        }
        var upperBoundKey: ValueBoxKey
        if let upperBound = upperBound {
            upperBoundKey = self.key(threadId: threadId, index: upperBound)
            if upperBound.timestamp < Int32.max - 1 {
                upperBoundKey = upperBoundKey.successor
            }
        } else {
            upperBoundKey = self.upperBound(threadId: threadId, peerId: peerId, namespace: namespace)
        }
        return Int(self.valueBox.count(self.table, start: lowerBoundKey, end: upperBoundKey))
    }
}

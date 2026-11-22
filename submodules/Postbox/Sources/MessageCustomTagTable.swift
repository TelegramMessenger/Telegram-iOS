import Foundation

private func extractKey(_ key: ValueBoxKey) -> MessageIndex {
    return MessageIndex(
        id: MessageId(
            peerId: PeerId(key.getInt64(0)),
            namespace: key.getInt32(8 + 8 + 4),
            id: key.getInt32(8 + 8 + 4 + 4 + 4)
        ),
        timestamp: key.getInt32(8 + 8 + 4 + 4)
    )
}

class MessageCustomTagTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let messageCustomTagIdTable: MessageCustomTagIdTable
    
    private let sharedKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4 + 4)
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, messageCustomTagIdTable: MessageCustomTagIdTable) {
        self.messageCustomTagIdTable = messageCustomTagIdTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(threadId: Int64?, tag: Int32, index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setInt64(8, value: threadId ?? 0)
        key.setInt32(8 + 8, value: tag)
        key.setInt32(8 + 8 + 4, value: index.id.namespace)
        key.setInt32(8 + 8 + 4 + 4, value: index.timestamp)
        key.setInt32(8 + 8 + 4 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func lowerBound(threadId: Int64?, tag: Int32, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 8 + 4 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt64(8, value: threadId ?? 0)
        key.setInt32(8 + 8, value: tag)
        key.setInt32(8 + 8 + 4, value: namespace)
        return key
    }
    
    private func upperBound(threadId: Int64?, tag: Int32, peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        return self.lowerBound(threadId: threadId, tag: tag, peerId: peerId, namespace: namespace).successor
    }
    
    func add(threadId: Int64?, tag: MemoryBuffer, index: MessageIndex) {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        self.valueBox.set(self.table, key: self.key(threadId: threadId, tag: mappedTag, index: index, key: self.sharedKey), value: MemoryBuffer())
    }
    
    func remove(threadId: Int64?, tag: MemoryBuffer, index: MessageIndex) {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        self.valueBox.remove(self.table, key: self.key(threadId: threadId, tag: mappedTag, index: index, key: self.sharedKey), secure: false)
    }
    
    func entryExists(threadId: Int64?, tag: MemoryBuffer, index: MessageIndex) -> Bool {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        return self.valueBox.exists(self.table, key: self.key(threadId: threadId, tag: mappedTag, index: index, key: self.sharedKey))
    }
    
    func earlierIndices(threadId: Int64?, tag: MemoryBuffer, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, minIndex: MessageIndex? = nil, count: Int) -> [MessageIndex] {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(threadId: threadId, tag: mappedTag, index: index).successor
            } else {
                key = self.key(threadId: threadId, tag: mappedTag, index: index)
            }
        } else {
            key = self.upperBound(threadId: threadId, tag: mappedTag, peerId: peerId, namespace: namespace)
        }
        let endKey: ValueBoxKey
        if let minIndex = minIndex {
            endKey = self.key(threadId: threadId, tag: mappedTag, index: minIndex)
        } else {
            endKey = self.lowerBound(threadId: threadId, tag: mappedTag, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: endKey, keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func laterIndices(threadId: Int64?, tag: MemoryBuffer, peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex?, includeFrom: Bool, count: Int) -> [MessageIndex] {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        var indices: [MessageIndex] = []
        let key: ValueBoxKey
        if let index = index {
            if includeFrom {
                key = self.key(threadId: threadId, tag: mappedTag, index: index).predecessor
            } else {
                key = self.key(threadId: threadId, tag: mappedTag, index: index)
            }
        } else {
            key = self.lowerBound(threadId: threadId, tag: mappedTag, peerId: peerId, namespace: namespace)
        }
        self.valueBox.range(self.table, start: key, end: self.upperBound(threadId: threadId, tag: mappedTag, peerId: peerId, namespace: namespace), keys: { key in
            indices.append(extractKey(key))
            return true
        }, limit: count)
        return indices
    }
    
    func latestIndex(threadId: Int64?, tag: MemoryBuffer, peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex? {
        let mappedTag = self.messageCustomTagIdTable.get(tag: tag)
        
        var result: MessageIndex?
        self.valueBox.range(self.table, start: self.lowerBound(threadId: threadId, tag: mappedTag, peerId: peerId, namespace: namespace), end: self.upperBound(threadId: threadId, tag: mappedTag, peerId: peerId, namespace: namespace), keys: { key in
            result = extractKey(key)
            return true
        }, limit: 1)
        return result
    }
}

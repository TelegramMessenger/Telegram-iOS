import Foundation

private func extractKey(_ key: ValueBoxKey) -> MessageIndex {
    return MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 8), id: key.getInt32(8 + 8 + 4 + 4)), timestamp: key.getInt32(8 + 8 + 4))
}

class MessageHistoryThreadReverseIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8 + 8)
    
    override init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool) {
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(peerId: PeerId, threadId: Int64, key: ValueBoxKey) -> ValueBoxKey {
        key.setInt64(0, value: peerId.toInt64())
        key.setInt64(8, value: threadId)
        
        return key
    }
    
    func get(peerId: PeerId, threadId: Int64) -> MessageIndex? {
        if let value = self.valueBox.get(self.table, key: self.key(peerId: peerId, threadId: threadId, key: self.sharedKey)) {
            var result: MessageIndex?
            withExtendedLifetime(value, {
                let readBuffer = ReadBuffer(memoryBufferNoCopy: value)
                var namespace: Int32 = 0
                readBuffer.read(&namespace, offset: 0, length: 4)
                var id: Int32 = 0
                readBuffer.read(&id, offset: 0, length: 4)
                var timestamp: Int32 = 0
                readBuffer.read(&timestamp, offset: 0, length: 4)
                result = MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp)
            })
            return result
        } else {
            return nil
        }
    }
    
    func set(peerId: PeerId, threadId: Int64, timestamp: Int32, namespace: MessageId.Namespace, id: MessageId.Id, hasValue: Bool) {
        if hasValue {
            let buffer = WriteBuffer()
            var namespace = namespace
            buffer.write(&namespace, length: 4)
            var id = id
            buffer.write(&id, length: 4)
            var timestamp = timestamp
            buffer.write(&timestamp, length: 4)
            withExtendedLifetime(buffer, {
                self.valueBox.set(self.table, key: self.key(peerId: peerId, threadId: threadId, key: self.sharedKey), value: buffer.readBufferNoCopy())
            })
        } else {
            self.valueBox.remove(self.table, key: self.key(peerId: peerId, threadId: threadId, key: self.sharedKey), secure: false)
        }
    }
}

class MessageHistoryThreadIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let reverseIndexTable: MessageHistoryThreadReverseIndexTable
    
    private let sharedKey = ValueBoxKey(length: 8 + 4 + 8 + 4 + 4)
    
    private var updatedInfoItems: [MessageHistoryThreadsTable.ItemId: CodableEntry] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, reverseIndexTable: MessageHistoryThreadReverseIndexTable, useCaches: Bool) {
        self.reverseIndexTable = reverseIndexTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(peerId: PeerId, timestamp: Int32, threadId: Int64, namespace: MessageId.Namespace, id: MessageId.Id, key: ValueBoxKey) -> ValueBoxKey {
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: timestamp)
        key.setInt64(8 + 4, value: threadId)
        key.setInt32(8 + 4 + 8, value: namespace)
        key.setInt32(8 + 4 + 8 + 4, value: id)
        
        return key
    }
    
    private static func extract(key: ValueBoxKey) -> (threadId: Int64, index: MessageIndex) {
        return (
            threadId: key.getInt64(8 + 4),
            index: MessageIndex(
                id: MessageId(
                    peerId: PeerId(key.getInt64(0)),
                    namespace: key.getInt32(8 + 4 + 8),
                    id: key.getInt32(8 + 4 + 8 + 4)
                ),
                timestamp: key.getInt32(8)
            )
        )
    }
    
    private func lowerBound(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    private func upperBound(peerId: PeerId) -> ValueBoxKey {
        return self.lowerBound(peerId: peerId).successor
    }
    
    func set(peerId: PeerId, threadId: Int64, info: CodableEntry) {
        self.updatedInfoItems[MessageHistoryThreadsTable.ItemId(peerId: peerId, threadId: threadId)] = info
    }
    
    func replay(threadsTable: MessageHistoryThreadsTable, namespaces: Set<MessageId.Namespace>, updatedIds: Set<MessageHistoryThreadsTable.ItemId>) -> Set<PeerId> {
        var peerIds = Set<PeerId>()
        for itemId in updatedIds.union(Set(self.updatedInfoItems.keys)) {
            let topIndex = threadsTable.getTop(peerId: itemId.peerId, threadId: itemId.threadId, namespaces: namespaces)
            let previousIndex = self.reverseIndexTable.get(peerId: itemId.peerId, threadId: itemId.threadId)
            if topIndex != previousIndex || self.updatedInfoItems[itemId] != nil {
                peerIds.insert(itemId.peerId)
                
                var info: ReadBuffer?
                if let previousIndex = previousIndex {
                    let previousKey = self.key(peerId: itemId.peerId, timestamp: previousIndex.timestamp, threadId: itemId.threadId, namespace: previousIndex.id.namespace, id: previousIndex.id.id, key: self.sharedKey)
                    if let previousValue = self.valueBox.get(self.table, key: previousKey) {
                        if previousValue.length != 0 {
                            info = previousValue
                        }
                    } else {
                        assert(false)
                    }
                    self.valueBox.remove(self.table, key: previousKey, secure: true)
                }
                if let updatedInfo = self.updatedInfoItems[itemId] {
                    info = ReadBuffer(data: updatedInfo.data)
                }
                
                if let topIndex = topIndex, let info = info {
                    if let previousIndex = previousIndex {
                        self.reverseIndexTable.set(peerId: itemId.peerId, threadId: itemId.threadId, timestamp: previousIndex.timestamp, namespace: previousIndex.id.namespace, id: previousIndex.id.id, hasValue: false)
                    }
                    
                    self.reverseIndexTable.set(peerId: itemId.peerId, threadId: itemId.threadId, timestamp: topIndex.timestamp, namespace: topIndex.id.namespace, id: topIndex.id.id, hasValue: true)
                    self.valueBox.set(self.table, key: self.key(peerId: itemId.peerId, timestamp: topIndex.timestamp, threadId: itemId.threadId, namespace: topIndex.id.namespace, id: topIndex.id.id, key: self.sharedKey), value: info)
                } else {
                    if let previousIndex = previousIndex {
                        self.reverseIndexTable.set(peerId: itemId.peerId, threadId: itemId.threadId, timestamp: previousIndex.timestamp, namespace: previousIndex.id.namespace, id: previousIndex.id.id, hasValue: false)
                        self.valueBox.remove(self.table, key: self.key(peerId: itemId.peerId, timestamp: previousIndex.timestamp, threadId: itemId.threadId, namespace: previousIndex.id.namespace, id: previousIndex.id.id, key: self.sharedKey), secure: true)
                    }
                }
            }
        }
        
        return peerIds
    }
    
    func getAll(peerId: PeerId) -> [(threadId: Int64, index: MessageIndex, info: CodableEntry)] {
        var result: [(threadId: Int64, index: MessageIndex, info: CodableEntry)] = []
        self.valueBox.range(self.table, start: self.upperBound(peerId: peerId), end: self.lowerBound(peerId: peerId), values: { key, value in
            let keyData = MessageHistoryThreadIndexTable.extract(key: key)
            if value.length == 0 {
                return true
            }
            let info = CodableEntry(data: value.makeData())
            result.append((keyData.threadId, keyData.index, info))
            return true
        }, limit: 100000)
        
        return result
    }
    
    override func beforeCommit() {
        super.beforeCommit()
        
        self.updatedInfoItems.removeAll()
    }
}

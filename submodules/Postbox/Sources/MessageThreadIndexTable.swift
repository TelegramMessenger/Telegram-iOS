import Foundation

public struct StoredMessageHistoryThreadInfo: Equatable, PostboxCoding {
    public struct Summary: Equatable, PostboxCoding {
        public var totalUnreadCount: Int32
        public var mutedUntil: Int32?
        
        public init(totalUnreadCount: Int32, mutedUntil: Int32?) {
            self.totalUnreadCount = totalUnreadCount
            self.mutedUntil = mutedUntil
        }
        
        public init(decoder: PostboxDecoder) {
            self.totalUnreadCount = decoder.decodeInt32ForKey("u", orElse: 0)
            self.mutedUntil = decoder.decodeOptionalInt32ForKey("m")
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(self.totalUnreadCount, forKey: "u")
            if let mutedUntil = self.mutedUntil {
                encoder.encodeInt32(mutedUntil, forKey: "m")
            } else {
                encoder.encodeNil(forKey: "m")
            }
        }
    }
    
    public var data: CodableEntry
    public var summary: Summary
    
    public init(data: CodableEntry, summary: Summary) {
        self.data = data
        self.summary = summary
    }
    
    public init(decoder: PostboxDecoder) {
        self.data = CodableEntry(data: decoder.decodeDataForKey("d")!)
        self.summary = decoder.decodeObjectForKey("s", decoder: { return Summary(decoder: $0) }) as! Summary
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeData(self.data.data, forKey: "d")
        encoder.encodeObject(self.summary, forKey: "s")
    }
}

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
    
    private struct UpdatedEntry {
        var value: StoredMessageHistoryThreadInfo?
    }
    
    enum IndexBoundary {
        case lowerBound
        case upperBound
        case index(StoredPeerThreadCombinedState.Index)
    }
    
    private let reverseIndexTable: MessageHistoryThreadReverseIndexTable
    
    private let sharedKey = ValueBoxKey(length: 8 + 4 + 8 + 4 + 4)
    
    private var updatedInfoItems: [MessageHistoryThreadsTable.ItemId: UpdatedEntry] = [:]
    
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
    
    func get(peerId: PeerId, threadId: Int64) -> StoredMessageHistoryThreadInfo? {
        if let updated = self.updatedInfoItems[MessageHistoryThreadsTable.ItemId(peerId: peerId, threadId: threadId)] {
            return updated.value
        } else {
            if let itemIndex = self.reverseIndexTable.get(peerId: peerId, threadId: threadId) {
                if let value = self.valueBox.get(self.table, key: self.key(peerId: itemIndex.id.peerId, timestamp: itemIndex.timestamp, threadId: threadId, namespace: itemIndex.id.namespace, id: itemIndex.id.id, key: self.sharedKey)) {
                    if value.length != 0 {
                        let decoder = PostboxDecoder(buffer: value)
                        let state = StoredMessageHistoryThreadInfo(decoder: decoder)
                        return state
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
    }
    
    func set(peerId: PeerId, threadId: Int64, info: StoredMessageHistoryThreadInfo?) {
        self.updatedInfoItems[MessageHistoryThreadsTable.ItemId(peerId: peerId, threadId: threadId)] = UpdatedEntry(value: info)
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
                    if let value = updatedInfo.value {
                        let encoder = PostboxEncoder()
                        value.encode(encoder)
                        info = encoder.makeReadBufferAndReset()
                    } else {
                        info = nil
                    }
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
    
    func fetch(peerId: PeerId, namespace: MessageId.Namespace, start: IndexBoundary, end: IndexBoundary, limit: Int) -> [(threadId: Int64, index: MessageIndex, info: StoredMessageHistoryThreadInfo)] {
        let startKey: ValueBoxKey
        switch start {
        case let .index(index):
            startKey = self.key(peerId: peerId, timestamp: index.timestamp, threadId: index.threadId, namespace: namespace, id: index.messageId, key: ValueBoxKey(length: self.sharedKey.length))
        case .lowerBound:
            startKey = self.lowerBound(peerId: peerId)
        case .upperBound:
            startKey = self.upperBound(peerId: peerId)
        }
        
        let endKey: ValueBoxKey
        switch end {
        case let .index(index):
            endKey = self.key(peerId: peerId, timestamp: index.timestamp, threadId: index.threadId, namespace: namespace, id: index.messageId, key: ValueBoxKey(length: self.sharedKey.length))
        case .lowerBound:
            endKey = self.lowerBound(peerId: peerId)
        case .upperBound:
            endKey = self.upperBound(peerId: peerId)
        }
        
        var result: [(threadId: Int64, index: MessageIndex, info: StoredMessageHistoryThreadInfo)] = []
        self.valueBox.range(self.table, start: startKey, end: endKey, values: { key, value in
            let keyData = MessageHistoryThreadIndexTable.extract(key: key)
            if value.length == 0 {
                return true
            }
            let decoder = PostboxDecoder(buffer: value)
            let state = StoredMessageHistoryThreadInfo(decoder: decoder)
            result.append((keyData.threadId, keyData.index, state))
            return true
        }, limit: limit)
        
        return result
    }
    
    func getAll(peerId: PeerId) -> [(threadId: Int64, index: MessageIndex, info: StoredMessageHistoryThreadInfo)] {
        var result: [(threadId: Int64, index: MessageIndex, info: StoredMessageHistoryThreadInfo)] = []
        self.valueBox.range(self.table, start: self.upperBound(peerId: peerId), end: self.lowerBound(peerId: peerId), values: { key, value in
            let keyData = MessageHistoryThreadIndexTable.extract(key: key)
            if value.length == 0 {
                return true
            }
            let decoder = PostboxDecoder(buffer: value)
            let state = StoredMessageHistoryThreadInfo(decoder: decoder)
            result.append((keyData.threadId, keyData.index, state))
            return true
        }, limit: 100000)
        
        return result
    }
    
    override func beforeCommit() {
        super.beforeCommit()
        
        self.updatedInfoItems.removeAll()
    }
}

class MessageHistoryThreadPinnedTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 8 + 4 + 8)
    
    override init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool) {
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(peerId: PeerId, index: Int32, threadId: Int64) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        self.sharedKey.setInt32(8, value: index)
        self.sharedKey.setInt64(8 + 4, value: threadId)
        
        return self.sharedKey
    }
    
    private static func extract(key: ValueBoxKey) -> (peerId: PeerId, threadId: Int64) {
        return (
            peerId: PeerId(key.getInt64(0)),
            threadId: key.getInt64(8 + 4)
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
    
    func get(peerId: PeerId) -> [Int64] {
        var result: [Int64] = []
        self.valueBox.range(self.table, start: self.lowerBound(peerId: peerId), end: self.upperBound(peerId: peerId), keys: { key in
            result.append(MessageHistoryThreadPinnedTable.extract(key: key).threadId)
            return true
        }, limit: 0)
        
        return result
    }
    
    func set(peerId: PeerId, threadIds: [Int64]) {
        self.valueBox.removeRange(self.table, start: self.lowerBound(peerId: peerId), end: self.upperBound(peerId: peerId))
        for i in 0 ..< threadIds.count {
            self.valueBox.set(self.table, key: self.key(peerId: peerId, index: Int32(i), threadId: threadIds[i]), value: MemoryBuffer())
        }
    }
    
    override func beforeCommit() {
        super.beforeCommit()
    }
}

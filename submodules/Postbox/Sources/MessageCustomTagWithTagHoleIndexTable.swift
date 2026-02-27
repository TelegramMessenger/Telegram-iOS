import Foundation

private func decomposeKey(_ key: ValueBoxKey) -> (id: MessageId, threadId: Int64?, tag: Int32, regularTag: UInt32) {
    let threadId = key.getInt64(8)
    return (
        MessageId(
            peerId: PeerId(key.getInt64(0)),
            namespace: key.getInt32(8 + 8 + 4 + 4),
            id: key.getInt32(8 + 8 + 4 + 4 + 4)
        ),
        threadId == 0 ? nil : threadId,
        key.getInt32(8 + 8),
        key.getUInt32(8 + 8 + 4)
    )
}

private func decodeValue(value: ReadBuffer, peerId: PeerId, namespace: MessageId.Namespace) -> MessageId {
    var id: Int32 = 0
    value.read(&id, offset: 0, length: 4)
    return MessageId(peerId: peerId, namespace: namespace, id: id)
}

final class MessageCustomTagWithTagHoleIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let seedConfiguration: SeedConfiguration
    private let metadataTable: MessageHistoryMetadataTable
    private let tagIdTable: MessageCustomTagIdTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, seedConfiguration: SeedConfiguration, metadataTable: MessageHistoryMetadataTable, tagIdTable: MessageCustomTagIdTable) {
        self.seedConfiguration = seedConfiguration
        self.metadataTable = metadataTable
        self.tagIdTable = tagIdTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(id: MessageId, threadId: Int64?, tag: Int32, regularTag: UInt32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4 + 4)
        key.setInt64(0, value: id.peerId.toInt64())
        key.setInt64(8, value: threadId ?? 0)
        key.setInt32(8 + 8, value: tag)
        key.setUInt32(8 + 8 + 4, value: regularTag)
        key.setInt32(8 + 8 + 4 + 4, value: id.namespace)
        key.setInt32(8 + 8 + 4 + 4 + 4, value: id.id)
        return key
    }
    
    private func lowerBound(peerId: PeerId, threadId: Int64?, tag: Int32, regularTag: UInt32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 8 + 4 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt64(8, value: threadId ?? 0)
        key.setInt32(8 + 8, value: tag)
        key.setUInt32(8 + 8 + 4, value: regularTag)
        return key
    }
    
    private func upperBound(peerId: PeerId, threadId: Int64?, tag: Int32, regularTag: UInt32) -> ValueBoxKey {
        return self.lowerBound(peerId: peerId, threadId: threadId, tag: tag, regularTag: regularTag).successor
    }
    
    private func lowerBound(peerId: PeerId, namespace: MessageId.Namespace, threadId: Int64?, tag: Int32, regularTag: UInt32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 8 + 4 + 4 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt64(8, value: threadId ?? 0)
        key.setInt32(8 + 8, value: tag)
        key.setUInt32(8 + 8 + 4, value: regularTag)
        key.setInt32(8 + 8 + 4 + 4, value: namespace)
        return key
    }
    
    private func upperBound(peerId: PeerId, namespace: MessageId.Namespace, threadId: Int64?, tag: Int32, regularTag: UInt32) -> ValueBoxKey {
        return self.lowerBound(peerId: peerId, namespace: namespace, threadId: threadId, tag: tag, regularTag: regularTag).successor
    }
    
    private func ensureInitialized(peerId: PeerId, threadId: Int64?, tag: Int32, tagValue: MemoryBuffer, regularTag: UInt32) {
        if !self.metadataTable.isPeerCustomTagInitialized(peerId: peerId, threadId: threadId, tag: tag, regularTag: regularTag) {
            self.metadataTable.setPeerCustomTagInitialized(peerId: peerId, threadId: threadId, tag: tag, regularTag: regularTag)
            
            if let namespaces = self.seedConfiguration.messageThreadHoles(peerId.namespace, threadId) {
                for namespace in namespaces {
                    var operations: [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]] = [:]
                    self.addInternal(peerId: peerId, threadId: threadId, tag: tag, tagValue: tagValue, regularTag: regularTag, namespace: namespace, range: 1 ... (Int32.max - 1), operations: &operations)
                }
            }
        }
    }
    
    func existingNamespaces(peerId: PeerId, threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32) -> Set<MessageId.Namespace> {
        let mappedTag = self.tagIdTable.get(tag: tag)
        
        self.ensureInitialized(peerId: peerId, threadId: threadId, tag: mappedTag, tagValue: tag, regularTag: regularTag)
        
        var result = Set<MessageId.Namespace>()
        var currentLowerBound = self.lowerBound(peerId: peerId, threadId: threadId, tag: mappedTag, regularTag: regularTag)
        let upperBound = self.upperBound(peerId: peerId, threadId: threadId, tag: mappedTag, regularTag: regularTag)
        while true {
            var decomposedKey: (id: MessageId, threadId: Int64?, tag: Int32, regularTag: UInt32)?
            self.valueBox.range(self.table, start: currentLowerBound, end: upperBound, keys: { key in
                decomposedKey = decomposeKey(key)
                return false
            }, limit: 1)
            if let decomposedKey {
                result.insert(decomposedKey.id.namespace)
                currentLowerBound = self.upperBound(peerId: peerId, namespace: decomposedKey.id.namespace, threadId: threadId, tag: mappedTag, regularTag: regularTag)
            } else {
                break
            }
        }
        return result
    }
    
    func closest(peerId: PeerId, threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, namespace: MessageId.Namespace, range: ClosedRange<MessageId.Id>) -> IndexSet {
        let mappedTag = self.tagIdTable.get(tag: tag)
        
        self.ensureInitialized(peerId: peerId, threadId: threadId, tag: mappedTag, tagValue: tag, regularTag: regularTag)
        
        var result = IndexSet()
        
        func processIntersectingRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
            let (upperId, keyThreadId, keyTag, keyRegularTag) = decomposeKey(key)
            assert(keyThreadId == threadId)
            assert(keyTag == mappedTag)
            assert(keyRegularTag == regularTag)
            assert(upperId.peerId == peerId)
            assert(upperId.namespace == namespace)
            let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
            let holeRange: ClosedRange<MessageId.Id> = lowerId.id ... upperId.id
            if holeRange.overlaps(range) {
                result.insert(integersIn: Int(holeRange.lowerBound) ... Int(holeRange.upperBound))
            }
        }
        
        func processEdgeRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
            let (upperId, keyThreadId, keyTag, keyRegularTag) = decomposeKey(key)
            assert(keyThreadId == threadId)
            assert(keyTag == mappedTag)
            assert(keyRegularTag == regularTag)
            assert(upperId.peerId == peerId)
            assert(upperId.namespace == namespace)
            let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
            let holeRange: ClosedRange<MessageId.Id> = lowerId.id ... upperId.id
            result.insert(integersIn: Int(holeRange.lowerBound) ... Int(holeRange.upperBound))
        }
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.lowerBound), threadId: threadId, tag: mappedTag, regularTag: regularTag).predecessor, end: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), threadId: threadId, tag: mappedTag, regularTag: regularTag).successor, values: { key, value in
            processIntersectingRange(key, value)
            return true
        }, limit: 0)
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), threadId: threadId, tag: mappedTag, regularTag: regularTag), end: self.upperBound(peerId: peerId, namespace: namespace, threadId: threadId, tag: mappedTag, regularTag: regularTag), values: { key, value in
            processIntersectingRange(key, value)
            return true
        }, limit: 1)
        
        if !result.contains(Int(range.lowerBound)) {
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.lowerBound), threadId: threadId, tag: mappedTag, regularTag: regularTag), end: self.lowerBound(peerId: peerId, namespace: namespace, threadId: threadId, tag: mappedTag, regularTag: regularTag), values: { key, value in
                processEdgeRange(key, value)
                return true
            }, limit: 1)
        }
        if !result.contains(Int(range.upperBound)) {
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), threadId: threadId, tag: mappedTag, regularTag: regularTag), end: self.upperBound(peerId: peerId, namespace: namespace, threadId: threadId, tag: mappedTag, regularTag: regularTag), values: { key, value in
                processEdgeRange(key, value)
                return true
            }, limit: 1)
        }
        
        return result
    }
    
    func add(peerId: PeerId, threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, namespace: MessageId.Namespace, range: ClosedRange<MessageId.Id>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
        let mappedTag = self.tagIdTable.get(tag: tag)
        
        self.ensureInitialized(peerId: peerId, threadId: threadId, tag: mappedTag, tagValue: tag, regularTag: regularTag)
        
        self.addInternal(peerId: peerId, threadId: threadId, tag: mappedTag, tagValue: tag, regularTag: regularTag, namespace: namespace, range: range, operations: &operations)
    }
    
    private func addInternal(peerId: PeerId, threadId: Int64?, tag: Int32, tagValue: MemoryBuffer, regularTag: UInt32, namespace: MessageId.Namespace, range: ClosedRange<MessageId.Id>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
        let clippedLowerBound = max(1, range.lowerBound)
        let clippedUpperBound = min(Int32.max - 1, range.upperBound)
        if clippedLowerBound > clippedUpperBound {
            return
        }
        let clippedRange = clippedLowerBound ... clippedUpperBound
        
        var insertedIndices = IndexSet()
        var removeKeys: [Int32] = []
        var insertRanges = IndexSet()
        
        var alreadyMapped = false
        
        func processRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
            let (upperId, keyThreadId, keyTag, keyRegularTag) = decomposeKey(key)
            assert(keyThreadId == threadId)
            assert(keyTag == tag)
            assert(keyRegularTag == regularTag)
            assert(upperId.peerId == peerId)
            assert(upperId.namespace == namespace)
            let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
            let holeRange: ClosedRange<Int32> = lowerId.id ... upperId.id
            if clippedRange.lowerBound >= holeRange.lowerBound && clippedRange.upperBound <= holeRange.upperBound {
                alreadyMapped = true
                return
            } else if clippedRange.overlaps(holeRange) || (holeRange.upperBound != Int32.max && clippedRange.lowerBound == holeRange.upperBound + 1) || clippedRange.upperBound == holeRange.lowerBound - 1 {
                removeKeys.append(upperId.id)
                let unionRange: ClosedRange = min(clippedRange.lowerBound, holeRange.lowerBound) ... max(clippedRange.upperBound, holeRange.upperBound)
                insertRanges.insert(integersIn: Int(unionRange.lowerBound) ... Int(unionRange.upperBound))
            }
        }
        
        let lowerScanBound = max(0, clippedRange.lowerBound - 2)
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: lowerScanBound), threadId: threadId, tag: tag, regularTag: regularTag), end: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: clippedRange.upperBound), threadId: threadId, tag: tag, regularTag: regularTag).successor, values: { key, value in
            processRange(key, value)
            if alreadyMapped {
                return false
            }
            return true
        }, limit: 0)
        
        if !alreadyMapped {
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: clippedRange.upperBound), threadId: threadId, tag: tag, regularTag: regularTag), end: self.upperBound(peerId: peerId, namespace: namespace, threadId: threadId, tag: tag, regularTag: regularTag), values: { key, value in
                processRange(key, value)
                if alreadyMapped {
                    return false
                }
                return true
            }, limit: 1)
        }
        
        if alreadyMapped {
            return
        }
        
        insertRanges.insert(integersIn: Int(clippedRange.lowerBound) ... Int(clippedRange.upperBound))
        insertedIndices.insert(integersIn: Int(clippedRange.lowerBound) ... Int(clippedRange.upperBound))
        
        for id in removeKeys {
            self.valueBox.remove(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: id), threadId: threadId, tag: tag, regularTag: regularTag), secure: false)
        }
        
        for insertRange in insertRanges.rangeView {
            let closedRange: ClosedRange<MessageId.Id> = Int32(insertRange.lowerBound) ... Int32(insertRange.upperBound - 1)
            var lowerBound: Int32 = closedRange.lowerBound
            self.valueBox.set(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: closedRange.upperBound), threadId: threadId, tag: tag, regularTag: regularTag), value: MemoryBuffer(memory: &lowerBound, capacity: 4, length: 4, freeWhenDone: false))
        }
        
        addMessageHistoryHoleOperation(.insert(clippedRange), peerId: peerId, threadId: threadId, namespace: namespace, space: .customTag(tagValue, MessageTags(rawValue: regularTag)), to: &operations)
    }
    
    func remove(peerId: PeerId, threadId: Int64?, tag: MemoryBuffer, regularTag: UInt32, namespace: MessageId.Namespace, range: ClosedRange<MessageId.Id>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
        let mappedTag = self.tagIdTable.get(tag: tag)
        
        self.ensureInitialized(peerId: peerId, threadId: threadId, tag: mappedTag, tagValue: tag, regularTag: regularTag)
        
        self.removeInternal(peerId: peerId, threadId: threadId, tag: mappedTag, tagValue: tag, regularTag: regularTag, namespace: namespace, range: range, operations: &operations)
    }
    
    private func removeInternal(peerId: PeerId, threadId: Int64?, tag: Int32, tagValue: MemoryBuffer, regularTag: UInt32, namespace: MessageId.Namespace, range: ClosedRange<MessageId.Id>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
        var removeKeys: [Int32] = []
        var insertRanges = IndexSet()
        
        func processRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
            let (upperId, keyThreadId, keyTag, keyRegularTag) = decomposeKey(key)
            assert(keyThreadId == threadId)
            assert(keyTag == tag)
            assert(keyRegularTag == regularTag)
            assert(upperId.peerId == peerId)
            assert(upperId.namespace == namespace)
            let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
            let holeRange: ClosedRange<MessageId.Id> = lowerId.id ... upperId.id
            if range.lowerBound <= holeRange.lowerBound && range.upperBound >= holeRange.upperBound {
                removeKeys.append(upperId.id)
            } else if range.overlaps(holeRange) {
                removeKeys.append(upperId.id)
                var holeIndices = IndexSet(integersIn: Int(holeRange.lowerBound) ... Int(holeRange.upperBound))
                holeIndices.remove(integersIn: Int(range.lowerBound) ... Int(range.upperBound))
                insertRanges.formUnion(holeIndices)
            }
        }
        
        let lowerScanBound = max(0, range.lowerBound - 2)
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: lowerScanBound), threadId: threadId, tag: tag, regularTag: regularTag), end: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), threadId: threadId, tag: tag, regularTag: regularTag).successor, values: { key, value in
            processRange(key, value)
            return true
        }, limit: 0)
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), threadId: threadId, tag: tag, regularTag: regularTag), end: self.upperBound(peerId: peerId, namespace: namespace, threadId: threadId, tag: tag, regularTag: regularTag), values: { key, value in
            processRange(key, value)
            return true
        }, limit: 1)
        
        for id in removeKeys {
            self.valueBox.remove(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: id), threadId: threadId, tag: tag, regularTag: regularTag), secure: false)
        }
        
        for insertRange in insertRanges.rangeView {
            let closedRange: ClosedRange<MessageId.Id> = Int32(insertRange.lowerBound) ... Int32(insertRange.upperBound - 1)
            var lowerBound: Int32 = closedRange.lowerBound
            self.valueBox.set(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: closedRange.upperBound), threadId: threadId, tag: tag, regularTag: regularTag), value: MemoryBuffer(memory: &lowerBound, capacity: 4, length: 4, freeWhenDone: false))
        }
        
        if !removeKeys.isEmpty {
            addMessageHistoryHoleOperation(.remove(range), peerId: peerId, threadId: threadId, namespace: namespace, space: .customTag(tagValue, MessageTags(rawValue: regularTag)), to: &operations)
        }
    }
    
    func resetAll() {
        self.clearMemoryCache()
        
        self.valueBox.removeAllFromTable(self.table)
        self.metadataTable.removePeerCustomTagInitializedList()
    }
}

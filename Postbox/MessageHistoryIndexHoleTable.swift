import Foundation

struct MessageHistoryIndexHoleOperationKey: Hashable {
    let peerId: PeerId
    let namespace: MessageId.Namespace
    let tag: MessageTags
}

enum MessageHistoryIndexHoleOperation {
    case insert(IndexSet)
    case remove(IndexSet)
}

private func addOperation(_ operation: MessageHistoryIndexHoleOperation, peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags, to operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
    let key = MessageHistoryIndexHoleOperationKey(peerId: peerId, namespace: namespace, tag: tag)
    if operations[key] == nil {
        operations[key] = []
    }
    operations[key]!.append(operation)
}

private func decomposeKey(_ key: ValueBoxKey) -> (id: MessageId, tag: MessageTags) {
    return (MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8), id: key.getInt32(8 + 4 + 4)), MessageTags(rawValue: key.getUInt32(8 + 4)))
}

private func decodeValue(value: ReadBuffer, peerId: PeerId, namespace: MessageId.Namespace) -> MessageId {
    var id: Int32 = 0
    value.read(&id, offset: 0, length: 4)
    return MessageId(peerId: peerId, namespace: namespace, id: id)
}

final class MessageHistoryIndexHoleTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    let metadataTable: MessageHistoryMetadataTable
    let seedConfiguration: SeedConfiguration
    
    init(valueBox: ValueBox, table: ValueBoxTable, metadataTable: MessageHistoryMetadataTable, seedConfiguration: SeedConfiguration) {
        self.seedConfiguration = seedConfiguration
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(id: MessageId, tag: MessageTags) -> ValueBoxKey {
        assert(tag.containsSingleElement)
        let key = ValueBoxKey(length: 8 + 4 + 4 + 4)
        key.setInt64(0, value: id.peerId.toInt64())
        key.setInt32(8, value: id.namespace)
        key.setUInt32(8 + 4, value: tag.rawValue)
        key.setInt32(8 + 4 + 4, value: id.id)
        return key
    }
    
    private func lowerBound(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags) -> ValueBoxKey {
        assert(tag.containsSingleElement)
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key
    }
    
    private func upperBound(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags) -> ValueBoxKey {
        assert(tag.containsSingleElement)
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key.successor
    }
    
    func intersecting(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags, range: ClosedRange<Int32>) -> IndexSet {
        assert(tag.containsSingleElement)
        
        var result = IndexSet()
        
        func processRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
            let (upperId, keyTag) = decomposeKey(key)
            assert(keyTag == tag)
            assert(upperId.peerId == peerId)
            assert(upperId.namespace == namespace)
            let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
            let holeRange: ClosedRange<Int32> = lowerId.id ... upperId.id
            result.insert(integersIn: Int(holeRange.lowerBound) ... Int(holeRange.upperBound))
        }
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.lowerBound), tag: tag).predecessor, end: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), tag: tag).successor, values: { key, value in
            processRange(key, value)
            return true
        }, limit: 0)
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), tag: tag), end: self.upperBound(peerId: peerId, namespace: namespace, tag: tag), values: { key, value in
            processRange(key, value)
            return true
        }, limit: 1)
        
        return result
    }
    
    func add(peerId: PeerId, namespace: MessageId.Namespace, tags: MessageTags, range: ClosedRange<Int32>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
        for tag in tags {
            var removedIndices = IndexSet()
            var insertedIndices = IndexSet()
            var removeKeys: [Int32] = []
            var insertRanges = IndexSet()
            
            insertRanges.insert(integersIn: Int(range.lowerBound) ... Int(range.upperBound))
            insertedIndices.insert(integersIn: Int(range.lowerBound) ... Int(range.upperBound))
            
            func processRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
                let (upperId, keyTag) = decomposeKey(key)
                assert(keyTag == tag)
                assert(upperId.peerId == peerId)
                assert(upperId.namespace == namespace)
                let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
                let holeRange: ClosedRange<Int32> = lowerId.id ... upperId.id
                if range.lowerBound <= holeRange.lowerBound && range.upperBound >= holeRange.upperBound {
                    removeKeys.append(upperId.id)
                } else if range.overlaps(holeRange) || range.lowerBound == holeRange.upperBound + 1 || range.upperBound == holeRange.lowerBound - 1 {
                    removeKeys.append(upperId.id)
                    let unionRange: ClosedRange = min(range.lowerBound, holeRange.lowerBound) ... max(range.upperBound, holeRange.upperBound)
                    insertRanges.insert(integersIn: Int(unionRange.lowerBound) ... Int(unionRange.upperBound))
                }
            }
            
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.lowerBound), tag: tag).predecessor, end: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), tag: tag).successor, values: { key, value in
                processRange(key, value)
                return true
            }, limit: 0)
            
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), tag: tag), end: self.upperBound(peerId: peerId, namespace: namespace, tag: tag), values: { key, value in
                processRange(key, value)
                return true
            }, limit: 1)
            
            for id in removeKeys {
                self.valueBox.remove(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: id), tag: tag))
            }
            
            if !removedIndices.isEmpty {
                addOperation(.remove(removedIndices), peerId: peerId, namespace: namespace, tag: tag, to: &operations)
            }
            
            if !insertedIndices.isEmpty {
                addOperation(.insert(removedIndices), peerId: peerId, namespace: namespace, tag: tag, to: &operations)
            }
            
            for insertRange in insertRanges.rangeView {
                let closedRange: ClosedRange<Int32> = Int32(insertRange.lowerBound) ... Int32(insertRange.upperBound - 1)
                var lowerBound: Int32 = closedRange.lowerBound
                self.valueBox.set(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: closedRange.upperBound), tag: tag), value: MemoryBuffer(memory: &lowerBound, capacity: 4, length: 4, freeWhenDone: false))
            }
        }
    }
    
    func remove(peerId: PeerId, namespace: MessageId.Namespace, tags: MessageTags, range: ClosedRange<Int32>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
        for tag in tags {
            var removedIndices = IndexSet()
            var insertedIndices = IndexSet()
            var removeKeys: [Int32] = []
            var insertRanges = IndexSet()
            
            func processRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
                let (upperId, keyTag) = decomposeKey(key)
                assert(keyTag == tag)
                assert(upperId.peerId == peerId)
                assert(upperId.namespace == namespace)
                let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
                let holeRange: ClosedRange<Int32> = lowerId.id ... upperId.id
                if range.lowerBound <= holeRange.lowerBound && range.upperBound >= holeRange.upperBound {
                    removeKeys.append(upperId.id)
                } else if range.overlaps(holeRange) {
                    removeKeys.append(upperId.id)
                    var holeIndices = IndexSet(integersIn: Int(holeRange.lowerBound) ... Int(holeRange.upperBound))
                    holeIndices.remove(integersIn: Int(range.lowerBound) ... Int(range.upperBound))
                    insertRanges.formUnion(holeIndices)
                }
            }
            
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.lowerBound), tag: tag).predecessor, end: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), tag: tag).successor, values: { key, value in
                processRange(key, value)
                return true
            }, limit: 0)
            
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), tag: tag), end: self.upperBound(peerId: peerId, namespace: namespace, tag: tag), values: { key, value in
                processRange(key, value)
                return true
            }, limit: 1)
            
            for id in removeKeys {
                self.valueBox.remove(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: id), tag: tag))
            }
            
            if !removedIndices.isEmpty {
                addOperation(.remove(removedIndices), peerId: peerId, namespace: namespace, tag: tag, to: &operations)
            }
            
            for insertRange in insertRanges.rangeView {
                let closedRange: ClosedRange<Int32> = Int32(insertRange.lowerBound) ... Int32(insertRange.upperBound - 1)
                var lowerBound: Int32 = closedRange.lowerBound
                self.valueBox.set(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: closedRange.upperBound), tag: tag), value: MemoryBuffer(memory: &lowerBound, capacity: 4, length: 4, freeWhenDone: false))
            }
        }
    }
}

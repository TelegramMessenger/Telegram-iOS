import Foundation

struct MessageHistoryIndexHoleOperationKey: Hashable {
    let peerId: PeerId
    let namespace: MessageId.Namespace
    let space: MessageHistoryHoleSpace
}

enum MessageHistoryIndexHoleOperation {
    case insert(ClosedRange<MessageId.Id>)
    case remove(ClosedRange<MessageId.Id>)
}

public enum MessageHistoryHoleSpace: Equatable, Hashable, CustomStringConvertible {
    case everywhere
    case tag(MessageTags)
    
    public var description: String {
        switch self {
        case .everywhere:
            return ".everywhere"
        case let .tag(tags):
            return ".tag\(tags.rawValue)"
        }
    }
}

private func addOperation(_ operation: MessageHistoryIndexHoleOperation, peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, to operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
    let key = MessageHistoryIndexHoleOperationKey(peerId: peerId, namespace: namespace, space: space)
    if operations[key] == nil {
        operations[key] = []
    }
    operations[key]!.append(operation)
}

private func decomposeKey(_ key: ValueBoxKey) -> (id: MessageId, space: MessageHistoryHoleSpace) {
    let tag = MessageTags(rawValue: key.getUInt32(8 + 4))
    let space: MessageHistoryHoleSpace
    if tag.rawValue == 0 {
        space = .everywhere
    } else {
        space = .tag(tag)
    }
    return (MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8), id: key.getInt32(8 + 4 + 4)), space)
}

private func decodeValue(value: ReadBuffer, peerId: PeerId, namespace: MessageId.Namespace) -> MessageId {
    var id: Int32 = 0
    value.read(&id, offset: 0, length: 4)
    return MessageId(peerId: peerId, namespace: namespace, id: id)
}

final class MessageHistoryHoleIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    let metadataTable: MessageHistoryMetadataTable
    let seedConfiguration: SeedConfiguration
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, metadataTable: MessageHistoryMetadataTable, seedConfiguration: SeedConfiguration) {
        self.seedConfiguration = seedConfiguration
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(id: MessageId, space: MessageHistoryHoleSpace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4 + 4 + 4)
        key.setInt64(0, value: id.peerId.toInt64())
        key.setInt32(8, value: id.namespace)
        let tagValue: UInt32
        switch space {
            case .everywhere:
                tagValue = 0
            case let .tag(tag):
                tagValue = tag.rawValue
        }
        key.setUInt32(8 + 4, value: tagValue)
        key.setInt32(8 + 4 + 4, value: id.id)
        return key
    }
    
    private func lowerBound(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    private func upperBound(peerId: PeerId) -> ValueBoxKey {
        return self.lowerBound(peerId: peerId).successor
    }
    
    private func lowerBound(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        let tagValue: UInt32
        switch space {
            case .everywhere:
                tagValue = 0
            case let .tag(tag):
                tagValue = tag.rawValue
        }
        key.setUInt32(8 + 4, value: tagValue)
        return key
    }
    
    private func upperBound(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        let tagValue: UInt32
        switch space {
            case .everywhere:
                tagValue = 0
            case let .tag(tag):
                tagValue = tag.rawValue
        }
        key.setUInt32(8 + 4, value: tagValue)
        return key.successor
    }
    
    private func namespaceLowerBound(peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key
    }
    
    private func namespaceUpperBound(peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key.successor
    }
    
    private func ensureInitialized(peerId: PeerId) {
        if !self.metadataTable.isInitialized(peerId) {
            self.metadataTable.setInitialized(peerId)
            if let tagsByNamespace = self.seedConfiguration.messageHoles[peerId.namespace] {
                for (namespace, tags) in tagsByNamespace {
                    for tag in tags {
                        self.metadataTable.setPeerTagInitialized(peerId: peerId, tag: tag)
                    }
                    var operations: [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]] = [:]
                    self.add(peerId: peerId, namespace: namespace, space: .everywhere, range: 1 ... (Int32.max - 1), operations: &operations)
                }
            }
        } else {
            if let tagsByNamespace = self.seedConfiguration.upgradedMessageHoles[peerId.namespace] {
                for (namespace, tags) in tagsByNamespace {
                    for tag in tags {
                        if !self.metadataTable.isPeerTagInitialized(peerId: peerId, tag: tag) {
                            self.metadataTable.setPeerTagInitialized(peerId: peerId, tag: tag)
                            var operations: [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]] = [:]
                            self.add(peerId: peerId, namespace: namespace, space: .tag(tag), range: 1 ... (Int32.max - 1), operations: &operations)
                        }
                    }
                }
            }
        }
    }
    
    func existingNamespaces(peerId: PeerId, holeSpace: MessageHistoryHoleSpace) -> Set<MessageId.Namespace> {
        self.ensureInitialized(peerId: peerId)
        
        var result = Set<MessageId.Namespace>()
        var currentLowerBound = self.lowerBound(peerId: peerId)
        let upperBound = self.upperBound(peerId: peerId)
        while true {
            var idAndSpace: (MessageId, MessageHistoryHoleSpace)?
            self.valueBox.range(self.table, start: currentLowerBound, end: upperBound, keys: { key in
                idAndSpace = decomposeKey(key)
                return false
            }, limit: 1)
            if let (id, space) = idAndSpace {
                if space == holeSpace {
                    result.insert(id.namespace)
                }
                currentLowerBound = self.upperBound(peerId: peerId, namespace: id.namespace, space: space)
            } else {
                break
            }
        }
        return result
    }
    
    private func scanSpaces(peerId: PeerId, namespace: MessageId.Namespace) -> [MessageHistoryHoleSpace] {
        self.ensureInitialized(peerId: peerId)
        
        var currentLowerBound = self.namespaceLowerBound(peerId: peerId, namespace: namespace)
        var result: [MessageHistoryHoleSpace] = []
        while true {
            var found = false
            self.valueBox.range(self.table, start: currentLowerBound, end: self.namespaceUpperBound(peerId: peerId, namespace: namespace), keys: { key in
                let space = decomposeKey(key).space
                result.append(space)
                currentLowerBound = self.upperBound(peerId: peerId, namespace: namespace, space: space)
                found = true
                return false
            }, limit: 1)
            if !found {
                break
            }
        }
        assert(Set(result).count == result.count)
        return result
    }
    
    func containing(id: MessageId) -> [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] {
        self.ensureInitialized(peerId: id.peerId)
        
        var result: [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] = [:]
        for space in self.scanSpaces(peerId: id.peerId, namespace: id.namespace) {
            self.valueBox.range(self.table, start: self.key(id: id, space: space), end: self.upperBound(peerId: id.peerId, namespace: id.namespace, space: space), values: { key, value in
                let (upperId, keySpace) = decomposeKey(key)
                assert(keySpace == space)
                assert(upperId.peerId == id.peerId)
                assert(upperId.namespace == id.namespace)
                let lowerId = decodeValue(value: value, peerId: id.peerId, namespace: id.namespace)
                let holeRange: ClosedRange<MessageId.Id> = lowerId.id ... upperId.id
                result[space] = holeRange
                return false
            }, limit: 1)
        }
        return result
    }
    
    func closest(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, range: ClosedRange<MessageId.Id>) -> IndexSet {
        self.ensureInitialized(peerId: peerId)
        
        var result = IndexSet()
        
        func processIntersectingRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
            let (upperId, keySpace) = decomposeKey(key)
            assert(keySpace == space)
            assert(upperId.peerId == peerId)
            assert(upperId.namespace == namespace)
            let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
            let holeRange: ClosedRange<MessageId.Id> = lowerId.id ... upperId.id
            if holeRange.overlaps(range) {
                result.insert(integersIn: Int(holeRange.lowerBound) ... Int(holeRange.upperBound))
            }
        }
        
        func processEdgeRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
            let (upperId, keySpace) = decomposeKey(key)
            assert(keySpace == space)
            assert(upperId.peerId == peerId)
            assert(upperId.namespace == namespace)
            let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
            let holeRange: ClosedRange<MessageId.Id> = lowerId.id ... upperId.id
            result.insert(integersIn: Int(holeRange.lowerBound) ... Int(holeRange.upperBound))
        }
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.lowerBound), space: space).predecessor, end: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), space: space).successor, values: { key, value in
            processIntersectingRange(key, value)
            return true
        }, limit: 0)
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), space: space), end: self.upperBound(peerId: peerId, namespace: namespace, space: space), values: { key, value in
            processIntersectingRange(key, value)
            return true
        }, limit: 1)
        
        if !result.contains(Int(range.lowerBound)) {
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.lowerBound), space: space), end: self.lowerBound(peerId: peerId, namespace: namespace, space: space), values: { key, value in
                processEdgeRange(key, value)
                return true
            }, limit: 1)
        }
        if !result.contains(Int(range.upperBound)) {
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), space: space), end: self.upperBound(peerId: peerId, namespace: namespace, space: space), values: { key, value in
                processEdgeRange(key, value)
                return true
            }, limit: 1)
        }
        
        return result
    }
    
    func add(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, range: ClosedRange<MessageId.Id>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
        self.ensureInitialized(peerId: peerId)
        
        self.addInternal(peerId: peerId, namespace: namespace, space: space, range: range, operations: &operations)
        
        switch space {
            case .everywhere:
                if let namespaceHoleTags = self.seedConfiguration.messageHoles[peerId.namespace]?[namespace] {
                    for tag in namespaceHoleTags {
                        self.addInternal(peerId: peerId, namespace: namespace, space: .tag(tag), range: range, operations: &operations)
                    }
                }
            case .tag:
                break
        }
    }
    
    private func addInternal(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, range: ClosedRange<MessageId.Id>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
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
            let (upperId, keySpace) = decomposeKey(key)
            assert(keySpace == space)
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
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: lowerScanBound), space: space), end: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: clippedRange.upperBound), space: space).successor, values: { key, value in
            processRange(key, value)
            if alreadyMapped {
                return false
            }
            return true
        }, limit: 0)
        
        if !alreadyMapped {
            self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: clippedRange.upperBound), space: space), end: self.upperBound(peerId: peerId, namespace: namespace, space: space), values: { key, value in
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
            self.valueBox.remove(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: id), space: space), secure: false)
        }
        
        for insertRange in insertRanges.rangeView {
            let closedRange: ClosedRange<MessageId.Id> = Int32(insertRange.lowerBound) ... Int32(insertRange.upperBound - 1)
            var lowerBound: Int32 = closedRange.lowerBound
            self.valueBox.set(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: closedRange.upperBound), space: space), value: MemoryBuffer(memory: &lowerBound, capacity: 4, length: 4, freeWhenDone: false))
        }
        
        addOperation(.insert(clippedRange), peerId: peerId, namespace: namespace, space: space, to: &operations)
    }
    
    func remove(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, range: ClosedRange<MessageId.Id>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
        self.ensureInitialized(peerId: peerId)
        
        self.removeInternal(peerId: peerId, namespace: namespace, space: space, range: range, operations: &operations)
        
        switch space {
            case .everywhere:
                if let namespaceHoleTags = self.seedConfiguration.messageHoles[peerId.namespace]?[namespace] {
                    for tag in namespaceHoleTags {
                        self.removeInternal(peerId: peerId, namespace: namespace, space: .tag(tag), range: range, operations: &operations)
                    }
                }
            case .tag:
                break
        }
    }
    
    private func removeInternal(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, range: ClosedRange<MessageId.Id>, operations: inout [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]) {
        postboxLog("MessageHistoryHoleIndexTable: removeInternal peerId: \(peerId) namespace: \(namespace) space: \(space) range: \(range)")
        
        var removeKeys: [Int32] = []
        var insertRanges = IndexSet()
        
        func processRange(_ key: ValueBoxKey, _ value: ReadBuffer) {
            let (upperId, keySpace) = decomposeKey(key)
            assert(keySpace == space)
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
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: lowerScanBound), space: space), end: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), space: space).successor, values: { key, value in
            processRange(key, value)
            return true
        }, limit: 0)
        
        self.valueBox.range(self.table, start: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: range.upperBound), space: space), end: self.upperBound(peerId: peerId, namespace: namespace, space: space), values: { key, value in
            processRange(key, value)
            return true
        }, limit: 1)
        
        for id in removeKeys {
            self.valueBox.remove(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: id), space: space), secure: false)
        }
        
        for insertRange in insertRanges.rangeView {
            let closedRange: ClosedRange<MessageId.Id> = Int32(insertRange.lowerBound) ... Int32(insertRange.upperBound - 1)
            var lowerBound: Int32 = closedRange.lowerBound
            self.valueBox.set(self.table, key: self.key(id: MessageId(peerId: peerId, namespace: namespace, id: closedRange.upperBound), space: space), value: MemoryBuffer(memory: &lowerBound, capacity: 4, length: 4, freeWhenDone: false))
        }
        
        if !removeKeys.isEmpty {
            addOperation(.remove(range), peerId: peerId, namespace: namespace, space: space, to: &operations)
        }
    }
    
    func debugList(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace) -> [ClosedRange<MessageId.Id>] {
        var result: [ClosedRange<MessageId.Id>] = []
        self.valueBox.range(self.table, start: self.lowerBound(peerId: peerId, namespace: namespace, space: space), end: self.upperBound(peerId: peerId, namespace: namespace, space: space), values: { key, value in
            let (upperId, keySpace) = decomposeKey(key)
            assert(keySpace == space)
            assert(upperId.peerId == peerId)
            assert(upperId.namespace == namespace)
            let lowerId = decodeValue(value: value, peerId: peerId, namespace: namespace)
            let holeRange: ClosedRange<MessageId.Id> = lowerId.id ... upperId.id
            result.append(holeRange)
            return true
        }, limit: 0)
        return result
    }
}

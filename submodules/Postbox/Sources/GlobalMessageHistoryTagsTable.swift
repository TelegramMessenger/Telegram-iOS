import Foundation

enum IntermediateGlobalMessageTagsEntry {
    case message(IntermediateMessage)
    case hole(MessageIndex)
    
    var index: MessageIndex {
        switch self {
            case let .message(message):
                return message.index
            case let .hole(index):
                return index
        }
    }
}

enum GlobalMessageHistoryTagsTableEntry {
    case message(MessageIndex)
    case hole(MessageIndex)
    
    var index: MessageIndex {
        switch self {
            case let .message(index):
                return index
            case let .hole(index):
                return index
        }
    }
}

enum GlobalMessageHistoryTagsOperation {
    case insertMessage(GlobalMessageTags, IntermediateMessage)
    case insertHole(GlobalMessageTags, MessageIndex)
    case remove([(GlobalMessageTags, MessageIndex)])
    case updateTimestamp(GlobalMessageTags, MessageIndex, Int32)
}

private func parseEntry(key: ValueBoxKey, value: ReadBuffer) -> GlobalMessageHistoryTagsTableEntry {
    var type: Int8 = 0
    value.read(&type, offset: 0, length: 1)
    let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(4 + 4 + 4 + 4)), namespace: key.getInt32(4 + 4), id: key.getInt32(4 + 4 + 4)), timestamp: key.getInt32(4))
    if type == 0 {
        return .message(index)
    } else if type == 1 {
        return .hole(index)
    } else {
        preconditionFailure()
    }
}

class GlobalMessageHistoryTagsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let sharedKey = ValueBoxKey(length: 4 + 4 + 4 + 4 + 8)
    
    private var cachedInitializedTags = Set<GlobalMessageTags>()
    
    private func key(_ tagMask: GlobalMessageTags, index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 4 + 4 + 4 + 4 + 8)) -> ValueBoxKey {
        key.setUInt32(0, value: tagMask.rawValue)
        key.setInt32(4, value: index.timestamp)
        key.setInt32(4 + 4, value: index.id.namespace)
        key.setInt32(4 + 4 + 4, value: index.id.id)
        key.setInt64(4 + 4 + 4 + 4, value: index.id.peerId.toInt64())
        return key
    }
    
    private func lowerBound(_ tagMask: GlobalMessageTags) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setUInt32(0, value: tagMask.rawValue)
        return key
    }
    
    private func upperBound(_ tagMask: GlobalMessageTags) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setUInt32(0, value: tagMask.rawValue)
        return key.successor
    }
    
    func ensureInitialized(_ tagMask: GlobalMessageTags) {
        for tag in tagMask {
            if !self.cachedInitializedTags.contains(tag) {
                var isEmpty = true
                self.valueBox.range(self.table, start: self.lowerBound(tag), end: self.upperBound(tag), keys: { _ in
                    isEmpty = false
                    return false
                }, limit: 1)
                if isEmpty {
                    self.addHole(tag, index: MessageIndex.absoluteUpperBound())
                }
                self.cachedInitializedTags.insert(tag)
            }
        }
    }
    
    func addMessage(_ tagMask: GlobalMessageTags, index: MessageIndex) -> Bool {
        self.ensureInitialized(tagMask)
        
        assert(tagMask.isSingleTag)
        var upperIsHole = false
        self.valueBox.range(self.table, start: self.key(tagMask, index: index, key: self.sharedKey), end: self.upperBound(tagMask), values: { key, value in
            let entry = parseEntry(key: key, value: value)
            if case .hole = entry {
                upperIsHole = true
            }
            return false
        }, limit: 1)
        if !upperIsHole {
            var type: Int8 = 0
            self.valueBox.set(self.table, key: self.key(tagMask, index: index, key: self.sharedKey), value: MemoryBuffer(memory: &type, capacity: 1, length: 1, freeWhenDone: false))
            return true
        } else {
            return false
        }
    }
    
    func addHole(_ tagMask: GlobalMessageTags, index: MessageIndex) {
        assert(tagMask.isSingleTag)
        var type: Int8 = 1
        self.valueBox.set(self.table, key: self.key(tagMask, index: index, key: self.sharedKey), value: MemoryBuffer(memory: &type, capacity: 1, length: 1, freeWhenDone: false))
    }
    
    func remove(_ tagMask: GlobalMessageTags, index: MessageIndex) {
        assert(tagMask.isSingleTag)
        self.valueBox.remove(self.table, key: self.key(tagMask, index: index, key: self.sharedKey), secure: false)
    }
    
    func get(_ tagMask: GlobalMessageTags, index: MessageIndex) -> GlobalMessageHistoryTagsTableEntry? {
        let key = self.key(tagMask, index: index)
        if let value = self.valueBox.get(self.table, key: key) {
            return parseEntry(key: key, value: value)
        } else {
            return nil
        }
    }
    
    func entriesAround(_ tagMask: GlobalMessageTags, index: MessageIndex, count: Int) -> (entries: [GlobalMessageHistoryTagsTableEntry], lower: GlobalMessageHistoryTagsTableEntry?, upper: GlobalMessageHistoryTagsTableEntry?) {
        var lowerEntries: [GlobalMessageHistoryTagsTableEntry] = []
        var upperEntries: [GlobalMessageHistoryTagsTableEntry] = []
        var lower: GlobalMessageHistoryTagsTableEntry?
        var upper: GlobalMessageHistoryTagsTableEntry?
        
        self.valueBox.range(self.table, start: self.key(tagMask, index: index), end: self.lowerBound(tagMask), values: { key, value in
            lowerEntries.append(parseEntry(key: key, value: value))
            return true
        }, limit: count / 2 + 1)
        
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        self.valueBox.range(self.table, start: self.key(tagMask, index: index).predecessor, end: self.upperBound(tagMask), values: { key, value in
            upperEntries.append(parseEntry(key: key, value: value))
            return true
        }, limit: count - lowerEntries.count + 1)
        if upperEntries.count >= count - lowerEntries.count + 1 {
            upper = upperEntries.last
            upperEntries.removeLast()
        }
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            var additionalLowerEntries: [GlobalMessageHistoryTagsTableEntry] = []
            self.valueBox.range(self.table, start: self.key(tagMask, index: lowerEntries.last!.index), end: self.lowerBound(tagMask), values: { key, value in
                additionalLowerEntries.append(parseEntry(key: key, value: value))
                return true
            }, limit: count - lowerEntries.count - upperEntries.count + 1)
            if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
                lower = additionalLowerEntries.last
                additionalLowerEntries.removeLast()
            }
            lowerEntries.append(contentsOf: additionalLowerEntries)
        }
        
        var entries: [GlobalMessageHistoryTagsTableEntry] = []
        entries.append(contentsOf: lowerEntries.reversed())
        entries.append(contentsOf: upperEntries)
        return (entries: entries, lower: lower, upper: upper)
    }
    
    func earlierEntries(_ tagMask: GlobalMessageTags, index: MessageIndex?, count: Int) -> [GlobalMessageHistoryTagsTableEntry] {
        var indices: [GlobalMessageHistoryTagsTableEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(tagMask, index: index)
        } else {
            key = self.upperBound(tagMask)
        }
        self.valueBox.range(self.table, start: key, end: self.lowerBound(tagMask), values: { key, value in
            indices.append(parseEntry(key: key, value: value))
            return true
        }, limit: count)
        return indices
    }
    
    func laterEntries(_ tagMask: GlobalMessageTags, index: MessageIndex?, count: Int) -> [GlobalMessageHistoryTagsTableEntry] {
        var indices: [GlobalMessageHistoryTagsTableEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(tagMask, index: index)
        } else {
            key = self.lowerBound(tagMask)
        }
        self.valueBox.range(self.table, start: key, end: self.upperBound(tagMask), values: { key, value in
            indices.append(parseEntry(key: key, value: value))
            return true
        }, limit: count)
        return indices
    }
    
    func getAll() -> [GlobalMessageHistoryTagsTableEntry] {
        var indices: [GlobalMessageHistoryTagsTableEntry] = []
        self.valueBox.scan(self.table, values: { key, value in
            indices.append(parseEntry(key: key, value: value))
            return true
        })
        return indices
    }
}

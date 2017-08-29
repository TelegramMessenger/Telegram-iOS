import Foundation

public struct InvalidatedMessageHistoryTagsSummaryKey: Hashable {
    public let peerId: PeerId
    public let namespace: MessageId.Namespace
    public let tagMask: MessageTags
    
    public init(peerId: PeerId, namespace: MessageId.Namespace, tagMask: MessageTags) {
        self.peerId = peerId
        self.namespace = namespace
        self.tagMask = tagMask
    }
    
    public var hashValue: Int {
        return (self.peerId.hashValue &* (31 * 31)) &+ (self.namespace.hashValue &* 31) + self.tagMask.rawValue.hashValue
    }
    
    public static func ==(lhs: InvalidatedMessageHistoryTagsSummaryKey, rhs: InvalidatedMessageHistoryTagsSummaryKey) -> Bool {
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.namespace != rhs.namespace {
            return false
        }
        if lhs.tagMask != rhs.tagMask {
            return false
        }
        return true
    }
}

public struct InvalidatedMessageHistoryTagsSummaryEntry: Hashable {
    public let key: InvalidatedMessageHistoryTagsSummaryKey
    public let version: Int32
    
    public var hashValue: Int {
        return (self.key.hashValue &* 31) &+ self.version.hashValue
    }
    
    public static func ==(lhs: InvalidatedMessageHistoryTagsSummaryEntry, rhs: InvalidatedMessageHistoryTagsSummaryEntry) -> Bool {
        if lhs.key != rhs.key {
            return false
        }
        if lhs.version != rhs.version {
            return false
        }
        return true
    }
}

enum InvalidatedMessageHistoryTagsSummaryEntryOperation {
    case add(InvalidatedMessageHistoryTagsSummaryEntry)
    case remove(InvalidatedMessageHistoryTagsSummaryKey)
}

final class InvalidatedMessageHistoryTagsSummaryTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    private func key(_ key: InvalidatedMessageHistoryTagsSummaryKey) -> ValueBoxKey {
        let result = ValueBoxKey(length: 4 + 4 + 8)
        result.setUInt32(0, value: key.tagMask.rawValue)
        result.setInt32(4, value: key.namespace)
        result.setInt64(4 + 4, value: key.peerId.toInt64())
        return result
    }
    
    private func lowerBound(tagMask: MessageTags, namespace: MessageId.Namespace) -> ValueBoxKey {
        let result = ValueBoxKey(length: 4 + 4)
        result.setUInt32(0, value: tagMask.rawValue)
        result.setInt32(4, value: namespace)
        return result
    }
    
    private func upperBound(tagMask: MessageTags, namespace: MessageId.Namespace) -> ValueBoxKey {
        return self.lowerBound(tagMask: tagMask, namespace: namespace).successor
    }
    
    func get(tagMask: MessageTags, namespace: MessageId.Namespace) -> [InvalidatedMessageHistoryTagsSummaryEntry] {
        var entries: [InvalidatedMessageHistoryTagsSummaryEntry] = []
        self.valueBox.range(self.table, start: self.lowerBound(tagMask: tagMask, namespace: namespace), end: self.upperBound(tagMask: tagMask, namespace: namespace), values: { key, value in
            var version: Int32 = 0
            value.read(&version, offset: 0, length: 4)
            entries.append(InvalidatedMessageHistoryTagsSummaryEntry(key: InvalidatedMessageHistoryTagsSummaryKey(peerId: PeerId(key.getInt64(4 + 4)), namespace: key.getInt32(4), tagMask: MessageTags(rawValue: key.getUInt32(0))), version: version))
            return true
        }, limit: 0)
        return entries
    }
    
    private func get(_ key: InvalidatedMessageHistoryTagsSummaryKey) -> InvalidatedMessageHistoryTagsSummaryEntry? {
        if let value = self.valueBox.get(self.table, key: self.key(key)) {
            var version: Int32 = 0
            value.read(&version, offset: 0, length: 4)
            return InvalidatedMessageHistoryTagsSummaryEntry(key: key, version: version)
        } else {
            return nil
        }
    }
    
    func insert(_ key: InvalidatedMessageHistoryTagsSummaryKey, operations: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        var version: Int32 = 0
        if let entry = self.get(key) {
            self.remove(entry, operations: &operations)
            version = entry.version + 1
        }
        self.valueBox.set(self.table, key: self.key(key), value: MemoryBuffer(memory: &version, capacity: 4, length: 4, freeWhenDone: false))
        operations.append(.add(InvalidatedMessageHistoryTagsSummaryEntry(key: key, version: version)))
    }
    
    func remove(_ entry: InvalidatedMessageHistoryTagsSummaryEntry, operations: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        if let current = self.get(entry.key), current.version == entry.version {
            self.valueBox.remove(self.table, key: self.key(entry.key))
            operations.append(.remove(entry.key))
        }
    }
    
    override func clearMemoryCache() {
    }
    
    override func beforeCommit() {
    }
}

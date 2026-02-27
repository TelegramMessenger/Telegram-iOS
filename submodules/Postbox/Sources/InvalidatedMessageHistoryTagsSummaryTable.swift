import Foundation

public struct InvalidatedMessageHistoryTagsSummaryKey: Comparable, Hashable {
    public let peerId: PeerId
    public let namespace: MessageId.Namespace
    public let tagMask: MessageTags
    public let threadId: Int64?
    public let customTag: MemoryBuffer?
    
    public init(peerId: PeerId, namespace: MessageId.Namespace, tagMask: MessageTags, threadId: Int64?, customTag: MemoryBuffer?) {
        self.peerId = peerId
        self.namespace = namespace
        self.tagMask = tagMask
        self.threadId = threadId
        self.customTag = customTag
    }
    
    public static func <(lhs: InvalidatedMessageHistoryTagsSummaryKey, rhs: InvalidatedMessageHistoryTagsSummaryKey) -> Bool {
        if lhs.peerId != rhs.peerId {
            return lhs.peerId < rhs.peerId
        }
        if lhs.namespace != rhs.namespace {
            return lhs.namespace != rhs.namespace
        }
        if lhs.tagMask != rhs.tagMask {
            return lhs.tagMask.rawValue < rhs.tagMask.rawValue
        }
        if let lhsThreadId = lhs.threadId, let rhsThreadId = rhs.threadId {
            if lhsThreadId != rhsThreadId {
                return lhsThreadId < rhsThreadId
            }
        } else if (lhs.threadId == nil) != (rhs.threadId == nil) {
            if lhs.threadId != nil {
                return true
            } else {
                return false
            }
        }
        if let lhsCustomTag = lhs.customTag, let rhsCustomTag = rhs.customTag {
            if lhsCustomTag != rhsCustomTag {
                return lhsCustomTag < rhsCustomTag
            }
        } else if (lhs.customTag == nil) != (rhs.customTag == nil) {
            if lhs.customTag != nil {
                return true
            } else {
                return false
            }
        }
        return false
    }
}

public struct InvalidatedMessageHistoryTagsSummaryEntry: Equatable, Hashable {
    public let key: InvalidatedMessageHistoryTagsSummaryKey
    public let version: Int32
    
    public init(key: InvalidatedMessageHistoryTagsSummaryKey, version: Int32) {
        self.key = key
        self.version = version
    }
}

enum InvalidatedMessageHistoryTagsSummaryEntryOperation {
    case add(InvalidatedMessageHistoryTagsSummaryEntry)
    case remove(InvalidatedMessageHistoryTagsSummaryKey)
}

final class InvalidatedMessageHistoryTagsSummaryTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private func key(_ key: InvalidatedMessageHistoryTagsSummaryKey) -> ValueBoxKey {
        if let customTag = key.customTag, customTag.length != 0 {
            var keyLength = 4 + 4 + 8
            keyLength += 8
            keyLength += customTag.length
            let result = ValueBoxKey(length: keyLength)
            
            var offset = 0
            result.setUInt32(offset, value: key.tagMask.rawValue)
            offset += 4
            
            result.setInt32(offset, value: key.namespace)
            offset += 4
            
            result.setInt64(offset, value: key.peerId.toInt64())
            offset += 8
            
            result.setInt64(offset, value: key.threadId ?? 0)
            offset += 8
            
            if customTag.length != 0 {
                customTag.withRawBufferPointer { buffer in
                    result.setBytes(offset, value: buffer)
                    offset += buffer.count
                }
            }
            
            return result
        } else if let threadId = key.threadId {
            let result = ValueBoxKey(length: 4 + 4 + 8 + 8)
            result.setUInt32(0, value: key.tagMask.rawValue)
            result.setInt32(4, value: key.namespace)
            result.setInt64(4 + 4, value: key.peerId.toInt64())
            result.setInt64(4 + 4 + 8, value: threadId)
            return result
        } else {
            let result = ValueBoxKey(length: 4 + 4 + 8)
            result.setUInt32(0, value: key.tagMask.rawValue)
            result.setInt32(4, value: key.namespace)
            result.setInt64(4 + 4, value: key.peerId.toInt64())
            return result
        }
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
            
            var threadId: Int64?
            var customTag: MemoryBuffer?
            if key.length >= 4 + 4 + 8 + 8 {
                threadId = key.getInt64(4 + 4 + 8)
                
                if key.length > 4 + 4 + 8 + 8 {
                    customTag = key.getMemoryBuffer(4 + 4 + 8 + 8, length: key.length - (4 + 4 + 8 + 8))
                    if threadId == 0 {
                        threadId = nil
                    }
                }
            }
            
            entries.append(InvalidatedMessageHistoryTagsSummaryEntry(key: InvalidatedMessageHistoryTagsSummaryKey(peerId: PeerId(key.getInt64(4 + 4)), namespace: key.getInt32(4), tagMask: MessageTags(rawValue: key.getUInt32(0)), threadId: threadId, customTag: customTag), version: version))
            return true
        }, limit: 0)
        return entries
    }
    
    func get(peerId: PeerId, threadId: Int64?, tagMask: MessageTags, namespace: MessageId.Namespace, customTag: MemoryBuffer?) -> InvalidatedMessageHistoryTagsSummaryEntry? {
        return self.get(InvalidatedMessageHistoryTagsSummaryKey(peerId: peerId, namespace: namespace, tagMask: tagMask, threadId: threadId, customTag: customTag))
    }
    
    func getIncludingCustomTags(peerId: PeerId, threadId: Int64?, tagMask: MessageTags, namespace: MessageId.Namespace) -> [InvalidatedMessageHistoryTagsSummaryEntry] {
        var entries: [InvalidatedMessageHistoryTagsSummaryEntry] = []
        
        let peerKey = self.key(InvalidatedMessageHistoryTagsSummaryKey(peerId: peerId, namespace: namespace, tagMask: tagMask, threadId: threadId, customTag: nil))
        self.valueBox.range(
            self.table,
            start: peerKey.predecessor, end: peerKey.successor, values: { key, value in
                var version: Int32 = 0
                value.read(&version, offset: 0, length: 4)
                
                var threadId: Int64?
                var customTag: MemoryBuffer?
                if key.length >= 4 + 4 + 8 + 8 {
                    threadId = key.getInt64(4 + 4 + 8)
                    
                    if key.length > 4 + 4 + 8 + 8 {
                        customTag = key.getMemoryBuffer(4 + 4 + 8 + 8, length: key.length - (4 + 4 + 8 + 8))
                        if threadId == 0 {
                            threadId = nil
                        }
                    }
                }
                
                let entry = InvalidatedMessageHistoryTagsSummaryEntry(key: InvalidatedMessageHistoryTagsSummaryKey(peerId: PeerId(key.getInt64(4 + 4)), namespace: key.getInt32(4), tagMask: MessageTags(rawValue: key.getUInt32(0)), threadId: threadId, customTag: customTag), version: version)
                assert(entry.key.peerId == peerId)
                assert(entry.key.namespace == namespace)
                assert(entry.key.tagMask == tagMask)
                assert(entry.key.threadId == threadId)
                
                entries.append(entry)
                
                return true
            },
            limit: 0
        )
        
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
            self.valueBox.remove(self.table, key: self.key(entry.key), secure: false)
            operations.append(.remove(entry.key))
        }
    }
    
    func removeEntriesWithCustomTags(peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace, tagMask: MessageTags, operations: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        for entry in self.getIncludingCustomTags(peerId: peerId, threadId: threadId, tagMask: tagMask, namespace: namespace) {
            self.valueBox.remove(self.table, key: self.key(entry.key), secure: false)
            operations.append(.remove(entry.key))
        }
    }
    
    override func clearMemoryCache() {
    }
    
    override func beforeCommit() {
    }
}

import Foundation

public struct MessageHistoryTagNamespaceCountValidityRange: Equatable {
    public let maxId: MessageId.Id
    
    public init(maxId: MessageId.Id) {
        self.maxId = maxId
    }
    
    public static func ==(lhs: MessageHistoryTagNamespaceCountValidityRange, rhs: MessageHistoryTagNamespaceCountValidityRange) -> Bool {
        return lhs.maxId == rhs.maxId
    }
    
    public func contains(_ id: MessageId.Id) -> Bool {
        return id <= self.maxId
    }
}

public struct MessageHistoryTagNamespaceSummary: Equatable, CustomStringConvertible {
    public let version: Int32
    public let count: Int32
    public let range: MessageHistoryTagNamespaceCountValidityRange
    
    public init(version: Int32, count: Int32, range: MessageHistoryTagNamespaceCountValidityRange) {
        self.version = version
        self.count = count
        self.range = range
    }
    
    public static func ==(lhs: MessageHistoryTagNamespaceSummary, rhs: MessageHistoryTagNamespaceSummary) -> Bool {
        return lhs.version == rhs.version && lhs.count == rhs.count && lhs.range == rhs.range
    }
    
    func withAddedCount(_ value: Int32) -> MessageHistoryTagNamespaceSummary {
        return MessageHistoryTagNamespaceSummary(version: self.version, count: Int32(clamping: Int64(self.count) + Int64(value)), range: self.range)
    }
    
    public var description: String {
        return "(version: \(self.version), count: \(self.count), range: (maxId: \(self.range.maxId)))"
    }
}

struct MessageHistoryTagsSummaryKey: Equatable, Hashable {
    let tag: MessageTags
    let peerId: PeerId
    let threadId: Int64?
    let namespace: MessageId.Namespace
    let customTag: MemoryBuffer?
    
    init(tag: MessageTags, peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace, customTag: MemoryBuffer?) {
        self.tag = tag
        self.peerId = peerId
        self.threadId = threadId
        self.namespace = namespace
        self.customTag = customTag
    }
}

private func readSummary(_ value: ReadBuffer) -> MessageHistoryTagNamespaceSummary {
    var versionValue: Int32 = 0
    value.read(&versionValue, offset: 0, length: 4)
    var countValue: Int32 = 0
    value.read(&countValue, offset: 0, length: 4)
    var maxIdValue: Int32 = 0
    value.read(&maxIdValue, offset: 0, length: 4)

    return MessageHistoryTagNamespaceSummary(version: versionValue, count: countValue, range: MessageHistoryTagNamespaceCountValidityRange(maxId: maxIdValue))
}

private func writeSummary(_ summary: MessageHistoryTagNamespaceSummary, to buffer: WriteBuffer) {
    var versionValue: Int32 = summary.version
    buffer.write(&versionValue, offset: 0, length: 4)
    var countValue: Int32 = summary.count
    buffer.write(&countValue, offset: 0, length: 4)
    var maxIdValue: Int32 = summary.range.maxId
    buffer.write(&maxIdValue, offset: 0, length: 4)
}

private struct CachedEntry {
    let summary: MessageHistoryTagNamespaceSummary?
}

class MessageHistoryTagsSummaryTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let invalidateTable: InvalidatedMessageHistoryTagsSummaryTable
    
    private var cachedSummaries: [MessageHistoryTagsSummaryKey: CachedEntry] = [:]
    private var updatedKeys = Set<MessageHistoryTagsSummaryKey>()
    
    private let sharedSimpleKey = ValueBoxKey(length: 4 + 8 + 4)
    private let sharedThreadKey = ValueBoxKey(length: 4 + 8 + 4 + 8)
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, invalidateTable: InvalidatedMessageHistoryTagsSummaryTable) {
        self.invalidateTable = invalidateTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func keyShared(key: MessageHistoryTagsSummaryKey) -> ValueBoxKey {
        return self.keyInternal(key: key, allowShared: true)
    }
    
    private func keyInternal(key: MessageHistoryTagsSummaryKey, allowShared: Bool) -> ValueBoxKey {
        if let customTag = key.customTag {
            if customTag.length != 10 && customTag.length != 7 {
                assert(true)
            }
            
            var keyLength = 4 + 8 + 4
            keyLength += 8
            keyLength += customTag.length
            let result = ValueBoxKey(length: keyLength)
            
            var offset = 0
            result.setUInt32(offset, value: key.tag.rawValue)
            offset += 4
            
            result.setInt64(offset, value: key.peerId.toInt64())
            offset += 8
            
            result.setInt32(offset, value: key.namespace)
            offset += 4
            
            result.setInt64(offset, value: key.threadId ?? 0)
            offset += 8
            
            customTag.withRawBufferPointer { buffer in
                result.setBytes(offset, value: buffer)
                offset += buffer.count
            }
            
            return result
        } else if let threadId = key.threadId {
            let result: ValueBoxKey
            if allowShared {
                result = self.sharedThreadKey
            } else {
                result = ValueBoxKey(length: 4 + 8 + 4 + 8)
            }
            result.setUInt32(0, value: key.tag.rawValue)
            result.setInt64(4, value: key.peerId.toInt64())
            result.setInt32(4 + 8, value: key.namespace)
            result.setInt64(4 + 8 + 4, value: threadId)
            return result
        } else {
            let result: ValueBoxKey
            if allowShared {
                result = self.sharedSimpleKey
            } else {
                result = ValueBoxKey(length: 4 + 8 + 4)
            }
            result.setUInt32(0, value: key.tag.rawValue)
            result.setInt64(4, value: key.peerId.toInt64())
            result.setInt32(4 + 8, value: key.namespace)
            return result
        }
    }
    
    func get(_ key: MessageHistoryTagsSummaryKey) -> MessageHistoryTagNamespaceSummary? {
        if let cached = self.cachedSummaries[key] {
            return cached.summary
        } else if let value = self.valueBox.get(self.table, key: self.keyShared(key: key)) {
            let entry = readSummary(value)
            self.cachedSummaries[key] = CachedEntry(summary: entry)
            return entry
        } else {
            self.cachedSummaries[key] = CachedEntry(summary: nil)
            return nil
        }
    }
    
    func getCustomTags(tag: MessageTags, peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace) -> [MemoryBuffer] {
        let key = MessageHistoryTagsSummaryKey(tag: tag, peerId: peerId, threadId: threadId, namespace: namespace, customTag: nil)
        
        let peerKey = self.keyInternal(key: key, allowShared: false)
        let prefixLength = 4 + 8 + 4 + 8
        var result: [MemoryBuffer] = []
        self.valueBox.range(self.table, start: peerKey.predecessor, end: peerKey.successor, keys: { key in
            let testPeerId = key.getInt64(4)
            assert(PeerId(testPeerId) == peerId)
            let testNamespace = key.getInt32(4 + 8)
            assert(testNamespace == namespace)
            
            if key.length > prefixLength {
                result.append(key.getMemoryBuffer(prefixLength, length: key.length - prefixLength))
            }
            return true
        }, limit: 0)
        
        for updatedKey in self.updatedKeys {
            if updatedKey.peerId == peerId && updatedKey.tag == tag && updatedKey.threadId == threadId && updatedKey.namespace == namespace {
                if let customTag = updatedKey.customTag {
                    if !result.contains(customTag) {
                        result.append(customTag)
                    }
                }
            }
        }
        
        return result
    }
    
    private func set(_ key: MessageHistoryTagsSummaryKey, summary: MessageHistoryTagNamespaceSummary, updatedSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary]) {
        if self.get(key) != summary {
            if key.tag.rawValue == 2048 {
                postboxLog("[MessageHistoryTagsSummaryTable] set \(key.tag.rawValue) for \(key.peerId) to \(summary.count)")
            }
            self.updatedKeys.insert(key)
            self.cachedSummaries[key] = CachedEntry(summary: summary)
            updatedSummaries[key] = summary
        }
    }
    
    func addMessage(key: MessageHistoryTagsSummaryKey, id: MessageId.Id, isNewlyAdded: Bool, updatedSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        if let current = self.get(key) {
            if !isNewlyAdded || !current.range.contains(id) {
                self.set(key, summary: current.withAddedCount(1), updatedSummaries: &updatedSummaries)
                if current.range.maxId == 0 {
                    self.invalidateTable.insert(InvalidatedMessageHistoryTagsSummaryKey(peerId: key.peerId, namespace: key.namespace, tagMask: key.tag, threadId: key.threadId, customTag: key.customTag), operations: &invalidateSummaries)
                }
            }
        } else {
            self.set(key, summary: MessageHistoryTagNamespaceSummary(version: 0, count: 1, range: MessageHistoryTagNamespaceCountValidityRange(maxId: 0)), updatedSummaries: &updatedSummaries)
            self.invalidateTable.insert(InvalidatedMessageHistoryTagsSummaryKey(peerId: key.peerId, namespace: key.namespace, tagMask: key.tag, threadId: key.threadId, customTag: key.customTag), operations: &invalidateSummaries)
        }
    }
    
    func removeMessage(key: MessageHistoryTagsSummaryKey, id: MessageId.Id, updatedSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        if let current = self.get(key) {
            if current.count == 0 {
            } else {
                self.set(key, summary: current.withAddedCount(-1), updatedSummaries: &updatedSummaries)
            }
        }
    }
    
    func replace(key: MessageHistoryTagsSummaryKey, count: Int32, maxId: MessageId.Id, updatedSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary]) {
        var version: Int32 = 0
        if let current = self.get(key) {
            version = current.version + 1
        }
        self.set(key, summary: MessageHistoryTagNamespaceSummary(version: version, count: count, range: MessageHistoryTagNamespaceCountValidityRange(maxId: maxId)), updatedSummaries: &updatedSummaries)
    }
    
    override func clearMemoryCache() {
        self.cachedSummaries.removeAll()
        assert(self.updatedKeys.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedKeys.isEmpty {
            let buffer = WriteBuffer()
            for key in self.updatedKeys {
                if let cached = self.cachedSummaries[key] {
                    if let summary = cached.summary {
                        buffer.reset()
                        writeSummary(summary, to: buffer)
                        self.valueBox.set(self.table, key: self.keyShared(key: key), value: buffer)
                    } else {
                        assertionFailure()
                        self.valueBox.remove(self.table, key: self.keyShared(key: key), secure: false)
                    }
                } else {
                    assertionFailure()
                }
            }
            self.updatedKeys.removeAll()
        }

        if !self.useCaches {
            self.cachedSummaries.removeAll()
        }
    }
}
